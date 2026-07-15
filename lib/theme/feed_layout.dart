/// Layout styles for feed profile cards (L01–L05).
/// Backend assigns stable layout_id; Flutter owns the visual treatment.
class FeedLayoutStyle {
  final String layoutId;
  final String name;
  final String description;
  /// Fraction of available content height used by the photo area (0–1).
  final double photoHeightFactor;
  final double photoWidthFactor;
  final double photoRotation;
  final bool photoOnLeft;
  final bool fullBleedPhoto;
  final bool compactCard;
  final bool boldTypography;
  final double borderRadius;
  final double borderWidth;
  final bool showAccentBorder;
  final bool useGlassmorphism;
  final bool useEditorialSplit;
  final bool usePosterBold;

  const FeedLayoutStyle({
    required this.layoutId,
    required this.name,
    required this.description,
    this.photoHeightFactor = 0.72,
    this.photoWidthFactor = 0.88,
    this.photoRotation = 0,
    this.photoOnLeft = false,
    this.fullBleedPhoto = false,
    this.compactCard = false,
    this.boldTypography = false,
    this.borderRadius = 20,
    this.borderWidth = 0,
    this.showAccentBorder = false,
    this.useGlassmorphism = false,
    this.useEditorialSplit = false,
    this.usePosterBold = false,
  });
}

class FeedLayoutCatalog {
  static const l01 = FeedLayoutStyle(
    layoutId: 'L01',
    name: 'Classic',
    description: 'Sleek glassmorphism frame with a floating card',
    photoHeightFactor: 0.78,
    photoWidthFactor: 0.86,
    photoRotation: 0,
    borderRadius: 24,
    useGlassmorphism: true,
  );

  static const l02 = FeedLayoutStyle(
    layoutId: 'L02',
    name: 'Split',
    description: 'Asymmetric editorial magazine page split',
    photoHeightFactor: 0.76,
    photoWidthFactor: 0.5,
    photoRotation: 0,
    borderRadius: 18,
    useEditorialSplit: true,
  );

  static const l03 = FeedLayoutStyle(
    layoutId: 'L03',
    name: 'Immersive',
    description: 'Cinematic full-bleed with luxury details overlay',
    fullBleedPhoto: true,
    photoHeightFactor: 1.0,
    photoWidthFactor: 1.0,
    photoRotation: 0,
    borderRadius: 0,
  );

  static const l04 = FeedLayoutStyle(
    layoutId: 'L04',
    name: 'Minimal',
    description: 'High-contrast clean art gallery card',
    compactCard: true,
    photoHeightFactor: 0.68,
    photoWidthFactor: 0.78,
    borderRadius: 16,
    showAccentBorder: true,
    borderWidth: 2.5,
  );

  static const l05 = FeedLayoutStyle(
    layoutId: 'L05',
    name: 'Bold',
    description: 'Typographic streetwear poster layout',
    boldTypography: true,
    photoHeightFactor: 0.88,
    photoWidthFactor: 0.92,
    photoRotation: -0.025,
    borderRadius: 20,
    showAccentBorder: true,
    borderWidth: 2,
    usePosterBold: true,
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
