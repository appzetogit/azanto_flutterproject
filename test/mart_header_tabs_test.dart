import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/di/app_providers.dart';
import 'package:azanto/src/quick/di/service_providers.dart';
import 'package:azanto/src/quick/domain/model/address.dart';
import 'package:azanto/src/quick/domain/model/category.dart';
import 'package:azanto/src/quick/ui/screens/home/widgets/delivery_header.dart';
import 'package:azanto/src/quick/ui/screens/notifications/notifications_provider.dart';

/// The header strip highlighted 'All' no matter what was selected: the plate,
/// border and indicator were keyed on `item.id == 'all'` rather than on the
/// selection, so picking Grocery re-themed the whole page while the strip
/// still pointed at All.
class _QuietNotifications extends NotificationsController {
  @override
  NotificationsState build() => const NotificationsState();
}

const _categories = [
  // One with artwork, one without — the mix that produced the icon/photo
  // inconsistency in the strip.
  Category(id: 'c1', name: 'Grocery', showInHeader: true),
  Category(
    id: 'c2',
    name: 'Fruits & Vegetables',
    imageUrl: 'https://img/fruit.jpg',
    showInHeader: true,
  ),
];

Future<void> _pump(
  WidgetTester tester,
  String selectedId, {
  Address? address,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        selectedAddressProvider.overrideWithValue(address),
        // Header reads the storefront name from the backend; without this the
        // real repository fires an HTTP call and leaves a timer pending.
        storeNameProvider.overrideWith((ref) async => 'MaavaMart'),
        notificationsProvider.overrideWith(_QuietNotifications.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: DeliveryHeader(
            categories: _categories,
            selectedCategoryId: selectedId,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The label of the tab wearing the visual highlight.
///
/// Deliberately keyed on the PLATE (its border) rather than the label's font
/// weight: the weight already followed the selection while the plate, border
/// and indicator were pinned to 'All', so a font-weight assertion passes on the
/// broken build and proves nothing.
String? _highlightedLabel(WidgetTester tester) {
  for (final label in ['All', ..._categories.map((c) => c.name)]) {
    final plated = find.descendant(
      of: find.ancestor(
        of: find.text(label),
        matching: find.byType(Column),
      ).first,
      matching: find.byWidgetPredicate((w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).border != null),
    );
    if (plated.evaluate().isNotEmpty) return label;
  }
  return null;
}

void main() {
  testWidgets('an empty selection highlights the All reset tab', (tester) async {
    await _pump(tester, '');
    expect(_highlightedLabel(tester), 'All');
  });

  testWidgets('selecting a category moves the highlight off All', (tester) async {
    await _pump(tester, 'c1');
    expect(_highlightedLabel(tester), 'Grocery');

    await _pump(tester, 'c2');
    expect(_highlightedLabel(tester), 'Fruits & Vegetables');
  });

  testWidgets('a long category name wraps instead of widening its tile',
      (tester) async {
    await _pump(tester, '');
    final long = tester.widget<Text>(find.text('Fruits & Vegetables'));
    expect(long.maxLines, 2);
    expect(long.textAlign, TextAlign.center);

    // Every tile is the same width, so one long name cannot stretch the strip.
    // Measured per tab rather than by collecting every SizedBox in the header:
    // the artwork widgets bring their own sized boxes.
    double tileWidth(String label) => tester
        .getSize(
          find
              .ancestor(of: find.text(label), matching: find.byType(SizedBox))
              .first,
        )
        .width;
    expect(tileWidth('Fruits & Vegetables'), tileWidth('Grocery'));
    expect(tileWidth('Grocery'), tileWidth('All'));
  });

  testWidgets('the strip is photographs only — no glyph on any tab',
      (tester) async {
    await _pump(tester, '');

    // Icons elsewhere in the header (the address caret, the notification bell)
    // are fine; the category strip itself must carry none, or the tab without
    // artwork reads as a broken image sitting between photographs.
    final strip = find.ancestor(
      of: find.text('All'),
      matching: find.byType(ListView),
    );
    expect(strip, findsOneWidget);
    expect(
      find.descendant(of: strip, matching: find.byType(Icon)),
      findsNothing,
    );
  });

  testWidgets('a category with no artwork still gets the same plate',
      (tester) async {
    await _pump(tester, '');

    // Same box for both tabs, whether or not the admin has uploaded an image,
    // so the strip stays even while the catalogue is being filled in.
    Size plate(String label) => tester.getSize(
          find
              .descendant(
                of: find.ancestor(
                  of: find.text(label),
                  matching: find.byType(Column),
                ).first,
                matching: find.byType(Container),
              )
              .first,
        );
    expect(plate('Grocery'), plate('Fruits & Vegetables'));
  });

  group('delivery address', () {
    // The fallback was a literal Indore address, so a signed-out user was shown
    // an office none of them had set as though it were their delivery address.
    testWidgets('with no saved address it prompts instead of inventing one',
        (tester) async {
      await _pump(tester, '');

      expect(find.text('Tap to save address'), findsOneWidget);
      expect(find.textContaining('Princess Center'), findsNothing);
      expect(find.textContaining('Indore'), findsNothing);
    });

    testWidgets('a real saved address is shown with its label', (tester) async {
      await _pump(
        tester,
        '',
        address: const Address(
          id: 'a1',
          label: AddressLabel.home,
          street: '12 Residency Road',
          city: 'Indore',
          state: 'Madhya Pradesh',
          zipCode: '452001',
          latitude: 22.7196,
          longitude: 75.8577,
        ),
      );

      expect(find.text('Tap to save address'), findsNothing);
      expect(find.textContaining('12 Residency Road'), findsOneWidget);
    });
  });
}
