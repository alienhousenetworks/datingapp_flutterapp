import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants.dart';

typedef ChatWsMessageHandler = void Function(Map<String, dynamic> data);

/// Real-time chat socket — mirrors web ChatWindow.jsx WebSocket flow.
class ChatWebSocket {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _disposed = false;

  String? _conversationId;
  ChatWsMessageHandler? _onMessage;
  Future<String?> Function()? _ticketProvider;

  bool get isConnected =>
      _channel != null && _channel!.closeCode == null;

  Future<void> connect({
    required String conversationId,
    required Future<String?> Function() ticketProvider,
    required ChatWsMessageHandler onMessage,
  }) async {
    _disposed = false;
    _conversationId = conversationId;
    _ticketProvider = ticketProvider;
    _onMessage = onMessage;
    await _openSocket(isReconnect: false);
  }

  Future<void> _openSocket({required bool isReconnect}) async {
    if (_disposed || _conversationId == null || _ticketProvider == null) return;

    await disconnect(clearHandlers: false);

    final ticket = await _ticketProvider!();
    if (ticket == null || ticket.isEmpty || _disposed) return;

    final url =
        '${AppConstants.wsBase}/chat/$_conversationId/?ticket=$ticket';

    try {
      _channel = IOWebSocketChannel.connect(
        url,
        headers: {'Origin': AppConstants.wsOrigin},
        connectTimeout: const Duration(seconds: 15),
      );
      _reconnectAttempts = 0;

      _subscription = _channel!.stream.listen(
        (event) {
          try {
            final data = jsonDecode(event.toString());
            if (data is Map<String, dynamic>) {
              _onMessage?.call(data);
            } else if (data is Map) {
              _onMessage?.call(Map<String, dynamic>.from(data));
            }
          } catch (_) {}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect,
        cancelOnError: true,
      );

      if (isReconnect) {
        _onMessage?.call({'type': '_reconnected'});
      }
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    final delay = Duration(
      milliseconds: (5000 * (1 << _reconnectAttempts.clamp(0, 3))).clamp(5000, 30000),
    );
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, () => _openSocket(isReconnect: true));
  }

  void sendText(String text) {
    if (!isConnected) return;
    _channel!.sink.add(jsonEncode({
      'type': 'message',
      'content': text,
      'message_type': 'text',
    }));
  }

  Future<void> disconnect({bool clearHandlers = true}) async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    if (clearHandlers) {
      _onMessage = null;
      _ticketProvider = null;
      _conversationId = null;
      _disposed = true;
    }
  }
}