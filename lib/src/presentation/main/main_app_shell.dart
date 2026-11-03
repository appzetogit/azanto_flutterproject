import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme/active_brand.dart';
import 'package:go_router/go_router.dart';

import '../../di/socket_providers.dart';
import '../common_widgets/offline_banner.dart';
import '../orders/viewmodels/active_order_viewmodel.dart';
import '../orders/widgets/floating_active_order_card.dart';
import 'widgets/custom_bottom_nav.dart';
import '../cart/viewmodels/cart_viewmodel.dart';
import '../navigation/route_names.dart';

import 'package:flutter/services.dart';
import '../common_widgets/exit_confirmation_dialog.dart';

class MainAppShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainAppShell({super.key, required this.navigationShell});

  @override
  ConsumerState<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends ConsumerState<MainAppShell> {
  bool _isNavVisible = true;

  @override
  void didUpdateWidget(MainAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _isNavVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the single app-wide socket connection alive for the whole
    // session (order tracking + chat both read it).
    ref.watch(socketConnectionProvider);
    // The bottom nav reads AppColors.primary directly (not Theme.of), so it
    // needs its own dependency on the color provider to repaint instantly.
    ref.watch(activeBrandProvider);
    final activeOrder = ref.watch(activeOrderViewModelProvider).activeOrder;

    final cartState = ref.watch(cartViewModelProvider);
    final hasCartItems = cartState.items.isNotEmpty;

    final router = GoRouter.of(context);

    final screensWithCartBar = {
      RouteNames.home,
      RouteNames.store99,
      RouteNames.restaurantDetail,
      RouteNames.foodDetail,
      RouteNames.allOffers,
    };

    return AnimatedBuilder(
      animation: router.routerDelegate,
      builder: (context, child) {
        final currentPath = router.routerDelegate.currentConfiguration.uri.path;
        final isCartBarVisible = hasCartItems && screensWithCartBar.contains(currentPath);
        final double bottomOffset = (currentPath == RouteNames.foodDetail) ? 120.0 : 24.0;
        
        final isHome = currentPath == RouteNames.home;
        final double targetBottom = isHome
            ? (isCartBarVisible ? (bottomOffset + 56.0 + 16.0) : 12.0)
            : -120.0;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (widget.navigationShell.currentIndex != 0) {
              widget.navigationShell.goBranch(0);
            } else {
              final shouldExit = await showExitConfirmationDialog(context);
              if (shouldExit == true) {
                SystemNavigator.pop();
              }
            }
          },
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Stack(
              children: [
                NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.axis == Axis.vertical) {
                      if (notification.direction == ScrollDirection.reverse) {
                        if (_isNavVisible) {
                          setState(() => _isNavVisible = false);
                        }
                      } else if (notification.direction == ScrollDirection.forward ||
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
                if (activeOrder != null)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: 16,
                    right: 16,
                    bottom: targetBottom,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      opacity: isHome ? 1.0 : 0.0,
                      child: IgnorePointer(
                        ignoring: !isHome,
                        child: FloatingActiveOrderCard(
                          order: activeOrder,
                          isCompact: isCartBarVisible,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: AnimatedSize(
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const OfflineBanner(),
                      CustomBottomNav(
                        currentIndex: widget.navigationShell.currentIndex,
                        onTap: (index) {
                          widget.navigationShell.goBranch(
                            index,
                            initialLocation:
                                index == widget.navigationShell.currentIndex,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
