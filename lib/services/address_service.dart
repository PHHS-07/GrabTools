import 'package:geocoding/geocoding.dart' as geocoding;
import 'location_service.dart';

class AddressService {
  static final AddressService _instance = AddressService._internal();

  AddressService._internal();

  factory AddressService() {
    return _instance;
  }

  /// Get a readable address from latitude and longitude
  Future<String?> getAddressFromCoordinates(double lat, double lng) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = _buildAddressString(place);
        return address;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get coordinates from an address string
  Future<List<geocoding.Location>> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await geocoding.locationFromAddress(address);
      return locations;
    } catch (e) {
      return [];
    }
  }

  /// Build a readable address from Placemark
  String _buildAddressString(geocoding.Placemark place) {
    final parts = <String>[];
    
    if ((place.street ?? '').isNotEmpty) parts.add(place.street!);
    if ((place.locality ?? '').isNotEmpty) parts.add(place.locality!);
    if ((place.postalCode ?? '').isNotEmpty) parts.add(place.postalCode!);
    if ((place.country ?? '').isNotEmpty) parts.add(place.country!);
    
    return parts.join(', ');
  }

  /// Get current location as an address
  Future<String?> getCurrentLocationAsAddress() async {
    try {
      final position = await LocationService().getCurrentLocation();
      if (position == null) return null;
      return getAddressFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      return null;
    }
  }
}
