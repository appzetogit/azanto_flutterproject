import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/utils/haptics.dart';
import '../../../di/cms_page_provider.dart';
import '../../../di/support_contact_provider.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../navigation/route_names.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    Haptics.light();
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (context.mounted) {
          AppSnackbar.error(context, 'Could not launch dialer for $phoneNumber');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.info(context, 'Calling $phoneNumber...');
      }
    }
  }

  Future<void> _sendEmail(BuildContext context, String emailAddress) async {
    Haptics.light();
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: emailAddress,
      queryParameters: {'subject': 'Support Request - Go Azanto App'},
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (context.mounted) {
          AppSnackbar.error(context, 'Could not open email client for $emailAddress');
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.info(context, 'Opening mail to $emailAddress...');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Help & Support',
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
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. HERO BANNER CARD
              _buildHeroCard(isDark, textColor, secondaryTextColor),

              SizedBox(height: 20.h),

              // 2. QUICK HELP SECTION (from the admin panel's CMS)
              _buildSectionTitle('Quick Help', textColor),
              SizedBox(height: 10.h),
              Consumer(
                builder: (context, ref, _) => _buildQuickHelpCard(
                  isDark,
                  textColor,
                  secondaryTextColor,
                  ref.watch(cmsPageProvider('support')),
                ),
              ),

              SizedBox(height: 20.h),

              // 3. CONTACT US SECTION (DYNAMIC CALL, MAIL, CHAT)
              _buildSectionTitle('Contact Us', textColor),
              SizedBox(height: 10.h),
              Consumer(
                builder: (context, ref, _) => _buildContactUsCard(
                  context,
                  isDark,
                  textColor,
                  secondaryTextColor,
                  ref.watch(supportContactProvider).value,
                ),
              ),

              SizedBox(height: 20.h),

              // 4. SUPPORT INFORMATION SECTION
              _buildSectionTitle('Support Information', textColor),
              SizedBox(height: 10.h),
              _buildSupportInfoCard(isDark, textColor, secondaryTextColor),

              SizedBox(height: 24.h),

              // 5. FOOTER
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      color: AppColors.primary,
                      size: 16.sp,
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Thank you for choosing Go Azanto!',
                      style: TextStyle(
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'We\'re always here to help you.',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Hero Card: Headphones Illustration + Help Text
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We\'re here to',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'help you!',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Facing an issue? Our support team is ready to assist you.',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: secondaryTextColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          SizedBox(
            width: 125.w,
            height: 115.h,
            child: Image.asset(
              'assets/images/help_support_headphones.webp',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.headset_mic_rounded,
                color: AppColors.primary,
                size: 64.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.w800,
        color: textColor,
      ),
    );
  }

  /// 2. Quick Help Card — title + body from the admin panel's CMS.
  Widget _buildQuickHelpCard(bool isDark, Color textColor, Color secondaryTextColor,
      AsyncValue<CmsPage?> page) {
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
          'Unable to load help content right now.',
          style: TextStyle(fontSize: 12.5.sp, color: secondaryTextColor),
        ),
        data: (page) {
          if (page == null) {
            return Text(
              'Help content has not been published yet.',
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

  /// 3. Contact Us Card: Call Us (Dynamic Phone Call), Email Us (Dynamic Mail Composer), Live Chat
  Widget _buildContactUsCard(
      BuildContext context, bool isDark, Color textColor, Color secondaryTextColor,
      SupportContact? contact) {
    // Published by the admin panel. Until it loads (or if it is blank) the row
    // shows a dash and does nothing, rather than dialling a stale number.
    final phone = contact?.phone;
    final email = contact?.email;
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
        children: [
          // 1. CALL US -> DYNAMIC PHONE CALL
          InkWell(
            onTap: phone == null ? null : () => _makePhoneCall(context, phone),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.phone_in_talk_rounded,
                      color: const Color(0xFF16A34A),
                      size: 18.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Call Us',
                          style: TextStyle(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Speak with our support team',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    phone ?? '—',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                    size: 18.sp,
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 14.w,
            endIndent: 14.w,
            color: isDark ? AppColors.borderDark : const Color(0xFFF2F2F2),
          ),

          // 2. EMAIL US -> DYNAMIC MAIL COMPOSER
          InkWell(
            onTap: email == null ? null : () => _sendEmail(context, email),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F2FE),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mail_outline_rounded,
                      color: const Color(0xFF0284C7),
                      size: 18.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Us',
                          style: TextStyle(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'We reply as soon as possible',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    email ?? '—',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                    size: 18.sp,
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            indent: 14.w,
            endIndent: 14.w,
            color: isDark ? AppColors.borderDark : const Color(0xFFF2F2F2),
          ),

          // 3. LIVE CHAT -> CHAT SCREEN
          InkWell(
            onTap: () {
              Haptics.light();
              context.push(RouteNames.chat);
            },
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3E8FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: const Color(0xFF9333EA),
                      size: 18.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Chat',
                          style: TextStyle(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Chat with our support team',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.primaryTintStrong,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      'Available 9AM - 9PM',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDeep,
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                    size: 18.sp,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Support Information Card: Support Hours | Response Time | We Care
  Widget _buildSupportInfoCard(bool isDark, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primaryTintDark : AppColors.primaryTint,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? AppColors.primaryTintDarkStrong : AppColors.primaryTintStrong,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. Support Hours
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(7.r),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTintStrong,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.access_time_rounded,
                    color: AppColors.primary,
                    size: 16.sp,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Support Hours',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '9AM - 9PM\nEveryday',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    color: secondaryTextColor,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 48.h,
            width: 1,
            color: isDark ? AppColors.primaryTintDarkStrong : AppColors.primaryTintStrong,
          ),

          // 2. Response Time
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(7.r),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTintStrong,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.primary,
                    size: 16.sp,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Response Time',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Within 24 hours',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 48.h,
            width: 1,
            color: isDark ? AppColors.primaryTintDarkStrong : AppColors.primaryTintStrong,
          ),

          // 3. We Care
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(7.r),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTintStrong,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    color: AppColors.primary,
                    size: 16.sp,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'We Care',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Your satisfaction is\nour priority',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    color: secondaryTextColor,
                    height: 1.25,
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
