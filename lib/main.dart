import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const SpyceApp());
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
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
