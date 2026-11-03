import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../checkout/viewmodels/checkout_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/address_viewmodel.dart';
import '../../home/widgets/location_access_prompt.dart';
import '../../home/viewmodels/user_location_provider.dart';

/// Switches which saved address the order goes to.
///
/// Picking one makes it the default, because that is what the cart, checkout
/// and the price preview all read — there is no separate "selected address"
/// anywhere, so setting the default is what actually moves the order.
class AddressPickerSheet {
  const AddressPickerSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddressPickerBody(),
    );
  }
}

class _AddressPickerBody extends ConsumerWidget {
  const _AddressPickerBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final addresses = ref.watch(addressViewModelProvider);
    final exploring = ref.watch(exploringHereProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: isDark ? context.bg(Color(0xFF0F172A)) : context.bg(Colors.white),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? context.bg(Color(0xFF334155)) : context.bg(Color(0xFFCBD5E1)),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Offered here rather than only on Home: this sheet is what opens
          // when location is off, so the invitation to turn it on belongs
          // alongside the addresses that work without it.
          const LocationPermissionBanner(borderRadius: 14),

          Text(
            'Select Delivery Address',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : context.fg(Color(0xFF0F172A)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Browse restaurants that deliver to this address',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? context.fg(Color(0xFF94A3B8)) : context.fg(Color(0xFF64748B)),
            ),
          ),
          const SizedBox(height: 14),

          // Browse without saving an address; one is asked for at checkout.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              Haptics.light();
              final messenger = ScaffoldMessenger.maybeOf(context);
              Navigator.of(context).pop();
              final here = await UserLocation.current(forceRefresh: true);
              if (here == null) {
                messenger?.showSnackBar(
                  const SnackBar(content: Text('Turn on location to explore restaurants near you')),
                );
                return;
              }
              ref.invalidate(userLocationProvider);
              ref.read(exploringHereProvider.notifier).set(true);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: exploring
                    ? context.bg(AppColors.primaryTint)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: exploring ? AppColors.primary : context.line(Color(0xFFE2E8F0)),
                  width: exploring ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.my_location_rounded, size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Use my current location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : context.fg(Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Explore restaurants near you. You can add the address at checkout.',
                          style: TextStyle(fontSize: 11.5, color: context.fg(Color(0xFF64748B))),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (addresses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No saved addresses yet.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? context.fg(Color(0xFF94A3B8)) : context.fg(Color(0xFF64748B)),
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: addresses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final address = addresses[i];
                  final selected = address.isDefault && !exploring;
                  return GestureDetector(
                    onTap: () async {
                      Haptics.light();
                      Navigator.of(context).pop();
                      // A saved address ends "exploring near me".
                      ref.read(exploringHereProvider.notifier).set(false);
                      if (selected) return;
                      await ref
                          .read(addressViewModelProvider.notifier)
                          .setDefaultAddress(address.id);
                      // The bill is priced against the delivery address, so a
                      // change here has to re-run the preview.
                      await ref
                          .read(checkoutViewModelProvider.notifier)
                          .setAddress(address.id);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected
                            ? context.bg(AppColors.primaryTint)
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : context.line(Color(0xFFE2E8F0)),
                          width: selected ? 1.4 : 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 20,
                            color: selected
                                ? AppColors.primary
                                : context.fg(Color(0xFF94A3B8)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  address.title.isEmpty
                                      ? 'Address'
                                      : address.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : context.fg(Color(0xFF0F172A)),
                                  ),
                                ),
                                if (address.fullAddress.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    address.fullAddress,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.3,
                                      fontWeight: FontWeight.w500,
                                      color: context.fg(Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () {
                Haptics.light();
                Navigator.of(context).pop();
                context.push(RouteNames.addAddress);
              },
              icon: Icon(Icons.add_rounded, size: 18, color: AppColors.primaryDeep),
              label: Text(
                'Enter Location Manually',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDeep,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primaryDeep, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
