import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/paper_plane_model.dart';
import 'api_client.dart';

class PaperPlaneService {
  final _client = ApiClient.instance;

  // ─── Sender ──────────────────────────────────────────────────

  /// POST /api/v1/paper-plane/launch/
  Future<PaperPlane> launch(String message, {String sticker = ''}) async {
    try {
      final response = await _client.post(
        AppConstants.paperPlaneLaunch,
        data: {'message': message, 'sticker': sticker},
      );
      return PaperPlane.fromJson(
          Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  /// GET /api/v1/paper-plane/my-planes/
  Future<List<PaperPlane>> getMyPlanes() async {
    try {
      final response = await _client.get(AppConstants.paperPlaneMyPlanes);
      final data = response.data;
      if (data is List) {
        return data
            .map((e) => PaperPlane.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  /// DELETE /api/v1/paper-plane/{planeId}/cancel/
  Future<void> cancel(String planeId) async {
    try {
      await _client.delete('${AppConstants.paperPlaneBase}$planeId/cancel/');
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // ─── Recipient ───────────────────────────────────────────────

  /// GET /api/v1/paper-plane/inbox/
  Future<PlaneDelivery?> getInbox() async {
    try {
      final response = await _client.get(AppConstants.paperPlaneInbox);
      final data = response.data;
      if (data is Map && data.containsKey('id')) {
        return PlaneDelivery.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 200) return null;
      throw _parseError(e);
    }
  }

  /// POST /api/v1/paper-plane/{deliveryId}/start-game/
  Future<GameConfig> startGame(String deliveryId) async {
    try {
      final response = await _client.post(
        '${AppConstants.paperPlaneBase}$deliveryId/start-game/',
      );
      return GameConfig.fromJson(
          Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  /// POST /api/v1/paper-plane/{deliveryId}/caught/
  Future<CatchResult> recordCatch(String deliveryId) async {
    try {
      final response = await _client.post(
        '${AppConstants.paperPlaneBase}$deliveryId/caught/',
      );
      return CatchResult.fromJson(
          Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  /// POST /api/v1/paper-plane/{deliveryId}/connect/
  Future<String> connect(String deliveryId) async {
    try {
      final response = await _client.post(
        '${AppConstants.paperPlaneBase}$deliveryId/connect/',
      );
      final data = response.data;
      if (data is Map) {
        final id = data['conversation_id']?.toString() ?? '';
        if (id.isEmpty || id == 'null') {
          throw 'Server did not return a conversation id.';
        }
        return id;
      }
      throw 'Unexpected connect response from server.';
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  /// POST /api/v1/paper-plane/{deliveryId}/pass/
  Future<void> pass(String deliveryId) async {
    try {
      await _client.post(
        '${AppConstants.paperPlaneBase}$deliveryId/pass/',
      );
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  /// GET /api/v1/paper-plane/sky/
  Future<List<SkyPlane>> getSkyPlanes() async {
    try {
      final response = await _client.get(AppConstants.paperPlaneSky);
      final data = response.data;
      if (data is List) {
        return data
            .map((e) => SkyPlane.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  /// POST /api/v1/paper-plane/catch-sky-plane/
  Future<GameConfig> catchSkyPlane(String planeId) async {
    try {
      final response = await _client.post(
        AppConstants.paperPlaneCatchSkyPlane,
        data: {'plane_id': planeId},
      );
      return GameConfig.fromJson(
          Map<String, dynamic>.from(response.data as Map));
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        return detail.map((e) => e.toString()).join(', ');
      }
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
      // Field errors: { "field": ["msg"] }
      for (final entry in data.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v is String && v.isNotEmpty) return v;
      }
      return 'Request failed (${e.response?.statusCode ?? '?'})';
    }
    if (data is String && data.isNotEmpty) {
      return data.length > 160 ? '${data.substring(0, 160)}…' : data;
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Network error. Check your connection.';
    }
    return e.message?.isNotEmpty == true ? e.message! : 'Network error.';
  }
}
