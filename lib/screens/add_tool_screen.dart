import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/tool_model.dart';
import '../services/tools_service.dart';
import '../services/storage_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_alerts.dart';
import 'location_picker_screen.dart';

class AddToolScreen extends StatefulWidget {
  const AddToolScreen({super.key});

  @override
  State<AddToolScreen> createState() => _AddToolScreenState();
}

class _AddToolScreenState extends State<AddToolScreen> {
  static const double _minPrice = 50;
  double _currentMaxPrice = 5000;

  final _formKey = GlobalKey<FormState>();
  final toolNameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final categoriesCtrl = TextEditingController();
  final addressCtrl = TextEditingController();

  File? _image;
  File? _proofImage;
  final _picker = ImagePicker();
  bool _isLoading = false;
  bool _isAiFilling = false;
  double _selectedPrice = 50;
  Map<String, dynamic>? _selectedLocation;
  String? _lastAiToolName;
  final FocusNode _toolNameFocusNode = FocusNode();
  static const List<String> _conditionOptions = [
    'Excellent',
    'Good',
    'Fair',
    'Needs Maintenance',
  ];
  String? _selectedConditionStatus;

  static const String _tcStrict = 'If the tool was broke/damaged by the BORROWER, then the cost of new/repair cost should be paid to the LENDER by the BORROWER.';
  static const String _tcNone = 'No Terms and Conditions';
  static const List<String> _tcOptions = [_tcStrict, _tcNone];
  String _selectedTcOption = _tcStrict;

  @override
  void initState() {
    super.initState();
    priceCtrl.text = _selectedPrice.toStringAsFixed(0);
    _toolNameFocusNode.addListener(() {
      if (!_toolNameFocusNode.hasFocus) {
        _autofillFromTitle();
      }
    });
    categoriesCtrl.addListener(_updateMaxPrice);
  }

  void _updateMaxPrice() {
    final text = categoriesCtrl.text.toLowerCase();
    double newMax = 5000; 
    
    if (text.contains('hand') || text.contains('manual')) {
      newMax = 1000;
    } else if (text.contains('garden') || text.contains('cleaning')) {
      newMax = 2000;
    } else if (text.contains('power') || text.contains('heavy') || text.contains('machinery')) {
      newMax = 5000;
    } else {
      newMax = 5000;
    }

    if (newMax != _currentMaxPrice) {
      if (mounted) {
        setState(() {
          _currentMaxPrice = newMax;
          if (_selectedPrice > _currentMaxPrice) {
            _selectedPrice = _currentMaxPrice;
            priceCtrl.text = _selectedPrice.toStringAsFixed(0);
          }
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _pickProofImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked != null) setState(() => _proofImage = File(picked.path));
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialAddress: addressCtrl.text,
          initialLocation: _selectedLocation,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        addressCtrl.text = result['address'] as String? ?? '';
        _selectedLocation = result['location'] as Map<String, dynamic>?;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (toolNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide tool name')));
      return;
    }
    final price = double.tryParse(priceCtrl.text);
    if (price == null || price < _minPrice || price > _currentMaxPrice) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Price must be between INR ${_minPrice.toInt()} and INR ${_currentMaxPrice.toInt()}')),
      );
      return;
    }
    if (addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a location')));
      return;
    }
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please pick tool location from map')));
      return;
    }
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tool image is mandatory')));
      return;
    }
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proof of ownership image is mandatory')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      final owner = auth.user;
      final profile = auth.profile;
      if (owner == null || profile == null) {
        showErrorAlert(context, 'Please sign in again and try.');
        return;
      }

      final toolsService = ToolsService();
      if (profile.trustScore < 50) {
        final currentTools = await toolsService.streamToolsByOwner(owner.uid).first;
        if (currentTools.length >= 2) {
          if (mounted) {
            setState(() => _isLoading = false);
            showErrorAlert(context, 'Your trust score is below 50. You cannot have more than 2 active listings.');
          }
          return;
        }
      }

      final ownerId = owner.uid;
      final storage = StorageService();
      
      String imageUrl = '';
      String imagePath = '';
      final dest = 'uploads/$ownerId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final res = await storage.uploadFile(_image!.path, dest);
      imageUrl = res['url'] ?? '';
      imagePath = res['path'] ?? '';

      String proofUrl = '';
      String proofPath = '';
      final pDest = 'uploads/$ownerId/proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final pRes = await storage.uploadFile(_proofImage!.path, pDest);
      proofUrl = pRes['url'] ?? '';
      proofPath = pRes['path'] ?? '';

      final categories = categoriesCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      final tool = Tool(
        id: '',
        ownerId: ownerId,
        title: toolNameCtrl.text.trim(),
        description: descCtrl.text.trim(),
        pricePerDay: price,
        imageUrls: imageUrl.isNotEmpty ? [imageUrl] : [],
        imageStoragePaths: imagePath.isNotEmpty ? [imagePath] : [],
        proofImageUrl: proofUrl.isNotEmpty ? proofUrl : null,
        proofStoragePath: proofPath.isNotEmpty ? proofPath : null,
        categories: categories,
        address: addressCtrl.text.trim(),
        location: _selectedLocation,
        conditionStatus: _selectedConditionStatus ?? '',
        termsAndConditions: _selectedTcOption == _tcStrict ? _tcStrict : null,
        available: true,
        isSuspicious: profile.trustScore < 50, // automatically flag for manual approval if < 50
        isVerified: false,
        visibility: 'visible',
      );

      await toolsService.addTool(tool);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tool created!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '').trim();
        showErrorAlert(
          context,
          message.isEmpty ? 'Unable to create tool. Please try again.' : message,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _autofillFromTitle({bool force = false}) async {
    final toolName = toolNameCtrl.text.trim();
    if (toolName.isEmpty) return;
    if (_isAiFilling) return;

    final descEmpty = descCtrl.text.trim().isEmpty;
    final catEmpty = categoriesCtrl.text.trim().isEmpty;
    if (!force && (!descEmpty || !catEmpty)) return;
    if (!force && _lastAiToolName == toolName) return;

    setState(() => _isAiFilling = true);
    try {
      final auth = context.read<AuthProvider>();
      final prompt = '''
Generate a tool listing draft for this tool name:
Tool name: "$toolName"

Return ONLY JSON in this exact shape:
{"description":"<short description>", "categories":["<cat1>", "<cat2>", "<cat3>"]}

Rules:
- description: 1-2 short sentences.
- categories: 2 to 4 short categories relevant for renting/sharing tools.
- No markdown, no code block fences, no extra text.
''';

      final aiRes = await auth.aiService.query(prompt);
      final text = (aiRes['text'] ?? aiRes['result'] ?? aiRes['answer'] ?? '').toString();
      final parsed = _parseAiListing(text);
      if (!mounted) return;

      if (parsed == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI could not parse suggestion. Enter details manually.')),
        );
        return;
      }

      if (descCtrl.text.trim().isEmpty || force) {
        descCtrl.text = parsed.description;
      }
      if (categoriesCtrl.text.trim().isEmpty || force) {
        categoriesCtrl.text = parsed.categories.join(', ');
      }

      _lastAiToolName = toolName;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI filled description and categories')),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorAlert(context, 'AI autofill failed. Please enter details manually.');
    } finally {
      if (mounted) setState(() => _isAiFilling = false);
    }
  }

  _AiListing? _parseAiListing(String raw) {
    if (raw.trim().isEmpty) return null;
    String candidate = raw.trim();

    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(candidate);
    if (jsonMatch != null) {
      candidate = jsonMatch.group(0) ?? candidate;
    }

    try {
      final map = json.decode(candidate) as Map<String, dynamic>;
      final description = (map['description'] ?? '').toString().trim();
      final categoriesRaw = map['categories'];
      final categories = <String>[];
      if (categoriesRaw is List) {
        for (final item in categoriesRaw) {
          final c = item.toString().trim();
          if (c.isNotEmpty) categories.add(c);
        }
      } else if (categoriesRaw is String) {
        categories.addAll(
          categoriesRaw
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty),
        );
      }

      if (description.isEmpty || categories.isEmpty) return null;
      return _AiListing(description: description, categories: categories.take(4).toList());
    } catch (_) {
      return null;
    }
  }

  void _onPriceSliderChanged(double value) {
    setState(() {
      _selectedPrice = value;
      priceCtrl.text = value.toStringAsFixed(0);
    });
  }

  void _onPriceTextChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null) return;
    final clamped = parsed.clamp(_minPrice, _currentMaxPrice).toDouble();
    if ((clamped - _selectedPrice).abs() >= 1) {
      setState(() => _selectedPrice = clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add your Tool')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: toolNameCtrl,
                      focusNode: _toolNameFocusNode,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _autofillFromTitle(),
                      decoration: InputDecoration(
                        labelText: 'Tool name *',
                        suffixIcon: IconButton(
                          onPressed: _isAiFilling ? null : () => _autofillFromTitle(force: true),
                          icon: _isAiFilling
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome),
                          tooltip: 'AI fill description & categories',
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Description *'),
                      maxLines: 3,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: categoriesCtrl,
                      decoration: const InputDecoration(labelText: 'Categories (comma separated) *'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Categories are required';
                        final categories = v.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        if (categories.isEmpty) return 'Enter at least one category';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedConditionStatus,
                      decoration: const InputDecoration(labelText: 'Condition Status *'),
                      items: _conditionOptions
                          .map((option) => DropdownMenuItem<String>(
                                value: option,
                                child: Text(option),
                              ))
                          .toList(),
                      onChanged: (value) => setState(() => _selectedConditionStatus = value),
                      validator: (value) => value == null || value.isEmpty ? 'Condition status is required' : null,
                    ),
                    const SizedBox(height: 12),
                    const Text('Terms and Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTcOption,
                      isExpanded: true,
                      isDense: false,
                      itemHeight: null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: _tcOptions.map((option) {
                        return DropdownMenuItem<String>(
                          value: option,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              option,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        );
                      }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedTcOption = value);
                      }
                    },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: priceCtrl,
                      decoration: InputDecoration(
                        labelText: 'Price per day (INR) *',
                        helperText: 'Enter manually or use slider range INR ${_minPrice.toInt()} - INR ${_currentMaxPrice.toInt()}',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: _onPriceTextChanged,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Price is required';
                        final parsed = double.tryParse(v);
                        if (parsed == null) return 'Invalid number';
                        if (parsed < _minPrice || parsed > _currentMaxPrice) {
                          return 'Allowed range: INR ${_minPrice.toInt()} - INR ${_currentMaxPrice.toInt()}';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _selectedPrice,
                      min: _minPrice,
                      max: _currentMaxPrice,
                      divisions: ((_currentMaxPrice - _minPrice) / 50).round(),
                      label: 'INR ${_selectedPrice.toStringAsFixed(0)}',
                      onChanged: _isLoading ? null : _onPriceSliderChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Location *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: addressCtrl,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Tap to select location',
                        suffixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onTap: _pickLocation,
                      validator: (v) => v == null || v.isEmpty ? 'Location required' : null,
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _pickLocation,
                      icon: const Icon(Icons.map),
                      label: const Text('Open Location Map'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tool Image *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _pickImage,
                          icon: const Icon(Icons.photo),
                          label: const Text('Pick Image'),
                        ),
                        const SizedBox(width: 12),
                        if (_image != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_image!, width: 88, height: 88, fit: BoxFit.cover),
                          )
                        else
                          const Text('Required'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text('Proof of Ownership *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text(
                      'Upload an image of the tool along with a handwritten note showing "GrabTools + [Today\'s Date]".',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _pickProofImage,
                          icon: const Icon(Icons.verified),
                          label: const Text('Pick Proof'),
                        ),
                        const SizedBox(width: 12),
                        if (_proofImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_proofImage!, width: 88, height: 88, fit: BoxFit.cover),
                          )
                        else
                          const Text('Required'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isLoading ? null : _submit, child: _isLoading
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('Saving...'),
                      ],
                    )
                  : const Text('Add Tool'))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _toolNameFocusNode.dispose();
    toolNameCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    categoriesCtrl.dispose();
    addressCtrl.dispose();
    super.dispose();
  }
}

class _AiListing {
  final String description;
  final List<String> categories;

  _AiListing({
    required this.description,
    required this.categories,
  });
}

class _SectionCard extends StatefulWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _hovered = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() => _hovered = value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(12);
    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.7),
          borderRadius: radius,
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : const Color(0xFF1300FF)).withValues(alpha: _hovered ? 0.2 : 0.1),
              blurRadius: _hovered ? 20 : 12,
              spreadRadius: _hovered ? 0.4 : 0,
              offset: Offset(0, _hovered ? 10 : 6),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: _hovered ? 0.16 : 0.06),
              blurRadius: _hovered ? 14 : 8,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}