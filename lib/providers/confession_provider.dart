import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/confession_model.dart';
import '../services/confession_service.dart';
import 'location_provider.dart';
import 'profile_provider.dart';

class ConfessionsState {
  final List<Confession> items;
  final List<MoodTagOption> moodTags;
  final bool isLoading;
  final bool isPosting;
  final String? error;
  final String? postError;
  final String? selectedMoodTag;

  const ConfessionsState({
    this.items = const [],
    this.moodTags = const [],
    this.isLoading = false,
    this.isPosting = false,
    this.error,
    this.postError,
    this.selectedMoodTag,
  });

  ConfessionsState copyWith({
    List<Confession>? items,
    List<MoodTagOption>? moodTags,
    bool? isLoading,
    bool? isPosting,
    String? error,
    String? postError,
    String? selectedMoodTag,
    bool clearError = false,
    bool clearPostError = false,
  }) =>
      ConfessionsState(
        items: items ?? this.items,
        moodTags: moodTags ?? this.moodTags,
        isLoading: isLoading ?? this.isLoading,
        isPosting: isPosting ?? this.isPosting,
        error: clearError ? null : (error ?? this.error),
        postError: clearPostError ? null : (postError ?? this.postError),
        selectedMoodTag: selectedMoodTag ?? this.selectedMoodTag,
      );
}

class ConfessionsNotifier extends StateNotifier<ConfessionsState> {
  final Ref _ref;
  final ConfessionService _service;

  ConfessionsNotifier(this._ref, this._service) : super(const ConfessionsState());

  Future<({double lat, double lon})?> _resolveCoords() async {
    final profile = _ref.read(profileProvider).profile;
    if (profile != null && profile.hasLocation) {
      return (lat: profile.latitude!, lon: profile.longitude!);
    }

    await _ref.read(locationSyncProvider.notifier).syncToProfile();
    final refreshed = _ref.read(profileProvider).profile;
    if (refreshed != null && refreshed.hasLocation) {
      return (lat: refreshed.latitude!, lon: refreshed.longitude!);
    }

    final gps = await _ref.read(locationServiceProvider).getCurrentLocation();
    final loc = gps.location;
    if (loc != null) {
      return (lat: loc.latitude, lon: loc.longitude);
    }
    return null;
  }

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final coords = await _resolveCoords();
      final items = await _service.getFeed(
        latitude: coords?.lat,
        longitude: coords?.lon,
      );

      var moodTags = state.moodTags;
      if (moodTags.isEmpty) {
        moodTags = await _service.getMoodTags();
      }

      state = state.copyWith(
        items: items,
        moodTags: moodTags,
        isLoading: false,
      );
    } on ConfessionException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void selectMood(String? moodTag) {
    state = state.copyWith(selectedMoodTag: moodTag);
  }

  Future<bool> post(String text) async {
    if (state.isPosting) return false;
    state = state.copyWith(isPosting: true, clearPostError: true);

    try {
      final coords = await _resolveCoords();
      if (coords == null) {
        state = state.copyWith(
          isPosting: false,
          postError:
              'Location is required. Enable location access in Settings.',
        );
        return false;
      }

      await _service.post(
        text: text,
        latitude: coords.lat,
        longitude: coords.lon,
        moodTag: state.selectedMoodTag,
      );

      state = state.copyWith(isPosting: false);
      await load();
      return true;
    } on ConfessionException catch (e) {
      state = state.copyWith(isPosting: false, postError: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isPosting: false,
        postError: 'Could not post confession. Try again.',
      );
      return false;
    }
  }

  Future<void> relate(String confessionId) async {
    try {
      final count = await _service.relate(confessionId);
      final updated = state.items.map((item) {
        if (item.id != confessionId) return item;
        return item.copyWith(
          relateCount: count > 0 ? count : item.relateCount + 1,
        );
      }).toList();
      state = state.copyWith(items: updated);
    } catch (_) {}
  }

  Future<String?> chatRequest(String confessionId, String message) async {
    try {
      await _service.chatRequest(confessionId, message);
      final updated = state.items.map((item) {
        if (item.id != confessionId) return item;
        return item.copyWith(hasRequestedChat: true);
      }).toList();
      state = state.copyWith(items: updated);
      return null;
    } on ConfessionException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not send chat request. Try again.';
    }
  }

  Future<String?> repost(String confessionId, {String? thought}) async {
    try {
      await _service.repost(confessionId, thought: thought);
      final updated = state.items.map((item) {
        if (item.id != confessionId) return item;
        return item.copyWith(repostCount: item.repostCount + 1);
      }).toList();
      state = state.copyWith(items: updated);
      return null;
    } on ConfessionException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not repost. Try again.';
    }
  }
}

final confessionServiceProvider =
    Provider<ConfessionService>((ref) => ConfessionService());

final confessionsProvider =
    StateNotifierProvider<ConfessionsNotifier, ConfessionsState>((ref) {
  return ConfessionsNotifier(ref, ref.read(confessionServiceProvider));
});