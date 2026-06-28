import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/profile_provider.dart';
import '../../services/theme_service.dart';
import '../../theme/feed_card_theme.dart';
import '../../theme/feed_layout.dart';
import '../../core/constants.dart';
import '../../theme/discovery_background.dart';

class ThemePickerScreen extends ConsumerStatefulWidget {
  const ThemePickerScreen({super.key});

  @override
  ConsumerState<ThemePickerScreen> createState() => _ThemePickerScreenState();
}

class _ThemePickerScreenState extends ConsumerState<ThemePickerScreen> {
  final _themeService = ThemeService();
  String? _selectedBgVariantId;
  String? _selectedLayoutId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider).profile;
    _selectedBgVariantId = profile?.themeConfig?.bgVariantId;
    _selectedLayoutId = profile?.themeConfig?.layoutId ?? 'L01';
  }

  Future<void> _save() async {
    if (_selectedBgVariantId == null) return;
    setState(() => _isSaving = true);

    final theme = FeedCardThemeCatalog.resolve(_selectedBgVariantId);
    try {
      await _themeService.updateMyTheme(
        layoutId: _selectedLayoutId,
        bgId: theme.bgId,
        bgVariantId: _selectedBgVariantId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Theme updated! ✨'),
            backgroundColor: Color(0xFF1E1E1E),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: const Color(0xFF1E1E1E),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themes = FeedCardThemeCatalog.all;
    // Group by bgId
    final groups = <String, List<FeedCardTheme>>{};
    for (final t in themes) {
      groups.putIfAbsent(t.bgId, () => []).add(t);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C0C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Choose Theme',
          style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_selectedBgVariantId != null)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFFF2E74)),
                    )
                  : Text(
                      'Apply',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFF2E74),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF1E1E1E)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'LAYOUT TEMPLATE',
            style: GoogleFonts.outfit(
              color: const Color(0xFF888888),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: FeedLayoutCatalog.all.map((layout) {
              final selected = _selectedLayoutId == layout.layoutId;
              return GestureDetector(
                onTap: () =>
                    setState(() => _selectedLayoutId = layout.layoutId),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFFF2E74)
                        : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFFF2E74)
                          : const Color(0xFF333333),
                    ),
                  ),
                  child: Text(
                    '${layout.layoutId} ${layout.name}',
                    style: GoogleFonts.outfit(
                      color: selected ? Colors.white : const Color(0xFFAAAAAA),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          ...List.generate(groups.length, (groupIdx) {
          final bgId = groups.keys.elementAt(groupIdx);
          final variants = groups[bgId]!;
          final bgName = _bgName(bgId);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  '$bgId — $bgName',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF888888),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                if (DiscoveryBackgroundCatalog.patternLabelForBgId(bgId).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      DiscoveryBackgroundCatalog.patternLabelForBgId(bgId),
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF666666),
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: variants
                      .map((v) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: _ThemeChip(
                                theme: v,
                                isSelected:
                                    _selectedBgVariantId == v.variantId,
                                onTap: () => setState(
                                  () => _selectedBgVariantId = v.variantId,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _bgName(String bgId) =>
      AppConstants.backgroundNames[bgId] ?? bgId;
}

class _ThemeChip extends StatelessWidget {
  final FeedCardTheme theme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeChip({
    required this.theme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: isSelected ? 2.5 : 0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.25),
                        blurRadius: 12,
                      )
                    ]
                  : [],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                DiscoveryBackground(
                  spec: DiscoveryBackgroundCatalog.resolve(theme.variantId),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.25),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                if (isSelected)
                  const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            theme.name,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : const Color(0xFF888888),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
