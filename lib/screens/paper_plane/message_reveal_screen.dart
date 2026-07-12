import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/paper_plane_provider.dart';
import '../../widgets/confetti_connect_widget.dart';

// ─────────────────────────────────────────────────────────────
// Message Reveal Screen
// Shown after the net catches the plane.
// Displays: sender info + message + 3-min countdown + Connect/Pass
// ─────────────────────────────────────────────────────────────

class MessageRevealScreen extends ConsumerStatefulWidget {
  const MessageRevealScreen({super.key});

  @override
  ConsumerState<MessageRevealScreen> createState() =>
      _MessageRevealScreenState();
}

class _MessageRevealScreenState extends ConsumerState<MessageRevealScreen>
    with TickerProviderStateMixin {
  // ── Reveal animation ──
  late AnimationController _revealController;
  late Animation<double> _scaleFade;

  // ── Circular countdown ──
  late Timer _timer;
  int _secondsLeft = 180; // 3 min — overridden by decisionDeadline from server
  bool _isActing = false;

  @override
  void initState() {
    super.initState();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleFade = CurvedAnimation(
      parent: _revealController,
      curve: Curves.elasticOut,
    );
    _revealController.forward();

    // Compute remaining seconds from server deadline
    final result = ref.read(catchGameProvider).catchResult;
    if (result != null) {
      final remaining = result.decisionDeadline.difference(DateTime.now());
      _secondsLeft = remaining.inSeconds.clamp(0, 180);
    }

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft = math.max(0, _secondsLeft - 1));
      if (_secondsLeft == 0) {
        t.cancel();
        _onTimerExpired();
      }
    });
  }

  Future<void> _onTimerExpired() async {
    if (_isActing) return;
    _isActing = true;
    HapticFeedback.mediumImpact();
    await ref.read(catchGameProvider.notifier).pass();
    if (mounted) {
      _showTimerExpiredSnack();
      context.go('/'); // back to main
    }
  }

  Future<void> _onConnect() async {
    if (_isActing) return;
    _isActing = true;
    _timer.cancel();
    HapticFeedback.heavyImpact();

    await ref.read(catchGameProvider.notifier).connect();
    if (!mounted) return;

    final state = ref.read(catchGameProvider);
    if (state.phase == GamePhase.connected && state.conversationId != null) {
      _showConnectedOverlay(state.conversationId!);
    } else {
      _isActing = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _onPass() async {
    if (_isActing) return;
    _isActing = true;
    _timer.cancel();
    HapticFeedback.mediumImpact();

    await ref.read(catchGameProvider.notifier).pass();
    if (mounted) {
      _showPassedSheet();
    }
  }

  void _showConnectedOverlay(String conversationId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => _ConnectedOverlay(
        conversationId: conversationId,
        onOpenChat: () {
          Navigator.of(context).pop();
          ref.read(catchGameProvider.notifier).reset();
          context.go('/chat/$conversationId');
        },
      ),
    );
  }

  void _showPassedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text('✈️', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text(
              'Plane flies on...',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Someone else might catch it. Good things take time.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.6), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(catchGameProvider.notifier).reset();
                  context.go('/');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A2A2A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Back to app',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) context.go('/');
    });
  }

  void _showTimerExpiredSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Time\'s up! The plane flew on to someone else.'),
        backgroundColor: Colors.deepPurple,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Color get _timerColor {
    if (_secondsLeft > 60) return const Color(0xFF4CAF50);
    if (_secondsLeft > 20) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _revealController.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(catchGameProvider).catchResult;
    if (result == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0C0C),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: ScaleTransition(
          scale: _scaleFade,
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF2E74), Color(0xFFFF6B35)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('✈️', style: TextStyle(fontSize: 22)),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${result.senderFirstName}, ${result.senderAge ?? '?'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '📍 ${result.senderCity.isNotEmpty ? result.senderCity : 'Unknown city'}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sticker badge
                    if (result.sticker.isNotEmpty)
                      Text(result.sticker,
                          style: const TextStyle(fontSize: 32)),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Message card ──
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFFF2E74).withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2E74).withOpacity(0.08),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '"',
                          style: TextStyle(
                            color: const Color(0xFFFF2E74).withOpacity(0.5),
                            fontSize: 64,
                            height: 0.8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            height: 1.6,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            '"',
                            style: TextStyle(
                              color: const Color(0xFFFF2E74).withOpacity(0.5),
                              fontSize: 64,
                              height: 0.8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Timer ──
              _CircularCountdown(
                secondsLeft: _secondsLeft,
                totalSeconds: 180,
                label: _timerLabel,
                color: _timerColor,
              ),

              const SizedBox(height: 28),

              // ── Action buttons ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    // PASS button
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: _isActing ? null : _onPass,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Colors.white24, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '❌  Pass',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // CONNECT button
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isActing ? null : _onConnect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF2E74),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor:
                                const Color(0xFFFF2E74).withOpacity(0.4),
                          ),
                          child: _isActing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  '✅  Connect',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Circular Countdown Widget ────────────────────────────────
class _CircularCountdown extends StatelessWidget {
  final int secondsLeft;
  final int totalSeconds;
  final String label;
  final Color color;

  const _CircularCountdown({
    required this.secondsLeft,
    required this.totalSeconds,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = secondsLeft / totalSeconds;
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                'to decide',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Connected Overlay ────────────────────────────────────────
class _ConnectedOverlay extends StatefulWidget {
  final String conversationId;
  final VoidCallback onOpenChat;

  const _ConnectedOverlay({
    required this.conversationId,
    required this.onOpenChat,
  });

  @override
  State<_ConnectedOverlay> createState() => _ConnectedOverlayState();
}

class _ConnectedOverlayState extends State<_ConnectedOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
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
        child: ConfettiConnectWidget(
          startTrigger: true,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFFF2E74).withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF2E74).withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 16),
                const Text(
                  'You\'re connected!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'A conversation has been opened.\nStart chatting!',
                  style:
                      TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.onOpenChat,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2E74),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Open Chat →',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
