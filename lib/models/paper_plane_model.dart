// ─── Paper Plane Models ──────────────────────────────────────

enum PlaneStatus { flying, caught, expired, cancelled }

enum DeliveryStatus { notified, gameStarted, caught, missed, passed }

PlaneStatus _parsePlaneStatus(String? s) {
  switch (s) {
    case 'FLYING':
      return PlaneStatus.flying;
    case 'CAUGHT':
      return PlaneStatus.caught;
    case 'EXPIRED':
      return PlaneStatus.expired;
    case 'CANCELLED':
      return PlaneStatus.cancelled;
    default:
      return PlaneStatus.flying;
  }
}

DeliveryStatus _parseDeliveryStatus(String? s) {
  switch (s) {
    case 'NOTIFIED':
      return DeliveryStatus.notified;
    case 'GAME_STARTED':
      return DeliveryStatus.gameStarted;
    case 'CAUGHT':
      return DeliveryStatus.caught;
    case 'MISSED':
      return DeliveryStatus.missed;
    case 'PASSED':
      return DeliveryStatus.passed;
    default:
      return DeliveryStatus.notified;
  }
}

// ─── PaperPlane — sender's own plane ─────────────────────────
class PaperPlane {
  final String id;
  final String message;
  final String sticker;
  final PlaneStatus status;
  final DateTime launchedAt;
  final DateTime expiresAt;
  final String senderCity;
  final PlaneCatchInfo? catchInfo;

  const PaperPlane({
    required this.id,
    required this.message,
    required this.sticker,
    required this.status,
    required this.launchedAt,
    required this.expiresAt,
    required this.senderCity,
    this.catchInfo,
  });

  bool get isFlying => status == PlaneStatus.flying;
  bool get isCaught => status == PlaneStatus.caught;
  bool get isExpired => status == PlaneStatus.expired;

  factory PaperPlane.fromJson(Map<String, dynamic> json) {
    return PaperPlane(
      id: json['id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      sticker: json['sticker']?.toString() ?? '',
      status: _parsePlaneStatus(json['status']),
      launchedAt:
          DateTime.tryParse(json['launched_at'] ?? '') ?? DateTime.now(),
      expiresAt: DateTime.tryParse(json['expires_at'] ?? '') ?? DateTime.now(),
      senderCity: json['sender_city']?.toString() ?? '',
      catchInfo: json['catch_info'] != null
          ? PlaneCatchInfo.fromJson(
              Map<String, dynamic>.from(json['catch_info'] as Map))
          : null,
    );
  }
}

class PlaneCatchInfo {
  final DateTime caughtAt;
  final String? catcherCity;
  final String? conversationId;

  const PlaneCatchInfo({
    required this.caughtAt,
    this.catcherCity,
    this.conversationId,
  });

  factory PlaneCatchInfo.fromJson(Map<String, dynamic> json) {
    return PlaneCatchInfo(
      caughtAt: DateTime.tryParse(json['caught_at'] ?? '') ?? DateTime.now(),
      catcherCity: json['catcher_city']?.toString(),
      conversationId: json['conversation_id']?.toString(),
    );
  }
}

// ─── PlaneDelivery — recipient's inbox item ───────────────────
class PlaneDelivery {
  final String id;
  final String planeId;
  final String senderCity;
  final String sticker;
  final DeliveryStatus status;
  final DateTime notifiedAt;
  final DateTime notificationDeadline;
  final DateTime? gameDeadline;
  final DateTime? decisionDeadline;

  const PlaneDelivery({
    required this.id,
    required this.planeId,
    required this.senderCity,
    required this.sticker,
    required this.status,
    required this.notifiedAt,
    required this.notificationDeadline,
    this.gameDeadline,
    this.decisionDeadline,
  });

  bool get isActionable =>
      status == DeliveryStatus.notified ||
      status == DeliveryStatus.gameStarted ||
      status == DeliveryStatus.caught;

  factory PlaneDelivery.fromJson(Map<String, dynamic> json) {
    return PlaneDelivery(
      id: json['id']?.toString() ?? '',
      planeId: json['plane_id']?.toString() ?? '',
      senderCity: json['sender_city']?.toString() ?? '',
      sticker: json['sticker']?.toString() ?? '',
      status: _parseDeliveryStatus(json['status']),
      notifiedAt:
          DateTime.tryParse(json['notified_at'] ?? '') ?? DateTime.now(),
      notificationDeadline:
          DateTime.tryParse(json['notification_deadline'] ?? '') ??
              DateTime.now(),
      gameDeadline: DateTime.tryParse(json['game_deadline'] ?? ''),
      decisionDeadline: DateTime.tryParse(json['decision_deadline'] ?? ''),
    );
  }
}

// ─── CatchResult — revealed after in-game catch ──────────────
class SenderProfileImage {
  final String id;
  final String imageUrl;
  final int order;

  const SenderProfileImage({
    required this.id,
    required this.imageUrl,
    required this.order,
  });

  factory SenderProfileImage.fromJson(Map<String, dynamic> json) {
    return SenderProfileImage(
      id: json['id']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      order: (json['order'] as int?) ?? 0,
    );
  }
}

class SenderMood {
  final String id;
  final String name;

  const SenderMood({required this.id, required this.name});

  factory SenderMood.fromJson(Map<String, dynamic> json) {
    return SenderMood(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class SenderProfileSnapshot {
  final String userId;
  final String username;
  final String name;
  final int? age;
  final String city;
  final String bio;
  final String? genderName;
  final bool isOnline;
  final bool isVerified;
  final List<SenderProfileImage> profileImages;
  final List<SenderMood> currentMoods;
  final List<SenderMood> intents;
  final List<SenderMood> turnOns;
  final List<String> hottakes;

  const SenderProfileSnapshot({
    required this.userId,
    required this.username,
    required this.name,
    this.age,
    required this.city,
    required this.bio,
    this.genderName,
    required this.isOnline,
    required this.isVerified,
    required this.profileImages,
    required this.currentMoods,
    required this.intents,
    required this.turnOns,
    required this.hottakes,
  });

  String? get firstImageUrl =>
      profileImages.isNotEmpty ? profileImages.first.imageUrl : null;

  factory SenderProfileSnapshot.fromJson(Map<String, dynamic> json) {
    List<SenderProfileImage> images = [];
    if (json['profile_images'] is List) {
      images = (json['profile_images'] as List)
          .map((e) => SenderProfileImage.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    List<SenderMood> moods = [];
    if (json['current_moods'] is List) {
      moods = (json['current_moods'] as List)
          .map((e) =>
              SenderMood.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    List<SenderMood> intents = [];
    if (json['intents'] is List) {
      intents = (json['intents'] as List)
          .map((e) =>
              SenderMood.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    List<SenderMood> turnOns = [];
    if (json['turn_ons'] is List) {
      turnOns = (json['turn_ons'] as List)
          .map((e) =>
              SenderMood.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    List<String> hottakes = [];
    if (json['hottakes'] is List) {
      hottakes = (json['hottakes'] as List)
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final genderRaw = json['gender'];
    String? genderName;
    if (genderRaw is Map) {
      genderName = genderRaw['name']?.toString();
    }

    return SenderProfileSnapshot(
      userId: json['user_id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      age: json['age'] as int?,
      city: json['city']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      genderName: genderName,
      isOnline: json['is_online'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      profileImages: images,
      currentMoods: moods,
      intents: intents,
      turnOns: turnOns,
      hottakes: hottakes,
    );
  }
}

class CatchResult {
  final String planeId;
  final String deliveryId;
  final String message;
  final String sticker;
  final String senderFirstName;
  final int? senderAge;
  final String senderCity;
  final DateTime decisionDeadline;
  final SenderProfileSnapshot? senderProfile;

  const CatchResult({
    required this.planeId,
    required this.deliveryId,
    required this.message,
    required this.sticker,
    required this.senderFirstName,
    this.senderAge,
    required this.senderCity,
    required this.decisionDeadline,
    this.senderProfile,
  });

  factory CatchResult.fromJson(Map<String, dynamic> json) {
    SenderProfileSnapshot? profile;
    if (json['sender_profile'] is Map) {
      profile = SenderProfileSnapshot.fromJson(
          Map<String, dynamic>.from(json['sender_profile'] as Map));
    }
    return CatchResult(
      planeId: json['plane_id']?.toString() ?? '',
      deliveryId: json['delivery_id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      sticker: json['sticker']?.toString() ?? '',
      senderFirstName: json['sender_first_name']?.toString() ?? 'Someone',
      senderAge: json['sender_age'] as int?,
      senderCity: json['sender_city']?.toString() ?? '',
      decisionDeadline:
          DateTime.tryParse(json['decision_deadline'] ?? '') ?? DateTime.now(),
      senderProfile: profile,
    );
  }
}

// ─── GameConfig — returned by start-game endpoint ─────────────
class GameConfig {
  final String deliveryId;
  final DateTime gameDeadline;
  final int gameWindowSeconds;
  final int planePathSeed; // deterministic randomness for plane trajectory

  const GameConfig({
    required this.deliveryId,
    required this.gameDeadline,
    required this.gameWindowSeconds,
    required this.planePathSeed,
  });

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    return GameConfig(
      deliveryId: json['delivery_id']?.toString() ?? '',
      gameDeadline:
          DateTime.tryParse(json['game_deadline'] ?? '') ?? DateTime.now(),
      gameWindowSeconds: json['game_window_seconds'] as int? ?? 60,
      planePathSeed: json['plane_path_seed'] as int? ?? 0,
    );
  }
}

// ─── SkyPlane — plane flying in the sky ───────────────────────
class SkyPlane {
  final String id;
  final String sticker;
  final double distanceKm;
  final bool isHighPriority;

  const SkyPlane({
    required this.id,
    required this.sticker,
    required this.distanceKm,
    required this.isHighPriority,
  });

  factory SkyPlane.fromJson(Map<String, dynamic> json) {
    return SkyPlane(
      id: json['id']?.toString() ?? '',
      sticker: json['sticker']?.toString() ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      isHighPriority: json['is_high_priority'] as bool? ?? false,
    );
  }
}
