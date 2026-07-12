import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants.dart';

/// Tracks profiles the user liked within the 36h cooldown window.
/// Persists locally so "Already liked" survives feed refreshes and scroll-back.
class LikeTrackerService {
  static const _storage = FlutterSecureStorage();

  Map<String, int> _likedAtByUserId = {};
  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final raw = await _storage.read(key: AppConstants.keyLikeTtlCache);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          _likedAtByUserId = decoded.map(
            (key, value) => MapEntry(key.toString(), (value as num).toInt()),
          );
        }
      } catch (_) {
        _likedAtByUserId = {};
      }
    }
    await _pruneExpired(save: true);
    _loaded = true;
  }

  bool isActive(String userId) {
    final likedAt = _likedAtByUserId[userId];
    if (likedAt == null) return false;
    return _secondsSince(likedAt) < AppConstants.likeTtlSeconds;
  }

  Future<void> recordLike(String userId) async {
    await ensureLoaded();
    _likedAtByUserId[userId] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _persist();
  }

  Future<void> _pruneExpired({bool save = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _likedAtByUserId.removeWhere(
      (_, likedAt) => now - likedAt >= AppConstants.likeTtlSeconds,
    );
    if (save) await _persist();
  }

  int _secondsSince(int likedAt) =>
      (DateTime.now().millisecondsSinceEpoch ~/ 1000) - likedAt;

  Future<void> _persist() async {
    await _storage.write(
      key: AppConstants.keyLikeTtlCache,
      value: jsonEncode(_likedAtByUserId),
    );
  }

  Future<void> clearAll() async {
    _likedAtByUserId = {};
    _loaded = true;
    await _storage.delete(key: AppConstants.keyLikeTtlCache);
  }
}