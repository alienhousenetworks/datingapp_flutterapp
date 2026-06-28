import 'package:dio/dio.dart';
import '../core/constants.dart';
import '../models/auth_model.dart';
import '../models/auth_exception.dart';
import 'api_client.dart';
import 'storage_service.dart';

class AuthService {
  final _client = ApiClient.instance;

  // POST /api/v1/auth/register/ — request OTP
  Future<String> requestOtp(
    String email, {
    required bool isSignUp,
  }) async {
    final deviceId = await StorageService.getOrCreateDeviceId();
    final normalized = email.trim().toLowerCase();
    await StorageService.saveEmail(normalized);
    try {
      final response = await _client.post(
        AppConstants.authRegister,
        data: {
          'email': normalized,
          'device_id': deviceId,
          'intent': isSignUp ? 'signup' : 'login',
        },
      );
      return response.data['message'] ?? 'OTP sent';
    } on DioException catch (e) {
      throw _parseAuthError(e);
    }
  }

  // POST /api/v1/auth/otp/verify/ — verify OTP and get JWT
  Future<AuthTokenResponse> verifyOtp(String email, String otp) async {
    final deviceId = await StorageService.getOrCreateDeviceId();
    try {
      final response = await _client.post(
        AppConstants.authOtpVerify,
        data: {'email': email, 'otp': otp, 'device_id': deviceId},
      );
      final result = AuthTokenResponse.fromJson(response.data);
      await StorageService.saveTokens(
        accessToken: result.access,
        refreshToken: result.refresh,
      );
      await StorageService.setIsNewUser(result.isNewUser);
      return result;
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // POST /api/v1/auth/otp/resend/
  Future<String> resendOtp() async {
    try {
      final response = await _client.post(AppConstants.authOtpResend);
      return response.data['message'] ?? 'OTP resent';
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  // POST /api/v1/auth/logout/
  Future<void> logout() async {
    final refreshToken = await StorageService.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _client.post(
          AppConstants.authLogout,
          data: {'refresh': refreshToken},
        );
      } catch (_) {}
    }
    await StorageService.clearAll();
  }

  AuthException _parseAuthError(DioException e) {
    final data = e.response?.data;
    final status = e.response?.statusCode;
    if (data is Map) {
      final message = data['message'] ??
          data['detail'] ??
          data['error'] ??
          data.values.first?.toString() ??
          'An error occurred';
      return AuthException(
        message: message.toString(),
        code: data['code']?.toString(),
        statusCode: status,
      );
    }
    if (data != null && data.toString().isNotEmpty) {
      return AuthException(message: data.toString(), statusCode: status);
    }

    if (status != null) {
      return AuthException(
        message: 'Request failed (HTTP $status)',
        statusCode: status,
      );
    }

    final type = e.type.name;
    final msg = e.message?.trim();
    if (msg != null && msg.isNotEmpty) {
      return AuthException(message: '$type: $msg');
    }
    return AuthException(
      message:
          '$type — check app has INTERNET permission and can reach ${AppConstants.baseUrl}',
    );
  }

  String _parseError(DioException e) => _parseAuthError(e).message;
}
