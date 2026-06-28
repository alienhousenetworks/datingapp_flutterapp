import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/constants.dart';
import 'analytics_service.dart';
import 'api_client.dart';
import 'device_context_service.dart';

/// Collects WebRTC stats during a call and submits to POST /call/metrics/.
class CallTelemetry {
  CallTelemetry();

  final _callStartMs = DateTime.now().millisecondsSinceEpoch;
  int? _iceGatherStartMs;
  int? _iceGatherEndMs;
  int? _iceConnectedMs;
  int? _firstMediaMs;
  int? _offerCreatedMs;
  int? _answerReceivedMs;

  bool _turnFallback = false;
  bool _metricsSubmitted = false;
  int _recoveryAttempts = 0;
  int _iceRestartCount = 0;

  final Map<String, int> _localTypes = {};
  final Map<String, int> _remoteTypes = {};
  final Map<String, int> _localFamilies = {'ipv4': 0, 'ipv6': 0};
  final Map<String, int> _remoteFamilies = {'ipv4': 0, 'ipv6': 0};

  String? _selectedLocalType;
  String? _selectedRemoteType;

  double _rttSum = 0;
  int _rttCount = 0;
  double _maxRtt = 0;
  double _lossSum = 0;
  int _lossCount = 0;
  double _maxLoss = 0;
  double _jitterSum = 0;
  int _jitterCount = 0;
  final List<double> _bitrates = [];

  Timer? _statsTimer;
  RTCPeerConnection? _pc;

  void begin({required String callSessionId}) {
    _activeCallId = callSessionId;
    _iceGatherStartMs = DateTime.now().millisecondsSinceEpoch;
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollStats());
  }

  void bindPeerConnection(RTCPeerConnection pc) => _pc = pc;

  void onLocalIceCandidate(String? candidate) =>
      _recordCandidate(candidate, isLocal: true);

  void onRemoteIceCandidate(String? candidate) =>
      _recordCandidate(candidate, isLocal: false);

  Future<void> onIceConnectionState(RTCIceConnectionState state) async {
    if (state == RTCIceConnectionState.RTCIceConnectionStateConnected &&
        _iceConnectedMs == null) {
      _iceConnectedMs = DateTime.now().millisecondsSinceEpoch - _callStartMs;
      _iceGatherEndMs ??= _iceConnectedMs;
    }
    await _logIceState(state);
  }

  void onPeerConnectionState(RTCPeerConnectionState state) {
    if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
        _firstMediaMs == null) {
      _firstMediaMs = DateTime.now().millisecondsSinceEpoch - _callStartMs;
    }
  }

  void markOfferCreated() {
    _offerCreatedMs = DateTime.now().millisecondsSinceEpoch;
  }

  void markAnswerReceived() {
    _answerReceivedMs = DateTime.now().millisecondsSinceEpoch;
  }

  void recordRemoteCandidate(String? candidate) {
    _recordCandidate(candidate, isLocal: false);
  }

  void markTurnFallback() => _turnFallback = true;

  void _recordCandidate(String? line, {required bool isLocal}) {
    if (line == null || line.isEmpty) return;
    final type = _parseTyp(line);
    final family = _isIpv6(line) ? 'ipv6' : 'ipv4';
    final types = isLocal ? _localTypes : _remoteTypes;
    final families = isLocal ? _localFamilies : _remoteFamilies;
    types[type] = (types[type] ?? 0) + 1;
    families[family] = (families[family] ?? 0) + 1;
    if (type == 'relay') _turnFallback = true;
  }

  Future<void> _logIceState(RTCIceConnectionState state) async {
    final callId = _activeCallId;
    if (callId == null) return;
    try {
      await ApiClient.instance.post(
        AppConstants.callIceState,
        data: {
          'call_session_id': callId,
          'state': state.toString().split('.').last,
          'elapsed_ms': DateTime.now().millisecondsSinceEpoch - _callStartMs,
        },
      );
    } catch (_) {}
  }

  String? _activeCallId;

  Future<void> _pollStats() async {
    final pc = _pc;
    if (pc == null) return;
    try {
      final stats = await pc.getStats();
      for (final report in stats) {
        final type = report.type;
        final v = report.values;
        if (type == 'candidate-pair' && v['selected']?.toString() == 'true') {
          final localId = v['localCandidateId']?.toString();
          final remoteId = v['remoteCandidateId']?.toString();
          for (final r in stats) {
            if (r.id == localId) {
              _selectedLocalType = r.values['candidateType']?.toString();
            }
            if (r.id == remoteId) {
              _selectedRemoteType = r.values['candidateType']?.toString();
            }
          }
          final rtt = double.tryParse(
            v['currentRoundTripTime']?.toString() ?? '',
          );
          if (rtt != null && rtt > 0) {
            _rttSum += rtt * 1000;
            _rttCount++;
            if (rtt * 1000 > _maxRtt) _maxRtt = rtt * 1000;
          }
        }
        if (type == 'inbound-rtp') {
          final loss = int.tryParse(v['packetsLost']?.toString() ?? '');
          final recv = int.tryParse(v['packetsReceived']?.toString() ?? '');
          if (loss != null && recv != null && recv > 0) {
            final ratio = loss / (loss + recv);
            _lossSum += ratio;
            _lossCount++;
            if (ratio > _maxLoss) _maxLoss = ratio;
          }
          final jitter = double.tryParse(v['jitter']?.toString() ?? '');
          if (jitter != null) {
            _jitterSum += jitter * 1000;
            _jitterCount++;
          }
          final br = int.tryParse(v['bytesReceived']?.toString() ?? '');
          if (br != null && br > 0) _bitrates.add(br / 1000.0);
        }
      }
    } catch (_) {}
  }

  Future<void> submit({required String callSessionId}) async {
    if (_metricsSubmitted) return;
    _metricsSubmitted = true;
    _statsTimer?.cancel();

    final establishmentMs = _iceConnectedMs?.toDouble();
    final gatherSec = (_iceGatherEndMs != null && _iceGatherStartMs != null)
        ? (_iceGatherEndMs! - _iceGatherStartMs!) / 1000.0
        : null;

    final avgRtt = _rttCount > 0 ? _rttSum / _rttCount : null;
    final avgLoss = _lossCount > 0 ? _lossSum / _lossCount : null;
    final avgJitter = _jitterCount > 0 ? _jitterSum / _jitterCount : null;
    final avgBitrate = _bitrates.isNotEmpty
        ? _bitrates.reduce((a, b) => a + b) / _bitrates.length
        : null;

    final localType = _selectedLocalType ?? '';
    final remoteType = _selectedRemoteType ?? '';
    final route = '$localType-$remoteType';
    final pathFamily = (_localFamilies['ipv6'] ?? 0) > 0 &&
            (_remoteFamilies['ipv6'] ?? 0) > 0
        ? 'ipv6'
        : 'ipv4';

    final ctx = await DeviceContextService.instance.getContext();

    final payload = {
      'call_session_id': callSessionId,
      'connection_establishment_time': establishmentMs != null
          ? establishmentMs / 1000.0
          : null,
      'ice_gathering_time': gatherSec,
      'ice_completion_time': gatherSec,
      'local_candidate_types': _localTypes,
      'remote_candidate_types': _remoteTypes,
      'local_candidate_families': _localFamilies,
      'remote_candidate_families': _remoteFamilies,
      'selected_local_candidate_type': localType.isEmpty ? null : localType,
      'selected_remote_candidate_type': remoteType.isEmpty ? null : remoteType,
      'p2p_success': !_turnFallback && localType != 'relay' && remoteType != 'relay',
      'turn_fallback_occurrence': _turnFallback,
      'fallback_used': _turnFallback,
      'average_rtt': avgRtt,
      'max_rtt': _maxRtt > 0 ? _maxRtt : null,
      'average_packet_loss': avgLoss,
      'max_packet_loss': _maxLoss > 0 ? _maxLoss : null,
      'average_jitter': avgJitter,
      'average_bitrate_kbps': avgBitrate,
      'recovery_attempts': _recoveryAttempts,
      'connection_type': pathFamily == 'ipv6' ? '$route-ipv6' : route,
      'connection_establishment_ms': establishmentMs,
      'turn_fallback_count': _turnFallback ? 1 : 0,
      'ice_connected_at_ms': _iceConnectedMs,
      'first_media_received_at_ms': _firstMediaMs,
      'offer_to_answer_ms': (_answerReceivedMs != null && _offerCreatedMs != null)
          ? _offerToAnswerMs()
          : null,
      'ice_restart_count': _iceRestartCount,
      'caller_isp': ctx.connectionType,
    };

    try {
      await ApiClient.instance.post(AppConstants.callMetrics, data: payload);
      if (kDebugMode) debugPrint('[CallTelemetry] metrics submitted');
    } catch (e) {
      if (kDebugMode) debugPrint('[CallTelemetry] submit failed: $e');
    }

    final durationSec = ((DateTime.now().millisecondsSinceEpoch - _callStartMs) / 1000)
        .round();
    AnalyticsService.instance.trackCallEnded(
      callId: callSessionId,
      durationSec: durationSec,
    );
  }

  int? _offerToAnswerMs() {
    if (_offerCreatedMs == null || _answerReceivedMs == null) return null;
    return _answerReceivedMs! - _offerCreatedMs!;
  }

  String _parseTyp(String line) {
    final m = RegExp(r'typ (\w+)').firstMatch(line);
    return m?.group(1) ?? 'unknown';
  }

  bool _isIpv6(String line) {
    final parts = line.split(' ');
    if (parts.length < 5) return false;
    final addr = parts[4];
    return addr.contains(':') && !addr.contains('.');
  }

  void dispose() {
    _statsTimer?.cancel();
    _pc = null;
  }
}