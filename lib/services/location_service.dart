import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;

class LocationService {
  static final LocationService _instance = LocationService._internal();

  LocationService._internal();

  factory LocationService() {
    return _instance;
  }

  /// Ensure location service is enabled on device.
  Future<bool> ensureLocationServiceEnabled() async {
    var enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await Geolocator.openLocationSettings();
      enabled = await Geolocator.isLocationServiceEnabled();
    }
    return enabled;
  }

  /// Request location permission from user
  Future<bool> requestLocationPermission() async {
    final serviceEnabled = await ensureLocationServiceEnabled();
    if (!serviceEnabled) return false;

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      return result == LocationPermission.whileInUse ||
          result == LocationPermission.always;
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openLocationSettings();
      return false;
    }
    return true;
  }

  /// Get current user location
  Future<Position?> getCurrentLocation() async {
    try {
      final serviceEnabled = await ensureLocationServiceEnabled();
      if (!serviceEnabled) return null;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final granted = await requestLocationPermission();
        if (!granted) return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      return null;
    }
  }

  /// Calculate distance between two coordinates (in kilometers)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371;

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));

    final c = 2 * math.asin(math.sqrt(a));
    final distance = earthRadiusKm * c;

    return distance;
  }

  static double _toRadians(double degree) {
    return degree * math.pi / 180;
  }
}
