import 'package:flutter/material.dart';

// ─── Feed Card Theme Catalog ─────────────────────────────────
// Flutter owns all visuals. Backend provides stable IDs (B01-B07, L01-L10).
// This file maps those IDs to actual colors/gradients shown in the app.

class FeedCardTheme {
  final String bgId;
  final String variantId;
  final String name;
  final Color primaryColor;
  final Color accentColor;
  final Color textColor;
  final List<Color> gradient;
  final String patternType; // 'gradient', 'mesh', 'geometric', 'aurora', 'neon', 'clouds'

  const FeedCardTheme({
    required this.bgId,
    required this.variantId,
    required this.name,
    required this.primaryColor,
    required this.accentColor,
    required this.textColor,
    required this.gradient,
    required this.patternType,
  });
}

class FeedCardThemeCatalog {
  // ─── B01: Gradient Wave ──────────────────────────────────
  static const b01Sunset = FeedCardTheme(
    bgId: 'B01',
    variantId: 'B01-sunset',
    name: 'Sunset',
    primaryColor: Color(0xFFFF6B35),
    accentColor: Color(0xFFFFD93D),
    textColor: Colors.white,
    gradient: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
    patternType: 'flameWave',
  );
  static const b01Ocean = FeedCardTheme(
    bgId: 'B01',
    variantId: 'B01-ocean',
    name: 'Ocean',
    primaryColor: Color(0xFF0077B6),
    accentColor: Color(0xFF00B4D8),
    textColor: Colors.white,
    gradient: [Color(0xFF0077B6), Color(0xFF00B4D8)],
    patternType: 'flameWave',
  );
  static const b01Midnight = FeedCardTheme(
    bgId: 'B01',
    variantId: 'B01-midnight',
    name: 'Midnight',
    primaryColor: Color(0xFF1A1A2E),
    accentColor: Color(0xFF6C63FF),
    textColor: Colors.white,
    gradient: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    patternType: 'flameWave',
  );

  // ─── B02: Puzzle Splash ──────────────────────────────────
  static const b02Pink = FeedCardTheme(
    bgId: 'B02',
    variantId: 'B02-pink',
    name: 'Pink',
    primaryColor: Color(0xFFFF2E74),
    accentColor: Color(0xFFFF85A1),
    textColor: Colors.white,
    gradient: [Color(0xFFFF2E74), Color(0xFFFF85A1), Color(0xFFFFC3D4)],
    patternType: 'puzzleSplash',
  );
  static const b02Teal = FeedCardTheme(
    bgId: 'B02',
    variantId: 'B02-teal',
    name: 'Teal',
    primaryColor: Color(0xFF00897B),
    accentColor: Color(0xFF4DB6AC),
    textColor: Colors.white,
    gradient: [Color(0xFF004D40), Color(0xFF00897B), Color(0xFF4DB6AC)],
    patternType: 'puzzleSplash',
  );
  static const b02Violet = FeedCardTheme(
    bgId: 'B02',
    variantId: 'B02-violet',
    name: 'Violet',
    primaryColor: Color(0xFF7C3AED),
    accentColor: Color(0xFFA78BFA),
    textColor: Colors.white,
    gradient: [Color(0xFF4C1D95), Color(0xFF7C3AED), Color(0xFFA78BFA)],
    patternType: 'puzzleSplash',
  );

  // ─── B03: Hexagon Splash ─────────────────────────────────
  static const b03Gold = FeedCardTheme(
    bgId: 'B03',
    variantId: 'B03-gold',
    name: 'Gold',
    primaryColor: Color(0xFFD4A017),
    accentColor: Color(0xFFFFD700),
    textColor: Color(0xFF1A1A1A),
    gradient: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
    patternType: 'hexagonSplash',
  );
  static const b03Coral = FeedCardTheme(
    bgId: 'B03',
    variantId: 'B03-coral',
    name: 'Coral',
    primaryColor: Color(0xFFFF6B6B),
    accentColor: Color(0xFFFFD93D),
    textColor: Colors.white,
    gradient: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
    patternType: 'hexagonSplash',
  );
  static const b03Ice = FeedCardTheme(
    bgId: 'B03',
    variantId: 'B03-ice',
    name: 'Ice',
    primaryColor: Color(0xFFB2EBF2),
    accentColor: Color(0xFF80DEEA),
    textColor: Color(0xFF006064),
    gradient: [Color(0xFFE0F7FA), Color(0xFFB2EBF2)],
    patternType: 'hexagonSplash',
  );

  // ─── B04: Bi Splash ──────────────────────────────────────
  static const b04Emerald = FeedCardTheme(
    bgId: 'B04',
    variantId: 'B04-emerald',
    name: 'Emerald',
    primaryColor: Color(0xFF00C853),
    accentColor: Color(0xFF64DD17),
    textColor: Colors.white,
    gradient: [Color(0xFF0D1B2A), Color(0xFF00C853), Color(0xFF1DE9B6)],
    patternType: 'biSplash',
  );
  static const b04Rose = FeedCardTheme(
    bgId: 'B04',
    variantId: 'B04-rose',
    name: 'Rose',
    primaryColor: Color(0xFFE91E63),
    accentColor: Color(0xFFF48FB1),
    textColor: Colors.white,
    gradient: [Color(0xFF1A0A12), Color(0xFFE91E63), Color(0xFFF48FB1)],
    patternType: 'biSplash',
  );

  // ─── B05: Square Splash ──────────────────────────────────
  static const b05Slate = FeedCardTheme(
    bgId: 'B05',
    variantId: 'B05-slate',
    name: 'Slate',
    primaryColor: Color(0xFF607D8B),
    accentColor: Color(0xFF90A4AE),
    textColor: Colors.white,
    gradient: [Color(0xFF263238), Color(0xFF455A64)],
    patternType: 'squareSplash',
  );
  static const b05Amber = FeedCardTheme(
    bgId: 'B05',
    variantId: 'B05-amber',
    name: 'Amber',
    primaryColor: Color(0xFFFF8F00),
    accentColor: Color(0xFFFFD54F),
    textColor: Color(0xFF1A1A1A),
    gradient: [Color(0xFFFF6F00), Color(0xFFFFCA28)],
    patternType: 'squareSplash',
  );

  // ─── B06: Advance Flame ──────────────────────────────────
  static const b06Cyan = FeedCardTheme(
    bgId: 'B06',
    variantId: 'B06-cyan',
    name: 'Neon Cyan',
    primaryColor: Color(0xFF00E5FF),
    accentColor: Color(0xFF00BCD4),
    textColor: Colors.white,
    gradient: [Color(0xFF0A0A0A), Color(0xFF001A1F)],
    patternType: 'advanceFlame',
  );
  static const b06Magenta = FeedCardTheme(
    bgId: 'B06',
    variantId: 'B06-magenta',
    name: 'Neon Magenta',
    primaryColor: Color(0xFFFF00FF),
    accentColor: Color(0xFFEA80FC),
    textColor: Colors.white,
    gradient: [Color(0xFF0D0014), Color(0xFF1A0025)],
    patternType: 'advanceFlame',
  );
  static const b06Lime = FeedCardTheme(
    bgId: 'B06',
    variantId: 'B06-lime',
    name: 'Neon Lime',
    primaryColor: Color(0xFFCCFF00),
    accentColor: Color(0xFF76FF03),
    textColor: Color(0xFF0A1A00),
    gradient: [Color(0xFF0D1400), Color(0xFF1A2600)],
    patternType: 'advanceFlame',
  );

  // ─── B07: Octagon Splash ─────────────────────────────────
  static const b07Peach = FeedCardTheme(
    bgId: 'B07',
    variantId: 'B07-peach',
    name: 'Peach',
    primaryColor: Color(0xFFFFCCBC),
    accentColor: Color(0xFFFF8A65),
    textColor: Color(0xFF4E342E),
    gradient: [Color(0xFFFFE0B2), Color(0xFFFFCCBC)],
    patternType: 'octagonSplash',
  );
  static const b07Lavender = FeedCardTheme(
    bgId: 'B07',
    variantId: 'B07-lavender',
    name: 'Lavender',
    primaryColor: Color(0xFFCE93D8),
    accentColor: Color(0xFFAB47BC),
    textColor: Color(0xFF4A148C),
    gradient: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
    patternType: 'octagonSplash',
  );
  static const b07Mint = FeedCardTheme(
    bgId: 'B07',
    variantId: 'B07-mint',
    name: 'Mint',
    primaryColor: Color(0xFFA5D6A7),
    accentColor: Color(0xFF66BB6A),
    textColor: Color(0xFF1B5E20),
    gradient: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
    patternType: 'octagonSplash',
  );

  // ─── Lookup ──────────────────────────────────────────────
  static final Map<String, FeedCardTheme> _catalog = {
    'B01-sunset': b01Sunset,
    'B01-ocean': b01Ocean,
    'B01-midnight': b01Midnight,
    'B02-pink': b02Pink,
    'B02-teal': b02Teal,
    'B02-violet': b02Violet,
    'B03-gold': b03Gold,
    'B03-coral': b03Coral,
    'B03-ice': b03Ice,
    'B04-emerald': b04Emerald,
    'B04-rose': b04Rose,
    'B05-slate': b05Slate,
    'B05-amber': b05Amber,
    'B06-cyan': b06Cyan,
    'B06-magenta': b06Magenta,
    'B06-lime': b06Lime,
    'B07-peach': b07Peach,
    'B07-lavender': b07Lavender,
    'B07-mint': b07Mint,
  };

  static FeedCardTheme resolve(String? bgVariantId) {
    return _catalog[bgVariantId] ?? b01Sunset; // default fallback
  }

  static FeedCardTheme resolveFromBgId(String? bgId) {
    if (bgId == null) return b01Sunset;
    final match = _catalog.entries.firstWhere(
      (e) => e.key.startsWith(bgId),
      orElse: () => _catalog.entries.first,
    );
    return match.value;
  }

  static List<FeedCardTheme> get all => _catalog.values.toList();
}
