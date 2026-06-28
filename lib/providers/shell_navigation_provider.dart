import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShellNavigationState {
  final int tabIndex;
  final bool openProfileEdit;

  const ShellNavigationState({
    this.tabIndex = 0,
    this.openProfileEdit = false,
  });

  ShellNavigationState copyWith({
    int? tabIndex,
    bool? openProfileEdit,
    bool clearEditRequest = false,
  }) =>
      ShellNavigationState(
        tabIndex: tabIndex ?? this.tabIndex,
        openProfileEdit:
            clearEditRequest ? false : (openProfileEdit ?? this.openProfileEdit),
      );
}

class ShellNavigationNotifier extends StateNotifier<ShellNavigationState> {
  ShellNavigationNotifier() : super(const ShellNavigationState());

  void goToProfileEdit() {
    state = state.copyWith(tabIndex: 3, openProfileEdit: true);
  }

  void setTab(int index) {
    state = state.copyWith(tabIndex: index, clearEditRequest: true);
  }

  void clearEditRequest() {
    state = state.copyWith(clearEditRequest: true);
  }
}

final shellNavigationProvider =
    StateNotifierProvider<ShellNavigationNotifier, ShellNavigationState>(
  (ref) => ShellNavigationNotifier(),
);