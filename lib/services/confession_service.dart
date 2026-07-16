import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/confession_model.dart';
import '../models/confession_request_model.dart';
import 'api_client.dart';

class ConfessionService {
  final _client = ApiClient.instance;

  static const int minTextLength = 30;
  static const int maxTextLength = 500;
  static const int minChatRequestLength = 10;
  static const int maxChatRequestLength = 300;

  Future<List<Confession>> getFeed({
    double? latitude,
    double? longitude,
  }) async {
    final params = <String, dynamic>{};
    if (latitude != null && longitude != null) {
      params['lat'] = latitude;
      params['lon'] = longitude;
    }

    try {
      final response = await _client.get(
        AppConstants.socialFeed,
        params: params.isEmpty ? null : params,
      );
      final items = _parseList(response.data);
      // If geo hybrid returned empty, fall back to global feed once
      if (items.isEmpty && params.isNotEmpty) {
        final global = await _client.get(AppConstants.socialFeed);
        return _parseList(global.data);
      }
      return items;
    } on DioException catch (e) {
      // Soft-fail: try global feed without coords if geo request fails
      if (params.isNotEmpty) {
        try {
          final global = await _client.get(AppConstants.socialFeed);
          return _parseList(global.data);
        } catch (_) {}
      }
      throw ConfessionException(_parseError(e));
    }
  }

  Future<List<MoodTagOption>> getMoodTags() async {
    try {
      final response = await _client.get(AppConstants.socialMoods);
      final data = response.data;
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => MoodTagOption.fromJson(Map<String, dynamic>.from(e)))
            .where((m) => m.value.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  Future<Confession> post({
    required String text,
    required double latitude,
    required double longitude,
    String? moodTag,
    String language = 'en',
  }) async {
    final trimmed = text.trim();
    if (trimmed.length < minTextLength) {
      throw ConfessionException(
        'Write at least $minTextLength characters.',
      );
    }

    try {
      final response = await _client.post(
        AppConstants.social,
        data: {
          'text': trimmed,
          'language': language,
          'latitude': double.parse(latitude.toStringAsFixed(6)),
          'longitude': double.parse(longitude.toStringAsFixed(6)),
          if (moodTag != null && moodTag.isNotEmpty) 'mood_tag': moodTag,
        },
      );
      final data = response.data;
      if (data is Map) {
        return Confession.fromJson(Map<String, dynamic>.from(data));
      }
      return Confession(
        id: '',
        text: trimmed,
        moodTag: moodTag,
        createdAt: DateTime.now(),
      );
    } on DioException catch (e) {
      throw ConfessionException(_parseError(e));
    }
  }

  Future<int> relate(String confessionId) async {
    try {
      final response = await _client.post('${AppConstants.social}$confessionId/relate/');
      final data = response.data;
      if (data is Map && data['count'] != null) {
        return _parseInt(data['count']) ?? 0;
      }
      return 0;
    } on DioException catch (e) {
      throw ConfessionException(_parseError(e));
    }
  }

  /// GET /api/v1/confession-requests/ — pending requests received by current user.
  Future<List<ConfessionChatRequest>> listIncomingRequests() async {
    try {
      final response = await _client.get(AppConstants.confessionRequests);
      return _parseRequestList(response.data);
    } on DioException catch (e) {
      throw ConfessionException(_parseError(e));
    }
  }

  /// POST /api/v1/confession-requests/{id}/accept/
  Future<ConfessionRequestActionResult> acceptRequest(String requestId) async {
    try {
      final response = await _client.post(
        '${AppConstants.confessionRequests}$requestId/accept/',
      );
      final data = response.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        if (map['error'] != null) {
          return ConfessionRequestActionResult(
            success: false,
            error: map['error'].toString(),
          );
        }
        return ConfessionRequestActionResult(
          success: true,
          conversationId: map['conversation_id']?.toString(),
        );
      }
      return const ConfessionRequestActionResult(success: true);
    } on DioException catch (e) {
      return ConfessionRequestActionResult(
        success: false,
        error: _parseError(e),
      );
    }
  }

  /// POST /api/v1/confession-requests/{id}/reject/
  Future<ConfessionRequestActionResult> rejectRequest(String requestId) async {
    try {
      final response = await _client.post(
        '${AppConstants.confessionRequests}$requestId/reject/',
      );
      final data = response.data;
      if (data is Map && data['error'] != null) {
        return ConfessionRequestActionResult(
          success: false,
          error: data['error'].toString(),
        );
      }
      return const ConfessionRequestActionResult(success: true);
    } on DioException catch (e) {
      return ConfessionRequestActionResult(
        success: false,
        error: _parseError(e),
      );
    }
  }

  /// POST /api/v1/social/{id}/chat-request/
  Future<void> chatRequest(String confessionId, String message) async {
    final trimmed = message.trim();
    if (trimmed.length < minChatRequestLength) {
      throw ConfessionException(
        'Note must be at least $minChatRequestLength characters.',
      );
    }
    if (trimmed.length > maxChatRequestLength) {
      throw ConfessionException(
        'Note must be at most $maxChatRequestLength characters.',
      );
    }

    try {
      await _client.post(
        '${AppConstants.social}$confessionId/chat-request/',
        data: {'message': trimmed},
      );
    } on DioException catch (e) {
      throw ConfessionException(_parseError(e));
    }
  }

  /// POST /api/v1/social/{id}/repost/
  Future<void> repost(String confessionId, {String? thought}) async {
    try {
      await _client.post(
        '${AppConstants.social}$confessionId/repost/',
        data: {
          'type': 'REPOST',
          if (thought != null && thought.trim().isNotEmpty)
            'repost_thought': thought.trim(),
        },
      );
    } on DioException catch (e) {
      throw ConfessionException(_parseError(e));
    }
  }

  List<ConfessionChatRequest> _parseRequestList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) =>
              ConfessionChatRequest.fromJson(Map<String, dynamic>.from(e)))
          .where((r) => r.id.isNotEmpty)
          .toList();
    }
    if (data is Map) {
      final results = data['results'];
      if (results is List) {
        return results
            .whereType<Map>()
            .map((e) =>
                ConfessionChatRequest.fromJson(Map<String, dynamic>.from(e)))
            .where((r) => r.id.isNotEmpty)
            .toList();
      }
    }
    return [];
  }

  List<Confession> _parseList(dynamic data) {
    List<dynamic>? raw;
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      final results = data['results'];
      if (results is List) raw = results;
    }
    if (raw == null) return [];

    final out = <Confession>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      try {
        final c = Confession.fromJson(Map<String, dynamic>.from(entry));
        // Keep items with id even if text briefly empty (cache miss edge cases)
        if (c.id.isNotEmpty || c.text.isNotEmpty) {
          out.add(c);
        }
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      if (data['detail'] is String) return data['detail'] as String;
      if (data['error'] is String) return data['error'] as String;
      if (data['text'] is List && (data['text'] as List).isNotEmpty) {
        return data['text'].first.toString();
      }
      for (final value in data.values) {
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String && value.isNotEmpty) return value;
      }
    }
    if (e.response?.statusCode == 429) {
      return 'Daily confession limit reached. Try again tomorrow.';
    }
    return 'Could not complete request. Please try again.';
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

class ConfessionException implements Exception {
  final String message;
  const ConfessionException(this.message);

  @override
  String toString() => message;
}