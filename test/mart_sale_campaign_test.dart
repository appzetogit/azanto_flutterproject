import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/quick/domain/model/sale_campaign.dart';

void main() {
  test('parses the campaign the backend actually sends', () {
    final c = SaleCampaign.fromJson(const {
      'id': '6a8821eca721442222aa1aec',
      'title': 'HOUSEFULL SALE',
      'dateLabel': '21ST AUG, 2026 - 20TH SEP, 2026',
      'dealLabel': 'CRAZY DEALS',
      'tiles': [
        {
          'title': 'Self Care &\nWellness',
          'badgeText': 'Up to 55% OFF',
          'emojis': '🧴 💧 🧼 💄',
          'categoryId': '6a81b8d8cc7e3947d2ad6e2b',
        },
      ],
    });

    expect(c.title, 'HOUSEFULL SALE');
    // The date strip is server-formatted; the app must never derive its own.
    expect(c.dateLabel, '21ST AUG, 2026 - 20TH SEP, 2026');
    expect(c.tiles.single.categoryId, '6a81b8d8cc7e3947d2ad6e2b');
  });

  test('an unlinked tile yields null, not an empty-string route', () {
    // '' would push a dead category route; null lets the tile stay inert.
    for (final raw in [
      <String, dynamic>{'title': 'T'},
      <String, dynamic>{'title': 'T', 'categoryId': null},
      <String, dynamic>{'title': 'T', 'categoryId': ''},
    ]) {
      expect(SaleCampaignTile.fromJson(raw).categoryId, isNull);
    }
  });

  test('missing fields degrade to empty strings rather than throwing', () {
    final c = SaleCampaign.fromJson(const {'id': 'x', 'title': 'Sale'});
    expect(c.dateLabel, '');
    expect(c.dealLabel, '');
    expect(c.tiles, isEmpty);
  });

  test('a campaign carries its category theme', () {
    final c = SaleCampaign.fromJson(const {
      'id': 'x',
      'title': 'ELECTRONICS SALE',
      'categoryId': '6a881f7e7dd28f56216864c1',
      'themeColor': '#FFF6D6',
      'accentColor': '#8D6E00',
      'searchHint': 'chargers',
    });
    expect(c.categoryId, '6a881f7e7dd28f56216864c1');
    expect(c.themeColor, '#FFF6D6');
    expect(c.searchHint, 'chargers');
  });

  test('hex parses, and anything unusable stays null so the brand palette wins',
      () {
    expect(parseHexColor('#FFF6D6'), 0xFFFFF6D6);
    expect(parseHexColor('FFF6D6'), 0xFFFFF6D6);
    // Null rather than black: an unset or malformed colour must leave the
    // existing theme alone, never repaint the header black.
    for (final bad in ['', '#FFF', 'not-a-colour', '#GGGGGG']) {
      expect(parseHexColor(bad), isNull, reason: bad);
    }
  });

  test('a pale theme needs dark ink, a deep one needs white', () {
    // The header text is white on the brand gradient; the category themes are
    // pale, so a fixed white would be invisible.
    bool wantsDarkInk(String hex) {
      final v = parseHexColor(hex)!;
      return Color(v).computeLuminance() > 0.5;
    }

    // The shipped tints, which are saturated enough to read as a colour change
    // yet still want dark ink.
    expect(wantsDarkInk('#A5DEC0'), isTrue, reason: 'grocery mint');
    expect(wantsDarkInk('#F9C2D9'), isTrue, reason: 'beauty pink');
    expect(wantsDarkInk('#FBE188'), isTrue, reason: 'electronics amber');
    expect(wantsDarkInk('#B4D9F7'), isTrue, reason: 'home blue');
    expect(wantsDarkInk('#1B5E20'), isFalse, reason: 'deep green');
  });
}
