import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/theme_model.dart';
import 'alien_house_backgrounds.dart';
import 'feed_card_theme.dart';

/// Backend B01–B07 families mapped to Figma Alien-House frame painters.
enum DiscoveryPattern {
  flameWave, // B01 — Flame1–6
  puzzleSplash, // B02 — frames 88–96
  hexagonSplash, // B03 — frames 97–101
  biSplash, // B04 — frames 118–124
  squareSplash, // B05 — frames 80–87
  advanceFlame, // B06 — frames 102–104
  octagonSplash, // B07 — frames 113–117
}

class DiscoveryPalette {
  final Color background;
  final Color layer1;
  final Color layer2;
  final Color layer3;
  final Color accent;

  const DiscoveryPalette({
    required this.background,
    required this.layer1,
    required this.layer2,
    required this.layer3,
    required this.accent,
  });

  factory DiscoveryPalette.fromFeedTheme(FeedCardTheme theme) {
    final gradient = theme.gradient;
    return DiscoveryPalette(
      background: gradient.isNotEmpty ? gradient.last : theme.primaryColor,
      layer1: gradient.isNotEmpty ? gradient.first : theme.primaryColor,
      layer2: gradient.length > 1 ? gradient[1] : theme.accentColor,
      layer3: theme.accentColor,
      accent: theme.primaryColor,
    );
  }
}

class DiscoveryBackgroundSpec {
  final DiscoveryPattern pattern;
  final DiscoveryPalette palette;
  final String patternLabel;
  final String variantId;
  final FeedCardTheme feedTheme;

  const DiscoveryBackgroundSpec({
    required this.pattern,
    required this.palette,
    required this.patternLabel,
    required this.variantId,
    required this.feedTheme,
  });
}

class DiscoveryBackgroundCatalog {
  static const Map<String, DiscoveryPattern> _bgPatterns = {
    'B01': DiscoveryPattern.flameWave,
    'B02': DiscoveryPattern.puzzleSplash,
    'B03': DiscoveryPattern.hexagonSplash,
    'B04': DiscoveryPattern.biSplash,
    'B05': DiscoveryPattern.squareSplash,
    'B06': DiscoveryPattern.advanceFlame,
    'B07': DiscoveryPattern.octagonSplash,
  };

  static const Map<DiscoveryPattern, String> patternLabels = {
    DiscoveryPattern.flameWave: 'Flame Wave',
    DiscoveryPattern.puzzleSplash: 'Puzzle Splash',
    DiscoveryPattern.hexagonSplash: 'Hexagon Splash',
    DiscoveryPattern.biSplash: 'Bi Splash',
    DiscoveryPattern.squareSplash: 'Square Splash',
    DiscoveryPattern.advanceFlame: 'Advance Flame',
    DiscoveryPattern.octagonSplash: 'Octagon Splash',
  };

  static DiscoveryBackgroundSpec resolve(String? bgVariantId) {
    final feedTheme = FeedCardThemeCatalog.resolve(bgVariantId);
    final pattern = _bgPatterns[feedTheme.bgId] ?? DiscoveryPattern.flameWave;
    final palette = DiscoveryPalette.fromFeedTheme(feedTheme);

    return DiscoveryBackgroundSpec(
      pattern: pattern,
      palette: palette,
      patternLabel: patternLabels[pattern] ?? feedTheme.bgId,
      variantId: feedTheme.variantId,
      feedTheme: feedTheme,
    );
  }

  static String patternLabelForBgId(String? bgId) {
    if (bgId == null) return '';
    final pattern = _bgPatterns[bgId];
    if (pattern == null) return '';
    return patternLabels[pattern] ?? '';
  }

  static DiscoveryBackgroundSpec resolveFromTheme(ThemeConfig? config) {
    if (config?.bgVariantId != null) {
      return resolve(config!.bgVariantId);
    }
    if (config?.bgId != null) {
      final feedTheme = FeedCardThemeCatalog.resolveFromBgId(config!.bgId);
      return resolve(feedTheme.variantId);
    }
    return resolve('B01-sunset');
  }
}

/// Maps stable backend variant IDs (B01-sunset, …) to Figma frame enums.
class AlienHouseVariantResolver {
  static Widget build(DiscoveryBackgroundSpec spec) {
    final primary = spec.feedTheme.primaryColor;
    final background = spec.palette.background;

    switch (spec.pattern) {
      case DiscoveryPattern.flameWave:
        return AlienHouseBackground.flame(
          variant: _flameVariant(spec.variantId),
          color: primary,
          backgroundColor: _darken(background),
        );
      case DiscoveryPattern.puzzleSplash:
        return AlienHouseBackground.puzzleSplash(
          variant: _puzzleVariant(spec.variantId),
          color: primary,
          backgroundColor: background,
        );
      case DiscoveryPattern.hexagonSplash:
        return AlienHouseBackground.hexagonSplash(
          variant: _hexagonVariant(spec.variantId),
          color: primary,
          backgroundColor: background,
        );
      case DiscoveryPattern.biSplash:
        return AlienHouseBackground.biSplash(
          variant: _biVariant(spec.variantId),
          color: primary,
          backgroundColor: background,
        );
      case DiscoveryPattern.squareSplash:
        return AlienHouseBackground.squareSplash(
          variant: _squareVariant(spec.variantId),
          color: primary,
          backgroundColor: background,
        );
      case DiscoveryPattern.advanceFlame:
        return AlienHouseBackground.advanceFlame(
          variant: _advanceFlameVariant(spec.variantId),
          color: primary,
          backgroundColor: _darken(background),
        );
      case DiscoveryPattern.octagonSplash:
        return AlienHouseBackground.octagonSplash(
          variant: _octagonVariant(spec.variantId),
          color: primary,
          backgroundColor: background,
        );
    }
  }

  static Color _darken(Color c) =>
      Color.alphaBlend(Colors.black.withValues(alpha: 0.35), c);

  static FlameVariant _flameVariant(String id) => switch (id) {
        'B01-ocean' => FlameVariant.flame2,
        'B01-midnight' => FlameVariant.flame3,
        'B01-sunset' => FlameVariant.flame1,
        _ => FlameVariant.flame1,
      };

  static PuzzleSplashVariant _puzzleVariant(String id) => switch (id) {
        'B02-teal' => PuzzleSplashVariant.v89,
        'B02-violet' => PuzzleSplashVariant.v90,
        'B02-pink' => PuzzleSplashVariant.v88,
        _ => PuzzleSplashVariant.v88,
      };

  static HexagonSplashVariant _hexagonVariant(String id) => switch (id) {
        'B03-coral' => HexagonSplashVariant.v98,
        'B03-ice' => HexagonSplashVariant.v99,
        'B03-gold' => HexagonSplashVariant.v97,
        _ => HexagonSplashVariant.v97,
      };

  static BiSplashVariant _biVariant(String id) => switch (id) {
        'B04-rose' => BiSplashVariant.v119,
        'B04-emerald' => BiSplashVariant.v118,
        _ => BiSplashVariant.v118,
      };

  static SquareSplashVariant _squareVariant(String id) => switch (id) {
        'B05-amber' => SquareSplashVariant.v81,
        'B05-slate' => SquareSplashVariant.v80,
        _ => SquareSplashVariant.v80,
      };

  static AdvanceFlameVariant _advanceFlameVariant(String id) => switch (id) {
        'B06-magenta' => AdvanceFlameVariant.v103,
        'B06-lime' => AdvanceFlameVariant.v104,
        'B06-cyan' => AdvanceFlameVariant.v102,
        _ => AdvanceFlameVariant.v102,
      };

  static OctagonSplashVariant _octagonVariant(String id) => switch (id) {
        'B07-lavender' => OctagonSplashVariant.v114,
        'B07-mint' => OctagonSplashVariant.v115,
        'B07-peach' => OctagonSplashVariant.v113,
        _ => OctagonSplashVariant.v113,
      };
}

/// Full-screen Figma background scaled to the parent (375×812 design frame).
class DiscoveryBackground extends StatelessWidget {
  final DiscoveryBackgroundSpec spec;
  final Widget? child;

  const DiscoveryBackground({
    super.key,
    required this.spec,
    this.child,
  });

  String _getSvgAssetPath(String id) {
    return switch (id) {
      'B01-sunset' => 'assets/svgs/FlameWarm.svg',
      'B01-ocean' => 'assets/svgs/FlameCool.svg',
      'B01-midnight' => 'assets/svgs/DarkFlame1.svg',
      'B02-pink' => 'assets/svgs/PuzzleSplashWarm.svg',
      'B02-teal' => 'assets/svgs/PuzzleSplashCool.svg',
      'B02-violet' => 'assets/svgs/PuzzleSplashSpyce.svg',
      'B03-gold' => 'assets/svgs/HexSplashWarm.svg',
      'B03-coral' => 'assets/svgs/HexSplashSpyce.svg',
      'B03-ice' => 'assets/svgs/HexSplashCool.svg',
      'B04-emerald' => 'assets/svgs/TriSplashCool.svg',
      'B04-rose' => 'assets/svgs/TriSplashWarm.svg',
      'B05-slate' => 'assets/svgs/SquareSplashSpyce.svg',
      'B05-amber' => 'assets/svgs/SquareSplashWarm.svg',
      'B06-cyan' => 'assets/svgs/FlameCool.svg',
      'B06-magenta' => 'assets/svgs/FlameSpyce.svg',
      'B06-lime' => 'assets/svgs/FlameWarm.svg',
      'B07-peach' => 'assets/svgs/StarSplashWarm.svg',
      'B07-lavender' => 'assets/svgs/StarSplashCool.svg',
      'B07-mint' => 'assets/svgs/StarSplashSpyce.svg',
      _ => 'assets/svgs/FlameWarm.svg',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment.center,
            child: SizedBox(
              width: 375,
              height: 812,
              child: SvgPicture.asset(
                _getSvgAssetPath(spec.variantId),
                fit: BoxFit.fill,
              ),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}