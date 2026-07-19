import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/call_manager_provider.dart';
import '../../services/chat_websocket.dart';
import 'call_screen.dart';
import '../profile/other_profile_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUsername;
  final String? otherUserId;
  final VoidCallback? onBack;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUsername,
    this.otherUserId,
    this.onBack,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _chatWs = ChatWebSocket();

  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _myUserId;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    await _resolveMyUserId();
    await _loadMessages();
    await _connectWebSocket();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _loadMessages(silent: true);
    });
  }

  Future<void> _connectWebSocket() async {
    final chatService = ref.read(chatServiceProvider);
    await _chatWs.connect(
      conversationId: widget.conversationId,
      ticketProvider: chatService.getWsTicket,
      onMessage: _onWsMessage,
    );
  }

  Future<void> _resolveMyUserId() async {
    var profile = ref.read(profileProvider).profile;
    if (profile == null) {
      await ref.read(profileProvider.notifier).loadProfile();
      profile = ref.read(profileProvider).profile;
    }
    if (profile?.id.isNotEmpty == true) {
      _myUserId = profile!.id;
      return;
    }
    final session = await ref.read(profileServiceProvider).getAuthSession();
    final sessionUserId = session['user_id']?.toString() ??
        session['id']?.toString() ??
        session['user']?.toString();
    if (sessionUserId != null && sessionUserId.isNotEmpty) {
      _myUserId = sessionUserId;
    }
  }

  void _onWsMessage(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    if (type == '_reconnected') {
      _loadMessages(silent: true);
      return;
    }
    if (type == 'message_update') {
      final messageId = data['message_id']?.toString();
      if (messageId == null || messageId.isEmpty) return;
      setState(() {
        _messages = _messages
            .map(
              (m) => m.id == messageId
                  ? m.copyWith(
                      isSeen: data['is_seen'] == true ? true : m.isSeen,
                    )
                  : m,
            )
            .toList();
      });
      return;
    }
    if (type != 'message') return;

    final msg = Message.fromJson(data);
    if (msg.id.isEmpty) return;

    final isMine = _isMyMessage(msg);

    if (!isMine && !msg.isSeen) {
      ref.read(chatServiceProvider).markSeen(msg.id);
    }

    setState(() {
      if (_messages.any((m) => m.id == msg.id)) {
        _messages = _messages
            .map((m) => m.id == msg.id ? msg.copyWith(isMe: isMine) : m)
            .toList();
      } else {
        final optIdx = _messages.indexWhere(
          (m) => m.id.startsWith('temp-') && m.content == msg.content && isMine,
        );
        if (optIdx != -1) {
          final updated = List<Message>.from(_messages);
          updated[optIdx] = msg.copyWith(isMe: true);
          _messages = updated;
        } else {
          _messages = [..._messages, msg.copyWith(isMe: isMine)];
        }
      }
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _chatWs.disconnect();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    try {
      final msgs =
          await ref.read(chatServiceProvider).getMessages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        if (!silent) _isLoading = false;
      });
      for (final msg in msgs) {
        if (!_isMyMessage(msg) && !msg.isSeen) {
          ref.read(chatServiceProvider).markSeen(msg.id);
        }
      }
      _scrollToBottom();
    } catch (_) {
      if (!silent && mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    _msgCtrl.clear();
    setState(() => _isSending = true);

    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = Message(
      id: tempId,
      conversationId: widget.conversationId,
      senderId: _myUserId ?? '',
      content: text,
      isMe: true,
      createdAt: DateTime.now(),
    );
    setState(() => _messages = [..._messages, optimistic]);
    _scrollToBottom();

    try {
      final msg = await ref
          .read(chatServiceProvider)
          .sendMessage(widget.conversationId, text);
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .map((m) => m.id == tempId ? msg.copyWith(isMe: true) : m)
            .toList();
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages = _messages.where((m) => m.id != tempId).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send', style: GoogleFonts.outfit()),
            backgroundColor: const Color(0xFF1E1E1E),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  bool _isMyMessage(Message msg) {
    if (msg.isMe) return true;
    if (_myUserId != null && msg.senderId.isNotEmpty) {
      return msg.senderId == _myUserId;
    }
    return msg.id.startsWith('temp-');
  }

  void _handleBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<String?> _resolveOtherUserId() async {
    if (widget.otherUserId != null && widget.otherUserId!.isNotEmpty) {
      return widget.otherUserId;
    }
    try {
      final conversations = await ref.read(chatServiceProvider).getConversations();
      for (final conv in conversations) {
        if (conv.id == widget.conversationId) {
          return conv.otherUserId;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _startCall(String callType) async {
    try {
      final otherId = await _resolveOtherUserId();
      if (otherId == null || otherId.isEmpty) {
        if (!mounted) return;
        _showCallSnack('Cannot start call — user id unavailable.');
        return;
      }

      final result = await ref.read(callManagerProvider.notifier).startOutgoingCall(
            calleeId: otherId,
            calleeLabel: widget.otherUsername,
            callType: callType,
          );

      if (!mounted) return;

      if (!result.success) {
        _showCallSnack(result.error ?? 'Could not start call.');
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallScreen(
            otherUserId: otherId,
            otherUsername: widget.otherUsername,
            callType: callType,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showCallSnack('Call failed: $e');
    }
  }

  void _showCallSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
    );
  }

  Future<void> _viewOtherProfile() async {
    final otherId = await _resolveOtherUserId();
    if (otherId == null || otherId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot open profile — user ID is missing.', style: GoogleFonts.outfit()),
          backgroundColor: const Color(0xFF1E1E1E),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtherProfileScreen(userId: otherId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C0C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: _handleBack,
        ),
        title: GestureDetector(
          onTap: _viewOtherProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFF1E1E1E),
                child: Icon(Icons.person, color: Colors.white70, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.otherUsername,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Voice call',
            onPressed: () => _startCall('voice'),
            icon: const Icon(Icons.call_rounded, color: Color(0xFFCCCCCC)),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: () => _startCall('video'),
            icon: const Icon(Icons.videocam_rounded, color: Color(0xFFCCCCCC)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF1E1E1E)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF2E74)),
                  )
                : _messages.isEmpty
                    ? _buildEmptyChat()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _MessageBubble(
                          message: _messages[i],
                          isMe: _isMyMessage(_messages[i]),
                        ),
                      ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👋', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Say hello to ${widget.otherUsername}!',
            style: GoogleFonts.outfit(
              color: const Color(0xFF888888),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F12),
        border: Border(top: BorderSide(color: Color(0xFF1E1E24), width: 1.2)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2E2E36), width: 1.2),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF55555C),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF2E74), Color(0xFFFF5C00)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2E74).withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              alignment: Alignment.center,
              child: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final tickColor = message.isSeen
        ? const Color(0xFF53BDEB)
        : Colors.white.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF1E1E24),
              child: Icon(Icons.person, color: Colors.white70, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFFFF2E74), Color(0xFFFF5C00)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : const Color(0xFF1E1E24),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(
                  color: isMe
                      ? const Color(0xFFFF2E74).withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.05),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: GoogleFonts.plusJakartaSans(
                      color: isMe ? Colors.white : const Color(0xFFDDDDDD),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.createdAt),
                          style: GoogleFonts.plusJakartaSans(
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.7)
                                : const Color(0xFF7C7C86),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          if (message.id.startsWith('temp-'))
                            Icon(
                              Icons.access_time,
                              size: 13,
                              color: Colors.white.withValues(alpha: 0.75),
                            )
                          else if (message.isSeen)
                            Icon(Icons.done_all, size: 15, color: tickColor)
                          else if (message.deliveredAt != null)
                            Icon(
                              Icons.done_all,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.75),
                            )
                          else
                            Icon(
                              Icons.done,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}