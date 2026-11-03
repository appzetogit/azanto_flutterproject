import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/image_utils.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../shared/widgets/app_bottom_navigation_bar.dart';
import '../../../shared/widgets/exit_confirmation_dialog.dart';
import '../../auth/application/auth_providers.dart';
import '../../notifications/application/notifications_providers.dart';
import '../../ride/application/ride_providers.dart';
import '../application/booking_controller.dart';
import '../application/booking_state.dart';
import '../application/home_providers.dart';
import '../application/saved_places_provider.dart';
import 'location_access.dart';
import '../data/models/app_module_model.dart';
import '../data/models/saved_address_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late PageController _pageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startBannerAutoSlide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingControllerProvider.notifier).loadCatalog();
    });
  }

  void _startBannerAutoSlide() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(
      const Duration(seconds: 3, milliseconds: 500),
      (timer) {
        if (!mounted) return;
        final count = _bannerCount;
        if (count <= 1) return;

        final nextIndex = (_currentBannerIndex + 1) % count;
        if (_pageController.hasClients) {
          if (nextIndex == 0) {
            _pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            );
          } else {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _getBannerList() {
    final banners = ref.watch(bannersProvider).value ?? const [];
    if (banners.isNotEmpty) {
      return banners
          .map(
            (b) => {
              'image': (b['image'] ?? '').toString(),
              'link':
                  (b['redirect_url'] ??
                          b['external_link'] ??
                          b['deep_link'] ??
                          b['link'] ??
                          '')
                      .toString(),
            },
          )
          .toList();
    }
    return const [
      {'image': 'assets/taxi/banner.webp', 'link': ''},
      {'image': 'assets/taxi/banner.webp', 'link': ''},
    ];
  }

  int get _bannerCount => _getBannerList().length;

  Widget _buildPromoBanner() {
    final banners = _getBannerList();

    return SizedBox(
      height: 130,
      width: double.infinity,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentBannerIndex = index;
          });
        },
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final item = banners[index];
          final img = item['image'] ?? '';
          final link = item['link'] ?? '';

          Widget imageWidget;
          // The CMS stores banner images as server-relative paths, so testing
          // for `http` alone always fell through to the bundled placeholder —
          // the same bug the module icons had.
          final resolvedImg = resolveMediaUrl(img);
          if (resolvedImg.startsWith('http')) {
            imageWidget = CachedNetworkImage(
              imageUrl: resolvedImg,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 130,
              placeholder: (context, url) =>
                  Image.asset('assets/taxi/banner.webp', fit: BoxFit.cover),
              errorWidget: (context, url, error) =>
                  Image.asset('assets/taxi/banner.webp', fit: BoxFit.cover),
            );
          } else {
            imageWidget = Image.asset(
              resolvedImg.startsWith('assets/')
                  ? resolvedImg
                  : 'assets/taxi/banner.webp',
              fit: BoxFit.cover,
              width: double.infinity,
              height: 130,
              errorBuilder: (context, error, stackTrace) =>
                  Image.asset('assets/taxi/banner.webp', fit: BoxFit.cover),
            );
          }

          return GestureDetector(
            onTap: link.isEmpty ? null : () => _openBannerLink(link),
            child: imageWidget,
          );
        },
      ),
    );
  }

  Future<void> _openBannerLink(String link) async {
    if (link.startsWith('/')) {
      if (mounted) context.push(link);
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// The pickup for a Home/Work shortcut: the rider's location, or - when
  /// that is off and stays off - a point they choose on the map. Null when
  /// they back out of both.
  Future<BookingLocation?> _resolvePickupForShortcut() async {
    var position = await ref.read(currentPositionProvider.future);
    if (position == null && mounted) {
      final ok = await requestLocationAccess(context, ref);
      if (ok) position = await ref.read(currentPositionProvider.future);
    }

    if (position != null) {
      final address = await ref.read(currentAddressProvider.future);
      return BookingLocation(
        lat: position.latitude,
        lng: position.longitude,
        address: address.isNotEmpty ? address : 'Current location',
      );
    }

    if (!mounted) return null;
    final picked = await context.push<Map<String, dynamic>>(
      '/home/map-picker?type=pickup',
    );
    final address = (picked?['address'] ?? '').toString();
    final lat = (picked?['lat'] as num?)?.toDouble() ?? 0;
    final lng = (picked?['lng'] as num?)?.toDouble() ?? 0;
    if (address.isEmpty || (lat == 0 && lng == 0)) return null;
    return BookingLocation(lat: lat, lng: lng, address: address);
  }

  Future<void> _handleHomeWorkTap(
    String slotType,
    SavedAddressModel? saved,
  ) async {
    if (saved == null) {
      final result = await context.push<Map<String, dynamic>>(
        '/home/map-picker?type=drop',
      );
      if (result != null && mounted) {
        final String addr = result['address'] ?? '';
        final double lat = (result['lat'] as num?)?.toDouble() ?? 0;
        final double lng = (result['lng'] as num?)?.toDouble() ?? 0;
        if (addr.isNotEmpty && lat != 0 && lng != 0) {
          await ref
              .read(savedPlacesProvider.notifier)
              .saveHomeOrWork(
                type: slotType,
                address: addr,
                lat: lat,
                lng: lng,
              );
          if (mounted) {
            SnackbarUtils.info(
              context,
              '${slotType.toLowerCase() == 'home' ? 'Home' : 'Work'} location saved!',
            );
          }
        }
      }
    } else {
      // Pickup is where the rider is. When that is unknown it used to be
      // set to Indore, so a Home/Work tap from Bengaluru with location off
      // booked from Indore. Ask for location, and failing that let the rider
      // point at their pickup on the map.
      final pickupLoc = await _resolvePickupForShortcut();
      if (pickupLoc == null || !mounted) return;

      final dropLoc = BookingLocation(
        lat: saved.lat,
        lng: saved.lng,
        address: saved.address,
      );

      ref.read(bookingControllerProvider.notifier)
        ..setPickup(pickupLoc)
        ..setDrop(dropLoc);

      if (mounted) {
        context.push('/home/ride-types');
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning,';
    if (hour >= 12 && hour < 17) return 'Good afternoon,';
    if (hour >= 17 && hour < 22) return 'Good evening,';
    return 'Good night,';
  }

  Widget _buildOngoingRideCard(BuildContext context) {
    final ride = ref.watch(myActiveRideProvider).value;
    if (ride == null) return const SizedBox.shrink();

    const finished = {'completed', 'cancelled', 'canceled'};
    if (finished.contains(ride.liveStatus) || finished.contains(ride.status)) {
      return const SizedBox.shrink();
    }

    final isScheduled =
        ride.scheduledAt != null && ride.scheduledAt!.isAfter(DateTime.now());

    String statusTitle = 'ONGOING RIDE';
    IconData statusIcon = Icons.local_taxi_rounded;
    Color statusBadgeBg = const Color(0xFFFA0272);
    Color statusTextColor = const Color(0xFF0D1B2A);

    if (isScheduled || ride.status == 'scheduled') {
      statusTitle = 'SCHEDULED RIDE';
      statusIcon = Icons.access_time_filled_rounded;
      statusBadgeBg = const Color(0xFF1E88E5);
      statusTextColor = Colors.white;
    } else if (ride.liveStatus == 'accepted' || ride.liveStatus == 'arriving') {
      statusTitle = 'DRIVER ON THE WAY';
      statusIcon = Icons.directions_car_filled_rounded;
    } else if (ride.liveStatus == 'arrived') {
      statusTitle = 'DRIVER ARRIVED';
      statusIcon = Icons.where_to_vote_rounded;
      statusBadgeBg = const Color(0xFF10B981);
      statusTextColor = Colors.white;
    } else if (ride.liveStatus == 'started' || ride.liveStatus == 'ongoing') {
      statusTitle = 'TRIP IN PROGRESS';
      statusIcon = Icons.navigation_rounded;
    }

    final fareText = ride.fare > 0
        ? '₹${ride.fare.toStringAsFixed(ride.fare.truncateToDouble() == ride.fare ? 0 : 2)}'
        : '';

    final pickupText = ride.pickupAddress.isNotEmpty
        ? ride.pickupAddress
        : 'Pickup location';
    final dropText = ride.dropAddress.isNotEmpty
        ? ride.dropAddress
        : 'Drop location';

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: GestureDetector(
        onTap: () async {
          await context.push('/ride/tracking/${ride.rideId}');
          if (context.mounted) ref.invalidate(myActiveRideProvider);
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF112233),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFA0272), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33FA0272),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBadgeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 14, color: statusTextColor),
                          const SizedBox(width: 5),
                          Text(
                            statusTitle,
                            style: TextStyle(
                              color: statusTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (fareText.isNotEmpty) ...[
                          Text(
                            fareText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFF1E2D3D)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFA0272),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 18,
                          color: const Color(0xFF1E2D3D),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickupText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            dropText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFB0BEC5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final displayName = (user?.name != null && user!.name.isNotEmpty)
        ? user.name.split(' ').first
        : 'there';

    // Shown under "Pickup location". This used to fall back to a fixed
    // "415, Gandhi Nagar, Bengaluru" while loading, on error and with location
    // off - so every rider without a fix was told they were in Gandhi Nagar.
    final addressAsync = ref.watch(currentAddressProvider);
    final locationOff = addressAsync.hasValue && addressAsync.value!.isEmpty;
    final pickupAddress = addressAsync.when(
      data: (addr) => addr.isNotEmpty ? addr : 'Location off - tap to turn on',
      loading: () => 'Finding your location...',
      error: (e, st) => 'Location unavailable - tap to retry',
    );

    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    const bgColor = Color(0xFF0D1B2A); // Pure Dark Navy Theme
    const cardBgColor = Color(0xFF112233); // Dark Navy Card

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await showExitConfirmationDialog(context);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              SingleChildScrollView(
               // physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(top: 12, bottom: 64),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- 1. TOP HEADER BAR ---
                          Row(
                            children: [
                              // Hamburger Menu Icon
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.menu_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  context.push('/profile');
                                },
                              ),
                              const SizedBox(width: 12),

                              // Greeting Text Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getGreeting(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFFB0BEC5),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        const Text(
                                          '👋',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    const Text(
                                      "Let's make today productive!",
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Notification Bell with Badge
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF1E2D3D),
                                      ),
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.notifications_outlined,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        context.push('/notifications');
                                      },
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: Container(
                                        padding: const EdgeInsets.all(3.5),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFA0272),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '$unreadCount',
                                          style: const TextStyle(
                                            color: Color(0xFF0D1B2A),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 8),

                              // Profile Avatar Icon
                              GestureDetector(
                                onTap: () => context.push('/profile'),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: cardBgColor,
                                    border: Border.all(
                                      color: const Color(0xFF1E2D3D),
                                    ),
                                    image:
                                        (user?.profileImage != null &&
                                            user!.profileImage!.isNotEmpty)
                                        ? DecorationImage(
                                            image: CachedNetworkImageProvider(
                                              user.profileImage!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child:
                                      (user?.profileImage == null ||
                                          user!.profileImage!.isEmpty)
                                      ? const Icon(
                                          Icons.person_outline_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // --- 2. PICKUP & SEARCH CARD ---
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF1E2D3D),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  width: 170,
                                  height: 100,
                                  child: Opacity(
                                    opacity: 0.85,
                                    child: Image.asset(
                                      'assets/taxi/search.webp',
                                      fit: BoxFit.cover,
                                      alignment: Alignment.topRight,
                                      errorBuilder: (_, __, _) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(15.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFFA0272),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Pickup location',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFB0BEC5),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 16.0,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.52,
                                          ),
                                          child: GestureDetector(
                                            // Only does anything when there is
                                            // no location to show.
                                            onTap: locationOff || addressAsync.hasError
                                                ? () => requestLocationAccess(context, ref)
                                                : null,
                                            child: Text(
                                              pickupAddress,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: locationOff || addressAsync.hasError
                                                    ? const Color(0xFFFFB020)
                                                    : Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      // Search Bar Box (1:1 Matching Reference Screenshot)
                                      InkWell(
                                        onTap: () => context.push(
                                          '/search',
                                          // Same as tapping the "Azanto City Ride"
                                          // tile below — a bare "Where are you
                                          // going?" tap is a city ride, so it
                                          // should scope the vehicle list to
                                          // that module the same way.
                                          extra: 'Azanto City Ride',
                                        ),
                                        borderRadius: BorderRadius.circular(26),
                                        child: Container(
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            5,
                                            5,
                                            5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0A1624),
                                            borderRadius: BorderRadius.circular(
                                              26,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFF1E2D3D),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on_outlined,
                                                color: Color(0xFFFA0272),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              const Expanded(
                                                child: Text(
                                                  'Where are you going?',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFFA0272),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.search_rounded,
                                                  color: Color(0xFF0D1B2A),
                                                  size: 20,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // --- 3. QUICK SHORTCUT CARDS ROW (Work, Home, Saved 1:1 Matching Reference Design) ---
                          Builder(
                            builder: (context) {
                              final savedPlaces = ref.watch(
                                savedPlacesProvider,
                              );
                              final workPlace = savedPlaces.firstWhere(
                                (e) =>
                                    e.type.toLowerCase() == 'work' ||
                                    e.label.toLowerCase() == 'work',
                                orElse: () => const SavedAddressModel(
                                  id: '',
                                  label: 'Work',
                                  address: '',
                                  lat: 0,
                                  lng: 0,
                                  type: 'work',
                                ),
                              );
                              final homePlace = savedPlaces.firstWhere(
                                (e) =>
                                    e.type.toLowerCase() == 'home' ||
                                    e.label.toLowerCase() == 'home',
                                orElse: () => const SavedAddressModel(
                                  id: '',
                                  label: 'Home',
                                  address: '',
                                  lat: 0,
                                  lng: 0,
                                  type: 'home',
                                ),
                              );

                              return Row(
                                children: [
                                  // 1. Work Card
                                  _QuickShortcutCard(
                                    icon: Icons.work_rounded,
                                    iconColor: const Color(0xFF1E88E5),
                                    title: 'Work',
                                    subtitle: workPlace.address.isNotEmpty
                                        ? workPlace.address
                                        : 'Set location',
                                    // Unset -> drop a pin on the map and save it.
                                    // Set -> straight to picking a vehicle, with
                                    // pickup and drop already filled in.
                                    onTap: () => _handleHomeWorkTap(
                                      'work',
                                      workPlace.address.isEmpty
                                          ? null
                                          : workPlace,
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // 2. Home Card
                                  _QuickShortcutCard(
                                    icon: Icons.home_rounded,
                                    iconColor: const Color(0xFFEF4444),
                                    title: 'Home',
                                    subtitle: homePlace.address.isNotEmpty
                                        ? homePlace.address
                                        : 'Set location',
                                    onTap: () => _handleHomeWorkTap(
                                      'home',
                                      homePlace.address.isEmpty
                                          ? null
                                          : homePlace,
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // 3. Saved Card
                                  _QuickShortcutCard(
                                    icon: Icons.star_rounded,
                                    iconColor: const Color(0xFFFFB800),
                                    title: 'Saved',
                                    subtitle: 'Your places',
                                    onTap: () =>
                                        context.push('/home/saved-places'),
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 14),

                          // --- 4. GO AZANTO BRAND BANNER CAROUSEL ---
                          InkWell(
                            onTap: () => context.push('/search'),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: double.infinity,
                              height: 130,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF1E2D3D),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _buildPromoBanner(),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // --- 4b. ONGOING/SCHEDULED RIDE CARD ---
                          // Shrinks to nothing when there's no active ride —
                          // always in the tree so it appears the instant one
                          // starts, without a rebuild to insert it.
                          _buildOngoingRideCard(context),

                          const SizedBox(height: 8),

                          // --- 5. SERVICES / MODULES SECTION HEADER ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Go Azanto Services',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => context.push('/home/all-services'),
                                child: const Row(
                                  children: [
                                    Text(
                                      'View All',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFFFA0272),
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Dynamic Backend App Modules Grid (with fallbacks if empty)
                          _buildDynamicServicesGrid(),

                          const SizedBox(height: 18),

                          // --- 6. WHAT DO YOU NEED TODAY? SECTION ---
                          const Text(
                            'What do you need today?',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),

                          const SizedBox(height: 10),

                          // 2 Featured Action Cards (Ride Now & Azanto Parcel)
                          Row(
                            children: [
                              // Action Card 1: Ride Now
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => context.push('/search'),
                                  child: Container(
                                    height: 120,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF009688),
                                          Color.fromARGB(255, 1, 86, 78),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 8,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          right: -10,
                                          bottom: -2,
                                          child: Image.asset(
                                            'assets/taxi/ridenow1.webp',
                                            width: 118,
                                            height: 90,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Image.asset(
                                                      'assets/taxi/car.webp',
                                                      width: 110,
                                                      height: 85,
                                                      fit: BoxFit.contain,
                                                    ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Ride Now',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Book a ride instantly',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFFC0EBE6),
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF00C7B1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  color: Colors.white,
                                                  size: 17,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Action Card 2: Azanto Parcel
                              Expanded(
                                child: GestureDetector(
                                  onTap: () =>
                                      context.push('/delivery/vehicle'),
                                  child: Container(
                                    height: 120,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF155DB2),
                                          Color.fromARGB(255, 9, 40, 72),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 8,
                                          offset: Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          right: 0,
                                          bottom: 4,
                                          child: Image.asset(
                                            'assets/taxi/parcel.webp',
                                            width: 100,
                                            height: 80,
                                            fit: BoxFit.contain,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const SizedBox(),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Azanto Parcel',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                  letterSpacing: -0.2,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Send your parcel',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFFC8E0FF),
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF1E88E5),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.arrow_forward_rounded,
                                                  color: Colors.white,
                                                  size: 17,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // --- 7. BOTTOM BRAND BANNER ARTWORK (#GoAzanto Made for India) ---
                    _buildBottomBanner(),
                  ],
                ),
              ),

              // --- BOTTOM NAVIGATION BAR ---
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AppBottomNavigationBar(currentIndex: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Bottom brand artwork banner matching reference UI (#GoAzanto Made for India)
  Widget _buildBottomBanner() {
    return Image.asset(
      'assets/taxi/bottombanner.webp',
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );
  }

  /// Dynamic Backend Modules grid renderer (1:1 Match to Reference Design Section 5)
  Widget _buildDynamicServicesGrid() {
    final modulesAsync = ref.watch(appModulesProvider);

    return modulesAsync.when(
      data: (modules) {
        final activeModules = modules.where((m) => m.active).toList();
        if (activeModules.isNotEmpty) {
          final screenWidth = MediaQuery.of(context).size.width;
          final cardWidth = (screenWidth - 32 - 20) / 3;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: activeModules.map((module) {
              final route = _routeForModule(module);
              return SizedBox(
                width: cardWidth,
                child: InkWell(
                  onTap: () {
                    if (module.name.toLowerCase().contains('bus') ||
                        module.serviceType.toLowerCase().contains('bus') ||
                        module.transportType.toLowerCase().contains('bus')) {
                      SnackbarUtils.info(context, 'Feature is Upcoming...');
                      return;
                    }
                    final targetRoute = route == '/search'
                        ? '/home/search'
                        : route;
                    // _routeForModule already appends its own query string
                    // for the ride/delivery cases (moduleId, title, ...) —
                    // appending another `?title=` on top of that produced a
                    // malformed double-`?` URL that silently corrupted
                    // whichever query param came after it.
                    final finalRoute = targetRoute.contains('?')
                        ? targetRoute
                        : '$targetRoute?title=${Uri.encodeComponent(module.name)}';
                    context.push(finalRoute, extra: module.name);
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF112233),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF1E2D3D)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildModuleIcon(module),
                        const SizedBox(height: 6),
                        Text(
                          module.name,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          module.shortDescription.isNotEmpty
                              ? module.shortDescription
                              : _subtitleForModule(module),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        }
        // Services are managed in Admin → App Modules: none active, none shown.
        return const SizedBox.shrink();
      },
      loading: () => const SizedBox(height: 96),
      // Built-in list only when the backend can't be reached.
      error: (_, __) => _buildFallbackServicesGrid(),
    );
  }

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
    // module offers. Without it every module opened the same search screen and
    // the rider saw the whole catalog — an airport booking listed parcel
    // scooters.
    final query = <String>[
      'moduleId=${Uri.encodeComponent(module.id)}',
      'title=${Uri.encodeComponent(module.name)}',
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

  Widget _buildModuleIcon(AppModuleModel module) {
    const tealColor = Color(0xFFFA0272);
    final iconUrl = module.mobileMenuIcon;

    if (iconUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: iconUrl,
        width: 44,
        height: 44,
        fit: BoxFit.contain,
        placeholder: (context, url) =>
            Icon(_fallbackIconForModule(module), size: 42, color: tealColor),
        errorWidget: (context, url, error) =>
            Icon(_fallbackIconForModule(module), size: 42, color: tealColor),
      );
    }
    return Icon(_fallbackIconForModule(module), size: 42, color: tealColor);
  }

  IconData _fallbackIconForModule(AppModuleModel module) {
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

  /// Builds Azanto Services Grid fallback (3 in a row matching reference design)
  Widget _buildFallbackServicesGrid() {
    final services = [
      _ServiceItemData(
        title: 'Azanto Airport',
        subtitle: 'Airport Transfers',
        icon: Icons.flight_takeoff_rounded,
        onTap: () => context.push(
          '/home/search?title=Azanto%20Airport',
          extra: 'Azanto Airport',
        ),
      ),
      _ServiceItemData(
        title: 'Azanto City Ride',
        subtitle: 'Ride in City',
        icon: Icons.apartment_rounded,
        onTap: () => context.push(
          '/home/search?title=Azanto%20City%20Ride',
          extra: 'Azanto City Ride',
        ),
      ),
      _ServiceItemData(
        title: 'Azanto Parcel',
        subtitle: 'Parcel Delivery',
        icon: Icons.inventory_2_rounded,
        onTap: () => context.push(
          '/delivery/vehicle?title=Azanto%20Parcel',
          extra: 'Azanto Parcel',
        ),
      ),
      _ServiceItemData(
        title: 'Azanto Outstation',
        subtitle: 'Outstation Trips',
        icon: Icons.add_road_rounded,
        onTap: () => context.push(
          '/home/search?title=Azanto%20Outstation',
          extra: 'Azanto Outstation',
        ),
      ),
      _ServiceItemData(
        title: 'Azanto Bus',
        subtitle: 'Bus Tickets',
        icon: Icons.directions_bus_rounded,
        onTap: () => SnackbarUtils.info(context, 'Feature is Upcoming...'),
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 32 - 20) / 3;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: services.map((s) {
        return SizedBox(
          width: cardWidth,
          child: InkWell(
            onTap: s.onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF112233),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF1E2D3D)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(s.icon, size: 42, color: const Color(0xFFFA0272)),
                  const SizedBox(height: 6),
                  Text(
                    s.title,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    s.subtitle,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ServiceItemData {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ServiceItemData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

/// Quick Shortcut Card (Work, Home, Saved 1:1 Matching Reference Design)
class _QuickShortcutCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickShortcutCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: const Color(0xFF112233),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF112233),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E2D3D)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, size: 21, color: iconColor),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
