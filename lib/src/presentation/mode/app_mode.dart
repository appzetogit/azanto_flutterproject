import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../quick/di/repository_providers.dart' as quick_di;

/// Which Azanto vertical the user is browsing. One account, one address book,
/// one wallet — but each mode keeps its own home, catalog, cart and checkout.
enum AppMode { food, quick }

/// Which vertical is on screen. Always starts at Food.
///
/// A cold start deliberately ignores whatever mode the user was last in: Azanto
/// is a food app that also sells groceries, so the launch destination is Food
/// even for someone who closed the app inside Mart. Switching within a session
/// still works normally — only the *restore* was dropped.
///
/// The stored key is still written so anything that wants "last used" can read
/// it, but nothing reads it back into [build] any more.
class AppModeNotifier extends Notifier<AppMode> {
  static const _key = 'app.mode';

  @override
  AppMode build() => AppMode.food;

  void set(AppMode mode) {
    state = mode;
    ref.read(quick_di.localStorageProvider).setString(_key, mode.name);
  }
}

final appModeProvider =
    NotifierProvider<AppModeNotifier, AppMode>(AppModeNotifier.new);

/// Home route for a mode — where the switcher and the splash screen land.
String homePathFor(AppMode mode) =>
    mode == AppMode.quick ? '/quick/home' : '/home';
