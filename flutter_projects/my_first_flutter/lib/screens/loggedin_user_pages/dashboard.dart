import 'package:flutter/material.dart';
import 'home.dart';
import 'report.dart';
import 'news.dart';
import 'more.dart';
import 'profile.dart';

class LoggedInDashboard extends StatefulWidget {
  const LoggedInDashboard({super.key});

  @override
  State<LoggedInDashboard> createState() => _LoggedInDashboardState();
}

class _LoggedInDashboardState extends State<LoggedInDashboard> {
  int _currentIndex = 0;

  late final List<Widget> _pages = const [
    LoggedInHome(),
    LoggedInReport(),
    LoggedInNews(),
    LoggedInMore(),
    LoggedInProfile(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      // IndexedStack keeps all 5 tabs mounted (just hides the inactive
      // ones) instead of destroying/rebuilding the screen on every
      // switch — preserves scroll position and avoids re-fetching each
      // tab's data every time the user comes back to it.
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // LayoutBuilder measures the available width so the active-tab
      // indicator bar can be sized to exactly one item's width and
      // positioned above it — never spilling into a neighboring tab.
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final double itemWidth = constraints.maxWidth / _pages.length;
          return Stack(
            children: [
              BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                selectedItemColor: Colors.black,
                unselectedItemColor: Colors.black38,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                elevation: 8,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.description_outlined),
                    activeIcon: Icon(Icons.description),
                    label: 'Report',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.newspaper_outlined),
                    activeIcon: Icon(Icons.newspaper),
                    label: 'News',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.grid_view_outlined),
                    activeIcon: Icon(Icons.grid_view),
                    label: 'More',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outline),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                top: 0,
                left: itemWidth * _currentIndex,
                width: itemWidth,
                child: Container(height: 3, color: Colors.black),
              ),
            ],
          );
        },
      ),
    );
  }
}
