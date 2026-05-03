import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/tool_model.dart';
import '../services/tools_service.dart';
import '../services/storage_service.dart';
import '../services/vision_service.dart';
import '../config/app_config.dart';
import '../widgets/app_alerts.dart';
import '../services/location_service.dart';
import 'location_picker_screen.dart';

class EditToolScreen extends StatefulWidget {
  final String toolId;
  const EditToolScreen({super.key, required this.toolId});

  @override
  State<EditToolScreen> createState() => _EditToolScreenState();
}

class _EditToolScreenState extends State<EditToolScreen> {
  final _formKey = GlobalKey<FormState>();
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final categoriesCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  Map<String, dynamic>? _selectedLocation;
  static const List<String> _conditionOptions = [
    'Excellent',
    'Good',
    'Fair',
    'Needs Maintenance',
  ];
  List<String> imageUrls = [];
  List<String> imagePaths = [];
  File? _pickedImage;
  final _picker = ImagePicker();
  bool _loading = true;
  late Tool _tool;
  String? _selectedConditionStatus;

  static const String _tcStrict = 'If the tool was broke/damaged by the BORROWER, then the cost of new/repair cost should be paid to the LENDER by the BORROWER.';
  static const String _tcNone = 'No Terms and Conditions';
  final List<String> _tcOptions = [_tcStrict, _tcNone];
  String _selectedTcOption = _tcStrict;

  bool _isSaving = false;
  bool _isVerifying = false;
  static const double _minPrice = 50;
  double _currentMaxPrice = 5000;

  @override
  void initState() {
    super.initState();
    ToolsService().getTool(widget.toolId).then((t) {
      if (t != null) {
        _tool = t;
        titleCtrl.text = t.title;
        descCtrl.text = t.description;
        priceCtrl.text = t.pricePerDay.toString();
        categoriesCtrl.text = t.categories.join(', ');
        
        final existingTc = t.termsAndConditions;
        if (existingTc != null && existingTc.isNotEmpty) {
          if (!_tcOptions.contains(existingTc)) {
            _tcOptions.add(existingTc);
          }
          _selectedTcOption = existingTc;
        } else {
          _selectedTcOption = _tcNone;
        }

        _selectedConditionStatus = t.conditionStatus.isEmpty ? null : t.conditionStatus;
        imageUrls = List.from(t.imageUrls);
        imagePaths = List.from(t.imageStoragePaths);
        addressCtrl.text = t.address ?? '';
        _selectedLocation = t.location;
      }
      setState(() => _loading = false);
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
        });
      }
    }
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

  Future<void> _useCurrentLocation() async {
    setState(() => _isSaving = true); // Reuse saving state for loading
    try {
      final pos = await LocationService().getCurrentLocation();
      if (pos != null && mounted) {
        setState(() {
          _selectedLocation = {
            'lat': pos.latitude,
            'lng': pos.longitude,
          };
          addressCtrl.text = 'My Current Location (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current location updated!')));
      } else {
        if (mounted) showErrorAlert(context, 'Unable to get current location. Ensure GPS is on.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _deleteImage(int idx) async {
    try {
      if (idx < imagePaths.length) {
        final path = imagePaths[idx];
        if (path.isNotEmpty) {
          await StorageService().deleteFile(path);
        }
      }
    } catch (e) {
      // Ignore file deletion errors (e.g. file already deleted or doesn't exist)
    }
    if (mounted) {
      setState(() {
        if (idx < imagePaths.length) imagePaths.removeAt(idx);
        if (idx < imageUrls.length) imageUrls.removeAt(idx);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (imageUrls.isEmpty && _pickedImage == null) {
      showErrorAlert(context, 'At least one tool image is mandatory');
      return;
    }

    setState(() => _isSaving = true);
    try {
      String newImageUrl = '';
      String newImagePath = '';
      if (_pickedImage != null) {
        if (AppConfig.visionApiKey != 'YOUR_VISION_API_KEY_HERE') {
          setState(() => _isVerifying = true);
          final visionResult = await VisionService().verifyToolImage(
            imageFile: _pickedImage!,
            toolName: titleCtrl.text.trim(),
          );
          setState(() => _isVerifying = false);
          if (!mounted) return;
          if (!visionResult.isValid) {
            showErrorAlert(context, visionResult.reason ?? 'Invalid image. Please upload a clear tool photo.');
            setState(() => _isSaving = false);
            return;
          }
        }

        final dest = 'uploads/${_tool.ownerId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final res = await StorageService().uploadFile(_pickedImage!.path, dest);
        newImageUrl = res['url'] ?? '';
        newImagePath = res['path'] ?? '';
        if (newImageUrl.isNotEmpty) {
          imageUrls.add(newImageUrl);
          imagePaths.add(newImagePath);
        }
      }

    final updated = Tool(
      id: _tool.id,
      ownerId: _tool.ownerId,
      title: titleCtrl.text,
      description: descCtrl.text,
      pricePerDay: double.tryParse(priceCtrl.text) ?? 0.0,
      imageUrls: imageUrls,
      imageStoragePaths: imagePaths,
      categories: categoriesCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      location: _selectedLocation,
      address: addressCtrl.text,
      conditionStatus: _selectedConditionStatus ?? '',
      termsAndConditions: _selectedTcOption == _tcNone ? null : _selectedTcOption,
      available: _tool.available,
      isSuspicious: _tool.isSuspicious,
      isVerified: _tool.isVerified,
      visibility: _tool.visibility,
    );

    await ToolsService().updateTool(updated);
    if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        showErrorAlert(context, 'Unable to update tool. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Tool')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                maxLines: 3,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: priceCtrl,
                decoration: InputDecoration(
                  labelText: 'Price per day',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  helperText: 'Max INR ${_currentMaxPrice.toInt()}',
                ),
                keyboardType: TextInputType.number,
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
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: categoriesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Categories (comma separated)',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedConditionStatus,
                decoration: const InputDecoration(
                  labelText: 'Condition Status',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                items: _conditionOptions
                    .map((option) => DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _selectedConditionStatus = value),
                validator: (value) => value == null || value.isEmpty ? 'Required' : null,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: addressCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  suffixIcon: Icon(Icons.location_on),
                ),
                onTap: _pickLocation,
                validator: (v) => v == null || v.isEmpty ? 'Location required' : null,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickLocation,
                    icon: const Icon(Icons.map),
                    label: const Text('Pick on Map'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _useCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use Current'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Terms and Conditions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
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
            ),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: List.generate(imageUrls.length, (i) {
              return Stack(children: [
                Image.network(imageUrls[i], width: 100, height: 80, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40)),
                Positioned(top: 0, right: 0, child: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteImage(i))),
              ]);
            })),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo),
                  label: const Text('Pick Image (add)'),
                ),
                const SizedBox(width: 12),
                if (_pickedImage != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_pickedImage!, width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  IconButton(
                    tooltip: 'Remove selected image',
                    onPressed: () => setState(() => _pickedImage = null),
                    icon: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                          const SizedBox(width: 10),
                          Text(_isVerifying ? 'Verifying image...' : 'Saving...'),
                        ],
                      )
                    : const Text('Save'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
    priceCtrl.dispose();
    categoriesCtrl.dispose();
    addressCtrl.dispose();
    super.dispose();
  }
}
