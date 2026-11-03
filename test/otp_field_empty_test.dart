import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/presentation/auth/screens/otp_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The OTP boxes must open empty.
///
/// They used to be prefilled from the backend's echoed dev OTP, falling back to
/// a literal '1234' when there was none — which in production meant every user
/// was handed a wrong code that looked like a real one, and a single tap on
/// Verify failed. This asserts on the rendered fields rather than on the absent
/// `devOtp` parameter, so re-adding prefill by any other route still fails.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => const MaterialApp(
            home: OtpScreen(phoneNumber: '9301988718'),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('every OTP box is empty when the screen opens', (tester) async {
    await pump(tester);
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      expect(tester.widget<TextField>(fields.at(i)).controller!.text, isEmpty);
    }
  });

  testWidgets('an autofilled code is dealt across the boxes in order',
      (tester) async {
    await pump(tester);
    final fields = find.byType(TextField);
    // One short of a full code: a complete code auto-submits.
    await tester.enterText(fields.first, '144');
    await tester.pump();
    String box(int i) => tester.widget<TextField>(fields.at(i)).controller!.text;
    expect([for (var i = 0; i < 4; i++) box(i)], ['1', '4', '4', '']);
  });
}
