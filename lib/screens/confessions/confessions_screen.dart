import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/confession_model.dart';
import '../../providers/confession_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/confession_service.dart';

class ConfessionsScreen extends ConsumerStatefulWidget {
  const ConfessionsScreen({super.key});

  @override
  ConsumerState<ConfessionsScreen> createState() => _ConfessionsScreenState();
}

class _ConfessionsScreenState extends ConsumerState<ConfessionsScreen> {
  final _bodyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(confessionsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _showChatRequestDialog(
      BuildContext context, String confessionId) async {
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ChatRequestDialog(),
    );
    if (note == null || !mounted) return;

    if (note.length < ConfessionService.minChatRequestLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Note must be at least ${ConfessionService.minChatRequestLength} characters.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFF1E1E1E),
        ),
      );
      return;
    }

    final err = await ref
        .read(confessionsProvider.notifier)
        .chatRequest(confessionId, note);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ?? 'Chat request sent!',
          style: GoogleFonts.outfit(),
        ),
        backgroundColor:
            err != null ? const Color(0xFF1E1E1E) : const Color(0xFF0C243B),
      ),
    );
  }

  Future<void> _showRepostDialog(BuildContext context, String confessionId) async {
    final thought = await showDialog<String>(
      context: context,
      builder: (ctx) => const _RepostDialog(),
    );
    if (thought == null || !mounted) return;

    final err = await ref
        .read(confessionsProvider.notifier)
        .repost(confessionId, thought: thought.isEmpty ? null : thought);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ?? 'Reposted!',
          style: GoogleFonts.outfit(),
        ),
        backgroundColor:
            err != null ? const Color(0xFF1E1E1E) : const Color(0xFF0C243B),
      ),
    );
  }

  Future<void> _post() async {
    final body = _bodyCtrl.text.trim();
    if (body.length < ConfessionService.minTextLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Write at least ${ConfessionService.minTextLength} characters.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFF1E1E1E),
        ),
      );
      return;
    }

    final ok = await ref.read(confessionsProvider.notifier).post(body);
    if (!mounted) return;

    if (ok) {
      _bodyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Confession posted!', style: GoogleFonts.outfit()),
          backgroundColor: const Color(0xFF0C243B),
        ),
      );
    } else {
      final err = ref.read(confessionsProvider).postError;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err, style: GoogleFonts.outfit()),
            backgroundColor: const Color(0xFF1E1E1E),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(confessionsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🌙', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Text(
                        'Confessions',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: state.isLoading
                            ? null
                            : () =>
                                ref.read(confessionsProvider.notifier).load(),
                        icon: const Icon(Icons.refresh_rounded,
                            color: Color(0xFF888888)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share anonymously. Relate with others.',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF666666),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ConfessionPostBox(
                controller: _bodyCtrl,
                moodTags: state.moodTags,
                selectedMood: state.selectedMoodTag,
                onMoodSelected: (m) =>
                    ref.read(confessionsProvider.notifier).selectMood(m),
                onPost: state.isPosting ? null : _post,
                isPosting: state.isPosting,
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  state.error!,
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFF6B6B),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: state.isLoading && state.items.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF2E74),
                      ),
                    )
                  : state.items.isEmpty
                      ? _buildEmpty(state.error == null)
                      : RefreshIndicator(
                          color: const Color(0xFFFF2E74),
                          onRefresh: () =>
                              ref.read(confessionsProvider.notifier).load(),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 4,
                            ),
                            itemCount: state.items.length,
                            itemBuilder: (_, i) => _ConfessionCard(
                              confession: state.items[i],
                              onRelate: () => ref
                                  .read(confessionsProvider.notifier)
                                  .relate(state.items[i].id),
                              onRepost: () =>
                                  _showRepostDialog(context, state.items[i].id),
                              onChatRequest: state.items[i].isAuthor ||
                                      state.items[i].hasRequestedChat
                                  ? null
                                  : () => _showChatRequestDialog(
                                        context,
                                        state.items[i].id,
                                      ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(bool loadedSuccessfully) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🤫', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          Text(
            loadedSuccessfully
                ? 'No confessions nearby yet'
                : 'Could not load confessions',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            loadedSuccessfully
                ? 'Be the first to share something real.'
                : 'Pull down to refresh or check your connection.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              color: const Color(0xFF888888),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog owns its [TextEditingController] lifecycle — avoids disposing while
/// the framework still has dependents (red screen crash).
class _ChatRequestDialog extends StatefulWidget {
  const _ChatRequestDialog();

  @override
  State<_ChatRequestDialog> createState() => _ChatRequestDialogState();
}

class _ChatRequestDialogState extends State<_ChatRequestDialog> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        'Send chat request',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: TextField(
        controller: _noteCtrl,
        autofocus: true,
        maxLines: 4,
        maxLength: ConfessionService.maxChatRequestLength,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          hintText:
              'Introduce yourself (${ConfessionService.minChatRequestLength}–${ConfessionService.maxChatRequestLength} chars)',
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
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.outfit(color: const Color(0xFF888888))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _noteCtrl.text.trim()),
          child: Text('Send',
              style: GoogleFonts.outfit(
                  color: const Color(0xFFFF2E74),
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _RepostDialog extends StatefulWidget {
  const _RepostDialog();

  @override
  State<_RepostDialog> createState() => _RepostDialogState();
}

class _RepostDialogState extends State<_RepostDialog> {
  final _thoughtCtrl = TextEditingController();

  @override
  void dispose() {
    _thoughtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: Text(
        'Repost confession',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: TextField(
        controller: _thoughtCtrl,
        autofocus: true,
        maxLines: 3,
        maxLength: 300,
        style: GoogleFonts.outfit(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Add a thought (optional)',
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
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: GoogleFonts.outfit(color: const Color(0xFF888888))),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _thoughtCtrl.text.trim()),
          child: Text('Repost',
              style: GoogleFonts.outfit(
                  color: const Color(0xFFFF2E74),
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _ConfessionPostBox extends StatelessWidget {
  final TextEditingController controller;
  final List<MoodTagOption> moodTags;
  final String? selectedMood;
  final ValueChanged<String?> onMoodSelected;
  final VoidCallback? onPost;
  final bool isPosting;

  const _ConfessionPostBox({
    required this.controller,
    required this.moodTags,
    required this.selectedMood,
    required this.onMoodSelected,
    required this.onPost,
    required this.isPosting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2E)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
            maxLines: 4,
            minLines: 2,
            maxLength: ConfessionService.maxTextLength,
            decoration: InputDecoration(
              hintText: 'What\'s on your mind? (min ${ConfessionService.minTextLength} chars)',
              hintStyle: GoogleFonts.outfit(
                color: const Color(0xFF555555),
                fontSize: 15,
              ),
              border: InputBorder.none,
              counterStyle:
                  GoogleFonts.outfit(color: const Color(0xFF555555)),
            ),
          ),
          if (moodTags.isNotEmpty) ...[
            const SizedBox(height: 4),
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: moodTags.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  if (i == 0) {
                    final selected = selectedMood == null;
                    return _MoodChip(
                      label: 'Any mood',
                      selected: selected,
                      onTap: () => onMoodSelected(null),
                    );
                  }
                  final mood = moodTags[i - 1];
                  return _MoodChip(
                    label: mood.label,
                    selected: selectedMood == mood.value,
                    onTap: () => onMoodSelected(mood.value),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '🎭 Always anonymous',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF888888),
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onPost,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF2E74),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: isPosting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Post',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
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

class _MoodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MoodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFFF2E74).withValues(alpha: 0.2)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF2E74)
                : const Color(0xFF333333),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: selected ? const Color(0xFFFF2E74) : const Color(0xFF888888),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ConfessionCard extends StatefulWidget {
  final Confession confession;
  final VoidCallback onRelate;
  final VoidCallback onRepost;
  final VoidCallback? onChatRequest;

  const _ConfessionCard({
    required this.confession,
    required this.onRelate,
    required this.onRepost,
    this.onChatRequest,
  });

  @override
  State<_ConfessionCard> createState() => _ConfessionCardState();
}

class _ConfessionCardState extends State<_ConfessionCard> {
  bool _related = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.trackConfessionViewed(widget.confession.id);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.confession;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF202024)),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  c.isAuthor ? '🎭 You' : '🎭 Anonymous',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF888888),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _timeAgo(c.createdAt),
                style: GoogleFonts.outfit(
                  color: const Color(0xFF555555),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (c.hasAuthorMeta) ...[
            const SizedBox(height: 8),
            _AuthorMetaRow(confession: c),
          ],
          const SizedBox(height: 12),
          Text(
            c.text,
            style: GoogleFonts.outfit(
              color: const Color(0xFFEEEEEE),
              fontSize: 15,
              height: 1.55,
            ),
          ),
          if (c.moodLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_moodEmoji(c.moodTag ?? '')} ${c.moodLabel}',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF888888),
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_related) return;
                  setState(() => _related = true);
                  widget.onRelate();
                },
                child: Row(
                  children: [
                    Icon(
                      _related ? Icons.favorite : Icons.favorite_border,
                      color: _related
                          ? const Color(0xFFFF2E74)
                          : const Color(0xFF666666),
                      size: 18,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${c.relateCount} relate',
                      style: GoogleFonts.outfit(
                        color: _related
                            ? const Color(0xFFFF2E74)
                            : const Color(0xFF666666),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              if (widget.onChatRequest != null) ...[
                GestureDetector(
                  onTap: widget.onChatRequest,
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline_rounded,
                          color: Color(0xFF666666), size: 18),
                      const SizedBox(width: 5),
                      Text(
                        'Chat',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF666666),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
              ] else if (!c.isAuthor && c.hasRequestedChat) ...[
                Row(
                  children: [
                    Icon(Icons.mark_email_read_outlined,
                        color: const Color(0xFFFF2E74).withValues(alpha: 0.7),
                        size: 18),
                    const SizedBox(width: 5),
                    Text(
                      'Requested',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFF2E74).withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 20),
              ],
              GestureDetector(
                onTap: widget.onRepost,
                child: Row(
                  children: [
                    const Icon(Icons.repeat_rounded,
                        color: Color(0xFF666666), size: 18),
                    const SizedBox(width: 5),
                    Text(
                      '${c.repostCount} repost',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF666666),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _moodEmoji(String mood) {
    const map = {
      'lonely': '🌙',
      'curious': '🔍',
      'regret': '😔',
      'happy': '😊',
      'anxious': '😰',
      'horny': '🔥',
      'grateful': '🙏',
      'dark_secret': '🖤',
      'fantasy': '✨',
      'taboo': '🤫',
      'guilt': '😞',
      'kink': '⛓️',
    };
    return map[mood.toLowerCase()] ?? '💭';
  }
}

class _AuthorMetaRow extends StatelessWidget {
  final Confession confession;

  const _AuthorMetaRow({required this.confession});

  String _genderEmoji(String? gender) {
    if (gender == null || gender.isEmpty) return '👤';
    final g = gender.toLowerCase();
    if (g.contains('female') || g.contains('woman')) return '👩';
    if (g.contains('male') || g.contains('man')) return '👨';
    return '👤';
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (confession.userGender != null && confession.userGender!.isNotEmpty) {
      chips.add(_MetaChip(
        label: '${_genderEmoji(confession.userGender)} ${confession.userGender}',
      ));
    }
    if (confession.userSexuality != null &&
        confession.userSexuality!.isNotEmpty) {
      chips.add(_MetaChip(label: '✨ ${confession.userSexuality}'));
    }
    if (confession.userAge != null) {
      chips.add(_MetaChip(label: '🎂 ${confession.userAge}'));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: chips,
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A30)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: const Color(0xFFAAAAAA),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}