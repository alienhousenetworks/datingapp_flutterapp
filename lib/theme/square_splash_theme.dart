import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class SquareSplashTheme {
  final String name;
  final Color innermostSquareColor;
  final Color concentricSquare2Color;
  final Color concentricSquare3Color;
  final Color outerSquareColor;
  final List<Color> backgroundStripes;
  final SystemUiOverlayStyle statusBarStyle;

  const SquareSplashTheme({
    required this.name,
    required this.innermostSquareColor,
    required this.concentricSquare2Color,
    required this.concentricSquare3Color,
    required this.outerSquareColor,
    required this.backgroundStripes,
    required this.statusBarStyle,
  });

  static List<SquareSplashTheme> get themes => [
        // Design 1: Slate Teal / Cool Blue-Grey
        SquareSplashTheme(
          name: 'Slate Teal',
          innermostSquareColor: const Color(0xFF85B5B3),
          concentricSquare2Color: const Color(0xFF1E323C),
          concentricSquare3Color: const Color(0xFF437582),
          outerSquareColor: const Color(0xFF2E5059),
          backgroundStripes: const [
            Color(0xFF548C99),
            Color(0xFF1C323C),
            Color(0xFF72A4B0),
          ],
          statusBarStyle: SystemUiOverlayStyle.dark,
        ),
        // Design 2: Copper Orange / Warm Rust
        SquareSplashTheme(
          name: 'Copper Orange',
          innermostSquareColor: const Color(0xFFD35400),
          concentricSquare2Color: const Color(0xFF30160F),
          concentricSquare3Color: const Color(0xFF963E19),
          outerSquareColor: const Color(0xFF4B2114),
          backgroundStripes: const [
            Color(0xFFC85A17),
            Color(0xFF2E140C),
            Color(0xFF7E3211),
          ],
          statusBarStyle: SystemUiOverlayStyle.dark,
        ),
        // Design 3: Crimson & Navy / Dark Burnt Orange
        SquareSplashTheme(
          name: 'Crimson & Navy',
          innermostSquareColor: const Color(0xFFE65F2B),
          concentricSquare2Color: const Color(0xFF1E3A4A),
          concentricSquare3Color: const Color(0xFFB83E14),
          outerSquareColor: const Color(0xFF15222E),
          backgroundStripes: const [
            Color(0xFFCC4E1F),
            Color(0xFF101C26),
            Color(0xFF385266),
          ],
          statusBarStyle: SystemUiOverlayStyle.light,
        ),
        // Design 4: Chestnut & Terracotta
        SquareSplashTheme(
          name: 'Chestnut & Terracotta',
          innermostSquareColor: const Color(0xFFD35400),
          concentricSquare2Color: const Color(0xFF3B1C12),
          concentricSquare3Color: const Color(0xFFA0491F),
          outerSquareColor: const Color(0xFF54281B),
          backgroundStripes: const [
            Color(0xFFB85526),
            Color(0xFF2B130D),
            Color(0xFF401E14),
          ],
          statusBarStyle: SystemUiOverlayStyle.dark,
        ),
        // Design 5: Ocean Teal / Cyan-Navy
        SquareSplashTheme(
          name: 'Ocean Teal',
          innermostSquareColor: const Color(0xFF6BB4B5),
          concentricSquare2Color: const Color(0xFF133845),
          concentricSquare3Color: const Color(0xFF257480),
          outerSquareColor: const Color(0xFF184F59),
          backgroundStripes: const [
            Color(0xFF368F97),
            Color(0xFF0D2730),
            Color(0xFF5DA3A6),
          ],
          statusBarStyle: SystemUiOverlayStyle.light,
        ),
        // Design 6: Deep Forest Teal / Dark Cyan
        SquareSplashTheme(
          name: 'Deep Forest Teal',
          innermostSquareColor: const Color(0xFF168B84),
          concentricSquare2Color: const Color(0xFF0A3434),
          concentricSquare3Color: const Color(0xFF126A67),
          outerSquareColor: const Color(0xFF0C4544),
          backgroundStripes: const [
            Color(0xFF126A67),
            Color(0xFF051F1F),
            Color(0xFF1FAAA1),
          ],
          statusBarStyle: SystemUiOverlayStyle.light,
        ),
        // Design 7: Kelly Green / Lime-Emerald
        SquareSplashTheme(
          name: 'Kelly Green',
          innermostSquareColor: const Color(0xFF0F7466),
          concentricSquare2Color: const Color(0xFF2E9D3E),
          concentricSquare3Color: const Color(0xFF5CBD38),
          outerSquareColor: const Color(0xFF42A83A),
          backgroundStripes: const [
            Color(0xFF46B332),
            Color(0xFF0A5046),
            Color(0xFF278D34),
          ],
          statusBarStyle: SystemUiOverlayStyle.dark,
        ),
        // Design 8: Periwinkle Blue / Cool Slate
        SquareSplashTheme(
          name: 'Periwinkle Blue',
          innermostSquareColor: const Color(0xFF7EAAB0),
          concentricSquare2Color: const Color(0xFF325776),
          concentricSquare3Color: const Color(0xFF4B83A6),
          outerSquareColor: const Color(0xFF3B6B8A),
          backgroundStripes: const [
            Color(0xFF5A94B2),
            Color(0xFF203A4E),
            Color(0xFF437596),
          ],
          statusBarStyle: SystemUiOverlayStyle.dark,
        ),
      ];
}

class SquareSplashPainter extends CustomPainter {
  final SquareSplashTheme theme;

  const SquareSplashPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Draw Slanted Wedge Background Stripes
    final numStripes = 14;
    final stripeHeight = h / (numStripes - 4);
    final slantDelta = 12.0; // More subtle slant to match Figma exactly

    double getLeftY(int i) {
      final baseY = i * stripeHeight;
      return baseY + (i % 2 == 0 ? -slantDelta : slantDelta);
    }

    double getRightY(int i) {
      final baseY = i * stripeHeight;
      return baseY + (i % 2 == 0 ? slantDelta : -slantDelta);
    }

    for (int i = -2; i < numStripes + 2; i++) {
      final leftTopY = getLeftY(i);
      final rightTopY = getRightY(i);
      final leftBottomY = getLeftY(i + 1);
      final rightBottomY = getRightY(i + 1);

      final paint = Paint()
        ..color = theme.backgroundStripes[(i + 100) % theme.backgroundStripes.length]
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(0, leftTopY)
        ..lineTo(w, rightTopY)
        ..lineTo(w, rightBottomY)
        ..lineTo(0, leftBottomY)
        ..close();

      canvas.drawPath(path, paint);
    }

    // 2. Draw Nested Concentric Squares in upper-center (centered behind visual focus)
    final cx = w / 2;
    final cy = h * 0.32;

    // Size squares proportionally to screen width to match Figma layout (made slightly smaller and more elegant)
    final size4 = w * 0.68;
    final size3 = w * 0.54;
    final size2 = w * 0.42;
    final size1 = w * 0.30;

    // Outermost (Square 4) - rotated counter-clockwise
    _drawRotatedSquare(canvas, cx, cy, size4, -0.07, size4 * 0.12, theme.outerSquareColor);

    // Square 3 - rotated clockwise
    _drawRotatedSquare(canvas, cx, cy, size3, 0.05, size3 * 0.12, theme.concentricSquare3Color);

    // Square 2 - rotated counter-clockwise
    _drawRotatedSquare(canvas, cx, cy, size2, -0.04, size2 * 0.12, theme.concentricSquare2Color);

    // Innermost (Square 1) - rotated clockwise
    _drawRotatedSquare(canvas, cx, cy, size1, 0.06, size1 * 0.12, theme.innermostSquareColor);
  }

  void _drawRotatedSquare(Canvas canvas, double cx, double cy, double squareSize, double rotation, double radius, Color color) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation);

    final rect = Rect.fromCenter(center: Offset.zero, width: squareSize, height: squareSize);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawRRect(rrect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SquareSplashPainter oldDelegate) {
    return oldDelegate.theme != theme;
  }
}

class SquareSplashBackground extends StatelessWidget {
  final SquareSplashTheme theme;
  final Widget? child;

  const SquareSplashBackground({
    super.key,
    required this.theme,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SquareSplashPainter(theme: theme),
      child: child ?? const SizedBox.expand(),
    );
  }
}
