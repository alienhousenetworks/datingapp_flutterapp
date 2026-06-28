import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';

class EmailScreen extends ConsumerStatefulWidget {
  final bool isSignUp;
  final VoidCallback onOtpSent;
  final VoidCallback? onBack;
  final VoidCallback? onSwitchToLogin;
  final VoidCallback? onSwitchToSignup;

  const EmailScreen({
    super.key,
    required this.isSignUp,
    required this.onOtpSent,
    this.onBack,
    this.onSwitchToLogin,
    this.onSwitchToSignup,
  });

  @override
  ConsumerState<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends ConsumerState<EmailScreen> {
  final _emailCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailCtrl.text.trim();
    final msg = await ref
        .read(authProvider.notifier)
        .requestOtp(email, isSignUp: widget.isSignUp);
    if (msg != null && mounted) {
      widget.onOtpSent();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                if (widget.onBack != null)
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF333333)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                if (widget.onBack != null) const SizedBox(height: 24),
                _AppLogoText(),
                const SizedBox(height: 52),
                // Title
                Text(
                  widget.isSignUp ? 'Create account' : 'Welcome back',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.isSignUp
                      ? 'Enter your email to get started'
                      : 'Enter your email to log in',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF888888),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 44),
                // Email label
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
                // Input
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
                              color: const Color(0xFFFF2E74).withOpacity(0.2),
                              blurRadius: 12,
                            )
                          ]
                        : [],
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextFormField(
                    controller: _emailCtrl,
                    focusNode: _focusNode,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                      hintText: 'you@example.com',
                      hintStyle: TextStyle(color: Color(0xFF444444)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(v)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                ),
                // Error message
                if (authState.error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A0E14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFFF2E74), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authState.error!,
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFFF2E74),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (authState.errorCode == 'email_exists' &&
                            widget.onSwitchToLogin != null) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: widget.onSwitchToLogin,
                            child: Text(
                              'Already have an account? Log in →',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (authState.errorCode == 'email_not_found' &&
                            widget.onSwitchToSignup != null) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: widget.onSwitchToSignup,
                            child: Text(
                              'No account yet? Create one →',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                // CTA button
                GestureDetector(
                  onTap: isLoading ? null : _submit,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF2E74), Color(0xFFE91E63)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF2E74).withOpacity(0.35),
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
                            'Get OTP →',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
                // Terms note
                Center(
                  child: Text(
                    'By continuing, you agree to our Terms & Privacy Policy',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF444444),
                      fontSize: 12,
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
}

class _AppLogoText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.5,
        ),
        children: const [
          TextSpan(text: 'sp', style: TextStyle(color: Colors.white)),
          TextSpan(
            text: 'y',
            style: TextStyle(
              color: Color(0xFFFF2E74),
              fontStyle: FontStyle.italic,
            ),
          ),
          TextSpan(text: 'ce', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
