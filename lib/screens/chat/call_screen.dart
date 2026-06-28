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

  Future<void> _hangUp() async {
    await ref.read(callManagerProvider.notifier).hangUp();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final call = ref.watch(callManagerProvider);
    final isVideo = widget.callType == 'video';

    if (_renderersReady) {
      _localRenderer.srcObject = call.localStream;
      _remoteRenderer.srcObject = call.remoteStream;
    }

    ref.listen<CallManagerState>(callManagerProvider, (prev, next) {
      if (next.uiState == CallUiState.idle && prev?.uiState != CallUiState.idle) {
        if (mounted) Navigator.pop(context);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Stack(
          children: [
            if (isVideo && call.remoteStream != null)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: isVideo ? 0.35 : 0.9),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              children: [
                const SizedBox(height: 24),
                Text(
                  widget.otherUsername,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  call.statusMessage ?? 'Connecting…',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFAAAAAA),
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (isVideo && call.localStream != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(right: 20, bottom: 20),
                      width: 110,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF333333)),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: RTCVideoView(
                        _localRenderer,
                        mirror: true,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: _hangUp,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call_end, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ],
        ),
      ),
    );
  }
}