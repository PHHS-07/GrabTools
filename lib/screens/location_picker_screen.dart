import 'package:flutter/material.dart';
import 'package:flutter_osm_plugin/flutter_osm_plugin.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/address_service.dart';
import '../widgets/app_alerts.dart';

class LocationPickerScreen extends StatefulWidget {
  final String? initialAddress;
  final Map<String, dynamic>? initialLocation;

  const LocationPickerScreen({
    this.initialAddress,
    this.initialLocation,
    super.key,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late MapController _mapController;
  final addressCtrl = TextEditingController();
  final addressService = AddressService();
  
  Position? _currentPosition;
  GeoPoint? _selectedLocation;
  GeoPoint? _currentMarker;
  bool _isLoading = true;
  bool _hasLocationError = false;
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize map with a default fallback (e.g. center of the screen) or initial value
    _mapController = MapController.withPosition(
      initPosition: widget.initialLocation != null 
          ? GeoPoint(
              latitude: widget.initialLocation!['lat'], 
              longitude: widget.initialLocation!['lng'],
            )
          : GeoPoint(latitude: 0, longitude: 0),
    );

    if (widget.initialAddress != null) {
      addressCtrl.text = widget.initialAddress!;
    }
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      setState(() => _isLoading = true);
      final position = await LocationService().getCurrentLocation();

      if (!mounted) return;

      if (position != null) {
        setState(() {
          _currentPosition = position;
          _selectedLocation = GeoPoint(latitude: position.latitude, longitude: position.longitude);
          _hasLocationError = false;
          _isLoading = false;
        });
        
        if (_isMapReady) {
          await _mapController.moveTo(_selectedLocation!, animate: true);
          await _mapController.setZoom(zoomLevel: 15);
        }
        _updateAddress();
        _updateMarker();
      } else {
        showErrorAlert(context, 'Could not get location');
        setState(() {
          _hasLocationError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorAlert(context, 'Something went wrong. Please try again.');
      }
      setState(() {
        _hasLocationError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateAddress({bool force = false}) async {
    if (_selectedLocation == null) return;
    final address = await addressService.getAddressFromCoordinates(
      _selectedLocation!.latitude,
      _selectedLocation!.longitude,
    );
    if (!mounted) return;
    setState(() {
      if (address != null && (force || addressCtrl.text.isEmpty)) {
        addressCtrl.text = address;
      }
    });
  }

  Future<void> _updateMarker() async {
    if (_selectedLocation == null) return;
    try {
      if (_currentMarker != null) {
        await _mapController.removeMarker(_currentMarker!);
      }
      await _mapController.addMarker(
        _selectedLocation!,
        markerIcon: const MarkerIcon(
          icon: Icon(
            Icons.location_on,
            color: Colors.red,
            size: 64,
          ),
        ),
      );
      _currentMarker = _selectedLocation;
    } catch (_) {}
  }

  Future<void> _searchAddress() async {
    if (addressCtrl.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final locations = await addressService.getCoordinatesFromAddress(
        addressCtrl.text.trim(),
      );

      if (!mounted) return;

      if (locations.isNotEmpty) {
        final loc = locations.first;
        final lat = loc.latitude;
        final lng = loc.longitude;
        final point = GeoPoint(latitude: lat, longitude: lng);

        setState(() {
          _selectedLocation = point;
        });

        if (_isMapReady) {
          await _mapController.moveTo(point, animate: true);
          await _mapController.setZoom(zoomLevel: 15);
        }
        
        _updateAddress();
        _updateMarker();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address not found')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      showErrorAlert(context, 'Unable to search address. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onMapLongPress(GeoPoint location) async {
    setState(() {
      _selectedLocation = location;
    });
    await _updateMarker();
    await _updateAddress(force: true);
  }

  void _confirmLocation() {
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location')),
      );
      return;
    }

    final result = {
      'address': addressCtrl.text.trim(),
      'location': {
        'lat': _selectedLocation!.latitude,
        'lng': _selectedLocation!.longitude,
      },
    };

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
      ),
      body: _isLoading && _currentPosition == null
          ? const Center(child: CircularProgressIndicator())
          : _hasLocationError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _initializeLocation,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: OSMFlutter(
                        controller: _mapController,
                        osmOption: const OSMOption(
                          userTrackingOption: UserTrackingOption(
                            enableTracking: false,
                            unFollowUser: false,
                          ),
                          zoomOption: ZoomOption(
                            initZoom: 15,
                            minZoomLevel: 3,
                            maxZoomLevel: 19,
                            stepZoom: 1.0,
                          ),
                        ),
                        onMapIsReady: (isReady) async {
                          if (!mounted) return;
                          setState(() => _isMapReady = isReady);
                          if (isReady && _selectedLocation != null) {
                            await _mapController.moveTo(_selectedLocation!, animate: false);
                            await _mapController.setZoom(zoomLevel: 15);
                            await _updateMarker();
                          }
                        },
                        onGeoPointClicked: (geoPoint) {
                          _onMapLongPress(geoPoint);
                        },
                      ),
                    ),
                    // Address Input Panel
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Enter Address or Tap Map to Select',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: addressCtrl,
                                          decoration: InputDecoration(
                                            hintText: 'Search address...',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                          ),
                                          onSubmitted: (_) => _searchAddress(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: _isLoading ? null : _searchAddress,
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Icon(Icons.search),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Confirm Button
                    Positioned(
                      bottom: 20,
                      left: 16,
                      right: 16,
                      child: ElevatedButton.icon(
                        onPressed: _confirmLocation,
                        icon: const Icon(Icons.check),
                        label: const Text('Confirm Location'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _currentPosition != null
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80.0),
              child: FloatingActionButton(
                onPressed: () async {
                  if (!_isMapReady) return;
                  final point = GeoPoint(
                    latitude: _currentPosition!.latitude,
                    longitude: _currentPosition!.longitude,
                  );
                  setState(() {
                    _selectedLocation = point;
                  });
                  await _mapController.moveTo(point, animate: true);
                  await _mapController.setZoom(zoomLevel: 15);
                  await _updateMarker();
                  await _updateAddress(force: true);
                },
                child: const Icon(Icons.my_location),
              ),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    addressCtrl.dispose();
    super.dispose();
  }
}
