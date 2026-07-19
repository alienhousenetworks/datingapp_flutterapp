import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

enum ControlMode { touch, tilt }

class _CatchGameScreenState extends ConsumerState<CatchGameScreen>
    with TickerProviderStateMixin {
  // ── Game tick controller for updating 20 planes ──
  late AnimationController _gameTickController;

  // ── Morph Animations ──
  late AnimationController _morphController;
  late Animation<double> _morphProgress;

  // ── Control Mode ──
  ControlMode _controlMode = ControlMode.touch;

  // ── Net position (moved by tilt or pan gesture) ──
  Offset _netPosition = const Offset(0.5, 0.5); // normalized 0-1
  Offset _targetNetPosition = const Offset(0.5, 0.5);
  Offset _shakeOffset = Offset.zero;

  // Low-pass filter values for accelerometer
  double _filteredAccX = 0.0;
  double _filteredAccY = 0.0;

  bool _hasCaught = false;
  bool _isHoveringClose = false;

  // ── Accelerometer stream subscription ──
  StreamSubscription<AccelerometerEvent>? _sensorSubscription;

  // ── Countdown ──
  late Timer _countdownTimer;
  int _secondsLeft = 60;
  int _pathSeed = 42;

  // Parallax clouds
  late List<Offset> _cloudsLayer1; // Fast
  late List<Offset> _cloudsLayer2; // Medium
  late List<Offset> _cloudsLayer3; // Slow

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
    _decoPlanes = _generateDecoPlanes();

    // Setup parallax clouds layers
    final rng = math.Random(_pathSeed);
    _cloudsLayer1 = List.generate(3, (_) => Offset(rng.nextDouble(), rng.nextDouble() * 0.3));
    _cloudsLayer2 = List.generate(4, (_) => Offset(rng.nextDouble(), 0.1 + rng.nextDouble() * 0.35));
    _cloudsLayer3 = List.generate(3, (_) => Offset(rng.nextDouble(), 0.2 + rng.nextDouble() * 0.45));

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

          // Smooth finger touch net lag tracking
          if (_controlMode == ControlMode.touch) {
            _netPosition = Offset(
              _netPosition.dx + (_targetNetPosition.dx - _netPosition.dx) * 0.15,
              _netPosition.dy + (_targetNetPosition.dy - _netPosition.dy) * 0.15,
            );
          }

          // Drift clouds for parallax layers
          for (int i = 0; i < _cloudsLayer1.length; i++) {
            double newX = _cloudsLayer1[i].dx + 0.0008;
            if (newX > 1.15) newX = -0.15;
            _cloudsLayer1[i] = Offset(newX, _cloudsLayer1[i].dy);
          }
          for (int i = 0; i < _cloudsLayer2.length; i++) {
            double newX = _cloudsLayer2[i].dx + 0.0004;
            if (newX > 1.15) newX = -0.15;
            _cloudsLayer2[i] = Offset(newX, _cloudsLayer2[i].dy);
          }
          for (int i = 0; i < _cloudsLayer3.length; i++) {
            double newX = _cloudsLayer3[i].dx + 0.00015;
            if (newX > 1.15) newX = -0.15;
            _cloudsLayer3[i] = Offset(newX, _cloudsLayer3[i].dy);
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
    _updateSensorSubscription();
  }

  void _updateSensorSubscription() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    if (_controlMode == ControlMode.tilt && !_hasCaught) {
      _sensorSubscription = accelerometerEventStream().listen((event) {
        if (!mounted || _hasCaught) return;
        setState(() {
          // Low-pass filter (alpha = 0.15) to eliminate hand tremors
          _filteredAccX = _filteredAccX + (event.x - _filteredAccX) * 0.15;
          _filteredAccY = _filteredAccY + (event.y - _filteredAccY) * 0.15;

          double dx = (_netPosition.dx - _filteredAccX * 0.0065).clamp(0.05, 0.95);
          double dy = (_netPosition.dy + _filteredAccY * 0.0065).clamp(0.05, 0.95);
          _netPosition = Offset(dx, dy);
        });
      }, onError: (_) {});
    }
  }

  Widget _buildModeButton(ControlMode mode, String label) {
    final isSelected = _controlMode == mode;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _controlMode = mode;
          _updateSensorSubscription();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF8BA5F8) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
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
    double minDistance = 70.0; // Net radius threshold
    Offset closestPlaneNorm = Offset.zero;
    bool isAnyPlaneNear = false;

    for (final gp in _gamePlanes) {
      final planeNorm = _planePositionNorm(gp.progress, gp.pathSeed);
      final planePx = Offset(planeNorm.dx * screenSize.width, planeNorm.dy * screenSize.height);
      final netPx = Offset(_netPosition.dx * screenSize.width, _netPosition.dy * screenSize.height);

      final dist = (planePx - netPx).distance;
      if (dist < 110.0) {
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
    try {
      // Trigger satisfying impact screen shake
      int shakeTicks = 0;
      Timer.periodic(const Duration(milliseconds: 16), (t) {
        if (shakeTicks > 12 || !mounted) {
          t.cancel();
          setState(() => _shakeOffset = Offset.zero);
        } else {
          shakeTicks++;
          final rng = math.Random();
          setState(() {
            _shakeOffset = Offset(
              (rng.nextDouble() - 0.5) * 12,
              (rng.nextDouble() - 0.5) * 12,
            );
          });
        }
      });

      await notifier.catchPlane(gp.id);
      var phase = ref.read(catchGameProvider).phase;
      if (phase == GamePhase.error) {
        _showCatchError(ref.read(catchGameProvider).error);
        return;
      }
      await notifier.planeCaught();
      phase = ref.read(catchGameProvider).phase;
      if (phase == GamePhase.error ||
          ref.read(catchGameProvider).catchResult == null) {
        _showCatchError(ref.read(catchGameProvider).error);
        return;
      }
      await _morphController.forward();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MessageRevealScreen()),
        );
      }
    } catch (e) {
      _showCatchError(e.toString());
    }
  }

  void _showCatchError(String? message) {
    if (!mounted) return;
    setState(() {
      _hasCaught = false;
    });
    _gameTickController.repeat();
    _startCountdown();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          (message != null && message.isNotEmpty)
              ? message
              : 'Could not catch that plane. Try another.',
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  void _updateTouchPosition(Offset localPosition, Size size) {
    if (_controlMode != ControlMode.touch) return;
    // Offset the net slightly above the finger (e.g. 60 pixels) so the finger doesn't block the view of the net.
    final targetY = localPosition.dy - 60.0;
    setState(() {
      _targetNetPosition = Offset(
        (localPosition.dx / size.width).clamp(0.05, 0.95),
        (targetY / size.height).clamp(0.05, 0.95),
      );
    });
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
        onPanStart: (details) {
          if (_hasCaught) return;
          _updateTouchPosition(details.localPosition, size);
        },
        onPanUpdate: (details) {
          if (_hasCaught) return;
          if (_controlMode == ControlMode.touch) {
            _updateTouchPosition(details.localPosition, size);
          } else {
            setState(() {
              _netPosition = Offset(
                (_netPosition.dx + details.delta.dx / size.width).clamp(0.05, 0.95),
                (_netPosition.dy + details.delta.dy / size.height).clamp(0.05, 0.95),
              );
            });
          }
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
                        cloudsLayer1: _cloudsLayer1,
                        cloudsLayer2: _cloudsLayer2,
                        cloudsLayer3: _cloudsLayer3,
                        secondsLeft: _secondsLeft,
                        totalSeconds: gameState.gameConfig?.gameWindowSeconds ?? 120,
                        hasCaught: _hasCaught,
                        morphProgress: _morphProgress.value,
                        collisionNorm: _collisionNorm,
                        isHoveringClose: _isHoveringClose,
                        shakeOffset: _shakeOffset,
                      ),
                    ),
                  ),

                  // ── Top Bar HUD ──
                  if (!_hasCaught)
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
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
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildModeButton(ControlMode.touch, 'Finger Touch'),
                                  _buildModeButton(ControlMode.tilt, 'Hand Gesture (Tilt)'),
                                ],
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
  final List<Offset> cloudsLayer1;
  final List<Offset> cloudsLayer2;
  final List<Offset> cloudsLayer3;
  final int secondsLeft;
  final int totalSeconds;
  final bool hasCaught;
  final double morphProgress;
  final Offset collisionNorm;
  final bool isHoveringClose;
  final Offset shakeOffset;

  _GameCanvasPainter({
    required this.gamePlanes,
    required this.decoPlanes,
    required this.getPlanePos,
    required this.netNorm,
    required this.cloudsLayer1,
    required this.cloudsLayer2,
    required this.cloudsLayer3,
    required this.secondsLeft,
    required this.totalSeconds,
    required this.hasCaught,
    required this.morphProgress,
    required this.collisionNorm,
    required this.isHoveringClose,
    required this.shakeOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Apply visual screen shake translation offset
    canvas.translate(shakeOffset.dx, shakeOffset.dy);

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

    // Parallax Clouds (Slowest/Lowest layer first)
    for (final cloud in cloudsLayer3) {
      _drawCloud(canvas, size, Offset(cloud.dx * size.width, cloud.dy * size.height), opacity: 0.08);
    }
    for (final cloud in cloudsLayer2) {
      _drawCloud(canvas, size, Offset(cloud.dx * size.width, cloud.dy * size.height), opacity: 0.14);
    }
    for (final cloud in cloudsLayer1) {
      _drawCloud(canvas, size, Offset(cloud.dx * size.width, cloud.dy * size.height), opacity: 0.22);
    }

    // Draw decorative background planes to populate the sky
    for (final dp in decoPlanes) {
      _drawDecoPlane(canvas, size, dp);
    }

    // Draw all active catching planes
    if (!hasCaught) {
      for (final gp in gamePlanes) {
        final pos = getPlanePos(gp.progress, gp.pathSeed);
        _drawPlane(canvas, size, pos, gp);
      }
    } else if (morphProgress < 1.0) {
      _drawMorphTarget(canvas, size);
    }

    // Net (drawn on top of background planes)
    if (!hasCaught || morphProgress < 1.0) {
      _drawNet(canvas, size, netNorm);
    }

    canvas.restore();
  }

  void _drawCloud(Canvas canvas, Size size, Offset center, {double opacity = 0.12}) {
    final paint = Paint()..color = Colors.white.withValues(alpha: opacity);
    canvas.drawOval(Rect.fromCenter(center: center, width: 110, height: 36), paint);
    canvas.drawOval(Rect.fromCenter(center: center.translate(-30, -12), width: 75, height: 34), paint);
    canvas.drawOval(Rect.fromCenter(center: center.translate(30, -8), width: 85, height: 32), paint);
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

  void _drawPlane(Canvas canvas, Size size, Offset norm, GamePlane gp) {
    final px = norm.dx * size.width;
    final py = norm.dy * size.height;

    // Draw shooting star wind trail behind the plane
    final trailPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 1; i <= 6; i++) {
      final prevT = gp.progress - (i * 0.012);
      if (prevT > 0) {
        final prevPos = getPlanePos(prevT, gp.pathSeed);
        final ppx = prevPos.dx * size.width;
        final ppy = prevPos.dy * size.height;
        trailPaint.color = Colors.white.withValues(alpha: (0.35 / i));
        canvas.drawCircle(Offset(ppx, ppy), (3.0 - i * 0.4).clamp(0.5, 3.0), trailPaint);
      }
    }

    canvas.save();
    canvas.translate(px, py);

    final planePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
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
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 22);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 105, height: 85), glowPaint);
    }

    // Woven Net Bag/Pocket (Hanging down, clean white)
    final netBagPath = Path()
      ..moveTo(-45, 5)
      ..quadraticBezierTo(-32, 95, 0, 120)
      ..quadraticBezierTo(32, 95, 45, 5)
      ..quadraticBezierTo(0, 20, -45, 5)
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
      ..strokeWidth = 1.2;
    for (double i = -32; i <= 32; i += 10) {
      canvas.drawLine(Offset(i, 8), Offset(i / 1.8, 110), meshPaint);
    }
    for (double y = 15; y <= 110; y += 15) {
      final widthAtY = 45 * (1.0 - (y - 15) / 160);
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
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke;
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 90, height: 70), rimPaint);

    final rimInnerPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 85, height: 65), rimInnerPaint);

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
        ..moveTo(20, 0)..lineTo(-15, -8)..lineTo(-6, -2)..lineTo(-15, 8)..lineTo(-8, 2)..close();
      canvas.drawPath(path, planePaint);
      canvas.restore();
    } else if (morphProgress < 0.7) {
      // Phase 2: Spectacular Shockwave + Multi-Colored Particle Burst
      final t = (morphProgress - 0.4) / 0.3; // 0.0 to 1.0
      
      // 1. Expanding shockwave ring
      final shockwavePaint = Paint()
        ..color = const Color(0xFFFF2E74).withValues(alpha: 1.0 - t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(Offset(netX, netY), 110.0 * t, shockwavePaint);

      // 2. High-fidelity multi-colored radial explosion
      final colors = [
        const Color(0xFFFF2E74),
        const Color(0xFFFFD700),
        const Color(0xFF00E676),
        const Color(0xFF29B6F6),
        Colors.white,
      ];
      
      for (int i = 0; i < 18; i++) {
        final angle = i * (2 * math.pi) / 18.0 + (i * 0.08);
        final dist = 85.0 * t;
        final px = netX + math.cos(angle) * dist;
        final py = netY + math.sin(angle) * dist;
        final size = (7.0 * (1.0 - t * 0.5)).clamp(1.5, 7.0);
        
        final scrapPaint = Paint()
          ..color = colors[i % colors.length].withValues(alpha: 1.0 - t)
          ..style = PaintingStyle.fill;
          
        canvas.drawCircle(Offset(px, py), size / 2, scrapPaint);
      }

      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8 * (1.0 - t))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      canvas.drawCircle(Offset(netX, netY), 20 * t + 5, glowPaint);
    } else {
      // Phase 3: Chili floats up from net to center
      final t = (morphProgress - 0.7) / 0.3;
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
