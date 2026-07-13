import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../providers/paper_plane_provider.dart';
import 'compose_screen.dart';
import 'my_planes_screen.dart';
import 'message_reveal_screen.dart';

// ─────────────────────────────────────────────────────────────
// Catch Game Screen
// User tilts phone or swipes to move insect net and catch the plane.
// Styled exactly like the bright blue-purple design matching the screenshot.
// ─────────────────────────────────────────────────────────────

class CatchGameScreen extends ConsumerStatefulWidget {
  const CatchGameScreen({super.key});

  @override
  ConsumerState<CatchGameScreen> createState() => _CatchGameScreenState();
}

class GamePlane {
  final String id;
  final String sticker;
  final double distanceKm;
  final bool isHighPriority;
  double progress;
  final double speed;
  final int pathSeed;

  GamePlane({
    required this.id,
    required this.sticker,
    required this.distanceKm,
    required this.isHighPriority,
    required this.progress,
    required this.speed,
    required this.pathSeed,
  });
}

class DecoPlane {
  final double x;
  final double y;
  final double scale;
  final double angle;
  final double opacity;

  DecoPlane({
    required this.x,
    required this.y,
    required this.scale,
    required this.angle,
    required this.opacity,
  });
}

class _CatchGameScreenState extends ConsumerState<CatchGameScreen>
    with TickerProviderStateMixin {
  // ── Game tick controller for updating 20 planes ──
  late AnimationController _gameTickController;

  // ── Morph Animations ──
  late AnimationController _morphController;
  late Animation<double> _morphProgress;

  // ── Net position (moved by tilt or pan gesture) ──
  Offset _netPosition = const Offset(0.5, 0.5); // normalized 0-1
  bool _hasCaught = false;
  bool _isHoveringClose = false;

  // ── Accelerometer stream subscription ──
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;

  // ── Countdown ──
  late Timer _countdownTimer;
  int _secondsLeft = 60;
  int _pathSeed = 42;
  late List<Offset> _cloudPositions;

  // Track exact contact position
  Offset _collisionNorm = Offset.zero;

  // List of active planes flying in the sky
  List<GamePlane> _gamePlanes = [];
  bool _planesInitialized = false;

  // Decorative planes flying in background to match visual screenshot
  List<DecoPlane> _decoPlanes = [];

  @override
  void initState() {
    super.initState();

    final gameState = ref.read(catchGameProvider);
    _secondsLeft = gameState.gameConfig?.gameWindowSeconds ?? 120;
    _pathSeed = gameState.gameConfig?.planePathSeed ?? 42;
    _cloudPositions = _generateClouds();
    _decoPlanes = _generateDecoPlanes();

    _gameTickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(() {
        if (_hasCaught) return;
        setState(() {
          // Initialize planes if we loaded them from provider
          final skyPlanes = ref.read(catchGameProvider).skyPlanes;
          if (!_planesInitialized && skyPlanes.isNotEmpty) {
            final rng = math.Random();
            _gamePlanes = skyPlanes.map((sp) {
              return GamePlane(
                id: sp.id,
                distanceKm: sp.distanceKm,
                isHighPriority: sp.isHighPriority,
                progress: rng.nextDouble(), // staggered starting position
                speed: 0.0012 + rng.nextDouble() * 0.0018, // independent speed
                pathSeed: rng.nextInt(10000),
                sticker: sp.sticker,
              );
            }).toList();
            _planesInitialized = true;
          }

          // Update position for all planes
          for (final gp in _gamePlanes) {
            gp.progress += gp.speed;
            if (gp.progress > 1.0) {
              gp.progress = 0.0;
            }
          }
        });
      })..repeat();

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _morphProgress = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeInOut,
    );

    _startCountdown();
    _initSensors();
  }

  void _initSensors() {
    _sensorSubscription = accelerometerEventStream().listen((event) {
      if (!mounted || _hasCaught) return;
      setState(() {
        double dx = (_netPosition.dx - event.x * 0.007).clamp(0.05, 0.95);
        double dy = (_netPosition.dy + event.y * 0.007).clamp(0.05, 0.95);
        _netPosition = Offset(dx, dy);
      });
    }, onError: (_) {});
  }

  List<Offset> _generateClouds() {
    final rng = math.Random(_pathSeed);
    return List.generate(
      5,
      (_) => Offset(rng.nextDouble(), rng.nextDouble() * 0.5),
    );
  }

  List<DecoPlane> _generateDecoPlanes() {
    final rng = math.Random(_pathSeed + 1);
    return List.generate(35, (index) {
      return DecoPlane(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        scale: 0.4 + rng.nextDouble() * 0.8,
        angle: -0.5 + rng.nextDouble() * 1.0,
        opacity: 0.25 + rng.nextDouble() * 0.35,
      );
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (!_hasCaught) {
        setState(() {
          _secondsLeft = math.max(0, _secondsLeft - 1);
        });
        if (_secondsLeft == 0) {
          t.cancel();
          _onGameOver();
        }
      } else {
        t.cancel();
      }
    });
  }

  void _onGameOver() {
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
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _checkCollision(Size screenSize) {
    if (_hasCaught) return;

    GamePlane? closestPlane;
    double minDistance = 55.0; // Net radius threshold
    Offset closestPlaneNorm = Offset.zero;
    bool isAnyPlaneNear = false;

    for (final gp in _gamePlanes) {
      final planeNorm = _planePositionNorm(gp.progress, gp.pathSeed);
      final planePx = Offset(planeNorm.dx * screenSize.width, planeNorm.dy * screenSize.height);
      final netPx = Offset(_netPosition.dx * screenSize.width, _netPosition.dy * screenSize.height);

      final dist = (planePx - netPx).distance;
      if (dist < 95.0) {
        isAnyPlaneNear = true;
      }
      if (dist < minDistance) {
        minDistance = dist;
        closestPlane = gp;
        closestPlaneNorm = planeNorm;
      }
    }

    if (isAnyPlaneNear != _isHoveringClose) {
      setState(() {
        _isHoveringClose = isAnyPlaneNear;
      });
    }

    if (closestPlane != null) {
      _hasCaught = true;
      _collisionNorm = closestPlaneNorm;
      _gameTickController.stop();
      _countdownTimer.cancel();
      HapticFeedback.heavyImpact();
      _onPlaneCaught(closestPlane);
    }
  }

  void _onPlaneCaught(GamePlane gp) async {
    final notifier = ref.read(catchGameProvider.notifier);
    await notifier.catchPlane(gp.id);
    await notifier.planeCaught();
    _morphController.forward().then((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MessageRevealScreen()),
        );
      }
    });
  }

  Offset _planePositionNorm(double t, int seed) {
    final rng = math.Random(seed);
    final direction = rng.nextInt(3);
    Offset p0, p1, p2, p3;
    if (direction == 0) {
      // Left to right
      p0 = Offset(-0.15, 0.2 + rng.nextDouble() * 0.4);
      p1 = Offset(0.3 + rng.nextDouble() * 0.2, 0.1 + rng.nextDouble() * 0.3);
      p2 = Offset(0.5 + rng.nextDouble() * 0.2, 0.4 + rng.nextDouble() * 0.4);
      p3 = Offset(1.15, 0.2 + rng.nextDouble() * 0.5);
    } else if (direction == 1) {
      // Right to left
      p0 = Offset(1.15, 0.2 + rng.nextDouble() * 0.4);
      p1 = Offset(0.7 - rng.nextDouble() * 0.2, 0.1 + rng.nextDouble() * 0.3);
      p2 = Offset(0.5 - rng.nextDouble() * 0.2, 0.4 + rng.nextDouble() * 0.4);
      p3 = Offset(-0.15, 0.2 + rng.nextDouble() * 0.5);
    } else {
      // Diagonal top-left to bottom-right
      p0 = Offset(0.2 + rng.nextDouble() * 0.6, -0.15);
      p1 = Offset(0.3 + rng.nextDouble() * 0.4, 0.3 + rng.nextDouble() * 0.3);
      p2 = Offset(0.5 + rng.nextDouble() * 0.4, 0.6 + rng.nextDouble() * 0.3);
      p3 = Offset(0.2 + rng.nextDouble() * 0.6, 1.15);
    }

    final mt = 1 - t;
    final basePos = Offset(
      mt * mt * mt * p0.dx +
          3 * mt * mt * t * p1.dx +
          3 * mt * t * t * p2.dx +
          t * t * t * p3.dx,
      mt * mt * mt * p0.dy +
          3 * mt * mt * t * p1.dy +
          3 * mt * t * t * p2.dy +
          t * t * t * p3.dy,
    );

    // Dynamic wave drift based on the unique seed
    final driftX = math.sin(t * math.pi * 4.0 + seed) * 0.035;
    final driftY = math.cos(t * math.pi * 3.0 + seed) * 0.025;

    return Offset(basePos.dx + driftX, basePos.dy + driftY);
  }

  void _showInstructionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF16161C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('How to Catch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Move the net by swiping on your screen or tilting your phone.\n\nGuide the net overlay directly over any flying white paper plane to catch it and read the secret message!',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: Color(0xFF7C98F6), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _gameTickController.dispose();
    _morphController.dispose();
    _countdownTimer.cancel();
    _sensorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final gameState = ref.watch(catchGameProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFACC2FA),
      body: GestureDetector(
        onPanUpdate: (details) {
          if (_hasCaught) return;
          setState(() {
            _netPosition = Offset(
              (_netPosition.dx + details.delta.dx / size.width).clamp(0.05, 0.95),
              (_netPosition.dy + details.delta.dy / size.height).clamp(0.05, 0.95),
            );
          });
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([_gameTickController, _morphProgress]),
          builder: (context, _) {
            if (!_hasCaught) {
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _checkCollision(size));
            }

            return SizedBox.expand(
              child: Stack(
                children: [
                  // ── Game Canvas ──
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GameCanvasPainter(
                        gamePlanes: _gamePlanes,
                        decoPlanes: _decoPlanes,
                        getPlanePos: _planePositionNorm,
                        netNorm: _netPosition,
                        cloudPositions: _cloudPositions,
                        secondsLeft: _secondsLeft,
                        totalSeconds: gameState.gameConfig?.gameWindowSeconds ?? 120,
                        hasCaught: _hasCaught,
                        morphProgress: _morphProgress.value,
                        collisionNorm: _collisionNorm,
                        isHoveringClose: _isHoveringClose,
                      ),
                    ),
                  ),

                  // ── Top Bar HUD ──
                  if (!_hasCaught)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: Text(
                                '${_secondsLeft}s',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _secondsLeft /
                                        (gameState.gameConfig?.gameWindowSeconds ?? 60),
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    valueColor: const AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Bottom UI Overlays (Matching exactly the screenshot) ──
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Circular action button with send paper plane icon
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PaperPlaneComposeScreen()),
                            );
                          },
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.send_rounded,
                              color: Color(0xFF8BA5F8),
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Pill-shaped outlined button "SEE YOUR PLANES"
                        OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const MyPlanesScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                          ),
                          child: const Text(
                            'SEE YOUR PLANES',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Outlined info (i) button in bottom right corner
                  Positioned(
                    bottom: 30,
                    right: 24,
                    child: IconButton(
                      icon: const Icon(Icons.info_outline, color: Colors.white, size: 24),
                      onPressed: _showInstructionDialog,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Game Canvas Painter ──────────────
class _GameCanvasPainter extends CustomPainter {
  final List<GamePlane> gamePlanes;
  final List<DecoPlane> decoPlanes;
  final Offset Function(double t, int seed) getPlanePos;
  final Offset netNorm;
  final List<Offset> cloudPositions;
  final int secondsLeft;
  final int totalSeconds;
  final bool hasCaught;
  final double morphProgress;
  final Offset collisionNorm;
  final bool isHoveringClose;

  _GameCanvasPainter({
    required this.gamePlanes,
    required this.decoPlanes,
    required this.getPlanePos,
    required this.netNorm,
    required this.cloudPositions,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.hasCaught,
    required this.morphProgress,
    required this.collisionNorm,
    required this.isHoveringClose,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Bright blue-purple gradient sky background
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final skyGrad = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFACC2FA),
        Color(0xFFCEBFFF),
      ],
    );
    canvas.drawRect(skyRect, Paint()..shader = skyGrad.createShader(skyRect));

    // Clouds
    for (final cloud in cloudPositions) {
      _drawCloud(canvas, size, Offset(cloud.dx * size.width, cloud.dy * size.height));
    }

    // Draw decorative background planes to populate the sky
    for (final dp in decoPlanes) {
      _drawDecoPlane(canvas, size, dp);
    }

    // Net
    if (!hasCaught || morphProgress < 1.0) {
      _drawNet(canvas, size, netNorm);
    }

    // Draw all active catching planes
    if (!hasCaught) {
      for (final gp in gamePlanes) {
        final pos = getPlanePos(gp.progress, gp.pathSeed);
        _drawPlane(canvas, size, pos);
      }
    } else if (morphProgress < 1.0) {
      _drawMorphTarget(canvas, size);
    }
  }

  void _drawCloud(Canvas canvas, Size size, Offset center) {
    final paint = Paint()..color = Colors.white.withOpacity(0.12);
    canvas.drawOval(Rect.fromCenter(center: center, width: 90, height: 32), paint);
    canvas.drawOval(Rect.fromCenter(center: center.translate(-25, -12), width: 60, height: 32), paint);
    canvas.drawOval(Rect.fromCenter(center: center.translate(25, -8), width: 70, height: 30), paint);
  }

  void _drawDecoPlane(Canvas canvas, Size size, DecoPlane dp) {
    final px = dp.x * size.width;
    final py = dp.y * size.height;

    canvas.save();
    canvas.translate(px, py);
    canvas.scale(dp.scale);
    canvas.rotate(dp.angle);

    final planePaint = Paint()
      ..color = Colors.white.withOpacity(dp.opacity)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(20, 0)
      ..lineTo(-15, -8)
      ..lineTo(-6, -2)
      ..lineTo(-15, 8)
      ..lineTo(-8, 2)
      ..close();

    canvas.drawPath(path, planePaint);
    canvas.restore();
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
      ..color = Colors.white.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawCircle(Offset.zero, 14, shadowPaint);

    final path = Path()
      ..moveTo(20, 0)
      ..lineTo(-15, -8)
      ..lineTo(-6, -2)
      ..lineTo(-15, 8)
      ..lineTo(-8, 2)
      ..close();

    canvas.drawPath(path, planePaint);

    final foldPaint = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-6, -2), const Offset(20, 0), foldPaint);

    canvas.restore();
  }

  void _drawNet(Canvas canvas, Size size, Offset norm) {
    final px = norm.dx * size.width;
    final py = norm.dy * size.height;

    canvas.save();
    canvas.translate(px, py);
    canvas.rotate(0.2); // Tilt rim like screenshot

    // If hovering close, draw a glowing attraction halo
    if (isHoveringClose && !hasCaught) {
      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 18);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 80, height: 65), glowPaint);
    }

    // Woven Net Bag/Pocket (Hanging down, clean white)
    final netBagPath = Path()
      ..moveTo(-35, 5)
      ..quadraticBezierTo(-25, 75, 0, 95)
      ..quadraticBezierTo(25, 75, 35, 5)
      ..quadraticBezierTo(0, 15, -35, 5)
      ..close();
    
    final netBagPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    canvas.drawPath(netBagPath, netBagPaint);

    final netBagOutline = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(netBagPath, netBagOutline);

    // Cross lines for the net pocket bag mesh
    final meshPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1;
    for (double i = -25; i <= 25; i += 8) {
      canvas.drawLine(Offset(i, 8), Offset(i / 1.8, 88), meshPaint);
    }
    for (double y = 15; y <= 85; y += 12) {
      final widthAtY = 35 * (1.0 - (y - 15) / 130);
      canvas.drawLine(Offset(-widthAtY, y), Offset(widthAtY, y), meshPaint);
    }

    // Long clean white handle
    final handlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 26), const Offset(-15, 180), handlePaint);

    // White rim circle (ellipse style)
    final rimPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke;
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 70, height: 55), rimPaint);

    final rimInnerPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 66, height: 51), rimInnerPaint);

    canvas.restore();
  }

  void _drawMorphTarget(Canvas canvas, Size size) {
    final startX = collisionNorm.dx * size.width;
    final startY = collisionNorm.dy * size.height;

    final netX = netNorm.dx * size.width;
    final netY = netNorm.dy * size.height;

    final centerX = size.width / 2;
    final centerY = size.height * 0.45;

    if (morphProgress < 0.4) {
      // Phase 1: Plane falls into net center
      final t = morphProgress / 0.4;
      final px = startX + (netX - startX) * t;
      final py = startY + (netY - startY) * t;

      canvas.save();
      canvas.translate(px, py);
      canvas.scale(1.0 - t * 0.5);

      final planePaint = Paint()..color = Colors.white.withOpacity(1.0 - t * 0.5);
      final path = Path()
        ..moveTo(20, 0)..lineTo(-15, -8)..lineTo(-6, -2)..lineTo(-15, 8)..lineTo(-8, 2)..close();
      canvas.drawPath(path, planePaint);
      canvas.restore();
    } else if (morphProgress < 0.6) {
      // Phase 2: Sparkle / Particle Burst
      final t = (morphProgress - 0.4) / 0.2; // 0.0 to 1.0
      
      // Draw 8 paper scraps radiating outwards
      final burstPaint = Paint()
        ..color = Colors.white.withOpacity(1.0 - t)
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final dist = 45.0 * t;
        final px = netX + math.cos(angle) * dist;
        final py = netY + math.sin(angle) * dist;
        
        final path = Path()
          ..moveTo(px, py)
          ..lineTo(px - 5, py - 7)
          ..lineTo(px + 5, py - 5)
          ..close();
        canvas.drawPath(path, burstPaint);
      }

      final glowPaint = Paint()
        ..color = Colors.white.withOpacity(0.8 * (1.0 - t))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(Offset(netX, netY), 20 * t + 5, glowPaint);
    } else {
      // Phase 3: Chili floats up from net to center
      final t = (morphProgress - 0.6) / 0.4;
      final px = netX + (centerX - netX) * t;
      final py = netY + (centerY - netY) * t;

      final textPainter = TextPainter(
        text: TextSpan(
          text: '🌶️',
          style: TextStyle(fontSize: 32 + 20 * t),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(px - textPainter.width / 2, py - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_GameCanvasPainter old) => true;
}

// ─── Plane Escaped Dialog ──────────────
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
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
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
                  backgroundColor: const Color(0xFF7C98F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
