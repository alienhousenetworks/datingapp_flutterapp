import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/message_model.dart';
import 'api_client.dart';

class ChatService {
  final _client = ApiClient.instance;

  // GET /api/v1/conversations/
  Future<List<Conversation>> getConversations() async {
    try {
      final response = await _client.get(AppConstants.conversations);
      final data = response.data;
      if (data is List) {
        return data.map((e) => Conversation.fromJson(e)).toList();
      }
      if (data is Map && data['results'] is List) {
        return (data['results'] as List)
            .map((e) => Conversation.fromJson(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // GET /api/v1/messages/?conversation={id}
  Future<List<Message>> getMessages(String conversationId) async {
    try {
      final response = await _client.get(
        AppConstants.messages,
        params: {'conversation': conversationId},
      );
      final data = response.data;
      if (data is List) {
        return data.map((e) => Message.fromJson(e)).toList();
      }
      if (data is Map && data['results'] is List) {
        return (data['results'] as List)
            .map((e) => Message.fromJson(e))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // POST /api/v1/messages/ — send a message
  Future<Message> sendMessage(String conversationId, String content) async {
    try {
      final response = await _client.post(
        AppConstants.messages,
        data: {'conversation': conversationId, 'content': content},
      );
      return Message.fromJson(response.data);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // PATCH /api/v1/messages/{id}/seen/
  Future<void> markSeen(String messageId) async {
    try {
      await _client.patch('${AppConstants.messages}$messageId/seen/');
    } catch (_) {}
  }

  // GET /api/v1/matches/
  Future<List<Match>> getMatches() async {
    try {
      final response = await _client.get(AppConstants.matches);
      final data = response.data;
      if (data is List) {
        return data.map((e) => Match.fromJson(e)).toList();
      }
      if (data is Map && data['results'] is List) {
        return (data['results'] as List).map((e) => Match.fromJson(e)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) return data['detail'] ?? 'Error';
    return 'Network error.';
  }
}
