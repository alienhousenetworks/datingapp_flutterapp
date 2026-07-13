import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/feed_item.dart';
import '../../models/profile_model.dart';
import '../../providers/feed_provider.dart';
import '../../providers/like_tracker_provider.dart';
import '../../providers/profile_provider.dart';
import '../../theme/feed_card_theme.dart';
import '../../theme/feed_layout.dart';
import '../../theme/discovery_background.dart';
import '../../utils/option_resolver.dart';

/// Figma Alien-House feed card:
/// Horizontal pages: Hero → Photo focus → Details → Turn-ons
/// Vertical scroll between users handled by parent FeedScreen.
class FeedProfileCard extends ConsumerStatefulWidget {
  final FeedItem item;
  final VoidCallback? onDm;
  final Future<LikeResult> Function()? onLike;

  const FeedProfileCard({
    super.key,
    required this.item,
    this.onDm,
    this.onLike,
  });

  @override
  ConsumerState<FeedProfileCard> createState() => _FeedProfileCardState();
}

class _FeedProfileCardState extends ConsumerState<FeedProfileCard> {
  final PageController _hCtrl = PageController();
  int _page = 0;
  int _photoIdx = 0;
  bool _isLiking = false;

  UserProfile get profile => widget.item.profile;
  FeedCardTheme get theme =>
      FeedCardThemeCatalog.resolve(profile.themeConfig?.bgVariantId);
  FeedLayoutStyle get layoutStyle =>
      FeedLayoutCatalog.resolve(profile.themeConfig?.layoutId);
  List<ProfileImage> get images => profile.images;
  bool get hasImages => images.isNotEmpty;
  int get pageCount => hasImages ? 4 : 3;

  @override
  void dispose() {
    _hCtrl.dispose();
    super.dispose();
  }

  void _goPhoto(int delta) {
    if (!hasImages) return;
    setState(() {
      _photoIdx = (_photoIdx + delta) % images.length;
      if (_photoIdx < 0) _photoIdx += images.length;
    });
  }

  bool isAlreadyLiked(WidgetRef ref) {
    ref.watch(likeTrackerProvider);
    final tracker = ref.read(likeTrackerProvider.notifier);
    return profile.isLiked || tracker.isActive(profile.id);
  }

  Future<void> _handleLike() async {
    if (isAlreadyLiked(ref) || _isLiking || widget.onLike == null) return;
    setState(() => _isLiking = true);
    final result = await widget.onLike!();
    if (mounted) {
      setState(() => _isLiking = false);
      if (result.matched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "It's a match with ${profile.displayUsername}!",
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: const Color(0xFF1E1E1E),
          ),
        );
      } else if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You liked ${profile.displayUsername}!',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: const Color(0xFF1E1E1E),
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (result.alreadyLiked) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.message ?? 'You already liked this profile',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: const Color(0xFF1E1E1E),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liked = isAlreadyLiked(ref);
    final options = ref.watch(optionsProvider);
    final languageLabels = OptionResolver.resolveList(
      profile.languages,
      options.languages,
    );
    final interestLabels = OptionResolver.resolveList(
      profile.turnOns,
      options.turnOns,
    );
    final bgSpec = DiscoveryBackgroundCatalog.resolveFromTheme(profile.themeConfig);

    return Stack(
      fit: StackFit.expand,
      children: [
        DiscoveryBackground(spec: bgSpec),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.65),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 56),
              if (liked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LikedBadge(),
                ),
              Expanded(
                child: Stack(
                  children: [
                    PageView(
                      controller: _hCtrl,
                      onPageChanged: (p) => setState(() => _page = p),
                      children: hasImages
                          ? [
                              _HeroPage(
                                profile: profile,
                                theme: theme,
                                layoutStyle: layoutStyle,
                                images: images,
                                photoIdx: _photoIdx,
                                onPhotoChanged: (i) =>
                                    setState(() => _photoIdx = i),
                              ),
                              _PhotoFocusPage(
                                profile: profile,
                                theme: theme,
                                images: images,
                                photoIdx: _photoIdx,
                                onPhotoChanged: (i) =>
                                    setState(() => _photoIdx = i),
                                onSwipe: _goPhoto,
                              ),
                              _DetailsPage(
                                profile: profile,
                                theme: theme,
                                languageLabels: languageLabels,
                              ),
                              _TurnOnsPage(
                                profile: profile,
                                theme: theme,
                                interestLabels: interestLabels,
                              ),
                            ]
                          : [
                              _CharacterHeroPage(
                                profile: profile,
                                theme: theme,
                                layoutStyle: layoutStyle,
                                large: false,
                              ),
                              _DetailsPage(
                                profile: profile,
                                theme: theme,
                                languageLabels: languageLabels,
                              ),
                              _TurnOnsPage(
                                profile: profile,
                                theme: theme,
                                interestLabels: interestLabels,
                              ),
                            ],
                    ),
                    Positioned(
                      bottom: 88,
                      left: 0,
                      right: 0,
                      child: _PageDots(count: pageCount, active: _page),
                    ),
                    if (widget.onLike != null)
                      Positioned(
                        bottom: 132,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: _LikeButton(
                            liked: liked,
                            loading: _isLiking,
                            onTap: _handleLike,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.onDm != null)
                SafeArea(
                  top: false,
                  left: false,
                  right: false,
                  bottom: true,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: _DmButton(onTap: widget.onDm!),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Page 0 (with photos): Polaroid hero ─────────────────────
class _HeroPage extends StatefulWidget {
  final UserProfile profile;
  final FeedCardTheme theme;
  final FeedLayoutStyle layoutStyle;
  final List<ProfileImage> images;
  final int photoIdx;
  final ValueChanged<int> onPhotoChanged;

  const _HeroPage({
    required this.profile,
    required this.theme,
    required this.layoutStyle,
    required this.images,
    required this.photoIdx,
    required this.onPhotoChanged,
  });

  @override
  State<_HeroPage> createState() => _HeroPageState();
}

class _HeroPageState extends State<_HeroPage> {
  late PageController _heroPhotoCtrl;

  @override
  void initState() {
    super.initState();
    _heroPhotoCtrl = PageController(initialPage: widget.photoIdx);
  }

  @override
  void didUpdateWidget(covariant _HeroPage old) {
    super.didUpdateWidget(old);
    if (old.photoIdx != widget.photoIdx && _heroPhotoCtrl.hasClients) {
      _heroPhotoCtrl.jumpToPage(widget.photoIdx);
    }
  }

  @override
  void dispose() {
    _heroPhotoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (widget.layoutStyle.fullBleedPhoto) {
      return Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _heroPhotoCtrl,
              itemCount: widget.images.length,
              onPageChanged: widget.onPhotoChanged,
              itemBuilder: (_, i) => _FeedImage(
                url: widget.images[i].url,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 110,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ProfileHeader(
                  profile: widget.profile,
                  theme: widget.theme,
                  layoutStyle: widget.layoutStyle,
                ),
                const SizedBox(height: 12),
                _SwipeHint(
                  text: 'SWIPE FOR PHOTOS →',
                  color: widget.theme.textColor.withOpacity(0.9),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (widget.layoutStyle.photoOnLeft) {
      return Container(
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        alignment: Alignment.center,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: width * widget.layoutStyle.photoWidthFactor,
              height: width * 0.9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.layoutStyle.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: widget.layoutStyle.showAccentBorder
                      ? Border.all(
                          color: widget.theme.accentColor,
                          width: widget.layoutStyle.borderWidth,
                        )
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.layoutStyle.borderRadius),
                  child: PageView.builder(
                    controller: _heroPhotoCtrl,
                    itemCount: widget.images.length,
                    onPageChanged: widget.onPhotoChanged,
                    itemBuilder: (_, i) => _FeedImage(
                      url: widget.images[i].url,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileHeader(
                    profile: widget.profile,
                    theme: widget.theme,
                    layoutStyle: widget.layoutStyle,
                    alignLeft: true,
                  ),
                  const SizedBox(height: 12),
                  _SwipeHint(
                    text: 'SWIPE PHOTOS →',
                    color: widget.theme.textColor.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final double cardHeight = widget.layoutStyle.compactCard ? width * 0.82 : width * 0.95;
    final double cardWidth = width * widget.layoutStyle.photoWidthFactor * 1.6;

    Widget photoContainer = Container(
      height: cardHeight,
      width: cardWidth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.layoutStyle.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: widget.layoutStyle.showAccentBorder
            ? Border.all(
                color: widget.theme.accentColor,
                width: widget.layoutStyle.borderWidth,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.layoutStyle.borderRadius),
        child: Stack(
          children: [
            PageView.builder(
              controller: _heroPhotoCtrl,
              itemCount: widget.images.length,
              onPageChanged: widget.onPhotoChanged,
              itemBuilder: (_, i) => _FeedImage(
                url: widget.images[i].url,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.layoutStyle.photoRotation != 0) {
      photoContainer = Transform.rotate(
        angle: widget.layoutStyle.photoRotation,
        child: photoContainer,
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          photoContainer,
          const SizedBox(height: 20),
          _ProfileHeader(
            profile: widget.profile,
            theme: widget.theme,
            layoutStyle: widget.layoutStyle,
          ),
          const SizedBox(height: 16),
          _SwipeHint(
            text: 'SWIPE FOR PHOTOS →',
            color: widget.theme.textColor.withOpacity(0.7),
          ),
          const SizedBox(height: 220),
        ],
      ),
    );
  }
}

// ─── Page 1: Big photo focus (Figma 10.36.04 layout) ─────────
class _PhotoFocusPage extends StatefulWidget {
  final UserProfile profile;
  final FeedCardTheme theme;
  final List<ProfileImage> images;
  final int photoIdx;
  final ValueChanged<int> onPhotoChanged;
  final void Function(int delta) onSwipe;

  const _PhotoFocusPage({
    required this.profile,
    required this.theme,
    required this.images,
    required this.photoIdx,
    required this.onPhotoChanged,
    required this.onSwipe,
  });

  @override
  State<_PhotoFocusPage> createState() => _PhotoFocusPageState();
}

class _PhotoFocusPageState extends State<_PhotoFocusPage> {
  late PageController _photoCtrl;
  @override
  void initState() {
    super.initState();
    _photoCtrl = PageController(initialPage: widget.photoIdx);
  }

  @override
  void didUpdateWidget(covariant _PhotoFocusPage old) {
    super.didUpdateWidget(old);
    if (old.photoIdx != widget.photoIdx &&
        _photoCtrl.hasClients &&
        _photoCtrl.page?.round() != widget.photoIdx) {
      _photoCtrl.animateToPage(
        widget.photoIdx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _photoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final diff = d.velocity.pixelsPerSecond.dx;
        if (diff > 400) widget.onSwipe(-1);
        if (diff < -400) widget.onSwipe(1);
      },
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'PHOTOS',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: PageView.builder(
                  controller: _photoCtrl,
                  itemCount: widget.images.length,
                  onPageChanged: widget.onPhotoChanged,
                  itemBuilder: (_, i) => _FeedImage(
                    url: widget.images[i].url,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.images.length,
              itemBuilder: (_, i) {
                final selected = i == widget.photoIdx;
                return GestureDetector(
                  onTap: () {
                    widget.onPhotoChanged(i);
                    _photoCtrl.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 64,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        width: selected ? 3 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _FeedImage(
                      url: widget.images[i].url,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _SwipeHint(
              text: 'TAP THUMBNAILS OR SWIPE → DETAILS',
              color: widget.theme.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 0 (no photos): Character hero (Figma 10.39.09) ─────
class _CharacterHeroPage extends StatelessWidget {
  final UserProfile profile;
  final FeedCardTheme theme;
  final FeedLayoutStyle layoutStyle;
  final bool large;

  const _CharacterHeroPage({
    required this.profile,
    required this.theme,
    required this.layoutStyle,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    if (layoutStyle.fullBleedPhoto) {
      return Stack(
        children: [
          Positioned.fill(
            child: _FeedImage(
              url: profile.avatarUrl ?? '',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 110,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ProfileHeader(
                  profile: profile,
                  theme: theme,
                  layoutStyle: layoutStyle,
                ),
                const SizedBox(height: 12),
                _SwipeHint(
                  text: 'SWIPE FOR DETAILS →',
                  color: theme.textColor.withOpacity(0.9),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (layoutStyle.photoOnLeft) {
      return Container(
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        alignment: Alignment.center,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: w * layoutStyle.photoWidthFactor,
              height: w * 0.9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(layoutStyle.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: layoutStyle.showAccentBorder
                      ? Border.all(
                          color: theme.accentColor,
                          width: layoutStyle.borderWidth,
                        )
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(layoutStyle.borderRadius),
                  child: _FeedImage(
                    url: profile.avatarUrl ?? '',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileHeader(
                    profile: profile,
                    theme: theme,
                    layoutStyle: layoutStyle,
                    alignLeft: true,
                  ),
                  const SizedBox(height: 12),
                  _SwipeHint(
                    text: 'SWIPE FOR DETAILS →',
                    color: theme.textColor.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final double cardHeight = layoutStyle.compactCard ? w * 0.82 : w * 0.95;
    final double cardWidth = w * layoutStyle.photoWidthFactor * 1.6;

    Widget characterArt = Container(
      height: cardHeight,
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(layoutStyle.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: layoutStyle.showAccentBorder
            ? Border.all(
                color: theme.accentColor,
                width: layoutStyle.borderWidth,
              )
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: _FeedImage(
        url: profile.avatarUrl ?? '',
        fit: BoxFit.cover,
      ),
    );

    if (layoutStyle.photoRotation != 0) {
      characterArt = Transform.rotate(
        angle: layoutStyle.photoRotation,
        child: characterArt,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          characterArt,
          const SizedBox(height: 20),
          _ProfileHeader(
            profile: profile,
            theme: theme,
            layoutStyle: layoutStyle,
          ),
          const SizedBox(height: 16),
          _SwipeHint(
            text: 'SWIPE FOR DETAILS →',
            color: theme.textColor.withOpacity(0.7),
          ),
          const SizedBox(height: 220),
        ],
      ),
    );
  }
}

// ─── Details page: intent, languages, bio ────────────────────
class _DetailsPage extends StatelessWidget {
  final UserProfile profile;
  final FeedCardTheme theme;
  final List<String> languageLabels;

  const _DetailsPage({
    required this.profile,
    required this.theme,
    required this.languageLabels,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = theme.textColor;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'ABOUT',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.displayUsername,
            style: GoogleFonts.outfit(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          _DetailBlock(
            label: 'INTENT',
            child: _Tag(
              label: profile.intent ?? 'Not set',
              theme: theme,
            ),
          ),
          _DetailBlock(
            label: 'LANGUAGES',
            child: languageLabels.isEmpty
                ? Text(
                    'Not set',
                    style: GoogleFonts.outfit(
                      color: textColor.withOpacity(0.6),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: languageLabels
                        .map((l) => _Tag(label: l, theme: theme))
                        .toList(),
                  ),
          ),
          _DetailBlock(
            label: 'BIO',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                profile.bio?.isNotEmpty == true
                    ? profile.bio!
                    : 'No bio yet.',
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (profile.gender != null || profile.sexuality != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (profile.gender != null)
                  _Tag(label: profile.gender!, theme: theme),
                if (profile.sexuality != null)
                  _Tag(label: profile.sexuality!, theme: theme),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _SwipeHint(
            text: 'SWIPE FOR TURN-ONS →',
            color: textColor,
          ),
          const SizedBox(height: 220),
        ],
      ),
    );
  }
}

// ─── Turn-ons page ───────────────────────────────────────────
class _TurnOnsPage extends StatelessWidget {
  final UserProfile profile;
  final FeedCardTheme theme;
  final List<String> interestLabels;

  const _TurnOnsPage({
    required this.profile,
    required this.theme,
    required this.interestLabels,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            'TURN ONS',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          if (interestLabels.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Nothing listed yet',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: theme.textColor.withOpacity(0.6),
                  fontSize: 15,
                ),
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: interestLabels
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.accentColor.withOpacity(0.6),
                        ),
                      ),
                      child: Text(
                        '🔥 $t',
                        style: GoogleFonts.outfit(
                          color: theme.textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 24),
          if (profile.mood != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '✨ ${profile.mood}',
                style: GoogleFonts.outfit(
                  color: theme.accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 220),
        ],
      ),
    );
  }
}

// ─── Shared widgets ──────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final UserProfile profile;
  final FeedCardTheme theme;
  final FeedLayoutStyle layoutStyle;
  final bool alignLeft;

  const _ProfileHeader({
    required this.profile,
    required this.theme,
    required this.layoutStyle,
    this.alignLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    final age = profile.age;
    final genderShort = _genderShort(profile.gender);
    final isBold = layoutStyle.boldTypography;

    return Column(
      crossAxisAlignment: alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          '${profile.displayUsername}${age != null ? ', $age' : ''}${genderShort.isNotEmpty ? ' • $genderShort' : ''}',
          textAlign: alignLeft ? TextAlign.left : TextAlign.center,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: isBold ? 30 : 25,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w800,
            letterSpacing: isBold ? -1.0 : -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            if (profile.distanceText.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  profile.distanceText,
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (profile.sexuality != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  profile.sexuality!,
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (profile.isOnline)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Online',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF00E676),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (profile.bio != null && profile.bio!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
              top: 14,
              left: alignLeft ? 0 : 16,
              right: alignLeft ? 0 : 16,
            ),
            child: Text(
              profile.bio!,
              textAlign: alignLeft ? TextAlign.left : TextAlign.center,
              maxLines: layoutStyle.compactCard ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white60,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }

  String _genderShort(String? gender) {
    final g = (gender ?? '').toLowerCase();
    if (g.contains('female') || g.contains('woman')) return 'F';
    if (g.contains('male') || g.contains('man')) return 'M';
    return '';
  }
}


class _FeedImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const _FeedImage({required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => Container(
        color: Colors.black12,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => const Icon(Icons.broken_image, size: 40),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String label;
  final Widget child;

  const _DetailBlock({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final FeedCardTheme theme;

  const _Tag({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: theme.textColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  final int count;
  final int active;

  const _PageDots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active == i ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active == i
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  final String text;
  final Color color;

  const _SwipeHint({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.swipe_rounded, color: color.withValues(alpha: 0.4), size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.outfit(
            color: color.withValues(alpha: 0.45),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _LikedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3040).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        '♥ Liked',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  final bool liked;
  final bool loading;
  final VoidCallback onTap;

  const _LikeButton({
    required this.liked,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: loading || liked ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: liked
                  ? const RadialGradient(
                      colors: [Color(0xFF8BD969), Color(0xFF6AB04C)],
                    )
                  : null,
              color: liked
                  ? null
                  : const Color(0xFF6AB04C).withValues(alpha: 0.45),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8BD969)
                      .withValues(alpha: liked ? 0.8 : 0.4),
                  blurRadius: liked ? 24 : 16,
                  spreadRadius: liked ? 2 : 0,
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: liked ? 0.9 : 0.35),
                width: 2,
              ),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
          ),
        ),
        if (liked) ...[
          const SizedBox(height: 6),
          Text(
            '♥ Already Liked',
            style: GoogleFonts.outfit(
              color: const Color(0xFF8BD969),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _DmButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DmButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send_rounded, color: Color(0xFFFF2E74), size: 20),
            const SizedBox(width: 10),
            Text(
              'Send a Message',
              style: GoogleFonts.outfit(
                color: const Color(0xFF1A1A1A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}