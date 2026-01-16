import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../chat/chat_list_screen.dart';
import '../favorites/favorites_screen.dart';
import '../profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ChatListScreen(),
    const FavoritesScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.white,
        selectedItemColor: AppTheme.primaryYellow,
        unselectedItemColor: AppTheme.textSecondary,
        selectedLabelStyle: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.roboto(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 0 ? Icons.home : Icons.home_outlined,
              color: _currentIndex == 0 ? AppTheme.primaryYellow : AppTheme.textSecondary,
            ),
            activeIcon: const Icon(Icons.home, color: AppTheme.primaryYellow),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 1 ? Icons.chat_bubble : Icons.chat_bubble_outline,
              color: _currentIndex == 1 ? AppTheme.primaryYellow : AppTheme.textSecondary,
            ),
            activeIcon: const Icon(Icons.chat_bubble, color: AppTheme.primaryYellow),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 2 ? Icons.star : Icons.star_border,
              color: _currentIndex == 2 ? AppTheme.primaryYellow : AppTheme.textSecondary,
            ),
            activeIcon: const Icon(Icons.star, color: AppTheme.primaryYellow),
            label: 'Saved',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 3 ? Icons.person : Icons.person_outline,
              color: _currentIndex == 3 ? AppTheme.primaryYellow : AppTheme.textSecondary,
            ),
            activeIcon: const Icon(Icons.person, color: AppTheme.primaryYellow),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

