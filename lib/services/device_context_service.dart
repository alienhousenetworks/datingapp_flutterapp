import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';

/// Cached device + network context attached to every analytics event.
class DeviceContext {
  final String platform;
  final String deviceType;
  final String osVersion;
  final String appVersion;
  final String connectionType;
  final String? manufacturer;
  final String? model;

  const DeviceContext({
    this.platform = 'unknown',
    this.deviceType = 'unknown',
    this.osVersion = '',
    this.appVersion = AppConstants.appVersion,
    this.connectionType = '',
    this.manufacturer,
    this.model,
  });

  Map<String, String> get analyticsHeaders => {
        'X-App-Version': appVersion,
        'X-Platform': platform,
        'X-Device-Type': deviceType,
        if (connectionType.isNotEmpty) 'X-Connection-Type': connectionType,
      };
}

class DeviceContextService {
  DeviceContextService._();
  static final DeviceContextService instance = DeviceContextService._();

  DeviceContext? _cached;

  DeviceContext? get cached => _cached;

  Future<DeviceContext> getContext({bool refreshNetwork = false}) async {
    if (_cached != null && !refreshNetwork) return _cached!;

    String platform = 'unknown';
    String deviceType = 'unknown';
    String osVersion = '';
    String? manufacturer;
    String? model;

    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        platform = 'web';
        deviceType = 'WEB';
      } else if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        platform = 'android';
        deviceType = 'ANDROID';
        osVersion = info.version.release;
        manufacturer = info.manufacturer;
        model = info.model;
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        platform = 'ios';
        deviceType = 'IOS';
        osVersion = info.systemVersion;
        manufacturer = 'Apple';
        model = info.utsname.machine;
      }
    } catch (_) {}

    String connectionType = _cached?.connectionType ?? '';
    if (refreshNetwork || connectionType.isEmpty) {
      connectionType = await _resolveConnectionType();
    }

    _cached = DeviceContext(
      platform: platform,
      deviceType: deviceType,
      osVersion: osVersion,
      appVersion: AppConstants.appVersion,
      connectionType: connectionType,
      manufacturer: manufacturer,
      model: model,
    );
    return _cached!;
  }

  Future<String> _resolveConnectionType() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (results.contains(ConnectivityResult.wifi)) return 'wifi';
      if (results.contains(ConnectivityResult.mobile)) return 'cellular';
      if (results.contains(ConnectivityResult.ethernet)) return 'ethernet';
      if (results.contains(ConnectivityResult.vpn)) return 'vpn';
    } catch (_) {}
    return 'unknown';
  }
}