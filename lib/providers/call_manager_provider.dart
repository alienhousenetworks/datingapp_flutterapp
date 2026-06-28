import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants.dart';
import '../services/api_client.dart';
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
  bool _isInitiator = false;
  bool _disposed = false;
  Future<void> ensureConnected() async {
    if (_socket != null) return;
    await _connectSocket();
  }

  Future<void> _connectSocket() async {
    if (_disposed) return;
    await _socketSub?.cancel();
    try {
      await _socket?.sink.close();
    } catch (_) {}

    final ticket = await _chatService.getWsTicket();
    if (ticket == null || ticket.isEmpty) {
      _scheduleReconnect();
      return;
    }

    try {
      final url = '${AppConstants.wsBase}/call/?ticket=$ticket';
      _socket = WebSocketChannel.connect(Uri.parse(url));
      _socketSub = _socket!.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw.toString());
            if (data is Map) {
              unawaited(_onSocketMessage(Map<String, dynamic>.from(data)));
            }
          } catch (_) {}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect,
        cancelOnError: true,
      );
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _send({'action': 'heartbeat'});
      });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _connectSocket);
  }

  void _send(Map<String, dynamic> payload) {
    if (_socket == null) return;
    try {
      _socket!.sink.add(jsonEncode(payload));
    } catch (_) {}
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
        params: {'force_turn': 'false', 'stun_only': 'true'},
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
    await ensureConnected();
    final needsVideo = callType == 'video';
    if (!await _ensurePermissions(needsVideo: needsVideo)) {
      state = state.copyWith(
        statusMessage: 'Microphone/camera permission required',
      );
      return;
    }

    _isInitiator = true;
    state = state.copyWith(
      uiState: CallUiState.outgoing,
      callType: callType,
      remoteLabel: calleeLabel,
      statusMessage: 'Ringing…',
      clearIncoming: true,
    );

    await _setupLocalMedia(needsVideo: needsVideo);
    await _ensurePeerConnection();

    _send({
      'action': 'initiate',
      'callee_id': calleeId,
      'call_type': callType,
    });
  }

  Future<void> acceptIncoming() async {
    final incoming = state.incoming;
    if (incoming == null) return;

    final needsVideo =
        incoming.callType == 'video' || incoming.callType == 'blind_date';
    if (!await _ensurePermissions(needsVideo: needsVideo)) return;

    _isInitiator = false;
    state = state.copyWith(
      uiState: CallUiState.active,
      activeCallId: incoming.callId,
      callType: incoming.callType,
      remoteLabel: incoming.callerLabel,
      statusMessage: 'Connecting…',
      clearIncoming: true,
    );

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
    final callId = state.activeCallId ?? state.incoming?.callId;
    if (callId != null) {
      _send({'action': 'end', 'call_id': callId});
    }
    await _cleanupMedia();
    state = const CallManagerState(uiState: CallUiState.idle);
  }

  Future<void> _setupLocalMedia({required bool needsVideo}) async {
    await _cleanupMedia(keepSocket: true);
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

    _pc!.onIceCandidate = (c) {
      final callId = state.activeCallId;
      if (c.candidate == null || callId == null) return;
      _send({
        'action': 'ice_candidate',
        'call_id': callId,
        'candidate': c.toMap(),
      });
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
      state = state.copyWith(
        statusMessage: data['message']?.toString() ?? 'Call error',
      );
      return;
    }

    if (type == 'call.incoming') {
      if (state.uiState != CallUiState.idle) return;
      state = state.copyWith(
        uiState: CallUiState.incoming,
        incoming: IncomingCallInfo(
          callId: data['call_id']?.toString() ?? '',
          callerId: data['caller_id']?.toString() ?? '',
          callerLabel: data['caller_email']?.toString() ?? 'Someone',
          callType: data['call_type']?.toString() ?? 'voice',
        ),
      );
      return;
    }

    if (type == 'call.accepted') {
      final callId = data['call_id']?.toString();
      state = state.copyWith(
        uiState: CallUiState.active,
        activeCallId: callId,
        statusMessage: 'Connecting media…',
      );
      if (_isInitiator && _pc != null && callId != null) {
        final offer = await _pc!.createOffer();
        await _pc!.setLocalDescription(offer);
        _send({
          'action': 'offer',
          'call_id': callId,
          'sdp': offer.sdp,
          'type': offer.type,
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
        RTCSessionDescription(data['sdp']?.toString(), data['type']?.toString()),
      );
      final answer = await _pc!.createAnswer();
      await _pc!.setLocalDescription(answer);
      _send({
        'action': 'answer',
        'call_id': state.activeCallId,
        'sdp': answer.sdp,
        'type': answer.type,
      });
      return;
    }

    if (type == 'answer' && _pc != null) {
      await _pc!.setRemoteDescription(
        RTCSessionDescription(data['sdp']?.toString(), data['type']?.toString()),
      );
      return;
    }

    if (type == 'ice_candidate' && _pc != null) {
      final candidate = data['candidate'];
      if (candidate is Map) {
        await _pc!.addCandidate(
          RTCIceCandidate(
            candidate['candidate']?.toString(),
            candidate['sdpMid']?.toString(),
            candidate['sdpMLineIndex'] as int?,
          ),
        );
      }
      return;
    }

    if (type == 'call.ended' || type == 'call_ended') {
      await hangUp();
    }
  }

  Future<void> _cleanupMedia({bool keepSocket = false}) async {
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
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _socketSub?.cancel();
    try {
      _socket?.sink.close();
    } catch (_) {}
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