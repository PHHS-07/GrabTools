import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/tools_service.dart';
import '../models/tool_model.dart';
import '../services/ratings_service.dart';
import '../widgets/tool_availability_badge.dart';
import 'tool_details_screen.dart';
import '../services/address_service.dart';
import '../services/storage_service.dart';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';

class ToolSearchScreen extends StatefulWidget {
  const ToolSearchScreen({super.key});

  @override
  State<ToolSearchScreen> createState() => _ToolSearchScreenState();
}

class _ToolSearchScreenState extends State<ToolSearchScreen> {
  static const String _historyStorageKey = 'assistance_history_v1';

  final Set<String> _selectedCategories = <String>{};
  final addressCtrl = TextEditingController();
  final radiusCtrl = TextEditingController(text: '2'); // km

  String? _sortOption;
  String? _ratingFilter;
  final Set<String> _selectedConditions = {};

  double? _userLat;
  double? _userLng;
  bool _geocoding = false;
  bool _assisting = false;

  XFile? _pickedImage;
  List<_AssistanceMessage> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _useMyLocation();
    });
  }

  @override
  void dispose() {
    addressCtrl.dispose();
    radiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyStorageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentUid = auth.user?.uid;
      
      final data = json.decode(raw) as List<dynamic>;
      final allMessages = data
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(_AssistanceMessage.fromJson)
          .toList();
          
      final userMessages = allMessages.where((msg) => msg.userId == currentUid || msg.userId == null).toList();
      
      if (mounted) {
        setState(() => _history = userMessages);
      }
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load all existing global history first
    final raw = prefs.getString(_historyStorageKey);
    List<_AssistanceMessage> globalHistory = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = json.decode(raw) as List<dynamic>;
        globalHistory = data
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map(_AssistanceMessage.fromJson)
            .toList();
      } catch (_) {}
    }

    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUid = auth.user?.uid;

    // Filter out the *current user's* old messages from the global store, 
    // replacing them entirely with the new local `_history` state.
    globalHistory.removeWhere((msg) => msg.userId == currentUid || msg.userId == null);
    globalHistory.addAll(_history);

    final payload = globalHistory.map((e) => e.toJson()).toList();
    await prefs.setString(_historyStorageKey, json.encode(payload));
  }

  Future<void> _appendHistory(_AssistanceMessage msg) async {
    _history.add(msg);
    await _saveHistory();
    if (mounted) setState(() {});
  }

  Future<void> _geocodeAddress(String address) async {
    setState(() => _geocoding = true);
    try {
      final locs = await AddressService().getCoordinatesFromAddress(address);
      if (locs.isNotEmpty) {
        setState(() {
          _userLat = locs.first.latitude;
          _userLng = locs.first.longitude;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address not found')));
        }
      }
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _geocoding = true);
    try {
      final addr = await AddressService().getCurrentLocationAsAddress();
      if (addr != null) {
        addressCtrl.text = addr;
        await _geocodeAddress(addr);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not determine current address')));
        }
      }
    } finally {
      if (mounted) setState(() => _geocoding = false);
    }
  }

  Future<void> _openFiltersDialog() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Filters & Sort', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              _sortOption = null;
                              _ratingFilter = null;
                              _selectedConditions.clear();
                            });
                            setState((){});
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text('By Price', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Low to High'),
                          selected: _sortOption == 'price_asc',
                          onSelected: (s) { if (s) { setSheetState(() => _sortOption = 'price_asc'); setState((){}); } },
                        ),
                        ChoiceChip(
                          label: const Text('High to Low'),
                          selected: _sortOption == 'price_desc',
                          onSelected: (s) { if (s) { setSheetState(() => _sortOption = 'price_desc'); setState((){}); } },
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text('By Distance', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Nearest to Farthest'),
                          selected: _sortOption == 'dist_asc',
                          onSelected: (s) { if (s) { setSheetState(() => _sortOption = 'dist_asc'); setState((){}); } },
                        ),
                        ChoiceChip(
                          label: const Text('Farthest to Nearest'),
                          selected: _sortOption == 'dist_desc',
                          onSelected: (s) { if (s) { setSheetState(() => _sortOption = 'dist_desc'); setState((){}); } },
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text('By Tool Ratings', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('4 star & above'),
                          selected: _ratingFilter == '4.0',
                          onSelected: (s) { if (s) { setSheetState(() => _ratingFilter = '4.0'); setState((){}); } },
                        ),
                        ChoiceChip(
                          label: const Text('2.5 star & above'),
                          selected: _ratingFilter == '2.5',
                          onSelected: (s) { if (s) { setSheetState(() => _ratingFilter = '2.5'); setState((){}); } },
                        ),
                        ChoiceChip(
                          label: const Text('Below 2.5 star'),
                          selected: _ratingFilter == 'below_2.5',
                          onSelected: (s) { if (s) { setSheetState(() => _ratingFilter = 'below_2.5'); setState((){}); } },
                        ),
                      ],
                    ),
                    const Divider(),
                    const Text('By Condition', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Excellent', 'Good', 'Fair', 'Needs Maintenance'].map((cond) {
                        return FilterChip(
                          label: Text(cond),
                          selected: _selectedConditions.contains(cond),
                          onSelected: (selected) {
                            setSheetState(() {
                              if (selected) {
                                _selectedConditions.add(cond);
                              } else {
                                _selectedConditions.remove(cond);
                              }
                            });
                            setState((){});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Apply Filters'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }



  Future<void> _openAssistanceDialog(List<String> availableCategories) async {
    final msgCtrl = TextEditingController();
    XFile? localPicked = _pickedImage;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Need Assistance'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: msgCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Describe what you need')),
            const SizedBox(height: 8),
            Row(children: [
              ElevatedButton.icon(onPressed: () async { final p = ImagePicker(); final f = await p.pickImage(source: ImageSource.gallery); if (f != null) { setState(() {}); localPicked = f; } }, icon: const Icon(Icons.image), label: const Text('Add Image')),
              const SizedBox(width: 8),
              if (localPicked != null) const Text('Image selected'),
            ])
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final message = msgCtrl.text.trim();
              if (message.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a description')));
                return;
              }
              Navigator.of(ctx).pop();
              await _handleAssistanceSubmit(message, localPicked, availableCategories);
            },
            child: const Text('Ask AI'),
          )
        ],
      ),
    );
  }

  Future<void> _handleAssistanceSubmit(String message, XFile? image, List<String> availableCategories) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUid = auth.user?.uid;
    setState(() => _assisting = true);
    String? imageUrl;
    try {
      if (image != null) {
        final dest = 'assistance_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        final res = await StorageService().uploadFile(image.path, dest);
        imageUrl = res['url'];
      }
      final prompt = StringBuffer()
        ..writeln('User needs assistance finding tools.')
        ..writeln('Description:')
        ..writeln(message)
        ..writeln();
      if (imageUrl != null) prompt.writeln('Image: $imageUrl');
      prompt.writeln('Available categories: ${availableCategories.join(', ')}.');
      prompt.writeln('Suggest up to 3 categories or specific tool types from the above list that best match the user request. Respond with a short list like: Category: <name>\nReason: <brief>');

      await _appendHistory(
        _AssistanceMessage(
          role: 'user',
          text: message,
          timestamp: DateTime.now().toIso8601String(),
          imageUrl: imageUrl,
          userId: currentUid,
        ),
      );

      final aiRes = await auth.aiService.query(prompt.toString(), imageUrl: imageUrl);
      final text = (aiRes['text'] ?? aiRes['result'] ?? aiRes['answer'] ?? aiRes.toString()).toString();

      await _appendHistory(
        _AssistanceMessage(
          role: 'assistant',
          text: text,
          timestamp: DateTime.now().toIso8601String(),
          userId: currentUid,
        ),
      );

      if (!mounted) return;
      // show AI response and allow applying the first matching category
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI Suggestions'),
          content: SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
            TextButton(
              onPressed: () {
                // try to find a category mentioned by AI
                final lowered = text.toLowerCase();
                final matches = availableCategories.where((c) => lowered.contains(c.toLowerCase())).toList();
                if (matches.isNotEmpty) {
                  setState(() {
                    _selectedCategories
                      ..clear()
                      ..addAll(matches);
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Applied suggested categories: ${matches.join(', ')}')),
                    );
                  }
                } else {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No suggested category could be matched')));
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Apply Suggestion'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('AI error: $e');
      await _appendHistory(
        _AssistanceMessage(
          role: 'assistant',
          text: 'Failed to get AI response: ${e.toString().replaceFirst('Exception: ', '')}',
          timestamp: DateTime.now().toIso8601String(),
          isError: true,
          userId: currentUid,
        ),
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('AI request failed'),
          content: SingleChildScrollView(
            child: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
        ),
      );
    } finally {
      if (mounted) setState(() => _assisting = false);
    }
  }

  Future<void> _openHistoryScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AssistanceHistoryScreen(
          messages: _history,
          onClear: () async {
            _history.clear();
            await _saveHistory();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  bool _withinRadius(Tool t, double? userLat, double? userLng, double radiusKm) {
    if (userLat == null || userLng == null) return true;
    if (t.location == null) return false;
    final toolLat = t.location!['lat'] as double?;
    final toolLng = t.location!['lng'] as double?;
    if (toolLat == null || toolLng == null) return false;
    final dist = LocationService.calculateDistance(userLat, userLng, toolLat, toolLng);
    return dist <= radiusKm;
  }

  @override
  Widget build(BuildContext context) {
    final radius = double.tryParse(radiusCtrl.text) ?? 10.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Tools'),
      ),
      body: Column(children: [
        // categories dropdown populated from available tools
        StreamBuilder<List<Tool>>(
          stream: ToolsService().streamTools(),
          builder: (ctx, snap) {
            final toolsAll = snap.data ?? [];
            final categories = <String>{};
            for (final t in toolsAll) {
              categories.addAll(t.categories);
            }
            final sorted = categories.toList()..sort();
            final availableCategories = sorted;

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _selectedCategories.isEmpty,
                          onSelected: (_) => setState(_selectedCategories.clear),
                        ),
                        ...availableCategories.map(
                          (category) => FilterChip(
                            label: Text(category),
                            selected: _selectedCategories.contains(category),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedCategories.add(category);
                                } else {
                                  _selectedCategories.remove(category);
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(width: 100, child: TextField(controller: radiusCtrl, decoration: const InputDecoration(labelText: 'km'))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address (city or street)'))),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _geocoding ? null : () => _geocodeAddress(addressCtrl.text), child: _geocoding ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Go')),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _geocoding ? null : _useMyLocation, child: const Icon(Icons.my_location)),
                ]),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(onPressed: _openFiltersDialog, icon: const Icon(Icons.filter_list), label: const Text('Filters')),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    ElevatedButton.icon(onPressed: _assisting ? null : () => _openAssistanceDialog(availableCategories), icon: const Icon(Icons.help), label: _assisting ? const Text('Asking...') : const Text('Need Assistance')),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _openHistoryScreen,
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Assistance History'),
                    ),
                    const SizedBox(width: 8),
                    if (_pickedImage != null) const Text('Image ready'),
                  ]),
                ),
              ]),
            );
          },
        ),
        const Divider(),
        Expanded(
          child: StreamBuilder<List<Tool>>(stream: ToolsService().streamTools(), builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            var tools = snap.data ?? [];
            final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
            
            // Exclude user's own tools from search results
            tools = tools.where((t) => t.ownerId != currentUserId).toList();

            if (_selectedCategories.isNotEmpty) {
              tools = tools
                  .where((tool) => tool.categories.any(_selectedCategories.contains))
                  .toList();
            }
            tools = tools.where((t) => _withinRadius(t, _userLat, _userLng, radius)).toList();
            if (_selectedConditions.isNotEmpty) {
              tools = tools.where((t) => _selectedConditions.contains(t.conditionStatus)).toList();
            }

            if (_sortOption == 'price_asc') {
              tools.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
            } else if (_sortOption == 'price_desc') {
              tools.sort((a, b) => b.pricePerDay.compareTo(a.pricePerDay));
            } else if ((_sortOption == 'dist_asc' || _sortOption == 'dist_desc') && _userLat != null && _userLng != null) {
              tools.sort((a, b) {
                final latA = a.location?['lat'] as double?;
                final lngA = a.location?['lng'] as double?;
                final latB = b.location?['lat'] as double?;
                final lngB = b.location?['lng'] as double?;
                
                final distA = (latA != null && lngA != null) ? LocationService.calculateDistance(_userLat!, _userLng!, latA, lngA) : double.infinity;
                final distB = (latB != null && lngB != null) ? LocationService.calculateDistance(_userLat!, _userLng!, latB, lngB) : double.infinity;
                
                if (_sortOption == 'dist_asc') {
                  return distA.compareTo(distB);
                } else {
                  return distB.compareTo(distA);
                }
              });
            }

            if (tools.isEmpty) return const Center(child: Text('No tools found'));
            return ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), itemCount: tools.length, itemBuilder: (ctx, i) {
              final t = tools[i];
              double? distance;
              if (_userLat != null && _userLng != null && t.location != null) {
                final toolLat = t.location!['lat'] as double?;
                final toolLng = t.location!['lng'] as double?;
                if (toolLat != null && toolLng != null) {
                  distance = LocationService.calculateDistance(_userLat!, _userLng!, toolLat, toolLng);
                }
              }

              return StreamBuilder(
                stream: RatingsService().streamRatingsByTool(t.id),
                builder: (context, ratingSnap) {
                  if (ratingSnap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
                  }
                  
                  double avgScore = 0.0;
                  int ratingsCount = 0;
                  if (ratingSnap.hasData && (ratingSnap.data as List).isNotEmpty) {
                    final ratingsList = ratingSnap.data as List;
                    ratingsCount = ratingsList.length;
                    avgScore = ratingsList.fold(0.0, (s, r) => s + ((r.toolRating ?? r.behavior) as num)) / ratingsCount;
                  }

                  if (_ratingFilter == '4.0' && avgScore < 4.0) return const SizedBox.shrink();
                  if (_ratingFilter == '2.5' && avgScore < 2.5) return const SizedBox.shrink();
                  if (_ratingFilter == 'below_2.5' && (ratingsCount == 0 || avgScore >= 2.5)) return const SizedBox.shrink();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LiquidGlassCard(
                      child: ListTile(
                        leading: t.imageUrls.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(t.imageUrls.first, width: 56, height: 56, fit: BoxFit.cover),
                              )
                            : const Icon(Icons.build),
                        title: Text(t.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    ratingsCount > 0 
                                      ? '${avgScore.toStringAsFixed(1)}/5 ($ratingsCount)' 
                                      : '0.0/5 (0)',
                                    style: TextStyle(
                                      fontSize: 12, 
                                      fontWeight: FontWeight.w600,
                                      color: ratingsCount > 0 ? null : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (distance != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 13, color: Colors.grey),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${distance.toStringAsFixed(1)} km away',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 2),
                            ToolAvailabilityBadge(tool: t, compact: true),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.currency_rupee, size: 16),
                            Text('${t.pricePerDay.toStringAsFixed(0)}/day'),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ToolDetailsScreen(toolId: t.id))),
                      ),
                    ),
                  );
                },
              );
            });
          }),
        )
      ]),
    );
  }
}

class _LiquidGlassCard extends StatefulWidget {
  final Widget child;

  const _LiquidGlassCard({required this.child});

  @override
  State<_LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<_LiquidGlassCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(14);
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : const Color(0xFF1300FF)).withValues(alpha: _hovered ? 0.22 : 0.12),
              blurRadius: _hovered ? 24 : 14,
              spreadRadius: _hovered ? 0.6 : 0,
              offset: Offset(0, _hovered ? 12 : 8),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: _hovered ? 0.18 : 0.08),
              blurRadius: _hovered ? 18 : 10,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.62),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.75),
                ),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistanceMessage {
  final String role;
  final String text;
  final String timestamp;
  final String? imageUrl;
  final bool isError;
  final String? userId;

  _AssistanceMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.imageUrl,
    this.isError = false,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'timestamp': timestamp,
        'imageUrl': imageUrl,
        'isError': isError,
        'userId': userId,
      };

  factory _AssistanceMessage.fromJson(Map<String, dynamic> json) {
    return _AssistanceMessage(
      role: (json['role'] ?? 'assistant').toString(),
      text: (json['text'] ?? '').toString(),
      timestamp: (json['timestamp'] ?? DateTime.now().toIso8601String()).toString(),
      imageUrl: json['imageUrl']?.toString(),
      isError: json['isError'] == true,
      userId: json['userId']?.toString(),
    );
  }
}

class _AssistanceHistoryScreen extends StatelessWidget {
  final List<_AssistanceMessage> messages;
  final Future<void> Function() onClear;

  const _AssistanceHistoryScreen({
    required this.messages,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...messages]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assistance History'),
        actions: [
          if (sorted.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await onClear();
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: sorted.isEmpty
          ? const Center(child: Text('No assistance history yet'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final msg = sorted[index];
                final isUser = msg.role == 'user';
                final bgColor = msg.isError
                    ? Colors.red.shade100
                    : isUser
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                        : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.12);

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUser ? 'You' : 'Assistant',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(msg.text),
                        if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Image: ${msg.imageUrl}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}