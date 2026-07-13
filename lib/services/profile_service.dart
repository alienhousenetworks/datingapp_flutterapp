import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/profile_model.dart';
import 'api_client.dart';

class ProfileService {
  final _client = ApiClient.instance;

  // GET /api/v1/profile/me/
  Future<UserProfile> getMyProfile() async {
    try {
      final response = await _client.get(AppConstants.profileMe);
      return UserProfile.fromJson(response.data);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // PATCH /api/v1/profile/me/
  Future<UserProfile> updateMyProfile(Map<String, dynamic> data) async {
    try {
      final response = await _client.patch(AppConstants.profileMe, data: data);
      return UserProfile.fromJson(response.data);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // POST /api/v1/profile/ — create profile (first time onboarding)
  Future<UserProfile> createProfile(Map<String, dynamic> data) async {
    try {
      final response = await _client.post(AppConstants.profileList, data: data);
      return UserProfile.fromJson(response.data);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // GET /api/v1/profile/{id}/
  Future<UserProfile> getProfile(String id) async {
    try {
      final response = await _client.get('${AppConstants.profileList}$id/');
      return UserProfile.fromJson(response.data);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // GET options (genders, sexualities, intents, languages, turn_ons)
  Future<List<NamedOption>> getGenders() => _getOptions(AppConstants.genders);
  Future<List<NamedOption>> getSexualities() => _getOptions(AppConstants.sexualities);
  Future<List<NamedOption>> getIntents() => _getOptions(AppConstants.intents);
  Future<List<NamedOption>> getLanguages() => _getOptions(AppConstants.languages);
  Future<List<NamedOption>> getTurnOns() => _getOptions(AppConstants.turnOns);
  Future<List<NamedOption>> getMoodOptions() => _getOptions(AppConstants.moodOptions);

  Future<List<NamedOption>> _getOptions(String url) async {
    try {
      final response = await _client.get(url);
      final list = response.data as List<dynamic>;
      return list.map((e) => NamedOption.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // POST /api/v1/images/upload/
  Future<void> uploadImage(String filePath) async {
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(filePath),
      });
      await _client.postFormData(AppConstants.imagesUpload, formData);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // DELETE /api/v1/images/{id}/
  Future<void> deleteImage(dynamic imageId) async {
    try {
      await _client.delete('${AppConstants.apiV1}/images/$imageId/');
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // GET /api/v1/avatars/
  Future<List<AvatarModel>> getAvatars() async {
    try {
      final response = await _client.get(AppConstants.avatars);
      final list = response.data as List<dynamic>;
      return list.map((e) => AvatarModel.fromJson(e)).toList();
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // PATCH /api/v1/profile/me/
  Future<UserProfile> changeAvatar(String avatarId) async {
    try {
      final response = await _client.patch(AppConstants.profileMe, data: {
        'avatar': avatarId,
      });
      return UserProfile.fromJson(response.data);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }



  // GET /api/v1/profile/username-available/
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _client.get(
        AppConstants.profileUsernameAvailable,
        params: {'username': username},
      );
      return response.data['available'] ?? true;
    } catch (_) {
      return true;
    }
  }

  // GET /api/v1/auth/session/
  Future<Map<String, dynamic>> getAuthSession() async {
    try {
      final response = await _client.get(AppConstants.authSession);
      return Map<String, dynamic>.from(response.data ?? {});
    } catch (_) {
      return {};
    }
  }

  // GET /api/v1/subscription/me/
  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final response = await _client.get(AppConstants.subscriptionMe);
      return Map<String, dynamic>.from(response.data ?? {});
    } catch (_) {
      return {'has_access': true, 'is_free': true};
    }
  }

  String _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final direct = data['message'] ?? data['detail'] ?? data['error'];
      if (direct != null) return direct.toString();

      final parts = <String>[];
      data.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          parts.add('$key: ${value.first}');
        } else if (value is String && value.isNotEmpty) {
          parts.add('$key: $value');
        }
      });
      if (parts.isNotEmpty) return parts.join(' · ');
      if (data.isNotEmpty) return data.values.first.toString();
      return 'Error updating profile';
    }
    if (data is List && data.isNotEmpty) return data.first.toString();
    return 'Network error. Please try again.';
  }
}



