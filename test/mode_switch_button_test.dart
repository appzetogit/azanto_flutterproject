import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:azanto/src/presentation/branding/theme_color_provider.dart';
import 'package:azanto/src/presentation/mode/mode_switch_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The centre disc of the food bottom bar opens the Taxi section (Mart is gone).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('reads Taxi in the brand colour and opens /taxi', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(bottomNavigationBar: ModeSwitchButton()),
        ),
        GoRoute(path: '/taxi', builder: (_, _) => const Text('taxi-section')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Taxi'), findsOneWidget);
    final disc = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);
    expect((disc.decoration! as BoxDecoration).color, AppThemeColor.azanto.color);

    await tester.tap(find.text('Taxi'));
    await tester.pumpAndSettle();
    expect(find.text('taxi-section'), findsOneWidget);
  });
}
