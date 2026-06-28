import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/call_manager_provider.dart';
import '../../screens/chat/call_screen.dart';

class IncomingCallOverlay extends ConsumerWidget {
  const IncomingCallOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(callManagerProvider);
    if (call.uiState != CallUiState.incoming || call.incoming == null) {
      return const SizedBox.shrink();
    }

    final info = call.incoming!;
    return Material(
      color: Colors.black.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  info.callType == 'video'
                      ? Icons.videocam_rounded
                      : Icons.call_rounded,
                  color: const Color(0xFFFF2E74),
                  size: 56,
                ),
                const SizedBox(height: 20),
                Text(
                  'Incoming ${info.callType == 'video' ? 'video' : 'voice'} call',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  info.callerLabel,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFAAAAAA),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundBtn(
                      color: const Color(0xFFE53935),
                      icon: Icons.call_end,
                      onTap: () =>
                          ref.read(callManagerProvider.notifier).declineIncoming(),
                    ),
                    const SizedBox(width: 48),
                    _RoundBtn(
                      color: const Color(0xFF4CAF50),
                      icon: Icons.call,
                      onTap: () async {
                        await ref
                            .read(callManagerProvider.notifier)
                            .acceptIncoming();
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallScreen(
                              otherUserId: info.callerId,
                              otherUsername: info.callerLabel,
                              callType: info.callType,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _RoundBtn({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}