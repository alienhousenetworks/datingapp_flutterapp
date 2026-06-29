import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'services/onboarding_service.dart';
import 'utils/profile_completeness.dart';
import 'services/storage_service.dart';
import 'services/subscription_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/email_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/subscription/subscription_screen.dart';
import 'navigation/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const ProviderScope(child: SpyceApp()));
}

class SpyceApp extends StatelessWidget {
  const SpyceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'spyce',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0C0C0C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF2E74),
          secondary: Color(0xFFFF2E74),
          surface: Color(0xFF141416),
        ),
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData.dark().textTheme,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0C0C0C),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const _AppRouter(),
    );
  }
}

class _AppRouter extends ConsumerStatefulWidget {
  const _AppRouter();

  @override
  ConsumerState<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<_AppRouter> {
  _Route _currentRoute = _Route.splash;
  bool _isSignUp = true;
  bool _initialized = false;

  final _onboardingService = OnboardingService();

  @override
  void initState() {
    super.initState();
    _resolveInitialRoute();
  }

  Future<void> _resolveInitialRoute() async {
    final loggedIn = await StorageService.isLoggedIn();
    if (!mounted) return;

    if (loggedIn) {
      final route = await _routeAfterAuthentication();
      if (!mounted) return;
      setState(() {
        _currentRoute = route;
        _initialized = true;
      });
      return;
    }

    setState(() => _initialized = true);
  }

  /// Uses GET /profile/me/ + is_discoverable — not the local onboarding flag.
  Future<_Route> _routeAfterAuthentication() async {
    try {
      final profile = await _onboardingService.fetchMyProfile();
      final complete = profile.isDiscoverable;
      await _onboardingService.syncLocalOnboardingFlag(complete: complete);

      if (!complete) {
        // Existing DB users with partial data complete missing fields in-app.
        if (ProfileCompleteness.hasPartialProfile(profile)) {
          if (await _onboardingService.needsSubscriptionGate()) {
            return _Route.subscription;
          }
          return _Route.main;
        }
        return _Route.onboarding;
      }

      if (await _onboardingService.needsSubscriptionGate()) {
        return _Route.subscription;
      }
      return _Route.main;
    } catch (_) {
      // Offline / transient error: fall back to cached flag so users aren't stuck.
      final cached = await StorageService.isOnboardingDone();
      return cached ? _Route.main : _Route.onboarding;
    }
  }

  Future<void> _afterOnboarding() async {
    final complete = await _onboardingService.isProfileComplete();
    await _onboardingService.syncLocalOnboardingFlag(complete: complete);
    final sub = await SubscriptionService().getStatus();
    if (!mounted) return;
    if (!complete) {
      setState(() => _currentRoute = _Route.main);
      return;
    }
    if (sub.isFree || sub.hasAccess) {
      setState(() => _currentRoute = _Route.main);
    } else {
      setState(() => _currentRoute = _Route.subscription);
    }
  }

  Future<void> _afterOtp() async {
    setState(() => _initialized = false);
    final route = await _routeAfterAuthentication();
    if (!mounted) return;
    setState(() {
      _currentRoute = route;
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    if (authState.status == AuthStatus.unauthenticated &&
        _currentRoute == _Route.main) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentRoute = _Route.splash);
      });
    }

    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0C0C),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF2E74)),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
      child: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentRoute) {
      case _Route.splash:
        return SplashScreen(
          key: const ValueKey('splash'),
          onGetStarted: () => setState(() {
            _isSignUp = true;
            _currentRoute = _Route.emailSignup;
          }),
          onLogin: () => setState(() {
            _isSignUp = false;
            _currentRoute = _Route.emailLogin;
          }),
        );

      case _Route.emailSignup:
        return EmailScreen(
          key: const ValueKey('email-signup'),
          isSignUp: true,
          onBack: () => setState(() => _currentRoute = _Route.splash),
          onOtpSent: () => setState(() => _currentRoute = _Route.otp),
          onSwitchToLogin: () => setState(() {
            _isSignUp = false;
            _currentRoute = _Route.emailLogin;
            ref.read(authProvider.notifier).clearError();
          }),
        );

      case _Route.emailLogin:
        return EmailScreen(
          key: const ValueKey('email-login'),
          isSignUp: false,
          onBack: () => setState(() => _currentRoute = _Route.splash),
          onOtpSent: () => setState(() => _currentRoute = _Route.otp),
          onSwitchToSignup: () => setState(() {
            _isSignUp = true;
            _currentRoute = _Route.emailSignup;
            ref.read(authProvider.notifier).clearError();
          }),
          onBypassLogin: () => setState(() => _currentRoute = _Route.main),
        );

      case _Route.otp:
        return OtpScreen(
          key: const ValueKey('otp'),
          email: ref.read(authProvider).email ?? '',
          isSignUp: _isSignUp,
          onBack: () => setState(() {
            _currentRoute =
                _isSignUp ? _Route.emailSignup : _Route.emailLogin;
          }),
          onVerified: _afterOtp,
        );

      case _Route.onboarding:
        return OnboardingScreen(
          key: const ValueKey('onboarding'),
          onComplete: _afterOnboarding,
        );

      case _Route.subscription:
        return SubscriptionScreen(
          key: const ValueKey('subscription'),
          onComplete: () => setState(() => _currentRoute = _Route.main),
        );

      case _Route.main:
        return const MainShell(key: ValueKey('main'));
    }
  }
}

enum _Route {
  splash,
  emailSignup,
  emailLogin,
  otp,
  onboarding,
  subscription,
  main,
}