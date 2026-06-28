import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/confession_request_model.dart';
import '../../models/message_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/confession_provider.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  final void Function(
    String conversationId,
    String otherUsername, {
    String? otherUserId,
  }) onOpenChat;

  const ConversationsScreen({super.key, required this.onOpenChat});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  String? _processingRequestId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) refreshChatData(ref);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _acceptRequest(ConfessionChatRequest request) async {
    if (_processingRequestId != null) return;
    setState(() => _processingRequestId = request.id);

    final result = await ref
        .read(confessionServiceProvider)
        .acceptRequest(request.id);

    if (!mounted) return;
    setState(() => _processingRequestId = null);

    if (result.success) {
      refreshChatData(ref);
      final convId = result.conversationId;
      if (convId != null && convId.isNotEmpty) {
        widget.onOpenChat(
          convId,
          request.senderUsername ?? 'User',
          otherUserId: request.senderId,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request accepted!', style: GoogleFonts.outfit()),
          backgroundColor: const Color(0xFF0C243B),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.error ?? 'Could not accept request.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFF1E1E1E),
        ),
      );
    }
  }

  Future<void> _rejectRequest(ConfessionChatRequest request) async {
    if (_processingRequestId != null) return;
    setState(() => _processingRequestId = request.id);

    final result = await ref
        .read(confessionServiceProvider)
        .rejectRequest(request.id);

    if (!mounted) return;
    setState(() => _processingRequestId = null);

    refreshChatData(ref);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Request declined.'
              : (result.error ?? 'Could not decline request.'),
          style: GoogleFonts.outfit(),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);
    final newMatches = ref.watch(newMatchesProvider);
    final confessionRequests = ref.watch(confessionRequestsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Text(
                    'Messages',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => refreshChatData(ref),
                    icon: const Icon(Icons.refresh_rounded,
                        color: Color(0xFF888888)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                'NEW MATCHES',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF555555),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: newMatches.when(
                data: (matchList) => matchList.isEmpty
                    ? Center(
                        child: Text(
                          'No new matches yet',
                          style: GoogleFonts.outfit(
                              color: const Color(0xFF555555), fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 24, right: 12),
                        itemCount: matchList.length,
                        itemBuilder: (_, i) => _MatchAvatar(
                          match: matchList[i],
                          onTap: () {
                            final m = matchList[i];
                            final convId = m.conversationId;
                            if (convId != null && convId.isNotEmpty) {
                              widget.onOpenChat(
                                convId,
                                m.matchedUsername ?? 'User',
                                otherUserId: m.matchedUserId,
                              );
                            }
                          },
                        ),
                      ),
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFFF2E74), strokeWidth: 2),
                ),
                error: (_, __) => Center(
                  child: TextButton(
                    onPressed: () => refreshChatData(ref),
                    child: Text(
                      'Could not load matches — tap to retry',
                      style: GoogleFonts.outfit(
                          color: const Color(0xFF555555), fontSize: 13),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(height: 1, color: const Color(0xFF1E1E1E)),
            ),
            Expanded(
              child: _buildMainContent(
                conversations,
                confessionRequests,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(
    AsyncValue<List<Conversation>> conversations,
    AsyncValue<List<ConfessionChatRequest>> confessionRequests,
  ) {
    if (conversations.isLoading && conversations.valueOrNull == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF2E74)),
      );
    }
    if (conversations.hasError && conversations.valueOrNull == null) {
      return _buildErrorState();
    }

    final activeConversations = conversations.valueOrNull ?? [];
    final requests = confessionRequests.valueOrNull ?? [];
    final requestsLoading =
        confessionRequests.isLoading && confessionRequests.valueOrNull == null;

    if (requests.isEmpty &&
        activeConversations.isEmpty &&
        !requestsLoading) {
      return _buildEmptyConversations();
    }

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      children: [
        if (requestsLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFFFF2E74),
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        if (requests.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
            child: Text(
              'CONFESSION CHAT REQUESTS',
              style: GoogleFonts.outfit(
                color: const Color(0xFF555555),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          ...requests.map(
            (req) => _ConfessionRequestCard(
              request: req,
              isProcessing: _processingRequestId == req.id,
              onAccept: () => _acceptRequest(req),
              onReject: () => _rejectRequest(req),
            ),
          ),
          if (activeConversations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 10),
              child: Container(height: 1, color: const Color(0xFF1E1E1E)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: Text(
                'CONVERSATIONS',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF555555),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ],
        ...activeConversations.map(
          (conv) => _ConversationTile(
            conversation: conv,
            onTap: () => widget.onOpenChat(
              conv.id,
              conv.otherUsername ?? 'User',
              otherUserId: conv.otherUserId,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyConversations() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💌', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Browse the feed and send someone a message!',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  color: const Color(0xFF888888), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Could not load messages',
              style: GoogleFonts.outfit(color: const Color(0xFF888888))),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => refreshChatData(ref),
            child: Text('Retry',
                style: GoogleFonts.outfit(color: const Color(0xFFFF2E74))),
          ),
        ],
      ),
    );
  }
}

class _ConfessionRequestCard extends StatelessWidget {
  final ConfessionChatRequest request;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _ConfessionRequestCard({
    required this.request,
    required this.isProcessing,
    required this.onAccept,
    required this.onReject,
  });

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final senderName = request.senderUsername ?? 'Someone';
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '🤫 Confession request',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFF2E74),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _timeAgo(request.createdAt),
                style: GoogleFonts.outfit(
                  color: const Color(0xFF555555),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF1E1E1E),
                child: Text(
                  senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFF2E74),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  senderName,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'From your confession:',
            style: GoogleFonts.outfit(
              color: const Color(0xFF666666),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '"${request.confessionText}"',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: const Color(0xFFAAAAAA),
              fontSize: 13,
              height: 1.45,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Their message:',
            style: GoogleFonts.outfit(
              color: const Color(0xFF666666),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '"${request.message}"',
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: const Color(0xFFEEEEEE),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: isProcessing ? null : onAccept,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF2E74),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Accept',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: isProcessing ? null : onReject,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Decline',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF888888),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MatchAvatar extends StatelessWidget {
  final Match match;
  final VoidCallback onTap;

  const _MatchAvatar({required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF2E74), Color(0xFFE91E63)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircleAvatar(
                  backgroundColor: const Color(0xFF1E1E1E),
                  backgroundImage: match.matchedAvatarUrl != null
                      ? CachedNetworkImageProvider(match.matchedAvatarUrl!)
                      : null,
                  child: match.matchedAvatarUrl == null
                      ? Text(
                          _initial(match.matchedUsername),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 56,
              child: Text(
                match.matchedUsername ?? 'User',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    color: const Color(0xFFAAAAAA), fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String? name) {
    if (name == null || name.isEmpty) return '?';
    return name[0].toUpperCase();
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF1E1E1E),
                backgroundImage: conversation.otherAvatarUrl != null
                    ? CachedNetworkImageProvider(conversation.otherAvatarUrl!)
                    : null,
                child: conversation.otherAvatarUrl == null
                    ? const Icon(Icons.person,
                        color: Colors.white70, size: 26)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.otherUsername ?? 'User',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: hasUnread
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      conversation.lastMessage?.content ??
                          'Tap to start chatting',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: hasUnread
                            ? Colors.white
                            : const Color(0xFF666666),
                        fontSize: 13,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasUnread)
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF2E74),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${conversation.unreadCount}',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}