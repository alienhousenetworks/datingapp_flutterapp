import 'profile_model.dart';

/// A discovery feed entry from GET /api/v1/feed/
class FeedItem {
  final UserProfile profile;
  final bool canDirectMessage;
  final double? score;
  final bool isBoosted;

  const FeedItem({
    required this.profile,
    this.canDirectMessage = false,
    this.score,
    this.isBoosted = false,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final profileData = json['profile'] as Map<String, dynamic>?;
    final userId = json['id']?.toString() ?? profileData?['id']?.toString() ?? '';

    return FeedItem(
      profile: profileData != null
          ? UserProfile.fromJson({...profileData, 'id': userId})
          : UserProfile.fromJson(json),
      canDirectMessage: json['can_direct_message'] ?? false,
      score: json['score'] == null
          ? null
          : (json['score'] is num
              ? (json['score'] as num).toDouble()
              : double.tryParse(json['score'].toString())),
      isBoosted: json['is_boosted'] ?? false,
    );
  }

  FeedItem copyWith({
    UserProfile? profile,
    bool? canDirectMessage,
    double? score,
    bool? isBoosted,
  }) =>
      FeedItem(
        profile: profile ?? this.profile,
        canDirectMessage: canDirectMessage ?? this.canDirectMessage,
        score: score ?? this.score,
        isBoosted: isBoosted ?? this.isBoosted,
      );
}