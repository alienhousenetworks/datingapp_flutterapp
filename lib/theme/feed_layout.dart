/// Premium layout styles for feed profile cards (L01–L05).
/// Backend assigns stable layout_id; Flutter owns the visual treatment.
/// Every layout shows the user's bio on the first (hero) page.
enum FeedLayoutKind {
  /// L01 — frosted luxury glass card
  velvetGlass,

  /// L02 — high-fashion editorial magazine split
  maison,

  /// L03 — cinematic full-bleed film poster
  noir,

  /// L04 — museum gallery framed portrait
  atelier,

  /// L05 — bold fashion runway poster
  runway,
}

class FeedLayoutStyle {
  final String layoutId;
  final String name;
  final String description;
  final FeedLayoutKind kind;
  final double photoHeightFactor;
  final double photoWidthFactor;
  final double photoRotation;
  final double borderRadius;
  final double borderWidth;
  final bool boldTypography;

  const FeedLayoutStyle({
    required this.layoutId,
    required this.name,
    required this.description,
    required this.kind,
    this.photoHeightFactor = 0.72,
    this.photoWidthFactor = 0.88,
    this.photoRotation = 0,
    this.borderRadius = 22,
    this.borderWidth = 0,
    this.boldTypography = false,
  });
}

class FeedLayoutCatalog {
  static const l01 = FeedLayoutStyle(
    layoutId: 'L01',
    name: 'Velvet Glass',
    description:
        'Frosted glass luxury card with soft glow and bio on the first page',
    kind: FeedLayoutKind.velvetGlass,
    photoHeightFactor: 0.82,
    photoWidthFactor: 0.90,
    borderRadius: 28,
  );

  static const l02 = FeedLayoutStyle(
    layoutId: 'L02',
    name: 'Maison',
    description:
        'High-fashion editorial split — portrait left, story & bio right',
    kind: FeedLayoutKind.maison,
    photoHeightFactor: 0.80,
    photoWidthFactor: 1.0,
    borderRadius: 20,
  );

  static const l03 = FeedLayoutStyle(
    layoutId: 'L03',
    name: 'Noir',
    description:
        'Cinematic full-bleed film poster with gold-accent bio overlay',
    kind: FeedLayoutKind.noir,
    photoHeightFactor: 1.0,
    photoWidthFactor: 1.0,
    borderRadius: 0,
  );

  static const l04 = FeedLayoutStyle(
    layoutId: 'L04',
    name: 'Atelier',
    description:
        'Museum gallery frame — refined portrait with bio beneath',
    kind: FeedLayoutKind.atelier,
    photoHeightFactor: 0.62,
    photoWidthFactor: 0.78,
    borderRadius: 4,
    borderWidth: 1.5,
  );

  static const l05 = FeedLayoutStyle(
    layoutId: 'L05',
    name: 'Runway',
    description:
        'Bold fashion runway poster with oversized type and bio strip',
    kind: FeedLayoutKind.runway,
    boldTypography: true,
    photoHeightFactor: 0.90,
    photoWidthFactor: 0.94,
    photoRotation: -0.018,
    borderRadius: 16,
    borderWidth: 2.5,
  );

  static final Map<String, FeedLayoutStyle> _catalog = {
    'L01': l01,
    'L02': l02,
    'L03': l03,
    'L04': l04,
    'L05': l05,
  };

  static FeedLayoutStyle resolve(String? layoutId) =>
      _catalog[layoutId] ?? l01;

  static List<FeedLayoutStyle> get all => _catalog.values.toList();
}
