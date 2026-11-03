import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../taxi_section.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    const navBgColor = Color(0xFF0B131E);
    const activeColor = Color(0xFFFA0272);
    const inactiveColor = Color(0xFF94A3B8);

    return Container(
      color: navBgColor,
      child: SafeArea(
        top: false,
        child: Container(
          height: 68,
          decoration: const BoxDecoration(
            color: navBgColor,
            border: Border(top: BorderSide(color: Color(0xFF1E2D3D), width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Home
              _BottomNavItem(
                icon: currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
                label: 'Home',
                isActive: currentIndex == 0,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () {
                  if (currentIndex != 0) context.go('/home');
                },
              ),

              // 2. All Services
              _BottomNavItem(
                icon: Icons.grid_view_rounded,
                label: 'All Services',
                isActive: currentIndex == 1,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () {
                  if (currentIndex != 1) context.go('/home/all-services');
                },
              ),

              // 3. Centre disc: back to Azanto Food — the twin of the food
              // bar's "Taxi" disc (raised circle, icon, label underneath).
              GestureDetector(
                onTap: () => TaxiSection.exitToFood?.call(),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -14),
                      child: Container(
                        // 50 + label fits the bar's fixed 68 height.
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: activeColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: navBgColor, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x59FA0272),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -10),
                      child: const Text(
                        'Food',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: activeColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 4. History
              _BottomNavItem(
                icon: currentIndex == 2 ? Icons.access_time_rounded : Icons.access_time_outlined,
                label: 'History',
                isActive: currentIndex == 2,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () {
                  if (currentIndex != 2) context.go('/rides');
                },
              ),

              // 5. Profile
              _BottomNavItem(
                icon: currentIndex == 3 ? Icons.person_rounded : Icons.person_outline_rounded,
                label: 'Profile',
                isActive: currentIndex == 3,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () {
                  if (currentIndex != 3) context.go('/profile');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 21),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
