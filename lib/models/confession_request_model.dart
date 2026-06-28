/// Incoming confession chat request — GET /api/v1/confession-requests/
class ConfessionChatRequest {
  final String id;
  final String? senderId;
  final String? senderUsername;
  final String confessionId;
  final String confessionText;
  final String message;
  final String status;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const ConfessionChatRequest({
    required this.id,
    this.senderId,
    this.senderUsername,
    required this.confessionId,
    required this.confessionText,
    required this.message,
    this.status = 'PENDING',
    this.expiresAt,
    required this.createdAt,
  });

  factory ConfessionChatRequest.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    Map<String, dynamic>? senderMap;
    if (sender is Map) {
      senderMap = Map<String, dynamic>.from(sender);
    }

    return ConfessionChatRequest(
      id: json['id']?.toString() ?? '',
      senderId: senderMap?['id']?.toString(),
      senderUsername: senderMap?['username']?.toString(),
      confessionId: json['confession']?.toString() ?? '',
      confessionText: json['confession_text']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'PENDING',
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ConfessionRequestActionResult {
  final bool success;
  final String? conversationId;
  final String? error;

  const ConfessionRequestActionResult({
    required this.success,
    this.conversationId,
    this.error,
  });
}