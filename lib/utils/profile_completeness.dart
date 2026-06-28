import '../models/profile_model.dart';

/// Client-side checks aligned with backend feed gate (core profile fields).
class ProfileCompleteness {
  static List<String> missingCoreFields(UserProfile profile) {
    final missing = <String>[];
    if (profile.username == null || profile.username!.trim().isEmpty) {
      missing.add('Username');
    }
    if (profile.dateOfBirth == null || profile.dateOfBirth!.trim().isEmpty) {
      missing.add('Date of birth');
    }
    if (profile.genderId == null || profile.genderId!.trim().isEmpty) {
      missing.add('Gender');
    }
    if (profile.sexualityId == null || profile.sexualityId!.trim().isEmpty) {
      missing.add('Sexuality');
    }
    if (profile.preferredGenderIds.isEmpty) {
      missing.add('Interested in');
    }
    return missing;
  }

  /// All blockers for Discover — includes backend identity verification.
  static List<String> discoverBlockers(UserProfile profile) {
    final blockers = missingCoreFields(profile);
    if (!profile.isIdentityVerified) {
      blockers.add('Identity verification');
    }
    return blockers;
  }

  static String missingFieldsMessage(UserProfile profile) {
    final blockers = discoverBlockers(profile);
    if (blockers.isEmpty) {
      if (!profile.isDiscoverable) {
        return 'Profile looks complete. Pull to refresh Discover in a moment.';
      }
      return 'Your profile is ready for Discover.';
    }
    return 'Still needed: ${blockers.join(', ')}.';
  }

  static bool hasPartialProfile(UserProfile profile) =>
      (profile.username?.isNotEmpty ?? false) ||
      profile.dateOfBirth != null ||
      profile.genderId != null ||
      profile.sexualityId != null ||
      profile.preferredGenderIds.isNotEmpty ||
      profile.bio?.isNotEmpty == true;
}