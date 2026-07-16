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
  /// Falls back to last-known position when CoreLocation returns
  /// kCLErrorLocationUnknown (common on simulator / cold GPS).
  Future<({DeviceLocation? location, String? error})> getCurrentLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        final last = await _lastKnownOrNull();
        if (last != null) {
          return (location: last, error: null);
        }
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

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 12),
          ),
        );
        return (location: _fromPosition(position), error: null);
      } catch (_) {
        // kCLErrorLocationUnknown / timeout — use last known fix if any
        final last = await _lastKnownOrNull();
        if (last != null) {
          return (location: last, error: null);
        }
        return (
          location: null,
          error:
              'Could not determine location yet. Move near a window or try again.',
        );
      }
    } catch (e) {
      final last = await _lastKnownOrNull();
      if (last != null) {
        return (location: last, error: null);
      }
      return (location: null, error: 'Could not get location: $e');
    }
  }

  Future<DeviceLocation?> _lastKnownOrNull() async {
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos == null) return null;
      return _fromPosition(pos);
    } catch (_) {
      return null;
    }
  }

  DeviceLocation _fromPosition(Position position) {
    return DeviceLocation(
      latitude: double.parse(position.latitude.toStringAsFixed(6)),
      longitude: double.parse(position.longitude.toStringAsFixed(6)),
    );
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
