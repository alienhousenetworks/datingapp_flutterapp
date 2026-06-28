import 'theme_model.dart';

// ─── Option Models (lookup lists from backend) ────────────────

class NamedOption {
  final String id;
  final String name;
  final String? code;

  NamedOption({required this.id, required this.name, this.code});

  factory NamedOption.fromJson(Map<String, dynamic> json) => NamedOption(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? '',
        code: json['code'],
      );
}

// ─── Profile Image ─────────────────────────────────────────────

class ProfileImage {
  final dynamic id;
  final String url;
  final int order;
  final bool isPrimary;

  ProfileImage({
    required this.id,
    required this.url,
    required this.order,
    required this.isPrimary,
  });

  factory ProfileImage.fromJson(Map<String, dynamic> json) => ProfileImage(
        id: json['id'],
        url: json['url'] ??
            json['image_url'] ??
            json['image'] ??
            '',
        order: json['order'] ?? 0,
        isPrimary: json['is_primary'] ?? json['order'] == 0,
      );
}

// ─── User Profile ──────────────────────────────────────────────

class UserProfile {
  final String id;
  final String? username;
  final String? displayName;
  final String? email;
  final String? bio;
  final String? dateOfBirth;
  final int? age;
  final bool hideAge;
  final bool hideDistance;
  final String? gender;
  final String? genderId;
  final String? sexuality;
  final String? sexualityId;
  final String? intent;
  final String? intentId;
  final List<String> languages;
  final List<String> languageIds;
  final List<String> turnOns;
  final List<String> turnOnIds;
  final List<ProfileImage> images;
  final String? mood;
  final String? city;
  final String? state;
  final String? country;
  final double? latitude;
  final double? longitude;
  final double? distance;
  final String? lastActive;
  final bool isVerified;
  final bool isIdentityVerified;
  final bool isOnline;
  final bool isLiked;
  final bool isDiscoverable;
  final List<String> preferredGenderIds;
  // Theme fields assigned by backend
  final ThemeConfig? themeConfig;

  UserProfile({
    required this.id,
    this.username,
    this.displayName,
    this.email,
    this.bio,
    this.dateOfBirth,
    this.age,
    this.hideAge = false,
    this.hideDistance = false,
    this.gender,
    this.genderId,
    this.sexuality,
    this.sexualityId,
    this.intent,
    this.intentId,
    this.languages = const [],
    this.languageIds = const [],
    this.turnOns = const [],
    this.turnOnIds = const [],
    this.images = const [],
    this.mood,
    this.city,
    this.state,
    this.country,
    this.latitude,
    this.longitude,
    this.distance,
    this.lastActive,
    this.isVerified = false,
    this.isIdentityVerified = false,
    this.isOnline = false,
    this.isLiked = false,
    this.isDiscoverable = false,
    this.preferredGenderIds = const [],
    this.themeConfig,
  });

  /// Mirrors backend `UserProfile.is_discoverable` (core onboarding fields).
  bool get hasCoreOnboardingFields =>
      (username?.isNotEmpty ?? false) &&
      dateOfBirth != null &&
      genderId != null &&
      sexualityId != null &&
      preferredGenderIds.isNotEmpty;

  String get displayUsername => username ?? 'user';

  String? get primaryImageUrl {
    if (images.isEmpty) return null;
    final primary = images.where((i) => i.isPrimary).toList();
    return primary.isNotEmpty ? primary.first.url : images.first.url;
  }

  bool get hasLocation =>
      latitude != null && longitude != null;

  String get locationLabel {
    final parts = <String>[
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
      if (state != null && state!.trim().isNotEmpty) state!.trim(),
      if (country != null && country!.trim().isNotEmpty) country!.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    if (hasLocation) {
      return '${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}';
    }
    return 'Not set';
  }

  String get distanceText {
    if (hideDistance || distance == null) return '';
    if (distance! < 1) return 'Nearby';
    return '${distance!.toStringAsFixed(0)} km away';
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // Parse images
    List<ProfileImage> images = [];
    if (json['images'] != null) {
      images = (json['images'] as List)
          .map((i) => ProfileImage.fromJson(i))
          .toList();
    }

    List<String> parseIdList(dynamic rawList) {
      if (rawList is! List) return [];
      return rawList
          .map((item) =>
              item is Map ? (item['id'] ?? '').toString() : item.toString())
          .where((id) => id.isNotEmpty)
          .toList();
    }

    List<String> parseNamedList(
      dynamic rawList, {
      dynamic detailList,
    }) {
      if (detailList is List && detailList.isNotEmpty) {
        return detailList
            .map((item) => item is Map ? (item['name'] ?? '').toString() : item.toString())
            .where((name) => name.isNotEmpty)
            .toList();
      }
      if (rawList is! List) return [];
      return rawList
          .map((item) => item is Map ? (item['name'] ?? '').toString() : item.toString())
          .where((name) => name.isNotEmpty)
          .toList();
    }

    // Parse languages (stored as UUID list; names come from languages_detail if present)
    final langIds = parseIdList(json['languages']);
    final langs = parseNamedList(
      json['languages'],
      detailList: json['languages_detail'],
    );

    // Parse turn_ons / interests
    final turnOnIdList = parseIdList(json['turn_ons']);
    final turnOns = parseNamedList(
      json['turn_ons'],
      detailList: json['turn_ons_detail'],
    );

    // Parse theme
    ThemeConfig? theme;
    if (json['theme'] != null) {
      theme = ThemeConfig.fromJson(json['theme']);
    } else if (json['layout_id'] != null || json['bg_id'] != null) {
      theme = ThemeConfig(
        layoutId: json['layout_id'],
        bgId: json['bg_id'],
        bgVariantId: json['bg_variant_id'],
        colorToken: json['color_token'],
      );
    }

    String? parseOptionName(dynamic field, String detailKey) {
      if (field is Map) return field['name']?.toString();
      final detail = json[detailKey];
      if (detail is Map) return detail['name']?.toString();
      if (field != null) return field.toString();
      return null;
    }

    String? parseOptionId(dynamic field) {
      if (field is Map) return field['id']?.toString();
      return field?.toString();
    }

    // Parse mood from current_moods_detail
    String? mood;
    if (json['current_moods_detail'] is List &&
        (json['current_moods_detail'] as List).isNotEmpty) {
      final first = (json['current_moods_detail'] as List).first;
      if (first is Map) mood = first['name']?.toString();
    }
    mood ??= json['mood']?.toString();

    List<String> preferredGenderIds = [];
    final rawPreferred = json['preferred_genders'];
    if (rawPreferred is List) {
      preferredGenderIds = rawPreferred
          .map((item) =>
              item is Map ? (item['id'] ?? '').toString() : item.toString())
          .where((id) => id.isNotEmpty)
          .toList();
    }
    if (preferredGenderIds.isEmpty && json['preferred_genders_detail'] is List) {
      preferredGenderIds = (json['preferred_genders_detail'] as List)
          .map((item) =>
              item is Map ? (item['id'] ?? '').toString() : item.toString())
          .where((id) => id.isNotEmpty)
          .toList();
    }

    return UserProfile(
      id: json['id']?.toString() ?? '',
      username: json['username'],
      displayName: json['display_name'] ?? json['name'],
      email: json['email'],
      bio: json['bio'],
      dateOfBirth: json['date_of_birth'] ?? json['dob'],
      age: _parseInt(json['age']),
      hideAge: json['hide_age'] ?? false,
      hideDistance: json['hide_distance'] ?? false,
      gender: parseOptionName(json['gender'], 'gender_detail'),
      genderId: parseOptionId(json['gender']) ?? json['gender_id']?.toString(),
      sexuality: parseOptionName(json['sexuality'], 'sexuality_detail'),
      sexualityId:
          parseOptionId(json['sexuality']) ?? json['sexuality_id']?.toString(),
      intent: parseOptionName(json['intent'], 'intent_detail'),
      intentId: parseOptionId(json['intent']) ?? json['intent_id']?.toString(),
      languages: langs,
      languageIds: langIds,
      turnOns: turnOns,
      turnOnIds: turnOnIdList,
      images: images,
      mood: mood,
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      distance: _parseDouble(json['distance_km']) ??
          _parseDouble(json['distance']),
      lastActive: json['last_active'],
      isVerified: json['is_verified'] ?? json['is_identity_verified'] ?? false,
      isIdentityVerified: json['is_identity_verified'] ?? false,
      isOnline: json['is_online'] ?? false,
      isLiked: json['is_liked'] ?? false,
      isDiscoverable: json['is_discoverable'] ?? false,
      preferredGenderIds: preferredGenderIds,
      themeConfig: theme,
    );
  }

  Map<String, dynamic> toUpdateJson() => {
        if (username != null) 'username': username,
        if (displayName != null) 'display_name': displayName,
        if (bio != null) 'bio': bio,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (genderId != null) 'gender': genderId,
        if (sexualityId != null) 'sexuality': sexualityId,
        if (intentId != null) 'intent': intentId,
        if (mood != null) 'mood': mood,
      };

  UserProfile copyWith({
    String? username,
    String? displayName,
    String? bio,
    String? dateOfBirth,
    String? gender,
    String? genderId,
    String? sexuality,
    String? sexualityId,
    String? intent,
    String? intentId,
    List<String>? languages,
    List<String>? languageIds,
    List<String>? turnOns,
    List<String>? turnOnIds,
    List<ProfileImage>? images,
    String? mood,
    String? city,
    String? state,
    String? country,
    double? latitude,
    double? longitude,
    bool? isLiked,
    bool? isVerified,
    bool? isIdentityVerified,
    bool? isDiscoverable,
    List<String>? preferredGenderIds,
    ThemeConfig? themeConfig,
  }) =>
      UserProfile(
        id: id,
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        email: email,
        bio: bio ?? this.bio,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        age: age,
        hideAge: hideAge,
        hideDistance: hideDistance,
        gender: gender ?? this.gender,
        genderId: genderId ?? this.genderId,
        sexuality: sexuality ?? this.sexuality,
        sexualityId: sexualityId ?? this.sexualityId,
        intent: intent ?? this.intent,
        intentId: intentId ?? this.intentId,
        languages: languages ?? this.languages,
        languageIds: languageIds ?? this.languageIds,
        turnOns: turnOns ?? this.turnOns,
        turnOnIds: turnOnIds ?? this.turnOnIds,
        images: images ?? this.images,
        mood: mood ?? this.mood,
        city: city ?? this.city,
        state: state ?? this.state,
        country: country ?? this.country,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        distance: distance,
        lastActive: lastActive,
        isOnline: isOnline,
        isLiked: isLiked ?? this.isLiked,
        isVerified: isVerified ?? this.isVerified,
        isIdentityVerified: isIdentityVerified ?? this.isIdentityVerified,
        isDiscoverable: isDiscoverable ?? this.isDiscoverable,
        preferredGenderIds: preferredGenderIds ?? this.preferredGenderIds,
        themeConfig: themeConfig ?? this.themeConfig,
      );
}
