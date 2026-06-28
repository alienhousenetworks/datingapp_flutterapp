import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/constants.dart';
import 'api_client.dart';
import 'device_context_service.dart';

/// STUN probe → POST /call/network-profile/ for admin P2P intelligence.
class NetworkProbeService {
  static bool _done = false;

  static Future<void> runOnce() async {
    if (_done) return;
    _done = true;

    final ctx = await DeviceContextService.instance.getContext(refreshNetwork: true);

    int host = 0;
    int srflx = 0;
    int relay = 0;
    int ipv6Host = 0;
    var hasIpv6 = false;
    final gatherStart = DateTime.now();

    RTCPeerConnection? pc;
    try {
      pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
        'iceCandidatePoolSize': 4,
      });

      final done = Completer<void>();
      pc.onIceCandidate = (RTCIceCandidate? c) {
        if (c?.candidate == null) {
          if (!done.isCompleted) done.complete();
          return;
        }
        final line = c!.candidate!;
        if (line.contains('typ host')) {
          host++;
          if (_isIpv6(line)) {
            ipv6Host++;
            hasIpv6 = true;
          }
        }
        if (line.contains('typ srflx')) srflx++;
        if (line.contains('typ relay')) relay++;
        if (_isIpv6(line)) hasIpv6 = true;
      };

      await pc.createDataChannel('network_probe', RTCDataChannelInit());
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await done.future.timeout(const Duration(seconds: 3), onTimeout: () {});
      await Future<void>.delayed(const Duration(milliseconds: 800));

      final gatherSec =
          DateTime.now().difference(gatherStart).inMilliseconds / 1000.0;

      await ApiClient.instance.post(
        AppConstants.callNetworkProfile,
        data: {
          'ipv4': host > 0 || srflx > 0,
          'ipv6': hasIpv6,
          'has_ipv6': hasIpv6,
          'ipv6_host_candidates': ipv6Host,
          'host_candidates': host,
          'srflx_candidates': srflx,
          'relay_candidates': relay,
          'gathering_time': gatherSec,
          'os': ctx.platform,
          'transport': 'UDP',
          'connection_type': ctx.connectionType,
        },
      );
    } finally {
      await pc?.close();
    }
  }

  static bool _isIpv6(String line) {
    final parts = line.split(' ');
    if (parts.length < 5) return false;
    final addr = parts[4];
    return addr.contains(':') && !addr.contains('.');
  }
}