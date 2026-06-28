import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/feed_filters.dart';
import '../models/feed_item.dart';
import '../models/feed_page.dart';
import 'api_client.dart';

class FeedService {
  final _client = ApiClient.instance;

  static const int defaultPageSize = 20;

  // GET /api/v1/feed/?count=20&cursor=0
  Future<FeedPage> getFeed({
    int count = defaultPageSize,
    int cursor = 0,
    bool refresh = false,
    FeedFilters filters = FeedFilters.defaults,
  }) async {
    try {
      final response = await _client.get(
        AppConstants.feed,
        params: {
          'count': count,
          'cursor': cursor,
          'include_liked': '1',
          if (refresh) 'refresh': '1',
          ...filters.toQueryParams(),
        },
      );
      return _parseFeedResponse(response.data);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  FeedPage _parseFeedResponse(dynamic data) {
    if (data is! Map) {
      return const FeedPage();
    }

    final map = Map<String, dynamic>.from(data);
    if (map['profile_incomplete'] == true) {
      return FeedPage(
        profileIncomplete: true,
        message: map['message']?.toString(),
      );
    }

    final results = map['results'];
    final items = <FeedItem>[];
    if (results is List) {
      for (final entry in results) {
        if (entry is Map) {
          items.add(FeedItem.fromJson(Map<String, dynamic>.from(entry)));
        }
      }
    }

    int? nextCursor;
    final rawCursor = map['next_cursor'];
    if (rawCursor != null) {
      nextCursor = int.tryParse(rawCursor.toString());
    }

    return FeedPage(
      items: items,
      nextCursor: nextCursor,
      emptyReason: map['empty_reason']?.toString(),
    );
  }

  // POST /api/v1/interaction/send/
  Future<Map<String, dynamic>> sendLike(String targetUserId) async {
    try {
      final response = await _client.post(
        AppConstants.interactionSend,
        data: {'target_user_id': targetUserId},
      );
      return Map<String, dynamic>.from(response.data ?? {});
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // POST /api/v1/interaction/pass/
  Future<Map<String, dynamic>> sendPass(String targetUserId) async {
    try {
      final response = await _client.post(
        AppConstants.interactionPass,
        data: {'target_user_id': targetUserId},
      );
      return Map<String, dynamic>.from(response.data ?? {});
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // POST /api/v1/interaction/start_conversation/
  Future<Map<String, dynamic>> startConversation(
    String targetUserId, {
    String message = 'Hey! 👋',
  }) async {
    try {
      final response = await _client.post(
        AppConstants.interactionStartConversation,
        data: {
          'target_user_id': targetUserId,
          'message': message,
        },
      );
      return Map<String, dynamic>.from(response.data ?? {});
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return data['message'] ??
          data['error'] ??
          data['detail'] ??
          'Action failed';
    }
    return 'Network error.';
  }
}