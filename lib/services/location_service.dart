import 'package:geolocator/geolocator.dart';

class DeviceLocation {
  final double latitude;
  final double longitude;

  const DeviceLocation({
    required this.latitude,
    required this.longitude,
  });
}

class LocationService {
  /// Returns the current GPS position, requesting permission when needed.
  Future<({DeviceLocation? location, String? error})> getCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return (
          location: null,
          error: 'Location services are turned off. Enable them in Settings.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return (
          location: null,
          error: 'Location permission denied. Allow access in Settings.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return (
          location: null,
          error: 'Location permission permanently denied. Enable in Settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      return (
        location: DeviceLocation(
          latitude: double.parse(position.latitude.toStringAsFixed(6)),
          longitude: double.parse(position.longitude.toStringAsFixed(6)),
        ),
        error: null,
      );
    } catch (e) {
      return (location: null, error: 'Could not get location: $e');
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}