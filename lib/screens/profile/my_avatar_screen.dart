import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/profile_model.dart';
import '../../providers/profile_provider.dart';
import '../../services/profile_service.dart';

class MyAvatarScreen extends ConsumerStatefulWidget {
  const MyAvatarScreen({super.key});

  @override
  ConsumerState<MyAvatarScreen> createState() => _MyAvatarScreenState();
}

class _MyAvatarScreenState extends ConsumerState<MyAvatarScreen> {
  final _profileService = ProfileService();
  List<AvatarModel> _avatars = [];
  bool _isLoading = true;
  String? _selectedAvatarId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAvatarsAndCurrent();
  }

  Future<void> _loadAvatarsAndCurrent() async {
    try {
      final avatars = await _profileService.getAvatars();
      final profile = ref.read(profileProvider).profile;
      if (mounted) {
        setState(() {
          _avatars = avatars;
          _selectedAvatarId = profile?.avatarId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load avatars: $e'),
            backgroundColor: const Color(0xFFFF2E74),
          ),
        );
      }
    }
  }

  Future<void> _saveAvatar() async {
    if (_selectedAvatarId == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _profileService.changeAvatar(_selectedAvatarId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Avatar updated successfully!', style: GoogleFonts.outfit()),
            backgroundColor: const Color(0xFF6AB04C),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update avatar: $e'),
            backgroundColor: const Color(0xFFFF2E74),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
        ),
        title: Text(
          'Choose Avatar',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2E74)),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _avatars.length,
                    itemBuilder: (context, index) {
                      final avatar = _avatars[index];
                      final isSelected = _selectedAvatarId == avatar.id;

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedAvatarId = avatar.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141416),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFFF2E74)
                                  : const Color(0xFF222222),
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFFF2E74).withOpacity(0.2),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : [],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: CachedNetworkImage(
                                  imageUrl: avatar.imageUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF2E74)),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, __, ___) => const Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.white24,
                                    size: 32,
                                  ),
                                ),
                              ),
                              if (avatar.style != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  color: Colors.black45,
                                  alignment: Alignment.center,
                                  child: Text(
                                    avatar.style!,
                                    style: GoogleFonts.outfit(
                                      color: isSelected ? Colors.white : Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: GestureDetector(
                      onTap: _saveAvatar,
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
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Save Avatar',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
