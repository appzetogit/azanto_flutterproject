import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../application/home_providers.dart';
import '../data/models/app_module_model.dart';

class ServiceCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String assetImage;
  final String route;

  const ServiceCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.assetImage,
    required this.route,
  });
}

class AllServicesScreen extends ConsumerWidget {
  const AllServicesScreen({super.key});

  static const List<ServiceCardData> _fallbackServices = [
    ServiceCardData(
      title: 'Azanto Airport',
      subtitle: 'Airport Transfers',
      icon: Icons.flight_takeoff_rounded,
      assetImage: 'assets/taxi/Ridenow.webp',
      route: '/search',
    ),
    ServiceCardData(
      title: 'Azanto City Ride',
      subtitle: 'Ride in City',
      icon: Icons.apartment_rounded,
      assetImage: 'assets/taxi/promo_car_banner.webp',
      route: '/search',
    ),
    ServiceCardData(
      title: 'Azanto Parcel',
      subtitle: 'Parcel Delivery',
      icon: Icons.inventory_2_rounded,
      assetImage: 'assets/taxi/Delivery.webp',
      route: '/delivery/vehicle',
    ),
    ServiceCardData(
      title: 'Azanto Outstation',
      subtitle: 'Outstation Trips',
      icon: Icons.add_road_rounded,
      assetImage: 'assets/taxi/outstation_service.webp',
      route: '/outstation',
    ),
    ServiceCardData(
      title: 'Azanto Bus',
      subtitle: 'Bus Tickets',
      icon: Icons.directions_bus_rounded,
      assetImage: 'assets/taxi/bottom_truck_bg.webp',
      route: '/search',
    ),
  ];

  static String _routeForModule(AppModuleModel module) {
    final tt = module.transportType.toLowerCase();
    final st = module.serviceType.toLowerCase();
    if (tt == 'delivery' || st == 'delivery') {
      // Carried the same way as the ride flow below, so the vehicle picker
      // can narrow itself to what this module actually offers instead of
      // showing every delivery vehicle regardless of which tile was tapped.
      return '/delivery/vehicle?moduleId=${Uri.encodeComponent(module.id)}';
    }
    if (st == 'rental') return '/rental';

    // The module id rides along so the vehicle list can show only what this
    // module offers — this card list used to drop it entirely, so opening a
    // module from "All Services" (rather than the home-screen grid) always
    // showed the full catalog regardless of which one was tapped.
    final query = <String>[
      'moduleId=${Uri.encodeComponent(module.id)}',
      if (st == 'outstation') 'outstation=1',
    ].join('&');
    return '/home/search?$query';
  }

  static String _subtitleForModule(AppModuleModel module) {
    final nameLower = module.name.toLowerCase();
    if (nameLower.contains('airport')) return 'Airport Transfers';
    if (nameLower.contains('city')) return 'Ride in City';
    if (nameLower.contains('parcel') || nameLower.contains('delivery'))
      return 'Parcel Delivery';
    if (nameLower.contains('outstation')) return 'Outstation Trips';
    if (nameLower.contains('bus')) return 'Bus Tickets';
    return 'Ride & Delivery';
  }

  static IconData _iconForModule(AppModuleModel module) {
    final lower = '${module.name} ${module.transportType} ${module.serviceType}'
        .toLowerCase();
    if (lower.contains('airport')) return Icons.flight_takeoff_rounded;
    if (lower.contains('city')) return Icons.apartment_rounded;
    if (lower.contains('parcel') || lower.contains('delivery'))
      return Icons.inventory_2_rounded;
    if (lower.contains('outstation')) return Icons.add_road_rounded;
    if (lower.contains('bus')) return Icons.directions_bus_rounded;
    if (lower.contains('bike')) return Icons.two_wheeler_rounded;
    return Icons.directions_car_rounded;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const bgColor = Color(0xFF0D1B2A);
    const cardBgColor = Color(0xFF112233);
    const borderColor = Color(0xFF1E2D3D);
    const tealColor = Color(0xFFFA0272);

    final modulesAsync = ref.watch(appModulesProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: bgColor,
        bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 1),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- TOP HEADER BAR WITH BACK ARROW & TITLE ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => context.go('/home'),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'All Services',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // --- VERTICAL LIST OF DYNAMIC / FALLBACK SERVICE CARDS ---
              Expanded(
                child: modulesAsync.when(
                  data: (modules) {
                    final activeModules = modules
                        .where((m) => m.active)
                        .toList();
                    if (activeModules.isNotEmpty) {
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: activeModules.length + 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == activeModules.length) {
                            return _buildBottomBanner();
                          }
                          final module = activeModules[index];
                          final route = _routeForModule(module);
                          final subtitle = module.shortDescription.isNotEmpty
                              ? module.shortDescription
                              : _subtitleForModule(module);

                          return GestureDetector(
                            onTap: () {
                              if (module.name.toLowerCase().contains('bus') ||
                                  module.serviceType.toLowerCase().contains(
                                    'bus',
                                  ) ||
                                  module.transportType.toLowerCase().contains(
                                    'bus',
                                  )) {
                                SnackbarUtils.info(
                                  context,
                                  'Feature is Upcoming...',
                                );
                                return;
                              }
                              final targetRoute = route == '/search'
                                  ? '/home/search'
                                  : route;
                              // _routeForModule already appends its own
                              // query string for the ride/delivery cases —
                              // appending another `?title=` on top of that
                              // would produce a malformed double-`?` URL.
                              final finalRoute = targetRoute.contains('?')
                                  ? '$targetRoute&title=${Uri.encodeComponent(module.name)}'
                                  : '$targetRoute?title=${Uri.encodeComponent(module.name)}';
                              context.push(finalRoute, extra: module.name);
                            },
                            child: Container(
                              height: 94,
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: borderColor),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 10,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                children: [
                                  // Content Row
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        // Module Icon / Image
                                        if (module.mobileMenuIcon.startsWith(
                                          'http',
                                        ))
                                          CachedNetworkImage(
                                            imageUrl: module.mobileMenuIcon,
                                            width: 36,
                                            height: 36,
                                            fit: BoxFit.contain,
                                            placeholder: (_, __) => Icon(
                                              _iconForModule(module),
                                              size: 36,
                                              color: tealColor,
                                            ),
                                            errorWidget: (_, __, _) => Icon(
                                              _iconForModule(module),
                                              size: 36,
                                              color: tealColor,
                                            ),
                                          )
                                        else
                                          Icon(
                                            _iconForModule(module),
                                            size: 36,
                                            color: tealColor,
                                          ),
                                        const SizedBox(width: 16),

                                        // Service Name & Subtitle
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                module.name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                subtitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Circular Arrow Button
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: const BoxDecoration(
                                            color: tealColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Color(0xFF0D1B2A),
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }
                    // Managed in Admin → App Modules.
                    return const Center(
                      child: Text(
                        'No services available right now',
                        style: TextStyle(color: Color(0xFF94A3B8)),
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFA0272)),
                  ),
                  error: (_, __) =>
                      _buildFallbackList(cardBgColor, borderColor, tealColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackList(
    Color cardBgColor,
    Color borderColor,
    Color tealColor,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: _fallbackServices.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == _fallbackServices.length) {
          return _buildBottomBanner();
        }
        final item = _fallbackServices[index];
        return GestureDetector(
          onTap: () {
            if (item.title.toLowerCase().contains('bus')) {
              SnackbarUtils.info(context, 'Feature is Upcoming...');
              return;
            }
            final targetRoute = item.route == '/search'
                ? '/home/search'
                : item.route;
            context.push(
              '$targetRoute?title=${Uri.encodeComponent(item.title)}',
              extra: item.title,
            );
          },
          child: Container(
            height: 94,
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  right: 30,
                  top: 0,
                  bottom: 0,
                  width: 110,
                  child: Opacity(
                    opacity: 0.85,
                    child: Image.asset(
                      item.assetImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon, size: 36, color: tealColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: tealColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF0D1B2A),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF112233),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E2D3D)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/taxi/bottombanner.webp',
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }
}
