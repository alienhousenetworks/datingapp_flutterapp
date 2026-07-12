import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/paper_plane_provider.dart';
import '../../models/paper_plane_model.dart';
import 'compose_screen.dart';
import 'catch_game_screen.dart';
import 'message_reveal_screen.dart';
import 'my_planes_screen.dart';

// ─────────────────────────────────────────────────────────────
// Paper Plane Hub Screen
// Entry point — two sections:
//   1. Inbox (recipient side) — any active incoming delivery
//   2. My Planes (sender side) — planes you have launched
// ─────────────────────────────────────────────────────────────

class PaperPlaneHubScreen extends ConsumerStatefulWidget {
  const PaperPlaneHubScreen({super.key});

  @override
  ConsumerState<PaperPlaneHubScreen> createState() =>
      _PaperPlaneHubScreenState();
}

class _PaperPlaneHubScreenState extends ConsumerState<PaperPlaneHubScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(catchGameProvider.notifier).checkInbox();
      ref.read(paperPlaneSenderProvider.notifier).loadMyPlanes();
    });
  }

  void _pushScreen(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _launchCompose() => _pushScreen(const PaperPlaneComposeScreen());

  void _openCatchGame(PlaneDelivery delivery) async {
    // Start the game session first
    await ref.read(catchGameProvider.notifier).startGame();
    if (!mounted) return;

    final phase = ref.read(catchGameProvider).phase;
    if (phase == GamePhase.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start game. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _pushScreen(const CatchGameScreen());
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(catchGameProvider);
    final senderState = ref.watch(paperPlaneSenderProvider);

    final hasIncoming = gameState.delivery != null && gameState.delivery!.isActionable;
    final flyingCount = senderState.flyingCount;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            backgroundColor: const Color(0xFF0C0C0C),
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white70, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              '✈️  Paper Plane',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero Description ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1A0A2E), Color(0xFF0D1A3E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFF2E74).withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Write. Fold. Fly.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Send a message into the world.\nSomeone unexpected might catch it.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _launchCompose,
                            icon: const Text('✈️',
                                style: TextStyle(fontSize: 18)),
                            label: const Text(
                              'Launch a Paper Plane',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF2E74),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Incoming Plane (Recipient) ──
                  const SizedBox(height: 28),
                  const _SectionTitle(text: 'Incoming Plane'),
                  const SizedBox(height: 12),
                  if (!hasIncoming)
                    _EmptyInboxCard()
                  else
                    _IncomingPlaneCard(
                      delivery: gameState.delivery!,
                      phase: gameState.phase,
                      onCatch: () => _openCatchGame(gameState.delivery!),
                      onReveal: () => _pushScreen(const MessageRevealScreen()),
                    ),

                  // ── My Planes (Sender) ──
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionTitle(text: 'My Planes'),
                      if (flyingCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2563EB).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$flyingCount flying',
                            style: const TextStyle(
                              color: Color(0xFF60A5FA),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Preview of the latest 2 planes
                  if (senderState.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF2E74),
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else if (senderState.planes.isEmpty)
                    _NoPlanesSent()
                  else ...[
                    ...senderState.planes.take(2).map(
                          (p) => _MiniPlaneCard(plane: p),
                        ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () =>
                            _pushScreen(const MyPlanesScreen()),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Colors.white12, width: 1),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'View all ${senderState.planes.length} planes →',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Incoming Plane Card ──────────────────────────────────────
class _IncomingPlaneCard extends StatelessWidget {
  final PlaneDelivery delivery;
  final GamePhase phase;
  final VoidCallback onCatch;
  final VoidCallback onReveal;

  const _IncomingPlaneCard({
    required this.delivery,
    required this.phase,
    required this.onCatch,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    final isPending =
        phase == GamePhase.notified || phase == GamePhase.catching;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF2E74).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF2E74).withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          // Animated plane icon
          _AnimatedPlaneIcon(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A plane landed for you!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  delivery.senderCity.isNotEmpty
                      ? 'From ${delivery.senderCity}'
                      : 'From somewhere in the world',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                if (delivery.sticker.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(delivery.sticker,
                      style: const TextStyle(fontSize: 20)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          // CTA
          GestureDetector(
            onTap: phase == GamePhase.revealed ? onReveal : onCatch,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF2E74),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                phase == GamePhase.revealed ? 'Open' : 'Catch!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedPlaneIcon extends StatefulWidget {
  @override
  State<_AnimatedPlaneIcon> createState() => _AnimatedPlaneIconState();
}

class _AnimatedPlaneIconState extends State<_AnimatedPlaneIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _wobble;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _wobble = Tween<double>(begin: -0.05, end: 0.05).animate(
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
      animation: _wobble,
      builder: (_, __) => Transform.rotate(
        angle: _wobble.value,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFF2E74).withOpacity(0.2),
                const Color(0xFFFF6B35).withOpacity(0.2),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('✈️', style: TextStyle(fontSize: 26)),
          ),
        ),
      ),
    );
  }
}

// ─── Mini Plane Card (preview) ────────────────────────────────
class _MiniPlaneCard extends StatelessWidget {
  final PaperPlane plane;

  const _MiniPlaneCard({required this.plane});

  @override
  Widget build(BuildContext context) {
    final isFlying = plane.status == PlaneStatus.flying;
    final isCaught = plane.status == PlaneStatus.caught;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCaught
              ? const Color(0xFF059669).withOpacity(0.3)
              : isFlying
                  ? const Color(0xFF2563EB).withOpacity(0.3)
                  : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Text(
            isFlying
                ? '✈️'
                : isCaught
                    ? '🎉'
                    : '⏰',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '"${plane.message}"',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.4),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            plane.status.name[0].toUpperCase() +
                plane.status.name.substring(1),
            style: TextStyle(
              color: isCaught
                  ? const Color(0xFF4ADE80)
                  : isFlying
                      ? const Color(0xFF60A5FA)
                      : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _EmptyInboxCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Row(
        children: [
          Text('🌍', style: TextStyle(fontSize: 28)),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No planes yet',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 3),
                Text(
                  'Someone\'s plane might land here anytime.',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPlanesSent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: const Text(
        'You haven\'t launched any planes yet.',
        style: TextStyle(color: Colors.white38, fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}
