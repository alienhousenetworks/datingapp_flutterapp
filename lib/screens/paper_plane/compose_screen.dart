import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import '../../providers/paper_plane_provider.dart';

// ─────────────────────────────────────────────────────────────
// Paper Plane Compose Screen
// Write your message → watch fold animation → launch
// ─────────────────────────────────────────────────────────────

class PaperPlaneComposeScreen extends ConsumerStatefulWidget {
  const PaperPlaneComposeScreen({super.key});

  @override
  ConsumerState<PaperPlaneComposeScreen> createState() =>
      _PaperPlaneComposeScreenState();
}

class _PaperPlaneComposeScreenState
    extends ConsumerState<PaperPlaneComposeScreen>
    with TickerProviderStateMixin {
  final _messageController = TextEditingController();
  final _focusNode = FocusNode();
  String _selectedSticker = '';
  bool _isAnimatingLaunch = false;

  // Interactive folding state variables
  bool _isFoldingInteractive = false;

  // Fold + fly animation controllers
  late AnimationController _foldController;
  late AnimationController _flyController;
  late Animation<double> _foldAnim;
  late Animation<Offset> _flyAnim;
  late Animation<double> _fadeAnim;

  static const _stickers = ['✈️', '💌', '🌙', '⭐', '🌸', '🔥', '💫', '🌊'];
  static const _maxChars = 200;

  @override
  void initState() {
    super.initState();

    _foldController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _foldAnim = CurvedAnimation(parent: _foldController, curve: Curves.easeInOut);
    _flyAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(3.0, -2.0),
    ).animate(CurvedAnimation(parent: _flyController, curve: Curves.easeIn));
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _flyController, curve: const Interval(0.6, 1.0)),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _foldController.dispose();
    _flyController.dispose();
    super.dispose();
  }

  void _onLaunch() {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) {
      _showError('Write a message for your plane!');
      return;
    }
    _focusNode.unfocus();
    setState(() {
      _isFoldingInteractive = true;
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _executeBackendLaunch() async {
    final msg = _messageController.text.trim();
    setState(() => _isAnimatingLaunch = true);

    // Phase 2: plane launches out of screen
    _flyController.forward();

    // Simultaneously call the API
    final success = await ref
        .read(paperPlaneSenderProvider.notifier)
        .launch(msg, sticker: _selectedSticker);

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;

    if (success) {
      HapticFeedback.heavyImpact();
      _showLaunchSuccess();
    } else {
      // Reset animation on failure
      _flyController.reset();
      setState(() {
        _isAnimatingLaunch = false;
        _isFoldingInteractive = false;
      });
      final error = ref.read(paperPlaneSenderProvider).error;
      _showError(error ?? 'Could not launch plane. Try again.');
    }
  }

  void _showLaunchSuccess() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => _LaunchSuccessOverlay(
        onDone: () {
          Navigator.of(context).pop();
          context.pop();
        },
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFoldingInteractive) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F11),
        body: SafeArea(
          child: _InteractiveFolder(
            message: _messageController.text,
            onCancel: () {
              setState(() {
                _isFoldingInteractive = false;
              });
            },
            onFoldComplete: () {
              _executeBackendLaunch();
            },
          ),
        ),
      );
    }

    final senderState = ref.watch(paperPlaneSenderProvider);
    final remaining = _maxChars - _messageController.text.length;
    final canLaunch = _messageController.text.trim().isNotEmpty &&
        !_isAnimatingLaunch &&
        !senderState.isLaunching;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Launch a Paper Plane',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Plane animation area ──
            Expanded(
              flex: 2,
              child: Center(
                child: SlideTransition(
                  position: _flyAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_foldAnim, _messageController]),
                      builder: (_, __) {
                        return _PlaneWidget(
                          foldProgress: _foldAnim.value,
                          message: _messageController.text,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // ── Message input ──
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your message',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2A2A2E),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        maxLength: _maxChars,
                        maxLines: 4,
                        minLines: 3,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.5,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Write something for the person who catches your plane...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            value: _messageController.text.length / _maxChars,
                            strokeWidth: 2,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              remaining < 20
                                  ? Colors.redAccent
                                  : remaining < 60
                                      ? Colors.orangeAccent
                                      : const Color(0xFFFF2E74),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$remaining left',
                          style: TextStyle(
                            color: remaining < 20
                                ? Colors.redAccent
                                : remaining < 60
                                    ? Colors.orangeAccent
                                    : Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // ── Sticker picker ──
                    const SizedBox(height: 24),
                    const Text(
                      'Add a sticker (optional)',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _stickers.length + 1, // +1 for "none"
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            final selected = _selectedSticker.isEmpty;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedSticker = ''),
                              child: AnimatedScale(
                                scale: selected ? 1.12 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOutBack,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 44,
                                  height: 44,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.white12
                                        : Colors.white.withValues(alpha: 0.04),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? Colors.white54
                                          : Colors.white.withValues(alpha: 0.1),
                                      width: 2.0,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Text('✕',
                                        style:
                                            TextStyle(color: Colors.white54, fontSize: 16)),
                                  ),
                                ),
                              ),
                            );
                          }
                          final sticker = _stickers[i - 1];
                          final selected = _selectedSticker == sticker;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedSticker = sticker);
                            },
                            child: AnimatedScale(
                              scale: selected ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutBack,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                height: 44,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFFF2E74).withValues(alpha: 0.25)
                                      : Colors.white.withValues(alpha: 0.04),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFFFF2E74)
                                        : Colors.white.withValues(alpha: 0.1),
                                    width: 2.0,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFFF2E74).withValues(alpha: 0.4),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : [],
                                ),
                                child: Center(
                                  child: Text(
                                    sticker,
                                    style: const TextStyle(fontSize: 22),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const Spacer(),

                    // ── Launch button ──
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: AnimatedOpacity(
                        opacity: canLaunch ? 1.0 : 0.4,
                        duration: const Duration(milliseconds: 200),
                        child: ElevatedButton(
                          onPressed: canLaunch ? _onLaunch : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF2E74),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: senderState.isLaunching
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('✈️  Fold & Launch',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        )),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Plane Widget (paper → chili → plane fold animation) ──────────────
class _PlaneWidget extends StatelessWidget {
  final double foldProgress; // 0 = paper, 1 = plane
  final String message;

  const _PlaneWidget({required this.foldProgress, required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: CustomPaint(
        painter: _PlanePainter(progress: foldProgress, message: message),
      ),
    );
  }
}

class _PlanePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0
  final String message;

  _PlanePainter({required this.progress, required this.message});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    if (progress < 0.35) {
      // Phase 1: Note converts to chili
      final t = progress / 0.35; // 0.0 -> 1.0
      // Draw shrinking white note paper sheet
      final paperPaint = Paint()
        ..color = Colors.white.withOpacity(1.0 - t)
        ..style = PaintingStyle.fill;
      final path = Path()
        ..moveTo(cx - 50 * (1.0 - t * 0.5), cy - 60 * (1.0 - t * 0.5))
        ..lineTo(cx + 50 * (1.0 - t * 0.5), cy - 60 * (1.0 - t * 0.5))
        ..lineTo(cx + 50 * (1.0 - t * 0.5), cy + 60 * (1.0 - t * 0.5))
        ..lineTo(cx - 50 * (1.0 - t * 0.5), cy + 60 * (1.0 - t * 0.5))
        ..close();
      canvas.drawPath(path, paperPaint);

      // Draw the text inside the paper sheet
      if (t < 0.8) {
        final textToShow = message.trim().isEmpty ? 'Add your note' : message;
        final truncatedText = textToShow.length > 25 ? '${textToShow.substring(0, 22)}...' : textToShow;
        
        final textPainter = TextPainter(
          text: TextSpan(
            text: truncatedText,
            style: TextStyle(
              color: Colors.black.withOpacity(1.0 - t / 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        );
        textPainter.layout(maxWidth: 80 * (1.0 - t * 0.5));
        textPainter.paint(
          canvas,
          Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
        );
      }

      // Draw growing chili emoji 🌶️
      final textPainter = TextPainter(
        text: TextSpan(
          text: '🌶️',
          style: TextStyle(
            fontSize: 24 * t + 8,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
      );
    } else if (progress < 0.8) {
      // Phase 2: Chili passes through paper plane
      final t = (progress - 0.35) / 0.45; // 0.0 -> 1.0
      
      // Draw stationary paper plane at center
      _drawPaperPlane(canvas, cx, cy, 1.2);

      // Draw chili traveling from bottom-left to top-right through center
      final startX = cx - 80;
      final startY = cy + 60;
      final endX = cx + 80;
      final endY = cy - 60;
      final chiliX = startX + (endX - startX) * t;
      final chiliY = startY + (endY - startY) * t;

      // Draw fire trail dots
      final trailPaint = Paint()..style = PaintingStyle.fill;
      for (double i = 0; i < t; i += 0.1) {
        final tx = startX + (endX - startX) * i;
        final ty = startY + (endY - startY) * i;
        trailPaint.color = Color.lerp(Colors.redAccent, Colors.orangeAccent, i)!
            .withOpacity(t - i + 0.1);
        canvas.drawCircle(Offset(tx, ty), 4 + i * 4, trailPaint);
      }

      final textPainter = TextPainter(
        text: const TextSpan(
          text: '🌶️',
          style: TextStyle(fontSize: 32),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(chiliX - textPainter.width / 2, chiliY - textPainter.height / 2),
      );
    } else {
      // Phase 3: Paper plane ignites with glow
      final t = (progress - 0.8) / 0.2; // 0.0 -> 1.0
      // Draw glowing paper plane
      final glowPaint = Paint()
        ..color = const Color(0xFFFF2E74).withOpacity(0.3 * t)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset(cx, cy), 30, glowPaint);

      _drawPaperPlane(canvas, cx, cy, 1.2);

      // Show some flame sparks
      final sparkPaint = Paint()
        ..color = Colors.orangeAccent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx - 30, cy + 10), 3 * t, sparkPaint);
      canvas.drawCircle(Offset(cx - 20, cy + 20), 4 * t, sparkPaint);
    }
  }

  void _drawPaperPlane(Canvas canvas, double cx, double cy, double scale) {
    final planePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = Colors.white70
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(cx + 25 * scale, cy)
      ..lineTo(cx - 25 * scale, cy - 15 * scale)
      ..lineTo(cx - 10 * scale, cy - 3 * scale)
      ..lineTo(cx - 25 * scale, cy + 15 * scale)
      ..lineTo(cx - 12 * scale, cy + 4 * scale)
      ..close();
    canvas.drawPath(path, planePaint);
    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(_PlanePainter old) => old.progress != progress;
}

// ─── Interactive Folding Overlay Widget ──────────────────────────────────
class _InteractiveFolder extends StatefulWidget {
  final String message;
  final VoidCallback onCancel;
  final VoidCallback onFoldComplete;

  const _InteractiveFolder({
    required this.message,
    required this.onCancel,
    required this.onFoldComplete,
  });

  @override
  State<_InteractiveFolder> createState() => _InteractiveFolderState();
}

class _InteractiveFolderState extends State<_InteractiveFolder>
    with TickerProviderStateMixin {
  static const _totalStages = 6;

  int _stage = 1;
  double _dragProgress = 0.0;
  bool _isAnimating = false;
  bool _isLaunching = false;
  int _lastHapticTick = 0;

  late AnimationController _foldCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _launchCtrl;
  late Animation<double> _foldCurve;

  @override
  void initState() {
    super.initState();
    _foldCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _foldCurve = CurvedAnimation(
      parent: _foldCtrl,
      curve: Curves.easeOutCubic,
    );
    _foldCtrl.addListener(() {
      setState(() => _dragProgress = _foldCurve.value);
    });

    // Gentle idle float so paper feels alive in space
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _launchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _foldCtrl.dispose();
    _floatCtrl.dispose();
    _launchCtrl.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    if (_isAnimating || _isLaunching) return;
    _foldCtrl.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating || _isLaunching) return;
    double delta = 0.0;
    switch (_stage) {
      case 1:
        delta = details.delta.dx + details.delta.dy;
        break;
      case 2:
        delta = -details.delta.dx + details.delta.dy;
        break;
      case 3:
        delta = details.delta.dx + details.delta.dy * 0.5;
        break;
      case 4:
        delta = -details.delta.dx + details.delta.dy * 0.5;
        break;
      case 5:
        delta = -details.delta.dx;
        break;
      case 6:
        delta = details.delta.dy;
        break;
    }

    setState(() {
      // Scale swipe delta for a physical and precise control feel
      _dragProgress = (_dragProgress + delta / 220).clamp(0.0, 1.0);
      
      // Emit micro-haptic clicks to feel paper fibers bending/resisting
      final currentTick = (_dragProgress * 6).floor();
      if (currentTick != _lastHapticTick) {
        _lastHapticTick = currentTick;
        HapticFeedback.lightImpact();
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_isAnimating || _isLaunching) return;
    // Dynamic snap check: if folded past 55%, snap to completion. Otherwise, spring back.
    if (_dragProgress >= 0.55) {
      _completeFold();
    } else {
      _snapBack();
    }
  }

  Future<void> _completeFold() async {
    setState(() => _isAnimating = true);
    _foldCtrl.value = _dragProgress;
    HapticFeedback.lightImpact();

    // Smoothly animate the rest of the fold to completion using a nice spring curve
    await _foldCtrl.animateTo(1.0, duration: const Duration(milliseconds: 320), curve: Curves.easeOutBack);
    if (!mounted) return;

    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;

    if (_stage < _totalStages) {
      setState(() {
        _stage++;
        _dragProgress = 0.0;
        _isAnimating = false;
        _lastHapticTick = 0;
      });
      _foldCtrl.reset();
      HapticFeedback.lightImpact();
    } else {
      setState(() => _isLaunching = true);
      HapticFeedback.heavyImpact();
      await _launchCtrl.forward();
      if (!mounted) return;
      widget.onFoldComplete();
    }
  }

  Future<void> _snapBack() async {
    setState(() => _isAnimating = true);
    _foldCtrl.value = _dragProgress;

    // Bounce back to flat open state
    await _foldCtrl.animateTo(0.0, duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
    if (!mounted) return;

    setState(() {
      _dragProgress = 0.0;
      _isAnimating = false;
      _lastHapticTick = 0;
    });
    _foldCtrl.reset();
    HapticFeedback.selectionClick();
  }

  Future<void> _runAutoFoldSequence() async {
    if (_isAnimating || _isLaunching) return;
    setState(() => _isLaunching = true);

    while (_stage <= _totalStages) {
      HapticFeedback.mediumImpact();
      _foldCtrl.value = 0.0;
      await _foldCtrl.animateTo(1.0, duration: const Duration(milliseconds: 180), curve: Curves.fastOutSlowIn);
      if (!mounted) return;

      HapticFeedback.selectionClick();
      if (_stage < _totalStages) {
        setState(() {
          _stage++;
          _dragProgress = 0.0;
        });
      } else {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 60));
    }

    HapticFeedback.heavyImpact();
    await _launchCtrl.forward();
    if (!mounted) return;
    widget.onFoldComplete();
  }

  ({String title, String helper, Alignment guide}) get _copy {
    switch (_stage) {
      case 1:
        return (
          title: 'Fold top-left corner',
          helper: 'Drag the corner to the center line',
          guide: const Alignment(-0.65, -0.65),
        );
      case 2:
        return (
          title: 'Fold top-right corner',
          helper: 'Match the right corner to the center line',
          guide: const Alignment(0.65, -0.65),
        );
      case 3:
        return (
          title: 'Fold left edge diagonal',
          helper: 'Fold the new diagonal edge to the center',
          guide: const Alignment(-0.55, -0.1),
        );
      case 4:
        return (
          title: 'Fold right edge diagonal',
          helper: 'Fold the right diagonal edge to the center',
          guide: const Alignment(0.55, -0.1),
        );
      case 5:
        return (
          title: 'Fold in half',
          helper: 'Close the plane along the center spine',
          guide: const Alignment(0.65, 0.15),
        );
      default:
        return (
          title: 'Fold the wings down',
          helper: 'Pull the wings down to lock the fold',
          guide: const Alignment(0.0, -0.2),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    final stageFraction = ((_stage - 1) + _dragProgress) / _totalStages;
    final screenSize = MediaQuery.of(context).size;

    return Container(
      // Full screen background with dark premium nebula theme
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF070709),
            Color(0xFF0F0F16),
            Color(0xFF140B18),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background ambient light sparkles/circles
          Positioned(
            top: screenSize.height * 0.15,
            left: screenSize.width * 0.1,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF2E74).withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            bottom: screenSize.height * 0.2,
            right: screenSize.width * 0.15,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8A2EFF).withOpacity(0.03),
              ),
            ),
          ),
          Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: _isLaunching ? null : widget.onCancel,
                ),
                title: const Text(
                  'Origami Desk',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                centerTitle: true,
                actions: [
                  if (!_isLaunching)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: TextButton.icon(
                        onPressed: _runAutoFoldSequence,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFFF2E74),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: Color(0xFFFF2E74), width: 1),
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 14),
                        label: const Text(
                          'Auto-Fold',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: stageFraction.clamp(0.0, 1.0),
                        minHeight: 5,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFF2E74)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'STAGE $_stage OF $_totalStages',
                      style: const TextStyle(
                        color: Color(0xFFFF2E74),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: Text(
                        copy.title,
                        key: ValueKey(_stage),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLaunching ? 'Taking flight…' : copy.helper,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_floatCtrl, _launchCtrl]),
                  builder: (context, _) {
                    final floatY = (0.5 - _floatCtrl.value) * 8;
                    final launchT = Curves.easeInOutCubic.transform(_launchCtrl.value);
                    
                    // Advanced flight trajectory: wind up slightly back/down, then swoosh forward/up
                    // Using bezier curve dynamics for launch path
                    final launchDx = launchT < 0.2 
                        ? -launchT * 30 
                        : (launchT - 0.2) * 550 - 6;
                    final launchDy = launchT < 0.2 
                        ? launchT * 20 
                        : -(launchT - 0.2) * 600 + 4;
                        
                    // Opacity fades near end of animation
                    final launchOpacity = 1.0 - (launchT * 1.25 - 0.25).clamp(0.0, 1.0);

                    // 3D rotation matrix calculation
                    final transformMatrix = Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // perspective
                      ..translate(launchDx, floatY + launchDy, 0.0)
                      ..rotateX(-launchT * 0.3)
                      ..rotateY(launchT * 0.8)
                      ..rotateZ(-launchT * 0.4)
                      ..scale(1.0 - launchT * 0.45);

                    return Center(
                      child: Opacity(
                        opacity: launchOpacity,
                        child: Transform(
                          transform: transformMatrix,
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onPanStart: _onPanStart,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            child: SizedBox(
                              // Large full screen canvas
                              width: screenSize.width * 0.9,
                              height: screenSize.height * 0.55,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Soft dynamic neon glow
                                  Container(
                                    width: 240,
                                    height: 300,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(32),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF2E74)
                                              .withValues(alpha: 0.15 + _dragProgress * 0.1),
                                          blurRadius: 70,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                  CustomPaint(
                                    size: Size(screenSize.width * 0.85, screenSize.height * 0.5),
                                    painter: _FoldablePaperPainter(
                                      stage: _stage,
                                      stageProgress: _dragProgress,
                                      message: widget.message,
                                      isLaunching: _isLaunching,
                                      launchProgress: _launchCtrl.value,
                                    ),
                                  ),
                                  if (!_isAnimating &&
                                      !_isLaunching &&
                                      _dragProgress < 0.12)
                                    Align(
                                      alignment: copy.guide,
                                      child: const _PulseIndicator(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: Text(
                  _isLaunching
                      ? '✈️  Launching into the clouds!'
                      : 'Swipe in direction of fold to fold the paper',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulseIndicator extends StatefulWidget {
  const _PulseIndicator();

  @override
  State<_PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<_PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.8, end: 1.4).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.scale(
            scale: _scale.value,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFF2E74)],
                ),
                border: Border.all(color: Colors.white70, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2E74).withValues(alpha: 0.6),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.swipe_rounded,
                size: 13,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Realistic origami paper plane painter (6 Stages) ────────────────────────
class _FoldablePaperPainter extends CustomPainter {
  final int stage;
  final double stageProgress;
  final String message;
  final bool isLaunching;
  final double launchProgress;

  // Paper palette
  static const _paper = Color(0xFFFAFAFA);
  static const _paperWarm = Color(0xFFF2E9DE);
  static const _paperEdge = Color(0xFFDFD1BE);
  static const _crease = Color(0xFFCBB69B);
  static const _foldShadow = Color(0xFF7E6E56);
  static const _ink = Color(0xFF282015);

  _FoldablePaperPainter({
    required this.stage,
    required this.stageProgress,
    required this.message,
    this.isLaunching = false,
    this.launchProgress = 0,
  });

  double _s(double t) {
    t = t.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  (double scale, double shade) _foldPerspective(double t) {
    final p = _s(t);
    if (p < 0.5) {
      final u = p * 2;
      return (1.0 - u * 0.96, 0.15 + u * 0.55);
    } else {
      final u = (p - 0.5) * 2;
      return (0.04 + u * 0.96, 0.7 - u * 0.45);
    }
  }

  Paint _paperFill({double shade = 0}) {
    final c = Color.lerp(_paper, _foldShadow, shade.clamp(0.0, 0.75))!;
    return Paint()
      ..color = c
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
  }

  Paint _edgePaint({double width = 1.2}) => Paint()
    ..color = _paperEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Paint _creasePaint({double alpha = 0.55, double width = 1.3}) => Paint()
    ..color = _crease.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  void _drawSoftShadow(Canvas canvas, Path path, {double blur = 18, double dy = 8}) {
    canvas.drawPath(
      path.shift(Offset(0, dy)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
        ..isAntiAlias = true,
    );
  }

  void _drawPaperBody(Canvas canvas, Path path, {double shade = 0, bool showLines = true}) {
    _drawSoftShadow(canvas, path);
    canvas.drawPath(path, _paperFill(shade: shade));

    final bounds = path.getBounds();
    final highlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.45),
          Colors.transparent,
          _paperWarm.withValues(alpha: 0.35),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(bounds)
      ..blendMode = BlendMode.srcATop;
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(bounds, highlight);
    
    if (showLines && stage <= 4) {
      final line = Paint()
        ..color = const Color(0xFFB0D2EB).withValues(alpha: 0.25)
        ..strokeWidth = 0.9;
      for (double y = bounds.top + 32; y < bounds.bottom - 12; y += 16) {
        canvas.drawLine(
          Offset(bounds.left + 16, y),
          Offset(bounds.right - 16, y),
          line,
        );
      }
    }
    canvas.restore();
    canvas.drawPath(path, _edgePaint());
  }

  void _draw3DCrease(Canvas canvas, Offset p1, Offset p2, Offset perp) {
    // Light reflection highlight
    canvas.drawLine(
      p1 + perp * 0.8,
      p2 + perp * 0.8,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..strokeWidth = 1.0
        ..isAntiAlias = true,
    );
    // Dark crease line
    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..color = _crease.withValues(alpha: 0.8)
        ..strokeWidth = 1.3
        ..isAntiAlias = true,
    );
    // Crease fold shadow
    canvas.drawLine(
      p1 - perp * 0.8,
      p2 - perp * 0.8,
      Paint()
        ..color = _foldShadow.withValues(alpha: 0.35)
        ..strokeWidth = 1.0
        ..isAntiAlias = true,
    );
  }

  void _drawFoldingFlap({
    required Canvas canvas,
    required Offset creaseA,
    required Offset creaseB,
    required Offset tip,
    required Offset targetTip,
    required double t,
    bool showGuide = true,
  }) {
    final p = _s(t);
    final (scale, shade) = _foldPerspective(p);

    final mid = Offset(
      (creaseA.dx + creaseB.dx) / 2,
      (creaseA.dy + creaseB.dy) / 2,
    );
    final axis = creaseB - creaseA;
    final axisLen = axis.distance;
    if (axisLen < 0.001) return;
    final axisDir = axis / axisLen;
    final perp = Offset(-axisDir.dy, axisDir.dx);

    final tipRel = tip - mid;
    final tipSide = tipRel.dx * perp.dx + tipRel.dy * perp.dy;
    final targetRel = targetTip - mid;
    final targetSide = targetRel.dx * perp.dx + targetRel.dy * perp.dy;

    late Offset animatedTip;
    if (p < 0.5) {
      final u = p * 2;
      final tipOnCrease = mid + axisDir * (tipRel.dx * axisDir.dx + tipRel.dy * axisDir.dy);
      final thickness = (tipSide.abs()) * (1 - u) * scale.clamp(0.04, 1.0);
      final sign = tipSide >= 0 ? 1.0 : -1.0;
      animatedTip = tipOnCrease + perp * sign * thickness;
    } else {
      final u = (p - 0.5) * 2;
      final tipOnCrease = mid + axisDir * (targetRel.dx * axisDir.dx + targetRel.dy * axisDir.dy);
      final thickness = (targetSide.abs()) * u * scale.clamp(0.04, 1.0);
      final sign = targetSide >= 0 ? 1.0 : -1.0;
      animatedTip = tipOnCrease + perp * sign * thickness;
    }

    final flap = Path()
      ..moveTo(creaseA.dx, creaseA.dy)
      ..lineTo(animatedTip.dx, animatedTip.dy)
      ..lineTo(creaseB.dx, creaseB.dy)
      ..close();

    // Dynamic liftoff shadow physics
    if (p > 0.01 && p < 0.99) {
      final height = 1.0 - (2.0 * (p - 0.5)).abs(); // 0.0 at flat edges, 1.0 at 90-deg peak
      final shadowBlur = 3.0 + height * 18.0;
      final shadowOpacity = 0.25 - height * 0.14;
      final shadowOffset = Offset(
        perp.dx * (1.5 + height * 12.0),
        perp.dy * (1.5 + height * 12.0) + (1.0 + height * 5.0),
      );

      canvas.drawPath(
        flap.shift(shadowOffset),
        Paint()
          ..color = Colors.black.withValues(alpha: shadowOpacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur)
          ..isAntiAlias = true,
      );
    }

    canvas.drawPath(flap, _paperFill(shade: shade * 0.55));
    canvas.drawPath(flap, _edgePaint(width: 1.0));
    
    // Draw crease line with high-fidelity highlights and shadows
    _draw3DCrease(canvas, creaseA, creaseB, perp);

    if (showGuide && p < 0.85) {
      final ghost = Path()
        ..moveTo(creaseA.dx, creaseA.dy)
        ..lineTo(targetTip.dx, targetTip.dy)
        ..lineTo(creaseB.dx, creaseB.dy)
        ..close();
      canvas.drawPath(
        ghost,
        Paint()
          ..color = const Color(0xFFFF2E74).withValues(alpha: 0.08 * (1 - p))
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        ghost,
        Paint()
          ..color = const Color(0xFFFF2E74).withValues(alpha: 0.3 * (1 - p))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawMessage(Canvas canvas, Rect area, String msg, {required double opacity}) {
    if (opacity <= 0.05) return;
    final textToShow = msg.trim().isEmpty ? 'Write your message...' : msg;
    final truncated = textToShow.length > 80 ? '${textToShow.substring(0, 77)}…' : textToShow;

    final tp = TextPainter(
      text: TextSpan(
        text: truncated,
        style: TextStyle(
          color: _ink.withValues(alpha: opacity),
          fontSize: 13.0,
          height: 1.5,
          fontWeight: FontWeight.w500,
          fontFamily: 'serif',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 6,
    );
    tp.layout(maxWidth: area.width - 24);
    tp.paint(
      canvas,
      Offset(area.center.dx - tp.width / 2, area.center.dy - tp.height / 2),
    );
  }

  Path _planeSilhouette(double cx, double cy, double scale) {
    return Path()
      ..moveTo(cx + 85 * scale, cy)
      ..lineTo(cx - 75 * scale, cy - 44 * scale)
      ..lineTo(cx - 30 * scale, cy - 6 * scale)
      ..lineTo(cx - 75 * scale, cy + 44 * scale)
      ..lineTo(cx - 35 * scale, cy + 8 * scale)
      ..close();
  }

  void _drawFinishedPlane(Canvas canvas, double cx, double cy, double t) {
    final scale = 1.1 + t * 0.15;
    final path = _planeSilhouette(cx, cy, scale);

    // Glowing flight exhaust effect
    if (isLaunching) {
      final exhaustPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF2E74).withValues(alpha: 0.9),
            const Color(0xFF8A2EFF).withValues(alpha: 0.3),
            Colors.transparent
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx - 65 * scale, cy), radius: 60 * t));
      canvas.drawCircle(Offset(cx - 65 * scale, cy), 50 * t, exhaustPaint);

      // Wind trails/sparks
      final sparkPaint = Paint()
        ..color = const Color(0xFFFF6B9D).withOpacity(1.0 - t)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx - 90 * scale, cy - 10), 4 * (1 - t), sparkPaint);
      canvas.drawCircle(Offset(cx - 100 * scale, cy + 15), 3 * (1 - t), sparkPaint);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF2E74).withValues(alpha: 0.2 + t * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    _drawSoftShadow(canvas, path, blur: 24, dy: 12);

    canvas.drawPath(path, _paperFill(shade: 0.03));

    // Wings detailing
    final upperWing = Path()
      ..moveTo(cx + 85 * scale, cy)
      ..lineTo(cx - 75 * scale, cy - 44 * scale)
      ..lineTo(cx - 30 * scale, cy - 6 * scale)
      ..close();
    canvas.save();
    canvas.clipPath(upperWing);
    canvas.drawRect(
      upperWing.getBounds(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.3), Colors.transparent],
        ).createShader(upperWing.getBounds()),
    );
    canvas.restore();

    final lowerWing = Path()
      ..moveTo(cx + 85 * scale, cy)
      ..lineTo(cx - 35 * scale, cy + 8 * scale)
      ..lineTo(cx - 75 * scale, cy + 44 * scale)
      ..close();
    canvas.save();
    canvas.clipPath(lowerWing);
    canvas.drawRect(
      lowerWing.getBounds(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, _foldShadow.withValues(alpha: 0.2)],
        ).createShader(lowerWing.getBounds()),
    );
    canvas.restore();

    // Fuselage spine
    final spine = Path()
      ..moveTo(cx + 80 * scale, cy)
      ..lineTo(cx - 32 * scale, cy - 8 * scale)
      ..lineTo(cx - 32 * scale, cy + 8 * scale)
      ..close();
    canvas.drawPath(spine, _paperFill(shade: 0.22));

    canvas.drawLine(Offset(cx + 70 * scale, cy), Offset(cx - 65 * scale, cy - 30 * scale), _creasePaint(alpha: 0.75, width: 1.5));
    canvas.drawLine(Offset(cx + 70 * scale, cy), Offset(cx - 65 * scale, cy + 30 * scale), _creasePaint(alpha: 0.75, width: 1.5));
    canvas.drawLine(Offset(cx + 80 * scale, cy), Offset(cx - 35 * scale, cy), _creasePaint(alpha: 0.6, width: 1.2));

    canvas.drawPath(path, _edgePaint(width: 1.5));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 10;

    // Significantly increased paper dimensions for full-screen feel
    const w = 240.0;
    const h = 310.0;
    final left = cx - w / 2;
    final right = cx + w / 2;
    final top = cy - h / 2;
    final bottom = cy + h / 2;
    final midX = cx;
    final foldY = top + w / 2;

    final t = stageProgress.clamp(0.0, 1.0);

    if (isLaunching || (stage == 6 && t > 0.92)) {
      final launchT = isLaunching ? launchProgress : (t - 0.92) / 0.08;
      _drawFinishedPlane(canvas, cx, cy, launchT.clamp(0.0, 1.0));
      return;
    }

    // ── STAGE 1: Top-left corner fold ──
    if (stage == 1) {
      final Path sheet = Path()
        ..moveTo(left, foldY)
        ..lineTo(midX, top)
        ..lineTo(right, top)
        ..lineTo(right, bottom)
        ..lineTo(left, bottom)
        ..close();
      _drawPaperBody(canvas, sheet);
      canvas.drawLine(Offset(midX, top), Offset(midX, bottom), _creasePaint(alpha: 0.3, width: 1));

      _drawFoldingFlap(
        canvas: canvas,
        creaseA: Offset(left, foldY),
        creaseB: Offset(midX, top),
        tip: Offset(left, top),
        targetTip: Offset(midX, foldY),
        t: t,
        showGuide: t < 0.95,
      );

      _drawMessage(canvas, Rect.fromLTRB(left + 24, foldY + 16, right - 24, bottom - 24), message, opacity: 0.9 - _s(t) * 0.4);
      return;
    }

    // ── STAGE 2: Top-right corner fold ──
    if (stage == 2) {
      final Path sheet = Path()
        ..moveTo(left, foldY)
        ..lineTo(midX, top)
        ..lineTo(right, foldY)
        ..lineTo(right, bottom)
        ..lineTo(left, bottom)
        ..close();
      _drawPaperBody(canvas, sheet);

      final leftDone = Path()
        ..moveTo(left, foldY)
        ..lineTo(midX, top)
        ..lineTo(midX, foldY)
        ..close();
      canvas.drawPath(leftDone, _paperFill(shade: 0.15));
      canvas.drawPath(leftDone, _edgePaint(width: 0.9));

      _drawFoldingFlap(
        canvas: canvas,
        creaseA: Offset(right, foldY),
        creaseB: Offset(midX, top),
        tip: Offset(right, top),
        targetTip: Offset(midX, foldY),
        t: t,
      );

      _drawMessage(canvas, Rect.fromLTRB(left + 24, foldY + 16, right - 24, bottom - 24), message, opacity: 0.5);
      return;
    }

    // ── STAGE 3: Left Diagonal Fold (Folding new left edge to center) ──
    if (stage == 3) {
      final Offset creaseStart = Offset(midX, top);
      final Offset creaseEnd = Offset(left + w * 0.35, bottom);

      final bodyPath = Path()
        ..moveTo(midX, top)
        ..lineTo(right, foldY)
        ..lineTo(right, bottom)
        ..lineTo(left, bottom)
        ..lineTo(left, foldY)
        ..close();
      _drawPaperBody(canvas, bodyPath, showLines: false);

      // Pre-folded corners settled
      final leftCorner = Path()
        ..moveTo(left, foldY)
        ..lineTo(midX, top)
        ..lineTo(midX, foldY)
        ..close();
      final rightCorner = Path()
        ..moveTo(right, foldY)
        ..lineTo(midX, top)
        ..lineTo(midX, foldY)
        ..close();
      canvas.drawPath(leftCorner, _paperFill(shade: 0.12));
      canvas.drawPath(rightCorner, _paperFill(shade: 0.12));

      _drawFoldingFlap(
        canvas: canvas,
        creaseA: creaseStart,
        creaseB: creaseEnd,
        tip: Offset(left, foldY),
        targetTip: Offset(midX, foldY + (bottom - foldY) * 0.2),
        t: t,
      );
      return;
    }

    // ── STAGE 4: Right Diagonal Fold ──
    if (stage == 4) {
      final Offset creaseStart = Offset(midX, top);
      final Offset creaseEnd = Offset(right - w * 0.35, bottom);

      final bodyPath = Path()
        ..moveTo(midX, top)
        ..lineTo(right, foldY)
        ..lineTo(right, bottom)
        ..lineTo(left, bottom)
        ..lineTo(left, foldY)
        ..close();
      _drawPaperBody(canvas, bodyPath, showLines: false);

      // Previous left diagonal fold settled
      final leftDiagDone = Path()
        ..moveTo(midX, top)
        ..lineTo(left + w * 0.35, bottom)
        ..lineTo(left, bottom)
        ..lineTo(left, foldY)
        ..close();
      canvas.drawPath(leftDiagDone, _paperFill(shade: 0.18));
      canvas.drawPath(leftDiagDone, _edgePaint(width: 1.0));

      final rightCorner = Path()
        ..moveTo(right, foldY)
        ..lineTo(midX, top)
        ..lineTo(midX, foldY)
        ..close();
      canvas.drawPath(rightCorner, _paperFill(shade: 0.12));

      _drawFoldingFlap(
        canvas: canvas,
        creaseA: creaseStart,
        creaseB: creaseEnd,
        tip: Offset(right, foldY),
        targetTip: Offset(midX, foldY + (bottom - foldY) * 0.2),
        t: t,
      );
      return;
    }

    // ── STAGE 5: Fold in half ──
    if (stage == 5) {
      final p = _s(t);
      final (scale, shade) = _foldPerspective(p);

      final leftHalf = Path()
        ..moveTo(left, bottom)
        ..lineTo(left, foldY)
        ..lineTo(midX, top)
        ..lineTo(midX, bottom)
        ..close();
      _drawPaperBody(canvas, leftHalf, shade: 0.03, showLines: false);

      final height = 1.0 - (2.0 * (p - 0.5)).abs();
      final shadowBlur = 4.0 + height * 20.0;
      final shadowOpacity = 0.25 - height * 0.12;

      if (p < 0.5) {
        final openW = (w / 2) * scale;
        final rightHalf = Path()
          ..moveTo(midX, top)
          ..lineTo(midX + openW, foldY)
          ..lineTo(midX + openW, bottom)
          ..lineTo(midX, bottom)
          ..close();
          
        canvas.drawPath(
          rightHalf.shift(Offset(-height * 14.0, height * 6.0)),
          Paint()
            ..color = Colors.black.withValues(alpha: shadowOpacity)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur)
            ..isAntiAlias = true,
        );
        canvas.drawPath(rightHalf, _paperFill(shade: shade * 0.45));
        canvas.drawPath(rightHalf, _edgePaint());
      } else {
        final flipW = (w / 2) * scale;
        final over = Path()
          ..moveTo(midX, top)
          ..lineTo(midX - flipW, foldY)
          ..lineTo(midX - flipW, bottom)
          ..lineTo(midX, bottom)
          ..close();
          
        canvas.drawPath(
          over.shift(Offset(-height * 6.0, height * 4.0 + 2)),
          Paint()
            ..color = Colors.black.withValues(alpha: shadowOpacity)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur)
            ..isAntiAlias = true,
        );
        canvas.drawPath(over, _paperFill(shade: 0.15 + shade * 0.15));
        canvas.drawPath(over, _edgePaint());
      }

      // Crease line at center spine
      _draw3DCrease(canvas, Offset(midX, top), Offset(midX, bottom), const Offset(1.0, 0.0));
      return;
    }

    // ── STAGE 6: Fold wings down ──
    if (stage == 6) {
      final p = _s(t);
      const bodyHalfW = 20.0;
      final noseY = top + 8;
      final tailY = bottom - 10;
      final bodyLeft = midX - bodyHalfW;
      final bodyRight = midX + bodyHalfW;

      final wingSpan = 15.0 + 105.0 * p;
      final wingAngle = 0.6 + p * 0.25;
      final wingTipY = noseY + (tailY - noseY) * wingAngle;

      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, tailY + 16), width: 120 + wingSpan * 0.7, height: 26),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );

      final leftWing = Path()
        ..moveTo(midX, noseY)
        ..lineTo(midX - wingSpan, wingTipY)
        ..lineTo(midX - wingSpan * 0.8, tailY - 20)
        ..lineTo(bodyLeft, tailY - 8)
        ..close();

      final rightWing = Path()
        ..moveTo(midX, noseY)
        ..lineTo(midX + wingSpan, wingTipY)
        ..lineTo(midX + wingSpan * 0.8, tailY - 20)
        ..lineTo(bodyRight, tailY - 8)
        ..close();

      // Draw wing liftoff shadows
      final wingHeight = 1.0 - p;
      final wingShadowBlur = 3.0 + wingHeight * 12.0;
      final wingShadowOpacity = 0.22 - wingHeight * 0.1;
      
      canvas.drawPath(
        leftWing.shift(Offset(-wingHeight * 8.0, wingHeight * 4.0 + 1)),
        Paint()
          ..color = Colors.black.withValues(alpha: wingShadowOpacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, wingShadowBlur)
          ..isAntiAlias = true,
      );
      canvas.drawPath(
        rightWing.shift(Offset(wingHeight * 8.0, wingHeight * 4.0 + 1)),
        Paint()
          ..color = Colors.black.withValues(alpha: wingShadowOpacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, wingShadowBlur)
          ..isAntiAlias = true,
      );

      canvas.drawPath(leftWing, _paperFill(shade: 0.12 + p * 0.05));
      canvas.drawPath(rightWing, _paperFill(shade: 0.06));

      for (final wing in [leftWing, rightWing]) {
        final b = wing.getBounds();
        canvas.save();
        canvas.clipPath(wing);
        canvas.drawRect(
          b,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withValues(alpha: 0.4), _paperWarm.withValues(alpha: 0.2), _foldShadow.withValues(alpha: 0.15)],
            ).createShader(b),
        );
        canvas.restore();
        canvas.drawPath(wing, _edgePaint(width: 1.2));
      }

      final body = Path()
        ..moveTo(midX, noseY - 8)
        ..lineTo(bodyRight, noseY + 22)
        ..lineTo(bodyRight, tailY)
        ..lineTo(midX, tailY + 10)
        ..lineTo(bodyLeft, tailY)
        ..lineTo(bodyLeft, noseY + 22)
        ..close();
      canvas.drawPath(body, _paperFill(shade: 0.24));
      canvas.drawPath(body, _edgePaint(width: 1.4));

      canvas.drawLine(Offset(midX, noseY), Offset(midX - wingSpan * 0.7, noseY + (tailY - noseY) * wingAngle * 0.65), _creasePaint(alpha: 0.65 + p * 0.25, width: 1.5));
      canvas.drawLine(Offset(midX, noseY), Offset(midX + wingSpan * 0.7, noseY + (tailY - noseY) * wingAngle * 0.65), _creasePaint(alpha: 0.65 + p * 0.25, width: 1.5));
      canvas.drawLine(Offset(midX, noseY - 6), Offset(midX, tailY + 6), _creasePaint(alpha: 0.9, width: 1.8));
    }
  }

  @override
  bool shouldRepaint(_FoldablePaperPainter old) =>
      old.stage != stage ||
      old.stageProgress != stageProgress ||
      old.message != message ||
      old.isLaunching != isLaunching ||
      old.launchProgress != launchProgress;
}

// ─── Launch Success Overlay ───────────────────────────────────
class _LaunchSuccessOverlay extends StatefulWidget {
  final VoidCallback onDone;

  const _LaunchSuccessOverlay({required this.onDone});

  @override
  State<_LaunchSuccessOverlay> createState() => _LaunchSuccessOverlayState();
}

class _LaunchSuccessOverlayState extends State<_LaunchSuccessOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _planeFlight;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.4, curve: Curves.elasticOut),
      ),
    );
    _planeFlight = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeInOutCubic),
      ),
    );
    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF06060E),
              Color(0xFF0F0F23),
              Color(0xFF26102A),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Ambient stars or circles in background
            Positioned.fill(
              child: Opacity(
                opacity: 0.15,
                child: Image.network(
                  'https://www.transparenttextures.com/patterns/dust.png',
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),

            // Immersive Plane flying across the sky
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _planeFlight,
                builder: (context, _) {
                  final t = _planeFlight.value;
                  final screenW = MediaQuery.of(context).size.width;
                  final screenH = MediaQuery.of(context).size.height;
                  
                  // Curved bezier trajectory: flies from bottom-left to top-right
                  final startX = -100.0;
                  final startY = screenH * 0.7;
                  final endX = screenW + 100.0;
                  final endY = screenH * 0.15;
                  
                  // Control point for curve
                  final cpX = screenW * 0.5;
                  final cpY = screenH * 0.3;
                  
                  // Quadratic bezier interpolation
                  final dx = (1 - t) * (1 - t) * startX + 2 * (1 - t) * t * cpX + t * t * endX;
                  final dy = (1 - t) * (1 - t) * startY + 2 * (1 - t) * t * cpY + t * t * endY;
                  
                  final rot = -0.5 + t * 0.8;
                  
                  return Stack(
                    children: [
                      // Trail particles
                      if (t > 0.05 && t < 0.95)
                        for (int i = 0; i < 8; i++)
                          Positioned(
                            left: dx - (i * 12 * cos(rot)),
                            top: dy - (i * 12 * sin(rot)) + 20,
                            child: Opacity(
                              opacity: ((10 - i) / 10.0) * (1.0 - t).clamp(0.0, 1.0),
                              child: Container(
                                width: (6 - i * 0.5).clamp(1.0, 6.0),
                                height: (6 - i * 0.5).clamp(1.0, 6.0),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF2E74),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFFFF2E74),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      Positioned(
                        left: dx,
                        top: dy,
                        child: Transform.rotate(
                          angle: rot,
                          child: const Text('✈️', style: TextStyle(fontSize: 64)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Success Text Card
            Center(
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16161E).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0xFFFF2E74).withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF2E74).withValues(alpha: 0.15),
                        blurRadius: 30,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2E74).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.done_all_rounded,
                          color: Color(0xFFFF2E74),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Launched Successfully!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your paper plane is flying high in the sky.\nSomeone special will catch it soon!',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 14,
                          height: 1.45,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
