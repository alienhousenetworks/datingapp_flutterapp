import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/auth_model.dart';
import '../models/auth_exception.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

// ─── Auth State ──────────────────────────────────────────────

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final String? email;
  final bool isNewUser;
  final bool isLoading;
  final String? error;
  final String? errorCode;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.email,
    this.isNewUser = false,
    this.isLoading = false,
    this.error,
    this.errorCode,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? email,
    bool? isNewUser,
    bool? isLoading,
    String? error,
    String? errorCode,
    bool clearError = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        email: email ?? this.email,
        isNewUser: isNewUser ?? this.isNewUser,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        errorCode: clearError ? null : (errorCode ?? this.errorCode),
      );
}

// ─── Auth Notifier ───────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _service;

  AuthNotifier(this._service) : super(const AuthState()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final loggedIn = await StorageService.isLoggedIn();
    if (loggedIn) {
      final email = await StorageService.getEmail();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        email: email,
      );
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<String?> requestOtp(String email, {required bool isSignUp}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final message = await _service.requestOtp(email, isSignUp: isSignUp);
      state = state.copyWith(isLoading: false, email: email.trim().toLowerCase());
      return message;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
        errorCode: e.code,
      );
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<AuthTokenResponse?> verifyOtp(String otp) async {
    state = state.copyWith(isLoading: true, error: null);
    final email = state.email ?? await StorageService.getEmail() ?? '';
    try {
      final result = await _service.verifyOtp(email, otp);
      state = state.copyWith(
        isLoading: false,
        status: AuthStatus.authenticated,
        isNewUser: result.isNewUser,
      );
      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _service.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ─── Providers ───────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});
