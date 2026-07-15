import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF2A2A2A),
                          width: 1,
                        ),
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
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                          counterText: '',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$remaining left',
                        style: TextStyle(
                          color: remaining < 20
                              ? Colors.orange
                              : Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    // ── Sticker picker ──
                    const SizedBox(height: 16),
                    const Text(
                      'Add a sticker (optional)',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _stickers.length + 1, // +1 for "none"
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            final selected = _selectedSticker.isEmpty;
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedSticker = ''),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 44,
                                height: 44,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white12
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? Colors.white54
                                        : Colors.white24,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Center(
                                  child: Text('✕',
                                      style:
                                          TextStyle(color: Colors.white54)),
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
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFFF2E74).withOpacity(0.2)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFFFF2E74)
                                      : Colors.white12,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  sticker,
                                  style: const TextStyle(fontSize: 22),
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
  static const _totalStages = 5;

  int _stage = 1;
  double _dragProgress = 0.0;
  bool _isAnimating = false;
  bool _isLaunching = false;

  late AnimationController _foldCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _launchCtrl;
  late Animation<double> _foldCurve;

  @override
  void initState() {
    super.initState();
    _foldCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    );
    _foldCurve = CurvedAnimation(
      parent: _foldCtrl,
      curve: Curves.easeInOutCubic,
    );
    _foldCtrl.addListener(() {
      setState(() => _dragProgress = _foldCurve.value);
    });

    // Gentle idle float so paper feels alive
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);

    _launchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void dispose() {
    _foldCtrl.dispose();
    _floatCtrl.dispose();
    _launchCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerAutoFold() async {
    if (_isAnimating || _isLaunching) return;
    setState(() => _isAnimating = true);
    HapticFeedback.mediumImpact();

    // Snap crease near the midpoint for a paper "click"
    final from = _dragProgress;
    _foldCtrl.value = from;
    await _foldCtrl.forward();
    if (!mounted) return;

    HapticFeedback.selectionClick();
    await Future.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    if (_stage < _totalStages) {
      setState(() {
        _stage++;
        _dragProgress = 0.0;
        _isAnimating = false;
      });
      _foldCtrl.reset();
      HapticFeedback.lightImpact();
    } else {
      // Final launch pose
      setState(() => _isLaunching = true);
      HapticFeedback.heavyImpact();
      await _launchCtrl.forward();
      if (!mounted) return;
      widget.onFoldComplete();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating || _isLaunching) return;
    double delta = 0;
    switch (_stage) {
      case 1:
        delta = details.delta.dx + details.delta.dy;
        break;
      case 2:
        delta = -details.delta.dx + details.delta.dy;
        break;
      case 3:
        delta = -details.delta.dx;
        break;
      case 4:
        delta = details.delta.dy;
        break;
      case 5:
        delta = details.delta.dx.abs() + details.delta.dy.abs();
        break;
    }

    if (delta <= 0) return;
    setState(() {
      _dragProgress = (_dragProgress + delta / 140).clamp(0.0, 1.0);
      // Soft haptic ticks as the fold progresses
      if (_dragProgress > 0.12 && _dragProgress < 0.15) {
        HapticFeedback.selectionClick();
      }
      if (_dragProgress >= 0.22) {
        _triggerAutoFold();
      }
    });
  }

  ({String title, String helper, Alignment guide}) get _copy {
    switch (_stage) {
      case 1:
        return (
          title: 'Fold top-left corner',
          helper: 'Drag the corner to the center crease',
          guide: const Alignment(-0.55, -0.55),
        );
      case 2:
        return (
          title: 'Fold top-right corner',
          helper: 'Match the other side to the center line',
          guide: const Alignment(0.55, -0.55),
        );
      case 3:
        return (
          title: 'Fold in half',
          helper: 'Close the paper along the spine',
          guide: const Alignment(0.6, 0.05),
        );
      case 4:
        return (
          title: 'Fold the wings',
          helper: 'Pull each wing down to form the body',
          guide: const Alignment(-0.15, -0.35),
        );
      default:
        return (
          title: 'Crease & launch',
          helper: 'Drag along the center to lock the fold',
          guide: Alignment.center,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    final stageFraction = ((_stage - 1) + _dragProgress) / _totalStages;

    return Container(
      color: const Color(0xFF0F0F11),
      child: Column(
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
              'Fold your plane',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
            child: Column(
              children: [
                // Stage progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: stageFraction.clamp(0.0, 1.0),
                    minHeight: 4,
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
                      fontSize: 20,
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
                final floatY = (0.5 - _floatCtrl.value) * 6;
                final launchT = Curves.easeInCubic.transform(_launchCtrl.value);
                final launchDx = launchT * 320;
                final launchDy = -launchT * 220;
                final launchRot = -launchT * 0.55;
                final launchScale = 1.0 - launchT * 0.35;
                final launchOpacity = 1.0 - (launchT * 1.15).clamp(0.0, 1.0);

                return Center(
                  child: Opacity(
                    opacity: launchOpacity,
                    child: Transform.translate(
                      offset: Offset(launchDx, floatY + launchDy),
                      child: Transform.rotate(
                        angle: launchRot,
                        child: Transform.scale(
                          scale: launchScale,
                          child: GestureDetector(
                            onPanUpdate: _onPanUpdate,
                            child: SizedBox(
                              width: 320,
                              height: 340,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Soft ambient glow under paper
                                  Container(
                                    width: 180,
                                    height: 200,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF2E74)
                                              .withValues(alpha: 0.12 + _dragProgress * 0.08),
                                          blurRadius: 48,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                  CustomPaint(
                                    size: const Size(320, 340),
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
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Text(
              _isLaunching
                  ? '✈️  Away it goes'
                  : 'Drag to fold  ·  release to auto-complete',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
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
    _scale = Tween<double>(begin: 0.75, end: 1.35).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.45, end: 1.0).animate(
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
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFF2E74)],
                ),
                border: Border.all(color: Colors.white70, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2E74).withValues(alpha: 0.55),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.touch_app_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Realistic origami paper plane painter ───────────────────────────────
class _FoldablePaperPainter extends CustomPainter {
  final int stage;
  final double stageProgress;
  final String message;
  final bool isLaunching;
  final double launchProgress;

  // Paper palette
  static const _paper = Color(0xFFFFFBF5);
  static const _paperWarm = Color(0xFFF5EDE0);
  static const _paperEdge = Color(0xFFE8DCC8);
  static const _crease = Color(0xFFD4C4A8);
  static const _foldShadow = Color(0xFF8A7A62);
  static const _ink = Color(0xFF2C2416);

  _FoldablePaperPainter({
    required this.stage,
    required this.stageProgress,
    required this.message,
    this.isLaunching = false,
    this.launchProgress = 0,
  });

  // Smoothstep for organic motion
  double _s(double t) {
    t = t.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  // Fold perspective: 0→1 maps to facing camera → edge-on → flipped
  // Returns (scale along fold axis, shade 0–1)
  (double scale, double shade) _foldPerspective(double t) {
    final p = _s(t);
    // scale goes 1 → ~0.04 at midpoint → 1 on the other side
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

  Paint _edgePaint({double width = 1.1}) => Paint()
    ..color = _paperEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Paint _creasePaint({double alpha = 0.55, double width = 1.2}) => Paint()
    ..color = _crease.withValues(alpha: alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  void _drawSoftShadow(Canvas canvas, Path path, {double blur = 14, double dy = 6}) {
    canvas.drawPath(
      path.shift(Offset(0, dy)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur)
        ..isAntiAlias = true,
    );
  }

  void _drawPaperBody(Canvas canvas, Path path, {double shade = 0}) {
    _drawSoftShadow(canvas, path);
    // Base fill
    canvas.drawPath(path, _paperFill(shade: shade));
    // Subtle top-left highlight gradient via layered translucent path
    final bounds = path.getBounds();
    final highlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.transparent,
          _paperWarm.withValues(alpha: 0.35),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(bounds)
      ..blendMode = BlendMode.srcATop;
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(bounds, highlight);
    // Faint ruled lines for “letter paper” feel early on
    if (stage <= 2) {
      final line = Paint()
        ..color = const Color(0xFFB8D4E8).withValues(alpha: 0.22)
        ..strokeWidth = 0.8;
      for (double y = bounds.top + 28; y < bounds.bottom - 12; y += 14) {
        canvas.drawLine(
          Offset(bounds.left + 12, y),
          Offset(bounds.right - 12, y),
          line,
        );
      }
    }
    canvas.restore();
    canvas.drawPath(path, _edgePaint());
  }

  /// Fold a triangle flap over a crease using perspective scale.
  /// [creaseA]/[creaseB] is the hinge. [tip] is the free corner.
  /// [targetTip] is where the tip lands when fully folded.
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

    // Midpoint of crease for local transform
    final mid = Offset(
      (creaseA.dx + creaseB.dx) / 2,
      (creaseA.dy + creaseB.dy) / 2,
    );
    final axis = creaseB - creaseA;
    final axisLen = axis.distance;
    if (axisLen < 0.001) return;
    final axisDir = axis / axisLen;
    // Perpendicular in plane
    final perp = Offset(-axisDir.dy, axisDir.dx);

    // Decide which side tip currently sits
    final tipRel = tip - mid;
    final tipSide = tipRel.dx * perp.dx + tipRel.dy * perp.dy;
    final targetRel = targetTip - mid;
    final targetSide = targetRel.dx * perp.dx + targetRel.dy * perp.dy;

    // Animated tip position: from tip → crease mid → target
    late Offset animatedTip;
    if (p < 0.5) {
      final u = p * 2;
      // Collapse tip toward crease (edge-on)
      final tipOnCrease = mid + axisDir * (tipRel.dx * axisDir.dx + tipRel.dy * axisDir.dy);
      animatedTip = Offset.lerp(tip, tipOnCrease, u)!;
      // Scale thickness via offset along perp
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

    // Drop shadow of moving flap
    if (p > 0.02 && p < 0.98) {
      canvas.drawPath(
        flap.shift(Offset(perp.dx * 3, perp.dy * 3 + 2)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12 + shade * 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    canvas.drawPath(flap, _paperFill(shade: shade * 0.55));
    // Inner fold gradient
    final fb = flap.getBounds();
    canvas.save();
    canvas.clipPath(flap);
    canvas.drawRect(
      fb,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            _foldShadow.withValues(alpha: shade * 0.35),
            Colors.white.withValues(alpha: 0.15 * (1 - shade)),
            _foldShadow.withValues(alpha: shade * 0.25),
          ],
        ).createShader(fb),
    );
    canvas.restore();
    canvas.drawPath(flap, _edgePaint(width: 1.0));

    // Crease hinge
    canvas.drawLine(creaseA, creaseB, _creasePaint(alpha: 0.65 + shade * 0.2, width: 1.4));

    // Ghost guide of destination
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
          ..color = const Color(0xFFFF2E74).withValues(alpha: 0.25 * (1 - p))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _drawMessage(
    Canvas canvas,
    Rect area,
    String msg, {
    required double opacity,
  }) {
    if (opacity <= 0.05) return;
    final textToShow = msg.trim().isEmpty ? 'Your message…' : msg;
    final truncated =
        textToShow.length > 48 ? '${textToShow.substring(0, 46)}…' : textToShow;

    final tp = TextPainter(
      text: TextSpan(
        text: truncated,
        style: TextStyle(
          color: _ink.withValues(alpha: opacity),
          fontSize: 11,
          height: 1.35,
          fontWeight: FontWeight.w500,
          fontFamily: 'serif',
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 4,
      ellipsis: '…',
    );
    tp.layout(maxWidth: area.width - 20);
    tp.paint(
      canvas,
      Offset(
        area.center.dx - tp.width / 2,
        area.center.dy - tp.height / 2,
      ),
    );
  }

  Path _planeSilhouette(double cx, double cy, double scale) {
    return Path()
      ..moveTo(cx + 52 * scale, cy)
      ..lineTo(cx - 48 * scale, cy - 28 * scale)
      ..lineTo(cx - 18 * scale, cy - 4 * scale)
      ..lineTo(cx - 48 * scale, cy + 28 * scale)
      ..lineTo(cx - 22 * scale, cy + 6 * scale)
      ..close();
  }

  void _drawFinishedPlane(Canvas canvas, double cx, double cy, double t) {
    final scale = 1.0 + t * 0.15;
    final path = _planeSilhouette(cx, cy, scale);

    // Glow
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF2E74).withValues(alpha: 0.2 + t * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );
    _drawSoftShadow(canvas, path, blur: 18, dy: 8);

    // Body with slight 3D: upper wing lighter, lower darker
    canvas.drawPath(path, _paperFill(shade: 0.05));

    // Center body spine
    final spine = Path()
      ..moveTo(cx + 48 * scale, cy)
      ..lineTo(cx - 20 * scale, cy - 3 * scale)
      ..lineTo(cx - 20 * scale, cy + 3 * scale)
      ..close();
    canvas.drawPath(spine, _paperFill(shade: 0.18));

    // Wing crease lines
    canvas.drawLine(
      Offset(cx + 40 * scale, cy),
      Offset(cx - 40 * scale, cy - 18 * scale),
      _creasePaint(alpha: 0.7, width: 1.3),
    );
    canvas.drawLine(
      Offset(cx + 40 * scale, cy),
      Offset(cx - 40 * scale, cy + 18 * scale),
      _creasePaint(alpha: 0.7, width: 1.3),
    );

    canvas.drawPath(path, _edgePaint(width: 1.3));

    // Specular highlight streak
    canvas.drawLine(
      Offset(cx + 30 * scale, cy - 4),
      Offset(cx - 10 * scale, cy - 10 * scale),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 8;

    // Paper dimensions (letter-ish ratio)
    const w = 148.0;
    const h = 196.0;
    final left = cx - w / 2;
    final right = cx + w / 2;
    final top = cy - h / 2;
    final bottom = cy + h / 2;
    final midX = cx;
    // Diagonal fold reaches this Y on the sides (classic corner-to-center)
    final foldY = top + w / 2; // square corner fold depth

    final t = stageProgress.clamp(0.0, 1.0);

    if (isLaunching || (stage == 5 && t > 0.92)) {
      final launchT = isLaunching ? launchProgress : (t - 0.92) / 0.08;
      _drawFinishedPlane(canvas, cx, cy, launchT.clamp(0.0, 1.0));
      return;
    }

    // ── STAGE 1: fold top-left corner to center ──
    if (stage == 1) {
      // Sheet: full before edge-on, corner cut after the flap passes the crease
      final Path sheet = t < 0.5
          ? (Path()..addRect(Rect.fromLTRB(left, top, right, bottom)))
          : (Path()
            ..moveTo(left, foldY)
            ..lineTo(midX, top)
            ..lineTo(right, top)
            ..lineTo(right, bottom)
            ..lineTo(left, bottom)
            ..close());
      _drawPaperBody(canvas, sheet);
      canvas.drawLine(
        Offset(midX, top),
        Offset(midX, bottom),
        _creasePaint(alpha: 0.35, width: 1),
      );
      _drawFoldingFlap(
        canvas: canvas,
        creaseA: Offset(left, foldY),
        creaseB: Offset(midX, top),
        tip: Offset(left, top),
        targetTip: Offset(midX, foldY),
        t: t,
        showGuide: t < 0.95,
      );

      _drawMessage(
        canvas,
        Rect.fromLTRB(left + 16, foldY + 8, right - 16, bottom - 16),
        message,
        opacity: 0.85 - t * 0.35,
      );
      return;
    }

    // ── STAGE 2: fold top-right corner (left already done) ──
    if (stage == 2) {
      final cutBody = Path()
        ..moveTo(left, foldY)
        ..lineTo(midX, top)
        ..lineTo(right, foldY)
        ..lineTo(right, bottom)
        ..lineTo(left, bottom)
        ..close();

      if (t < 0.5) {
        // Still show right corner attached
        final pre = Path()
          ..moveTo(left, foldY)
          ..lineTo(midX, top)
          ..lineTo(right, top)
          ..lineTo(right, bottom)
          ..lineTo(left, bottom)
          ..close();
        _drawPaperBody(canvas, pre);
      } else {
        _drawPaperBody(canvas, cutBody);
      }

      // Settled left triangle (previous fold)
      final leftDone = Path()
        ..moveTo(left, foldY)
        ..lineTo(midX, top)
        ..lineTo(midX, foldY)
        ..close();
      canvas.drawPath(leftDone, _paperFill(shade: 0.14));
      canvas.drawPath(leftDone, _edgePaint(width: 0.9));
      canvas.drawLine(Offset(left, foldY), Offset(midX, top), _creasePaint(alpha: 0.75));

      canvas.drawLine(
        Offset(midX, top),
        Offset(midX, bottom),
        _creasePaint(alpha: 0.35, width: 1),
      );

      _drawFoldingFlap(
        canvas: canvas,
        creaseA: Offset(right, foldY),
        creaseB: Offset(midX, top),
        tip: Offset(right, top),
        targetTip: Offset(midX, foldY),
        t: t,
      );

      _drawMessage(
        canvas,
        Rect.fromLTRB(left + 16, foldY + 12, right - 16, bottom - 16),
        message,
        opacity: 0.45,
      );
      return;
    }

    // ── STAGE 3: fold in half along vertical center ──
    if (stage == 3) {
      final p = _s(t);
      final (scale, shade) = _foldPerspective(p);

      // Left half always visible (ground)
      final leftHalf = Path()
        ..moveTo(left, foldY)
        ..lineTo(midX, top)
        ..lineTo(midX, bottom)
        ..lineTo(left, bottom)
        ..close();
      _drawPaperBody(canvas, leftHalf, shade: 0.02);

      // Settled nose triangle on left
      final nose = Path()
        ..moveTo(left, foldY)
        ..lineTo(midX, top)
        ..lineTo(midX, foldY)
        ..close();
      canvas.drawPath(nose, _paperFill(shade: 0.16));
      canvas.drawPath(nose, _edgePaint(width: 0.9));

      // Right half folding over
      final halfW = w / 2;
      final foldedWidth = halfW * scale;

      // Shadow under the closing flap
      if (p > 0.05 && p < 0.95) {
        final shadowW = halfW * (1 - p) + 8;
        canvas.drawRect(
          Rect.fromLTRB(midX - (p > 0.5 ? foldedWidth : 0), top, midX + shadowW, bottom),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.08 + shade * 0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
      }

      if (p < 0.5) {
        // Right side still open, collapsing toward spine
        final openW = halfW * scale;
        final rightHalf = Path()
          ..moveTo(midX, top)
          ..lineTo(midX + openW, top + (foldY - top) * (1 - scale).clamp(0.0, 1.0) * 0.15)
          ..lineTo(midX + openW, bottom)
          ..lineTo(midX, bottom)
          ..close();
        canvas.drawPath(rightHalf, _paperFill(shade: shade * 0.4));
        // Right nose remnant
        final rightNose = Path()
          ..moveTo(midX, top)
          ..lineTo(midX + openW * 0.85, foldY - (foldY - top) * (1 - scale) * 0.3)
          ..lineTo(midX, foldY)
          ..close();
        canvas.drawPath(rightNose, _paperFill(shade: 0.2 + shade * 0.3));
        canvas.drawPath(rightHalf, _edgePaint());
      } else {
        // Flipped onto left side
        final flipW = halfW * scale;
        final over = Path()
          ..moveTo(midX, top)
          ..lineTo(midX - flipW, top + 4)
          ..lineTo(midX - flipW, bottom)
          ..lineTo(midX, bottom)
          ..close();
        canvas.drawPath(
          over.shift(const Offset(-2, 2)),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.12)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawPath(over, _paperFill(shade: 0.12 + shade * 0.15));
        // Inner fold shading near spine
        canvas.drawRect(
          Rect.fromLTRB(midX - 6, top, midX, bottom),
          Paint()
            ..shader = LinearGradient(
              colors: [
                _foldShadow.withValues(alpha: 0.25),
                Colors.transparent,
              ],
            ).createShader(Rect.fromLTRB(midX - 6, top, midX, bottom)),
        );
        canvas.drawPath(over, _edgePaint());
      }

      // Spine crease
      canvas.drawLine(
        Offset(midX, top),
        Offset(midX, bottom),
        _creasePaint(alpha: 0.85, width: 1.6),
      );

      // Guide dashed half-fold
      if (p < 0.3) {
        final dash = Paint()
          ..color = const Color(0xFFFF2E74).withValues(alpha: 0.35)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawLine(Offset(midX, top + 8), Offset(midX, bottom - 8), dash);
      }
      return;
    }

    // ── STAGE 4: fold wings down (side view of half-folded plane) ──
    if (stage == 4) {
      final p = _s(t);
      // Body is a vertical strip (half sheet), wings fold out from top edge
      final bodyW = 28.0;
      final bodyLeft = midX - bodyW / 2;
      final bodyRight = midX + bodyW / 2;
      final noseY = top + 8;
      final tailY = bottom - 4;

      // Wing span grows as we fold
      final wingSpan = 8 + 58 * p;
      final wingDrop = 12 + 70 * p;

      // Soft table shadow
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, tailY + 10),
          width: 90 + wingSpan * 0.4,
          height: 18,
        ),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );

      // Left wing
      final leftWing = Path()
        ..moveTo(midX, noseY)
        ..lineTo(midX - wingSpan, noseY + wingDrop * 0.55)
        ..lineTo(midX - wingSpan * 0.85, tailY - 20)
        ..lineTo(bodyLeft, tailY - 8)
        ..lineTo(bodyLeft, noseY + 20)
        ..close();

      // Right wing
      final rightWing = Path()
        ..moveTo(midX, noseY)
        ..lineTo(midX + wingSpan, noseY + wingDrop * 0.55)
        ..lineTo(midX + wingSpan * 0.85, tailY - 20)
        ..lineTo(bodyRight, tailY - 8)
        ..lineTo(bodyRight, noseY + 20)
        ..close();

      // Wings with slight shade difference
      canvas.drawPath(
        leftWing.shift(const Offset(-1, 3)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        rightWing.shift(const Offset(1, 3)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );

      canvas.drawPath(leftWing, _paperFill(shade: 0.08 + p * 0.05));
      canvas.drawPath(rightWing, _paperFill(shade: 0.04));

      // Wing gradients
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
              colors: [
                Colors.white.withValues(alpha: 0.35),
                _paperWarm.withValues(alpha: 0.2),
                _foldShadow.withValues(alpha: 0.12),
              ],
            ).createShader(b),
        );
        canvas.restore();
        canvas.drawPath(wing, _edgePaint());
      }

      // Fuselage (center body)
      final body = Path()
        ..moveTo(midX, noseY - 4)
        ..lineTo(bodyRight, noseY + 16)
        ..lineTo(bodyRight, tailY)
        ..lineTo(midX, tailY + 6)
        ..lineTo(bodyLeft, tailY)
        ..lineTo(bodyLeft, noseY + 16)
        ..close();
      canvas.drawPath(body, _paperFill(shade: 0.2));
      canvas.drawPath(body, _edgePaint(width: 1.2));

      // Wing root creases
      canvas.drawLine(
        Offset(midX, noseY),
        Offset(midX - wingSpan * 0.7, noseY + wingDrop * 0.4),
        _creasePaint(alpha: 0.65 + p * 0.2, width: 1.3),
      );
      canvas.drawLine(
        Offset(midX, noseY),
        Offset(midX + wingSpan * 0.7, noseY + wingDrop * 0.4),
        _creasePaint(alpha: 0.65 + p * 0.2, width: 1.3),
      );

      // Center spine
      canvas.drawLine(
        Offset(midX, noseY - 2),
        Offset(midX, tailY + 2),
        _creasePaint(alpha: 0.8, width: 1.5),
      );

      // Hint arrow while early
      if (p < 0.25) {
        final arrowPaint = Paint()
          ..color = const Color(0xFFFF2E74).withValues(alpha: 0.5)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(midX - 40, noseY + 10),
          Offset(midX - 40, noseY + 40),
          arrowPaint,
        );
        canvas.drawLine(
          Offset(midX + 40, noseY + 10),
          Offset(midX + 40, noseY + 40),
          arrowPaint,
        );
      }
      return;
    }

    // ── STAGE 5: final crease polish → plane icon ──
    if (stage == 5) {
      final p = _s(t);
      // Morph from winged body to classic dart silhouette
      final morph = p;

      final bodyW = 28.0 * (1 - morph * 0.3);
      final wingSpan = 66.0 * (1 - morph * 0.15);
      final noseY = top + 20 + morph * 30;
      final tailY = bottom - 20 - morph * 10;

      if (morph < 0.55) {
        // Still wings form with deepening crease
        final leftWing = Path()
          ..moveTo(cx, noseY)
          ..lineTo(cx - wingSpan, noseY + 40)
          ..lineTo(cx - wingSpan * 0.8, tailY - 16)
          ..lineTo(cx - bodyW / 2, tailY)
          ..close();
        final rightWing = Path()
          ..moveTo(cx, noseY)
          ..lineTo(cx + wingSpan, noseY + 40)
          ..lineTo(cx + wingSpan * 0.8, tailY - 16)
          ..lineTo(cx + bodyW / 2, tailY)
          ..close();

        _drawSoftShadow(canvas, leftWing);
        _drawSoftShadow(canvas, rightWing);
        canvas.drawPath(leftWing, _paperFill(shade: 0.1));
        canvas.drawPath(rightWing, _paperFill(shade: 0.05));
        canvas.drawPath(leftWing, _edgePaint());
        canvas.drawPath(rightWing, _edgePaint());

        // Animated crease stroke
        final creaseLen = morph * 2;
        final creasePaint = Paint()
          ..shader = LinearGradient(
            colors: [
              const Color(0xFFFF2E74).withValues(alpha: 0.0),
              const Color(0xFFFF2E74).withValues(alpha: 0.85),
              const Color(0xFFFF2E74).withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(cx - 50, cy - 2, 100, 4))
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(cx - 48 * creaseLen.clamp(0.0, 1.0), cy),
          Offset(cx + 48 * creaseLen.clamp(0.0, 1.0), cy),
          creasePaint,
        );

        canvas.drawLine(
          Offset(cx, noseY),
          Offset(cx, tailY),
          _creasePaint(alpha: 0.75, width: 1.6),
        );
      } else {
        final planeT = ((morph - 0.55) / 0.45).clamp(0.0, 1.0);
        _drawFinishedPlane(canvas, cx, cy, planeT);
      }
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

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();

    Future.delayed(const Duration(seconds: 3), () {
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
    return Center(
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFFF2E74).withOpacity(0.4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✈️', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text(
                'Your plane is flying!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Someone special might catch it.\nWe\'ll notify you when they do.',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
