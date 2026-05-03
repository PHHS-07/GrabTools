import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

import '../models/tool_model.dart';
import '../services/location_service.dart';
import '../services/ratings_service.dart';
import '../services/tools_service.dart';
import '../widgets/app_alerts.dart';
import '../widgets/contact_owner_sheet.dart';
import '../widgets/tool_availability_badge.dart';
import 'tool_details_screen.dart';

class ToolMapSearchScreen extends StatefulWidget {
  const ToolMapSearchScreen({super.key});

  @override
  State<ToolMapSearchScreen> createState() => _ToolMapSearchScreenState();
}

class _ToolMapSearchScreenState extends State<ToolMapSearchScreen> {
  Position? _userLocation;
  bool _isLoading = true;
  bool _hasLocationError = false;
  double _radiusKm = 5.0;
  String? _selectedCategory;

  final List<String> _categories = const [
    'Power Tools',
    'Hand Tools',
    'Gardening',
    'Cleaning',
    'Painting',
    'Plumbing',
    'Electrical',
    'Heavy Equipment',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _hasLocationError = false;
      });

      final position = await LocationService().getCurrentLocation();
      if (!mounted) return;

      if (position != null) {
        setState(() {
          _userLocation = position;
          _isLoading = false;
        });
      } else {
        showErrorAlert(context, 'Could not get location. Please enable location services.');
        setState(() {
          _hasLocationError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorAlert(context, 'Unable to get location. Please try again.');
      }
      setState(() {
        _hasLocationError = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover Nearby Tools')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasLocationError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _getUserLocation,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _userLocation == null
                  ? const Center(child: Text('Location not available'))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: FilterChip(
                                        label: const Text('All'),
                                        selected: _selectedCategory == null,
                                        onSelected: (_) => setState(() => _selectedCategory = null),
                                      ),
                                    ),
                                    ..._categories.map(
                                      (cat) => Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: FilterChip(
                                          label: Text(cat),
                                          selected: _selectedCategory == cat,
                                          onSelected: (_) => setState(() => _selectedCategory = cat),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text('Search Radius', style: TextStyle(fontWeight: FontWeight.bold)),
                              Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      value: _radiusKm,
                                      min: 2,
                                      max: 50,
                                      divisions: 48,
                                      label: '${_radiusKm.toStringAsFixed(0)} km',
                                      onChanged: (value) => setState(() => _radiusKm = value),
                                    ),
                                  ),
                                  Text('${_radiusKm.toStringAsFixed(0)} km'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              if (_radiusKm > 10.0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      border: Border.all(color: Colors.red),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Max 10 km search radius is allowed',
                                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: StreamBuilder<List<Tool>>(
                                  stream: ToolsService().streamToolsNearby(
                                    userLat: _userLocation!.latitude,
                                    userLng: _userLocation!.longitude,
                                    radiusKm: _radiusKm > 10.0 ? 10.0 : _radiusKm,
                                    category: _selectedCategory,
                                  ),
                            builder: (context, snap) {
                              if (snap.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              var tools = snap.data ?? [];
                              final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.uid;
                              tools = tools.where((t) => t.ownerId != currentUserId).toList();

                              if (tools.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.search_off, size: 64, color: Colors.grey),
                                      const SizedBox(height: 16),
                                      const Text('No tools found nearby'),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try increasing the search radius or changing category',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                itemCount: tools.length,
                                itemBuilder: (ctx, i) {
                                  final t = tools[i];
                                  final distance = (t.location != null)
                                      ? LocationService.calculateDistance(
                                          _userLocation!.latitude,
                                          _userLocation!.longitude,
                                          t.location!['lat'] as double,
                                          t.location!['lng'] as double,
                                        )
                                      : 0.0;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: _LiquidGlassCard(
                                      child: ListTile(
                                      leading: t.imageUrls.isNotEmpty
                                          ? Image.network(
                                              t.imageUrls.first,
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 28),
                                            )
                                          : const Icon(Icons.build),
                                      title: Text(t.title),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                            StreamBuilder<List<Rating>>(
                                              stream: RatingsService().streamRatingsByTool(t.id),
                                              builder: (context, ratingSnap) {
                                                if (!ratingSnap.hasData || ratingSnap.data!.isEmpty) {
                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 2),
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.star, color: Colors.amber, size: 14),
                                                        const SizedBox(width: 4),
                                                        const Text(
                                                          '0.0/5 (0)',
                                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
                                                final ratings = ratingSnap.data!;
                                                final avgScore = ratings.fold(0.0, (s, r) => s + (r.toolRating ?? r.behavior)) / ratings.length;
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 2),
                                                  child: Row(
                                                    children: [
                                                      const Icon(Icons.star, color: Colors.amber, size: 14),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${avgScore.toStringAsFixed(1)}/5 (${ratings.length})',
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                          if (t.address != null)
                                            Row(
                                              children: [
                                                const Icon(Icons.location_on, size: 13, color: Colors.grey),
                                                const SizedBox(width: 2),
                                                Expanded(
                                                  child: Text(
                                                    t.address!,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          Row(
                                            children: [
                                              Text(
                                                '${distance.toStringAsFixed(1)} km away • ',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                              const Icon(Icons.currency_rupee, size: 13),
                                              Text(
                                                '${t.pricePerDay.toStringAsFixed(0)}/day',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          ToolAvailabilityBadge(tool: t, compact: true),
                                          const SizedBox(height: 4),
                                          TextButton.icon(
                                            onPressed: () => showContactOwnerSheet(context, t),
                                            icon: const Icon(Icons.contact_phone, size: 16),
                                            label: const Text('Contact Owner'),
                                          ),
                                        ],
                                      ),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => ToolDetailsScreen(toolId: t.id)),
                                      ),
                                    ),
                                  ),
                                  );
                                },
                              );
                            },
                          ),
                                ),
                              ],
                            ),
                        ),
                      ],
                    ),
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