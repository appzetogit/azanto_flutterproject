import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/widgets/feedback/app_dialog.dart';

import '../../core/constants/app_durations.dart';
import '../../core/utils/app_haptics.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../di/app_providers.dart';
import '../../../di/mart_enabled_provider.dart';
import '../../../presentation/mode/mode_switch_button.dart';
import '../common/widgets/misc/fly_to_cart.dart';
import '../common/widgets/misc/mart_view_cart_bar.dart';
import '../screens/home/widgets/maavamart_maintenance_screen.dart';

/// Bottom navigation for the top-level destinations, with the module switch
/// raised into the centre.
///
/// Cart is a plain nav item and carries [cartAnchorKey] so the fly-to-cart
/// animation still knows where to land from anywhere in the app.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// The visual order differs from the router's branch order, so each item
  /// names its branch explicitly rather than relying on position.
  /// Router branches: 0 home · 1 categories · 2 cart · 3 orders · 4 profile.
  static const _cartBranchIndex = 2;
  static const _homeBranchIndex = 0;

  static const _left = [
    (0, Icons.home_outlined, Icons.home_rounded, 'Home'),
    (1, Icons.grid_view_outlined, Icons.grid_view_rounded, 'Categories'),
  ];

  static const _right = [
    (_cartBranchIndex, Icons.shopping_cart_outlined, Icons.shopping_cart_rounded,
        'Cart'),
    (4, Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
  ];

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _isNavVisible = true;

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _isNavVisible = true;
    }
  }

  void _go(int index) {
    if (index != widget.navigationShell.currentIndex) AppHaptics.selection();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartItemCountProvider);
    final current = widget.navigationShell.currentIndex;
    // Defaults true while the flag is loading/unreachable, matching
    // HomeScreen's own read of this provider — the nav bar must never
    // disappear because of a slow or failed request.
    final martEnabled = ref.watch(martEnabledProvider).asData?.value ?? true;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (current != AppShell._homeBranchIndex) {
          _go(AppShell._homeBranchIndex);
          return;
        }
        await _confirmExit(context);
      },
      child: _scaffold(context, cartCount, current, martEnabled),
    );
  }

  Future<void> _confirmExit(BuildContext context) async {
    final shouldExit = await AppDialog.confirm(
      context,
      icon: Icons.exit_to_app_rounded,
      title: 'Do you want to exit the app?',
      message: 'Your cart is saved and will be waiting when you come back.',
      confirmLabel: 'Exit',
      cancelLabel: 'Cancel',
    );
    if (!shouldExit) return;

    await SystemNavigator.pop();
  }

  Widget _scaffold(
    BuildContext context,
    int cartCount,
    int current,
    bool martEnabled,
  ) {
    return Scaffold(
      // Admin-disabled: the whole section is off, not just the Home tab —
      // a shopper already sitting on Categories/Cart/Orders/Profile when the
      // flag flips must land on the same maintenance screen, not keep
      // browsing whichever tab they happened to be on. This replaces
      // HomeScreen's own (now redundant) martEnabled check as the single
      // place that decides "is Mart usable at all".
      body: !martEnabled
          ? MaavaMartMaintenanceScreen(
              title: 'Azanto MART',
              subtitle: 'Not Serving Your Area… Yet! 💜',
              body: "We'll be back soon. Stay tuned!",
              onRetry: () => ref.invalidate(martEnabledProvider),
            )
          : Stack(
              children: [
                NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis == Axis.vertical) {
                      if (notification.direction == ScrollDirection.reverse) {
                        if (_isNavVisible) {
                          setState(() => _isNavVisible = false);
                        }
                      } else if (notification.direction ==
                              ScrollDirection.forward ||
                          notification.metrics.extentBefore == 0) {
                        if (!_isNavVisible) {
                          setState(() => _isNavVisible = true);
                        }
                      }
                    }
                    return false;
                  },
                  child: widget.navigationShell,
                ),
                if (current != AppShell._cartBranchIndex)
                  const MartViewCartBar(bottomOffset: 12),
              ],
            ),
      // Admin-disabled: MaavaMartMaintenanceScreen's own back arrow is the
      // only way out, so the tab bar (which would otherwise reveal Cart,
      // Categories, Profile — none of them functional while Mart is off)
      // is dropped entirely rather than just hidden.
      bottomNavigationBar: !martEnabled ? null : AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Container(
          height: _isNavVisible ? null : 0.0,
          clipBehavior: _isNavVisible ? Clip.none : Clip.hardEdge,
          decoration: const BoxDecoration(),
          child: AnimatedSlide(
            offset: _isNavVisible ? Offset.zero : const Offset(0, 1.3),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(top: BorderSide(color: context.semantic.border)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 68,
                  child: Row(
                    children: [
                      for (final item in AppShell._left)
                        Expanded(
                          child: _NavItem(
                            spec: item,
                            selected: current == item.$1,
                            onTap: () => _go(item.$1),
                          ),
                        ),
                      const Expanded(
                        child: Center(child: ModeSwitchButton(diameter: 52)),
                      ),
                      for (final item in AppShell._right)
                        Expanded(
                          child: _NavItem(
                            spec: item,
                            selected: current == item.$1,
                            onTap: () => _go(item.$1),
                            count: item.$1 == AppShell._cartBranchIndex ? cartCount : 0,
                            anchorKey:
                                item.$1 == AppShell._cartBranchIndex ? cartAnchorKey : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
    this.count = 0,
    this.anchorKey,
  });

  /// (branch index, unselected icon, selected icon, label)
  final (int, IconData, IconData, String) spec;
  final bool selected;
  final VoidCallback onTap;

  /// Item count shown as a badge on the icon; 0 hides it. Cart only.
  final int count;

  /// Landing point for the fly-to-cart animation. Cart only.
  final Key? anchorKey;

  @override
  Widget build(BuildContext context) {
    final color =
        selected ? context.colors.primary : const Color(0xFF6B7280);

    return Semantics(
      button: true,
      selected: selected,
      label: count > 0 ? '${spec.$4}, $count items' : spec.$4,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              key: anchorKey,
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(selected ? spec.$3 : spec.$2, size: 24, color: color),
                if (count > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(count),
                      tween: Tween(begin: 0.6, end: 1),
                      duration: AppDurations.medium,
                      curve: Curves.elasticOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 1,
                        ),
                        constraints: const BoxConstraints(minWidth: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: AppRadii.rPill,
                          border: Border.all(
                            color: context.colors.surface,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: context.text.labelSmall!.copyWith(
                            color: context.colors.surface,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              spec.$4,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall!.copyWith(
                color: selected ? context.semantic.accent : const Color(0xFF6B7280),
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                fontSize: 10.5,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              height: 3,
              width: 16,
              decoration: BoxDecoration(
                color: selected ? context.semantic.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
