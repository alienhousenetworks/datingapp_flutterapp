import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'device_context_service.dart';
import 'location_context.dart';
import 'event_batcher_service.dart';



/// Product analytics — batches events to POST /api/v1/analytics/events/
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final _uuid = const Uuid();
  final _queue = <Map<String, dynamic>>[];
  Timer? _flushTimer;
  String? _sessionId;
  DateTime? _sessionStartedAt;
  bool _flushing = false;

  String get sessionId => _sessionId ??= _uuid.v4();

  void startSession() {
    _sessionId = _uuid.v4();
    _sessionStartedAt = DateTime.now();
    track('session_start');
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
  }

  Future<void> endSession() async {
    if (_sessionStartedAt != null) {
      track('session_end', properties: {
        'duration_sec': DateTime.now().difference(_sessionStartedAt!).inSeconds,
      });
    }
    await flush();
    _flushTimer?.cancel();
    _flushTimer = null;
    _sessionId = null;
    _sessionStartedAt = null;
  }

  void track(String eventName, {Map<String, dynamic>? properties}) {
    _queue.add({
      'event_name': eventName,
      'properties': properties ?? {},
      'session_id': sessionId,
    });
    if (_queue.length >= 10) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();

    try {
      final ctx = await DeviceContextService.instance.getContext();
      final loc = LocationContext.instance;
      final enriched = batch.map((e) {
        return {
          ...e,
          'device_type': ctx.deviceType,
          'platform': ctx.platform,
          'app_version': ctx.appVersion,
          'os_version': ctx.osVersion,
          if (loc.country != null) 'country': loc.country,
          if (loc.state != null) 'state': loc.state,
          if (loc.city != null) 'city': loc.city,
          'properties': {
            ...(e['properties'] as Map<String, dynamic>? ?? {}),
            if (ctx.connectionType.isNotEmpty)
              'connection_type': ctx.connectionType,
            if (ctx.manufacturer != null) 'manufacturer': ctx.manufacturer,
            if (ctx.model != null) 'device_model': ctx.model,
          },
        };
      }).toList();

      for (final event in enriched) {
        EventBatcherService.instance.enqueue(type: 'analytics', data: event);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] flush failed: $e');
      _queue.insertAll(0, batch.take(50));
    } finally {
      _flushing = false;
    }
  }


  // ─── Convenience wrappers ─────────────────────────────────

  void trackFeedImpression({
    required String profileId,
    String source = 'feed',
    double? score,
    int? index,
  }) {
    track('feed_profile_shown', properties: {
      'profile_id': profileId,
      'source': source,
      if (score != null) 'score': score,
      if (index != null) 'index': index,
    });
    EventBatcherService.instance.enqueue(
      type: 'seen',
      data: {
        'profile_ids': [profileId]
      },
    );
  }


  void trackFeedLike(String profileId, {bool matched = false}) {
    track('profile_liked', properties: {
      'profile_id': profileId,
      'matched': matched,
    });
  }

  void trackFeedPass(String profileId) {
    track('profile_skipped', properties: {'profile_id': profileId});
  }

  void trackConfessionViewed(String confessionId) {
    track('confession_viewed', properties: {'confession_id': confessionId});
  }

  void trackCallStarted({required String callId, required String callType}) {
    track('call_started', properties: {
      'call_session_id': callId,
      'call_type': callType,
    });
  }

  void trackCallEnded({required String callId, required int durationSec}) {
    track('call_ended', properties: {
      'call_session_id': callId,
      'duration_sec': durationSec,
    });
  }
}