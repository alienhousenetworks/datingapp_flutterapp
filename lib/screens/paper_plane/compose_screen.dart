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
                      animation: _foldAnim,
                      builder: (_, __) {
                        return _PlaneWidget(foldProgress: _foldAnim.value);
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

// ─── Plane Widget (paper → plane fold animation) ──────────────
class _PlaneWidget extends StatelessWidget {
  final double foldProgress; // 0 = paper, 1 = plane

  const _PlaneWidget({required this.foldProgress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: CustomPaint(
        painter: _PlanePainter(foldProgress: foldProgress),
      ),
    );
  }
}

class _PlanePainter extends CustomPainter {
  final double foldProgress;

  _PlanePainter({required this.foldProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Paper fill
    final paperPaint = Paint()
      ..color =
          Color.lerp(Colors.white, const Color(0xFFFF2E74), foldProgress)!
      ..style = PaintingStyle.fill;

    // Outline
    final outlinePaint = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    if (foldProgress < 0.5) {
      // Draw flat paper sheet
      final t = foldProgress / 0.5;
      final path = Path()
        ..moveTo(cx - 50 + t * 20, cy - 40)
        ..lineTo(cx + 50 - t * 20, cy - 40 + t * 20)
        ..lineTo(cx + 50 - t * 10, cy + 40 - t * 20)
        ..lineTo(cx - 50 + t * 10, cy + 40)
        ..close();
      canvas.drawPath(path, paperPaint);
      canvas.drawPath(path, outlinePaint);

      // Fold lines on paper
      final linePaint = Paint()
        ..color = Colors.white.withOpacity(0.3 - t * 0.2)
        ..strokeWidth = 1;
      canvas.drawLine(
          Offset(cx, cy - 40 + t * 10), Offset(cx, cy + 40 - t * 10),
          linePaint);
    } else {
      // Draw paper plane
      final t = (foldProgress - 0.5) / 0.5;
      final path = Path()
        // Nose
        ..moveTo(cx + 60 * t, cy)
        // Top wing
        ..lineTo(cx - 40, cy - 20 - t * 10)
        // Body top
        ..lineTo(cx - 10, cy - 5 + t * 5)
        // Bottom wing
        ..lineTo(cx - 40, cy + 20 + t * 10)
        // Tail
        ..lineTo(cx - 20 + t * 5, cy + 5)
        ..close();
      canvas.drawPath(path, paperPaint);
      canvas.drawPath(path, outlinePaint);

      // Shadow/depth line
      final shadowPaint = Paint()
        ..color = Colors.black.withOpacity(0.2 * t)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(cx - 10, cy - 5 + t * 5),
        Offset(cx - 20 + t * 5, cy + 5),
        shadowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_PlanePainter old) => old.foldProgress != foldProgress;
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
