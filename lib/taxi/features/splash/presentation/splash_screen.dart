import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/update_service.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/application/auth_state.dart';
import '../../../taxi_section.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    UpdateService.checkForUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  /// No splash in Azanto: this is only a blank hand-off while the shared
  /// session is checked, then it goes straight to taxi home.
  Future<void> _bootstrap() async {
    final auth = ref.read(authControllerProvider.notifier);
    if (ref.read(authControllerProvider).status != AuthStatus.authenticated) {
      await auth.bootstrap();
    }
    if (!mounted) return;
    // One Azanto login: a signed-out rider goes to the shared login screen.
    if (ref.read(authControllerProvider).status != AuthStatus.authenticated) {
      TaxiSection.openLogin?.call();
      return;
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFFA0272))),
    );
  }
}
