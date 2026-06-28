import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String email;
  final bool isSignUp;
  final VoidCallback onVerified;
  final VoidCallback? onBack;

  const OtpScreen({
    super.key,
    required this.email,
    required this.isSignUp,
    required this.onVerified,
    this.onBack,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _ctrs =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  int _resendSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_nodes[0]);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrs) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        t.cancel();
      }
    });
  }

  String get _otp => _ctrs.map((c) => c.text).join();

  void _onDigitInput(String value, int index) {
    if (value.length > 1) {
      // Handle paste
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _ctrs[i].text = digits[i];
      }
      if (digits.length >= 6) _verify();
      return;
    }
    if (value.isNotEmpty && index < 5) {
      FocusScope.of(context).requestFocus(_nodes[index + 1]);
    }
    if (_otp.length == 6) _verify();
  }

  void _onBackspace(int index) {
    if (_ctrs[index].text.isEmpty && index > 0) {
      _ctrs[index - 1].clear();
      FocusScope.of(context).requestFocus(_nodes[index - 1]);
    }
  }

  Future<void> _verify() async {
    if (_otp.length != 6) return;
    final result = await ref.read(authProvider.notifier).verifyOtp(_otp);
    if (result != null && mounted) {
      widget.onVerified();
    }
  }

  Future<void> _resend() async {
    await ref
        .read(authProvider.notifier)
        .requestOtp(widget.email, isSignUp: widget.isSignUp);
    _startResendTimer();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Back button
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
              const SizedBox(height: 48),
              // Heading
              Text(
                'Verify your\nemail',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(
                      color: const Color(0xFF888888), fontSize: 15),
                  children: [
                    const TextSpan(text: 'We sent a 6-digit code to\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        color: Color(0xFFFF2E74),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 44),
              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _buildOtpBox(i, isLoading)),
              ),
              // Error
              if (authState.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A0E14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
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
                ),
              ],
              const SizedBox(height: 36),
              // Verify button
              GestureDetector(
                onTap: isLoading ? null : _verify,
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
                          'Verify →',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              // Resend
              Center(
                child: _resendSeconds > 0
                    ? Text(
                        'Resend code in ${_resendSeconds}s',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF555555),
                          fontSize: 14,
                        ),
                      )
                    : GestureDetector(
                        onTap: _resend,
                        child: Text(
                          'Resend code',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFFF2E74),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
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

  Widget _buildOtpBox(int index, bool disabled) {
    return SizedBox(
      width: 48,
      height: 58,
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) {
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            _onBackspace(index);
          }
        },
        child: TextFormField(
          controller: _ctrs[index],
          focusNode: _nodes[index],
          enabled: !disabled,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: const Color(0xFF1E1E1E),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF333333)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF2E74), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
            ),
          ),
          onChanged: (v) => _onDigitInput(v, index),
        ),
      ),
    );
  }
}
