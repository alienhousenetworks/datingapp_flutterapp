import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── 4 Figma Splash Variants ─────────────────────────────────
// Variant A: Purple/lavender checkered
// Variant B: Green/olive vertical stripes + blob card
// Variant C: Colorblock grid (teal/yellow/salmon/gray)
// Variant D: Green/purple mixed checkered

enum SplashVariant { A, B, C, D }

class SplashScreen extends StatefulWidget {
  final VoidCallback? onGetStarted;
  final VoidCallback? onLogin;

  const SplashScreen({super.key, this.onGetStarted, this.onLogin});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _slide;
  late SplashVariant _variant;

  @override
  void initState() {
    super.initState();
    _variant = SplashVariant.values[math.Random().nextInt(4)];

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildVariant(),
    );
  }

  Widget _buildVariant() {
    switch (_variant) {
      case SplashVariant.A:
        return _SplashVariantA(
          fade: _fade,
          slide: _slide,
          onGetStarted: widget.onGetStarted,
          onLogin: widget.onLogin,
        );
      case SplashVariant.B:
        return _SplashVariantB(
          fade: _fade,
          slide: _slide,
          onGetStarted: widget.onGetStarted,
          onLogin: widget.onLogin,
        );
      case SplashVariant.C:
        return _SplashVariantC(
          fade: _fade,
          slide: _slide,
          onGetStarted: widget.onGetStarted,
          onLogin: widget.onLogin,
        );
      case SplashVariant.D:
        return _SplashVariantD(
          fade: _fade,
          slide: _slide,
          onGetStarted: widget.onGetStarted,
          onLogin: widget.onLogin,
        );
    }
  }
}

// ──────────────────────────────────────────────────────────────
// VARIANT A: Purple/Lavender Checkered
// ──────────────────────────────────────────────────────────────
class _SplashVariantA extends StatelessWidget {
  final Animation<double> fade;
  final Animation<double> slide;
  final VoidCallback? onGetStarted;
  final VoidCallback? onLogin;

  const _SplashVariantA({
    required this.fade,
    required this.slide,
    this.onGetStarted,
    this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Checkered background
        CustomPaint(
          painter: _CheckeredPainter(
            color1: const Color(0xFFB39DDB), // lavender
            color2: const Color(0xFF7E57C2), // purple
          ),
          child: const SizedBox.expand(),
        ),
        SafeArea(
          child: FadeTransition(
            opacity: fade,
            child: AnimatedBuilder(
              animation: slide,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, slide.value),
                child: child,
              ),
              child: _SplashContent(
                cardStyle: _CardStyle.dashedYellow,
                headingText: 'Find your\npartner in life',
                subText:
                    'We created to bring together amazing singles who want to find love, laughter and happily ever after!',
                textColor: Colors.white,
                onGetStarted: onGetStarted,
                onLogin: onLogin,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// VARIANT B: Green/Olive Vertical Stripes + Blob Card
// ──────────────────────────────────────────────────────────────
class _SplashVariantB extends StatelessWidget {
  final Animation<double> fade;
  final Animation<double> slide;
  final VoidCallback? onGetStarted;
  final VoidCallback? onLogin;

  const _SplashVariantB({
    required this.fade,
    required this.slide,
    this.onGetStarted,
    this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Vertical stripes background
        CustomPaint(
          painter: _StripesPainter(
            colors: const [
              Color(0xFF6D7F3E), // olive green
              Color(0xFF4A5E2A), // dark olive
              Color(0xFF8A9F4B), // light olive
            ],
          ),
          child: const SizedBox.expand(),
        ),
        SafeArea(
          child: FadeTransition(
            opacity: fade,
            child: AnimatedBuilder(
              animation: slide,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, slide.value),
                child: child,
              ),
              child: _SplashContent(
                cardStyle: _CardStyle.blob,
                headingText: 'Find your\npartner in life',
                subText:
                    'We created to bring together amazing singles who want to find love, laughter and happily ever after!',
                textColor: Colors.white,
                buttonDark: true,
                onGetStarted: onGetStarted,
                onLogin: onLogin,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// VARIANT C: Colorblock Grid — Join screen
// ──────────────────────────────────────────────────────────────
class _SplashVariantC extends StatelessWidget {
  final Animation<double> fade;
  final Animation<double> slide;
  final VoidCallback? onGetStarted;
  final VoidCallback? onLogin;

  const _SplashVariantC({
    required this.fade,
    required this.slide,
    this.onGetStarted,
    this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        // Colorblock background
        CustomPaint(
          painter: _ColorblockPainter(),
          child: const SizedBox.expand(),
        ),
        // Floating content
        SafeArea(
          child: FadeTransition(
            opacity: fade,
            child: AnimatedBuilder(
              animation: slide,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, slide.value),
                child: child,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.1),
                    // Illustration placeholder
                    SizedBox(
                      height: size.height * 0.4,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Two figure silhouettes
                          _buildFigureA(),
                          Positioned(
                            right: 30,
                            bottom: 20,
                            child: _buildFigureB(),
                          ),
                          Positioned(
                            bottom: 10,
                            child: _buildHeartIcon(),
                          ),
                        ],
                      ),
                    ),
                    // Heading
                    Text(
                      'Find someone who\ngets you.',
                      textAlign: TextAlign.left,
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1A1A),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Real connections.\nMade for you.',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: const Color(0xFF555555),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Create Account button
                    _SplashButton(
                      label: '♥  Create Account',
                      onTap: onGetStarted,
                      dark: false,
                    ),
                    const SizedBox(height: 12),
                    // Continue as guest
                    GestureDetector(
                      onTap: onLogin,
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF7043),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Already have account? Log in',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFigureA() {
    return Container(
      width: 80,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.person, color: Colors.white70, size: 50),
    );
  }

  Widget _buildFigureB() {
    return Container(
      width: 70,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFF555555),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.person_outline, color: Colors.white70, size: 44),
    );
  }

  Widget _buildHeartIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(Icons.favorite, color: Color(0xFFFF7043), size: 26),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// VARIANT D: Green/Purple Mixed Checkered
// ──────────────────────────────────────────────────────────────
class _SplashVariantD extends StatelessWidget {
  final Animation<double> fade;
  final Animation<double> slide;
  final VoidCallback? onGetStarted;
  final VoidCallback? onLogin;

  const _SplashVariantD({
    required this.fade,
    required this.slide,
    this.onGetStarted,
    this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          painter: _CheckeredPainter(
            color1: const Color(0xFF8BC34A), // lime green
            color2: const Color(0xFF7E57C2), // purple
          ),
          child: const SizedBox.expand(),
        ),
        SafeArea(
          child: FadeTransition(
            opacity: fade,
            child: AnimatedBuilder(
              animation: slide,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, slide.value),
                child: child,
              ),
              child: _SplashContent(
                cardStyle: _CardStyle.dashedYellow,
                headingText: 'Find your\npartner in life',
                subText:
                    'We created to bring together amazing singles who want to find love, laughter and happily ever after!',
                textColor: Colors.white,
                onGetStarted: onGetStarted,
                onLogin: onLogin,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Shared Content Widget
// ──────────────────────────────────────────────────────────────

enum _CardStyle { dashedYellow, blob }

class _SplashContent extends StatelessWidget {
  final _CardStyle cardStyle;
  final String headingText;
  final String subText;
  final Color textColor;
  final bool buttonDark;
  final VoidCallback? onGetStarted;
  final VoidCallback? onLogin;

  const _SplashContent({
    required this.cardStyle,
    required this.headingText,
    required this.subText,
    required this.textColor,
    this.buttonDark = false,
    this.onGetStarted,
    this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28.0),
      child: Column(
        children: [
          SizedBox(height: size.height * 0.08),
          // Illustration Card
          SizedBox(
            height: size.height * 0.38,
            child: cardStyle == _CardStyle.dashedYellow
                ? _DashedCard()
                : _BlobCard(),
          ),
          const SizedBox(height: 24),
          // Heading
          Text(
            headingText,
            textAlign: TextAlign.left,
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: textColor,
              height: 1.1,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subText,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: textColor.withOpacity(0.8),
              height: 1.45,
            ),
          ),
          const Spacer(),
          _SplashButton(
            label: 'Join now',
            onTap: onGetStarted,
            dark: buttonDark,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onLogin,
            child: Text(
              'Already have account? Log in',
              style: GoogleFonts.outfit(
                color: textColor.withOpacity(0.75),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

class _DashedCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _DashedBorderPainter(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_rounded,
                    color: const Color(0xFFFF2E74), size: 40),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        color: Colors.grey[400], size: 28),
                    const SizedBox(width: 8),
                    Icon(Icons.favorite_border_rounded,
                        color: Colors.grey[400], size: 28),
                    const SizedBox(width: 8),
                    Icon(Icons.star_border_rounded,
                        color: Colors.grey[400], size: 28),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_rounded,
                        color: const Color(0xFFFF2E74), size: 18),
                    const SizedBox(width: 4),
                    Icon(Icons.favorite_rounded,
                        color: const Color(0xFFFF2E74), size: 22),
                    const SizedBox(width: 4),
                    Icon(Icons.favorite_rounded,
                        color: const Color(0xFFFF2E74), size: 18),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlobCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipPath(
        clipper: _BlobClipper(),
        child: Container(
          width: 200,
          height: 210,
          color: const Color(0xFF2E3B1C),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              Icon(Icons.people_rounded, color: Colors.white70, size: 70),
              const SizedBox(height: 8),
              Text(
                'Actions',
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool dark;

  const _SplashButton({
    required this.label,
    this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1A1A1A) : const Color(0xFFFFD700),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: dark ? Colors.white : const Color(0xFF1A1A1A),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Custom Painters
// ──────────────────────────────────────────────────────────────

class _CheckeredPainter extends CustomPainter {
  final Color color1;
  final Color color2;

  const _CheckeredPainter({required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 40.0;
    final rows = (size.height / tileSize).ceil() + 2;
    final cols = (size.width / tileSize).ceil() + 2;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final paint = Paint()
          ..color = (row + col) % 2 == 0 ? color1 : color2;
        canvas.drawRect(
          Rect.fromLTWH(
            col * tileSize,
            row * tileSize,
            tileSize,
            tileSize,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckeredPainter old) =>
      old.color1 != color1 || old.color2 != color2;
}

class _StripesPainter extends CustomPainter {
  final List<Color> colors;

  const _StripesPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final stripeWidth = size.width / colors.length / 2;
    int colorIdx = 0;
    double x = 0;
    while (x < size.width) {
      final paint = Paint()..color = colors[colorIdx % colors.length];
      canvas.drawRect(
        Rect.fromLTWH(x, 0, stripeWidth, size.height),
        paint,
      );
      x += stripeWidth;
      colorIdx++;
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ColorblockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 4 blocks: teal (top-left), yellow (top-right), salmon (bottom-left), gray (bottom-right)
    final blocks = [
      [const Color(0xFF80CBC4), Rect.fromLTWH(0, 0, w * 0.5, h * 0.5)],
      [const Color(0xFFFFF176), Rect.fromLTWH(w * 0.5, 0, w * 0.5, h * 0.5)],
      [const Color(0xFFFF7043), Rect.fromLTWH(0, h * 0.5, w * 0.5, h * 0.5)],
      [const Color(0xFFBDBDBD), Rect.fromLTWH(w * 0.5, h * 0.5, w * 0.5, h * 0.5)],
    ];
    for (final block in blocks) {
      canvas.drawRect(block[1] as Rect, Paint()..color = block[0] as Color);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFFD700)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 6.0;
    final radius = Radius.circular(14);
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final rrect = RRect.fromRectAndRadius(rect, radius);

    _drawDashedRRect(canvas, rrect, paint, dashWidth, dashSpace);
  }

  void _drawDashedRRect(
      Canvas canvas, RRect rrect, Paint paint, double dashW, double dashS) {
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      while (dist < metric.length) {
        final end = (dist + dashW).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, end), paint);
        dist += dashW + dashS;
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _BlobClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(w * 0.1, h * 0.05)
      ..quadraticBezierTo(w * 0.5, -h * 0.08, w * 0.9, h * 0.05)
      ..quadraticBezierTo(w * 1.1, h * 0.45, w * 0.92, h * 0.9)
      ..quadraticBezierTo(w * 0.5, h * 1.1, w * 0.08, h * 0.9)
      ..quadraticBezierTo(-w * 0.1, h * 0.5, w * 0.1, h * 0.05)
      ..close();
  }

  @override
  bool shouldReclip(_) => false;
}
