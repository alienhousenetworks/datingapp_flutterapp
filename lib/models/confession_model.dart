/// Confession entry from GET /api/v1/social/feed/
class Confession {
  final String id;
  final String text;
  final String? moodTag;
  final int relateCount;
  final int repostCount;
  final bool isAuthor;
  final bool hasRequestedChat;
  final int? timeRemainingMin;
  final String? userGender;
  final String? userSexuality;
  final int? userAge;
  final DateTime createdAt;

  const Confession({
    required this.id,
    required this.text,
    this.moodTag,
    this.relateCount = 0,
    this.repostCount = 0,
    this.isAuthor = false,
    this.hasRequestedChat = false,
    this.timeRemainingMin,
    this.userGender,
    this.userSexuality,
    this.userAge,
    required this.createdAt,
  });

  factory Confession.fromJson(Map<String, dynamic> json) => Confession(
        id: json['id']?.toString() ?? '',
        text: json['text']?.toString() ??
            json['body']?.toString() ??
            json['content']?.toString() ??
            '',
        moodTag: json['mood_tag']?.toString() ?? json['mood']?.toString(),
        relateCount: _parseInt(json['relate_count'] ?? json['relates']) ?? 0,
        repostCount: _parseInt(json['repost_count'] ?? json['reposts']) ?? 0,
        isAuthor: json['is_author'] == true,
        hasRequestedChat: json['has_requested_chat'] == true,
        timeRemainingMin: _parseInt(json['time_remaining_min']),
        userGender: json['user_gender']?.toString(),
        userSexuality: json['user_sexuality']?.toString(),
        userAge: _parseInt(json['user_age']),
        createdAt:
            DateTime.tryParse(json['created_at']?.toString() ?? '') ??
                DateTime.now(),
      );

  Confession copyWith({
    int? relateCount,
    int? repostCount,
    bool? hasRequestedChat,
  }) =>
      Confession(
        id: id,
        text: text,
        moodTag: moodTag,
        relateCount: relateCount ?? this.relateCount,
        repostCount: repostCount ?? this.repostCount,
        isAuthor: isAuthor,
        hasRequestedChat: hasRequestedChat ?? this.hasRequestedChat,
        timeRemainingMin: timeRemainingMin,
        userGender: userGender,
        userSexuality: userSexuality,
        userAge: userAge,
        createdAt: createdAt,
      );

  bool get hasAuthorMeta =>
      (userGender != null && userGender!.isNotEmpty) ||
      (userSexuality != null && userSexuality!.isNotEmpty) ||
      userAge != null;

  String get moodLabel {
    if (moodTag == null || moodTag!.isEmpty) return '';
    return moodTag!
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

class MoodTagOption {
  final String value;
  final String label;

  const MoodTagOption({required this.value, required this.label});

  factory MoodTagOption.fromJson(Map<String, dynamic> json) => MoodTagOption(
        value: json['value']?.toString() ?? '',
        label: json['label']?.toString() ?? json['value']?.toString() ?? '',
      );
}