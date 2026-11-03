import 'package:flutter/material.dart';

/// The highlighted "out of our zones" message card — used on the address
/// screen and embedded contexts when a pin is outside serviceable coverage.
class OutOfZoneNotice extends StatelessWidget {
  const OutOfZoneNotice({super.key, this.zoneName});

  final String? zoneName;

  static const message =
      'Sorry, you are out of our zones. We currently serve only in Bhiwandi and nearby.';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zone = (zoneName != null && zoneName!.trim().isNotEmpty)
        ? zoneName!.trim()
        : 'Bhiwandi';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF281414) : const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
          width: 1.3,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF451A1A) : const Color(0xFFFFE4E6),
              border: Border.all(
                color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFDA4AF),
                width: 1.2,
              ),
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 24,
                  color: Color(0xFFDC2626),
                ),
                Positioned(
                  top: 11,
                  child: Icon(
                    Icons.close_rounded,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Service not available',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'We currently serve only in $zone and nearby areas.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.32,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
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
