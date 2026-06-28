import 'feed_item.dart';

/// Paginated response from GET /api/v1/feed/
class FeedPage {
  final List<FeedItem> items;
  final int? nextCursor;
  final bool profileIncomplete;
  final String? message;
  final String? emptyReason;

  const FeedPage({
    this.items = const [],
    this.nextCursor,
    this.profileIncomplete = false,
    this.message,
    this.emptyReason,
  });

  bool get hasMore => nextCursor != null;
}