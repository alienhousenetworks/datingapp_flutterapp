import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

// ─────────────────────────────────────────────────────────────
// Catch Game Screen
// User tilts phone to move a net and intercept the paper plane.
// Listens to accelerometer events with pan gesture fallback.
// ─────────────────────────────────────────────────────────────

import '../../providers/paper_plane_provider.dart';

class CatchGameScreen extends ConsumerStatefulWidget {
  const CatchGameScreen({super.key});

  @override
  ConsumerState<CatchGameScreen> createState() => _CatchGameScreenState();
}

class _CatchGameScreenState extends ConsumerState<CatchGameScreen>
    with TickerProviderStateMixin {
  // ── Plane path animation ──
  late AnimationController _planeController;
  late Animation<double> _planeT; // 0.0 → 1.0 across the bezier path

  // ── Net position (moved by tilt or pan gesture) ──
  Offset _netPosition = const Offset(0.5, 0.7); // normalized 0-1
  bool _hasCaught = false;

  // ── Accelerometer stream subscription ──
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;

  // ── Countdown ──
  late Timer _countdownTimer;
  int _secondsLeft = 60;

  // ── Path seed (from server) ──
  int _pathSeed = 42;

  // ── Cloud positions (decorative) ──
  late List<Offset> _cloudPositions;

  @override
  void initState() {
    super.initState();

    final gameState = ref.read(catchGameProvider);
    _secondsLeft = gameState.gameConfig?.gameWindowSeconds ?? 60;
    _pathSeed = gameState.gameConfig?.planePathSeed ?? 42;
    _cloudPositions = _generateClouds();

    _planeController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _secondsLeft),
    );
    _planeT = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _planeController, curve: Curves.easeInOut),
    );

    _planeController.forward();
    _planeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_hasCaught) {
        _onGameOver();
      }
    });

    _startCountdown();
    _initSensors();
  }

  void _initSensors() {
    // Listen to accelerometer events. On a real device, tilting changes values.
    // x > 0 means left tilt, x < 0 means right tilt.
    // y > 0 means forward tilt, y < 0 means backward tilt.
    _sensorSubscription = accelerometerEventStream().listen((event) {
      if (!mounted || _hasCaught) return;
      setState(() {
        // Map acceleration values to screen coordinates (smooth scaling)
        double dx = (_netPosition.dx - event.x * 0.007).clamp(0.05, 0.95);
        double dy = (_netPosition.dy + event.y * 0.007).clamp(0.05, 0.95);
        _netPosition = Offset(dx, dy);
      });
    }, onError: (_) {
      // Stream error fallback is handled gracefully via gesture pan details
    });
  }

  List<Offset> _generateClouds() {
    final rng = math.Random(_pathSeed);
    return List.generate(
      5,
      (_) => Offset(rng.nextDouble(), rng.nextDouble() * 0.5),
    );
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft = math.max(0, _secondsLeft - 1);
      });
      if (_secondsLeft == 0) {
        t.cancel();
        if (!_hasCaught) _onGameOver();
      }
    });
  }

  void _onGameOver() {
    // Plane escaped — pass to next user
    ref.read(catchGameProvider.notifier).pass();
    _showEscapedOverlay();
  }

  void _showEscapedOverlay() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EscapedDialog(
        onDone: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop(); // back to feed/home
        },
      ),
    );
  }

  // ── Check collision ──
  void _checkCollision(Offset planeNorm, Size screenSize) {
    if (_hasCaught) return;

    final planePx =
        Offset(planeNorm.dx * screenSize.width, planeNorm.dy * screenSize.height);
    final netPx = Offset(
        _netPosition.dx * screenSize.width, _netPosition.dy * screenSize.height);

    final dist = (planePx - netPx).distance;
    if (dist < 55) {
      // HIT!
      _hasCaught = true;
      _planeController.stop();
      _countdownTimer.cancel();
      HapticFeedback.heavyImpact();
      _onPlaneCaught();
    }
  }

  void _onPlaneCaught() {
    ref.read(catchGameProvider.notifier).planeCaught();
    // Navigation handled by watching provider state in build()
  }

  // ── Bezier path for plane ──
  Offset _planePositionNorm(double t, Size size) {
    final rng = math.Random(_pathSeed);
    // Control points (normalized)
    const p0 = Offset(-0.1, 0.3);
    final p1 = Offset(0.3 + rng.nextDouble() * 0.2, 0.1);
    final p2 = Offset(0.5 + rng.nextDouble() * 0.2, 0.6);
    const p3 = Offset(1.1, 0.4);

    // Cubic bezier
    final mt = 1 - t;
    return Offset(
      mt * mt * mt * p0.dx +
          3 * mt * mt * t * p1.dx +
          3 * mt * t * t * p2.dx +
          t * t * t * p3.dx,
      mt * mt * mt * p0.dy +
          3 * mt * mt * t * p1.dy +
          3 * mt * t * t * p2.dy +
          t * t * t * p3.dy,
    );
  }

  @override
  void dispose() {
    _planeController.dispose();
    _countdownTimer.cancel();
    _sensorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch game state — navigate when caught
    ref.listen(catchGameProvider, (prev, next) {
      if (next.phase == GamePhase.revealed) {
        // Go to message reveal screen
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/paper-plane/reveal');
        }
      }
    });

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        // Pan gesture drives net position (simulates tilt for devices
        // where sensor package is not yet integrated)
        onPanUpdate: (details) {
          setState(() {
            _netPosition = Offset(
              (_netPosition.dx + details.delta.dx / size.width).clamp(0.05, 0.95),
              (_netPosition.dy + details.delta.dy / size.height).clamp(0.05, 0.95),
            );
          });
        },
        child: AnimatedBuilder(
          animation: _planeT,
          builder: (context, _) {
            final planeNorm = _planePositionNorm(_planeT.value, size);
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _checkCollision(planeNorm, size));

            return CustomPaint(
              size: size,
              painter: _GameCanvasPainter(
                planeNorm: planeNorm,
                netNorm: _netPosition,
                cloudPositions: _cloudPositions,
                secondsLeft: _secondsLeft,
                totalSeconds: ref.read(catchGameProvider).gameConfig?.gameWindowSeconds ?? 60,
                hasCaught: _hasCaught,
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // ── Top bar ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_secondsLeft}s',
                              style: TextStyle(
                                color: _secondsLeft <= 10
                                    ? Colors.red
                                    : Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Progress bar
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: _secondsLeft /
                                      (ref.read(catchGameProvider).gameConfig?.gameWindowSeconds ?? 60),
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _secondsLeft <= 10
                                        ? Colors.red
                                        : const Color(0xFFFF2E74),
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    // ── Bottom hint ──
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Swipe to move your net • Catch the plane!',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Game Canvas Painter ──────────────────────────────────────
class _GameCanvasPainter extends CustomPainter {
  final Offset planeNorm;
  final Offset netNorm;
  final List<Offset> cloudPositions;
  final int secondsLeft;
  final int totalSeconds;
  final bool hasCaught;

  _GameCanvasPainter({
    required this.planeNorm,
    required this.netNorm,
    required this.cloudPositions,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.hasCaught,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Sky gradient background ──
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final skyGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF0A0A1A),
        const Color(0xFF1A1040),
        const Color(0xFF2D1B6E),
      ],
    );
    canvas.drawRect(skyRect, Paint()..shader = skyGrad.createShader(skyRect));

    // ── Stars ──
    final starPaint = Paint()..color = Colors.white.withOpacity(0.6);
    final rng = math.Random(42);
    for (int i = 0; i < 60; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height * 0.7),
        rng.nextDouble() * 1.5,
        starPaint,
      );
    }

    // ── Clouds ──
    for (final cloud in cloudPositions) {
      _drawCloud(canvas, size,
          Offset(cloud.dx * size.width, cloud.dy * size.height));
    }

    // ── Plane ──
    if (!hasCaught) {
      _drawPlane(canvas, size, planeNorm);
    }

    // ── Net ──
    _drawNet(canvas, size, netNorm);
  }

  void _drawCloud(Canvas canvas, Size size, Offset center) {
    final paint = Paint()..color = Colors.white.withOpacity(0.08);
    canvas.drawOval(
        Rect.fromCenter(center: center, width: 80, height: 30), paint);
    canvas.drawOval(
        Rect.fromCenter(
            center: center.translate(-20, -12), width: 50, height: 30),
        paint);
    canvas.drawOval(
        Rect.fromCenter(
            center: center.translate(20, -8), width: 60, height: 28),
        paint);
  }

  void _drawPlane(Canvas canvas, Size size, Offset norm) {
    final px = norm.dx * size.width;
    final py = norm.dy * size.height;

    canvas.save();
    canvas.translate(px, py);

    final planePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = const Color(0xFFFF2E74).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    // Glow
    canvas.drawCircle(Offset.zero, 18, shadowPaint);

    // Plane body
    final path = Path()
      ..moveTo(28, 0)   // nose
      ..lineTo(-20, -12) // top wing tip
      ..lineTo(-8, -3)  // top body
      ..lineTo(-20, 12)  // bottom wing tip
      ..lineTo(-10, 3)  // bottom body
      ..close();

    canvas.drawPath(path, planePaint);

    // Highlight
    canvas.drawPath(
      Path()
        ..moveTo(28, 0)
        ..lineTo(-8, -3)
        ..lineTo(-10, 3)
        ..close(),
      Paint()..color = Colors.white.withOpacity(0.3),
    );

    canvas.restore();
  }

  void _drawNet(Canvas canvas, Size size, Offset norm) {
    final px = norm.dx * size.width;
    final py = norm.dy * size.height;

    canvas.save();
    canvas.translate(px, py);

    // Handle
    final handlePaint = Paint()
      ..color = const Color(0xFFFF2E74)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(0, 20), const Offset(0, 50), handlePaint);

    // Net circle rim
    final rimPaint = Paint()
      ..color = const Color(0xFFFF2E74)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, 28, rimPaint);

    // Net mesh lines
    final meshPaint = Paint()
      ..color = const Color(0xFFFF2E74).withOpacity(0.5)
      ..strokeWidth = 1;
    for (double x = -25; x <= 25; x += 10) {
      final top = Offset(x, -math.sqrt(math.max(0, 28 * 28 - x * x)));
      final bot = Offset(x, math.sqrt(math.max(0, 28 * 28 - x * x)));
      canvas.drawLine(top, bot, meshPaint);
    }
    for (double y = -20; y <= 20; y += 10) {
      final left = Offset(-math.sqrt(math.max(0, 28 * 28 - y * y)), y);
      final right = Offset(math.sqrt(math.max(0, 28 * 28 - y * y)), y);
      canvas.drawLine(left, right, meshPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_GameCanvasPainter old) => true;
}

// ─── Plane Escaped Dialog ─────────────────────────────────────
class _EscapedDialog extends StatelessWidget {
  final VoidCallback onDone;

  const _EscapedDialog({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😅', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            const Text(
              'It got away!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'The plane slipped past you.\nMaybe catch the next one?',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2E74),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Back', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
