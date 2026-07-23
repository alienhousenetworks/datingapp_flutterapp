import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C0C),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _SettingsSection(
            title: 'Privacy',
            items: [
              _SettingsItem(
                icon: Icons.visibility_off_outlined,
                label: 'Hide age',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.place_outlined,
                label: 'Hide distance',
                onTap: () {},
              ),
              _SettingsItem(
                icon: Icons.lock_outline_rounded,
                label: 'Privacy settings',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Notifications',
            items: [
              _SettingsItem(
                icon: Icons.notifications_outlined,
                label: 'Push notifications',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsSection(
            title: 'Account',
            items: [
              _SettingsItem(
                icon: Icons.block_outlined,
                label: 'Blocked users',
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section with title + grouped items ─────────────────────
class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: GoogleFonts.outfit(
              color: const Color(0xFF555555),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141416),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF202024)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFF202024),
                    indent: 48,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Individual settings row ─────────────────────────────────
class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFF2E74), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFF555555), size: 14),
          ],
        ),
      ),
    );
  }
}
