import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'splash_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  bool _isFocused = false;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _emailController.text = "mayura@hk.com"; // Default email from the mockup
    _emailFocusNode.addListener(() {
      setState(() {
        _isFocused = _emailFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate OTP network request delay
    await Future.delayed(const Duration(milliseconds: 1200));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      // Navigate to Home Screen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // Logo left-aligned
                  const AppLogo(fontSize: 36),
                  
                  const SizedBox(height: 48),
                  
                  // Heading
                  Text(
                    'Welcome back',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Subtitle
                  Text(
                    'Enter your email to get started',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF7F7F7F),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Label
                  Text(
                    'EMAIL ADDRESS',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF555555),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Input text field with glowing container
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isFocused 
                            ? const Color(0xFFFF2E74) 
                            : const Color(0xFF333333),
                        width: 1.5,
                      ),
                      boxShadow: _isFocused
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF2E74).withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: TextFormField(
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Get OTP Button with ambient glow
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2E74).withOpacity(0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () {
                        if (_formKey.currentState!.validate()) {
                          _handleLogin();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF2E74),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Get OTP',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Demo Mode Tip Card
                  GestureDetector(
                    onTap: _handleLogin, // Bypass key to make it interactive and work instantly
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141416),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF222225),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '💡',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF666666),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                                children: [
                                  const TextSpan(text: 'Demo mode: backend offline? '),
                                  TextSpan(
                                    text: 'Just click the button — it\'ll skip to the app.',
                                    style: TextStyle(
                                      color: const Color(0xFF888888),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
      ),
    );
  }
}
