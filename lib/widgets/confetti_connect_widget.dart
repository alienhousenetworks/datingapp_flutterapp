import 'dart:math' as math;
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// Confetti Connect Widget
// Creates a premium particle explosion effect when matching.
// Done purely in custom painters (no package dependency).
// ─────────────────────────────────────────────────────────────

class ConfettiConnectWidget extends StatefulWidget {
  final Widget child;
  final bool startTrigger;

  const ConfettiConnectWidget({
    super.key,
    required this.child,
    this.startTrigger = true,
  });

  @override
  State<ConfettiConnectWidget> createState() => _ConfettiConnectWidgetState();
}

class _ConfettiConnectWidgetState extends State<ConfettiConnectWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.startTrigger) {
      _triggerExplosion();
    }
  }

  void _triggerExplosion() {
    final rng = math.Random();
    _particles.clear();
    for (int i = 0; i < 80; i++) {
      _particles.add(_ConfettiParticle(
        color: _colors[rng.nextInt(_colors.length)],
        angle: rng.nextDouble() * 2 * math.pi,
        speed: 150 + rng.nextDouble() * 250,
        rotationSpeed: rng.nextDouble() * 4 * math.pi - 2 * math.pi,
        size: 6 + rng.nextDouble() * 8,
        shape: rng.nextBool() ? _ParticleShape.circle : _ParticleShape.rect,
      ));
    }
    _ctrl.forward(from: 0.0);
  }

  static const _colors = [
    Color(0xFFFF2E74), // Spicy brand pink
    Color(0xFFFF6B35), // Accent orange
    Color(0xFF4ADE80), // Match success green
    Color(0xFF60A5FA), // Light blue
    Color(0xFFFBBF24), // Gold
    Color(0xFFA78BFA), // Lavender
  ];

  @override
  void didUpdateWidget(ConfettiConnectWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startTrigger && !oldWidget.startTrigger) {
      _triggerExplosion();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              if (!_ctrl.isAnimating) return const SizedBox.shrink();
              return CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(
                  particles: _particles,
                  progress: _ctrl.value,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _ParticleShape { circle, rect }

class _ConfettiParticle {
  final Color color;
  final double angle;
  final double speed;
  final double rotationSpeed;
  final double size;
  final _ParticleShape shape;

  _ConfettiParticle({
    required this.color,
    required this.angle,
    required this.speed,
    required this.rotationSpeed,
    required this.size,
    required this.shape,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 3; // Center explosion near the top hero badge

    final double gravity = 400.0 * progress;

    for (final p in particles) {
      // Calculate new position
      final double distance = p.speed * progress;
      final double px = cx + math.cos(p.angle) * distance;
      final double py = cy + math.sin(p.angle) * distance + (gravity * progress);

      // Rotate particle
      final double rotation = p.rotationSpeed * progress;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(rotation);

      // Fade out progress
      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withOpacity(opacity);

      if (p.shape == _ParticleShape.circle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          paint,
        );
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
