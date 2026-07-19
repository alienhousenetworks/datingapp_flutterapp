import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/paper_plane_model.dart';

/// Full profile bottom sheet shown when the recipient taps the sender's
/// avatar/name on the message reveal screen.
///
/// Usage:
/// ```dart
/// SenderProfileSheet.show(context, profile: result.senderProfile!,
///   deliveryId: result.deliveryId,
///   onConnect: _onConnect,
///   onPass: _onPass,
/// );
/// ```
class SenderProfileSheet extends StatefulWidget {
  final SenderProfileSnapshot profile;
  final String deliveryId;
  final VoidCallback? onConnect;
  final VoidCallback? onPass;
  final bool isActing;

  const SenderProfileSheet({
    super.key,
    required this.profile,
    required this.deliveryId,
    this.onConnect,
    this.onPass,
    this.isActing = false,
  });

  static Future<void> show(
    BuildContext context, {
    required SenderProfileSnapshot profile,
    required String deliveryId,
    VoidCallback? onConnect,
    VoidCallback? onPass,
    bool isActing = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      enableDrag: true,
      builder: (_) => SenderProfileSheet(
        profile: profile,
        deliveryId: deliveryId,
        onConnect: onConnect,
        onPass: onPass,
        isActing: isActing,
      ),
    );
  }

  @override
  State<SenderProfileSheet> createState() => _SenderProfileSheetState();
}

class _SenderProfileSheetState extends State<SenderProfileSheet> {
  int _currentPage = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ─── Colours ─────────────────────────────────────────────────
  static const _bg = Color(0xFF0E0E14);
  static const _surface = Color(0xFF1A1A24);
  static const _accent = Color(0xFFFF8C61);
  static const _accentDeep = Color(0xFFFF5C00);

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final size = MediaQuery.of(context).size;
    final sheetHeight = size.height * 0.92;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        height: sheetHeight,
        color: _bg,
        child: Column(
          children: [
            // ── Drag handle ──────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),

            // ── Scrollable content ───────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Image Carousel ───────────────────────────
                    _buildImageCarousel(profile, size),

                    // ── Profile Info ─────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(profile),
                          const SizedBox(height: 16),
                          if (profile.currentMoods.isNotEmpty) ...[
                            _buildMoodsRow(profile.currentMoods),
                            const SizedBox(height: 16),
                          ],
                          if (profile.bio.isNotEmpty) ...[
                            _buildSection('About', profile.bio),
                            const SizedBox(height: 16),
                          ],
                          if (profile.intents.isNotEmpty) ...[
                            _buildTagRow('Looking for', profile.intents),
                            const SizedBox(height: 16),
                          ],
                          if (profile.turnOns.isNotEmpty) ...[
                            _buildTagRow('Interests', profile.turnOns),
                            const SizedBox(height: 16),
                          ],
                          if (profile.hottakes.isNotEmpty) ...[
                            _buildHottakes(profile.hottakes),
                            const SizedBox(height: 16),
                          ],
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Action Buttons ───────────────────────────────────
            _buildActions(),
          ],
        ),
      ),
    );
  }

  // ─── Image carousel with dots ─────────────────────────────────
  Widget _buildImageCarousel(SenderProfileSnapshot profile, Size size) {
    final images = profile.profileImages;
    if (images.isEmpty) {
      return _buildPlaceholderAvatar(profile, size);
    }

    return SizedBox(
      height: size.height * 0.50,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              return Image.network(
                images[index].imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => _buildPlaceholderAvatar(profile, size),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: _surface,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                        color: _accent,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Gradient overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, _bg.withOpacity(0.95)],
                ),
              ),
            ),
          ),

          // Page indicator dots
          if (images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive ? _accent : Colors.white38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderAvatar(SenderProfileSnapshot profile, Size size) {
    return Container(
      height: size.height * 0.35,
      color: _surface,
      child: Center(
        child: CircleAvatar(
          radius: 56,
          backgroundColor: _accent.withOpacity(0.2),
          child: Text(
            (profile.name.isNotEmpty ? profile.name[0] : '?').toUpperCase(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: _accent,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header: name, username, age, city, online, verified ──────
  Widget _buildHeader(SenderProfileSnapshot profile) {
    final nameParts = <String>[];
    if (profile.name.isNotEmpty) nameParts.add(profile.name);
    if (profile.age != null) nameParts.add('${profile.age}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                nameParts.join(', '),
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            if (profile.isVerified)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A3AFF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1A3AFF).withOpacity(0.5),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 12, color: Color(0xFF5B8CFF)),
                    SizedBox(width: 3),
                    Text(
                      'Verified',
                      style: TextStyle(
                        color: Color(0xFF5B8CFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (profile.username.isNotEmpty) ...[
              Text(
                '@${profile.username}',
                style: GoogleFonts.plusJakartaSans(
                  color: _accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (profile.isOnline)
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E676),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Online now',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF00E676),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (profile.city.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 14, color: Colors.white38),
              const SizedBox(width: 4),
              Text(
                profile.city,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (profile.genderName != null) ...[
                const SizedBox(width: 10),
                const Text('·', style: TextStyle(color: Colors.white38)),
                const SizedBox(width: 10),
                Text(
                  profile.genderName!,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  // ─── Moods row ────────────────────────────────────────────────
  Widget _buildMoodsRow(List<SenderMood> moods) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: moods.map((m) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF8C61), Color(0xFFFF2E74)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            m.name,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Generic tag row (intents, turn-ons) ──────────────────────
  Widget _buildTagRow(String label, List<SenderMood> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                item.name,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Bio section ──────────────────────────────────────────────
  Widget _buildSection(String label, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Hot takes ────────────────────────────────────────────────
  Widget _buildHottakes(List<String> hottakes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('HOT TAKES'),
        const SizedBox(height: 8),
        ...hottakes.map((take) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _accentDeep.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accentDeep.withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🌶️ ', style: TextStyle(fontSize: 15)),
                    Expanded(
                      child: Text(
                        take,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  // ─── Action buttons ───────────────────────────────────────────
  Widget _buildActions() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          decoration: BoxDecoration(
            color: _bg.withOpacity(0.85),
            border: const Border(top: BorderSide(color: Color(0x14FFFFFF))),
          ),
          child: Row(
            children: [
              // Pass button
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton(
                    onPressed: widget.isActing
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop();
                            widget.onPass?.call();
                          },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      '✈️ Pass',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Connect button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF8C61), Color(0xFFFF5C00)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _accentDeep.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: widget.isActing
                          ? null
                          : () {
                              HapticFeedback.heavyImpact();
                              Navigator.of(context).pop();
                              widget.onConnect?.call();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: widget.isActing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              '❤️ Connect',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
