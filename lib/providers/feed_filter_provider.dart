import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/feed_filters.dart';

class FeedFiltersNotifier extends StateNotifier<FeedFilters> {
  FeedFiltersNotifier() : super(FeedFilters.defaults);

  void update(FeedFilters filters) => state = filters;

  void reset() => state = FeedFilters.defaults;
}

final feedFiltersProvider =
    StateNotifierProvider<FeedFiltersNotifier, FeedFilters>(
  (ref) => FeedFiltersNotifier(),
);