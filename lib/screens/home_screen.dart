import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_screen.dart';
import '../theme/square_splash_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class DatingProfile {
  final String name;
  final String gender;
  final String orientation;
  final String distance;
  final String mood;
  final String status;
  final int themeIndex;

  const DatingProfile({
    required this.name,
    required this.gender,
    required this.orientation,
    required this.distance,
    required this.mood,
    required this.status,
    required this.themeIndex,
  });
}

class _HomeScreenState extends State<HomeScreen> {
  final List<DatingProfile> _profiles = const [
    DatingProfile(
      name: 'VEASHNAVI',
      gender: 'Female',
      orientation: 'Heterosexual',
      distance: '0 KM away',
      mood: 'New friends',
      status: 'Recently Active',
      themeIndex: 0,
    ),
    DatingProfile(
      name: 'SURAJ',
      gender: 'Male',
      orientation: 'Heterosexual',
      distance: '2 KM away',
      mood: 'Dating',
      status: 'Online',
      themeIndex: 1,
    ),
    DatingProfile(
      name: 'ELINITY',
      gender: 'Female',
      orientation: 'Bisexual',
      distance: '5 KM away',
      mood: 'Deep chats',
      status: 'Active 2h ago',
      themeIndex: 2,
    ),
    DatingProfile(
      name: 'PRIYA',
      gender: 'Female',
      orientation: 'Heterosexual',
      distance: '1 KM away',
      mood: 'Coffee chats',
      status: 'Online',
      themeIndex: 3,
    ),
    DatingProfile(
      name: 'ROHIT',
      gender: 'Male',
      orientation: 'Heterosexual',
      distance: '3 KM away',
      mood: 'Music events',
      status: 'Active 10m ago',
      themeIndex: 4,
    ),
    DatingProfile(
      name: 'ANANYA',
      gender: 'Female',
      orientation: 'Bisexual',
      distance: '4 KM away',
      mood: 'Art galleries',
      status: 'Active 1h ago',
      themeIndex: 5,
    ),
    DatingProfile(
      name: 'KABIR',
      gender: 'Male',
      orientation: 'Heterosexual',
      distance: '6 KM away',
      mood: 'Hiking partners',
      status: 'Online',
      themeIndex: 6,
    ),
    DatingProfile(
      name: 'ISHA',
      gender: 'Female',
      orientation: 'Heterosexual',
      distance: '8 KM away',
      mood: 'Late night walks',
      status: 'Active 5h ago',
      themeIndex: 7,
    ),
  ];

  int _profileIndex = 0;
  late PageController _verticalPageController;

  @override
  void initState() {
    super.initState();
    _verticalPageController = PageController(initialPage: 0);
    // Initialize status bar style for first profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateStatusBarStyle(0);
    });
  }

  @override
  void dispose() {
    _verticalPageController.dispose();
    super.dispose();
  }

  void _updateStatusBarStyle(int index) {
    final themesList = SquareSplashTheme.themes;
    final theme = themesList[index % themesList.length];
    SystemChrome.setSystemUIOverlayStyle(theme.statusBarStyle);
  }

  void _handleLogout() {
    // Reset status bar style when leaving Home screen
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  void _nextProfile() {
    if (_profileIndex < _profiles.length - 1) {
      _verticalPageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      // Loop back to the first profile
      _verticalPageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    }
  }

  void _likeProfile() {
    final activeProfile = _profiles[_profileIndex];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'You liked ${activeProfile.name}! 💖',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFFF2E74),
        duration: const Duration(milliseconds: 800),
      ),
    );
    _nextProfile();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final themesList = SquareSplashTheme.themes;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Stack(
          children: [
            // Swipable Body Section (Vertical PageView for Profiles)
            Positioned.fill(
              child: PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _verticalPageController,
                itemCount: _profiles.length,
                clipBehavior: Clip.none,
                onPageChanged: (index) {
                  setState(() {
                    _profileIndex = index;
                  });
                  _updateStatusBarStyle(index);
                },
                itemBuilder: (context, index) {
                  final profile = _profiles[index];
                  final theme = themesList[profile.themeIndex % themesList.length];
                  
                  return SquareSplashBackground(
                    theme: theme,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 52.0, bottom: 98.0),
                      child: ProfileHorizontalSwipeView(
                        profile: profile,
                        screenWidth: screenWidth,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Static Top Header (stays in place fixed when swiping profiles)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'spyce',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white70,
                        size: 24,
                      ),
                      onPressed: _handleLogout,
                    ),
                  ],
                ),
              ),
            ),

            // Static Heart Button at the bottom (stays in place fixed when swiping profiles)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _likeProfile,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFF2E74),
                          Color(0xFFE91E63),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2E74).withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
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
}

class ProfileHorizontalSwipeView extends StatefulWidget {
  final DatingProfile profile;
  final double screenWidth;

  const ProfileHorizontalSwipeView({
    super.key,
    required this.profile,
    required this.screenWidth,
  });

  @override
  State<ProfileHorizontalSwipeView> createState() => _ProfileHorizontalSwipeViewState();
}

class _ProfileHorizontalSwipeViewState extends State<ProfileHorizontalSwipeView> {
  late PageController _horizontalPageController;

  @override
  void initState() {
    super.initState();
    _horizontalPageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _horizontalPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _horizontalPageController,
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
      children: [
        // Page 1: Details View
        _buildDetailsPage(widget.profile, widget.screenWidth),
        // Page 2: Photo Gallery View
        _buildGalleryPage(widget.profile, widget.screenWidth),
      ],
    );
  }

  // DETAILS PAGE (First slide)
  Widget _buildDetailsPage(DatingProfile profile, double screenWidth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  // Polaroid Card centered & sized to prevent edge collision
                  Transform.rotate(
                    angle: -0.035, // Subtle tilt
                    child: SizedBox(
                      width: screenWidth > 400 ? 230.0 : screenWidth * 0.58,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          // White Polaroid Frame
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.only(
                              top: 10.0,
                              left: 10.0,
                              right: 10.0,
                              bottom: 40.0, // Polaroid bottom spacing
                            ),
                            child: AspectRatio(
                              aspectRatio: 0.90,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F3F4), // Placeholder inside frame
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    'No Image',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF9E9E9E),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Favourite Track overlay
                          Positioned(
                            right: 4,
                            bottom: 24,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Transform.rotate(
                                  angle: 0.2,
                                  child: Text(
                                    'Favourite track',
                                    style: GoogleFonts.playfairDisplay(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.italic,
                                      shadows: [
                                        const Shadow(
                                          color: Colors.black45,
                                          blurRadius: 3,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF7B1FA2),
                                    border: Border.all(color: Colors.white, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.music_note_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Chunky yellow name
                  Text(
                    profile.name,
                    style: GoogleFonts.lilitaOne(
                      color: const Color(0xFFFFEB3B),
                      fontSize: 32,
                      letterSpacing: 1.0,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Pills
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildOutlinePill(profile.gender),
                      const SizedBox(width: 8),
                      _buildOutlinePill(profile.orientation),
                    ],
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Location & Status
                  _buildLocationAndStatus(profile),
                  
                  const SizedBox(height: 12),
                  
                  // Mood Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C243B).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: Text(
                      'Mood: ${profile.mood}',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Hint text to swipe
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'SWIPE LEFT FOR GALLERY',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white.withOpacity(0.6),
                        size: 12,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLocationAndStatus(DatingProfile profile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '📍 ${profile.distance}',
          style: GoogleFonts.outfit(
            color: const Color(0xFFFFEB3B),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '•',
          style: TextStyle(color: Color(0xFFFFEB3B), fontSize: 13),
        ),
        const SizedBox(width: 8),
        Text(
          '🕒 ${profile.status}',
          style: GoogleFonts.outfit(
            color: const Color(0xFFFFEB3B),
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // PHOTO GALLERY PAGE (Second slide)
  Widget _buildGalleryPage(DatingProfile profile, double screenWidth) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title: PHOTO GALLERY
                  Text(
                    'PHOTO GALLERY',
                    style: GoogleFonts.lilitaOne(
                      color: const Color(0xFFFFEB3B),
                      fontSize: 30,
                      letterSpacing: 1.0,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Dark Gallery container matching design
                  Container(
                    width: screenWidth > 400 ? 230.0 : screenWidth * 0.58,
                    height: (screenWidth > 400 ? 230.0 : screenWidth * 0.58) * 1.14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C243B).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.08),
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'No other images',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Swipable Pill indicators [icon] SWIPE LEFT FOR DETAILS [icon]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          _horizontalPageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SWIPE LEFT FOR DETAILS',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          _horizontalPageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E3A5F).withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_forward, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOutlinePill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
