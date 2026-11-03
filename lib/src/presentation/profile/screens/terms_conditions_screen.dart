import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../di/cms_page_provider.dart';
import '../../../di/support_contact_provider.dart';

class TermsConditionsScreen extends ConsumerWidget {
  const TermsConditionsScreen({super.key});

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    Haptics.light();
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (context.mounted) {
          AppSnackbar.info(context, 'Calling $phoneNumber...');
        }
      }
    } catch (_) {}
  }

  Future<void> _sendEmail(BuildContext context, String emailAddress) async {
    Haptics.light();
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: emailAddress,
      //queryParameters: {'subject': 'Terms & Conditions Inquiry - Azanto App'},
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (context.mounted) {
          AppSnackbar.info(context, 'Opening mail to $emailAddress...');
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB);
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

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
          'Terms and Conditions',
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

              SizedBox(height: 16.h),

              // 2. TERMS CONTENT CARD (from the admin panel's CMS)
              _buildTermsSectionsCard(ref, isDark, textColor, secondaryTextColor),

              SizedBox(height: 16.h),

              // 3. NEED HELP? CONTACT CARD (Phone & Email with dynamic actions)
              _buildNeedHelpCard(context, ref, isDark, textColor, secondaryTextColor),

              SizedBox(height: 16.h),

              // 4. FOOTER & CLOSE BUTTON
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.primary,
                        size: 15.sp,
                      ),
                      SizedBox(width: 5.w),
                      Flexible(
                        child: Text(
                          'By using Go Azanto, you agree to these Terms and Conditions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'Thank you for choosing Go Azanto!',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: secondaryTextColor,
                    ),
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

  /// 1. Hero Card: Headline + Orange Accent Line + Description + 3D Clipboard Illustration
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
                  AppColors.primaryTintDark,
                ]
              : [
                  AppColors.primaryTint,
                  AppColors.primaryTint,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                    children: [
                      TextSpan(
                        text: 'Terms &\n',
                        style: TextStyle(color: AppColors.primary),
                      ),
                      TextSpan(
                        text: 'Conditions',
                        style: TextStyle(color: textColor),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  width: 32.w,
                  height: 2.5.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 10.h),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: secondaryTextColor,
                      height: 1.35,
                    ),
                    children: [
                      TextSpan(text: 'Please read these terms carefully before using the '),
                      TextSpan(
                        text: 'Go Azanto',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      TextSpan(text: ' app.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          SizedBox(
            width: 100.w,
            height: 100.h,
            child: Image.asset(
              'assets/images/termncondition.webp',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.description_rounded,
                color: AppColors.primary,
                size: 64.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Terms content card — title + body from the admin panel's CMS.
  Widget _buildTermsSectionsCard(
      WidgetRef ref, bool isDark, Color textColor, Color secondaryTextColor) {
    final page = ref.watch(cmsPageProvider('terms'));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
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
        error: (_, __) => Text(
          'Unable to load the terms and conditions right now.',
          style: TextStyle(fontSize: 12.5.sp, color: secondaryTextColor),
        ),
        data: (page) {
          if (page == null) {
            return Text(
              'The terms and conditions have not been published yet.',
              style: TextStyle(fontSize: 12.5.sp, color: secondaryTextColor),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                page.title,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                plainTextFromHtml(page.content),
                style: TextStyle(
                  fontSize: 12.5.sp,
                  height: 1.5,
                  color: secondaryTextColor,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 3. Need Help? Contact Card (Phone & Email with dynamic actions)
  Widget _buildNeedHelpCard(
      BuildContext context, WidgetRef ref, bool isDark, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: EdgeInsets.all(12.r),
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
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  color: AppColors.primaryTintStrong,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.headset_mic_rounded,
                  color: AppColors.primary,
                  size: 16.sp,
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need Help?',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'If you have any questions, feel free to contact us.',
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Inner white card for Phone & Email
          Container(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Left Column: Phone
                Expanded(
                  child: InkWell(
                    onTap: () => _makePhoneCall(context, _contactPhone(ref)),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6.r),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTintStrong,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.phone_in_talk_rounded,
                              color: AppColors.primary,
                              size: 14.sp,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Phone',
                                  style: TextStyle(
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  _contactPhone(ref),
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: secondaryTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 32.h,
                  width: 1,
                  color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
                ),

                // Right Column: Email
                Expanded(
                  child: InkWell(
                    onTap: () => _sendEmail(context, _contactEmail(ref)),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6.r),
                            decoration: BoxDecoration(
                              color: AppColors.primaryTintStrong,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.mail_outline_rounded,
                              color: AppColors.primary,
                              size: 14.sp,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email',
                                  style: TextStyle(
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  _contactEmail(ref),
                                  style: TextStyle(
                                    fontSize: 9.5.sp,
                                    color: secondaryTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The support address the admin panel publishes, or an empty string while it
/// is still loading. Never a compiled-in mailbox: this page used to print one,
/// so updating it in the panel changed nothing here.
String _contactEmail(WidgetRef ref) =>
    ref.watch(supportContactProvider).value?.email ?? '';

/// Same source as [_contactEmail], the panel's phone field.
String _contactPhone(WidgetRef ref) =>
    ref.watch(supportContactProvider).value?.phone ?? '';
