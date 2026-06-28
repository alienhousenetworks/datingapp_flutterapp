/// Query filters for GET /api/v1/feed/ — mirrors web DiscoverPage defaults.
enum FeedLocationMode { distance, region }

class FeedFilters {
  final int minAge;
  final int maxAge;
  /// 0 = anywhere (no distance cap). Used only when [locationMode] is distance.
  final int distance;
  final FeedLocationMode locationMode;
  final String? city;
  final String? state;
  final String? country;
  final String? intentId;
  final bool currentlyOnline;
  final List<String> genderIds;

  const FeedFilters({
    this.minAge = 18,
    this.maxAge = 100,
    this.distance = 0,
    this.locationMode = FeedLocationMode.distance,
    this.city,
    this.state,
    this.country,
    this.intentId,
    this.currentlyOnline = false,
    this.genderIds = const [],
  });

  static const FeedFilters defaults = FeedFilters();

  bool get hasRegionFilter =>
      (city != null && city!.trim().isNotEmpty) ||
      (state != null && state!.trim().isNotEmpty) ||
      (country != null && country!.trim().isNotEmpty);

  bool get usesRegionMode =>
      locationMode == FeedLocationMode.region && hasRegionFilter;

  FeedFilters copyWith({
    int? minAge,
    int? maxAge,
    int? distance,
    FeedLocationMode? locationMode,
    String? city,
    String? state,
    String? country,
    bool clearCity = false,
    bool clearState = false,
    bool clearCountry = false,
    String? intentId,
    bool clearIntent = false,
    bool? currentlyOnline,
    List<String>? genderIds,
  }) =>
      FeedFilters(
        minAge: minAge ?? this.minAge,
        maxAge: maxAge ?? this.maxAge,
        distance: distance ?? this.distance,
        locationMode: locationMode ?? this.locationMode,
        city: clearCity ? null : (city ?? this.city),
        state: clearState ? null : (state ?? this.state),
        country: clearCountry ? null : (country ?? this.country),
        intentId: clearIntent ? null : (intentId ?? this.intentId),
        currentlyOnline: currentlyOnline ?? this.currentlyOnline,
        genderIds: genderIds ?? this.genderIds,
      );

  bool get isDefault =>
      minAge == defaults.minAge &&
      maxAge == defaults.maxAge &&
      distance == defaults.distance &&
      locationMode == defaults.locationMode &&
      !hasRegionFilter &&
      (intentId == null || intentId!.isEmpty) &&
      !currentlyOnline &&
      genderIds.isEmpty;

  int get activeCount {
    var n = 0;
    if (minAge != defaults.minAge || maxAge != defaults.maxAge) n++;
    if (usesRegionMode) {
      n++;
    } else if (distance != defaults.distance) {
      n++;
    }
    if (intentId != null && intentId!.isNotEmpty) n++;
    if (currentlyOnline) n++;
    if (genderIds.isNotEmpty) n++;
    return n;
  }

  String distanceLabel() {
    if (distance == 0) return 'Anywhere';
    return '$distance km';
  }

  String locationLabel() {
    if (usesRegionMode) {
      final parts = <String>[
        if (city != null && city!.trim().isNotEmpty) city!.trim(),
        if (state != null && state!.trim().isNotEmpty) state!.trim(),
        if (country != null && country!.trim().isNotEmpty) country!.trim(),
      ];
      return parts.join(', ');
    }
    return distanceLabel();
  }

  String ageLabel() => '$minAge–$maxAge';

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{
      'min_age': minAge,
      'max_age': maxAge,
    };

    if (usesRegionMode) {
      params['location_mode'] = 'region';
      final c = city?.trim();
      final s = state?.trim();
      final co = country?.trim();
      if (c != null && c.isNotEmpty) params['city'] = c;
      if (s != null && s.isNotEmpty) params['state'] = s;
      if (co != null && co.isNotEmpty) params['country'] = co;
    } else {
      params['location_mode'] = 'distance';
      params['distance'] = distance;
    }

    if (intentId != null && intentId!.isNotEmpty) {
      params['intent'] = intentId;
    }
    if (currentlyOnline) {
      params['currently_online'] = 'true';
    }
    if (genderIds.isNotEmpty) {
      params['gender'] = genderIds;
    }
    return params;
  }
}

const kDistanceFilterOptions = <int>[10, 50, 80, 100, 200, 0];