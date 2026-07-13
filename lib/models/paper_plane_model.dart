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
class CatchResult {
  final String planeId;
  final String deliveryId;
  final String message;
  final String sticker;
  final String senderFirstName;
  final int? senderAge;
  final String senderCity;
  final DateTime decisionDeadline;

  const CatchResult({
    required this.planeId,
    required this.deliveryId,
    required this.message,
    required this.sticker,
    required this.senderFirstName,
    this.senderAge,
    required this.senderCity,
    required this.decisionDeadline,
  });

  factory CatchResult.fromJson(Map<String, dynamic> json) {
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
