import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/shared/orders/cancel_window.dart';

void main() {
  test('the window is anchored to the server timestamp, not to first render',
      () {
    // An order placed 40s ago must show 20s left, not a fresh minute — this is
    // what makes the countdown survive closing and reopening the app.
    final placed = DateTime.now().subtract(const Duration(seconds: 40));
    final left = cancelWindowEndsAt(placed).difference(DateTime.now());
    expect(left.inSeconds, inInclusiveRange(19, 20));
    expect(isCancelWindowOpen(placed), isTrue);

    expect(
      isCancelWindowOpen(DateTime.now().subtract(const Duration(seconds: 61))),
      isFalse,
    );
    // No timestamp defers to the status rule rather than hiding the button.
    expect(isCancelWindowOpen(null), isTrue);
  });

  test('mm:ss', () {
    expect(formatCancelRemaining(const Duration(minutes: 1)), '01:00');
    expect(formatCancelRemaining(const Duration(seconds: 59)), '00:59');
    expect(formatCancelRemaining(const Duration(seconds: 9)), '00:09');
    expect(formatCancelRemaining(Duration.zero), '00:00');
  });

  testWidgets('ticks down in real time, then hides the button and fires '
      'onExpired exactly once', (tester) async {
    var expired = 0;
    // Just under two seconds left, so the whole window closes inside the test.
    // Real delays rather than tester.pump(duration): the widget recomputes from
    // the wall clock every tick — that is what keeps it accurate while the app
    // is backgrounded — and pumping only advances fake timers.
    final placed =
        DateTime.now().subtract(kCancelWindow - const Duration(milliseconds: 1800));

    await tester.pumpWidget(MaterialApp(
      home: CancelWindowGate(
        placedAt: placed,
        statusAllows: true,
        onExpired: () => expired++,
        builder: (context, remaining) => Text(
            'Cancel order available for ${formatCancelRemaining(remaining)}'),
      ),
    ));

    expect(find.text('Cancel order available for 00:01'), findsOneWidget);
    expect(expired, 0);

    // Burn real time (the widget reads the wall clock), then advance the fake
    // clock so the pending periodic timer actually fires. A widget test needs
    // both: pump() alone never fires it, and a real delay alone never rebuilds.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2200)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    // At zero the button is gone, not merely disabled.
    expect(find.textContaining('Cancel order'), findsNothing);
    expect(expired, 1);

    // Later ticks must not re-fire it.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await tester.pump(const Duration(seconds: 1));
    expect(expired, 1);
  });

  testWidgets('an order already past its window fires onExpired without ever '
      'showing the button', (tester) async {
    var expired = 0;
    await tester.pumpWidget(MaterialApp(
      home: CancelWindowGate(
        placedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        statusAllows: true,
        onExpired: () => expired++,
        builder: (context, remaining) => const Text('CANCEL'),
      ),
    ));
    expect(find.text('CANCEL'), findsNothing);
    await tester.pump();
    expect(expired, 1);
  });

  testWidgets('an order past its window never renders the button',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CancelWindowGate(
        placedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        statusAllows: true,
        builder: (context, remaining) => const Text('CANCEL'),
      ),
    ));
    expect(find.text('CANCEL'), findsNothing);
  });

  testWidgets('the status rule still wins on its own', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CancelWindowGate(
        placedAt: DateTime.now(),
        statusAllows: false,
        builder: (context, remaining) => const Text('CANCEL'),
      ),
    ));
    expect(find.text('CANCEL'), findsNothing);
  });
}
