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
import '../watermark_overlay.dart';

/// Brand accent used for CTAs when theme accents are too muted.
const Color _kBrandPink = Color(0xFFFF2E74);
const Color _kBrandPinkDeep = Color(0xFFE91E63);
const Color _kLikedGreen = Color(0xFF5FD068);
const Color _kLikedGreenDeep = Color(0xFF2E9B4A);

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
            backgroundColor: _kBrandPinkDeep,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final bgSpec =
        DiscoveryBackgroundCatalog.resolveFromTheme(profile.themeConfig);
    final hasActions = widget.onLike != null || widget.onDm != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        DiscoveryBackground(spec: bgSpec),
        // Soft vignette so content stays readable on busy themes
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.72),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.35, 1.0],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 52),
              if (liked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: const _LikedBadge(),
                ),
              Expanded(
                child: PageView(
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
              ),
              // Unified bottom chrome: dots + actions
              _BottomChrome(
                pageCount: pageCount,
                activePage: _page,
                theme: theme,
                liked: liked,
                liking: _isLiking,
                onLike: widget.onLike != null ? _handleLike : null,
                onDm: widget.onDm,
                hasActions: hasActions,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Bottom chrome: dots + like + message ────────────────────
class _BottomChrome extends StatelessWidget {
  final int pageCount;
  final int activePage;
  final FeedCardTheme theme;
  final bool liked;
  final bool liking;
  final VoidCallback? onLike;
  final VoidCallback? onDm;
  final bool hasActions;

  const _BottomChrome({
    required this.pageCount,
    required this.activePage,
    required this.theme,
    required this.liked,
    required this.liking,
    required this.onLike,
    required this.onDm,
    required this.hasActions,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottomInset),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.82),
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PageDots(
            count: pageCount,
            active: activePage,
            accent: theme.accentColor,
          ),
          if (hasActions) ...[
            const SizedBox(height: 14),
            _ActionRow(
              theme: theme,
              liked: liked,
              liking: liking,
              onLike: onLike,
              onDm: onDm,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final FeedCardTheme theme;
  final bool liked;
  final bool liking;
  final VoidCallback? onLike;
  final VoidCallback? onDm;

  const _ActionRow({
    required this.theme,
    required this.liked,
    required this.liking,
    required this.onLike,
    required this.onDm,
  });

  @override
  Widget build(BuildContext context) {
    final hasLike = onLike != null;
    final hasDm = onDm != null;

    if (hasLike && hasDm) {
      return Row(
        children: [
          _LikeButton(
            liked: liked,
            loading: liking,
            onTap: onLike!,
            compact: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _DmButton(
              onTap: onDm!,
              accent: theme.accentColor,
              primary: theme.primaryColor,
            ),
          ),
        ],
      );
    }

    if (hasLike) {
      return Center(
        child: _LikeButton(
          liked: liked,
          loading: liking,
          onTap: onLike!,
          compact: false,
        ),
      );
    }

    return _DmButton(
      onTap: onDm!,
      accent: theme.accentColor,
      primary: theme.primaryColor,
    );
  }
}

// ─── Page 0 (with photos): layout-aware hero ─────────────────
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

  Widget _photoPager({BoxFit fit = BoxFit.cover}) {
    return PageView.builder(
      controller: _heroPhotoCtrl,
      itemCount: widget.images.length,
      onPageChanged: widget.onPhotoChanged,
      itemBuilder: (_, i) => _FeedImage(
        url: widget.images[i].url,
        fit: fit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.layoutStyle;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxH = constraints.maxHeight;
        final maxW = constraints.maxWidth;

        switch (style.kind) {
          case FeedLayoutKind.velvetGlass:
            return _buildVelvetGlass(maxH, maxW, style);
          case FeedLayoutKind.maison:
            return _buildMaison(maxH, maxW, style);
          case FeedLayoutKind.noir:
            return _buildNoir(maxH, maxW, style);
          case FeedLayoutKind.atelier:
            return _buildAtelier(maxH, maxW, style);
          case FeedLayoutKind.runway:
            return _buildRunway(maxH, maxW, style);
        }
      },
    );
  }

  // ── L01 Velvet Glass ──────────────────────────────────────
  Widget _buildVelvetGlass(double maxH, double maxW, FeedLayoutStyle style) {
    final cardH = (maxH * style.photoHeightFactor).clamp(300.0, maxH - 4);
    final cardW = (maxW * style.photoWidthFactor).clamp(260.0, maxW - 24);
    final accent = widget.theme.accentColor;
    final primary = widget.theme.primaryColor;

    return Center(
      child: Container(
        height: cardH,
        width: cardW,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(style.borderRadius),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1.2,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.16),
              Colors.white.withValues(alpha: 0.05),
              primary.withValues(alpha: 0.08),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.32),
              blurRadius: 36,
              spreadRadius: -2,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(style.borderRadius - 1),
          child: Column(
            children: [
              Expanded(
                flex: 62,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  decoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(style.borderRadius - 10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(style.borderRadius - 10),
                    child: _photoPager(),
                  ),
                ),
              ),
              Expanded(
                flex: 38,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: _ProfileHeader(
                          profile: widget.profile,
                          theme: widget.theme,
                          layoutStyle: style,
                          dense: true,
                          showBio: true,
                          bioMaxLines: 3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _SwipeHint(
                        text: 'SWIPE PHOTOS →',
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── L02 Maison (editorial split) ──────────────────────────
  Widget _buildMaison(double maxH, double maxW, FeedLayoutStyle style) {
    final cardH = (maxH * style.photoHeightFactor).clamp(280.0, maxH - 4);
    final accent = widget.theme.accentColor;
    final primary = widget.theme.primaryColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Center(
        child: Container(
          height: cardH,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(style.borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            color: const Color(0xFF0A0A0A).withValues(alpha: 0.55),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.20),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(style.borderRadius - 1),
            child: Row(
              children: [
                Expanded(
                  flex: 11,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _photoPager(),
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            'MAISON',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        accent.withValues(alpha: 0.15),
                        accent,
                        primary,
                        accent.withValues(alpha: 0.15),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 18, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _ProfileHeader(
                            profile: widget.profile,
                            theme: widget.theme,
                            layoutStyle: style,
                            alignLeft: true,
                            dense: true,
                            showBio: true,
                            bioMaxLines: 5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _SwipeHint(
                          text: 'SWIPE PHOTOS →',
                          color: Colors.white.withValues(alpha: 0.5),
                          alignLeft: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── L03 Noir (cinematic full-bleed) ───────────────────────
  Widget _buildNoir(double maxH, double maxW, FeedLayoutStyle style) {
    final accent = widget.theme.accentColor;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: _photoPager()),
        // Film-grain style vignette
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.92),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.28, 0.48, 1.0],
              ),
            ),
          ),
        ),
        // Gold accent line
        Positioned(
          left: 20,
          right: 20,
          bottom: 0,
          height: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  accent.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 24,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 18,
                      height: 1,
                      color: accent.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'NOIR',
                      style: GoogleFonts.outfit(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 18,
                      height: 1,
                      color: accent.withValues(alpha: 0.7),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ProfileHeader(
                  profile: widget.profile,
                  theme: widget.theme,
                  layoutStyle: style,
                  dense: true,
                  showBio: true,
                  bioMaxLines: 3,
                  forceLightText: true,
                ),
                const SizedBox(height: 8),
                _SwipeHint(
                  text: 'SWIPE FOR PHOTOS →',
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── L04 Atelier (museum gallery frame) ────────────────────
  Widget _buildAtelier(double maxH, double maxW, FeedLayoutStyle style) {
    final cardH = (maxH * style.photoHeightFactor).clamp(220.0, maxH * 0.68);
    final cardW = (maxW * style.photoWidthFactor).clamp(210.0, maxW - 48);
    final accent = widget.theme.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Outer museum mat + frame
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(style.borderRadius + 6),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: style.borderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Container(
              height: cardH,
              width: cardW,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(style.borderRadius),
                border: Border.all(
                  color: accent.withValues(alpha: 0.55),
                  width: 1.2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(style.borderRadius - 0.5),
                child: _photoPager(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Plaque-style name plate
          Container(
            width: cardW + 20,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: _ProfileHeader(
              profile: widget.profile,
              theme: widget.theme,
              layoutStyle: style,
              dense: true,
              showBio: true,
              bioMaxLines: 3,
            ),
          ),
          const SizedBox(height: 8),
          _SwipeHint(
            text: 'SWIPE PHOTOS →',
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  // ── L05 Runway (fashion poster) ───────────────────────────
  Widget _buildRunway(double maxH, double maxW, FeedLayoutStyle style) {
    final cardH = (maxH * style.photoHeightFactor).clamp(300.0, maxH - 4);
    final cardW = (maxW * style.photoWidthFactor).clamp(270.0, maxW - 20);
    final accent = widget.theme.accentColor;
    final primary = widget.theme.primaryColor;

    Widget poster = Container(
      height: cardH,
      width: cardW,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(style.borderRadius),
        border: Border.all(
          color: accent.withValues(alpha: 0.9),
          width: style.borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.38),
            blurRadius: 32,
            spreadRadius: 0,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(6, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(style.borderRadius - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _photoPager(),
            // Vertical brand stripe
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 7,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [accent, primary, accent],
                  ),
                ),
              ),
            ),
            // Top label
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'RUNWAY',
                  style: GoogleFonts.outfit(
                    color: _readableOn(accent),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ),
            // Bottom type block
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: cardH * 0.52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.94),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProfileHeader(
                    profile: widget.profile,
                    theme: widget.theme,
                    layoutStyle: style,
                    alignLeft: true,
                    dense: true,
                    showBio: true,
                    bioMaxLines: 3,
                    forceLightText: true,
                  ),
                  const SizedBox(height: 8),
                  _SwipeHint(
                    text: 'SWIPE PHOTOS →',
                    color: Colors.white.withValues(alpha: 0.7),
                    alignLeft: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (style.photoRotation != 0) {
      poster = Transform.rotate(angle: style.photoRotation, child: poster);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: poster,
      ),
    );
  }
}

// ─── Page 1: Big photo focus ─────────────────────────────────
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
          const SizedBox(height: 8),
          Text(
            'PHOTOS',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          if (widget.profile.city?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: widget.theme.accentColor,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.profile.city!,
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: widget.theme.accentColor.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.theme.accentColor.withValues(alpha: 0.2),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.5),
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
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 68,
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
                    width: 60,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? widget.theme.accentColor
                            : Colors.white.withValues(alpha: 0.28),
                        width: selected ? 2.5 : 1,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: widget.theme.accentColor
                                    .withValues(alpha: 0.45),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
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
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: _SwipeHint(
              text: 'TAP THUMBNAILS OR SWIPE → DETAILS',
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page 0 (no photos): Character hero ──────────────────────
class _CharacterHeroPage extends StatelessWidget {
  final UserProfile profile;
  final FeedCardTheme theme;
  final FeedLayoutStyle layoutStyle;

  const _CharacterHeroPage({
    required this.profile,
    required this.theme,
    required this.layoutStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Reuse hero photo logic with a single avatar image when present
    final avatar = profile.avatarUrl;
    final images = avatar != null && avatar.isNotEmpty
        ? [ProfileImage(id: 'avatar', url: avatar, order: 0, isPrimary: true)]
        : <ProfileImage>[];

    if (images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [theme.primaryColor, theme.accentColor],
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 24,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                (profile.displayUsername.isNotEmpty
                        ? profile.displayUsername[0]
                        : '?')
                    .toUpperCase(),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _ProfileHeader(
              profile: profile,
              theme: theme,
              layoutStyle: layoutStyle,
              showBio: true,
              bioMaxLines: 4,
            ),
            const SizedBox(height: 8),
            _SwipeHint(
              text: 'SWIPE FOR DETAILS →',
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ],
        ),
      );
    }

    return _HeroPage(
      profile: profile,
      theme: theme,
      layoutStyle: layoutStyle,
      images: images,
      photoIdx: 0,
      onPhotoChanged: (_) {},
    );
  }
}

// ─── Details page ────────────────────────────────────────────
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ABOUT',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            profile.displayUsername,
            style: GoogleFonts.outfit(
              color: theme.accentColor,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (profile.city?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: theme.accentColor,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  profile.city!,
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          _DetailBlock(
            label: 'INTENT',
            accent: theme.accentColor,
            child: _Tag(label: profile.intent ?? 'Not set', theme: theme),
          ),
          _DetailBlock(
            label: 'LANGUAGES',
            accent: theme.accentColor,
            child: languageLabels.isEmpty
                ? Text(
                    'Not set',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.55),
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
            accent: theme.accentColor,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.accentColor.withValues(alpha: 0.28),
                ),
              ),
              child: Text(
                profile.bio?.isNotEmpty == true ? profile.bio! : 'No bio yet.',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
          ),
          if (profile.gender != null || profile.sexuality != null) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (profile.gender != null)
                  _Tag(label: profile.gender!, theme: theme),
                if (profile.sexuality != null)
                  _Tag(label: profile.sexuality!, theme: theme),
              ],
            ),
          ],
          const SizedBox(height: 18),
          _SwipeHint(
            text: 'SWIPE FOR TURN-ONS →',
            color: Colors.white.withValues(alpha: 0.75),
          ),
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
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      child: Column(
        children: [
          Text(
            'TURN ONS',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 18),
          if (interestLabels.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                'Nothing listed yet',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.55),
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
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.primaryColor.withValues(alpha: 0.55),
                            theme.accentColor.withValues(alpha: 0.35),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.accentColor.withValues(alpha: 0.65),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.accentColor.withValues(alpha: 0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Text(
                        '🔥 $t',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 22),
          if (profile.mood != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.accentColor.withValues(alpha: 0.5),
                ),
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
  final bool dense;
  final bool forceLightText;
  /// When true, bio is shown even on dense hero cards (first page).
  final bool showBio;
  final int bioMaxLines;

  const _ProfileHeader({
    required this.profile,
    required this.theme,
    required this.layoutStyle,
    this.alignLeft = false,
    this.dense = false,
    this.forceLightText = false,
    this.showBio = false,
    this.bioMaxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    final age = profile.age;
    final genderShort = _genderShort(profile.gender);
    final isBold = layoutStyle.boldTypography;
    final titleColor = forceLightText ? Colors.white : Colors.white;
    final nameSize = dense
        ? (isBold ? 24.0 : 20.0)
        : (isBold ? 28.0 : 24.0);
    final hasBio = profile.bio != null && profile.bio!.trim().isNotEmpty;
    final shouldShowBio = showBio || !dense;

    return Column(
      crossAxisAlignment:
          alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${profile.displayUsername}${age != null ? ', $age' : ''}${genderShort.isNotEmpty ? ' • $genderShort' : ''}',
          textAlign: alignLeft ? TextAlign.left : TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: titleColor,
            fontSize: nameSize,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w800,
            letterSpacing: isBold ? -0.8 : -0.4,
            height: 1.1,
            shadows: forceLightText || isBold
                ? [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
        SizedBox(height: dense ? 6 : 8),
        Wrap(
          alignment: alignLeft ? WrapAlignment.start : WrapAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            if (profile.distanceText.isNotEmpty)
              _MetaChip(
                label: profile.distanceText,
                accent: theme.accentColor,
              ),
            if (profile.sexuality != null)
              _MetaChip(
                label: profile.sexuality!,
                accent: theme.accentColor,
              ),
            if (profile.isOnline)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF00E676).withValues(alpha: 0.4),
                  ),
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
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (shouldShowBio)
          Padding(
            padding: EdgeInsets.only(
              top: dense ? 8 : 10,
              left: alignLeft ? 0 : 8,
              right: alignLeft ? 0 : 8,
            ),
            child: Text(
              hasBio ? profile.bio! : 'No bio yet.',
              textAlign: alignLeft ? TextAlign.left : TextAlign.center,
              maxLines: bioMaxLines,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: hasBio ? 0.82 : 0.45),
                fontSize: dense ? 12.5 : 13.5,
                height: 1.4,
                fontStyle: hasBio ? FontStyle.normal : FontStyle.italic,
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

class _MetaChip extends StatelessWidget {
  final String label;
  final Color accent;

  const _MetaChip({required this.label, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: Colors.white.withValues(alpha: 0.88),
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _FeedImage extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const _FeedImage({required this.url, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        color: Colors.black26,
        child: const Center(
          child: Icon(Icons.person_rounded, size: 48, color: Colors.white38),
        ),
      );
    }
    return WatermarkOverlay(
      child: CachedNetworkImage(
        imageUrl: url,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => Container(
          color: Colors.black26,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: Colors.black26,
          child: const Icon(Icons.broken_image_rounded,
              size: 40, color: Colors.white38),
        ),
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final String label;
  final Widget child;
  final Color accent;

  const _DetailBlock({
    required this.label,
    required this.child,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.accentColor.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: Colors.white,
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
  final Color accent;

  const _PageDots({
    required this.count,
    required this.active,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) {
          final isActive = active == i;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isActive ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: isActive
                  ? accent
                  : Colors.white.withValues(alpha: 0.32),
              borderRadius: BorderRadius.circular(4),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.55),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  final String text;
  final Color color;
  final bool alignLeft;

  const _SwipeHint({
    required this.text,
    required this.color,
    this.alignLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          alignLeft ? MainAxisAlignment.start : MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.swipe_rounded, color: color.withValues(alpha: 0.55), size: 13),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              color: color.withValues(alpha: 0.55),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

class _LikedBadge extends StatelessWidget {
  const _LikedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kLikedGreen, _kLikedGreenDeep],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kLikedGreen.withValues(alpha: 0.45),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '♥ Liked',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  final bool liked;
  final bool loading;
  final VoidCallback onTap;
  final bool compact;

  const _LikeButton({
    required this.liked,
    required this.loading,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 58.0 : 68.0;
    final iconSize = compact ? 28.0 : 32.0;

    return GestureDetector(
      onTap: loading || liked ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutBack,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: liked
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kLikedGreen, _kLikedGreenDeep],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kBrandPink, _kBrandPinkDeep],
                ),
          boxShadow: [
            BoxShadow(
              color: (liked ? _kLikedGreen : _kBrandPink)
                  .withValues(alpha: liked ? 0.65 : 0.55),
              blurRadius: liked ? 22 : 18,
              spreadRadius: liked ? 1 : 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: liked ? 0.95 : 0.55),
            width: 2.2,
          ),
        ),
        child: loading
            ? Padding(
                padding: EdgeInsets.all(size * 0.28),
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Icon(
                liked ? Icons.favorite_rounded : Icons.favorite_rounded,
                color: Colors.white,
                size: iconSize,
              ),
      ),
    );
  }
}

class _DmButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color accent;
  final Color primary;

  const _DmButton({
    required this.onTap,
    required this.accent,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                primary.withValues(alpha: 0.95),
                accent.withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Send a Message',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pick black or white text for contrast on [bg].
Color _readableOn(Color bg) {
  final luminance = bg.computeLuminance();
  return luminance > 0.55 ? const Color(0xFF1A1A1A) : Colors.white;
}
