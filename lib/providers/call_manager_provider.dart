import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants.dart';
import '../services/analytics_service.dart';
import '../services/api_client.dart';
import '../services/call_telemetry.dart';
import '../services/chat_service.dart';
import 'chat_provider.dart';

enum CallUiState { idle, outgoing, incoming, active, ended }

class CallStartResult {
  final bool success;
  final String? error;

  const CallStartResult({required this.success, this.error});
}

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
  final bool socketConnected;
  final MediaStream? localStream;
  final MediaStream? remoteStream;

  const CallManagerState({
    this.uiState = CallUiState.idle,
    this.incoming,
    this.activeCallId,
    this.callType,
    this.remoteLabel,
    this.statusMessage,
    this.socketConnected = false,
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
    bool? socketConnected,
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
        socketConnected: socketConnected ?? this.socketConnected,
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
  bool _settingUpPeer = false;
  Completer<void>? _connectCompleter;
  final List<Map<String, dynamic>> _outgoingQueue = [];
  final List<RTCIceCandidate> _pendingIceCandidates = [];

  bool _needsVideo(String callType) {
    final t = callType.toLowerCase();
    return t == 'video' || t == 'blind_date';
  }

  String _displayCallType(String callType) {
    final t = callType.toLowerCase();
    if (t == 'video') return 'video';
    if (t == 'blind_date') return 'blind_date';
    return 'voice';
  }

  Future<void> ensureConnected() async {
    if (_socketReady && _socket != null) return;

    if (_connecting && _connectCompleter != null) {
      try {
        await _connectCompleter!.future.timeout(const Duration(seconds: 15));
      } catch (_) {}
      if (_socketReady && _socket != null) return;
    }

    if (!_socketReady && !_connecting) {
      await _connectSocket();
    }
    if (_connectCompleter != null && !(_connectCompleter!.isCompleted)) {
      try {
        await _connectCompleter!.future.timeout(const Duration(seconds: 15));
      } catch (_) {}
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
    state = state.copyWith(socketConnected: false);

    try {
      final ticket = await _chatService.getWsTicket();
      if (ticket == null || ticket.isEmpty) {
        if (kDebugMode) debugPrint('[CallWS] Missing WS ticket');
        if (!(_connectCompleter?.isCompleted ?? true)) {
          _connectCompleter!.completeError(StateError('missing ws ticket'));
        }
        _scheduleReconnect();
        return;
      }

      final url = '${AppConstants.wsBase}/call/?ticket=$ticket';
      if (kDebugMode) debugPrint('[CallWS] Connecting…');

      final ws = await WebSocket.connect(
        url,
        headers: {'Origin': AppConstants.wsOrigin},
      ).timeout(
        const Duration(seconds: 15),
      );
      _socket = IOWebSocketChannel(ws);
      _socketReady = true;
      state = state.copyWith(socketConnected: true);
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
    state = state.copyWith(socketConnected: false);
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

  /// Mirrors web `initiateCall`: connect → media → initiate (no PC yet).
  Future<CallStartResult> startOutgoingCall({
    required String calleeId,
    required String calleeLabel,
    required String callType,
  }) async {
    try {
      if (state.uiState != CallUiState.idle) {
        await _resetCallState();
      }

      await ensureConnected();
      if (!_socketReady) {
        const msg = 'Call service unavailable. Check your connection.';
        state = state.copyWith(statusMessage: msg);
        return const CallStartResult(success: false, error: msg);
      }

      final apiCallType = _displayCallType(callType);
      final needsVideo = _needsVideo(apiCallType);
      if (!await _ensurePermissions(needsVideo: needsVideo)) {
        const msg = 'Microphone/camera permission is required for calls.';
        state = state.copyWith(statusMessage: msg);
        return const CallStartResult(success: false, error: msg);
      }

      _isInitiator = true;
      _pendingIceCandidates.clear();
      _telemetry = CallTelemetry();

      state = state.copyWith(
        uiState: CallUiState.outgoing,
        callType: apiCallType,
        remoteLabel: calleeLabel,
        statusMessage: 'Ringing…',
        clearIncoming: true,
      );

      await _setupLocalMedia(needsVideo: needsVideo);

      if (!_socketReady) {
        await _resetCallState();
        const msg = 'Call socket disconnected. Try again.';
        state = state.copyWith(statusMessage: msg);
        return const CallStartResult(success: false, error: msg);
      }

      _send({
        'action': 'initiate',
        'callee_id': calleeId,
        'call_type': apiCallType,
      });

      return const CallStartResult(success: true);
    } catch (e) {
      if (kDebugMode) debugPrint('[Call] startOutgoingCall failed: $e');
      await _resetCallState();
      final msg = 'Could not start call: $e';
      state = state.copyWith(statusMessage: msg);
      return CallStartResult(success: false, error: msg);
    }
  }

  Future<CallStartResult> acceptIncoming() async {
    try {
      final incoming = state.incoming;
      if (incoming == null) {
        return const CallStartResult(success: false, error: 'No incoming call');
      }

      await ensureConnected();
      if (!_socketReady) {
        const msg = 'Call service unavailable. Check your connection.';
        state = state.copyWith(statusMessage: msg);
        return const CallStartResult(success: false, error: msg);
      }

      final apiCallType = _displayCallType(incoming.callType);
      final needsVideo = _needsVideo(apiCallType);
      if (!await _ensurePermissions(needsVideo: needsVideo)) {
        const msg = 'Microphone/camera permission is required.';
        return const CallStartResult(success: false, error: msg);
      }

      _isInitiator = false;
      _pendingIceCandidates.clear();
      _telemetry = CallTelemetry()..begin(callSessionId: incoming.callId);

      state = state.copyWith(
        uiState: CallUiState.outgoing,
        activeCallId: incoming.callId,
        callType: apiCallType,
        remoteLabel: incoming.callerLabel,
        statusMessage: 'Connecting…',
        clearIncoming: true,
      );

      await _setupLocalMedia(needsVideo: needsVideo);
      _send({'action': 'accept', 'call_id': incoming.callId});

      return const CallStartResult(success: true);
    } catch (e) {
      if (kDebugMode) debugPrint('[Call] acceptIncoming failed: $e');
      await _resetCallState();
      return CallStartResult(success: false, error: 'Could not accept call: $e');
    }
  }

  void declineIncoming() {
    _send({'action': 'end'});
    unawaited(_resetCallState());
  }

  Future<void> hangUp() async {
    if (_endingCall) return;
    _endingCall = true;
    final callId = state.activeCallId ?? state.incoming?.callId;
    _send({'action': 'end'});
    if (callId != null) {
      await _telemetry?.submit(callSessionId: callId);
    }
    await _resetCallState();
    _endingCall = false;
  }

  Future<void> _resetCallState({bool keepSocket = true}) async {
    _pendingIceCandidates.clear();
    _settingUpPeer = false;
    await _cleanupMedia(keepSocket: keepSocket);
    state = CallManagerState(
      uiState: CallUiState.idle,
      socketConnected: state.socketConnected,
    );
  }

  Future<void> _setupLocalMedia({required bool needsVideo}) async {
    await _releaseMediaTracks(keepPc: true);
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

  Future<void> _setupPeerConnectionIfNeeded() async {
    if (_pc != null || _settingUpPeer) return;
    _settingUpPeer = true;
    try {
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

      if (_isInitiator && state.activeCallId != null) {
        final offer = await _pc!.createOffer();
        _telemetry?.markOfferCreated();
        await _pc!.setLocalDescription(offer);
        _send({
          'action': 'offer',
          'call_id': state.activeCallId,
          'sdp': offer.sdp,
        });
      }
    } finally {
      _settingUpPeer = false;
    }
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
        socketConnected: state.socketConnected,
      );
      return;
    }

    if (type == 'call.incoming') {
      if (state.uiState != CallUiState.idle) {
        if (kDebugMode) {
          debugPrint('[CallWS] Ignoring incoming — state=${state.uiState}');
        }
        return;
      }
      final incomingType = _displayCallType(
        data['call_type']?.toString() ?? 'voice',
      );
      state = state.copyWith(
        uiState: CallUiState.incoming,
        incoming: IncomingCallInfo(
          callId: data['call_id']?.toString() ?? '',
          callerId: data['caller_id']?.toString() ?? '',
          callerLabel: data['caller_email']?.toString() ?? 'Someone',
          callType: incomingType,
        ),
        statusMessage: 'Incoming call',
      );
      if (kDebugMode) debugPrint('[CallWS] ← call.incoming');
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
          callType: state.callType ?? 'voice',
        );
        await _flushPendingIce(callId);
      }
      await _setupPeerConnectionIfNeeded();
      return;
    }

    if (type == 'offer') {
      final callId = data['call_id']?.toString();
      if (callId != null) {
        state = state.copyWith(activeCallId: callId, uiState: CallUiState.active);
      }
      await _setupPeerConnectionIfNeeded();
      if (_pc == null) return;
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

  Future<void> _releaseMediaTracks({bool keepPc = false}) async {
    if (!keepPc) {
      await _pc?.close();
      _pc = null;
    }
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
    await _releaseMediaTracks();
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