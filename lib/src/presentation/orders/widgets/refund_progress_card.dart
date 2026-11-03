import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../data/models/order_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';

/// Where a cancelled order's money is: started, sent to the bank, back in the
/// account (an expected date -- the bank never confirms that step).
class RefundProgressCard extends StatelessWidget {
  final RefundProgress progress;

  const RefundProgressCard({super.key, required this.progress});

  static const _green = Color(0xFF39C96B);
  static const _amber = Color(0xFFE09B1A);

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _day(DateTime? at) => at == null ? '' : '${at.day} ${_months[at.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final pending = isDark ? AppColors.borderDark : AppColors.dividerLight;
    final accent = progress.isFailed ? _amber : _green;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'REFUND',
            style: TextStyle(
              color: secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          color: cardBg,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    progress.isFailed
                        ? Icons.warning_amber_rounded
                        : progress.destination == 'wallet'
                            ? Icons.account_balance_wallet_rounded
                            : Icons.currency_rupee_rounded,
                    color: accent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          progress.title,
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          progress.message,
                          style: TextStyle(color: secondaryText, fontSize: 13, height: 1.35),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (progress.steps.length > 1) ...[
                const SizedBox(height: 16),
                for (var i = 0; i < progress.steps.length; i++)
                  _StepRow(
                    step: progress.steps[i],
                    isLast: i == progress.steps.length - 1,
                    lineDone: progress.steps[i].done &&
                        i + 1 < progress.steps.length &&
                        progress.steps[i + 1].done,
                    trailing: progress.steps[i].done
                        ? _day(progress.steps[i].at)
                        : progress.steps[i].note,
                    doneColor: _green,
                    pendingColor: pending,
                    primaryText: primaryText,
                    secondaryText: secondaryText,
                  ),
              ],
              if (progress.arn.isNotEmpty) ...[
                const SizedBox(height: 14),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: progress.arn));
                    AppSnackbar.success(context, 'Bank reference copied');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          'Bank reference (ARN): ',
                          style: TextStyle(color: secondaryText, fontSize: 12.5),
                        ),
                        Flexible(
                          child: Text(
                            progress.arn,
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 14, color: secondaryText),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final RefundStep step;
  final bool isLast;
  final bool lineDone;
  final String trailing;
  final Color doneColor;
  final Color pendingColor;
  final Color primaryText;
  final Color secondaryText;

  const _StepRow({
    required this.step,
    required this.isLast,
    required this.lineDone,
    required this.trailing,
    required this.doneColor,
    required this.pendingColor,
    required this.primaryText,
    required this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Icon(
                  step.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: step.done ? doneColor : pendingColor,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: lineDone ? doneColor : pendingColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16, top: 1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      step.label,
                      style: TextStyle(
                        color: step.done ? primaryText : secondaryText,
                        fontSize: 14,
                        fontWeight: step.done ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (trailing.isNotEmpty)
                    Text(
                      trailing,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
