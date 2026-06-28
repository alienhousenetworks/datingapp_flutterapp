/// Layout styles for feed profile cards (L01–L10).
/// Backend assigns stable layout_id; Flutter owns the visual treatment.
class FeedLayoutStyle {
  final String layoutId;
  final String name;
  final String description;
  final double photoWidthFactor;
  final double photoRotation;
  final bool photoOnLeft;
  final bool fullBleedPhoto;
  final bool compactCard;
  final bool boldTypography;
  final double borderRadius;
  final double borderWidth;
  final bool showAccentBorder;

  const FeedLayoutStyle({
    required this.layoutId,
    required this.name,
    required this.description,
    this.photoWidthFactor = 0.55,
    this.photoRotation = -0.03,
    this.photoOnLeft = false,
    this.fullBleedPhoto = false,
    this.compactCard = false,
    this.boldTypography = false,
    this.borderRadius = 12,
    this.borderWidth = 0,
    this.showAccentBorder = false,
  });
}

class FeedLayoutCatalog {
  static const l01 = FeedLayoutStyle(
    layoutId: 'L01',
    name: 'Classic',
    description: 'Photo top, profile info bottom',
    photoWidthFactor: 0.55,
  );

  static const l02 = FeedLayoutStyle(
    layoutId: 'L02',
    name: 'Split',
    description: 'Photo left, info right',
    photoWidthFactor: 0.42,
    photoOnLeft: true,
    photoRotation: 0,
  );

  static const l03 = FeedLayoutStyle(
    layoutId: 'L03',
    name: 'Immersive',
    description: 'Full-bleed photo with overlay text',
    fullBleedPhoto: true,
    photoWidthFactor: 0.92,
    photoRotation: 0,
  );

  static const l04 = FeedLayoutStyle(
    layoutId: 'L04',
    name: 'Minimal',
    description: 'Compact card with accent border',
    compactCard: true,
    photoWidthFactor: 0.45,
    borderRadius: 8,
    showAccentBorder: true,
    borderWidth: 2,
  );

  static const l05 = FeedLayoutStyle(
    layoutId: 'L05',
    name: 'Bold',
    description: 'Large typography hero layout',
    boldTypography: true,
    photoWidthFactor: 0.5,
    photoRotation: 0.02,
  );

  static const l06 = FeedLayoutStyle(
    layoutId: 'L06',
    name: 'Vibrant',
    description: 'Sunset gradient emphasis',
    photoWidthFactor: 0.58,
    photoRotation: -0.05,
  );

  static const l07 = FeedLayoutStyle(
    layoutId: 'L07',
    name: 'Cyan Glow',
    description: 'Cyan to green gradient emphasis',
    photoWidthFactor: 0.52,
    showAccentBorder: true,
    borderWidth: 1.5,
  );

  static const l08 = FeedLayoutStyle(
    layoutId: 'L08',
    name: 'Moody Radial',
    description: 'Dark moody radial gradient',
    photoWidthFactor: 0.48,
    photoRotation: 0.04,
    compactCard: true,
  );

  static const l09 = FeedLayoutStyle(
    layoutId: 'L09',
    name: 'Cyberpunk',
    description: 'Neon pink to neon cyan',
    boldTypography: true,
    photoWidthFactor: 0.6,
    showAccentBorder: true,
    borderWidth: 2,
    borderRadius: 4,
  );

  static const l10 = FeedLayoutStyle(
    layoutId: 'L10',
    name: 'Warm Pinkish',
    description: 'Warm pinkish glow',
    photoWidthFactor: 0.54,
    photoRotation: -0.02,
  );

  static final Map<String, FeedLayoutStyle> _catalog = {
    'L01': l01,
    'L02': l02,
    'L03': l03,
    'L04': l04,
    'L05': l05,
    'L06': l06,
    'L07': l07,
    'L08': l08,
    'L09': l09,
    'L10': l10,
  };

  static FeedLayoutStyle resolve(String? layoutId) =>
      _catalog[layoutId] ?? l01;

  static List<FeedLayoutStyle> get all => _catalog.values.toList();
}