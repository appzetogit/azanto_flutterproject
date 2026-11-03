import 'package:flutter/material.dart';

import '../../presentation/branding/app_colors.dart';

/// The card chrome the Food checkout screens use, extracted so Mart can wear
/// the same surface without duplicating Food's screens.
///
/// Food's cart, bill and order cards all share one look: a 24pt radius, a
/// hairline `#F3F4F6` border and a soft low shadow that is dropped entirely in
/// dark mode (a shadow under a dark card only muddies it). Mart's cards used a
/// smaller radius, no shadow and a different border, which is the main reason
/// the two checkouts read as different apps.
class FoodStyleCard extends StatelessWidget {
  const FoodStyleCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
        ),
        boxShadow: isDark
            ? const []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: child,
    );
  }
}
