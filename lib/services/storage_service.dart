import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  // ─── Token Management ────────────────────────────────────
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.keyAccessToken, value: accessToken),
      _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken),
    ]);
  }

  static Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.keyAccessToken);

  static Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.keyRefreshToken);

  static Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: AppConstants.keyAccessToken),
      _storage.delete(key: AppConstants.keyRefreshToken),
    ]);
  }

  // ─── User Data ───────────────────────────────────────────
  static Future<void> saveEmail(String email) =>
      _storage.write(key: AppConstants.keyUserEmail, value: email);

  static Future<String?> getEmail() =>
      _storage.read(key: AppConstants.keyUserEmail);

  static Future<String> getOrCreateDeviceId() async {
    String? deviceId = await _storage.read(key: AppConstants.keyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = const Uuid().v4();
      await _storage.write(key: AppConstants.keyDeviceId, value: deviceId);
    }
    return deviceId;
  }

  static Future<void> setOnboardingDone(bool done) =>
      _storage.write(
        key: AppConstants.keyOnboardingDone,
        value: done.toString(),
      );

  static Future<bool> isOnboardingDone() async {
    final val = await _storage.read(key: AppConstants.keyOnboardingDone);
    return val == 'true';
  }

  static Future<void> setIsNewUser(bool isNew) =>
      _storage.write(key: AppConstants.keyIsNewUser, value: isNew.toString());

  static Future<bool> isNewUser() async {
    final val = await _storage.read(key: AppConstants.keyIsNewUser);
    return val == 'true';
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ─── Full Logout ─────────────────────────────────────────
  static Future<void> clearAll() => _storage.deleteAll();
}
