import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hand-drawn style placeholder characters (Figma Alien-House style).
/// Picks a stable random variant per profile id when user has no photos.
class FeedCharacterArt extends StatelessWidget {
  final String? gender;
  final String seed;

  const FeedCharacterArt({
    super.key,
    this.gender,
    required this.seed,
  });

  static int variantIndexForSeed(String seed, int count) {
    var hash = 0;
    for (final c in seed.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return hash % count;
  }

  bool get _isFemale {
    final g = (gender ?? '').toLowerCase();
    return g.contains('female') || g.contains('woman') || g == 'f';
  }

  @override
  Widget build(BuildContext context) {
    final femaleVariants = [
      _CharacterPalette(
        skin: const Color(0xFFFFD5C8),
        hair: const Color(0xFF6B3FA0),
        shirt: const Color(0xFFFF6B9D),
        accent: const Color(0xFFFFD93D),
        hairStyle: _HairStyle.long,
      ),
      _CharacterPalette(
        skin: const Color(0xFFE8B4A0),
        hair: const Color(0xFF2D1B4E),
        shirt: const Color(0xFF80CBC4),
        accent: const Color(0xFFFF7043),
        hairStyle: _HairStyle.bob,
      ),
      _CharacterPalette(
        skin: const Color(0xFFFFE0BD),
        hair: const Color(0xFFE91E63),
        shirt: const Color(0xFFB39DDB),
        accent: const Color(0xFF00BCD4),
        hairStyle: _HairStyle.curly,
      ),
    ];
    final maleVariants = [
      _CharacterPalette(
        skin: const Color(0xFFD4A574),
        hair: const Color(0xFF1A1A2E),
        shirt: const Color(0xFF4FC3F7),
        accent: const Color(0xFFFFD700),
        hairStyle: _HairStyle.short,
      ),
      _CharacterPalette(
        skin: const Color(0xFFC68642),
        hair: const Color(0xFF3E2723),
        shirt: const Color(0xFF8BC34A),
        accent: const Color(0xFFFF5722),
        hairStyle: _HairStyle.messy,
      ),
      _CharacterPalette(
        skin: const Color(0xFFE0AC69),
        hair: const Color(0xFF37474F),
        shirt: const Color(0xFF7E57C2),
        accent: const Color(0xFF00E676),
        hairStyle: _HairStyle.short,
      ),
    ];

    final variants = _isFemale ? femaleVariants : maleVariants;
    final idx = variantIndexForSeed(seed, variants.length);

    return CustomPaint(
      painter: _CharacterPainter(variants[idx], _isFemale),
      child: const SizedBox.expand(),
    );
  }
}

enum _HairStyle { long, bob, curly, short, messy }

class _CharacterPalette {
  final Color skin;
  final Color hair;
  final Color shirt;
  final Color accent;
  final _HairStyle hairStyle;

  const _CharacterPalette({
    required this.skin,
    required this.hair,
    required this.shirt,
    required this.accent,
    required this.hairStyle,
  });
}

class _CharacterPainter extends CustomPainter {
  final _CharacterPalette palette;
  final bool isFemale;

  _CharacterPainter(this.palette, this.isFemale);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final cy = size.height * 0.52;

    // Soft blob background
    final bg = Paint()..color = palette.accent.withValues(alpha: 0.25);
    canvas.drawCircle(Offset(cx, cy), size.width * 0.38, bg);

    // Body
    final body = Paint()..color = palette.shirt;
    final bodyPath = Path()
      ..moveTo(cx - size.width * 0.22, cy + size.height * 0.08)
      ..quadraticBezierTo(
        cx - size.width * 0.28,
        cy + size.height * 0.28,
        cx,
        cy + size.height * 0.32,
      )
      ..quadraticBezierTo(
        cx + size.width * 0.28,
        cy + size.height * 0.28,
        cx + size.width * 0.22,
        cy + size.height * 0.08,
      )
      ..close();
    canvas.drawPath(bodyPath, body);

    // Head
    final headR = size.width * 0.18;
    canvas.drawCircle(
      Offset(cx, cy - size.height * 0.02),
      headR,
      Paint()..color = palette.skin,
    );

    // Hair
    _drawHair(canvas, Offset(cx, cy - size.height * 0.02), headR);

    // Eyes (simple dots)
    final eye = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawCircle(
      Offset(cx - headR * 0.35, cy - size.height * 0.04),
      headR * 0.08,
      eye,
    );
    canvas.drawCircle(
      Offset(cx + headR * 0.35, cy - size.height * 0.04),
      headR * 0.08,
      eye,
    );

    // Smile
    final smile = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, cy + size.height * 0.01),
        width: headR * 0.7,
        height: headR * 0.4,
      ),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      smile,
    );

    // Cheek blush
    final blush = Paint()..color = const Color(0xFFFF8A80).withValues(alpha: 0.45);
    canvas.drawCircle(
      Offset(cx - headR * 0.55, cy + size.height * 0.01),
      headR * 0.12,
      blush,
    );
    canvas.drawCircle(
      Offset(cx + headR * 0.55, cy + size.height * 0.01),
      headR * 0.12,
      blush,
    );

    // Decorative doodles
    final doodle = Paint()
      ..color = palette.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.15, size.height * 0.2), 6, doodle);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.25), 4, doodle);
    _drawStar(canvas, Offset(size.width * 0.82, size.height * 0.15), 10, palette.accent);
  }

  void _drawHair(Canvas canvas, Offset center, double headR) {
    final hair = Paint()..color = palette.hair;
    switch (palette.hairStyle) {
      case _HairStyle.long:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy - headR * 0.1),
            width: headR * 2.1,
            height: headR * 1.6,
          ),
          hair,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            center.dx - headR * 0.9,
            center.dy,
            headR * 1.8,
            headR * 1.4,
          ),
          hair,
        );
      case _HairStyle.bob:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy - headR * 0.15),
            width: headR * 2.2,
            height: headR * 1.5,
          ),
          hair,
        );
      case _HairStyle.curly:
        for (int i = -2; i <= 2; i++) {
          canvas.drawCircle(
            Offset(center.dx + i * headR * 0.35, center.dy - headR * 0.5),
            headR * 0.28,
            hair,
          );
        }
      case _HairStyle.short:
      case _HairStyle.messy:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy - headR * 0.2),
            width: headR * 2.0,
            height: headR * 1.2,
          ),
          hair,
        );
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Color color) {
    final p = Paint()..color = color;
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (i * 4 * math.pi / 5) - math.pi / 2;
      final pt = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _CharacterPainter old) =>
      old.palette != palette || old.isFemale != isFemale;
}