import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUsername;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUsername,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _chatService = ChatService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final msgs = await _chatService.getMessages(widget.conversationId);
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (_) {
      setState(() => _isLoading = false);
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

    try {
      final msg = await _chatService.sendMessage(widget.conversationId, text);
      setState(() {
        _messages.add(msg);
        _isSending = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isSending = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to send'),
              backgroundColor: const Color(0xFF1E1E1E)),
        );
      }
    }
  }

  bool _isMyMessage(Message msg) {
    return msg.senderId == (_myUserId ?? '');
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
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF1E1E1E),
              child: const Icon(Icons.person, color: Colors.white70, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUsername,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF1E1E1E)),
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFFF2E74)),
                  )
                : _messages.isEmpty
                    ? _buildEmptyChat()
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) =>
                            _MessageBubble(
                          message: _messages[i],
                          isMe: _isMyMessage(_messages[i]),
                        ),
                      ),
          ),
          // Input bar
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
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        border: Border(
          top: BorderSide(color: const Color(0xFF1E1E1E)),
        ),
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
                      color: const Color(0xFF555555), fontSize: 15),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
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
                  colors: [Color(0xFFFF2E74), Color(0xFFE91E63)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2E74).withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
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
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF1E1E1E),
              child:
                  const Icon(Icons.person, color: Colors.white70, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFFFF2E74)
                    : const Color(0xFF1E1E1E),
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
