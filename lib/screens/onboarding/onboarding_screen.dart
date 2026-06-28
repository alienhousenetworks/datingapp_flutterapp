import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../models/profile_model.dart';
import '../../providers/profile_provider.dart';
import '../../services/storage_service.dart';
import '../../services/profile_service.dart';
import '../../services/onboarding_service.dart';
import '../../utils/profile_completeness.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  static const int _totalPages = 11;

  // Form state
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  DateTime? _dob;
  NamedOption? _selectedGender;
  NamedOption? _selectedSexuality;
  NamedOption? _selectedIntent;
  final Set<String> _selectedLanguageIds = {};
  final Set<String> _selectedTurnOnIds = {};
  final Set<String> _selectedPreferredGenderIds = {};
  File? _profileImage;
  bool _isSaving = false;
  bool _verificationDone = false;
  String? _usernameError;

  final _profileService = ProfileService();
  final _imagePicker = ImagePicker();

  static const int _lastRequiredPage = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(optionsProvider.notifier).loadAll();
      await _skipIfAlreadyComplete();
    });
  }

  Future<void> _skipIfAlreadyComplete() async {
    try {
      final profile = await OnboardingService().fetchMyProfile();
      if (!mounted) return;
      if (profile.isDiscoverable) {
        await StorageService.setOnboardingDone(true);
        widget.onComplete();
        return;
      }
      await _prefillFromProfile(profile);
    } catch (_) {}
  }

  Future<void> _prefillFromProfile(UserProfile profile) async {
    if (profile.username?.isNotEmpty ?? false) {
      _usernameCtrl.text = profile.username!;
    }
    if (profile.bio?.isNotEmpty ?? false) {
      _bioCtrl.text = profile.bio!;
    }
    if (profile.dateOfBirth != null) {
      _dob = DateTime.tryParse(profile.dateOfBirth!);
    }

    final options = ref.read(optionsProvider);
    NamedOption? findOption(List<NamedOption> list, String? id) {
      if (id == null) return null;
      for (final o in list) {
        if (o.id == id) return o;
      }
      return null;
    }

    _selectedGender = findOption(options.genders, profile.genderId);
    _selectedSexuality = findOption(options.sexualities, profile.sexualityId);
    _selectedIntent = findOption(options.intents, profile.intentId);
    _selectedPreferredGenderIds.addAll(profile.preferredGenderIds);
    _selectedLanguageIds.addAll(
      profile.languageIds.isNotEmpty ? profile.languageIds : profile.languages,
    );
    _selectedTurnOnIds.addAll(
      profile.turnOnIds.isNotEmpty ? profile.turnOnIds : profile.turnOns,
    );

    if (!mounted) return;
    setState(() {});
    _jumpToFirstMissingPage();
  }

  void _jumpToFirstMissingPage() {
    var page = 0;
    if (_usernameCtrl.text.trim().length >= 3) page = 1;
    if (_dob != null) page = 2;
    if (_selectedGender != null) page = 3;
    if (_selectedSexuality != null) page = 4;
    if (_selectedPreferredGenderIds.isNotEmpty) page = 5;
    if (page > 0 && page < _totalPages) {
      _pageCtrl.jumpToPage(page);
      setState(() => _currentPage = page);
    }
  }

  bool _canSkipCurrentPage() => _currentPage > _lastRequiredPage;

  bool _hasRequiredFields() =>
      _usernameCtrl.text.trim().length >= 3 &&
      _usernameError == null &&
      _dob != null &&
      _selectedGender != null &&
      _selectedSexuality != null &&
      _selectedPreferredGenderIds.isNotEmpty;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _totalPages - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  Future<void> _checkUsername(String username) async {
    if (username.length < 3) return;
    final available =
        await ref.read(profileServiceProvider).isUsernameAvailable(username);
    setState(() {
      _usernameError = available ? null : 'Username already taken';
    });
  }

  Future<void> _finish() async {
    if (!_hasRequiredFields()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please complete: ${ProfileCompleteness.missingCoreFields(_draftProfile()).join(', ')}',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: const Color(0xFFFF2E74),
          ),
        );
      }
      _jumpToFirstMissingPage();
      return;
    }

    setState(() => _isSaving = true);
    try {
      final langs = ref
          .read(optionsProvider)
          .languages
          .where((l) => _selectedLanguageIds.contains(l.id))
          .map((l) => l.id)
          .toList();

      final turnOns = ref
          .read(optionsProvider)
          .turnOns
          .where((t) => _selectedTurnOnIds.contains(t.id))
          .map((t) => t.id)
          .toList();

      final profileData = {
        if (_usernameCtrl.text.isNotEmpty) 'username': _usernameCtrl.text.trim(),
        if (_dob != null)
          'date_of_birth': DateFormat('yyyy-MM-dd').format(_dob!),
        if (_selectedGender != null) 'gender': _selectedGender!.id,
        if (_selectedSexuality != null) 'sexuality': _selectedSexuality!.id,
        if (_selectedIntent != null) 'intent': _selectedIntent!.id,
        if (_selectedPreferredGenderIds.isNotEmpty)
          'preferred_genders': _selectedPreferredGenderIds.toList(),
        if (_bioCtrl.text.isNotEmpty) 'bio': _bioCtrl.text.trim(),
        if (langs.isNotEmpty) 'languages': langs,
        if (turnOns.isNotEmpty) 'turn_ons': turnOns,
      };

      // Create/update profile
      await ref.read(profileProvider.notifier).updateProfile(profileData);

      // Upload image if selected
      if (_profileImage != null) {
        try {
          await _profileService.uploadImage(_profileImage!.path);
        } catch (_) {}
      }

      final updated = await OnboardingService().fetchMyProfile();
      await StorageService.setOnboardingDone(updated.isDiscoverable);
      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFFF2E74),
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  UserProfile _draftProfile() => UserProfile(
        id: '',
        username: _usernameCtrl.text.trim(),
        dateOfBirth:
            _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : null,
        genderId: _selectedGender?.id,
        sexualityId: _selectedSexuality?.id,
        preferredGenderIds: _selectedPreferredGenderIds.toList(),
      );

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(optionsProvider);
    final progress = (_currentPage + 1) / _totalPages;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Column(
          children: [
            // Progress header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_currentPage > 0)
                        GestureDetector(
                          onTap: _back,
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded,
                                color: Colors.white, size: 14),
                          ),
                        ),
                      if (_currentPage > 0) const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Step ${_currentPage + 1} of $_totalPages',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF555555),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: const Color(0xFF1E1E1E),
                                valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFFFF2E74)),
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_canSkipCurrentPage())
                        GestureDetector(
                          onTap:
                              _currentPage < _totalPages - 1 ? _next : null,
                          child: Text(
                            'Skip',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF555555),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Page view
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  // Page 0: Username
                  _StepPage(
                    emoji: '✨',
                    title: 'Choose your\nusername',
                    subtitle: 'This is how others will find you',
                    child: _buildUsernameStep(),
                    onNext: _next,
                  ),
                  // Page 1: Date of birth
                  _StepPage(
                    emoji: '🎂',
                    title: 'When were\nyou born?',
                    subtitle: 'Your age may be visible to others',
                    child: _buildDobStep(),
                    onNext: _next,
                  ),
                  // Page 2: Gender
                  _StepPage(
                    emoji: '👤',
                    title: 'I identify\nas...',
                    subtitle: 'This helps us show you relevant matches',
                    child: _buildSingleSelectStep(
                      options.genders,
                      _selectedGender,
                      (o) => setState(() => _selectedGender = o),
                      isLoading: options.isLoading,
                    ),
                    onNext: _next,
                  ),
                  // Page 3: Sexuality
                  _StepPage(
                    emoji: '🌈',
                    title: 'My sexuality\nis...',
                    subtitle: 'We respect all identities',
                    child: _buildSingleSelectStep(
                      options.sexualities,
                      _selectedSexuality,
                      (o) => setState(() => _selectedSexuality = o),
                      isLoading: options.isLoading,
                    ),
                    onNext: _next,
                  ),
                  // Page 4: Preferred genders
                  _StepPage(
                    emoji: '💕',
                    title: "I'm interested\nin...",
                    subtitle: 'Who would you like to meet?',
                    child: _buildMultiSelectStep(
                      options.genders,
                      _selectedPreferredGenderIds,
                      isLoading: options.isLoading,
                    ),
                    onNext: _next,
                  ),
                  // Page 5: Intent
                  _StepPage(
                    emoji: '🎯',
                    title: "I'm looking\nfor...",
                    subtitle: 'What brings you here?',
                    child: _buildSingleSelectStep(
                      options.intents,
                      _selectedIntent,
                      (o) => setState(() => _selectedIntent = o),
                      isLoading: options.isLoading,
                    ),
                    onNext: _next,
                  ),
                  // Page 6: Turn-ons
                  _StepPage(
                    emoji: '💫',
                    title: "I'm into...",
                    subtitle: 'Select all that apply',
                    child: _buildMultiSelectStep(
                      options.turnOns,
                      _selectedTurnOnIds,
                      isLoading: options.isLoading,
                    ),
                    onNext: _next,
                  ),
                  // Page 7: Languages
                  _StepPage(
                    emoji: '🌍',
                    title: 'I speak...',
                    subtitle: 'Select the languages you use',
                    child: _buildMultiSelectStep(
                      options.languages,
                      _selectedLanguageIds,
                      isLoading: options.isLoading,
                    ),
                    onNext: _next,
                  ),
                  // Page 8: Bio
                  _StepPage(
                    emoji: '💬',
                    title: 'Tell us about\nyourself',
                    subtitle: 'Optional — skip if you prefer',
                    child: _buildBioStep(),
                    onNext: _next,
                  ),
                  // Page 9: Profile photo
                  _StepPage(
                    emoji: '📸',
                    title: 'Add a\nphoto',
                    subtitle: 'Optional — you can add more later',
                    child: _buildPhotoStep(),
                    onNext: _next,
                  ),
                  // Page 10: Verification (mock)
                  _StepPage(
                    emoji: '✅',
                    title: 'Verify your\nprofile',
                    subtitle: 'Optional — boosts trust (mock for now)',
                    child: _buildVerificationStep(),
                    onNext: _finish,
                    nextLabel: _isSaving ? 'Saving...' : "Let's go! →",
                    isLoading: _isSaving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameStep() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _usernameError != null
                  ? const Color(0xFFFF2E74)
                  : const Color(0xFF333333),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextFormField(
            controller: _usernameCtrl,
            style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'e.g. stargazer_99',
              hintStyle: GoogleFonts.outfit(color: const Color(0xFF444444)),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_\.]')),
              LengthLimitingTextInputFormatter(30),
            ],
            onChanged: (v) {
              if (v.length >= 3) _checkUsername(v);
            },
          ),
        ),
        if (_usernameError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline,
                  color: Color(0xFFFF2E74), size: 14),
              const SizedBox(width: 6),
              Text(
                _usernameError!,
                style: GoogleFonts.outfit(
                    color: const Color(0xFFFF2E74), fontSize: 13),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFF555555), size: 14),
            const SizedBox(width: 6),
            Text(
              'Only letters, numbers, _ and .',
              style: GoogleFonts.outfit(
                  color: const Color(0xFF555555), fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDobStep() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(2000),
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
      },
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _dob != null
                ? const Color(0xFFFF2E74)
                : const Color(0xFF333333),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: Color(0xFFFF2E74), size: 20),
            const SizedBox(width: 12),
            Text(
              _dob != null
                  ? DateFormat('MMMM d, yyyy').format(_dob!)
                  : 'Tap to select your birthday',
              style: GoogleFonts.outfit(
                color: _dob != null ? Colors.white : const Color(0xFF666666),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleSelectStep(
    List<NamedOption> options,
    NamedOption? selected,
    Function(NamedOption) onSelect, {
    bool isLoading = false,
  }) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF2E74)),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options
          .map(
            (o) => GestureDetector(
              onTap: () => onSelect(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: selected?.id == o.id
                      ? const Color(0xFFFF2E74)
                      : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: selected?.id == o.id
                        ? const Color(0xFFFF2E74)
                        : const Color(0xFF333333),
                  ),
                  boxShadow: selected?.id == o.id
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF2E74).withOpacity(0.3),
                            blurRadius: 8,
                          )
                        ]
                      : [],
                ),
                child: Text(
                  o.name,
                  style: GoogleFonts.outfit(
                    color: selected?.id == o.id
                        ? Colors.white
                        : const Color(0xFFAAAAAA),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMultiSelectStep(
    List<NamedOption> options,
    Set<String> selectedIds, {
    bool isLoading = false,
  }) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF2E74)),
      );
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: selectedIds.contains(o.id)
                      ? const Color(0xFFFF2E74)
                      : const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(30),
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
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBioStep() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: _bioCtrl,
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
        maxLines: 5,
        maxLength: 300,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Write something interesting about yourself...',
          hintStyle: GoogleFonts.outfit(color: const Color(0xFF444444)),
          counterStyle:
              GoogleFonts.outfit(color: const Color(0xFF555555), fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildVerificationStep() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _verificationDone
                  ? const Color(0xFF00BCD4)
                  : const Color(0xFF333333),
            ),
          ),
          child: Column(
            children: [
              Icon(
                _verificationDone
                    ? Icons.verified_rounded
                    : Icons.verified_outlined,
                color: _verificationDone
                    ? const Color(0xFF00BCD4)
                    : const Color(0xFF555555),
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                _verificationDone
                    ? 'Verification submitted!'
                    : 'Get a verified badge',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mock verification — real selfie check coming soon.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF888888),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!_verificationDone)
          GestureDetector(
            onTap: () {
              setState(() => _verificationDone = true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Verification submitted (mock)',
                    style: GoogleFonts.outfit(),
                  ),
                  backgroundColor: const Color(0xFF0C243B),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF0C243B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF64B5F6)),
              ),
              alignment: Alignment.center,
              child: Text(
                'Verify Now',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF64B5F6),
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPhotoStep() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(80),
              border: Border.all(
                color: _profileImage != null
                    ? const Color(0xFFFF2E74)
                    : const Color(0xFF333333),
                width: 2,
              ),
              boxShadow: _profileImage != null
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF2E74).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ]
                  : [],
            ),
            clipBehavior: Clip.antiAlias,
            child: _profileImage != null
                ? Image.file(_profileImage!, fit: BoxFit.cover)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_rounded,
                          color: Color(0xFFFF2E74), size: 40),
                      const SizedBox(height: 8),
                      Text(
                        'Add photo',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF888888),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Profiles with photos get\n10x more attention',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: const Color(0xFF888888),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ─── Step Page Wrapper ───────────────────────────────────────

class _StepPage extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onNext;
  final String? nextLabel;
  final bool isLoading;

  const _StepPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onNext,
    this.nextLabel,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              color: const Color(0xFF888888),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(child: child),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: isLoading ? null : onNext,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF2E74), Color(0xFFE91E63)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF2E74).withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      nextLabel ?? 'Continue →',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}


