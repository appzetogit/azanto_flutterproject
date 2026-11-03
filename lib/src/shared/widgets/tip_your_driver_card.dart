import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/utils/haptics.dart';
import '../../presentation/branding/app_colors.dart';

/// Fallback tip amounts, used only until the admin-configured list arrives (or
/// when a store has configured none). Kept so the card is never empty.
const kDefaultTipPresets = <double>[10, 20, 30, 50];

/// "Tip your delivery partner" — the cart card, shared by Food and Mart.
///
/// Lifted verbatim from the Food cart so both verticals render the identical
/// card; it was inline there, which is why Mart had no tip at all. The amounts
/// come from the admin panel (`tipPresets` on fee settings) rather than a
/// compiled-in list, and the selection is reported upward — this widget owns
/// the look, the host owns what a tip means to its checkout.
class TipYourDriverCard extends StatelessWidget {
  const TipYourDriverCard({
    super.key,
    required this.selected,
    required this.presets,
    required this.onSelect,
  });

  /// Currently selected tip; 0 selects the "No Tip" chip.
  final double selected;

  /// Amounts to offer, in display order.
  final List<double> presets;

  final ValueChanged<double> onSelect;

  /// Encouragement under each chip, by position — copy, not data, so any
  /// number of admin-configured presets still reads sensibly.
  static const _tipSubtitles = [
    'Thanks!',
    'Great!',
    'Awesome!',
    'You\u2019re the best!',
  ];

  @override
  Widget build(BuildContext context) => _buildTipCard(context);

  Widget _buildTipCard(BuildContext context) {
    final amounts = presets.isEmpty ? kDefaultTipPresets : presets;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tipOptions = [
      for (final (index, amount) in amounts.indexed)
        (
          amount,
          _tipSubtitles[index < _tipSubtitles.length
              ? index
              : _tipSubtitles.length - 1],
        ),
    ];

    final brandPurple = AppColors.primary;
    final lightPurple = AppColors.primaryTint;
    final purpleBadgeBg = AppColors.primaryTintStrong;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP HEADER: Illustration + Title + Right Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Hand + Heart Gift Illustration Icon Container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: lightPurple,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.volunteer_activism_rounded,
                      size: 26,
                      color: brandPurple.withValues(alpha: 0.85),
                    ),
                    Positioned(
                      top: 4,
                      right: 8,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 10,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Title + Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tip your delivery partner',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    GestureDetector(
                      onTap: () {
                        Haptics.light();
                        _showTipInfoSheet(context, isDark);
                      },
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              '100% of your tip goes to them',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 13,
                            color: Color(0xFF6B7280),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Right Lavender Kindness Badge
              Container(
                width: 106,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primaryTintDark : purpleBadgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 15,
                      color: isDark ? AppColors.primaryLight : brandPurple,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'They deliver with care, you tip with kindness 💜',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.primarySoft : AppColors.primaryDeepText,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. TIP PRESET CHIPS (10, 20, 30, 50, No Tip)
          Row(
            children: [
              for (final (amount, subtitle) in tipOptions) ...[
                Expanded(
                  child: _buildTipChip(
                    amount: amount,
                    amountText: '₹${amount.toStringAsFixed(0)}',
                    subtitleText: subtitle,
                    isSelected: selected == amount,
                    isNoTip: false,
                    isDark: isDark,
                    brandPurple: brandPurple,
                    onTap: () {
                      Haptics.light();
                      onSelect(amount);
                    },
                  ),
                ),
                const SizedBox(width: 5),
              ],
              // "No Tip" Chip
              Expanded(
                child: _buildTipChip(
                  amount: 0,
                  amountText: '',
                  subtitleText: 'No Tip',
                  isSelected: selected == 0,
                  isNoTip: true,
                  isDark: isDark,
                  brandPurple: brandPurple,
                  onTap: () {
                    Haptics.light();
                    onSelect(0);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Dotted horizontal line separator
          CustomPaint(
            size: const Size(double.infinity, 1),
            painter: _DottedLinePainter(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),

          const SizedBox(height: 10),

          // 3. FOOTER BANNER NOTE: Gift Icon + Kindness motivation + Learn More
          Row(
            children: [
              Icon(
                Icons.card_giftcard_rounded,
                size: 15,
                color: isDark ? AppColors.primaryLight : brandPurple,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Your kindness motivates them to do better every day! 💜',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  _showTipInfoSheet(context, isDark);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Learn more',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.primaryLight : brandPurple,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: isDark ? AppColors.primaryLight : brandPurple,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildTipChip({
    required double amount,
    required String amountText,
    required String subtitleText,
    required bool isSelected,
    required bool isNoTip,
    required bool isDark,
    required Color brandPurple,
    required VoidCallback onTap,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? brandPurple
                  : (isDark ? AppColors.cardDark : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? brandPurple
                    : (isNoTip
                        ? (isDark ? const Color(0xFF4B5563) : const Color(0xFFCBD5E1))
                        : (isDark ? AppColors.borderDark : const Color(0xFFE5E7EB))),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: brandPurple.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isNoTip) ...[
                  Icon(
                    Icons.do_not_disturb_alt_rounded,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitleText,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                    ),
                  ),
                ] else ...[
                  Text(
                    amountText,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white : const Color(0xFF111827)),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.95)
                          : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isSelected)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: brandPurple, width: 1.5),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.check_rounded,
                size: 11,
                color: brandPurple,
              ),
            ),
          ),
      ],
    );
  }


  void _showTipInfoSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Icon(
                Icons.volunteer_activism_rounded,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '100% of your tip goes to your delivery partner',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Go Azanto does not deduct any transaction fees or commissions from delivery tips. Your full contribution is transferred directly to the delivery executive as appreciation for their hard work and care.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;

  _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter oldDelegate) => oldDelegate.color != color;
}

