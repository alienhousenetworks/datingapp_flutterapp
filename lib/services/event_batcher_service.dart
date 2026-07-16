import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';

class EventBatcherService {
  EventBatcherService._();
  static final EventBatcherService instance = EventBatcherService._();

  final List<Map<String, dynamic>> _queue = [];
  Timer? _timer;
  bool _flushing = false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => flush());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    flush();
  }

  void enqueue({required String type, required Map<String, dynamic> data}) {
    _queue.add({
      'type': type,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'data': data,
    });
  }

  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();

    try {
      await ApiClient.instance.post(
        '/api/v1/events/bulk/',
        data: {'events': batch},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[EventBatcher] flush failed: $e');
      _queue.insertAll(0, batch);
    } finally {
      _flushing = false;
    }
  }
}
