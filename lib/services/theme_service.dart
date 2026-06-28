import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/theme_model.dart';
import 'api_client.dart';

class ThemeService {
  final _client = ApiClient.instance;

  // GET /api/v1/theme/me/
  Future<ThemeConfig?> getMyTheme() async {
    try {
      final response = await _client.get(AppConstants.themeMe);
      if (response.data == null) return null;
      return ThemeConfig.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }

  // PATCH /api/v1/theme/me/
  Future<ThemeConfig?> updateMyTheme({
    String? layoutId,
    String? bgId,
    String? bgVariantId,
  }) async {
    try {
      final response = await _client.patch(
        AppConstants.themeMe,
        data: {
          if (layoutId != null) 'layout_id': layoutId,
          if (bgId != null) 'bg_id': bgId,
          if (bgVariantId != null) 'bg_variant_id': bgVariantId,
        },
      );
      if (response.data == null) return null;
      return ThemeConfig.fromJson(response.data);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // GET /api/v1/theme/options/
  Future<ThemeOptionsResponse> getThemeOptions() async {
    try {
      final response = await _client.get(AppConstants.themeOptions);
      return ThemeOptionsResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) return data['detail'] ?? 'Failed to update theme';
    return 'Network error.';
  }
}
