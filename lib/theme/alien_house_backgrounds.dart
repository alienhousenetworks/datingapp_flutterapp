// =============================================================================
// Alien House — Background Frames & Variants
// Generated from Figma node 831:2792 "Selected Frames. For feed"
// File: 6AWNmmO1bGxYbxPqycN37q
//
// Sections / Background Types:
//  1. FlameBackground        — Flame1–6  (organic blob/flame shapes)
//  2. SquareSplashBackground — 80–87     (concentric rounded rectangles)
//  3. PuzzleSplashBackground — 88–96     (star/puzzle polygon shapes)
//  4. HexagonSplashBackground— 97–101    (concentric hexagons)
//  5. OctagonSplashBackground— 113–117   (concentric octagons)
//  6. BiSplashBackground     — 118–124   (bi-curve diagonal vectors)
//  7. FlameSplashBackground  — 125–131   (ellipse-based flame layers)
//  8. TriSplashBackground    — 132–138   (tri-vector shapes)
//  9. SimpleFlameBackground  — 105–112   (grid of ellipse flames)
// 10. AdvanceFlameBackground — 102–104   (dense grid ellipse flames)
// 11. ExtendedFlameBackground— Flame7–9  (dual-layer complex flames)
//
// Usage:
//   FlameBackground(variant: FlameVariant.flame1, color: Color(0xFFFF5722))
//   AlienHouseSquareSplashFrame(variant: SquareSplashVariant.v80, color: Color(0xFF6C63FF))
//   etc.
// =============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum FlameVariant { flame1, flame2, flame3, flame4, flame5, flame6 }

enum FlameExtendedVariant { flame7, flame8, flame9 }

enum SquareSplashVariant { v80, v81, v82, v83, v84, v85, v86, v87 }

enum PuzzleSplashVariant { v88, v89, v90, v91, v92, v93, v94, v95, v96 }

enum HexagonSplashVariant { v97, v98, v99, v100, v101 }

enum OctagonSplashVariant { v113, v114, v115, v116, v117 }

enum BiSplashVariant { v118, v119, v120, v121, v122, v123, v124 }

enum FlameSplashVariant { v125, v126, v127, v128, v129, v130, v131 }

enum TriSplashVariant { v132, v133, v134, v135, v136, v137, v138 }

enum SimpleFlameVariant { v105, v106, v107, v108, v109, v110, v111, v112 }

enum AdvanceFlameVariant { v102, v103, v104 }

// ─────────────────────────────────────────────────────────────────────────────
// 1. FLAME BACKGROUND  (Flame1–6)
//    375×822 frames. Organic blob shapes painted as a stack of SVG-like paths.
//    Variants differ only in how many "extra" detail vectors are rendered on
//    top of the base 8-vector shape (Flame4/5/6 have ~23 extra vectors).
// ─────────────────────────────────────────────────────────────────────────────

class AlienHouseFlameFrame extends StatelessWidget {
  const AlienHouseFlameFrame({
    super.key,
    required this.variant,
    this.baseColor = const Color(0xFFFF6B35),
    this.accentColor = const Color(0xFFFF9A5C),
    this.backgroundColor = const Color(0xFF1A0A00),
  });

  final FlameVariant variant;
  final Color baseColor;
  final Color accentColor;
  final Color backgroundColor;

  bool get _isDetailedVariant =>
      variant == FlameVariant.flame4 ||
      variant == FlameVariant.flame5 ||
      variant == FlameVariant.flame6;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: 375,
        height: 822,
        child: CustomPaint(
          painter: _FlamePainter(
            baseColor: baseColor,
            accentColor: accentColor,
            backgroundColor: backgroundColor,
            detailed: _isDetailedVariant,
            // Flame4 is leftmost detailed, Flame5/6 shift slightly
            offsetX: variant == FlameVariant.flame4
                ? 0
                : variant == FlameVariant.flame5
                    ? 8
                    : -4,
          ),
        ),
      ),
    );
  }
}

class _FlamePainter extends CustomPainter {
  const _FlamePainter({
    required this.baseColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.detailed,
    this.offsetX = 0,
  });

  final Color baseColor;
  final Color accentColor;
  final Color backgroundColor;
  final bool detailed;
  final double offsetX;

  @override
  void paint(Canvas canvas, Size size) {
    // Background rectangle (Rectangle 2105 — w:374, h:821, rounded)
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(16),
      ),
      bgPaint,
    );

    final sw = size.width;
    final sh = size.height;

    // Base flame layers — 8 blob vectors (Group 21 / Group 23)
    // Approximated with cubic bezier flame shapes
    _drawFlameLayer(canvas, sw, sh, 0, baseColor.withOpacity(0.15), large: true);
    _drawFlameLayer(canvas, sw, sh, 1, baseColor.withOpacity(0.25), large: true);
    _drawFlameLayer(canvas, sw, sh, 2, baseColor.withOpacity(0.35));
    _drawFlameLayer(canvas, sw, sh, 3, accentColor.withOpacity(0.45));
    _drawFlameLayer(canvas, sw, sh, 4, accentColor.withOpacity(0.55));
    _drawFlameLayer(canvas, sw, sh, 5, baseColor.withOpacity(0.6));
    _drawFlameLayer(canvas, sw, sh, 6, accentColor.withOpacity(0.7));
    _drawFlameLayer(canvas, sw, sh, 7, baseColor.withOpacity(0.85));

    if (detailed) {
      // Extra detail vectors for Flame4/5/6 — small flame tips and wisps
      _drawDetailFlames(canvas, sw, sh);
    }
  }

  void _drawFlameLayer(
    Canvas canvas,
    double w,
    double h,
    int layer,
    Color color, {
    bool large = false,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Each layer creates a slightly different organic flame blob
    final path = Path();
    final cx = w * 0.5 + offsetX;
    final baseY = h * (large ? 0.95 : 0.9 - layer * 0.04);
    final spread = w * (large ? 0.55 : 0.4 - layer * 0.02);
    final height = h * (large ? 0.85 : 0.75 - layer * 0.05);
    final wobble = w * 0.08 * (layer.isEven ? 1 : -1);

    path.moveTo(cx - spread * 0.4, baseY);
    path.cubicTo(
      cx - spread * 0.6,
      baseY - height * 0.3,
      cx - spread * 0.5 + wobble,
      baseY - height * 0.6,
      cx,
      baseY - height,
    );
    path.cubicTo(
      cx + spread * 0.5 + wobble,
      baseY - height * 0.6,
      cx + spread * 0.6,
      baseY - height * 0.3,
      cx + spread * 0.4,
      baseY,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  void _drawDetailFlames(Canvas canvas, double w, double h) {
    // Smaller wisp details (Vector 250–271 in Flame4/5/6)
    final colors = [
      accentColor.withOpacity(0.4),
      baseColor.withOpacity(0.5),
      accentColor.withOpacity(0.3),
    ];

    for (int i = 0; i < 8; i++) {
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.fill;
      final cx = w * (0.2 + (i % 4) * 0.2) + offsetX;
      final by = h * (0.8 - (i ~/ 4) * 0.15);
      final ht = h * 0.18;
      final sp = w * 0.06;

      final path = Path();
      path.moveTo(cx - sp, by);
      path.cubicTo(
        cx - sp * 1.5, by - ht * 0.4,
        cx + sp * 0.3, by - ht * 0.7,
        cx, by - ht,
      );
      path.cubicTo(
        cx - sp * 0.3, by - ht * 0.7,
        cx + sp * 1.5, by - ht * 0.4,
        cx + sp, by,
      );
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) =>
      old.baseColor != baseColor ||
      old.detailed != detailed ||
      old.offsetX != offsetX;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. SQUARE SPLASH BACKGROUND  (frames 80–87)
//    375×812. Multiple concentric rounded rectangles radiating outward from
//    center, clipped to the frame. Each variant has slightly different
//    rotation/offset of the ring stack (from Figma x/y positions).
// ─────────────────────────────────────────────────────────────────────────────

class AlienHouseSquareSplashFrame extends StatelessWidget {
  const AlienHouseSquareSplashFrame({
    super.key,
    required this.variant,
    this.primaryColor = const Color(0xFF6C63FF),
    this.backgroundColor = Colors.white,
  });

  final SquareSplashVariant variant;
  final Color primaryColor;
  final Color backgroundColor;

  // Each variant shifts the ring stack center slightly
  Offset get _centerOffset {
    // From Figma: rings are offset to lower-left of frame center
    // Approximated from x/y patterns across variants
    const offsets = {
      SquareSplashVariant.v80: Offset(-115, 100),
      SquareSplashVariant.v81: Offset(-118, 100),
      SquareSplashVariant.v82: Offset(-110, 100),
      SquareSplashVariant.v83: Offset(-107, 100),
      SquareSplashVariant.v84: Offset(-105, 100),
      SquareSplashVariant.v85: Offset(-112, 100),
      SquareSplashVariant.v86: Offset(-108, 100),
      SquareSplashVariant.v87: Offset(-109, 100),
    };
    return offsets[variant] ?? const Offset(-115, 100);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 812,
      child: CustomPaint(
        painter: _SquareSplashPainter(
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
          centerOffset: _centerOffset,
        ),
      ),
    );
  }
}

class _SquareSplashPainter extends CustomPainter {
  const _SquareSplashPainter({
    required this.primaryColor,
    required this.backgroundColor,
    required this.centerOffset,
  });

  final Color primaryColor;
  final Color backgroundColor;
  final Offset centerOffset;

  // Ring sizes from Figma (widths of Rectangle 290–312)
  static const List<double> _sizes = [
    980, 1029.9, 940, 945.9, 945.2, 861.8, 780, 777.7, 769.3, 693.6, 693.6,
    620, 609.6, 593.5, 525.5, 460, 441.4, 417.6, 417.6, 357.3, 357.3,
    300, 300, 273.3, 241.8, 189.2, 140,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Center of the ring stack (frame origin + center offset from Figma)
    final cx = size.width / 2 + centerOffset.dx;
    final cy = size.height / 2 + centerOffset.dy;

    for (int i = 0; i < _sizes.length; i++) {
      final s = _sizes[i];
      final progress = i / (_sizes.length - 1);
      final paint = Paint()
        ..color = primaryColor.withOpacity(0.04 + progress * 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: s,
        height: s,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(s * 0.12)),
        paint,
      );
    }

    // Innermost filled square (smallest ring — solid)
    final innerSize = _sizes.last;
    final innerPaint = Paint()
      ..color = primaryColor.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: innerSize,
          height: innerSize,
        ),
        Radius.circular(innerSize * 0.12),
      ),
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(_SquareSplashPainter old) =>
      old.primaryColor != primaryColor || old.centerOffset != centerOffset;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. PUZZLE SPLASH BACKGROUND  (frames 88–96)
//    375×812. Concentric star (puzzle) shapes radiating from lower-left.
//    Stars are 10-pointed (Star 167–176) with sizes from 400 to ~2980.
// ─────────────────────────────────────────────────────────────────────────────

class PuzzleSplashBackground extends StatelessWidget {
  const PuzzleSplashBackground({
    super.key,
    required this.variant,
    this.primaryColor = const Color(0xFF00BCD4),
    this.backgroundColor = Colors.white,
    this.showIllustration = false,
  });

  final PuzzleSplashVariant variant;
  final Color primaryColor;
  final Color backgroundColor;
  // v95 and v96 include an "Illustrations/float" frame child
  final bool showIllustration;

  // Variants 95 and 96 have illustration children
  bool get _hasIllustration =>
      variant == PuzzleSplashVariant.v95 || variant == PuzzleSplashVariant.v96;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 812,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(375, 812),
            painter: _StarSplashPainter(
              primaryColor: primaryColor,
              backgroundColor: backgroundColor,
            ),
          ),
          if (_hasIllustration || showIllustration)
            // Illustrations/float at x:83, y:220, size:210×149
            Positioned(
              left: 83,
              top: 220,
              width: 210,
              height: 149,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    Icons.auto_awesome,
                    color: primaryColor.withOpacity(0.5),
                    size: 48,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StarSplashPainter extends CustomPainter {
  const _StarSplashPainter({
    required this.primaryColor,
    required this.backgroundColor,
  });

  final Color primaryColor;
  final Color backgroundColor;

  // Star sizes from Figma (Star 167–176: w/h from 400 to ~2980)
  static const List<double> _starSizes = [
    400, 500, 625, 781.25, 976.56, 1220.7, 1525.9, 1907.3, 2384.2, 2980.2,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Stars are anchored at bottom-left of the frame (negative x,y from Figma)
    // Star 167 (smallest, 400×400) at x:-13, y:95 relative to frame
    final anchorX = -13.0;
    final anchorY = 95.0;

    for (int i = 0; i < _starSizes.length; i++) {
      final s = _starSizes[i];
      final cx = anchorX + s / 2;
      final cy = anchorY + s / 2;
      final progress = i / (_starSizes.length - 1);

      final paint = Paint()
        ..color = primaryColor.withOpacity(0.06 + progress * 0.02)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      _drawStar(canvas, Offset(cx, cy), s / 2, s / 2 * 0.48, 10, paint);
    }
  }

  void _drawStar(
    Canvas canvas,
    Offset center,
    double outerR,
    double innerR,
    int points,
    Paint paint,
  ) {
    final path = Path();
    final angleStep = math.pi / points;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = -math.pi / 2 + i * angleStep;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_StarSplashPainter old) =>
      old.primaryColor != primaryColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. HEXAGON SPLASH BACKGROUND  (frames 97–101)
//    375×812. Concentric hexagons (Polygon 32–42, 6-sided) from 300 to 1300.
// ─────────────────────────────────────────────────────────────────────────────

class HexagonSplashBackground extends StatelessWidget {
  const HexagonSplashBackground({
    super.key,
    required this.variant,
    this.primaryColor = const Color(0xFF4CAF50),
    this.backgroundColor = Colors.white,
  });

  final HexagonSplashVariant variant;
  final Color primaryColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 812,
      child: CustomPaint(
        painter: _HexagonSplashPainter(
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

class _HexagonSplashPainter extends CustomPainter {
  const _HexagonSplashPainter({
    required this.primaryColor,
    required this.backgroundColor,
  });

  final Color primaryColor;
  final Color backgroundColor;

  // Polygon 32–42 sizes (from Figma: 300, 463, 500, 700, 695, 900, 927, 1100, 1158, 1300, 1390)
  static const List<double> _hexSizes = [
    300, 463.4, 500, 699.9, 695.1, 900, 926.8, 1100, 1158.5, 1300, 1390.1,
  ];

  // Center from Figma: Polygon 32 (smallest) at x:37, y:132, size:300
  // so center = (37+150, 132+150) = (187, 282)
  static const Offset _center = Offset(187, 282);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    for (int i = 0; i < _hexSizes.length; i++) {
      final s = _hexSizes[i];
      final progress = i / (_hexSizes.length - 1);
      final paint = Paint()
        ..color = primaryColor.withOpacity(0.05 + progress * 0.02)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      _drawRegularPolygon(canvas, _center, s / 2, 6, paint);
    }
  }

  void _drawRegularPolygon(
    Canvas canvas,
    Offset center,
    double radius,
    int sides,
    Paint paint,
  ) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / sides;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_HexagonSplashPainter old) =>
      old.primaryColor != primaryColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. OCTAGON SPLASH BACKGROUND  (frames 113–117)
//    375×812. 20 concentric octagons (8-sided) from 250 to 1200, 25px apart.
// ─────────────────────────────────────────────────────────────────────────────

class OctagonSplashBackground extends StatelessWidget {
  const OctagonSplashBackground({
    super.key,
    required this.variant,
    this.primaryColor = const Color(0xFFFF5722),
    this.backgroundColor = Colors.white,
  });

  final OctagonSplashVariant variant;
  final Color primaryColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 812,
      child: CustomPaint(
        painter: _OctagonSplashPainter(
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

class _OctagonSplashPainter extends CustomPainter {
  const _OctagonSplashPainter({
    required this.primaryColor,
    required this.backgroundColor,
  });

  final Color primaryColor;
  final Color backgroundColor;

  // Polygon 47–66 sizes from Figma: 250, 300, 350, 400, 450, 500, 550, 600,
  //  650, 700, 750, 800, 850, 900, 950, 1000, 1050, 1100, 1150, 1200
  static final List<double> _octSizes =
      List.generate(20, (i) => 250.0 + i * 50);

  // Polygon 66 (smallest: 250×250) at x:62, y:168 → center (62+125, 168+125)
  static const Offset _center = Offset(187, 293);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    for (int i = 0; i < _octSizes.length; i++) {
      final s = _octSizes[i];
      final progress = i / (_octSizes.length - 1);
      final paint = Paint()
        ..color = primaryColor.withOpacity(0.04 + progress * 0.015)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      _drawPolygon(canvas, _center, s / 2, 8, paint);
    }
  }

  void _drawPolygon(
    Canvas canvas,
    Offset center,
    double radius,
    int sides,
    Paint paint,
  ) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final angle = -math.pi / 2 + 2 * math.pi * i / sides;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OctagonSplashPainter old) =>
      old.primaryColor != primaryColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. BI-SPLASH BACKGROUND  (frames 118–124)
//    375×812. 13 diagonal bi-curve vector shapes fanning upward from bottom.
//    Vector 78–91: teardrop-like shapes stacked with decreasing size.
// ─────────────────────────────────────────────────────────────────────────────

class BiSplashBackground extends StatelessWidget {
  const BiSplashBackground({
    super.key,
    required this.variant,
    this.primaryColor = const Color(0xFF9C27B0),
    this.backgroundColor = Colors.white,
  });

  final BiSplashVariant variant;
  final Color primaryColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 812,
      child: CustomPaint(
        painter: _BiSplashPainter(
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

class _BiSplashPainter extends CustomPainter {
  const _BiSplashPainter({
    required this.primaryColor,
    required this.backgroundColor,
  });

  final Color primaryColor;
  final Color backgroundColor;

  // Vector 78–91 approximate from Figma (x, y, width, height)
  // Each is a diagonal teardrop/feather shape going from bottom-right toward top-left
  static const List<List<double>> _layers = [
    [168.6, 480.1, 290.4, 367.8],  // Vector 78 (innermost)
    [162.8, 536.4, 380.1, 481.3],
    [158.2, 581.8, 451.9, 572.2],
    [152.4, 639.1, 541.6, 685.7],
    [146.6, 695.4, 631.3, 799.2],
    [140.8, 752.6, 721.0, 912.8],
    [135.4, 809.5, 810.4, 1026.2],
    [129.5, 866.3, 900.0, 1139.7],
    [123.5, 923.1, 989.7, 1253.2],
    [118.5, 979.9, 1079.3, 1366.7],
    [112.6, 1036.7, 1169.0, 1480.3],
    [106.6, 1093.5, 1258.6, 1593.8],
    [100.7, 1150.3, 1348.2, 1707.3], // Vector 91 (outermost)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    for (int i = 0; i < _layers.length; i++) {
      final l = _layers[i];
      final progress = 1.0 - i / (_layers.length - 1); // inner = most opaque
      final paint = Paint()
        ..color = primaryColor.withOpacity(0.04 + progress * 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      // Approximate teardrop curve using the bounding rect
      _drawTeardrop(canvas, l[0], l[1], l[2], l[3], paint);
    }
  }

  void _drawTeardrop(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    Paint paint,
  ) {
    // Each vector is a diagonal curved teardrop/feather shape
    final path = Path();
    // Tip at top-right of the bounding box, tail at bottom-left
    final tipX = x + w;
    final tipY = y;
    final tailX = x;
    final tailY = y + h;

    path.moveTo(tipX, tipY);
    path.cubicTo(
      tipX - w * 0.3, tipY + h * 0.1,
      tailX + w * 0.3, tailY - h * 0.15,
      tailX + w * 0.05, tailY - h * 0.05,
    );
    path.cubicTo(
      tailX - w * 0.05, tailY + h * 0.02,
      tipX - w * 0.05, tipY - h * 0.05,
      tipX, tipY,
    );
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BiSplashPainter old) =>
      old.primaryColor != primaryColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. FLAME-SPLASH BACKGROUND  (frames 125–131)
//    375×812. 28 concentric ellipse-flame shapes stacked from innermost to
//    outermost. Ellipse 570–618: each shrinks toward top-right of frame.
// ─────────────────────────────────────────────────────────────────────────────

class FlameSplashBackground extends StatelessWidget {
  const FlameSplashBackground({
    super.key,
    required this.variant,
    this.primaryColor = const Color(0xFFFF9800),
    this.backgroundColor = Colors.white,
  });

  final FlameSplashVariant variant;
  final Color primaryColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 812,
      child: CustomPaint(
        painter: _FlameSplashPainter(
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

class _FlameSplashPainter extends CustomPainter {
  const _FlameSplashPainter({
    required this.primaryColor,
    required this.backgroundColor,
  });

  final Color primaryColor;
  final Color backgroundColor;

  // Ellipse 570–618: (x, y, width, height) from Figma
  // Innermost is Ellipse 570, outermost is Ellipse 618
  static const List<List<double>> _ellipses = [
    [91.1, 106.9, 190.2, 351.2],  // Ellipse 570 (innermost)
    [75.3, 78.4, 221.0, 408.2],
    [59.5, 50.0, 253.6, 468.3],
    [43.6, 21.5, 284.4, 525.2],
    [27.8, -10.2, 317.0, 585.4],
    [12.0, -38.6, 347.8, 642.3],
    [-3.8, -67.1, 380.4, 702.4],
    [-19.6, -95.6, 411.3, 759.4],
    [-35.5, -124.1, 443.8, 819.5],
    [-51.3, -152.5, 474.6, 876.4],
    [-67.1, -184.2, 505.5, 933.4],
    [-82.9, -212.7, 537.9, 993.5],
    [-98.8, -241.1, 568.8, 1050.5],
    [-114.6, -272.8, 601.2, 1110.6],
    [-130.4, -301.3, 632.2, 1167.5],
    [-146.2, -329.7, 664.8, 1227.7],
    [-162.0, -361.4, 695.6, 1284.6],
    [-177.9, -389.9, 728.2, 1344.7],
    [-193.7, -418.3, 759.0, 1401.7],
    [-209.5, -446.8, 791.6, 1461.8],
    [-225.3, -475.3, 822.7, 1518.8],
    [-241.1, -503.8, 855.0, 1578.9],
    [-257.0, -535.4, 885.9, 1635.8],
    [-272.8, -563.9, 918.4, 1695.9],
    [-288.6, -592.4, 949.2, 1752.9],
    [-303.4, -625.0, 980.9, 1812.0],
    [-319.2, -654.6, 1012.0, 1868.9],
    [-335.0, -682.0, 1044.1, 1928.0], // Ellipse 618 (outermost)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    for (int i = 0; i < _ellipses.length; i++) {
      final e = _ellipses[i];
      final progress = i / (_ellipses.length - 1);
      final paint = Paint()
        ..color = primaryColor.withOpacity(0.04 + (1.0 - progress) * 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      final rect = Rect.fromLTWH(e[0], e[1], e[2], e[3]);
      canvas.drawOval(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_FlameSplashPainter old) =>
      old.primaryColor != primaryColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. TRI-SPLASH BACKGROUND  (frames 132–138)
//    375×812. 28 concentric triangular/tri-corner wave vectors fanning out
//    from the bottom-right of the frame toward the top-left. (Vector 92–118)
// ─────────────────────────────────────────────────────────────────────────────

class TriSplashBackground extends StatelessWidget {
  const TriSplashBackground({
    super.key,
    required this.variant,
    this.primaryColor = const Color(0xFF2196F3),
    this.backgroundColor = Colors.white,
  });

  final TriSplashVariant variant;
  final Color primaryColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 812,
      child: CustomPaint(
        painter: _TriSplashPainter(
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

class _TriSplashPainter extends CustomPainter {
  const _TriSplashPainter({
    required this.primaryColor,
    required this.backgroundColor,
  });

  final Color primaryColor;
  final Color backgroundColor;

  // Vector 92–118 from Figma: approximate bounding boxes (x, y, w, h)
  static const List<List<double>> _layers = [
    [260.8, 554.4, 562.0, 544.4],   // Vector 118 (innermost)
    [271.8, 594.0, 645.6, 625.3],
    [282.4, 633.4, 726.9, 704.2],
    [293.3, 671.7, 807.5, 782.0],
    [303.8, 711.1, 888.8, 860.8],
    [314.3, 750.6, 970.1, 939.7],
    [324.9, 790.0, 1051.4, 1018.5],
    [335.8, 829.5, 1132.0, 1096.4],
    [346.3, 869.0, 1213.3, 1175.2],
    [356.9, 908.4, 1294.6, 1254.1],
    [367.8, 946.7, 1375.2, 1331.9],
    [378.3, 986.1, 1456.5, 1410.8],
    [386.2, 1018.4, 1521.5, 1473.7],
    [398.8, 1065.2, 1618.8, 1568.0],
    [410.0, 1103.7, 1699.9, 1646.5],
    [422.7, 1151.7, 1797.2, 1740.8],
    [431.2, 1183.3, 1862.1, 1803.6],
    [442.4, 1221.9, 1943.2, 1882.2],
    [450.8, 1253.5, 2008.1, 1945.0],
    [460.8, 1293.3, 2089.2, 2023.6],
    [472.0, 1331.8, 2170.3, 2102.1],
    [481.9, 1371.6, 2251.4, 2180.7],
    [493.1, 1410.2, 2332.5, 2259.3],
    [504.3, 1450.0, 2413.6, 2337.8],
    [518.5, 1505.0, 2527.1, 2447.8],
    [531.2, 1551.7, 2624.4, 2542.1],
    [542.4, 1591.6, 2705.5, 2620.6], // Vector 117 (outermost)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    for (int i = 0; i < _layers.length; i++) {
      final l = _layers[i];
      final progress = 1.0 - i / (_layers.length - 1);
      final paint = Paint()
        ..color = primaryColor.withOpacity(0.035 + progress * 0.065)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      // Approximate as curved triangular/wave path
      _drawTriLayer(canvas, l[0], l[1], l[2], l[3], paint);
    }
  }

  void _drawTriLayer(
    Canvas canvas,
    double x,
    double y,
    double w,
    double h,
    Paint paint,
  ) {
    final path = Path();
    // These vectors appear to be quarter-circle arc shapes (bottom-right anchor)
    // Approximate with an arc from (x+w, y) to (x, y+h) curving outward
    final rect = Rect.fromLTWH(x, y, w * 2, h * 2);
    path.addArc(rect, -math.pi / 2, math.pi / 2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TriSplashPainter old) =>
      old.primaryColor != primaryColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. SIMPLE FLAME BACKGROUND  (frames 105–112)
//    375×812. Grid of ellipse-flame shapes arranged in alternating rows.
//    Ellipse 525–563: 60×111 each, positioned in an offset grid pattern.
// ─────────────────────────────────────────────────────────────────────────────

class SimpleFlameBackground extends StatelessWidget {
  const SimpleFlameBackground({
    super.key,
    required this.variant,
    this.primaryColor = const Color(0xFFE91E63),
    this.backgroundColor = Colors.white,
  });

  final SimpleFlameVariant variant;
  final Color primaryColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 812,
      child: CustomPaint(
        painter: _SimpleFlameGridPainter(
          primaryColor: primaryColor,
          backgroundColor: backgroundColor,
          rowOffset: _rowOffsetForVariant(variant),
        ),
      ),
    );
  }

  static double _rowOffsetForVariant(SimpleFlameVariant variant) {
    final index = SimpleFlameVariant.values.indexOf(variant);
    return (index % 4) * 8.0;
  }
}

class _SimpleFlameGridPainter extends CustomPainter {
  const _SimpleFlameGridPainter({
    required this.primaryColor,
    required this.backgroundColor,
    this.rowOffset = 0,
  });

  final Color primaryColor;
  final Color backgroundColor;
  final double rowOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    const ew = 60.0;
    const eh = 111.0;
    const colsA = [25.0, 155.0, 285.0];
    const colsB = [145.0, 275.0, 405.0];
    const rowStartY = -58.0;
    const rowStep = 136.0;
    const totalRows = 9;

    for (int row = 0; row < totalRows; row++) {
      final y = rowStartY + row * rowStep + rowOffset;
      final cols = row.isEven ? colsA : colsB;
      for (final x in cols) {
        final fillPaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        final strokePaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        final rect = Rect.fromLTWH(x, y, ew, eh);
        canvas.drawOval(rect, fillPaint);
        canvas.drawOval(rect, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_SimpleFlameGridPainter old) =>
      old.primaryColor != primaryColor ||
      old.backgroundColor != backgroundColor ||
      old.rowOffset != rowOffset;
}

// ─────────────────────────────────────────────────────────────────────────────
// 10. ADVANCE FLAME BACKGROUND  (frames 102–104)
//    Dense ellipse grid with dual-tone coloring.
// ─────────────────────────────────────────────────────────────────────────────

class AdvanceFlameBackground extends StatelessWidget {
  const AdvanceFlameBackground({
    super.key,
    required this.variant,
    this.primaryColor = const Color(0xFFFF5722),
    this.secondaryColor = const Color(0xFFFF9800),
    this.backgroundColor = Colors.white,
  });

  final AdvanceFlameVariant variant;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 812,
      child: CustomPaint(
        painter: _AdvanceFlameGridPainter(
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          backgroundColor: backgroundColor,
          rowOffset: _rowOffsetForVariant(variant),
        ),
      ),
    );
  }

  static double _rowOffsetForVariant(AdvanceFlameVariant variant) {
    final index = AdvanceFlameVariant.values.indexOf(variant);
    return index * 12.0;
  }
}

class _AdvanceFlameGridPainter extends CustomPainter {
  const _AdvanceFlameGridPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    this.rowOffset = 0,
  });

  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final double rowOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    const ew = 60.0;
    const eh = 111.0;
    const colsA = [25.0, 155.0, 285.0];
    const colsB = [145.0, 275.0, 405.0];
    const rowStartY = -58.0;
    const rowStep = 136.0;
    const totalRows = 9;

    for (int row = 0; row < totalRows; row++) {
      final y = rowStartY + row * rowStep + rowOffset;
      final cols = row.isEven ? colsA : colsB;
      for (int ci = 0; ci < cols.length; ci++) {
        final x = cols[ci];
        final color = (row + ci).isEven ? primaryColor : secondaryColor;
        final fillPaint = Paint()
          ..color = color.withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        final strokePaint = Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        final rect = Rect.fromLTWH(x, y, ew, eh);
        canvas.drawOval(rect, fillPaint);
        canvas.drawOval(rect, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_AdvanceFlameGridPainter old) =>
      old.primaryColor != primaryColor ||
      old.secondaryColor != secondaryColor ||
      old.backgroundColor != backgroundColor ||
      old.rowOffset != rowOffset;
}

// ─────────────────────────────────────────────────────────────────────────────
// 11. EXTENDED FLAME BACKGROUND  (Flame7, Flame8, Flame9)
//     375×822. More complex variants with dual Group layers (Group 31+32 or
//     Group 35) — identical vector sets overlaid on each other for depth.
// ─────────────────────────────────────────────────────────────────────────────

class ExtendedFlameBackground extends StatelessWidget {
  const ExtendedFlameBackground({
    super.key,
    required this.variant,
    this.baseColor = const Color(0xFFFF6B35),
    this.accentColor = const Color(0xFFFF9A5C),
    this.backgroundColor = const Color(0xFF1A0A00),
    this.shadowColor = const Color(0x44FF6B35),
  });

  final FlameExtendedVariant variant;
  final Color baseColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color shadowColor;

  /// Flame7 & 8 use two groups (Group 31 + Group 32) — full detail dual-layer
  /// Flame9 uses Group 35 (single group) — simplified version
  bool get _isDualLayer =>
      variant == FlameExtendedVariant.flame7 ||
      variant == FlameExtendedVariant.flame8;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: 375,
        height: 822,
        child: CustomPaint(
          painter: _ExtendedFlamePainter(
            baseColor: baseColor,
            accentColor: accentColor,
            backgroundColor: backgroundColor,
            shadowColor: shadowColor,
            dualLayer: _isDualLayer,
            // Flame8 offset from Flame7 (x: 1011 vs 603)
            offsetX: variant == FlameExtendedVariant.flame8 ? 6.0 : 0.0,
          ),
        ),
      ),
    );
  }
}

class _ExtendedFlamePainter extends CustomPainter {
  const _ExtendedFlamePainter({
    required this.baseColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.shadowColor,
    required this.dualLayer,
    this.offsetX = 0,
  });

  final Color baseColor;
  final Color accentColor;
  final Color backgroundColor;
  final Color shadowColor;
  final bool dualLayer;
  final double offsetX;

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(16),
      ),
      bgPaint,
    );

    final sw = size.width;
    final sh = size.height;

    // First group of flame vectors (Group 31 in Flame7/8, Group 35 in Flame9)
    _paintFlameGroup(canvas, sw, sh, baseColor, accentColor, offsetX, alpha: 1.0);

    if (dualLayer) {
      // Second group (Group 32) — layered on top with slight color shift
      _paintFlameGroup(
        canvas, sw, sh,
        accentColor, baseColor, offsetX,
        alpha: 0.6,
      );
    }
  }

  void _paintFlameGroup(
    Canvas canvas,
    double w,
    double h,
    Color primary,
    Color accent,
    double dx, {
    required double alpha,
  }) {
    // 31 vector vectors per group — base 8 + 23 detail
    // Base 8 (Vector 147–154)
    for (int i = 0; i < 8; i++) {
      final paint = Paint()
        ..color = (i < 4 ? primary : accent).withOpacity(alpha * (0.12 + i * 0.08))
        ..style = PaintingStyle.fill;
      _drawBaseFlameVector(canvas, w, h, i, dx, paint);
    }

    // Detail vectors (Vector 250–271)
    for (int i = 0; i < 23; i++) {
      final paint = Paint()
        ..color = (i.isEven ? primary : accent).withOpacity(alpha * (0.2 + i * 0.02))
        ..style = PaintingStyle.fill;
      _drawDetailVector(canvas, w, h, i, dx, paint);
    }
  }

  void _drawBaseFlameVector(
    Canvas canvas,
    double w,
    double h,
    int index,
    double dx,
    Paint paint,
  ) {
    // Approximate the 8 base vectors (Vector 147–154)
    // Each is a unique organic blob shape
    final path = Path();
    final cx = w * 0.5 + dx;
    final configs = [
      [cx + 0.22 * w, 0.0, 0.5 * w, 0.18 * h],  // V147: top spike
      [cx - 0.03 * w, 0.01 * h, 0.97 * w, h],    // V148: full-height blob
      [cx - 0.03 * w, 0.38 * h, 0.9 * w, 0.62 * h], // V149
      [cx + 0.22 * w, 0.1 * h, 0.34 * w, 0.57 * h], // V150
      [cx - 0.27 * w, 0.0, 0.25 * w, 0.28 * h],  // V151: left wisp
      [cx - 0.07 * w, 0.0, 0.44 * w, 0.56 * h],  // V152
      [cx - 0.27 * w, 0.21 * h, 0.33 * w, 0.51 * h], // V153
      [cx - 0.28 * w, 0.66 * h, 0.2 * w, 0.34 * h],  // V154
    ];
    if (index >= configs.length) return;
    final c = configs[index];
    // Draw an organic blob from config (cx, y, w, h)
    final bx = c[0] - c[2] / 2;
    final by = c[1];
    final bw = c[2];
    final bh = c[3];

    path.addOval(Rect.fromLTWH(bx, by, bw, bh));
    canvas.drawPath(path, paint);
  }

  void _drawDetailVector(
    Canvas canvas,
    double w,
    double h,
    int index,
    double dx,
    Paint paint,
  ) {
    // Smaller detail wisps/spikes
    final cx = w * 0.5 + dx;
    final x = cx + (index % 5 - 2) * w * 0.15;
    final y = h * (0.1 + (index % 7) * 0.12);
    final dw = w * 0.08;
    final dh = h * 0.08;

    final path = Path();
    path.moveTo(x, y);
    path.cubicTo(x - dw, y + dh * 0.3, x + dw * 0.5, y + dh * 0.7, x, y + dh);
    path.cubicTo(x - dw * 0.5, y + dh * 0.7, x + dw, y + dh * 0.3, x, y);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ExtendedFlamePainter old) =>
      old.baseColor != baseColor || old.dualLayer != dualLayer;
}

// ─────────────────────────────────────────────────────────────────────────────
// CONVENIENCE FACTORY — AlienHouseBackground
// Single entry point for all background types via enum
// ─────────────────────────────────────────────────────────────────────────────

enum AlienHouseBackgroundType {
  flame,
  flameExtended,
  squareSplash,
  puzzleSplash,
  hexagonSplash,
  octagonSplash,
  biSplash,
  flameSplash,
  triSplash,
  simpleFlame,
  advanceFlame,
}

/// Top-level factory widget. Wrap in a sized container for proper constraints.
class AlienHouseBackground extends StatelessWidget {
  const AlienHouseBackground.flame({
    super.key,
    required FlameVariant variant,
    this.color = const Color(0xFFFF6B35),
    this.backgroundColor = const Color(0xFF1A0A00),
  })  : _type = AlienHouseBackgroundType.flame,
        _flameVariant = variant,
        _flameExtVariant = null,
        _sqVariant = null,
        _pzVariant = null,
        _hxVariant = null,
        _ocVariant = null,
        _biVariant = null,
        _fspVariant = null,
        _triVariant = null,
        _sfVariant = null,
        _afVariant = null;

  const AlienHouseBackground.squareSplash({
    super.key,
    required SquareSplashVariant variant,
    this.color = const Color(0xFF6C63FF),
    this.backgroundColor = Colors.white,
  })  : _type = AlienHouseBackgroundType.squareSplash,
        _flameVariant = null,
        _flameExtVariant = null,
        _sqVariant = variant,
        _pzVariant = null,
        _hxVariant = null,
        _ocVariant = null,
        _biVariant = null,
        _fspVariant = null,
        _triVariant = null,
        _sfVariant = null,
        _afVariant = null;

  const AlienHouseBackground.puzzleSplash({
    super.key,
    required PuzzleSplashVariant variant,
    this.color = const Color(0xFF00BCD4),
    this.backgroundColor = Colors.white,
  })  : _type = AlienHouseBackgroundType.puzzleSplash,
        _flameVariant = null,
        _flameExtVariant = null,
        _sqVariant = null,
        _pzVariant = variant,
        _hxVariant = null,
        _ocVariant = null,
        _biVariant = null,
        _fspVariant = null,
        _triVariant = null,
        _sfVariant = null,
        _afVariant = null;

  const AlienHouseBackground.hexagonSplash({
    super.key,
    required HexagonSplashVariant variant,
    this.color = const Color(0xFF4CAF50),
    this.backgroundColor = Colors.white,
  })  : _type = AlienHouseBackgroundType.hexagonSplash,
        _flameVariant = null,
        _flameExtVariant = null,
        _sqVariant = null,
        _pzVariant = null,
        _hxVariant = variant,
        _ocVariant = null,
        _biVariant = null,
        _fspVariant = null,
        _triVariant = null,
        _sfVariant = null,
        _afVariant = null;

  const AlienHouseBackground.octagonSplash({
    super.key,
    required OctagonSplashVariant variant,
    this.color = const Color(0xFFFF5722),
    this.backgroundColor = Colors.white,
  })  : _type = AlienHouseBackgroundType.octagonSplash,
        _flameVariant = null,
        _flameExtVariant = null,
        _sqVariant = null,
        _pzVariant = null,
        _hxVariant = null,
        _ocVariant = variant,
        _biVariant = null,
        _fspVariant = null,
        _triVariant = null,
        _sfVariant = null,
        _afVariant = null;

  const AlienHouseBackground.biSplash({
    super.key,
    required BiSplashVariant variant,
    this.color = const Color(0xFF9C27B0),
    this.backgroundColor = Colors.white,
  })  : _type = AlienHouseBackgroundType.biSplash,
        _flameVariant = null,
        _flameExtVariant = null,
        _sqVariant = null,
        _pzVariant = null,
        _hxVariant = null,
        _ocVariant = null,
        _biVariant = variant,
        _fspVariant = null,
        _triVariant = null,
        _sfVariant = null,
        _afVariant = null;

  const AlienHouseBackground.flameSplash({
    super.key,
    required FlameSplashVariant variant,
    this.color = const Color(0xFFFF9800),
    this.backgroundColor = Colors.white,
  })  : _type = AlienHouseBackgroundType.flameSplash,
        _flameVariant = null,
        _flameExtVariant = null,
        _sqVariant = null,
        _pzVariant = null,
        _hxVariant = null,
        _ocVariant = null,
        _biVariant = null,
        _fspVariant = variant,
        _triVariant = null,
        _sfVariant = null,
        _afVariant = null;

  const AlienHouseBackground.triSplash({
    super.key,
    required TriSplashVariant variant,
    this.color = const Color(0xFF2196F3),
    this.backgroundColor = Colors.white,
  })  : _type = AlienHouseBackgroundType.triSplash,
        _flameVariant = null,
        _flameExtVariant = null,
        _sqVariant = null,
        _pzVariant = null,
        _hxVariant = null,
        _ocVariant = null,
        _biVariant = null,
        _fspVariant = null,
        _triVariant = variant,
        _sfVariant = null,
        _afVariant = null;

  const AlienHouseBackground.simpleFlame({
    super.key,
    required SimpleFlameVariant variant,
    this.color = const Color(0xFFE91E63),
    this.backgroundColor = Colors.white,
  })  : _type = AlienHouseBackgroundType.simpleFlame,
        _flameVariant = null,
        _flameExtVariant = null,
        _sqVariant = null,
        _pzVariant = null,
        _hxVariant = null,
        _ocVariant = null,
        _biVariant = null,
        _fspVariant = null,
        _triVariant = null,
        _sfVariant = variant,
        _afVariant = null;

  const AlienHouseBackground.advanceFlame({
    super.key,
    required AdvanceFlameVariant variant,
    this.color = const Color(0xFFFF5722),
    this.backgroundColor = Colors.white,
  })  : _type = AlienHouseBackgroundType.advanceFlame,
        _flameVariant = null,
        _flameExtVariant = null,
        _sqVariant = null,
        _pzVariant = null,
        _hxVariant = null,
        _ocVariant = null,
        _biVariant = null,
        _fspVariant = null,
        _triVariant = null,
        _sfVariant = null,
        _afVariant = variant;

  final AlienHouseBackgroundType _type;
  final FlameVariant? _flameVariant;
  final FlameExtendedVariant? _flameExtVariant;
  final SquareSplashVariant? _sqVariant;
  final PuzzleSplashVariant? _pzVariant;
  final HexagonSplashVariant? _hxVariant;
  final OctagonSplashVariant? _ocVariant;
  final BiSplashVariant? _biVariant;
  final FlameSplashVariant? _fspVariant;
  final TriSplashVariant? _triVariant;
  final SimpleFlameVariant? _sfVariant;
  final AdvanceFlameVariant? _afVariant;

  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    switch (_type) {
      case AlienHouseBackgroundType.flame:
        return AlienHouseFlameFrame(
          variant: _flameVariant!,
          baseColor: color,
          accentColor: color.withOpacity(0.7),
          backgroundColor: backgroundColor,
        );
      case AlienHouseBackgroundType.flameExtended:
        return ExtendedFlameBackground(
          variant: _flameExtVariant!,
          baseColor: color,
          accentColor: color.withOpacity(0.7),
          backgroundColor: backgroundColor,
        );
      case AlienHouseBackgroundType.squareSplash:
        return AlienHouseSquareSplashFrame(
          variant: _sqVariant!,
          primaryColor: color,
          backgroundColor: backgroundColor,
        );
      case AlienHouseBackgroundType.puzzleSplash:
        return PuzzleSplashBackground(
          variant: _pzVariant!,
          primaryColor: color,
          backgroundColor: backgroundColor,
        );
      case AlienHouseBackgroundType.hexagonSplash:
        return HexagonSplashBackground(
          variant: _hxVariant!,
          primaryColor: color,
          backgroundColor: backgroundColor,
        );
      case AlienHouseBackgroundType.octagonSplash:
        return OctagonSplashBackground(
          variant: _ocVariant!,
          primaryColor: color,
          backgroundColor: backgroundColor,
        );
      case AlienHouseBackgroundType.biSplash:
        return BiSplashBackground(
          variant: _biVariant!,
          primaryColor: color,
          backgroundColor: backgroundColor,
        );
      case AlienHouseBackgroundType.flameSplash:
        return FlameSplashBackground(
          variant: _fspVariant!,
          primaryColor: color,
          backgroundColor: backgroundColor,
        );
      case AlienHouseBackgroundType.triSplash:
        return TriSplashBackground(
          variant: _triVariant!,
          primaryColor: color,
          backgroundColor: backgroundColor,
        );
      case AlienHouseBackgroundType.simpleFlame:
        return SimpleFlameBackground(
          variant: _sfVariant!,
          primaryColor: color,
          backgroundColor: backgroundColor,
        );
      case AlienHouseBackgroundType.advanceFlame:
        return AdvanceFlameBackground(
          variant: _afVariant!,
          primaryColor: color,
          backgroundColor: backgroundColor,
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
