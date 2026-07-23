import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../models/profile_model.dart';
import '../../providers/profile_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/shell_navigation_provider.dart';
import '../../providers/location_provider.dart';
import '../../theme/feed_card_theme.dart';
import '../../theme/discovery_background.dart';
import '../../utils/option_resolver.dart';
import '../../utils/profile_completeness.dart';
import '../../services/verification_service.dart';
import 'theme_picker_screen.dart';
import 'my_avatar_screen.dart';
import 'settings_screen.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(profileProvider.notifier).loadProfile();
      ref.read(optionsProvider.notifier).loadAll();
      ref.read(locationSyncProvider.notifier).syncToProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final locationState = ref.watch(locationSyncProvider);
    final profile = profileState.profile;

    ref.listen<ShellNavigationState>(shellNavigationProvider, (previous, next) {
      if (!next.openProfileEdit) return;
      final current = ref.read(profileProvider).profile;
      if (current == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showEditSheet(current);
          ref.read(shellNavigationProvider.notifier).clearEditRequest();
        }
      });
    });

    if (profileState.isLoading && profile == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0C0C),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF2E74)),
        ),
      );
    }

    if (profile == null) {
      return _buildNoProfile();
    }

    final bgSpec = DiscoveryBackgroundCatalog.resolveFromTheme(profile.themeConfig);
    final cardTheme = FeedCardThemeCatalog.resolve(
      profile.themeConfig?.bgVariantId ??
          (profile.themeConfig?.bgId != null
              ? FeedCardThemeCatalog.resolveFromBgId(profile.themeConfig!.bgId)
                  .variantId
              : null),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: Stack(
        children: [
          Positioned.fill(
            child: DiscoveryBackground(spec: bgSpec),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cardTheme.primaryColor.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(profile)),
              if (!profile.isDiscoverable)
                SliverToBoxAdapter(child: _buildDiscoverabilityBanner(profile)),
              SliverToBoxAdapter(child: _buildStats(profile)),
              SliverToBoxAdapter(
                  child: _buildSections(profile, locationState)),
              SliverToBoxAdapter(child: _buildActions()),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(UserProfile profile) {
    return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Profile',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Row(
                      children: [
                        // Edit button
                        _HeaderButton(
                          icon: Icons.edit_rounded,
                          onTap: () => _showEditSheet(profile),
                        ),
                        const SizedBox(width: 8),
                        // Settings
                        _HeaderButton(
                          icon: Icons.settings_outlined,
                          onTap: () => _showSettings(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFFF2E74), width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF2E74).withOpacity(0.4),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: profile.primaryImageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: profile.primaryImageUrl!,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: const Color(0xFF1E1E1E),
                                child: const Icon(Icons.person,
                                    color: Colors.white70, size: 52),
                              ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2E74),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: const Color(0xFF0C0C0C), width: 2),
                          ),
                          child: const Icon(Icons.add_a_photo,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '@${profile.username ?? 'username'}',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (profile.isIdentityVerified) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00BCD4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildDiscoverabilityBanner(UserProfile profile) {
    final missing = ProfileCompleteness.discoverBlockers(profile);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2A1520),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFF2E74).withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFFFF2E74), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Profile not discoverable yet',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ProfileCompleteness.missingFieldsMessage(profile),
              style: GoogleFonts.outfit(
                color: const Color(0xFFCCCCCC),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: missing
                    .map((m) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            m,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFFF2E74),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (missing.any((m) => m != 'Identity verification'))
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showEditSheet(profile),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF2E74),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Edit profile',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (missing.any((m) => m != 'Identity verification') &&
                    !profile.isIdentityVerified)
                  const SizedBox(width: 8),
                if (!profile.isIdentityVerified)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _mockVerify(profile),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C243B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF64B5F6)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Verify now',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64B5F6),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(UserProfile profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          _StatChip(label: profile.gender ?? '—', icon: Icons.person_outline),
          const SizedBox(width: 8),
          _StatChip(
              label: profile.sexuality ?? '—', icon: Icons.favorite_border),
          const SizedBox(width: 8),
          _StatChip(label: profile.intent ?? '—', icon: Icons.track_changes),
        ],
      ),
    );
  }

  Widget _buildSections(UserProfile profile, LocationSyncState locationState) {
    final options = ref.watch(optionsProvider);
    final languageLabels = OptionResolver.resolveList(
      profile.languages,
      options.languages,
    );
    final interestLabels = OptionResolver.resolveList(
      profile.turnOns,
      options.turnOns,
    );
    final preferredLabels = OptionResolver.resolveList(
      profile.preferredGenderIds,
      options.genders,
    );
    final ageText = profile.hideAge
        ? 'Hidden'
        : (profile.age != null
            ? '${profile.age} years old'
            : (profile.dateOfBirth != null
                ? _formatDob(profile.dateOfBirth!)
                : 'Not set'));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('Photos'),
          _buildPhotosSection(profile),
          _SectionHeader('Location'),
          _buildLocationSection(profile, locationState),
          _SectionHeader('Age'),
          _InfoCard(
            child: Row(
              children: [
                const Icon(Icons.cake_outlined,
                    color: Color(0xFFFF2E74), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ageText,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFCCCCCC),
                      fontSize: 14,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showEditSheet(profile),
                  child: Text(
                    'Edit',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFFF2E74),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _SectionHeader('Interested in'),
          _InfoCard(
            child: preferredLabels.isEmpty
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Not set — required for Discover',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF666666),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showEditSheet(profile),
                        child: Text(
                          'Add',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFFF2E74),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: preferredLabels.map((t) => _Tag(t)).toList(),
                  ),
          ),
          // Bio
          _SectionHeader('About me'),
          _InfoCard(
            child: profile.bio != null && profile.bio!.isNotEmpty
                ? Text(
                    profile.bio!,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFCCCCCC),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Not set',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF666666),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _showEditSheet(profile),
                        child: Text(
                          'Add',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFFF2E74),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          _SectionHeader('Interests'),
          _InfoCard(
            child: interestLabels.isEmpty
                ? Text('Not set',
                    style: GoogleFonts.outfit(
                        color: const Color(0xFF666666), fontSize: 14))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: interestLabels
                        .map((t) => _Tag(t))
                        .toList(),
                  ),
          ),
          _SectionHeader('Languages'),
          _InfoCard(
            child: languageLabels.isEmpty
                ? Text('Not set',
                    style: GoogleFonts.outfit(
                        color: const Color(0xFF666666), fontSize: 14))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: languageLabels
                        .map((l) => _Tag(l))
                        .toList(),
                  ),
          ),
          // Avatar
          _SectionHeader('Avatar'),
          GestureDetector(
            onTap: _openAvatarPicker,
            child: _InfoCard(
              child: Row(
                children: [
                  if (profile.avatarUrl != null)
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF333333)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CachedNetworkImage(
                        imageUrl: profile.avatarUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    const Icon(Icons.person_outline_rounded, color: Color(0xFFFF2E74), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      profile.avatarType != null
                          ? 'Style: ${profile.avatarType}'
                          : 'Choose placeholder avatar',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFCCCCCC),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF555555), size: 14),
                ],
              ),
            ),
          ),
          // Theme
          _SectionHeader('Theme'),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ThemePickerScreen(),
              ),
            ).then((_) {
              ref.read(profileProvider.notifier).loadProfile();
            }),
            child: _InfoCard(
              child: Row(
                children: [
                  const Icon(Icons.palette_outlined,
                      color: Color(0xFFFF2E74), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      profile.themeConfig?.bgId != null
                          ? 'BG: ${AppConstants.backgroundNames[profile.themeConfig!.bgId] ?? profile.themeConfig!.bgId}'
                              '${profile.themeConfig!.bgVariantId != null ? ' · ${_variantLabel(profile.themeConfig!.bgVariantId!)}' : ''}'
                              '  •  Layout: ${AppConstants.layoutNames[profile.themeConfig!.layoutId] ?? profile.themeConfig!.layoutId ?? "—"}'
                          : 'Tap to choose your theme',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFCCCCCC),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF555555), size: 14),
                ],
              ),
            ),
          ),
          // Verification
          _SectionHeader('Verification'),
          _InfoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      profile.isIdentityVerified
                          ? Icons.verified_rounded
                          : Icons.verified_outlined,
                      color: profile.isIdentityVerified
                          ? const Color(0xFF00BCD4)
                          : const Color(0xFF555555),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        profile.isIdentityVerified
                            ? 'Verified profile'
                            : 'Not verified — tap Verify for Discover',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFCCCCCC),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!profile.isIdentityVerified) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => _mockVerify(profile),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C243B),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF64B5F6)),
                        ),
                        child: Text(
                          'Verify',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF64B5F6),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          _ActionButton(
            label: 'Settings',
            icon: Icons.settings_outlined,
            color: const Color(0xFF555555),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _ActionButton(
            label: 'Subscription',
            icon: Icons.star_rounded,
            color: const Color(0xFFFFD700),
            onTap: _showSubscription,
          ),
          const SizedBox(height: 10),
          _ActionButton(
            label: 'Log out',
            icon: Icons.logout_rounded,
            color: const Color(0xFFFF2E74),
            onTap: _logout,
          ),
          const SizedBox(height: 10),
          _ActionButton(
            label: 'Delete account',
            icon: Icons.delete_forever_rounded,
            color: const Color(0xFF333333),
            textColor: const Color(0xFFCC4444),
            onTap: _confirmDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(
    UserProfile profile,
    LocationSyncState locationState,
  ) {
    final isSyncing = locationState.isSyncing;
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place_outlined,
                  color: Color(0xFFFF2E74), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  profile.hasLocation || profile.city != null
                      ? profile.locationLabel
                      : 'Location not set',
                  style: GoogleFonts.outfit(
                    color: profile.hasLocation || profile.city != null
                        ? const Color(0xFFCCCCCC)
                        : const Color(0xFF666666),
                    fontSize: 14,
                  ),
                ),
              ),
              if (isSyncing)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF2E74),
                  ),
                )
              else
                GestureDetector(
                  onTap: _syncLocation,
                  child: Text(
                    profile.hasLocation ? 'Update' : 'Enable',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFFF2E74),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          if (locationState.lastError != null) ...[
            const SizedBox(height: 8),
            Text(
              locationState.lastError!,
              style: GoogleFonts.outfit(
                color: const Color(0xFFFF2E74),
                fontSize: 12,
              ),
            ),
          ] else if (!profile.hasLocation && !isSyncing) ...[
            const SizedBox(height: 8),
            Text(
              'Allow location access so others can see your city and distance.',
              style: GoogleFonts.outfit(
                color: const Color(0xFF666666),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _syncLocation() async {
    final ok = await ref
        .read(locationSyncProvider.notifier)
        .syncToProfile(force: true);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location updated',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFF1E1E1E),
        ),
      );
      return;
    }
    final err = ref.read(locationSyncProvider).lastError ??
        'Could not update location';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err, style: GoogleFonts.outfit()),
        backgroundColor: const Color(0xFFFF2E74),
        action: SnackBarAction(
          label: 'Settings',
          textColor: Colors.white,
          onPressed: () => ref.read(locationServiceProvider).openAppSettings(),
        ),
      ),
    );
  }

  void _showEditSheet(UserProfile profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141416),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _EditProfileSheet(
        profile: profile,
        onSaved: () async {
          await ref.read(profileProvider.notifier).loadProfile();
          ref.read(feedProvider.notifier).loadFeed();
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
  }

  void _openAvatarPicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyAvatarScreen(),
      ),
    ).then((_) {
      ref.read(profileProvider.notifier).loadProfile();
      ref.read(feedProvider.notifier).loadFeed();
    });
  }

  Widget _buildPhotosSection(UserProfile profile) {
    final images = profile.images;
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: Container(
                    width: 72,
                    height: 72,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFF2E74),
                        width: 1.5,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo,
                            color: Color(0xFFFF2E74), size: 22),
                        SizedBox(height: 4),
                        Text(
                          'Add',
                          style: TextStyle(
                            color: Color(0xFFFF2E74),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ...images.map(
                  (img) => Container(
                    width: 72,
                    height: 72,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: img.url.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: img.url,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: const Color(0xFF1E1E1E),
                            child: const Icon(Icons.image,
                                color: Color(0xFF555555)),
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (images.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Add at least one photo so others can see you',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF666666),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _mockVerify(UserProfile profile) async {
    final result = await VerificationService().mockVerify();
    if (!mounted) return;
    if (result.success) {
      ref.read(profileProvider.notifier).setIdentityVerified(true);
      try {
        await ref.read(profileProvider.notifier).loadProfile();
      } catch (_) {}
      ref.read(feedProvider.notifier).loadFeed();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verified! You can use Discover now.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFF0C243B),
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.error ?? 'Verification failed. Try again or contact support.',
          style: GoogleFonts.outfit(),
        ),
        backgroundColor: const Color(0xFFFF2E74),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    try {
      await ref.read(profileServiceProvider).uploadImage(picked.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploading photo…',
                style: GoogleFonts.outfit()),
            backgroundColor: const Color(0xFF1E1E1E),
          ),
        );
      }
      await Future.delayed(const Duration(seconds: 2));
      await ref.read(profileProvider.notifier).loadProfile();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141416),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SettingsSheet(),
    );
  }

  Future<void> _showSubscription() async {
    final profileService = ref.read(profileServiceProvider);
    final status = await profileService.getSubscriptionStatus();
    if (!mounted) return;
    if (status['is_free'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Your profile has free access — no subscription needed.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFF1E1E1E),
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141416),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SubscriptionSheet(status: status),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Log out?',
            style: GoogleFonts.outfit(color: Colors.white)),
        content: Text('Are you sure you want to log out?',
            style: GoogleFonts.outfit(color: const Color(0xFF888888))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: const Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Log out',
                style: GoogleFonts.outfit(color: const Color(0xFFFF2E74))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }

  Future<void> _confirmDelete() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Delete account?',
            style: GoogleFonts.outfit(color: Colors.white)),
        content: Text(
          'This is permanent and cannot be undone. All your data will be deleted.',
          style: GoogleFonts.outfit(color: const Color(0xFF888888)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: const Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Delete',
                style: GoogleFonts.outfit(
                    color: const Color(0xFFCC4444),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _variantLabel(String variantId) {
    final theme = FeedCardThemeCatalog.resolve(variantId);
    return theme.name;
  }

  String _formatDob(String dob) {
    final parsed = DateTime.tryParse(dob);
    if (parsed == null) return dob;
    return DateFormat('MMM d, yyyy').format(parsed);
  }

  Widget _buildNoProfile() {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_off,
                color: Color(0xFF555555), size: 64),
            const SizedBox(height: 16),
            Text('No profile found',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontSize: 20)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () =>
                  ref.read(profileProvider.notifier).loadProfile(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF2E74)),
              child: Text('Retry',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Profile Sheet ──────────────────────────────────────
class _EditProfileSheet extends ConsumerStatefulWidget {
  final UserProfile profile;
  final VoidCallback onSaved;

  const _EditProfileSheet(
      {required this.profile, required this.onSaved});

  @override
  ConsumerState<_EditProfileSheet> createState() =>
      _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late TextEditingController _usernameCtrl;
  late TextEditingController _bioCtrl;
  DateTime? _dob;
  NamedOption? _selectedGender;
  NamedOption? _selectedSexuality;
  NamedOption? _selectedIntent;
  final Set<String> _selectedPreferredGenderIds = {};
  final Set<String> _selectedLanguageIds = {};
  final Set<String> _selectedTurnOnIds = {};
  bool _isSaving = false;
  String? _usernameError;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _usernameCtrl = TextEditingController(text: p.username ?? '');
    _bioCtrl = TextEditingController(text: p.bio ?? '');
    if (p.dateOfBirth != null) {
      _dob = DateTime.tryParse(p.dateOfBirth!);
    }
    _selectedPreferredGenderIds.addAll(p.preferredGenderIds);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindOptions());
  }

  void _bindOptions() {
    final options = ref.read(optionsProvider);
    final p = widget.profile;

    NamedOption? find(List<NamedOption> list, String? id) {
      if (id == null) return null;
      for (final o in list) {
        if (o.id == id) return o;
      }
      return null;
    }

    setState(() {
      _selectedGender = find(options.genders, p.genderId);
      _selectedSexuality = find(options.sexualities, p.sexualityId);
      _selectedIntent = find(options.intents, p.intentId);
      if (_selectedPreferredGenderIds.isEmpty) {
        _selectedPreferredGenderIds.addAll(
          OptionResolver.resolveIdSet(p.preferredGenderIds, options.genders),
        );
      }
      _selectedLanguageIds
        ..clear()
        ..addAll(OptionResolver.resolveIdSet(
          p.languageIds.isNotEmpty ? p.languageIds : p.languages,
          options.languages,
        ));
      _selectedTurnOnIds
        ..clear()
        ..addAll(OptionResolver.resolveIdSet(
          p.turnOnIds.isNotEmpty ? p.turnOnIds : p.turnOns,
          options.turnOns,
        ));
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkUsername(String username) async {
    if (username == widget.profile.username) {
      setState(() => _usernameError = null);
      return;
    }
    if (username.length < 3) return;
    final available =
        await ref.read(profileServiceProvider).isUsernameAvailable(username);
    setState(() {
      _usernameError = available ? null : 'Username already taken';
    });
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFF2E74),
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    final username = _usernameCtrl.text.trim().toLowerCase();
    if (username.length < 3 || _usernameError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid username',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFFFF2E74),
        ),
      );
      return;
    }
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Date of birth is required',
              style: GoogleFonts.outfit()),
          backgroundColor: const Color(0xFFFF2E74),
        ),
      );
      return;
    }
    if (_selectedPreferredGenderIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Select at least one gender under Interested in',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFFFF2E74),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final p = widget.profile;

    // Backend requires lat/lon on profile edits after onboarding.
    var lat = p.latitude;
    var lon = p.longitude;
    if (lat == null || lon == null) {
      await ref.read(locationSyncProvider.notifier).syncToProfile(force: true);
      final refreshed = ref.read(profileProvider).profile;
      lat = refreshed?.latitude ?? lat;
      lon = refreshed?.longitude ?? lon;
    }

    final data = <String, dynamic>{
      'username': username,
      'bio': _bioCtrl.text.trim(),
      'date_of_birth': DateFormat('yyyy-MM-dd').format(_dob!),
      'preferred_genders': _selectedPreferredGenderIds.toList(),
      if (_selectedIntent != null) 'intent': _selectedIntent!.id,
      if (_selectedLanguageIds.isNotEmpty)
        'languages': _selectedLanguageIds.toList(),
      if (_selectedTurnOnIds.isNotEmpty) 'turn_ons': _selectedTurnOnIds.toList(),
      if (lat != null && lon != null) ...{
        'latitude': lat,
        'longitude': lon,
      },
    };

    // Backend locks gender/sexuality once set — only send when still empty.
    if (p.genderId == null && _selectedGender != null) {
      data['gender'] = _selectedGender!.id;
    }
    if (p.sexualityId == null && _selectedSexuality != null) {
      data['sexuality'] = _selectedSexuality!.id;
    }

    final ok = await ref.read(profileProvider.notifier).updateProfile(data);
    setState(() => _isSaving = false);
    if (!mounted) return;

    if (!ok) {
      final err =
          ref.read(profileProvider).error ?? 'Could not save profile';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err, style: GoogleFonts.outfit()),
          backgroundColor: const Color(0xFFFF2E74),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final updated = ref.read(profileProvider).profile;
    if (updated != null && !updated.isDiscoverable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ProfileCompleteness.missingFieldsMessage(updated),
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: const Color(0xFF1E1E1E),
        ),
      );
    }
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(optionsProvider);
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: maxHeight,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  Text(
                    'Edit Profile',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Required for Discover',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF666666),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Username *'),
                    _inputField(
                      _usernameCtrl,
                      'e.g. stargazer_99',
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9_\.]')),
                        LengthLimitingTextInputFormatter(30),
                      ],
                      onChanged: (v) {
                        if (v.length >= 3) _checkUsername(v);
                      },
                    ),
                    if (_usernameError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _usernameError!,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFFF2E74),
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _fieldLabel('Date of birth *'),
                    GestureDetector(
                      onTap: _pickDob,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _dob != null
                                ? const Color(0xFFFF2E74)
                                : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          _dob != null
                              ? DateFormat('MMMM d, yyyy').format(_dob!)
                              : 'Tap to select birthday',
                          style: GoogleFonts.outfit(
                            color: _dob != null
                                ? Colors.white
                                : const Color(0xFF444444),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel('Gender *'),
                    widget.profile.genderId != null
                        ? _lockedField(widget.profile.gender ?? 'Set')
                        : _singleSelectChips(
                            options.genders,
                            _selectedGender,
                            (o) => setState(() => _selectedGender = o),
                          ),
                    const SizedBox(height: 16),
                    _fieldLabel('Sexuality *'),
                    widget.profile.sexualityId != null
                        ? _lockedField(widget.profile.sexuality ?? 'Set')
                        : _singleSelectChips(
                            options.sexualities,
                            _selectedSexuality,
                            (o) => setState(() => _selectedSexuality = o),
                          ),
                    const SizedBox(height: 16),
                    _fieldLabel('Interested in *'),
                    _multiSelectChips(
                      options.genders,
                      _selectedPreferredGenderIds,
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel('Looking for'),
                    _singleSelectChips(
                      options.intents,
                      _selectedIntent,
                      (o) => setState(() => _selectedIntent = o),
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel('Interests'),
                    _multiSelectChips(options.turnOns, _selectedTurnOnIds),
                    const SizedBox(height: 16),
                    _fieldLabel('Languages'),
                    _multiSelectChips(options.languages, _selectedLanguageIds),
                    const SizedBox(height: 16),
                    _fieldLabel('Bio'),
                    _inputField(_bioCtrl, 'Something about you...',
                        maxLines: 3),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF2E74),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)
                      : Text(
                          'Save Changes',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
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

  Widget _lockedField(String value) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.outfit(color: const Color(0xFF888888)),
              ),
            ),
            Text(
              'Locked',
              style: GoogleFonts.outfit(
                color: const Color(0xFF555555),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );

  Widget _fieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: const Color(0xFF888888),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _inputField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: GoogleFonts.outfit(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: const Color(0xFF444444)),
        filled: true,
        fillColor: const Color(0xFF1E1E1E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _singleSelectChips(
    List<NamedOption> options,
    NamedOption? selected,
    ValueChanged<NamedOption> onSelect,
  ) {
    if (options.isEmpty) {
      return Text(
        'Loading options...',
        style: GoogleFonts.outfit(color: const Color(0xFF666666), fontSize: 13),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (o) => GestureDetector(
              onTap: () => onSelect(o),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected?.id == o.id
                      ? const Color(0xFFFF2E74)
                      : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected?.id == o.id
                        ? const Color(0xFFFF2E74)
                        : const Color(0xFF333333),
                  ),
                ),
                child: Text(
                  o.name,
                  style: GoogleFonts.outfit(
                    color: selected?.id == o.id
                        ? Colors.white
                        : const Color(0xFFAAAAAA),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _multiSelectChips(
    List<NamedOption> options,
    Set<String> selectedIds,
  ) {
    if (options.isEmpty) {
      return Text(
        'Loading options...',
        style: GoogleFonts.outfit(color: const Color(0xFF666666), fontSize: 13),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (o) => GestureDetector(
              onTap: () => setState(() {
                if (selectedIds.contains(o.id)) {
                  selectedIds.remove(o.id);
                } else {
                  selectedIds.add(o.id);
                }
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selectedIds.contains(o.id)
                      ? const Color(0xFFFF2E74)
                      : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selectedIds.contains(o.id)
                        ? const Color(0xFFFF2E74)
                        : const Color(0xFF333333),
                  ),
                ),
                child: Text(
                  o.name,
                  style: GoogleFonts.outfit(
                    color: selectedIds.contains(o.id)
                        ? Colors.white
                        : const Color(0xFFAAAAAA),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─── Settings Sheet ──────────────────────────────────────────
class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Settings',
              style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          _SettingRow(icon: Icons.visibility_off, label: 'Hide age'),
          _SettingRow(icon: Icons.place_outlined, label: 'Hide distance'),
          _SettingRow(icon: Icons.notifications_outlined, label: 'Notifications'),
          _SettingRow(icon: Icons.block_outlined, label: 'Blocked users'),
          _SettingRow(icon: Icons.lock_outline, label: 'Privacy settings'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SettingRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF2E74), size: 20),
          const SizedBox(width: 14),
          Text(label,
              style: GoogleFonts.outfit(
                  color: Colors.white, fontSize: 15)),
          const Spacer(),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: Color(0xFF555555), size: 14),
        ],
      ),
    );
  }
}

// ─── Subscription Sheet ──────────────────────────────────────
class _SubscriptionSheet extends StatelessWidget {
  final Map<String, dynamic> status;

  const _SubscriptionSheet({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPremium =
        status['has_active_subscription'] ?? status['is_premium'] ?? false;
    final isFree = status['is_free'] ?? true;
    final tier = isFree ? 'free' : (isPremium ? 'premium' : 'trial');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('⭐', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            isPremium ? 'You\'re Premium!' : 'Go Premium',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPremium
                ? 'Current plan: $tier'
                : 'Unlock unlimited messaging, profile boosts, and more',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                color: const Color(0xFF888888), fontSize: 14),
          ),
          const SizedBox(height: 24),
          if (!isPremium) ...[
            _PlanCard(
                label: '3-Day Trial',
                price: 'Free',
                features: ['Try all premium features', 'No card required']),
            const SizedBox(height: 12),
            _PlanCard(
                label: 'Monthly',
                price: '₹299/mo',
                features: [
                  'Unlimited DMs',
                  'Profile boost',
                  'See who liked you'
                ]),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String label;
  final String price;
  final List<String> features;

  const _PlanCard(
      {required this.label,
      required this.price,
      required this.features});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              const Spacer(),
              Text(price,
                  style: GoogleFonts.outfit(
                      color: const Color(0xFFFFD700),
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF00E676), size: 14),
                    const SizedBox(width: 6),
                    Text(f,
                        style: GoogleFonts.outfit(
                            color: const Color(0xFFAAAAAA),
                            fontSize: 13)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StatChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2E)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFFF2E74), size: 16),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  color: const Color(0xFFCCCCCC),
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          color: const Color(0xFF555555),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF202024)),
      ),
      child: child,
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Text(label,
          style:
              GoogleFonts.outfit(color: const Color(0xFFAAAAAA), fontSize: 13)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color? textColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label,
                style: GoogleFonts.outfit(
                  color: textColor ?? Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}
