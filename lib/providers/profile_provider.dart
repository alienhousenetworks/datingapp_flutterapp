import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';

// ─── Profile State ───────────────────────────────────────────

class ProfileState {
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.error,
  });

  ProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    String? error,
  }) =>
      ProfileState(
        profile: profile ?? this.profile,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── Profile Notifier ────────────────────────────────────────

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileService _service;

  ProfileNotifier(this._service) : super(const ProfileState());

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _service.getMyProfile(),
        _service.getAuthSession(),
      ]);
      final profile = results[0] as UserProfile;
      final session = results[1] as Map<String, dynamic>;
      final identityVerified = session['is_identity_verified'] == true;
      state = state.copyWith(
        profile: profile.copyWith(
          isIdentityVerified: identityVerified,
          isVerified: identityVerified || profile.isVerified,
        ),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updated = await _service.updateMyProfile(data);
      state = state.copyWith(profile: updated, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void setProfile(UserProfile profile) {
    state = state.copyWith(profile: profile);
  }

  void setIdentityVerified(bool verified) {
    final profile = state.profile;
    if (profile == null) return;
    state = state.copyWith(
      profile: profile.copyWith(
        isIdentityVerified: verified,
        isVerified: verified,
      ),
    );
  }
}

// ─── Options State ───────────────────────────────────────────

class OptionsState {
  final List<NamedOption> genders;
  final List<NamedOption> sexualities;
  final List<NamedOption> intents;
  final List<NamedOption> languages;
  final List<NamedOption> turnOns;
  final List<NamedOption> moodOptions;
  final bool isLoading;

  const OptionsState({
    this.genders = const [],
    this.sexualities = const [],
    this.intents = const [],
    this.languages = const [],
    this.turnOns = const [],
    this.moodOptions = const [],
    this.isLoading = false,
  });

  OptionsState copyWith({
    List<NamedOption>? genders,
    List<NamedOption>? sexualities,
    List<NamedOption>? intents,
    List<NamedOption>? languages,
    List<NamedOption>? turnOns,
    List<NamedOption>? moodOptions,
    bool? isLoading,
  }) =>
      OptionsState(
        genders: genders ?? this.genders,
        sexualities: sexualities ?? this.sexualities,
        intents: intents ?? this.intents,
        languages: languages ?? this.languages,
        turnOns: turnOns ?? this.turnOns,
        moodOptions: moodOptions ?? this.moodOptions,
        isLoading: isLoading ?? this.isLoading,
      );
}

class OptionsNotifier extends StateNotifier<OptionsState> {
  final ProfileService _service;

  OptionsNotifier(this._service) : super(const OptionsState());

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _service.getGenders(),
        _service.getSexualities(),
        _service.getIntents(),
        _service.getLanguages(),
        _service.getTurnOns(),
        _service.getMoodOptions(),
      ]);
      state = OptionsState(
        genders: results[0],
        sexualities: results[1],
        intents: results[2],
        languages: results[3],
        turnOns: results[4],
        moodOptions: results[5],
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }
}

// ─── Providers ───────────────────────────────────────────────

final profileServiceProvider = Provider<ProfileService>((ref) => ProfileService());

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(ref.read(profileServiceProvider));
});

final optionsProvider =
    StateNotifierProvider<OptionsNotifier, OptionsState>((ref) {
  return OptionsNotifier(ref.read(profileServiceProvider));
});
