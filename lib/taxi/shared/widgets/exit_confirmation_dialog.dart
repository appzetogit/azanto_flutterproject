import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<bool?> showExitConfirmationDialog(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
  final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
  final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: bgColor,
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Badge
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF4C0519) : const Color(0xFFFFEBEB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.power_settings_new_rounded,
                  color: Color(0xFFEF4444),
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Exit Application',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Message
              Text(
                'Are you sure you want to exit the app?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),

              // Actions Row (Cancel & Exit)
              Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textPrimary,
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Exit Button
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(dialogContext).pop(true);
                          SystemNavigator.pop();
                        },
                        child: const Text(
                          'Exit',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
