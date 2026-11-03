import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


/// The 5-item footer trust strip matching the bottom of the screenshot.
class FeatureHighlightsRow extends StatelessWidget {
  const FeatureHighlightsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final items = const [
      _FeatureData(
        icon: Icons.eco_outlined,
        title: 'Best Quality',
        subtitle: 'We deliver only the freshest & finest products.',
      ),
      _FeatureData(
        icon: Icons.sell_outlined,
        title: 'Affordable Prices',
        subtitle: 'Best prices & exclusive offers on all your favorite products.',
      ),
      _FeatureData(
        icon: Icons.local_shipping_outlined,
        title: 'Fast Delivery',
        subtitle: 'Lightning fast delivery at your doorstep on time.',
      ),
      _FeatureData(
        icon: Icons.lock_outline_rounded,
        title: '100% Secure',
        subtitle: 'Your payments and data are safe with us.',
      ),
      _FeatureData(
        icon: Icons.autorenew_rounded,
        title: 'Easy Returns',
        subtitle: 'Not satisfied? Easy returns within 7 days of delivery.',
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          return Container(
            width: 145,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: context.colors.primary,
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 10.5,
                    color: context.colors.onSurface,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 8.5,
                    color: const Color(0xFF64748B),
                    height: 1.15,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FeatureData {
  const _FeatureData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
