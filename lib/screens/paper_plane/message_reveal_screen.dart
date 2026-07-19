import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/paper_plane_model.dart';
import '../../providers/paper_plane_provider.dart';
import '../../widgets/confetti_connect_widget.dart';
import 'sender_profile_sheet.dart';

class MessageRevealScreen extends ConsumerStatefulWidget {
  const MessageRevealScreen({super.key});

  @override
  ConsumerState<MessageRevealScreen> createState() => _MessageRevealScreenState();
}

class _MessageRevealScreenState extends ConsumerState<MessageRevealScreen>
    with TickerProviderStateMixin {
  // ── Circular countdown ──
  late Timer _timer;
  int _secondsLeft = 180; // 3 min — overridden by decisionDeadline from server
  bool _isActing = false;

  // ── Chili Reveal & Letter animations ──
  bool _chiliOpened = false;
  bool _showSuccessOverlay = false;
  bool _isFlyAwayAnimActive = false;

  late AnimationController _chiliSplitController;
  late Animation<double> _chiliSplitProgress;

  late AnimationController _pulseController;
  late AnimationController _vibrateController;
  late AnimationController _floatController;
  late AnimationController _flyAwayController;

  @override
  void initState() {
    super.initState();

    // Compute remaining seconds from server deadline
    final result = ref.read(catchGameProvider).catchResult;
    if (result != null) {
      final remaining = result.decisionDeadline.difference(DateTime.now());
      _secondsLeft = remaining.inSeconds.clamp(0, 180);
    }

    _startTimer();

    // ── Animation Controllers ──
    _chiliSplitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _chiliSplitProgress = CurvedAnimation(
      parent: _chiliSplitController,
      curve: Curves.easeOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _vibrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _flyAwayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
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
    setState(() => _isActing = true);
    _timer.cancel();
    HapticFeedback.heavyImpact();

    await ref.read(catchGameProvider.notifier).connect();
    if (!mounted) return;

    final state = ref.read(catchGameProvider);
    final convId = state.conversationId;
    if (state.phase == GamePhase.connected &&
        convId != null &&
        convId.isNotEmpty) {
      setState(() {
        _showSuccessOverlay = true;
      });
    } else {
      setState(() => _isActing = false);
      _startTimer(); // resume timer
      final err = state.error?.trim();
      final message = (err != null && err.isNotEmpty)
          ? err
          : 'Could not connect. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _onPass() async {
    if (_isActing) return;
    setState(() => _isActing = true);
    _timer.cancel();
    HapticFeedback.mediumImpact();

    setState(() {
      _isFlyAwayAnimActive = true;
    });

    _flyAwayController.forward().then((_) async {
      await ref.read(catchGameProvider.notifier).pass();
      if (mounted) {
        _showPassedSheet();
      }
    });
  }

  void _showPassedSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161616),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
      if (mounted) {
        ref.read(catchGameProvider.notifier).reset();
        context.go('/');
      }
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
    return '${_secondsLeft}s';
  }

  @override
  void dispose() {
    _timer.cancel();
    _chiliSplitController.dispose();
    _pulseController.dispose();
    _vibrateController.dispose();
    _floatController.dispose();
    _flyAwayController.dispose();
    super.dispose();
  }

  // ─── Sender header on the revealed message card ────────────────
  /// Renders the sender's avatar (real photo or initial), name, username,
  /// and location. Tapping opens the full SenderProfileSheet.
  Widget _buildSenderHeader(CatchResult result, BuildContext context) {
    final profile = result.senderProfile;
    final hasProfileSheet = profile != null;

    // Build the avatar widget
    Widget avatarWidget;
    final photoUrl = profile?.firstImageUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      avatarWidget = ClipOval(
        child: Image.network(
          photoUrl,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallbackAvatar(result.senderFirstName),
        ),
      );
    } else {
      avatarWidget = _fallbackAvatar(result.senderFirstName);
    }

    final username = profile?.username ?? '';
    final isOnline = profile?.isOnline ?? false;
    final isVerified = profile?.isVerified ?? false;

    final headerContent = Row(
      children: [
        // Avatar with optional online ring
        Stack(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isOnline
                      ? const Color(0xFF00E676)
                      : Colors.white.withOpacity(0.4),
                  width: 2.5,
                ),
              ),
              child: ClipOval(child: avatarWidget),
            ),
            if (isOnline)
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'A message from the sky',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF181C1F),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: Color(0xFF1A3AFF),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (username.isNotEmpty) '@$username',
                  '${result.senderFirstName}${result.senderAge != null ? ", ${result.senderAge}" : ""}',
                  if (result.senderCity.isNotEmpty) '📍 ${result.senderCity}',
                ].join(' · '),
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF40484F),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (hasProfileSheet)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    'Tap to view profile →',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFFFF8C61),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (result.sticker.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(result.sticker, style: const TextStyle(fontSize: 26)),
          ),
      ],
    );

    if (!hasProfileSheet) return headerContent;

    // Wrap with GestureDetector when profile data is available
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        SenderProfileSheet.show(
          context,
          profile: profile,
          deliveryId: result.deliveryId,
          onConnect: _isActing ? null : _onConnect,
          onPass: _isActing ? null : _onPass,
          isActing: _isActing,
        );
      },
      child: headerContent,
    );
  }

  Widget _fallbackAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFF8C61), Color(0xFFFF2E74)],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final gameState = ref.watch(catchGameProvider);
    final result = gameState.catchResult;

    if (result == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0C0C),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF2E74))),
      );
    }

    // Fly-away animations transformation details
    final double flyX = _flyAwayController.value * size.width;
    final double flyY = -_flyAwayController.value * size.height;
    final double flyScale = 1.0 - _flyAwayController.value * 0.9;
    final double flyRotation = _flyAwayController.value * 0.8;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: Stack(
        children: [
          // ── Background Atmospheric Layer ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF0A0A1A),
                    Color(0xFF140E2A),
                    Color(0xFF261033),
                  ],
                ),
              ),
            ),
          ),

          // Cosmic Sky Lights overlay
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Image.network(
                'https://www.transparenttextures.com/patterns/dust.png',
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),

          // ── App Header ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      onPressed: () {
                        if (!_chiliOpened) {
                          context.go('/');
                        } else {
                          _onPass();
                        }
                      },
                    ),
                    Text(
                      'Paper Planes',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 48), // Spacer to balance
                  ],
                ),
              ),
            ),
          ),

          // ── Main Content Area ──
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),

                // ── Progress countdown ──
                if (_chiliOpened) ...[
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: _secondsLeft / 180.0,
                          strokeWidth: 3.5,
                          backgroundColor: Colors.white.withOpacity(0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8C61)),
                        ),
                        Text(
                          _timerLabel,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'EXPIRES SOON',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Centered Card / Chili View ──
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _chiliSplitController,
                          _pulseController,
                          _floatController,
                          _flyAwayController
                        ]),
                        builder: (context, _) {
                          if (!_chiliOpened) {
                            // Pulsing closed chili state
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Transform.scale(
                                  scale: 1.0 + 0.05 * _pulseController.value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.35 * _pulseController.value),
                                          blurRadius: 40,
                                          spreadRadius: 10,
                                        ),
                                      ],
                                    ),
                                    child: const Text('🌶️', style: TextStyle(fontSize: 96)),
                                  ),
                                ),
                                const SizedBox(height: 40),
                                ElevatedButton(
                                  onPressed: () {
                                    HapticFeedback.heavyImpact();
                                    _vibrateController.repeat(max: 1.0);
                                    Future.delayed(const Duration(milliseconds: 300), () {
                                      _vibrateController.stop();
                                      _chiliSplitController.forward().then((_) {
                                        setState(() => _chiliOpened = true);
                                      });
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF2E74),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                                    elevation: 10,
                                    shadowColor: const Color(0xFFFF2E74).withOpacity(0.4),
                                  ),
                                  child: Text(
                                    '🔥 Open Chili',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }

                          // Split Chili halves flying apart before fully open
                          if (_chiliSplitController.value < 1.0) {
                            final splitVal = _chiliSplitProgress.value;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.translate(
                                  offset: Offset(-80 * splitVal, 0),
                                  child: Transform.rotate(
                                    angle: -0.2 * splitVal,
                                    child: const Text('🌶️', style: TextStyle(fontSize: 96)),
                                  ),
                                ),
                                Transform.translate(
                                  offset: Offset(80 * splitVal, 0),
                                  child: Transform.rotate(
                                    angle: 0.2 * splitVal,
                                    child: const Text('🌶️', style: TextStyle(fontSize: 96)),
                                  ),
                                ),
                              ],
                            );
                          }

                          // Revealed paper letter with slight tilt and floating action
                          final double floatVal = math.sin(_floatController.value * 2 * math.pi) * 8;
                          
                          return Transform.translate(
                            offset: Offset(floatVal + (isClosed ? 0 : flyX), floatVal + (isClosed ? 0 : flyY)),
                            child: Transform.scale(
                              scale: isClosed ? 1.0 : flyScale,
                              child: Transform.rotate(
                                angle: -0.02 + (isClosed ? 0 : flyRotation),
                                child: Container(
                                  width: math.min(size.width * 0.9, 440),
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.18),
                                        blurRadius: 40,
                                        offset: const Offset(0, 15),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // ── Sender Header — tappable to open full profile ──
                                      _buildSenderHeader(result, context),
                                      const SizedBox(height: 24),
                                      Container(
                                        height: 1,
                                        color: const Color(0xFFE0E3E7).withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 24),

                                      // The Message Text
                                      Stack(
                                        children: [
                                          Opacity(
                                            opacity: 0.08,
                                            child: Text(
                                              '“',
                                              style: GoogleFonts.plusJakartaSans(
                                                color: const Color(0xFF00658f),
                                                fontSize: 64,
                                                fontWeight: FontWeight.w800,
                                                height: 0.8,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 8, left: 8),
                                            child: Text(
                                              result.message,
                                              style: GoogleFonts.plusJakartaSans(
                                                color: const Color(0xFF181C1F).withOpacity(0.95),
                                                fontSize: 17,
                                                height: 1.6,
                                                fontStyle: FontStyle.italic,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 32),

                                      // Grayscale eco illustration at the bottom right
                                      Align(
                                        alignment: Alignment.bottomRight,
                                        child: Opacity(
                                          opacity: 0.05,
                                          child: Icon(
                                            Icons.eco,
                                            size: 64,
                                            color: const Color(0xFF181C1F),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // ── Lower Action Buttons Area ──
                if (_chiliOpened) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Primary: Connect Button
                        Container(
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF8C61), Color(0xFFFF5C00)],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF5C00).withOpacity(0.35),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isActing ? null : _onConnect,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _isActing
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.favorite_rounded, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        '❤️ Connect',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Secondary: Let it Fly Away Button
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: TextButton(
                            onPressed: _isActing ? null : _onPass,
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                                side: BorderSide(color: Colors.white.withOpacity(0.15)),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '✈️ Let it Fly Away',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 160), // spacer balance
                ]
              ],
            ),
          ),

          // ── Connection Success Overlay ──
          if (_showSuccessOverlay)
            Positioned.fill(
              child: ConfettiConnectWidget(
                startTrigger: true,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF8C61), Color(0xFFFFD700)],
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 96, color: Colors.white),
                        const SizedBox(height: 24),
                        Text(
                          "It's a Connection!",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 48),
                          child: Text(
                            "Your paper plane has landed safely. Start the conversation now.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: () {
                                final state = ref.read(catchGameProvider);
                                ref.read(catchGameProvider.notifier).reset();
                                if (state.conversationId != null) {
                                  context.go('/chat/${state.conversationId}');
                                } else {
                                  context.go('/');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFFF5C00),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                elevation: 5,
                              ),
                              child: Text(
                                'Open Chat →',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
      ),
    );
  }

  bool get isClosed => !_isFlyAwayAnimActive;
}
