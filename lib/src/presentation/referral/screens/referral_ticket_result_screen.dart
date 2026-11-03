import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../navigation/back_navigation.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/haptics.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../common_widgets/skeleton_loading.dart';
import '../viewmodels/referral_viewmodel.dart';
import '../widgets/fire_particle_share_button.dart';
import '../widgets/refer_earn_background.dart';
import '../widgets/referral_ticket_card.dart';
import '../widgets/rotating_ticket_border.dart';

/// The dedicated "here's your ticket" page shown right after the referral
/// ticket finishes printing — just the ticket and the share button.
class ReferralTicketResultScreen extends ConsumerStatefulWidget {
  const ReferralTicketResultScreen({super.key});

  @override
  ConsumerState<ReferralTicketResultScreen> createState() =>
      _ReferralTicketResultScreenState();
}

class _ReferralTicketResultScreenState
    extends ConsumerState<ReferralTicketResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  double get _ticketWidth => 240.w;
  double get _ticketHeight => _ticketWidth / ReferralTicketCard.aspectRatio;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeIn));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _shareTicket() {
    final details = ref.read(referralDetailsProvider).value;
    final user = ref.read(authViewModelProvider).value;
    final code = details?.referralCode.isNotEmpty == true
        ? details!.referralCode
        : (user?.referralCode ?? '');
    final rewardStr = (details != null && details.rewardAmount > 0)
        ? '₹${details.rewardAmount.toStringAsFixed(0)}'
        : '';

    // Always the Play Store listing: the server's link and share text point
    // at the website. The app doesn't read an install referrer, so the code
    // has to be in the message for the friend to enter at sign-up.
    final invite = rewardStr.isEmpty
        ? 'Join me on Go Azanto!'
        : 'Join me on Go Azanto and get $rewardStr off on your first order!';
    final msg = code.isEmpty
        ? '$invite\nDownload: ${AppConstants.playStoreUrl}'
        : '$invite\nUse my referral code $code while signing up.\n'
            'Download: ${AppConstants.playStoreUrl}';

    Haptics.medium();
    SharePlus.instance.share(ShareParams(text: msg));
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(referralDetailsProvider);
    final user = ref.watch(authViewModelProvider).value;

    return Scaffold(
      backgroundColor: ReferEarnBackground.solid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.backOr(),
        ),
        title: Text(
          'Refer & earn',
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
        ),
        centerTitle: true,
      ),
      body: ReferEarnBackground(
        child: SafeArea(
          child: detailsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: SkeletonBanner(height: 300),
            ),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
            data: (details) {
              final code = details.referralCode.isNotEmpty
                  ? details.referralCode
                  : (user?.referralCode ?? 'SUVO25');
              final hasReward = details.rewardAmount > 0;
              final rewardAmountStr = details.rewardAmount.toStringAsFixed(0);

              return Column(
                children: [
                  SizedBox(height: 20.h),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_alt_outlined, color: Colors.grey, size: 20),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    hasReward
                        ? 'Earn ₹$rewardAmountStr on every referral'
                        : 'Invite your friends',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Text(
                      'Earn credits when your friend completes their first order!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
                    ),
                  ),

                  // Ticket — tilted, with a rotating glow tracing its edge.
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _entryController,
                        builder: (context, child) => Opacity(
                          opacity: _fadeAnimation.value,
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: child,
                          ),
                        ),
                        child: Transform.rotate(
                          angle: -0.09,
                          child: RotatingTicketBorder(
                            width: _ticketWidth,
                            height: _ticketHeight,
                            notch: 14.r,
                            child: ReferralTicketCard(
                              width: _ticketWidth,
                              height: _ticketHeight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Share button
                  Padding(
                    padding: EdgeInsets.only(bottom: 24.h),
                    child: Column(
                      children: [
                        FireParticleShareButton(onPressed: _shareTicket),
                        if (code.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              Haptics.light();
                              AppSnackbar.success(context, 'Code $code copied!');
                            },
                            icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                            label: Text('Copy code: $code', style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                        SizedBox(height: 8.h),
                        Text(
                          hasReward
                              ? 'You earn ₹$rewardAmountStr on every friend who signs up with your code'
                              : 'Share your code with friends',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
