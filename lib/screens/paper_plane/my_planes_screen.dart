import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/paper_plane_model.dart';
import '../../providers/paper_plane_provider.dart';

// ─────────────────────────────────────────────────────────────
// My Planes Screen — sender sees all their planes + statuses
// ─────────────────────────────────────────────────────────────

class MyPlanesScreen extends ConsumerStatefulWidget {
  const MyPlanesScreen({super.key});

  @override
  ConsumerState<MyPlanesScreen> createState() => _MyPlanesScreenState();
}

class _MyPlanesScreenState extends ConsumerState<MyPlanesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(paperPlaneSenderProvider.notifier).loadMyPlanes());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paperPlaneSenderProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white70, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'My Planes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          // Launch new plane FAB in app bar
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => context.push('/paper-plane/compose'),
              icon: const Text('✈️'),
              label: const Text(
                'Launch',
                style: TextStyle(
                  color: Color(0xFFFF2E74),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: const Color(0xFFFF2E74),
        backgroundColor: const Color(0xFF1A1A1A),
        onRefresh: () =>
            ref.read(paperPlaneSenderProvider.notifier).loadMyPlanes(),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF2E74)))
            : state.planes.isEmpty
                ? _EmptyState(onLaunch: () => context.push('/paper-plane/compose'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: state.planes.length,
                    itemBuilder: (_, i) => _PlaneCard(
                      plane: state.planes[i],
                      onCancel: () => ref
                          .read(paperPlaneSenderProvider.notifier)
                          .cancel(state.planes[i].id),
                    ),
                  ),
      ),
    );
  }
}

// ─── Plane Card ───────────────────────────────────────────────
class _PlaneCard extends StatelessWidget {
  final PaperPlane plane;
  final VoidCallback onCancel;

  const _PlaneCard({required this.plane, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _borderColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status row ──
          Row(
            children: [
              _StatusBadge(status: plane.status),
              const Spacer(),
              if (plane.sticker.isNotEmpty)
                Text(plane.sticker, style: const TextStyle(fontSize: 20)),
              if (plane.isFlying) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _confirmCancel(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white38,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // ── Message preview ──
          Text(
            '"${plane.message}"',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          // ── Catch info / time remaining ──
          if (plane.isCaught && plane.catchInfo != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF059669).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    plane.catchInfo!.catcherCity != null
                        ? 'Caught by someone in ${plane.catchInfo!.catcherCity}'
                        : 'Caught!',
                    style: const TextStyle(
                        color: Color(0xFF4ADE80), fontSize: 13),
                  ),
                ],
              ),
            ),
          ] else if (plane.isFlying) ...[
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(
                  'Expires ${_timeUntil(plane.expiresAt)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.location_on_outlined,
                    color: Colors.white38, size: 14),
                const SizedBox(width: 4),
                Text(
                  'From ${plane.senderCity.isNotEmpty ? plane.senderCity : 'your location'}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color get _borderColor {
    switch (plane.status) {
      case PlaneStatus.flying:
        return const Color(0xFF2563EB);
      case PlaneStatus.caught:
        return const Color(0xFF059669);
      case PlaneStatus.expired:
        return Colors.white24;
      case PlaneStatus.cancelled:
        return Colors.red;
    }
  }

  String _timeUntil(DateTime dt) {
    final diff = dt.difference(DateTime.now());
    if (diff.isNegative) return 'soon';
    if (diff.inHours >= 1) return 'in ${diff.inHours}h';
    return 'in ${diff.inMinutes}m';
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Cancel plane?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your plane will stop flying and be recalled.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep flying',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onCancel();
            },
            child: const Text('Cancel it',
                style: TextStyle(color: Color(0xFFFF2E74))),
          ),
        ],
      ),
    );
  }
}

// ─── Status Badge ─────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final PlaneStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            _label,
            style: TextStyle(
              color: _color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String get _icon {
    switch (status) {
      case PlaneStatus.flying:
        return '✈️';
      case PlaneStatus.caught:
        return '🎉';
      case PlaneStatus.expired:
        return '⏰';
      case PlaneStatus.cancelled:
        return '✕';
    }
  }

  String get _label {
    switch (status) {
      case PlaneStatus.flying:
        return 'Flying';
      case PlaneStatus.caught:
        return 'Caught!';
      case PlaneStatus.expired:
        return 'Expired';
      case PlaneStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get _color {
    switch (status) {
      case PlaneStatus.flying:
        return const Color(0xFF60A5FA);
      case PlaneStatus.caught:
        return const Color(0xFF4ADE80);
      case PlaneStatus.expired:
        return Colors.white38;
      case PlaneStatus.cancelled:
        return Colors.red;
    }
  }

  Color get _bg {
    switch (status) {
      case PlaneStatus.flying:
        return const Color(0xFF2563EB).withOpacity(0.15);
      case PlaneStatus.caught:
        return const Color(0xFF059669).withOpacity(0.15);
      case PlaneStatus.expired:
        return Colors.white.withOpacity(0.05);
      case PlaneStatus.cancelled:
        return Colors.red.withOpacity(0.1);
    }
  }
}

// ─── Empty State ──────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onLaunch;

  const _EmptyState({required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✈️', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 20),
            const Text(
              'No planes in the air',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Launch a paper plane with a message.\nSomeone out there might catch it.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onLaunch,
              icon: const Text('✈️'),
              label: const Text('Launch your first plane'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2E74),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
