import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';
import 'profile_provider.dart';

class LocationSyncState {
  final bool isSyncing;
  final String? lastError;

  const LocationSyncState({
    this.isSyncing = false,
    this.lastError,
  });

  LocationSyncState copyWith({bool? isSyncing, String? lastError}) =>
      LocationSyncState(
        isSyncing: isSyncing ?? this.isSyncing,
        lastError: lastError,
      );
}

class LocationSyncNotifier extends StateNotifier<LocationSyncState> {
  final Ref _ref;

  LocationSyncNotifier(this._ref) : super(const LocationSyncState());

  LocationService get _locationService => _ref.read(locationServiceProvider);

  /// Fetches GPS and PATCHes latitude/longitude to the backend.
  Future<bool> syncToProfile({bool force = false}) async {
    if (state.isSyncing) return false;

    final profile = _ref.read(profileProvider).profile;
    if (!force && profile != null && profile.hasLocation) {
      return true;
    }

    state = state.copyWith(isSyncing: true, lastError: null);

    final result = await _locationService.getCurrentLocation();
    if (result.location == null) {
      state = state.copyWith(
        isSyncing: false,
        lastError: result.error ?? 'Location unavailable',
      );
      return false;
    }

    final loc = result.location!;
    final ok =
        await _ref.read(profileProvider.notifier).updateProfile({
      'latitude': loc.latitude,
      'longitude': loc.longitude,
    });

    state = state.copyWith(
      isSyncing: false,
      lastError: ok ? null : _ref.read(profileProvider).error,
    );
    return ok;
  }
}

final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());

final locationSyncProvider =
    StateNotifierProvider<LocationSyncNotifier, LocationSyncState>((ref) {
  return LocationSyncNotifier(ref);
});