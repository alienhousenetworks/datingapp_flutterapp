import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/confession_request_model.dart';
import '../models/message_model.dart';
import '../providers/confession_provider.dart';
import '../services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  return ref.read(chatServiceProvider).getConversations();
});

final matchesProvider = FutureProvider<List<Match>>((ref) {
  return ref.read(chatServiceProvider).getMatches();
});

/// Matches without an active conversation (mirrors web MatchesPage).
final newMatchesProvider = FutureProvider<List<Match>>((ref) async {
  final matches = await ref.watch(matchesProvider.future);
  final conversations = await ref.watch(conversationsProvider.future);

  final activeConvUserIds = conversations
      .map((c) => c.otherUserId)
      .whereType<String>()
      .toSet();

  return matches
      .where((m) =>
          m.matchedUserId.isNotEmpty &&
          !activeConvUserIds.contains(m.matchedUserId))
      .toList();
});

final confessionRequestsProvider =
    FutureProvider<List<ConfessionChatRequest>>((ref) {
  return ref.read(confessionServiceProvider).listIncomingRequests();
});

void refreshChatData(WidgetRef ref) {
  ref.invalidate(matchesProvider);
  ref.invalidate(conversationsProvider);
  ref.invalidate(newMatchesProvider);
  ref.invalidate(confessionRequestsProvider);
}