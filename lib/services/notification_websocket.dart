import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/constants.dart';
typedef NotificationHandler = void Function(Map<String, dynamic> data);

/// Global notifications socket — refreshes chat on new_message / match events.
class NotificationWebSocket {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  bool _disposed = false;
  NotificationHandler? _onEvent;

  Future<void> connect({
    required Future<String?> Function() ticketProvider,
    required NotificationHandler onEvent,
  }) async {
    _disposed = false;
    _onEvent = onEvent;
    await _open(ticketProvider);
  }

  Future<void> _open(Future<String?> Function() ticketProvider) async {
    if (_disposed) return;
    await _subscription?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}

    final ticket = await ticketProvider();
    if (ticket == null || ticket.isEmpty || _disposed) {
      _scheduleReconnect(ticketProvider);
      return;
    }

    try {
      final url = '${AppConstants.wsBase}/notifications/?ticket=$ticket';
      _channel = IOWebSocketChannel.connect(
        url,
        headers: {'Origin': AppConstants.wsOrigin},
        connectTimeout: const Duration(seconds: 15),
      );
      _subscription = _channel!.stream.listen(
        (raw) {
          try {
            final data = jsonDecode(raw.toString());
            if (data is Map) {
              _onEvent?.call(Map<String, dynamic>.from(data));
            }
          } catch (_) {}
        },
        onDone: () => _scheduleReconnect(ticketProvider),
        onError: (_) => _scheduleReconnect(ticketProvider),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect(ticketProvider);
    }
  }

  void _scheduleReconnect(Future<String?> Function() ticketProvider) {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () => _open(ticketProvider));
  }

  Future<void> disconnect() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _onEvent = null;
  }
}