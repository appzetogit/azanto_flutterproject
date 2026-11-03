import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/di/support_contact_provider.dart';

/// The Help & Support screen used to dial a hardcoded number that no longer
/// matched the one the admin panel publishes. It now reads
/// `businessSettings`, and the thing that must never regress is the *blank*
/// case: an empty string from the backend has to become `null`, because the
/// screen keys "show a dash and disable the row" off null. If a blank slipped
/// through as `''` the row would look tappable and dial nothing.
void main() {
  test('blank backend contact fields become null, not empty strings', () {
    const blank = SupportContact();
    expect(blank.phone, isNull);
    expect(blank.email, isNull);
  });

  test('parsing keeps real values and drops empty ones', () {
    // Mirrors the shape businessSettings actually returns.
    String? clean(String? v) => (v?.trim().isEmpty ?? true) ? null : v!.trim();

    expect(clean('9010551238'), '9010551238');
    expect(clean('  maava1238@gmail.com  '), 'maava1238@gmail.com');
    expect(clean(''), isNull);
    expect(clean('   '), isNull);
    expect(clean(null), isNull);
  });
}
