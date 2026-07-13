import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../providers/paper_plane_provider.dart';

// ─────────────────────────────────────────────────────────────
// Catch Game Screen
// User tilts phone or swipes to move insect net and catch the plane.
// Shows game animations: caught plane converts to a chili which floats up.
// Open chili splits the chili to reveal the note card.
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

class _CatchGameScreenState extends ConsumerState<CatchGameScreen>
    with TickerProviderStateMixin {
  // ── Game tick controller for updating 20 planes ──
  late AnimationController _gameTickController;

  // ── Morph & Open Animations ──
  late AnimationController _morphController;
  late Animation<double> _morphProgress;

  late AnimationController _chiliSplitController;
  late Animation<double> _chiliSplitProgress;

  // ── Net position (moved by tilt or pan gesture) ──
  Offset _netPosition = const Offset(0.5, 0.7); // normalized 0-1
  bool _hasCaught = false;
  bool _chiliOpened = false;
  bool _isConnecting = false;
  bool _isPassing = false;

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

  @override
  void initState() {
    super.initState();

    final gameState = ref.read(catchGameProvider);
    _secondsLeft = gameState.gameConfig?.gameWindowSeconds ?? 120;
    _pathSeed = gameState.gameConfig?.planePathSeed ?? 42;
    _cloudPositions = _generateClouds();

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
                sticker: sp.sticker,
                distanceKm: sp.distanceKm,
                isHighPriority: sp.isHighPriority,
                progress: rng.nextDouble(), // staggered starting position
                speed: 0.0012 + rng.nextDouble() * 0.0018, // independent speed
                pathSeed: rng.nextInt(10000),
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

    _chiliSplitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _chiliSplitProgress = CurvedAnimation(
      parent: _chiliSplitController,
      curve: Curves.easeOutBack,
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

    for (final gp in _gamePlanes) {
      final planeNorm = _planePositionNorm(gp.progress, gp.pathSeed);
      final planePx = Offset(planeNorm.dx * screenSize.width, planeNorm.dy * screenSize.height);
      final netPx = Offset(_netPosition.dx * screenSize.width, _netPosition.dy * screenSize.height);

      final dist = (planePx - netPx).distance;
      if (dist < 55) {
        _hasCaught = true;
        _collisionNorm = planeNorm;
        _gameTickController.stop();
        _countdownTimer.cancel();
        HapticFeedback.heavyImpact();
        _onPlaneCaught(gp);
        break;
      }
    }
  }

  void _onPlaneCaught(GamePlane gp) async {
    final notifier = ref.read(catchGameProvider.notifier);
    await notifier.catchPlane(gp.id);
    await notifier.planeCaught();
    _morphController.forward();
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

  Future<void> _onConnect() async {
    if (_isConnecting) return;
    setState(() => _isConnecting = true);
    HapticFeedback.heavyImpact();

    await ref.read(catchGameProvider.notifier).connect();
    final state = ref.read(catchGameProvider);
    if (state.phase == GamePhase.connected && state.conversationId != null) {
      if (mounted) {
        ref.read(catchGameProvider.notifier).reset();
        context.go('/chat/${state.conversationId}');
      }
    } else {
      if (mounted) {
        setState(() => _isConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect. Try again.')),
        );
      }
    }
  }

  Future<void> _onPass() async {
    if (_isPassing) return;
    setState(() => _isPassing = true);
    HapticFeedback.mediumImpact();

    await ref.read(catchGameProvider.notifier).pass();
    if (mounted) {
      ref.read(catchGameProvider.notifier).reset();
      context.go('/');
    }
  }

  @override
  void dispose() {
    _gameTickController.dispose();
    _morphController.dispose();
    _chiliSplitController.dispose();
    _countdownTimer.cancel();
    _sensorSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final gameState = ref.watch(catchGameProvider);
    final catchResult = gameState.catchResult;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
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
          animation: Listenable.merge([_gameTickController, _morphProgress, _chiliSplitProgress]),
          builder: (context, _) {
            if (!_hasCaught) {
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _checkCollision(size));
            }

            return Stack(
              children: [
                // ── Game Canvas ──
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GameCanvasPainter(
                      gamePlanes: _gamePlanes,
                      getPlanePos: _planePositionNorm,
                      netNorm: _netPosition,
                      cloudPositions: _cloudPositions,
                      secondsLeft: _secondsLeft,
                      totalSeconds: gameState.gameConfig?.gameWindowSeconds ?? 120,
                      hasCaught: _hasCaught,
                      morphProgress: _morphProgress.value,
                      collisionNorm: _collisionNorm,
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
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_secondsLeft}s',
                              style: TextStyle(
                                color: _secondsLeft <= 10 ? Colors.red : Colors.white,
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
                                  backgroundColor: Colors.white24,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _secondsLeft <= 10 ? Colors.red : const Color(0xFFFF2E74),
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

                // ── Bottom Hint HUD ──
                if (!_hasCaught)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Swipe/Tilt to move Net • Catch the plane!',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ),
                  ),

                // ── Chili Reveal Mode Overlay ──
                if (_hasCaught && _morphProgress.isCompleted)
                  Positioned.fill(
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.65),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Chili graphics (Split / Pulse)
                              if (!_chiliOpened)
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Transform.scale(
                                      scale: 1.0 + 0.08 * math.sin(DateTime.now().millisecondsSinceEpoch / 150),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withValues(alpha: 0.35),
                                              blurRadius: 30,
                                              spreadRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child: const Text('🌶️', style: TextStyle(fontSize: 84)),
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                    ElevatedButton(
                                      onPressed: () {
                                        HapticFeedback.heavyImpact();
                                        _chiliSplitController.forward().then((_) {
                                          setState(() => _chiliOpened = true);
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFFF2E74),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('🔥 Open Chili',
                                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                              // Left / Right split chili animation on opening
                              if (_chiliSplitController.value > 0.0 && !_chiliOpened)
                                Positioned(
                                  left: size.width * 0.5 - 60 - 80 * _chiliSplitProgress.value,
                                  child: Transform.rotate(
                                    angle: -0.2 * _chiliSplitProgress.value,
                                    child: const Text('🌶️', style: TextStyle(fontSize: 84)),
                                  ),
                                ),

                              // Note card fade/slide in (Centered postcard style)
                              if (_chiliOpened && catchResult != null)
                                Center(
                                  child: Container(
                                    width: math.min(size.width * 0.88, 380),
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E1E1E),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: const Color(0xFFFF2E74).withValues(alpha: 0.4),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF2E74).withValues(alpha: 0.12),
                                          blurRadius: 40,
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text('🌶️', style: TextStyle(fontSize: 28)),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Note from ${catchResult.senderFirstName}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  Text(
                                                    '📍 ${catchResult.senderCity.isNotEmpty ? catchResult.senderCity : "Unknown Location"}',
                                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (catchResult.sticker.isNotEmpty)
                                              Text(catchResult.sticker, style: const TextStyle(fontSize: 28)),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        const Divider(color: Colors.white24, height: 1),
                                        const SizedBox(height: 16),
                                        Text(
                                          '“',
                                          style: TextStyle(
                                            color: const Color(0xFFFF2E74).withValues(alpha: 0.6),
                                            fontSize: 36,
                                            fontWeight: FontWeight.bold,
                                            height: 0.8,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Text(
                                            catchResult.message,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              height: 1.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                height: 50,
                                                child: OutlinedButton(
                                                  onPressed: _isPassing || _isConnecting ? null : _onPass,
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(color: Colors.white24, width: 1.5),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(14),
                                                    ),
                                                  ),
                                                  child: _isPassing
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2),
                                                        )
                                                      : const Text(
                                                          'Pass',
                                                          style: TextStyle(color: Colors.white70, fontSize: 15),
                                                        ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              flex: 2,
                                              child: SizedBox(
                                                height: 50,
                                                child: ElevatedButton(
                                                  onPressed: _isPassing || _isConnecting ? null : _onConnect,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFFFF2E74),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(14),
                                                    ),
                                                  ),
                                                  child: _isConnecting
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                        )
                                                  : const Text(
                                                      'Accept & Chat',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
  final Offset Function(double t, int seed) getPlanePos;
  final Offset netNorm;
  final List<Offset> cloudPositions;
  final int secondsLeft;
  final int totalSeconds;
  final bool hasCaught;
  final double morphProgress;
  final Offset collisionNorm;

  _GameCanvasPainter({
    required this.gamePlanes,
    required this.getPlanePos,
    required this.netNorm,
    required this.cloudPositions,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.hasCaught,
    required this.morphProgress,
    required this.collisionNorm,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Sky gradient background
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final skyGrad = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF0A0A1A),
        Color(0xFF1A1040),
        Color(0xFF2D1B6E),
      ],
    );
    canvas.drawRect(skyRect, Paint()..shader = skyGrad.createShader(skyRect));

    // Stars
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    final rng = math.Random(42);
    for (int i = 0; i < 60; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height * 0.7),
        rng.nextDouble() * 1.5,
        starPaint,
      );
    }

    // Clouds
    for (final cloud in cloudPositions) {
      _drawCloud(canvas, size, Offset(cloud.dx * size.width, cloud.dy * size.height));
    }

    // Net
    if (!hasCaught || morphProgress < 1.0) {
      _drawNet(canvas, size, netNorm);
    }

    // Draw all flying planes or the caught morph target
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
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawOval(Rect.fromCenter(center: center, width: 80, height: 30), paint);
    canvas.drawOval(Rect.fromCenter(center: center.translate(-20, -12), width: 50, height: 30), paint);
    canvas.drawOval(Rect.fromCenter(center: center.translate(20, -8), width: 60, height: 28), paint);
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
      ..color = const Color(0xFFFF2E74).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    canvas.drawCircle(Offset.zero, 18, shadowPaint);

    final path = Path()
      ..moveTo(28, 0)
      ..lineTo(-20, -12)
      ..lineTo(-8, -3)
      ..lineTo(-20, 12)
      ..lineTo(-10, 3)
      ..close();

    canvas.drawPath(path, planePaint);
    canvas.restore();
  }

  void _drawNet(Canvas canvas, Size size, Offset norm) {
    final px = norm.dx * size.width;
    final py = norm.dy * size.height;

    canvas.save();
    canvas.translate(px, py);

    // Woven Net Bag/Pocket (Hanging down)
    final netBagPath = Path()
      ..moveTo(-28, 5)
      ..quadraticBezierTo(-20, 70, 0, 85)
      ..quadraticBezierTo(20, 70, 28, 5)
      ..quadraticBezierTo(0, 15, -28, 5)
      ..close();
    
    final netBagPaint = Paint()
      ..color = const Color(0xFFFF2E74).withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawPath(netBagPath, netBagPaint);

    final netBagOutline = Paint()
      ..color = const Color(0xFFFF2E74).withValues(alpha: 0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(netBagPath, netBagOutline);

    // Cross lines for the net pocket bag mesh
    final meshPaint = Paint()
      ..color = const Color(0xFFFF2E74).withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (double i = -20; i <= 20; i += 10) {
      canvas.drawLine(Offset(i, 8), Offset(i / 2, 80), meshPaint);
    }
    for (double y = 15; y <= 75; y += 15) {
      final widthAtY = 28 * (1.0 - (y - 15) / 120);
      canvas.drawLine(Offset(-widthAtY, y), Offset(widthAtY, y), meshPaint);
    }

    // Long Stick/Handle (Insect collection style)
    final handlePaint = Paint()
      ..color = const Color(0xFF8B5A2B) // wood brown
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 26), const Offset(0, 110), handlePaint);

    // Net circle rim
    final rimPaint = Paint()
      ..color = const Color(0xFFFF2E74)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset.zero, 28, rimPaint);

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

      final planePaint = Paint()..color = Colors.white.withValues(alpha: 1.0 - t * 0.5);
      final path = Path()
        ..moveTo(28, 0)..lineTo(-20, -12)..lineTo(-8, -3)..lineTo(-20, 12)..lineTo(-10, 3)..close();
      canvas.drawPath(path, planePaint);
      canvas.restore();
    } else if (morphProgress < 0.6) {
      // Phase 2: Sparkle / Morph Burst at net center
      final t = (morphProgress - 0.4) / 0.2;
      final sparklePaint = Paint()
        ..color = Colors.amber.withValues(alpha: 1.0 - t)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(netX, netY), 15 * t + 5, sparklePaint);
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
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2E74),
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
