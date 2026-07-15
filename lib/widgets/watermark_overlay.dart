import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_provider.dart';

class WatermarkOverlay extends ConsumerWidget {
  final Widget child;

  const WatermarkOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final viewerText = profileState.profile?.username ?? profileState.profile?.id ?? 'viewer';
    final watermarkText = 'viewer: $viewerText';

    return ClipRect(
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _WatermarkPainter(text: watermarkText),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  final String text;

  _WatermarkPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.12),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(1, 1),
              blurRadius: 1,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textWidth = textPainter.width;
    final textHeight = textPainter.height;

    // Angle of diagonal rotation (30 degrees)
    const angle = -30 * math.pi / 180;
    
    final double stepX = textWidth + 80;
    final double stepY = textHeight + 60;

    // Draw grid to cover the canvas
    canvas.save();
    
    // Determine bounds to cover after rotation
    final double maxDim = math.max(size.width, size.height);
    
    for (double y = -maxDim; y < size.height + maxDim; y += stepY) {
      for (double x = -maxDim; x < size.width + maxDim; x += stepX) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(angle);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter oldDelegate) {
    return oldDelegate.text != text;
  }
}
