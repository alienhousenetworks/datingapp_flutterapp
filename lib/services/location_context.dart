/// Shared lat/lon + geo labels for API headers and analytics.
class LocationContext {
  LocationContext._();
  static final LocationContext instance = LocationContext._();

  double? latitude;
  double? longitude;
  String? city;
  String? state;
  String? country;

  void update({
    double? lat,
    double? lon,
    String? city,
    String? state,
    String? country,
  }) {
    if (lat != null) latitude = lat;
    if (lon != null) longitude = lon;
    if (city != null) this.city = city;
    if (state != null) this.state = state;
    if (country != null) this.country = country;
  }

  Map<String, String> get geoHeaders {
    final headers = <String, String>{};
    if (latitude != null) headers['X-Latitude'] = latitude!.toStringAsFixed(6);
    if (longitude != null) headers['X-Longitude'] = longitude!.toStringAsFixed(6);
    if (city != null && city!.isNotEmpty) headers['X-City'] = city!;
    if (state != null && state!.isNotEmpty) headers['X-State'] = state!;
    if (country != null && country!.isNotEmpty) headers['X-Country'] = country!;
    return headers;
  }
}