// ─── Auth Models ─────────────────────────────────────────────

class OtpRequestModel {
  final String email;
  final String deviceId;

  OtpRequestModel({required this.email, required this.deviceId});

  Map<String, dynamic> toJson() => {
        'email': email,
        'device_id': deviceId,
      };
}

class OtpVerifyModel {
  final String email;
  final String otp;
  final String deviceId;

  OtpVerifyModel({
    required this.email,
    required this.otp,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'otp': otp,
        'device_id': deviceId,
      };
}

class AuthTokenResponse {
  final String access;
  final String refresh;
  final bool isNewUser;
  final String? userId;
  final String? email;

  AuthTokenResponse({
    required this.access,
    required this.refresh,
    required this.isNewUser,
    this.userId,
    this.email,
  });

  factory AuthTokenResponse.fromJson(Map<String, dynamic> json) {
    return AuthTokenResponse(
      access: json['access'] ?? '',
      refresh: json['refresh'] ?? '',
      isNewUser: json['is_new_user'] ?? json['created'] ?? false,
      userId: json['user_id']?.toString() ?? json['id']?.toString(),
      email: json['email'],
    );
  }
}

class AuthMessageResponse {
  final String message;
  AuthMessageResponse({required this.message});
  factory AuthMessageResponse.fromJson(Map<String, dynamic> json) =>
      AuthMessageResponse(message: json['message'] ?? json['detail'] ?? '');
}
