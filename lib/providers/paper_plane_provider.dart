import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/paper_plane_model.dart';
import '../services/paper_plane_service.dart';

// ─── Sender Provider ──────────────────────────────────────────

class SenderPlaneState {
  final List<PaperPlane> planes;
  final bool isLoading;
  final bool isLaunching;
  final String? error;
  final String? launchSuccess; // plane id just launched

  const SenderPlaneState({
    this.planes = const [],
    this.isLoading = false,
    this.isLaunching = false,
    this.error,
    this.launchSuccess,
  });

  SenderPlaneState copyWith({
    List<PaperPlane>? planes,
    bool? isLoading,
    bool? isLaunching,
    String? error,
    bool clearError = false,
    String? launchSuccess,
    bool clearLaunchSuccess = false,
  }) =>
      SenderPlaneState(
        planes: planes ?? this.planes,
        isLoading: isLoading ?? this.isLoading,
        isLaunching: isLaunching ?? this.isLaunching,
        error: clearError ? null : (error ?? this.error),
        launchSuccess: clearLaunchSuccess
            ? null
            : (launchSuccess ?? this.launchSuccess),
      );

  int get flyingCount =>
      planes.where((p) => p.status == PlaneStatus.flying).length;
}

class SenderPlaneNotifier extends StateNotifier<SenderPlaneState> {
  final PaperPlaneService _service;

  SenderPlaneNotifier(this._service) : super(const SenderPlaneState());

  Future<void> loadMyPlanes() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final planes = await _service.getMyPlanes();
      state = state.copyWith(planes: planes, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> launch(String message, {String sticker = ''}) async {
    state = state.copyWith(isLaunching: true, clearError: true);
    try {
      final plane = await _service.launch(message, sticker: sticker);
      state = state.copyWith(
        planes: [plane, ...state.planes],
        isLaunching: false,
        launchSuccess: plane.id,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLaunching: false, error: e.toString());
      return false;
    }
  }

  Future<void> cancel(String planeId) async {
    try {
      await _service.cancel(planeId);
      await loadMyPlanes();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void clearLaunchSuccess() =>
      state = state.copyWith(clearLaunchSuccess: true);
  void clearError() => state = state.copyWith(clearError: true);
}

final paperPlaneSenderProvider =
    StateNotifierProvider<SenderPlaneNotifier, SenderPlaneState>((ref) {
  return SenderPlaneNotifier(PaperPlaneService());
});

// ─── Catch Game Provider ──────────────────────────────────────

enum GamePhase {
  idle,         // no active delivery
  notified,     // push received, haven't opened game yet
  catching,     // game running — tilt to catch
  revealed,     // net hit plane — message shown, 3-min timer running
  connected,    // user tapped CONNECT
  passed,       // user tapped PASS
  error,
}

class CatchGameState {
  final GamePhase phase;
  final PlaneDelivery? delivery;
  final GameConfig? gameConfig;
  final CatchResult? catchResult;
  final String? conversationId;     // set after CONNECT
  final String? error;

  const CatchGameState({
    this.phase = GamePhase.idle,
    this.delivery,
    this.gameConfig,
    this.catchResult,
    this.conversationId,
    this.error,
  });

  CatchGameState copyWith({
    GamePhase? phase,
    PlaneDelivery? delivery,
    GameConfig? gameConfig,
    CatchResult? catchResult,
    String? conversationId,
    String? error,
    bool clearError = false,
  }) =>
      CatchGameState(
        phase: phase ?? this.phase,
        delivery: delivery ?? this.delivery,
        gameConfig: gameConfig ?? this.gameConfig,
        catchResult: catchResult ?? this.catchResult,
        conversationId: conversationId ?? this.conversationId,
        error: clearError ? null : (error ?? this.error),
      );
}

class CatchGameNotifier extends StateNotifier<CatchGameState> {
  final PaperPlaneService _service;

  CatchGameNotifier(this._service) : super(const CatchGameState());

  /// Called on app open / notification tap — check if a plane is waiting
  Future<void> checkInbox() async {
    try {
      final delivery = await _service.getInbox();
      if (delivery != null && delivery.isActionable) {
        state = state.copyWith(
          phase: delivery.status == DeliveryStatus.gameStarted
              ? GamePhase.catching
              : delivery.status == DeliveryStatus.caught
                  ? GamePhase.revealed
                  : GamePhase.notified,
          delivery: delivery,
        );
      } else {
        state = const CatchGameState(phase: GamePhase.idle);
      }
    } catch (_) {
      // Silently fail — inbox check is background
    }
  }

  /// Called when user opens the catch game screen
  Future<void> startGame() async {
    final deliveryId = state.delivery?.id;
    if (deliveryId == null) return;

    try {
      final config = await _service.startGame(deliveryId);
      state = state.copyWith(phase: GamePhase.catching, gameConfig: config);
    } catch (e) {
      state = state.copyWith(phase: GamePhase.error, error: e.toString());
    }
  }

  /// Called from the game canvas when net collides with plane
  Future<void> planeCaught() async {
    final deliveryId = state.delivery?.id;
    if (deliveryId == null) return;

    try {
      final result = await _service.recordCatch(deliveryId);
      state = state.copyWith(phase: GamePhase.revealed, catchResult: result);
    } catch (e) {
      state = state.copyWith(phase: GamePhase.error, error: e.toString());
    }
  }

  /// Recipient tapped CONNECT
  Future<void> connect() async {
    final deliveryId = state.delivery?.id;
    if (deliveryId == null) return;

    try {
      final conversationId = await _service.connect(deliveryId);
      state = state.copyWith(
        phase: GamePhase.connected,
        conversationId: conversationId,
      );
    } catch (e) {
      state = state.copyWith(phase: GamePhase.error, error: e.toString());
    }
  }

  /// Recipient tapped PASS or decision timer expired
  Future<void> pass() async {
    final deliveryId = state.delivery?.id;
    if (deliveryId != null) {
      try {
        await _service.pass(deliveryId);
      } catch (_) {}
    }
    state = state.copyWith(phase: GamePhase.passed);
  }

  void reset() => state = const CatchGameState(phase: GamePhase.idle);
  void clearError() => state = state.copyWith(clearError: true);
}

final catchGameProvider =
    StateNotifierProvider<CatchGameNotifier, CatchGameState>((ref) {
  return CatchGameNotifier(PaperPlaneService());
});
