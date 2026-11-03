import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../branding/app_colors.dart';

class ZoneComingSoonWidget extends StatelessWidget {
  final String title;
  final String message;

  const ZoneComingSoonWidget({
    super.key,
    this.title = 'Coming Soon!',
    this.message =
        'We’re not delivering in your area yet, but we’ll be there soon. Stay tuned!',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: isDark
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Decorative Illustration Badge
            Container(
              width: 80.r,
              height: 80.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.primaryLight.withValues(alpha: 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Container(
                  width: 60.r,
                  height: 60.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primaryLight,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.two_wheeler_rounded,
                    size: 30.sp,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: 18.h),

            // Expanding Pill Tag
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 14.sp,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'EXPANDING SOON',
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),

            // Header Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 8.h),

            // Message Body
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
