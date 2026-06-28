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

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUsername;
  final String? otherUserId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUsername,
    this.otherUserId,
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
    final profile = ref.read(profileProvider).profile;
    _myUserId = profile?.id;

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

  void _onWsMessage(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    if (type == '_reconnected') {
      _loadMessages(silent: true);
      return;
    }
    if (type != 'message') return;

    final msg = Message.fromJson(data);
    if (msg.id.isEmpty) return;

    final isMine = data['is_me'] == true ||
        (msg.senderId.isNotEmpty &&
            _myUserId != null &&
            msg.senderId == _myUserId);

    if (!isMine && !msg.isSeen) {
      ref.read(chatServiceProvider).markSeen(msg.id);
    }

    setState(() {
      if (_messages.any((m) => m.id == msg.id)) {
        _messages = _messages
            .map((m) => m.id == msg.id ? msg : m)
            .toList();
      } else {
        // Replace optimistic temp message from same sender text
        final optIdx = _messages.indexWhere(
          (m) => m.id.startsWith('temp-') && m.content == msg.content && isMine,
        );
        if (optIdx != -1) {
          final updated = List<Message>.from(_messages);
          updated[optIdx] = msg;
          _messages = updated;
        } else {
          _messages = [..._messages, msg];
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
        _messages = _messages.map((m) => m.id == tempId ? msg : m).toList();
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
    if (_myUserId != null && msg.senderId.isNotEmpty) {
      return msg.senderId == _myUserId;
    }
    return msg.id.startsWith('temp-');
  }

  void _startCall(String callType) {
    final otherId = widget.otherUserId;
    if (otherId == null || otherId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cannot start call — user id unavailable.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFF1E1E1E),
        ),
      );
      return;
    }
    ref.read(callManagerProvider.notifier).startOutgoingCall(
          calleeId: otherId,
          calleeLabel: widget.otherUsername,
          callType: callType,
        );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallScreen(
          otherUserId: otherId,
          otherUsername: widget.otherUsername,
          callType: callType,
        ),
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
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
        color: Color(0xFF0C0C0C),
        border: Border(top: BorderSide(color: Color(0xFF1E1E1E))),
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
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: GoogleFonts.outfit(
                    color: const Color(0xFF555555),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
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
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF2E74), Color(0xFFE91E63)],
                ),
                shape: BoxShape.circle,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF1E1E1E),
              child: Icon(Icons.person, color: Colors.white70, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFFF2E74) : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Text(
                message.content,
                style: GoogleFonts.outfit(
                  color: isMe ? Colors.white : const Color(0xFFCCCCCC),
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}