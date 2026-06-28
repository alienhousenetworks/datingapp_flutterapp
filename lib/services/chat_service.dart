import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/message_model.dart';
import 'api_client.dart';

class ChatService {
  final _client = ApiClient.instance;

  /// POST /api/v1/auth/ws-ticket/
  Future<String?> getWsTicket() async {
    try {
      final response = await _client.post(AppConstants.authWsTicket);
      final data = response.data;
      if (data is Map) {
        return data['ticket']?.toString();
      }
    } catch (_) {}
    return null;
  }

  String chatWebSocketUrl(String conversationId, String ticket) =>
      '${AppConstants.wsBase}/chat/$conversationId/?ticket=$ticket';

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

  // GET /api/v1/messages/?conversation_id={id}
  Future<List<Message>> getMessages(String conversationId) async {
    try {
      final response = await _client.get(
        AppConstants.messages,
        params: {'conversation_id': conversationId},
      );
      final data = response.data;
      List<Message> messages = [];
      if (data is List) {
        messages = data.map((e) => Message.fromJson(e)).toList();
      } else if (data is Map && data['results'] is List) {
        messages = (data['results'] as List)
            .map((e) => Message.fromJson(e))
            .toList();
      }
      // API returns newest-first; chat UI expects oldest-first.
      return messages.reversed.toList();
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // POST /api/v1/messages/ — send a message (REST fallback)
  Future<Message> sendMessage(String conversationId, String content) async {
    try {
      final response = await _client.post(
        AppConstants.messages,
        data: {
          'conversation': conversationId,
          'content': {'text': content},
          'message_type': 'text',
        },
      );
      return Message.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // POST /api/v1/messages/{id}/seen/
  Future<void> markSeen(String messageId) async {
    try {
      await _client.post('${AppConstants.messages}$messageId/seen/');
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
    if (data is Map) {
      return data['detail']?.toString() ??
          data['message']?.toString() ??
          data['error']?.toString() ??
          'Error';
    }
    return 'Network error.';
  }
}