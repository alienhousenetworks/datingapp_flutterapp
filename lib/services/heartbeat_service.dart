import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import 'analytics_service.dart';
import 'api_client.dart';
import 'device_context_service.dart';
import 'location_context.dart';
import 'location_service.dart';
import 'network_probe_service.dart';

/// Keeps DAU/MAU accurate: POST /users/last-active/ + geo headers on all API calls.
class HeartbeatService {
  HeartbeatService._();
  static final HeartbeatService instance = HeartbeatService._();

  final _locationService = LocationService();
  Timer? _timer;
  bool _running = false;

  Future<void> start() async {
    if (_running) return;
    _running = true;
    AnalyticsService.instance.startSession();
    await _ping();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _ping());
    unawaited(NetworkProbeService.runOnce());
  }

  Future<void> stop() async {
    _running = false;
    _timer?.cancel();
    _timer = null;
    await AnalyticsService.instance.endSession();
  }

  Future<void> _ping() async {
    try {
      var lat = LocationContext.instance.latitude;
      var lon = LocationContext.instance.longitude;

      if (lat == null || lon == null) {
        final result = await _locationService.getCurrentLocation();
        if (result.location != null) {
          lat = result.location!.latitude;
          lon = result.location!.longitude;
          LocationContext.instance.update(lat: lat, lon: lon);
        }
      }

      if (lat == null || lon == null) return;

      await ApiClient.instance.post(
        AppConstants.usersLastActive,
        data: {'lat': lat, 'lon': lon},
      );
      await DeviceContextService.instance.getContext(refreshNetwork: true);
    } catch (e) {
      if (kDebugMode) debugPrint('[Heartbeat] ping failed: $e');
    }
  }
}