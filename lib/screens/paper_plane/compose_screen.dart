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

  Future<void> _onLaunch() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) {
      _showError('Write a message for your plane!');
      return;
    }

    _focusNode.unfocus();
    setState(() => _isAnimatingLaunch = true);
    HapticFeedback.mediumImpact();

    // Phase 1: paper folds into plane
    await _foldController.forward();
    await Future.delayed(const Duration(milliseconds: 200));

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
      _foldController.reset();
      _flyController.reset();
      setState(() => _isAnimatingLaunch = false);
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
        ..color = Colors.white.withValues(alpha: 1.0 - t)
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
              color: Colors.black.withValues(alpha: 1.0 - t / 0.8),
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
            .withValues(alpha: t - i + 0.1);
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
        ..color = const Color(0xFFFF2E74).withValues(alpha: 0.3 * t)
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
