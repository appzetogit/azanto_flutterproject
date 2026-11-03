import 'package:flutter/material.dart';

import '../../../../../presentation/branding/app_colors.dart';
import '../../../../core/constants/app_durations.dart';
import '../../../../core/utils/app_haptics.dart';

/// − qty + control styled to match Food section's stepper pill design.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.height = 34,
    this.compact = false,
    this.canIncrement = true,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final double height;
  final bool compact;
  final bool canIncrement;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stepperBg = isDark
        ? const Color(0xFF2A2A2A)
        : AppColors.primaryTint;
    final stepperBorder = isDark
        ? const Color(0xFF3D3D3D)
        : AppColors.primary.withValues(alpha: 0.3);
    final stepperTextColor = isDark ? Colors.white : AppColors.primary;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: stepperBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: stepperBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)),
            onTap: () {
              AppHaptics.light();
              onDecrement();
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: 2,
              ),
              child: Text(
                '−',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: stepperTextColor,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: AppDurations.fast,
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '$quantity',
                key: ValueKey(quantity),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: stepperTextColor,
                ),
              ),
            ),
          ),
          InkWell(
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(18)),
            onTap: canIncrement
                ? () {
                    AppHaptics.light();
                    onIncrement();
                  }
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: 2,
              ),
              child: Text(
                '+',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: canIncrement
                      ? stepperTextColor
                      : stepperTextColor.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
