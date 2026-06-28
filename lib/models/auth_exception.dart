class AuthException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const AuthException({
    required this.message,
    this.code,
    this.statusCode,
  });

  bool get isEmailExists => code == 'email_exists';
  bool get isEmailNotFound => code == 'email_not_found';

  @override
  String toString() => message;
}