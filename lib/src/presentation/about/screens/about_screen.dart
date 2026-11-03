import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/haptics.dart';
import '../../../di/cms_page_provider.dart';
import '../../../di/support_contact_provider.dart';
import '../../branding/app_colors.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB);
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final page = ref.watch(cmsPageProvider('about'));

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 28.sp, color: textColor),
          onPressed: () {
            Haptics.light();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'About Us',
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. HERO BANNER CARD
              _buildHeroCard(isDark, textColor, secondaryTextColor),

              SizedBox(height: 14.h),

              // 3. OUR MISSION & OUR VISION (2 Side-by-Side Cards)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildMissionCard(isDark, textColor, secondaryTextColor)),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildVisionCard(isDark, textColor, secondaryTextColor)),
                ],
              ),

              SizedBox(height: 20.h),

              // 4. WHY CHOOSE Azanto? SECTION
              _buildSectionTitle('Why Choose Go Azanto?', isDark),
              SizedBox(height: 12.h),
              _buildWhyChooseUsCard(isDark, textColor, secondaryTextColor, page),

              SizedBox(height: 16.h),

              // 5. COMPANY DETAILS LIST TILE CARD
              _buildCompanyInfoCard(context, ref, isDark, textColor, secondaryTextColor),

              SizedBox(height: 16.h),

              // 6. THANK YOU BANNER CARD
              _buildThankYouCard(isDark, textColor, secondaryTextColor),

              SizedBox(height: 20.h),

              // 7. FOOTER & CLOSE BUTTON
              Column(
                children: [
                  Text(
                    (page.value?.version ?? '').isEmpty ? '' : 'Version ${page.value!.version}',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '© 2026 Go Azanto. All Rights Reserved.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: secondaryTextColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Fresh Food. Fast Delivery. Anytime.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.favorite_rounded, color: AppColors.primary, size: 14.sp),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () {
                        Haptics.light();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24.r),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Hero Card: Azanto Logo + Subtitle + Headline + Description + 3D Illustration
  Widget _buildHeroCard(bool isDark, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  AppColors.primaryTintDark,
                  AppColors.primaryTintDarkStrong,
                ]
              : [
                  AppColors.primaryTint,
                  AppColors.primaryTintStrong,
                ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? AppColors.primaryTintDarkStrong : AppColors.primaryTintStrong,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Content Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Logo & Category Subtitle
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'azanto',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Container(
                      padding: EdgeInsets.all(3.r),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        color: Colors.white,
                        size: 10.sp,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Food & Drink',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 3.h),
                Container(
                  width: 32.w,
                  height: 2.5.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),

                SizedBox(height: 12.h),

                // Headline
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                    children: [
                      TextSpan(
                        text: 'Good Food. Great Moments.\n',
                        style: TextStyle(color: textColor),
                      ),
                      TextSpan(
                        text: 'Delivered to You.',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8.h),

                // Description
                Text(
                  'Go Azanto is your trusted food delivery platform, connecting you with the best restaurants, cafés and food partners. Fresh meals, quick delivery and delightful experiences – all at your fingertips.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    height: 1.35,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 12.w),

          // Right 3D Illustration Asset
          SizedBox(
            width: 135.w,
            height: 150.h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Image.asset(
                'assets/images/about_hero.webp',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.fastfood_rounded, color: AppColors.primary, size: 48.sp),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Our Mission Card (Orange Tinted with Bullseye Icon)
  Widget _buildMissionCard(bool isDark, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: EdgeInsets.all(14.r),
      constraints: BoxConstraints(minHeight: 165.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primaryTintDark : AppColors.primaryTint,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? AppColors.primaryTintDarkStrong : AppColors.primaryTintStrong,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primaryTintDarkStrong : AppColors.primaryTintStrong,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.track_changes_rounded,
                  color: AppColors.primary,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Our Mission',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Container(
                      width: 20.w,
                      height: 2.h,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            'To make food ordering effortless by delivering quality meals quickly, safely and affordably through smart technology and excellent service.',
            style: TextStyle(
              fontSize: 11.sp,
              height: 1.35,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Our Vision Card (Green Tinted with Eye Icon)
  Widget _buildVisionCard(bool isDark, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: EdgeInsets.all(14.r),
      constraints: BoxConstraints(minHeight: 165.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14241B) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF1C422C) : const Color(0xFFDCFCE7),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B3B29) : const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.visibility_outlined,
                  color: const Color(0xFF16A34A),
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Our Vision',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Container(
                      width: 20.w,
                      height: 2.h,
                      color: const Color(0xFF16A34A),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            'To become the most trusted Food & Drink platform, connecting millions of customers with the best local restaurants and creating memorable food experiences.',
            style: TextStyle(
              fontSize: 11.sp,
              height: 1.35,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Section Title Header with Flanking Lines
  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24.w,
          height: 2.h,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(1.r),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        SizedBox(width: 10.w),
        Container(
          width: 24.w,
          height: 2.h,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(1.r),
          ),
        ),
      ],
    );
  }

  /// Admin panel's fixed icon set for a feature ([CmsFeature.icon]).
  static IconData _featureIcon(String name) {
    switch (name) {
      case 'Heart':
        return Icons.favorite_rounded;
      case 'Users':
        return Icons.groups_rounded;
      case 'Shield':
        return Icons.shield_outlined;
      case 'Clock':
        return Icons.access_time_rounded;
      case 'Star':
        return Icons.star_rounded;
      case 'Award':
        return Icons.emoji_events_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  /// 4. Why Choose Azanto Card — features grid from the admin panel's CMS.
  Widget _buildWhyChooseUsCard(
      bool isDark, Color textColor, Color secondaryTextColor, AsyncValue<CmsPage?> page) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 6.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: page.when(
        loading: () => Padding(
          padding: EdgeInsets.symmetric(vertical: 24.h),
          child: const Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Text(
            'Unable to load this content right now.',
            style: TextStyle(fontSize: 12.5.sp, color: secondaryTextColor),
          ),
        ),
        data: (page) {
          final features = page?.features ?? const [];
          if (features.isEmpty) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Text(
                'No highlights published yet.',
                style: TextStyle(fontSize: 12.5.sp, color: secondaryTextColor),
              ),
            );
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / features.length;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(features.length, (index) {
                  final f = features[index];
                  final showDivider = index < features.length - 1;

                  return SizedBox(
                    width: itemWidth,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 3.w),
                      decoration: showDivider
                          ? BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: isDark ? AppColors.borderDark : const Color(0xFFF0F0F0),
                                  width: 1,
                                ),
                              ),
                            )
                          : null,
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.all(7.r),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _featureIcon(f.icon),
                              color: AppColors.primary,
                              size: 15.sp,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            f.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            f.description,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9.sp,
                              height: 1.2,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            },
          );
        },
      ),
    );
  }

  /// 5. Company Info Card: Company Name, Category, Website, Email, Support
  Widget _buildCompanyInfoCard(
      BuildContext context, WidgetRef ref, bool isDark, Color textColor, Color secondaryTextColor) {
    final contact = ref.watch(supportContactProvider).value;
    final items = [
      {'icon': Icons.label_outlined, 'title': 'Company Name', 'value': 'Go Azanto', 'isLink': false},
      {'icon': Icons.grid_view_rounded, 'title': 'Category', 'value': 'Food & Drink', 'isLink': false},
      {
        'icon': Icons.language_rounded,
        'title': 'Website',
        'value': 'maava.in',
        'isLink': true,
        'url': 'https://maava.in'
      },
      {
        'icon': Icons.email_outlined,
        'title': 'Email',
        'value': contact?.email ?? '—',
        'isLink': false,
        if (contact?.email != null) 'url': 'mailto:${contact!.email}',
      },
      {
        'icon': Icons.phone_outlined,
        'title': 'Customer Support',
        'value': contact?.phone ?? '—',
        'isLink': false,
        if (contact?.phone != null) 'url': 'tel:${contact!.phone}',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;

          return InkWell(
            onTap: item['url'] != null ? () => _launchUrl(item['url'] as String) : null,
            borderRadius: BorderRadius.vertical(
              top: index == 0 ? Radius.circular(16.r) : Radius.zero,
              bottom: isLast ? Radius.circular(16.r) : Radius.zero,
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  child: Row(
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: AppColors.primary,
                        size: 18.sp,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        item['title'] as String,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item['value'] as String,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: item['isLink'] == true ? AppColors.primary : secondaryTextColor,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                        size: 16.sp,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 14.w,
                    endIndent: 14.w,
                    color: isDark ? AppColors.borderDark : const Color(0xFFF2F2F2),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// 6. Thank You Banner Card: Heart Icon + Message + Food Bowl Illustration
  Widget _buildThankYouCard(bool isDark, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isDark
              ? [
                  AppColors.primaryTintDark,
                  AppColors.primaryTintDarkStrong,
                ]
              : [
                  AppColors.primaryTint,
                  AppColors.primaryTintStrong,
                ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? AppColors.primaryTintDarkStrong : AppColors.primaryTintStrong,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: const Color(0xFFFF3B30),
              size: 18.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thank you for being a part of Go Azanto!',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'We are grateful for your trust and support.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 80.w,
            height: 55.h,
            child: Image.asset(
              'assets/images/about_thank_you_food.webp',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.local_dining_rounded,
                color: AppColors.primary,
                size: 32.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
