import 'package:dio/dio.dart';
import '../core/constants.dart';
import 'api_client.dart';

class SubscriptionStatus {
  final bool hasAccess;
  final bool isFree;
  final bool requiresSubscription;
  final bool hasActiveSubscription;
  final int trialDays;
  final int trialDaysRemaining;
  final String price;
  final String currency;
  final int subscriptionDurationDays;

  const SubscriptionStatus({
    this.hasAccess = true,
    this.isFree = true,
    this.requiresSubscription = false,
    this.hasActiveSubscription = false,
    this.trialDays = 0,
    this.trialDaysRemaining = 0,
    this.price = '0.00',
    this.currency = 'USD',
    this.subscriptionDurationDays = 30,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) =>
      SubscriptionStatus(
        hasAccess: json['has_access'] ?? true,
        isFree: json['is_free'] ?? true,
        requiresSubscription: json['requires_subscription'] ?? false,
        hasActiveSubscription: json['has_active_subscription'] ?? false,
        trialDays: json['trial_days'] ?? 0,
        trialDaysRemaining: json['trial_days_remaining'] ?? 0,
        price: json['price']?.toString() ?? '0.00',
        currency: json['currency']?.toString() ?? 'USD',
        subscriptionDurationDays: json['subscription_duration_days'] ?? 30,
      );

  bool get shouldShowPaywall =>
      !isFree && !hasAccess && requiresSubscription;
}

class SubscriptionService {
  final _client = ApiClient.instance;

  Future<SubscriptionStatus> getStatus() async {
    try {
      final response = await _client.get(AppConstants.subscriptionMe);
      return SubscriptionStatus.fromJson(
        Map<String, dynamic>.from(response.data ?? {}),
      );
    } catch (_) {
      return const SubscriptionStatus();
    }
  }

  Future<void> startTrial() async {
    // Trial is automatic on signup per backend config — refresh status.
    await getStatus();
  }

  Future<Map<String, dynamic>> purchase() async {
    try {
      final response = await _client.post(AppConstants.subscriptionPurchase);
      return Map<String, dynamic>.from(response.data ?? {});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        throw data['error'] ?? data['detail'] ?? 'Purchase failed';
      }
      throw 'Payment unavailable';
    }
  }
}