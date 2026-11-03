import 'package:flutter/material.dart';

import '../../presentation/branding/app_colors.dart';
import '../../presentation/home/widgets/zone_coming_soon_widget.dart';

/// Full-screen "not available in your area yet" state, shown in place of the
/// whole catalog — Food or Mart alike — once the customer's location resolves
/// to somewhere outside every configured service zone.
///
/// Reuses [ZoneComingSoonWidget]'s existing card design rather than a second
/// one: that widget already stays as the smaller in-page card for the
/// separate "inside a zone, but this particular list is empty" case, so the
/// two states read as the same idea at two sizes instead of two different
/// looks for what a shopper experiences as the same thing — nothing to order
/// right now.
class ZoneUnavailableScreen extends StatelessWidget {
  const ZoneUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: const SafeArea(
        child: Center(
          child: ZoneComingSoonWidget(
            title: "We're Coming Soon to Your Area!",
            message:
                "Food and Mart services are not available in your location yet. "
                "We're working to bring them to you soon.",
          ),
        ),
      ),
    );
  }
}
