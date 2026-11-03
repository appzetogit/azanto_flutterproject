import 'dart:io';

Future<void> diagLog(String message) async {
  try {
    final file = File('/storage/emulated/0/Android/data/com.maava.user/files/diag.log');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${DateTime.now().toIso8601String()} $message\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {
    // Diagnostics must never crash the app.
  }
}
