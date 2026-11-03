import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../../features/auth/application/auth_providers.dart';
import '../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../../shared/widgets/profile_tile.dart';
import '../../../taxi_section.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final dividerColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    final user = ref.watch(authControllerProvider).user;
    final userName = (user?.name != null && user!.name.isNotEmpty) ? user.name : 'Add your name';
    final userPhone = (user?.phone != null && user!.phone.isNotEmpty) ? user.phone : '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: bgColor,
        bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 3),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Profile Header Row
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: isDark ? const Color(0xFF3B1405) : const Color(0xFFFFECE5),
                          backgroundImage: buildSafeImageProvider(user?.profileImage),
                          child: buildSafeImageProvider(user?.profileImage) == null
                              ? const Icon(Icons.person_rounded, size: 40, color: AppColors.primaryOrange)
                              : null,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () => context.push('/profile/edit'),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryOrange,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userPhone,
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user_rounded, size: 12, color: Color(0xFF10B981)),
                              SizedBox(width: 4),
                              Text(
                                'Verified Profile',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.edit_rounded, size: 18, color: textPrimary),
                    ),
                    onPressed: () => context.push('/profile/edit'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ACCOUNT & REWARDS
              Text(
                'ACCOUNT & REWARDS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              _SectionCard(
                isDark: isDark,
                children: [
                  ProfileTile(
                    icon: Icons.bookmark_border_rounded,
                    iconColor: const Color(0xFF2563EB),
                    iconBackgroundColor: const Color(0xFFEFF6FF),
                    title: 'Saved Places',
                    subtitle: 'Home, work and favourite locations',
                    onTap: () => context.push('/profile/saved-places'),
                  ),
                  Divider(height: 1, color: dividerColor),
                  ProfileTile(
                    icon: Icons.card_giftcard_rounded,
                    iconColor: AppColors.primaryOrange,
                    iconBackgroundColor: const Color(0xFFFFECE5),
                    title: 'Rewards & Offers',
                    subtitle: 'Claim coupons and referral bonuses',
                    onTap: () => context.push('/rewards'),
                  ),
                  Divider(height: 1, color: dividerColor),
                  ProfileTile(
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: const Color(0xFF10B981),
                    iconBackgroundColor: const Color(0xFFECFDF5),
                    title: 'Payment & Wallet',
                    subtitle: 'Manage cards, UPI and transaction history',
                    onTap: () => context.push('/wallet'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // PREFERENCES & HELP
              Text(
                'PREFERENCES & HELP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              _SectionCard(
                isDark: isDark,
                children: [
                  ProfileTile(
                    icon: Icons.notifications_none_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    iconBackgroundColor: const Color(0xFFF3E8FF),
                    title: 'Notifications',
                    subtitle: 'Trip alerts, offers and news',
                    onTap: () => context.push('/notifications'),
                  ),
                  Divider(height: 1, color: dividerColor),
                  ProfileTile(
                    icon: Icons.headset_mic_outlined,
                    iconColor: const Color(0xFF0284C7),
                    iconBackgroundColor: const Color(0xFFE0F2FE),
                    title: 'Help & Support',
                    subtitle: 'FAQs, contact support and live chat',
                    onTap: () => context.push('/support'),
                  ),
                  Divider(height: 1, color: dividerColor),
                  ProfileTile(
                    icon: Icons.language_rounded,
                    iconColor: const Color(0xFF2563EB),
                    iconBackgroundColor: const Color(0xFFEBF5FF),
                    title: 'Language',
                    subtitle: 'Choose your preferred language',
                    onTap: () => context.push('/profile/language'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ACCOUNT MANAGEMENT
              Text(
                'ACCOUNT MANAGEMENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              _SectionCard(
                isDark: isDark,
                children: [
                  ProfileTile(
                    icon: Icons.delete_outline_rounded,
                    iconColor: const Color(0xFFEF4444),
                    iconBackgroundColor: const Color(0xFFFEF2F2),
                    title: 'Delete Account',
                    subtitle: 'Request permanent removal of your account & data',
                    onTap: () => context.push('/profile/delete-account'),
                  ),
                  Divider(height: 1, color: dividerColor),
                  ProfileTile(
                    icon: Icons.logout_rounded,
                    iconColor: const Color(0xFFF97316),
                    iconBackgroundColor: const Color(0xFFFFF7ED),
                    title: 'Logout',
                    subtitle: 'Sign out of your account on this device',
                    onTap: () => _showLogoutDialog(context, ref, isDark),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref, bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              elevation: 0,
              // The theme's full-width minimum would push Cancel onto its own
              // row in the dialog's action bar.
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(authControllerProvider.notifier).logout();
              // Same account as Food, so this signs out of Azanto.
              await TaxiSection.signOut?.call();
            },
            child: const Text(
              'Logout',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;

  const _SectionCard({
    required this.children,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
