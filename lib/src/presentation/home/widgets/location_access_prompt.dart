import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';

import '../../branding/app_colors.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/user_location_provider.dart';
import '../viewmodels/zone_viewmodel.dart';

/// Full-screen Location Guard rendered when location service is disabled or permission missing.
/// Users cannot access or see any app content until location is enabled.
class LocationRequiredView extends ConsumerStatefulWidget {
  const LocationRequiredView({super.key});

  @override
  ConsumerState<LocationRequiredView> createState() => _LocationRequiredViewState();
}

class _LocationRequiredViewState extends ConsumerState<LocationRequiredView> {
  bool _isChecking = false;
  AppLifecycleListener? _lifecycleListener;
  StreamSubscription<ServiceStatus>? _serviceStatusSubscription;

  @override
  void initState() {
    super.initState();
    // Auto-refresh when coming back to app from settings
    _lifecycleListener = AppLifecycleListener(
      onResume: _refreshLocationState,
    );
    // Auto-refresh when location toggle switches on at system level
    _serviceStatusSubscription = Geolocator.getServiceStatusStream().listen((status) {
      if (status == ServiceStatus.enabled) {
        _refreshLocationState();
      }
    });
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    _serviceStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshLocationState() async {
    if (!mounted || _isChecking) return;
    setState(() => _isChecking = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          ref.invalidate(userLocationProvider);
          ref.invalidate(zoneViewModelProvider);
          ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true);
        }
      }
    } catch (_) {} finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _handleEnableLocation() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }
      }
    } catch (_) {}

    ref.invalidate(userLocationProvider);
    ref.invalidate(zoneViewModelProvider);
    ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true);

    if (mounted) {
      setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.backgroundDark : const Color(0xFFFAFDFF);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 96.w,
                height: 96.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Icon(
                    Icons.location_off_rounded,
                    size: 48.sp,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: 28.h),
              Text(
                'Location Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'MintoFood requires your location to discover nearby restaurants, check delivery serviceability, and deliver your food.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  height: 1.5,
                  color: isDark ? context.fg(Color(0xFF94A3B8)) : context.fg(Color(0xFF64748B)),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 36.h),
              SizedBox(
                width: double.infinity,
                height: 52.h,
                child: ElevatedButton.icon(
                  onPressed: _isChecking ? null : _handleEnableLocation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                  ),
                  icon: _isChecking
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(Icons.my_location_rounded, size: 20.sp),
                  label: Text(
                    _isChecking ? 'Checking Location…' : 'Enable Location',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              TextButton(
                onPressed: _refreshLocationState,
                child: Text(
                  'Check Location Status',
                  style: TextStyle(
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class LocationAccessPrompt {
  const LocationAccessPrompt._();

  static Future<void> ensure(BuildContext context, WidgetRef ref) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (serviceEnabled &&
        (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always)) {
      ref.invalidate(userLocationProvider);
      ref.invalidate(zoneViewModelProvider);
    }
  }
}

/// True when the phone cannot place the customer — location off, or permission
/// refused, with no last known fix.
///
/// Distinct from having nowhere to deliver: a saved address still gives the app
/// a point to work from (see `deliveryPointProvider`), so this only drives the
/// "turn it on" prompt, never a block.
final locationPermissionOffProvider = Provider<bool>((ref) {
  final async = ref.watch(userLocationProvider);
  return async.hasValue && async.value == null && UserLocation.lastKnown == null;
});

/// The "Location Permission is Off — GRANT" strip.
///
/// Shown instead of blocking the app: the order is going to a saved address, so
/// the customer can browse and order without ever granting location. Renders
/// nothing once location is available.
class LocationPermissionBanner extends ConsumerStatefulWidget {
  const LocationPermissionBanner({super.key, this.borderRadius = 0});

  /// Rounded when it sits inside a padded sheet; square when it runs
  /// edge-to-edge under the Home header.
  final double borderRadius;

  @override
  ConsumerState<LocationPermissionBanner> createState() =>
      _LocationPermissionBannerState();
}

class _LocationPermissionBannerState
    extends ConsumerState<LocationPermissionBanner> {
  bool _isRequesting = false;

  Future<void> _grant() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        // The app cannot turn the radio on; only Settings can.
        await Geolocator.openLocationSettings();
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
        }
      }
    } catch (_) {}

    ref.invalidate(userLocationProvider);
    ref.invalidate(zoneViewModelProvider);
    if (mounted) setState(() => _isRequesting = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(locationPermissionOffProvider)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryDeep,
        borderRadius: BorderRadius.circular(widget.borderRadius),
      ),
      margin: EdgeInsets.only(bottom: widget.borderRadius > 0 ? 14.h : 0),
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 12.w, 12.h),
      child: Row(
        children: [
          Icon(Icons.my_location_rounded, color: Colors.white, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Location Permission is Off',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Granting location permission will ensure accurate address and hassle-free delivery',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11.5.sp,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          TextButton(
            onPressed: _isRequesting ? null : _grant,
            style: TextButton.styleFrom(
              backgroundColor: context.bg(Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6.r),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              minimumSize: Size(0, 36.h),
            ),
            child: _isRequesting
                ? SizedBox(
                    width: 14.w,
                    height: 14.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'GRANT',
                    style: TextStyle(
                      color: AppColors.primaryDeep,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
