import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/feed_filters.dart';
import '../../models/feed_item.dart';
import '../../providers/feed_filter_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/shell_navigation_provider.dart';
import '../../utils/profile_completeness.dart';
import '../../widgets/feed/feed_filter_sheet.dart';
import '../../services/analytics_service.dart';
import '../../widgets/feed/feed_profile_card.dart';

class FeedScreen extends ConsumerStatefulWidget {
  final void Function(String conversationId) onOpenChat;

  const FeedScreen({super.key, required this.onOpenChat});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final PageController _verticalCtrl = PageController();

  void _onPageChanged(int index) {
    final feedState = ref.read(feedProvider);
    if (index < feedState.items.length) {
      final item = feedState.items[index];
      AnalyticsService.instance.trackFeedImpression(
        profileId: item.profile.id,
        score: item.score,
        index: index,
        source: item.isBoosted ? 'boost' : 'feed',
      );
    }
    if (!feedState.hasMore || feedState.isLoadingMore) return;
    if (index >= feedState.items.length - 3) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(optionsProvider.notifier).loadAll();
      await ref.read(profileProvider.notifier).loadProfile();
      // Feed candidate pool requires location when the user base is large.
      await ref.read(locationSyncProvider.notifier).syncToProfile();
      if (!mounted) return;
      ref.read(feedProvider.notifier).loadFeed();
    });
  }

  @override
  void dispose() {
    _verticalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);

    if (feedState.isLoading && feedState.items.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0C0C),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF2E74)),
        ),
      );
    }

    if (feedState.profileIncomplete && feedState.items.isEmpty) {
      return _buildProfileIncompleteState(
        feedState.profileIncompleteMessage,
      );
    }

    if (feedState.error != null && feedState.items.isEmpty) {
      return _buildErrorState(feedState.error!);
    }

    if (feedState.items.isEmpty) {
      return _buildEmptyState();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: Stack(
        children: [
          PageView.builder(
            controller: _verticalCtrl,
            scrollDirection: Axis.vertical,
            onPageChanged: _onPageChanged,
            itemCount: feedState.items.length +
                (feedState.isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= feedState.items.length) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFF2E74),
                  ),
                );
              }
              final item = feedState.items[index];
              return FeedProfileCard(
                item: item,
                onLike: () async => ref
                    .read(feedProvider.notifier)
                    .likeProfile(item.profile.id),
                onDm: item.canDirectMessage
                    ? () => _handleDm(item)
                    : null,
              );
            },
          ),
          _FeedTopBar(
            onOpenFilters: () => FeedFilterSheet.show(context),
          ),
          const Positioned(
            bottom: 100,
            right: 20,
            child: _ScrollHint(),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDm(FeedItem item) async {
    final message = await _showDmDialog(item.profile.displayUsername);
    if (message == null || !mounted) return;

    final convId = await ref
        .read(feedProvider.notifier)
        .sendDm(item.profile.id, message: message);
    if (convId != null && mounted) {
      widget.onOpenChat(convId);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start conversation. Try again.'),
          backgroundColor: Color(0xFF1E1E1E),
        ),
      );
    }
  }

  Future<String?> _showDmDialog(String username) async {
    final ctrl = TextEditingController(text: 'Hey! 👋');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Message $username',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Say something...',
            hintStyle: GoogleFonts.outfit(color: const Color(0xFF666666)),
            filled: true,
            fillColor: const Color(0xFF141416),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: const Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text('Send',
                style: GoogleFonts.outfit(
                    color: const Color(0xFFFF2E74),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || result.isEmpty) return null;
    return result;
  }

  Widget _buildErrorState(String error) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFF555555), size: 64),
              const SizedBox(height: 20),
              Text(
                'Could not load feed',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    color: const Color(0xFF888888), fontSize: 14),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () =>
                    ref.read(feedProvider.notifier).refreshFeed(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2E74),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                ),
                child: Text('Try Again',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _emptyFeedHint(FeedState feedState, FeedFilters filters) {
    final reason = feedState.emptyReason;
    if (!filters.isDefault) {
      return 'Try widening age or distance filters, or tap Adjust filters.';
    }
    switch (reason) {
      case 'location_missing':
        return 'Enable location on your profile so we can find people near you, then tap Refresh.';
      case 'no_matching_profiles':
        return 'No one matches your gender preferences yet. Try again later or broaden who you\'re interested in.';
      case 'gender_preferences_incomplete':
        return 'Set your gender and who you\'re interested in on your profile, then refresh.';
      case 'filtered_by_interactions':
        return 'You\'ve seen everyone nearby for now. Check back later for new profiles.';
      default:
        return 'Make sure location is enabled on your profile, then tap Refresh.';
    }
  }

  Widget _buildEmptyState() {
    final feedState = ref.watch(feedProvider);
    final filters = ref.watch(feedFiltersProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('✨', style: TextStyle(fontSize: 60)),
                  const SizedBox(height: 20),
                  Text(
                    'No profiles to show right now',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _emptyFeedHint(feedState, filters),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        color: const Color(0xFF888888), fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: () =>
                        ref.read(feedProvider.notifier).refreshFeed(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF2E74),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                    ),
                    child: Text('Refresh',
                        style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  if (!filters.isDefault) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => FeedFilterSheet.show(context),
                      child: Text(
                        'Adjust filters',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFFF2E74),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          _FeedTopBar(onOpenFilters: () => FeedFilterSheet.show(context)),
        ],
      ),
    );
  }

  Widget _buildProfileIncompleteState(String? message) {
    final profile = ref.watch(profileProvider).profile;
    final missing = profile != null
        ? ProfileCompleteness.discoverBlockers(profile)
        : <String>[];

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.person_outline_rounded,
                  color: Color(0xFFFF2E74), size: 64),
              const SizedBox(height: 20),
              Text(
                'Complete your profile',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                missing.isNotEmpty
                    ? ProfileCompleteness.missingFieldsMessage(profile!)
                    : (message ??
                        'Add username, date of birth, gender, sexuality, and '
                            'preferred genders to use the feed.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF888888),
                  fontSize: 15,
                ),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: missing
                      .map(
                        (field) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFFF2E74).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            field,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFFF2E74),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => ref
                    .read(shellNavigationProvider.notifier)
                    .goToProfileEdit(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2E74),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                ),
                child: Text('Update Profile',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedTopBar extends ConsumerWidget {
  final VoidCallback onOpenFilters;

  const _FeedTopBar({required this.onOpenFilters});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(feedFiltersProvider);
    final active = filters.activeCount;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.4),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.outfit(
                        fontSize: 22, fontWeight: FontWeight.w900),
                    children: const [
                      TextSpan(
                          text: 'sp',
                          style: TextStyle(color: Colors.white)),
                      TextSpan(
                          text: 'y',
                          style: TextStyle(
                              color: Color(0xFFFF2E74),
                              fontStyle: FontStyle.italic)),
                      TextSpan(
                          text: 'ce',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onOpenFilters,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active > 0
                                ? const Color(0xFFFF2E74)
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              color: active > 0
                                  ? const Color(0xFFFF2E74)
                                  : Colors.white.withValues(alpha: 0.85),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Filters',
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (active > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF2E74),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$active',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScrollHint extends StatelessWidget {
  const _ScrollHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.unfold_more_rounded,
              color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            'Scroll for more',
            style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}