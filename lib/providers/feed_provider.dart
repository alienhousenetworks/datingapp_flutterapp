import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feed_filters.dart';
import '../models/feed_item.dart';
import '../models/feed_page.dart';
import '../services/analytics_service.dart';
import '../services/feed_service.dart';
import 'feed_filter_provider.dart';
import 'like_tracker_provider.dart';

class FeedState {
  final List<FeedItem> items;
  final int currentIndex;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int? nextCursor;
  final String? error;
  final bool profileIncomplete;
  final String? profileIncompleteMessage;
  final String? emptyReason;

  const FeedState({
    this.items = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.nextCursor,
    this.error,
    this.profileIncomplete = false,
    this.profileIncompleteMessage,
    this.emptyReason,
  });

  FeedItem? get currentItem =>
      items.isNotEmpty && currentIndex < items.length
          ? items[currentIndex]
          : null;

  FeedState copyWith({
    List<FeedItem>? items,
    int? currentIndex,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? nextCursor,
    bool clearNextCursor = false,
    String? error,
    bool? profileIncomplete,
    String? profileIncompleteMessage,
    String? emptyReason,
  }) =>
      FeedState(
        items: items ?? this.items,
        currentIndex: currentIndex ?? this.currentIndex,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
        error: error,
        profileIncomplete: profileIncomplete ?? this.profileIncomplete,
        profileIncompleteMessage:
            profileIncompleteMessage ?? this.profileIncompleteMessage,
        emptyReason: emptyReason,
      );
}

class FeedNotifier extends StateNotifier<FeedState> {
  final Ref _ref;
  final FeedService _service;
  final LikeTrackerNotifier _likeTracker;

  FeedNotifier(this._ref, this._service, this._likeTracker)
      : super(const FeedState());

  FeedFilters get _filters => _ref.read(feedFiltersProvider);

  /// Fresh load from cursor 0. Backend keeps the Redis cache; read-time
  /// filtering removes already-liked/passed users from each chunk.
  Future<void> loadFeed() async {
    await _loadFeed(refresh: false);
  }

  /// Busts the server-side feed cache so new mutual-preference profiles appear.
  Future<void> refreshFeed() async {
    await _loadFeed(refresh: true);
  }

  Future<void> _loadFeed({required bool refresh}) async {
    if (state.isLoading) return;
    state = state.copyWith(
      isLoading: true,
      error: null,
      profileIncomplete: false,
      profileIncompleteMessage: null,
      emptyReason: null,
      clearNextCursor: true,
    );
    try {
      await _likeTracker.ensureLoaded();
      final page = await _service.getFeed(
        refresh: refresh,
        filters: _filters,
      );
      _applyPage(page, append: false, resetIndex: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Append the next chunk using [next_cursor]. Does not invalidate cache.
  Future<void> loadMore() async {
    if (state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore ||
        state.nextCursor == null) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, error: null);
    try {
      await _likeTracker.ensureLoaded();
      final page = await _service.getFeed(
        cursor: state.nextCursor!,
        filters: _filters,
      );
      _applyPage(page, append: true, resetIndex: false);
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void _applyPage(
    FeedPage page, {
    required bool append,
    required bool resetIndex,
  }) {
    if (page.profileIncomplete) {
      state = state.copyWith(
        items: append ? state.items : const [],
        isLoading: false,
        isLoadingMore: false,
        hasMore: false,
        clearNextCursor: true,
        profileIncomplete: true,
        profileIncompleteMessage: page.message,
        emptyReason: null,
      );
      return;
    }

    final enriched = _enrichWithLikeState(page.items);
    final deduplicated = _deduplicate(enriched);
    final merged = append ? _mergeItems(state.items, deduplicated) : deduplicated;

    state = state.copyWith(
      items: merged,
      currentIndex: resetIndex ? 0 : state.currentIndex,
      isLoading: false,
      isLoadingMore: false,
      hasMore: page.hasMore,
      nextCursor: page.nextCursor,
      clearNextCursor: !page.hasMore,
      profileIncomplete: false,
      emptyReason: merged.isEmpty ? page.emptyReason : null,
    );
  }

  List<FeedItem> _deduplicate(List<FeedItem> items) {
    final seen = <String>{};
    final unique = <FeedItem>[];
    for (final item in items) {
      if (!seen.contains(item.profile.id)) {
        unique.add(item);
        seen.add(item.profile.id);
      }
    }
    return unique;
  }

  List<FeedItem> _enrichWithLikeState(List<FeedItem> items) {
    return items
        .map((item) {
          final liked =
              item.profile.isLiked || _likeTracker.isActive(item.profile.id);
          return item.copyWith(
            profile: item.profile.copyWith(isLiked: liked),
          );
        })
        .toList();
  }

  List<FeedItem> _mergeItems(List<FeedItem> existing, List<FeedItem> incoming) {
    final seen = existing.map((e) => e.profile.id).toSet();
    final merged = [...existing];
    for (final item in incoming) {
      if (!seen.contains(item.profile.id)) {
        merged.add(item);
        seen.add(item.profile.id);
      }
    }
    return merged;
  }

  void _markProfileLiked(String targetUserId) {
    final updated = state.items.map((item) {
      if (item.profile.id != targetUserId) return item;
      return item.copyWith(
        profile: item.profile.copyWith(isLiked: true),
      );
    }).toList();
    state = state.copyWith(items: updated);
  }

  /// Pass registers a view signal server-side; backend filters at read time.
  /// Remove locally so the user moves on without reloading the cache.
  Future<bool> passProfile(String targetUserId) async {
    try {
      await _service.sendPass(targetUserId);
      AnalyticsService.instance.trackFeedPass(targetUserId);
      final updated =
          state.items.where((item) => item.profile.id != targetUserId).toList();
      state = state.copyWith(items: updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> sendDm(String targetUserId, {String? message}) async {
    try {
      final result = await _service.startConversation(
        targetUserId,
        message: message ?? 'Hey! 👋',
      );
      if (result.containsKey('error')) return null;
      return result['conversation_id']?.toString() ??
          result['match_id']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Like is O(1) on the backend — feed cache is not cleared.
  /// Liked profiles stay in the current list; future pages filter them out.
  Future<LikeResult> likeProfile(String targetUserId) async {
    if (_likeTracker.isActive(targetUserId)) {
      return const LikeResult(
        success: false,
        alreadyLiked: true,
        message: 'Already liked within last 36 hours',
      );
    }

    try {
      final result = await _service.sendLike(targetUserId);
      final status = result['status']?.toString() ?? '';
      if (status == 'cooldown' || status == 'liked' || status == 'match') {
        await _likeTracker.recordLike(targetUserId);
        _markProfileLiked(targetUserId);
        AnalyticsService.instance.trackFeedLike(
          targetUserId,
          matched: status == 'match',
        );
        return LikeResult(
          success: status != 'cooldown',
          alreadyLiked: status == 'cooldown',
          matched: status == 'match',
          message: result['message']?.toString(),
        );
      }
      await _likeTracker.recordLike(targetUserId);
      _markProfileLiked(targetUserId);
      return const LikeResult(success: true);
    } catch (_) {
      return const LikeResult(success: false);
    }
  }
}

class LikeResult {
  final bool success;
  final bool alreadyLiked;
  final bool matched;
  final String? message;

  const LikeResult({
    required this.success,
    this.alreadyLiked = false,
    this.matched = false,
    this.message,
  });
}

final feedServiceProvider = Provider<FeedService>((ref) => FeedService());

final feedProvider =
    StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  return FeedNotifier(
    ref,
    ref.read(feedServiceProvider),
    ref.read(likeTrackerProvider.notifier),
  );
});