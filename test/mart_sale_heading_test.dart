import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/domain/model/sale_campaign.dart';
import 'package:azanto/src/quick/ui/common/widgets/misc/status_bar_style.dart';
import 'package:azanto/src/quick/ui/screens/home/widgets/bouncing_heading.dart';
import 'package:azanto/src/quick/ui/screens/home/widgets/housefull_sale_banner.dart';

/// The headline used to be split on whitespace into a big first part and a
/// small last word — 'GROCERY' over 'SALE' — so the two halves read as separate
/// elements. It is one heading now, rendered at one size from one backend
/// string.
///
/// [BouncingHeading] lays the glyphs out individually so the lift can travel
/// across them, so `find.text` cannot match the whole string. The assertions
/// read the heading the banner handed the animation instead; the semantics
/// label that keeps it announceable is covered in mart_heading_animation_test.

/// The heading text the banner actually handed to the animation.
String _heading(WidgetTester tester) =>
    tester.widget<BouncingHeading>(find.byType(BouncingHeading)).text;

Future<void> _pumpBanner(WidgetTester tester, String title) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HousefullSaleBanner(
            campaign: SaleCampaign(id: 'c', title: title),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('sale heading', () {
    testWidgets('renders the backend heading whole, as one text element',
        (tester) async {
      await _pumpBanner(tester, 'GROCERY SALE');

      expect(_heading(tester), 'GROCERY SALE');
      // The old split rendered these as two separately-styled Texts.
      expect(find.text('GROCERY'), findsNothing);
      expect(find.text('SALE'), findsNothing);
    });

    testWidgets('the animation wraps the whole heading, not part of it',
        (tester) async {
      await _pumpBanner(tester, 'FRUITS & VEGETABLES SALE');

      expect(_heading(tester), 'FRUITS & VEGETABLES SALE',
          reason: 'the animation owns the whole heading, not part of it');
    });

    testWidgets('every category heading gets the same treatment',
        (tester) async {
      for (final title in [
        'DAIRY & BAKERY SALE',
        'SNACKS & BEVERAGES SALE',
        'ELECTRONICS SALE',
        'FASHION SALE',
        'BEAUTY & PERSONAL CARE SALE',
      ]) {
        await _pumpBanner(tester, title);
        expect(_heading(tester), title, reason: title);
      }
    });

    testWidgets('the date strip stays outside the animation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HousefullSaleBanner(
                campaign: const SaleCampaign(
                  id: 'c',
                  title: 'GROCERY SALE',
                  dateLabel: '21ST AUG, 2026 - 20TH SEP, 2026',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final date = find.text('21ST AUG, 2026 - 20TH SEP, 2026');
      expect(date, findsOneWidget);
      expect(
        find.ancestor(of: date, matching: find.byType(BouncingHeading)),
        findsNothing,
        reason: 'the bounce belongs to the heading, not the whole block',
      );
    });

    testWidgets('the bounce never moves the heading out of the tree',
        (tester) async {
      await _pumpBanner(tester, 'GROCERY SALE');
      // Step through a full loop; the heading must stay mounted throughout.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(BouncingHeading), findsOneWidget);
        expect(_heading(tester), 'GROCERY SALE');
      }
    });
  });

  group('offer tiles', () {
    // The grid indexed cards[0]..cards[3] unconditionally, so any campaign with
    // fewer than four tiles threw RangeError and took the whole screen down.
    // Campaigns created in the admin panel start with NO tiles, which made this
    // reachable by an ordinary admin action.
    for (final tileCount in [0, 1, 2, 3, 4]) {
      testWidgets('$tileCount tiles renders without throwing', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: HousefullSaleBanner(
                  campaign: SaleCampaign(
                    id: 'c',
                    title: 'GROCERY SALE',
                    tiles: [
                      for (var i = 0; i < tileCount; i++)
                        SaleCampaignTile(title: 'Tile $i', categoryId: 'cat$i'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(_heading(tester), 'GROCERY SALE');
        for (var i = 0; i < tileCount; i++) {
          expect(find.text('Tile $i'), findsOneWidget);
        }
      });
    }
  });

  group('status bar', () {
    test('icon brightness follows the colour behind the bar', () {
      // A deep category plate needs white icons.
      expect(
        StatusBarStyle.iconBrightnessOn(const Color(0xFF4C1D95)),
        Brightness.light,
      );
      // A pale one needs dark icons.
      expect(
        StatusBarStyle.iconBrightnessOn(const Color(0xFFA5DEC0)),
        Brightness.dark,
      );
      // The plain white listing header.
      expect(
        StatusBarStyle.iconBrightnessOn(const Color(0xFFFFFFFF)),
        Brightness.dark,
      );
    });
  });
}
