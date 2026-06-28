import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/like_tracker_service.dart';

final likeTrackerServiceProvider = Provider<LikeTrackerService>(
  (ref) => LikeTrackerService(),
);

/// Bumps whenever the local like TTL cache changes so widgets rebuild.
class LikeTrackerNotifier extends StateNotifier<int> {
  final LikeTrackerService _service;

  LikeTrackerNotifier(this._service) : super(0);

  Future<void> ensureLoaded() => _service.ensureLoaded();

  bool isActive(String userId) => _service.isActive(userId);

  Future<void> recordLike(String userId) async {
    await _service.recordLike(userId);
    state++;
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    state++;
  }
}

final likeTrackerProvider =
    StateNotifierProvider<LikeTrackerNotifier, int>((ref) {
  return LikeTrackerNotifier(ref.read(likeTrackerServiceProvider));
});