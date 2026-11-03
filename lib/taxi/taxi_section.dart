import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import '../src/presentation/auth/viewmodels/auth_viewmodel.dart';
import 'app/app.dart';
import 'app/router.dart';
import 'core/providers/core_providers.dart';
import 'core/storage/local_storage_service.dart';
import 'core/services/route_api.dart';
import 'core/services/socket_service.dart';
import 'core/storage/secure_storage_service.dart';
import '../src/di/network_providers.dart' as food;
import 'features/ride/voice/application/ride_voice_providers.dart';

/// Azanto's Taxi section — the taxi module (lib/taxi) running as a nested app
/// under the host's `/taxi` route. It keeps its own router, theme and login
/// (taxi auth is separate on the backend: /api/v1/taxi/users/...).
class TaxiSection extends ConsumerStatefulWidget {
  const TaxiSection({super.key});

  /// Taxi storage, opened once at startup. Spread into the root ProviderScope.
  static Future<List<Override>> overrides() async {
    final local = LocalStorageService();
    await local.init();
    return [
      localStorageServiceProvider.overrideWithValue(local),
      // One Azanto login: taxi rides on the food session.
      secureStorageServiceProvider.overrideWith((ref) {
        final s = SecureStorageService(
          ref.watch(food.tokenStorageProvider),
          ref.watch(food.apiClientProvider),
        );
        RouteApi.storage = s;
        SocketService.freshToken = s.validToken;
        return s;
      }),
    ];
  }

  /// Leaves the taxi section for Food home. Set while the section is mounted;
  /// the taxi bottom bar's "Food" button calls it.
  static VoidCallback? exitToFood;

  /// Sends a signed-out rider to the shared Azanto login; after OTP the food
  /// login returns to /taxi. The taxi router is reset to its splash so the
  /// section re-checks the session when it comes back.
  static VoidCallback? openLogin;

  /// Signs out of Azanto (the one shared account) and returns to Food home.
  static Future<void> Function()? signOut;

  @override
  ConsumerState<TaxiSection> createState() => _TaxiSectionState();
}

class _TaxiSectionState extends ConsumerState<TaxiSection> {
  ChildBackButtonDispatcher? _back;

  @override
  void initState() {
    super.initState();
    TaxiSection.exitToFood = () {
      if (mounted) context.go('/home');
    };
    TaxiSection.openLogin = () {
      appRouter.go('/');
      if (mounted) context.go('/login?from=/taxi');
    };
    TaxiSection.signOut = () async {
      await ref.read(authViewModelProvider.notifier).logout();
      appRouter.go('/');
      if (mounted) context.go('/home');
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        ref.read(rideVoiceSchedulerProvider).resumeActiveRide();
      } catch (_) {}
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _back ??= Router.of(context).backButtonDispatcher?.createChildBackButtonDispatcher();
    _back?.takePriority();
  }

  @override
  void dispose() {
    final back = _back;
    if (back != null) back.parent.forget(back);
    TaxiSection.exitToFood = null;
    TaxiSection.openLogin = null;
    TaxiSection.signOut = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TaxiUserApp(backButtonDispatcher: _back);
  }
}
