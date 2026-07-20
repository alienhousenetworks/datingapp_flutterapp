import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/subscription_service.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const SubscriptionScreen({super.key, required this.onComplete});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final _service = SubscriptionService();
  SubscriptionStatus? _status;
  bool _isLoading = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await _service.getStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _isLoading = false;
    });
    if (status.isFree || status.hasAccess) {
      widget.onComplete();
    }
  }

  Future<void> _useTrial() async {
    setState(() => _isPurchasing = true);
    await _service.startTrial();
    final status = await _service.getStatus();
    setState(() => _isPurchasing = false);
    if (!mounted) return;
    if (status.hasAccess) {
      widget.onComplete();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trial started! Enjoy premium features.'),
          backgroundColor: Color(0xFF1E1E1E),
        ),
      );
      widget.onComplete();
    }
  }

  Future<void> _subscribe() async {
    setState(() => _isPurchasing = true);
    try {
      await _service.purchase();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription flow initiated (payment gateway).'),
            backgroundColor: Color(0xFF1E1E1E),
          ),
        );
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFF1E1E1E),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0C0C),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF2E74)),
        ),
      );
    }

    final status = _status ?? const SubscriptionStatus();

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('⭐', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                'Unlock SPYCE Premium',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Unlimited DMs, profile boosts, and more.',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF888888),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 32),
              if (status.trialDays > 0) ...[
                _PlanTile(
                  title: '${status.trialDays}-Day Free Trial',
                  subtitle: 'Try all premium features first',
                  price: 'Free',
                  accent: const Color(0xFF00E676),
                  onTap: _isPurchasing ? null : _useTrial,
                ),
                const SizedBox(height: 14),
              ],
              _PlanTile(
                title: 'Subscribe Now',
                subtitle:
                    '${status.subscriptionDurationDays}-day premium access',
                price: '${status.currency} ${status.price}',
                accent: const Color(0xFFFFD700),
                onTap: _isPurchasing ? null : _subscribe,
              ),
              const Spacer(),
              Center(
                child: TextButton(
                  onPressed: _isPurchasing ? null : widget.onComplete,
                  child: Text(
                    'Maybe later',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF555555),
                      fontSize: 14,
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

class _PlanTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final Color accent;
  final VoidCallback? onTap;

  const _PlanTile({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.accent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF141416),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF888888),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: GoogleFonts.outfit(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

