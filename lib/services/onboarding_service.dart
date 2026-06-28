import '../models/profile_model.dart';
import '../utils/profile_completeness.dart';
import 'profile_service.dart';
import 'storage_service.dart';
import 'subscription_service.dart';

/// Resolves whether the user still needs onboarding using the backend profile.
class OnboardingService {
  final ProfileService _profileService;
  final SubscriptionService _subscriptionService;

  OnboardingService({
    ProfileService? profileService,
    SubscriptionService? subscriptionService,
  })  : _profileService = profileService ?? ProfileService(),
        _subscriptionService = subscriptionService ?? SubscriptionService();

  Future<UserProfile> fetchMyProfile() => _profileService.getMyProfile();

  Future<bool> isProfileComplete() async {
    final profile = await fetchMyProfile();
    return profile.isDiscoverable;
  }

  Future<bool> hasPartialProfile() async {
    final profile = await fetchMyProfile();
    return ProfileCompleteness.hasPartialProfile(profile);
  }

  List<String> missingCoreFields(UserProfile profile) =>
      ProfileCompleteness.missingCoreFields(profile);

  Future<void> syncLocalOnboardingFlag({required bool complete}) =>
      StorageService.setOnboardingDone(complete);

  /// True when the user can enter the main app (profile complete + access).
  Future<bool> canEnterMainApp() async {
    if (!await isProfileComplete()) return false;
    final sub = await _subscriptionService.getStatus();
    return sub.isFree || sub.hasAccess;
  }

  Future<bool> needsSubscriptionGate() async {
    if (!await isProfileComplete()) return false;
    final sub = await _subscriptionService.getStatus();
    return !sub.isFree && !sub.hasAccess;
  }
}