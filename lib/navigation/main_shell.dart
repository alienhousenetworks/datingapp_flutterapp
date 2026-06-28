import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/feed/feed_screen.dart';
import '../screens/chat/conversations_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/confessions/confessions_screen.dart';
import '../screens/profile/my_profile_screen.dart';
import '../providers/shell_navigation_provider.dart';
import '../providers/location_provider.dart';
import '../providers/feed_provider.dart';
import '../providers/call_manager_provider.dart';
import '../providers/chat_provider.dart';
import '../services/notification_websocket.dart';
import '../widgets/call/incoming_call_overlay.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _selectedIndex = 0;
  final _notificationWs = NotificationWebSocket();

  // Chat navigation state
  String? _openConversationId;
  String? _openConversationUsername;
  String? _openConversationOtherUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationSyncProvider.notifier).syncToProfile();
      ref.read(callManagerProvider.notifier).ensureConnected();
      _connectNotifications();
    });
  }

  Future<void> _connectNotifications() async {
    final chatService = ref.read(chatServiceProvider);
    await _notificationWs.connect(
      ticketProvider: chatService.getWsTicket,
      onEvent: (data) {
        final type = data['type']?.toString() ?? '';
        if (type == 'new_message' || type == 'match_notification') {
          refreshChatData(ref);
        }
      },
    );
  }

  @override
  void dispose() {
    _notificationWs.disconnect();
    super.dispose();
  }

  void _refreshTabData(int index) {
    if (index == 0) {
      ref.read(feedProvider.notifier).refreshFeed();
    } else if (index == 1) {
      refreshChatData(ref);
    }
  }

  void _onTabTapped(int index) {
    ref.read(shellNavigationProvider.notifier).setTab(index);
    if (index == _selectedIndex && index == 1) {
      // Tapping chat tab again goes back to list
      setState(() {
        _openConversationId = null;
        _openConversationUsername = null;
        _openConversationOtherUserId = null;
      });
      return;
    }
    setState(() {
      _selectedIndex = index;
      if (index != 1) {
        _openConversationId = null;
        _openConversationUsername = null;
        _openConversationOtherUserId = null;
      }
    });
  }

  void _openChat(
    String conversationId, {
    String username = 'User',
    String? otherUserId,
  }) {
    setState(() {
      _selectedIndex = 1;
      _openConversationId = conversationId;
      _openConversationUsername = username;
      _openConversationOtherUserId = otherUserId;
    });
  }

  void _openChatFromFeed(String conversationId) {
    _openChat(conversationId);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ShellNavigationState>(shellNavigationProvider, (previous, next) {
      if (next.tabIndex != _selectedIndex) {
        setState(() => _selectedIndex = next.tabIndex);
        _refreshTabData(next.tabIndex);
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: const Color(0xFF0C0C0C),
            body: _buildBody(),
            bottomNavigationBar: _buildNavBar(),
          ),
          const IncomingCallOverlay(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedIndex == 1 && _openConversationId != null) {
      return ChatScreen(
        conversationId: _openConversationId!,
        otherUsername: _openConversationUsername ?? 'User',
        otherUserId: _openConversationOtherUserId,
      );
    }

    return IndexedStack(
      index: _selectedIndex,
      children: [
        // Feed
        FeedScreen(onOpenChat: _openChatFromFeed),
        // Chat / Conversations
        ConversationsScreen(
          onOpenChat: (id, username, {otherUserId}) =>
              _openChat(id, username: username, otherUserId: otherUserId),
        ),
        // Confessions
        const ConfessionsScreen(),
        // Profile
        const MyProfileScreen(),
      ],
    );
  }

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        border: Border(
          top: BorderSide(color: const Color(0xFF1E1E1E), width: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore_rounded,
                label: 'Discover',
                isSelected: _selectedIndex == 0,
                onTap: () => _onTabTapped(0),
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Messages',
                isSelected: _selectedIndex == 1,
                onTap: () => _onTabTapped(1),
                showBack: _openConversationId != null,
              ),
              _NavItem(
                icon: Icons.auto_awesome_outlined,
                activeIcon: Icons.auto_awesome_rounded,
                label: 'Confess',
                isSelected: _selectedIndex == 2,
                onTap: () => _onTabTapped(2),
              ),
              _NavItem(
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                isSelected: _selectedIndex == 3,
                onTap: () => _onTabTapped(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showBack;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isSelected)
                    Container(
                      width: 44,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF2E74).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  Icon(
                    isSelected ? activeIcon : icon,
                    color: isSelected
                        ? const Color(0xFFFF2E74)
                        : const Color(0xFF555555),
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                showBack ? '← Back' : label,
                style: GoogleFonts.outfit(
                  color: isSelected
                      ? const Color(0xFFFF2E74)
                      : const Color(0xFF555555),
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
