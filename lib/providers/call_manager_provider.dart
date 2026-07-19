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
  final bool isMuted;
  final bool isVideoOff;

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
    this.isMuted = false,
    this.isVideoOff = false,
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
    bool? isMuted,
    bool? isVideoOff,
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
        isMuted: isMuted ?? this.isMuted,
        isVideoOff: isVideoOff ?? this.isVideoOff,
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
  /// Local candidates gathered before callId is known.
  final List<RTCIceCandidate> _pendingLocalIceCandidates = [];
  /// Remote candidates that arrived before remote description / PC ready.
  final List<RTCIceCandidate> _pendingRemoteIceCandidates = [];
  bool _remoteDescriptionSet = false;
  bool _iceConnected = false;
  bool _turnEscalated = false;
  bool _iceRestartInFlight = false;
  int _recoveryCycles = 0;
  int _delayedTurnMs = 3500;
  Timer? _turnEscalateTimer;
  Timer? _iceWatchdogTimer;
  List<Map<String, dynamic>> _cachedFullIceServers = const [];
  static const int _maxRecoveryCycles = 2;
  static const int _defaultIcePoolSize = 8;

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

  /// Build RTCConfiguration optimized for P2P.
  /// [stunOnly] omits TURN so host/srflx connectivity checks run first.
  Future<Map<String, dynamic>> _iceConfig({bool stunOnly = false}) async {
    List<Map<String, dynamic>> servers = [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
    ];
    var poolSize = _defaultIcePoolSize;
    var transportPolicy = 'all';

    try {
      final response = await ApiClient.instance.get(
        AppConstants.callIceServers,
        params: {
          'force_turn': 'false',
          if (stunOnly) 'stun_only': 'true',
        },
      );
      final res = response.data;
      if (res is Map) {
        if (res['iceServers'] is List) {
          final mapped = (res['iceServers'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (mapped.isNotEmpty) servers = mapped;
        }
        poolSize = (res['iceCandidatePoolSize'] as num?)?.toInt() ??
            _defaultIcePoolSize;
        // Cap pool — large values over-gather relay and slow P2P checks.
        if (poolSize > 12) poolSize = 8;
        if (res['iceTransportPolicy'] != null) {
          transportPolicy = res['iceTransportPolicy'].toString();
        }
        final delayed = (res['delayed_turn_ms'] as num?)?.toInt();
        if (delayed != null && delayed >= 0) {
          _delayedTurnMs = delayed;
        }
        if (!stunOnly) {
          _cachedFullIceServers = servers;
        } else if (_cachedFullIceServers.isEmpty) {
          // Warm full config (with TURN) in background for later escalate.
          unawaited(_prefetchFullIceServers());
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Call][ICE] config fetch failed: $e');
    }

    if (stunOnly) {
      servers = _filterStunOnly(servers);
      transportPolicy = 'all';
    }

    return _buildRtcConfiguration(
      servers: servers,
      poolSize: poolSize,
      transportPolicy: transportPolicy,
    );
  }

  Future<void> _prefetchFullIceServers() async {
    try {
      final response = await ApiClient.instance.get(
        AppConstants.callIceServers,
        params: {'force_turn': 'false'},
      );
      final res = response.data;
      if (res is Map && res['iceServers'] is List) {
        _cachedFullIceServers = (res['iceServers'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        final delayed = (res['delayed_turn_ms'] as num?)?.toInt();
        if (delayed != null && delayed >= 0) _delayedTurnMs = delayed;
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> _filterStunOnly(List<Map<String, dynamic>> servers) {
    final out = <Map<String, dynamic>>[];
    for (final s in servers) {
      final urlsRaw = s['urls'];
      final urls = urlsRaw is List
          ? urlsRaw.map((e) => e.toString()).toList()
          : [urlsRaw?.toString() ?? ''];
      final stun = urls
          .where((u) => u.startsWith('stun:') || u.startsWith('stuns:'))
          .toList();
      if (stun.isEmpty) continue;
      final entry = <String, dynamic>{
        'urls': stun.length == 1 ? stun.first : stun,
      };
      out.add(entry);
    }
    if (out.isEmpty) {
      return [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ];
    }
    return out;
  }

  Map<String, dynamic> _buildRtcConfiguration({
    required List<Map<String, dynamic>> servers,
    required int poolSize,
    required String transportPolicy,
  }) {
    return {
      'iceServers': servers,
      'iceTransportPolicy': transportPolicy,
      // Small pool favors quick host/srflx before relay allocation.
      'iceCandidatePoolSize': poolSize.clamp(0, 12),
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'sdpSemantics': 'unified-plan',
      // Keep gathering so late srflx/IPv6 still appear.
      'continualGatheringPolicy': 'gather_continually',
    };
  }

  int _candidateSendPriority(String? line) {
    if (line == null) return 0;
    if (line.contains('typ host')) return 100;
    if (line.contains('typ prflx')) return 80;
    if (line.contains('typ srflx')) return 60;
    if (line.contains('typ relay')) return 10;
    return 20;
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
      _resetIceNegotiationFlags();
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
      _resetIceNegotiationFlags();
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

  void toggleMute() {
    final local = state.localStream;
    if (local != null) {
      final muted = !state.isMuted;
      for (final track in local.getAudioTracks()) {
        track.enabled = !muted;
      }
      state = state.copyWith(isMuted: muted);
    }
  }

  void toggleVideo() {
    final local = state.localStream;
    if (local != null) {
      final videoOff = !state.isVideoOff;
      for (final track in local.getVideoTracks()) {
        track.enabled = !videoOff;
      }
      state = state.copyWith(isVideoOff: videoOff);
    }
  }

  void _resetIceNegotiationFlags() {
    _pendingLocalIceCandidates.clear();
    _pendingRemoteIceCandidates.clear();
    _remoteDescriptionSet = false;
    _iceConnected = false;
    _turnEscalated = false;
    _iceRestartInFlight = false;
    _recoveryCycles = 0;
    _turnEscalateTimer?.cancel();
    _turnEscalateTimer = null;
    _iceWatchdogTimer?.cancel();
    _iceWatchdogTimer = null;
  }

  Future<void> _resetCallState({bool keepSocket = true}) async {
    _resetIceNegotiationFlags();
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
      // P2P-first: STUN only initially so host/srflx checks win before relay.
      // TURN is injected after delayed_turn_ms if still not connected.
      final useP2pFirst = _delayedTurnMs > 0;
      final iceConfig = await _iceConfig(stunOnly: useP2pFirst);
      if (kDebugMode) {
        debugPrint(
          '[Call][ICE] PC create p2pFirst=$useP2pFirst '
          'delayedTurnMs=$_delayedTurnMs servers=${(iceConfig['iceServers'] as List?)?.length}',
        );
      }
      _pc = await createPeerConnection(iceConfig);

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
        final callId = state.activeCallId;
        if (callId == null) {
          _pendingLocalIceCandidates.add(c);
          return;
        }
        _sendIceCandidate(callId, c);
      };

      _pc!.onIceConnectionState = (iceState) {
        unawaited(_onIceConnectionState(iceState));
      };

      _pc!.onConnectionState = (connState) {
        _telemetry?.onPeerConnectionState(connState);
        if (connState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _iceConnected = true;
          _turnEscalateTimer?.cancel();
          _iceWatchdogTimer?.cancel();
        } else if (connState ==
            RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
          unawaited(_attemptIceRecovery('connection_failed'));
        }
      };

      _pc!.onTrack = (event) {
        if (event.streams.isEmpty) return;
        _iceConnected = true;
        _turnEscalateTimer?.cancel();
        _iceWatchdogTimer?.cancel();
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

      // Drain any remote candidates that arrived before PC existed.
      await _flushPendingRemoteIce();

      if (_isInitiator && state.activeCallId != null) {
        final needsVideo = _needsVideo(state.callType ?? 'voice');
        final offer = await _pc!.createOffer({
          'offerToReceiveAudio': true,
          'offerToReceiveVideo': needsVideo,
        });
        _telemetry?.markOfferCreated();
        await _pc!.setLocalDescription(offer);
        _send({
          'action': 'offer',
          'call_id': state.activeCallId,
          'sdp': offer.sdp,
          'type': 'offer',
        });
      }

      _scheduleTurnEscalation();
      _startIceWatchdog();
    } finally {
      _settingUpPeer = false;
    }
  }

  Future<void> _onIceConnectionState(RTCIceConnectionState iceState) async {
    await _telemetry?.onIceConnectionState(iceState);
    if (iceState == RTCIceConnectionState.RTCIceConnectionStateConnected ||
        iceState == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
      _iceConnected = true;
      _turnEscalateTimer?.cancel();
      _iceWatchdogTimer?.cancel();
      if (kDebugMode) debugPrint('[Call][ICE] connected/completed');
    } else if (iceState == RTCIceConnectionState.RTCIceConnectionStateFailed) {
      unawaited(_attemptIceRecovery('ice_failed'));
    } else if (iceState ==
        RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
      // Brief grace — mobile networks often flap; don't escalate instantly.
      Future<void>.delayed(const Duration(seconds: 4), () {
        if (_disposed || _iceConnected || _pc == null) return;
        final s = _pc?.iceConnectionState;
        if (s == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            s == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          unawaited(_attemptIceRecovery('ice_disconnected'));
        }
      });
    }
  }

  void _scheduleTurnEscalation() {
    _turnEscalateTimer?.cancel();
    if (_turnEscalated || _delayedTurnMs <= 0) {
      // Already full config or TURN required immediately.
      if (!_turnEscalated && _delayedTurnMs <= 0) {
        unawaited(_escalateToTurn(reason: 'immediate'));
      }
      return;
    }
    _turnEscalateTimer = Timer(Duration(milliseconds: _delayedTurnMs), () {
      if (_disposed || _iceConnected || _pc == null) return;
      unawaited(_escalateToTurn(reason: 'delayed_p2p_window'));
    });
  }

  void _startIceWatchdog() {
    _iceWatchdogTimer?.cancel();
    // Overall connect budget: delayed TURN + ~12s for relay path.
    final budgetMs = (_delayedTurnMs > 0 ? _delayedTurnMs : 0) + 14000;
    _iceWatchdogTimer = Timer(Duration(milliseconds: budgetMs), () {
      if (_disposed || _iceConnected || _pc == null) return;
      unawaited(_attemptIceRecovery('watchdog_timeout'));
    });
  }

  Future<void> _escalateToTurn({required String reason}) async {
    if (_turnEscalated || _pc == null || _iceConnected) return;
    _turnEscalated = true;
    _telemetry?.markTurnFallback();
    if (kDebugMode) debugPrint('[Call][ICE] escalate TURN reason=$reason');

    try {
      List<Map<String, dynamic>> servers = _cachedFullIceServers;
      if (servers.isEmpty) {
        final full = await _iceConfig(stunOnly: false);
        servers = (full['iceServers'] as List?)
                ?.whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            [];
      }
      if (servers.isEmpty) return;

      final config = _buildRtcConfiguration(
        servers: servers,
        poolSize: _defaultIcePoolSize,
        transportPolicy: 'all',
      );
      await _pc!.setConfiguration(config);

      // Restart ICE so new relay candidates are gathered & paired.
      if (_isInitiator && state.activeCallId != null) {
        await _sendIceRestartOffer(reason: reason);
      } else {
        // Callee: request restart; also restartIce if available.
        try {
          await _pc!.restartIce();
        } catch (_) {}
        _send({
          'action': 'ice_restart_request',
          'call_id': state.activeCallId,
          'reason': reason,
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Call][ICE] TURN escalate failed: $e');
    }
  }

  Future<void> _sendIceRestartOffer({required String reason}) async {
    if (_pc == null || _iceRestartInFlight) return;
    _iceRestartInFlight = true;
    try {
      final needsVideo = _needsVideo(state.callType ?? 'voice');
      final offer = await _pc!.createOffer({
        'iceRestart': true,
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': needsVideo,
      });
      _telemetry?.markOfferCreated();
      await _pc!.setLocalDescription(offer);
      // Keep remote description; ICE restart reuses the prior remote SDP
      // until the new answer lands (avoids dropping in-flight candidates).
      _send({
        'action': 'offer',
        'call_id': state.activeCallId,
        'sdp': offer.sdp,
        'type': 'offer',
        'ice_restart': true,
        'reason': reason,
      });
      if (kDebugMode) debugPrint('[Call][ICE] iceRestart offer sent ($reason)');
    } catch (e) {
      if (kDebugMode) debugPrint('[Call][ICE] iceRestart offer failed: $e');
    } finally {
      _iceRestartInFlight = false;
    }
  }

  Future<void> _attemptIceRecovery(String reason) async {
    if (_disposed || _iceConnected || _pc == null) return;
    if (_recoveryCycles >= _maxRecoveryCycles) {
      if (kDebugMode) {
        debugPrint('[Call][ICE] recovery exhausted reason=$reason');
      }
      state = state.copyWith(
        statusMessage: 'Connection unstable — try again on Wi‑Fi',
      );
      return;
    }
    _recoveryCycles++;
    if (kDebugMode) {
      debugPrint(
        '[Call][ICE] recovery #$_recoveryCycles reason=$reason',
      );
    }
    state = state.copyWith(statusMessage: 'Reconnecting…');
    if (!_turnEscalated) {
      await _escalateToTurn(reason: reason);
    } else if (_isInitiator) {
      await _sendIceRestartOffer(reason: reason);
    } else {
      try {
        await _pc?.restartIce();
      } catch (_) {}
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
      final sdpType = data['sdp_type']?.toString() ?? 'offer';
      await _pc!.setRemoteDescription(
        RTCSessionDescription(data['sdp']?.toString(), sdpType),
      );
      _remoteDescriptionSet = true;
      await _flushPendingRemoteIce();
      final answer = await _pc!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': _needsVideo(state.callType ?? 'voice'),
      });
      await _pc!.setLocalDescription(answer);
      _send({
        'action': 'answer',
        'call_id': state.activeCallId,
        'sdp': answer.sdp,
        'type': 'answer',
      });
      return;
    }

    if (type == 'answer' && _pc != null) {
      _telemetry?.markAnswerReceived();
      final sdpType = data['sdp_type']?.toString() ?? 'answer';
      await _pc!.setRemoteDescription(
        RTCSessionDescription(data['sdp']?.toString(), sdpType),
      );
      _remoteDescriptionSet = true;
      await _flushPendingRemoteIce();
      return;
    }

    if (type == 'ice_candidate') {
      await _handleRemoteIceCandidate(data);
      return;
    }

    if (type == 'ice_restart_approved' || type == 'ice_restart_pending') {
      if (type == 'ice_restart_approved' && _isInitiator) {
        await _sendIceRestartOffer(reason: 'coordinated_restart');
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
    final line = map['candidate']?.toString();
    // Prefer sending host/srflx immediately; still send relay (needed as backup).
    _send({
      'action': 'ice_candidate',
      'call_id': callId,
      'priority_score': _candidateSendPriority(line),
      'candidate': {
        'candidate': map['candidate'],
        'sdpMid': map['sdpMid'],
        'sdpMLineIndex': map['sdpMLineIndex'],
      },
    });
  }

  Future<void> _handleRemoteIceCandidate(Map<String, dynamic> data) async {
    final candidate = data['candidate'];
    if (candidate is! Map) return;
    final line = candidate['candidate']?.toString();
    if (line == null || line.isEmpty) return;

    final ice = RTCIceCandidate(
      line,
      candidate['sdpMid']?.toString(),
      (candidate['sdpMLineIndex'] as num?)?.toInt(),
    );
    _telemetry?.onRemoteIceCandidate(line);

    // Queue until PC exists AND remote description is applied — otherwise
    // candidates are dropped and P2P checks never complete → forced TURN.
    if (_pc == null || !_remoteDescriptionSet) {
      _pendingRemoteIceCandidates.add(ice);
      return;
    }
    try {
      await _pc!.addCandidate(ice);
    } catch (e) {
      if (kDebugMode) debugPrint('[Call][ICE] addCandidate failed: $e');
      _pendingRemoteIceCandidates.add(ice);
    }
  }

  Future<void> _flushPendingRemoteIce() async {
    if (_pc == null || !_remoteDescriptionSet) return;
    if (_pendingRemoteIceCandidates.isEmpty) return;

    // Apply host/srflx before relay so P2P pairs form first.
    final pending = List<RTCIceCandidate>.from(_pendingRemoteIceCandidates)
      ..sort(
        (a, b) => _candidateSendPriority(b.candidate)
            .compareTo(_candidateSendPriority(a.candidate)),
      );
    _pendingRemoteIceCandidates.clear();
    for (final candidate in pending) {
      try {
        await _pc!.addCandidate(candidate);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[Call][ICE] flush remote candidate failed: $e');
        }
      }
    }
  }

  Future<void> _flushPendingIce(String callId) async {
    if (_pendingLocalIceCandidates.isEmpty) return;
    final pending = List<RTCIceCandidate>.from(_pendingLocalIceCandidates)
      ..sort(
        (a, b) => _candidateSendPriority(b.candidate)
            .compareTo(_candidateSendPriority(a.candidate)),
      );
    _pendingLocalIceCandidates.clear();
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