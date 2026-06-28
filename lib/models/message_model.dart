// ─── Message Models ──────────────────────────────────────────

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String? senderUsername;
  final String content;
  final String? mediaUrl;
  final String? messageType; // text, image, voice
  final bool isSeen;
  final bool isMe;
  final DateTime? deliveredAt;
  final String? reaction;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.senderUsername,
    required this.content,
    this.mediaUrl,
    this.messageType,
    this.isSeen = false,
    this.isMe = false,
    this.deliveredAt,
    this.reaction,
    required this.createdAt,
  });

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderUsername,
    String? content,
    String? mediaUrl,
    String? messageType,
    bool? isSeen,
    bool? isMe,
    DateTime? deliveredAt,
    String? reaction,
    DateTime? createdAt,
  }) =>
      Message(
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        senderId: senderId ?? this.senderId,
        senderUsername: senderUsername ?? this.senderUsername,
        content: content ?? this.content,
        mediaUrl: mediaUrl ?? this.mediaUrl,
        messageType: messageType ?? this.messageType,
        isSeen: isSeen ?? this.isSeen,
        isMe: isMe ?? this.isMe,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        reaction: reaction ?? this.reaction,
        createdAt: createdAt ?? this.createdAt,
      );

  static String _parseContent(dynamic raw) {
    if (raw is String) return raw;
    if (raw is Map) {
      return raw['text']?.toString() ??
          raw['url']?.toString() ??
          raw['caption']?.toString() ??
          '';
    }
    return '';
  }

  static String _parseSenderId(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) return raw['id']?.toString() ?? '';
    return raw.toString();
  }

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id']?.toString() ?? '',
        conversationId: json['conversation']?.toString() ?? '',
        senderId: _parseSenderId(json['sender']),
        senderUsername: json['sender_username'] ?? json['sender_name'],
        content: _parseContent(json['content'] ?? json['text']),
        mediaUrl: json['media_url'] ?? json['media'],
        messageType: json['message_type'] ?? 'text',
        isSeen: json['is_seen'] ?? json['seen'] ?? false,
        isMe: json['is_me'] == true,
        deliveredAt: DateTime.tryParse(json['delivered_at']?.toString() ?? ''),
        reaction: json['reaction'],
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      );
}

class Conversation {
  final String id;
  final List<String> participantIds;
  final List<String> participantUsernames;
  final Message? lastMessage;
  final int unreadCount;
  final DateTime? updatedAt;
  // The other user's info (populated client-side or by backend)
  final String? otherUserId;
  final String? otherUsername;
  final String? otherAvatarUrl;

  Conversation({
    required this.id,
    required this.participantIds,
    required this.participantUsernames,
    this.lastMessage,
    this.unreadCount = 0,
    this.updatedAt,
    this.otherUserId,
    this.otherUsername,
    this.otherAvatarUrl,
  });

  static Map<String, dynamic>? _otherUserMap(Map<String, dynamic> json) {
    final raw = json['other_user'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final other = _otherUserMap(json);
    return Conversation(
      id: json['id']?.toString() ?? '',
      participantIds: (json['participants'] as List<dynamic>? ?? [])
          .map((p) => p.toString())
          .toList(),
      participantUsernames:
          (json['participant_usernames'] as List<dynamic>? ?? [])
              .map((p) => p.toString())
              .toList(),
      lastMessage: json['last_message'] != null
          ? Message.fromJson(
              Map<String, dynamic>.from(json['last_message'] as Map),
            )
          : null,
      unreadCount: json['unread_count'] ?? 0,
      updatedAt: DateTime.tryParse(
        json['updated_at'] ?? json['last_message_at'] ?? '',
      ),
      otherUserId:
          json['other_user_id']?.toString() ?? other?['id']?.toString(),
      otherUsername:
          json['other_username']?.toString() ?? other?['username']?.toString(),
      otherAvatarUrl: json['other_avatar_url']?.toString() ??
          other?['avatar_url']?.toString(),
    );
  }
}

class Match {
  final String id;
  final String userId;
  final String matchedUserId;
  final String? matchedUsername;
  final String? matchedAvatarUrl;
  final String? conversationId;
  final DateTime? matchedAt;
  final bool hasConversation;

  Match({
    required this.id,
    required this.userId,
    required this.matchedUserId,
    this.matchedUsername,
    this.matchedAvatarUrl,
    this.conversationId,
    this.matchedAt,
    this.hasConversation = false,
  });

  static Map<String, dynamic>? _otherUserMap(Map<String, dynamic> json) {
    final raw = json['other_user'] ?? json['matched_user_data'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  factory Match.fromJson(Map<String, dynamic> json) {
    final other = _otherUserMap(json);
    return Match(
      id: json['id']?.toString() ?? '',
      userId: json['user']?.toString() ?? '',
      matchedUserId: other?['id']?.toString() ??
          json['matched_user']?.toString() ??
          json['matched_user_id']?.toString() ??
          '',
      matchedUsername: other?['username']?.toString() ??
          json['matched_username']?.toString(),
      matchedAvatarUrl: other?['avatar_url']?.toString() ??
          json['matched_avatar_url']?.toString(),
      conversationId: json['conversation_id']?.toString(),
      matchedAt: DateTime.tryParse(
        json['matched_at']?.toString() ?? json['created_at']?.toString() ?? '',
      ),
      hasConversation:
          json['has_conversation'] == true || json['conversation_id'] != null,
    );
  }
}
