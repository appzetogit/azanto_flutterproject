import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:azanto/taxi/shared/widgets/app_bottom_navigation_bar.dart';

/// The taxi bar's centre disc reads "Food" (no logo) and fits the bar.
void main() {
  testWidgets('centre disc says Food and does not overflow', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(
          bottomNavigationBar: AppBottomNavigationBar(currentIndex: 0),
        ),
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    expect(find.text('Food'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
