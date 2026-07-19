import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/call_manager_provider.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String otherUserId;
  final String otherUsername;
  final String callType;

  const CallScreen({
    super.key,
    required this.otherUserId,
    required this.otherUsername,
    required this.callType,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;
  bool _didPop = false;

  // Track position for draggable local camera view in video calls
  Offset _localVideoOffset = const Offset(20, 20); // offset from bottom-right

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (mounted) setState(() => _renderersReady = true);
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  void _popOnce() {
    if (_didPop || !mounted) return;
    _didPop = true;
    Navigator.of(context).pop();
  }

  Future<void> _hangUp() async {
    await ref.read(callManagerProvider.notifier).hangUp();
    _popOnce();
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callManagerProvider);
    final isVideo = widget.callType.toLowerCase() == 'video' ||
        widget.callType.toUpperCase() == 'VIDEO';

    if (_renderersReady) {
      _localRenderer.srcObject = call.localStream;
      _remoteRenderer.srcObject = call.remoteStream;
    }

    ref.listen<CallManagerState>(callManagerProvider, (prev, next) {
      if (next.uiState == CallUiState.idle && prev?.uiState != CallUiState.idle) {
        _popOnce();
      }
    });

    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF070709),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Background Stream / Graphic ──
            if (isVideo && call.remoteStream != null)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              // Audio wave layout or fallback graphic
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0F0F16),
                        Color(0xFF09090C),
                      ],
                    ),
                  ),
                  child: _PulsingAudioWaves(username: widget.otherUsername),
                ),
              ),

            // Semi-transparent gradient overlay for readability of text and buttons
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: isVideo ? 0.3 : 0.0),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),

            // ── Top Header (Username & Connection Status) ──
            Positioned(
              top: 32,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Text(
                    widget.otherUsername,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                    ),
                    child: Text(
                      call.statusMessage ?? 'Connecting…',
                      style: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFCCCCCC),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Floating Local Video Overlay (Draggable, Video Calls Only) ──
            if (isVideo && call.localStream != null)
              Positioned(
                right: _localVideoOffset.dx,
                bottom: _localVideoOffset.dy + 100, // keep clear of the controls bar
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      // Adjust offset ensuring it stays inside bounds
                      final newX = (_localVideoOffset.dx - details.delta.dx)
                          .clamp(16.0, screenSize.width - 150.0);
                      final newY = (_localVideoOffset.dy - details.delta.dy)
                          .clamp(16.0, screenSize.height - 280.0);
                      _localVideoOffset = Offset(newX, newY);
                    });
                  },
                  child: Container(
                    width: 110,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2A2A2E), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: call.isVideoOff
                        ? Container(
                            color: const Color(0xFF1E1E1E),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 28),
                                SizedBox(height: 6),
                                Text(
                                  'Camera Off',
                                  style: TextStyle(color: Colors.white38, fontSize: 10),
                                ),
                              ],
                            ),
                          )
                        : RTCVideoView(
                            _localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                  ),
                ),
              ),

            // ── Bottom Action Controls Bar ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Mute / Unmute Button
                  _buildCallButton(
                    icon: call.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: call.isMuted ? const Color(0xFFE53935) : Colors.white.withValues(alpha: 0.15),
                    iconColor: call.isMuted ? Colors.white : Colors.white,
                    onTap: () {
                      ref.read(callManagerProvider.notifier).toggleMute();
                    },
                    tooltip: call.isMuted ? 'Unmute' : 'Mute',
                  ),
                  const SizedBox(width: 24),

                  // End Call / Hang Up Button (Enlarged & Red)
                  GestureDetector(
                    onTap: _hangUp,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x60E53935),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Video Toggle Camera Button (Video Calls Only)
                  if (isVideo)
                    _buildCallButton(
                      icon: call.isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      color: call.isVideoOff ? const Color(0xFFE53935) : Colors.white.withValues(alpha: 0.15),
                      iconColor: call.isVideoOff ? Colors.white : Colors.white,
                      onTap: () {
                        ref.read(callManagerProvider.notifier).toggleVideo();
                      },
                      tooltip: call.isVideoOff ? 'Turn Video On' : 'Turn Video Off',
                    )
                  else
                    // Placeholder spacing for visual symmetry in voice calls
                    const SizedBox(width: 56),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Icon(icon, color: iconColor, size: 24),
      ),
    );
  }
}

// ─── Pulsing concentric audio waves for voice call visualizer ────────────────────────
class _PulsingAudioWaves extends StatefulWidget {
  final String username;
  const _PulsingAudioWaves({required this.username});

  @override
  State<_PulsingAudioWaves> createState() => _PulsingAudioWavesState();
}

class _PulsingAudioWavesState extends State<_PulsingAudioWaves>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?';
    return Center(
      child: SizedBox(
        width: 320,
        height: 320,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 3 Concentric pulsing rings
            for (double i = 0; i < 3; i++)
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final progress = (_controller.value + i / 3.0) % 1.0;
                  final opacity = (1.0 - progress) * 0.35;
                  final scale = 1.0 + progress * 1.6;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFFF2E74).withValues(alpha: opacity),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2E74).withValues(alpha: opacity * 0.15),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            // Central Avatar Sphere
            Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF2E74), Color(0xFFFF5C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2E74).withValues(alpha: 0.35),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
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