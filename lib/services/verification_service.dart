import 'package:dio/dio.dart';
import '../core/constants.dart';
import 'api_client.dart';

class VerificationResult {
  final bool success;
  final String? error;

  const VerificationResult({required this.success, this.error});
}

class VerificationService {
  final _client = ApiClient.instance;

  /// Mock verify — uses backend mock-complete until third-party provider is enabled.
  Future<VerificationResult> mockVerify() async {
    try {
      final response = await _client.post(AppConstants.verificationMockComplete);
      final status = response.data['status']?.toString().toUpperCase();
      if (status == 'SUCCESS') {
        return const VerificationResult(success: true);
      }
      return VerificationResult(
        success: false,
        error: response.data['error']?.toString() ?? 'Verification failed',
      );
    } on DioException catch (e) {
      // Fallback for servers not yet deployed with mock-complete
      if (e.response?.statusCode == 404) {
        return _faceioMockFallback();
      }
      final data = e.response?.data;
      if (data is Map && data['error'] != null) {
        return VerificationResult(success: false, error: data['error'].toString());
      }
      return VerificationResult(success: false, error: e.message ?? 'Network error');
    } catch (e) {
      return VerificationResult(success: false, error: e.toString());
    }
  }

  Future<VerificationResult> _faceioMockFallback() async {
    try {
      final response = await _client.post(
        AppConstants.verificationFaceioComplete,
        data: {'facial_id': 'mock-dev-bypass'},
      );
      final status = response.data['status']?.toString().toUpperCase();
      return VerificationResult(
        success: status == 'SUCCESS',
        error: status == 'SUCCESS' ? null : 'Verification failed',
      );
    } catch (e) {
      return VerificationResult(success: false, error: e.toString());
    }
  }

  Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await _client.get(AppConstants.verificationStatus);
      return Map<String, dynamic>.from(response.data ?? {});
    } catch (_) {
      return {};
    }
  }
}