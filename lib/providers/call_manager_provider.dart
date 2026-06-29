import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants.dart';
import '../services/analytics_service.dart';
import '../services/api_client.dart';
import '../services/call_telemetry.dart';
import '../services/chat_service.dart';
import 'chat_provider.dart';

enum CallUiState { idle, outgoing, incoming, active, ended }

class IncomingCallInfo {
  final String callId;
  final String callerId;
  final String callerLabel;
  final String callType;

  const IncomingCallInfo({
    required this.callId,
    required this.callerId,
    required this.callerLabel,
    required this.callType,
  });
}

class CallManagerState {
  final CallUiState uiState;
  final IncomingCallInfo? incoming;
  final String? activeCallId;
  final String? callType;
  final String? remoteLabel;
  final String? statusMessage;
  final MediaStream? localStream;
  final MediaStream? remoteStream;

  const CallManagerState({
    this.uiState = CallUiState.idle,
    this.incoming,
    this.activeCallId,
    this.callType,
    this.remoteLabel,
    this.statusMessage,
    this.localStream,
    this.remoteStream,
  });

  CallManagerState copyWith({
    CallUiState? uiState,
    IncomingCallInfo? incoming,
    bool clearIncoming = false,
    String? activeCallId,
    String? callType,
    String? remoteLabel,
    String? statusMessage,
    MediaStream? localStream,
    MediaStream? remoteStream,
    bool clearStreams = false,
  }) =>
      CallManagerState(
        uiState: uiState ?? this.uiState,
        incoming: clearIncoming ? null : (incoming ?? this.incoming),
        activeCallId: activeCallId ?? this.activeCallId,
        callType: callType ?? this.callType,
        remoteLabel: remoteLabel ?? this.remoteLabel,
        statusMessage: statusMessage ?? this.statusMessage,
        localStream: clearStreams ? null : (localStream ?? this.localStream),
        remoteStream: clearStreams ? null : (remoteStream ?? this.remoteStream),
      );
}

class CallManagerNotifier extends StateNotifier<CallManagerState> {
  CallManagerNotifier(this._chatService) : super(const CallManagerState());

  final ChatService _chatService;
  WebSocketChannel? _socket;
  StreamSubscription? _socketSub;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  RTCPeerConnection? _pc;
  CallTelemetry? _telemetry;
  bool _isInitiator = false;
  bool _disposed = false;
  bool _endingCall = false;
  bool _socketReady = false;
  bool _connecting = false;
  Completer<void>? _connectCompleter;
  final List<Map<String, dynamic>> _outgoingQueue = [];
  final List<RTCIceCandidate> _pendingIceCandidates = [];

  String _normalizeCallType(String callType) {
    final normalized = callType.toUpperCase();
    if (normalized == 'VIDEO' || normalized == 'BLIND_DATE') {
      return normalized;
    }
    return 'VOICE';
  }

  bool _needsVideo(String callType) {
    final t = callType.toLowerCase();
    return t == 'video' || t == 'blind_date';
  }
  Future<void> ensureConnected() async {
    if (_socketReady && _socket != null) return;
    if (_connecting && _connectCompleter != null) {
      await _connectCompleter!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {},
      );
      return;
    }
    await _connectSocket();
    if (_connectCompleter != null) {
      await _connectCompleter!.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {},
      );
    }
  }

  Future<void> _connectSocket() async {
    if (_disposed || _connecting) return;

    _connecting = true;
    _socketReady = false;
    _connectCompleter = Completer<void>();
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _socket?.sink.close();
    } catch (_) {}
    _socket = null;

    try {
      final ticket = await _chatService.getWsTicket();
      if (ticket == null || ticket.isEmpty) {
        if (kDebugMode) {
          debugPrint('[CallWS] Missing WS ticket — cannot connect');
        }
        if (!(_connectCompleter?.isCompleted ?? true)) {
          _connectCompleter!.completeError(StateError('missing ws ticket'));
        }
        _scheduleReconnect();
        return;
      }

      final url = '${AppConstants.wsBase}/call/?ticket=$ticket';
      if (kDebugMode) debugPrint('[CallWS] Connecting to $url');

      _socket = WebSocketChannel.connect(Uri.parse(url));
      _socketReady = true;
      _flushOutgoingQueue();

      if (state.uiState != CallUiState.idle &&
          (state.activeCallId != null || state.incoming?.callId != null)) {
        final callId = state.activeCallId ?? state.incoming?.callId;
        if (callId != null) {
          _sendNow({
            'action': 'reconnect_sync',
            'call_id': callId,
            'call_state': state.uiState.name,
          });
        }
      }

      _socketSub = _socket!.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw.toString());
            if (data is Map) {
              unawaited(_onSocketMessage(Map<String, dynamic>.from(data)));
            }
          } catch (e) {
            if (kDebugMode) debugPrint('[CallWS] Parse error: $e');
          }
        },
        onDone: () {
          _markSocketDisconnected();
          _scheduleReconnect();
        },
        onError: (err) {
          if (kDebugMode) debugPrint('[CallWS] Stream error: $err');
          _markSocketDisconnected();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_socketReady) _send({'action': 'heartbeat'});
      });

      if (kDebugMode) debugPrint('[CallWS] Connected');
      if (!(_connectCompleter?.isCompleted ?? true)) {
        _connectCompleter!.complete();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CallWS] Connect failed: $e');
      _markSocketDisconnected();
      if (!(_connectCompleter?.isCompleted ?? true)) {
        _connectCompleter!.completeError(e);
      }
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _markSocketDisconnected() {
    _socketReady = false;
    _socket = null;
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_disposed && !_socketReady) {
        unawaited(_connectSocket());
      }
    });
  }

  void _send(Map<String, dynamic> payload) {
    if (_socketReady && _socket != null) {
      _sendNow(payload);
      return;
    }
    _outgoingQueue.add(payload);
    if (kDebugMode) {
      debugPrint(
        '[CallWS] Queued ${payload['action'] ?? payload['type']} (socket not ready)',
      );
    }
    if (!_connecting) unawaited(ensureConnected());
  }

  void _sendNow(Map<String, dynamic> payload) {
    if (_socket == null) return;
    try {
      _socket!.sink.add(jsonEncode(payload));
      if (kDebugMode) {
        debugPrint('[CallWS] → ${payload['action'] ?? payload['type']}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[CallWS] Send failed: $e');
      _outgoingQueue.add(payload);
      _markSocketDisconnected();
      _scheduleReconnect();
    }
  }

  void _flushOutgoingQueue() {
    if (!_socketReady || _outgoingQueue.isEmpty) return;
    final pending = List<Map<String, dynamic>>.from(_outgoingQueue);
    _outgoingQueue.clear();
    for (final payload in pending) {
      _sendNow(payload);
    }
  }

  Future<bool> _ensurePermissions({required bool needsVideo}) async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) return false;
    if (needsVideo) {
      final cam = await Permission.camera.request();
      if (!cam.isGranted) return false;
    }
    return true;
  }

  Future<List<Map<String, dynamic>>> _iceServers() async {
    try {
      final response = await ApiClient.instance.get(
        AppConstants.callIceServers,
        params: {'force_turn': 'false'},
      );
      final res = response.data;
      if (res is Map && res['iceServers'] is List) {
        return (res['iceServers'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return [
      {'urls': 'stun:stun.l.google.com:19302'},
    ];
  }

  Future<void> startOutgoingCall({
    required String calleeId,
    required String calleeLabel,
    required String callType,
  }) async {
    if (state.uiState != CallUiState.idle) return;

    await ensureConnected();
    if (!_socketReady) {
      state = state.copyWith(
        statusMessage: 'Call service unavailable — reconnecting…',
      );
      return;
    }

    final normalizedType = _normalizeCallType(callType);
    final needsVideo = _needsVideo(normalizedType);
    if (!await _ensurePermissions(needsVideo: needsVideo)) {
      state = state.copyWith(
        statusMessage: 'Microphone/camera permission required',
      );
      return;
    }

    _isInitiator = true;
    _pendingIceCandidates.clear();
    state = state.copyWith(
      uiState: CallUiState.outgoing,
      callType: normalizedType,
      remoteLabel: calleeLabel,
      statusMessage: 'Ringing…',
      clearIncoming: true,
    );

    _telemetry = CallTelemetry();
    await _setupLocalMedia(needsVideo: needsVideo);
    await _ensurePeerConnection();

    if (!_socketReady) {
      state = state.copyWith(
        uiState: CallUiState.idle,
        statusMessage: 'Call socket disconnected. Try again.',
      );
      return;
    }

    _send({
      'action': 'initiate',
      'callee_id': calleeId,
      'call_type': normalizedType,
    });
  }

  Future<void> acceptIncoming() async {
    final incoming = state.incoming;
    if (incoming == null) return;

    await ensureConnected();
    if (!_socketReady) {
      state = state.copyWith(
        statusMessage: 'Call service unavailable — reconnecting…',
      );
      return;
    }

    final normalizedType = _normalizeCallType(incoming.callType);
    final needsVideo = _needsVideo(normalizedType);
    if (!await _ensurePermissions(needsVideo: needsVideo)) return;

    _isInitiator = false;
    _pendingIceCandidates.clear();
    state = state.copyWith(
      uiState: CallUiState.active,
      activeCallId: incoming.callId,
      callType: normalizedType,
      remoteLabel: incoming.callerLabel,
      statusMessage: 'Connecting…',
      clearIncoming: true,
    );

    _telemetry = CallTelemetry()..begin(callSessionId: incoming.callId);
    await _setupLocalMedia(needsVideo: needsVideo);
    await _ensurePeerConnection();

    _send({'action': 'accept', 'call_id': incoming.callId});
  }

  void declineIncoming() {
    final callId = state.incoming?.callId;
    if (callId != null) {
      _send({'action': 'end', 'call_id': callId});
    }
    state = state.copyWith(uiState: CallUiState.idle, clearIncoming: true);
  }

  Future<void> hangUp() async {
    if (_endingCall) return;
    _endingCall = true;
    final callId = state.activeCallId ?? state.incoming?.callId;
    if (callId != null) {
      _send({'action': 'end', 'call_id': callId});
      await _telemetry?.submit(callSessionId: callId);
    }
    await _resetCallState();
    _endingCall = false;
  }

  Future<void> _resetCallState({bool keepSocket = true}) async {
    _pendingIceCandidates.clear();
    await _cleanupMedia(keepSocket: keepSocket);
    state = const CallManagerState(uiState: CallUiState.idle);
  }

  Future<void> _setupLocalMedia({required bool needsVideo}) async {
    await _releaseMediaTracks();
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': needsVideo
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            }
          : false,
    });
    state = state.copyWith(localStream: stream);
  }

  Future<void> _ensurePeerConnection() async {
    if (_pc != null) return;
    final iceServers = await _iceServers();
    _pc = await createPeerConnection({'iceServers': iceServers});

    final local = state.localStream;
    if (local != null) {
      for (final track in local.getTracks()) {
        await _pc!.addTrack(track, local);
      }
    }

    _telemetry?.bindPeerConnection(_pc!);

    _pc!.onIceCandidate = (c) {
      _telemetry?.onLocalIceCandidate(c.candidate);
      if (c.candidate == null) return;
      if (c.candidate!.contains('typ relay')) {
        _telemetry?.markTurnFallback();
      }
      final callId = state.activeCallId;
      if (callId == null) {
        _pendingIceCandidates.add(c);
        return;
      }
      _sendIceCandidate(callId, c);
    };

    _pc!.onIceConnectionState = (iceState) {
      unawaited(_telemetry?.onIceConnectionState(iceState));
    };

    _pc!.onConnectionState = (connState) {
      _telemetry?.onPeerConnectionState(connState);
    };

    _pc!.onTrack = (event) {
      if (event.streams.isEmpty) return;
      state = state.copyWith(
        remoteStream: event.streams.first,
        statusMessage: 'Connected',
        uiState: CallUiState.active,
      );
      final callId = state.activeCallId;
      if (callId != null) {
        _send({'action': 'media_connected', 'call_id': callId});
      }
    };
  }

  Future<void> _onSocketMessage(Map<String, dynamic> data) async {
    final type = data['type']?.toString() ?? data['action']?.toString() ?? '';

    if (type == 'error') {
      final message = data['message']?.toString() ?? 'Call error';
      if (kDebugMode) debugPrint('[CallWS] error: $message');
      await _resetCallState();
      state = CallManagerState(
        uiState: CallUiState.idle,
        statusMessage: message,
      );
      return;
    }

    if (type == 'call.incoming') {
      if (state.uiState != CallUiState.idle) return;
      final incomingType = _normalizeCallType(
        data['call_type']?.toString() ?? 'VOICE',
      );
      state = state.copyWith(
        uiState: CallUiState.incoming,
        incoming: IncomingCallInfo(
          callId: data['call_id']?.toString() ?? '',
          callerId: data['caller_id']?.toString() ?? '',
          callerLabel: data['caller_email']?.toString() ?? 'Someone',
          callType: incomingType,
        ),
      );
      return;
    }

    if (type == 'call.ringing' || type == 'call.initiated') {
      final callId = data['call_id']?.toString();
      if (callId == null || callId.isEmpty) return;
      state = state.copyWith(
        activeCallId: callId,
        statusMessage: 'Ringing…',
      );
      await _flushPendingIce(callId);
      return;
    }

    if (type == 'call.accepted') {
      final callId = data['call_id']?.toString();
      state = state.copyWith(
        uiState: CallUiState.active,
        activeCallId: callId,
        statusMessage: 'Connecting media…',
      );
      if (callId != null) {
        _telemetry ??= CallTelemetry();
        _telemetry!.begin(callSessionId: callId);
        AnalyticsService.instance.trackCallStarted(
          callId: callId,
          callType: state.callType ?? 'VOICE',
        );
        await _flushPendingIce(callId);
      }
      if (_isInitiator && _pc != null && callId != null) {
        final offer = await _pc!.createOffer();
        _telemetry?.markOfferCreated();
        await _pc!.setLocalDescription(offer);
        _send({
          'action': 'offer',
          'call_id': callId,
          'sdp': offer.sdp,
        });
      }
      return;
    }

    if (type == 'offer' && _pc != null) {
      final callId = data['call_id']?.toString();
      if (callId != null) {
        state = state.copyWith(activeCallId: callId, uiState: CallUiState.active);
      }
      await _pc!.setRemoteDescription(
        RTCSessionDescription(
          data['sdp']?.toString(),
          data['type']?.toString() ?? 'offer',
        ),
      );
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      _send({
        'action': 'answer',
        'call_id': state.activeCallId,
        'sdp': answer.sdp,
      });
      return;
    }

    if (type == 'answer' && _pc != null) {
      _telemetry?.markAnswerReceived();
      await _pc!.setRemoteDescription(
        RTCSessionDescription(
          data['sdp']?.toString(),
          data['type']?.toString() ?? 'answer',
        ),
      );
      return;
    }

    if (type == 'ice_candidate' && _pc != null) {
      final candidate = data['candidate'];
      if (candidate == null) return;
      if (candidate is Map) {
        final line = candidate['candidate']?.toString();
        if (line == null || line.isEmpty) return;
        _telemetry?.onRemoteIceCandidate(line);
        await _pc!.addCandidate(
          RTCIceCandidate(
            line,
            candidate['sdpMid']?.toString(),
            (candidate['sdpMLineIndex'] as num?)?.toInt(),
          ),
        );
      }
      return;
    }

    if (type == 'call.connected') {
      state = state.copyWith(
        uiState: CallUiState.active,
        statusMessage: 'Connected',
      );
      return;
    }

    if (type == 'call.ended' || type == 'call_ended') {
      if (_endingCall) return;
      _endingCall = true;
      final callId = state.activeCallId;
      if (callId != null) {
        await _telemetry?.submit(callSessionId: callId);
      }
      await _resetCallState();
      _endingCall = false;
    }
  }

  void _sendIceCandidate(String callId, RTCIceCandidate candidate) {
    final map = candidate.toMap();
    _send({
      'action': 'ice_candidate',
      'call_id': callId,
      'candidate': {
        'candidate': map['candidate'],
        'sdpMid': map['sdpMid'],
        'sdpMLineIndex': map['sdpMLineIndex'],
      },
    });
  }

  Future<void> _flushPendingIce(String callId) async {
    if (_pendingIceCandidates.isEmpty) return;
    final pending = List<RTCIceCandidate>.from(_pendingIceCandidates);
    _pendingIceCandidates.clear();
    for (final candidate in pending) {
      _sendIceCandidate(callId, candidate);
    }
  }

  Future<void> _releaseMediaTracks() async {
    await _pc?.close();
    _pc = null;
    final local = state.localStream;
    if (local != null) {
      for (final t in local.getTracks()) {
        await t.stop();
      }
      await local.dispose();
    }
    final remote = state.remoteStream;
    if (remote != null) {
      for (final t in remote.getTracks()) {
        await t.stop();
      }
      await remote.dispose();
    }
    state = state.copyWith(clearStreams: true);
  }

  Future<void> _cleanupMedia({bool keepSocket = false}) async {
    _telemetry?.dispose();
    _telemetry = null;
    await _pc?.close();
    _pc = null;
    final local = state.localStream;
    if (local != null) {
      for (final t in local.getTracks()) {
        await t.stop();
      }
      await local.dispose();
    }
    final remote = state.remoteStream;
    if (remote != null) {
      for (final t in remote.getTracks()) {
        await t.stop();
      }
      await remote.dispose();
    }
    state = state.copyWith(clearStreams: true);
    if (!keepSocket) {
      _isInitiator = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _socketReady = false;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _socketSub?.cancel();
    try {
      _socket?.sink.close();
    } catch (_) {}
    _socket = null;
    _outgoingQueue.clear();
    _cleanupMedia();
    super.dispose();
  }
}

final callManagerProvider =
    StateNotifierProvider<CallManagerNotifier, CallManagerState>((ref) {
  final notifier = CallManagerNotifier(ref.read(chatServiceProvider));
  notifier.ensureConnected();
  return notifier;
});