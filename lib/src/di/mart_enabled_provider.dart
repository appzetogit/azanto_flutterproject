import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_config.dart';
import 'network_providers.dart';

/// Whether the admin's "Mart (Quick Commerce)" feature flag is on.
///
/// `feature-settings/public` is public (no token) and returns every feature
/// row (key `quick_commerce`, set from the admin panel's Feature Settings
/// page); a missing row (fresh install, not yet seeded) defaults to enabled
/// so Mart isn't accidentally hidden.
///
/// `autoDispose`: Mart's `HomeScreen` is the only watcher, and it's created
/// fresh on every Food→Mart switch (a `context.go` route change, not a
/// preserved tab). A plain (non-autoDispose) provider would cache its first
/// answer for the rest of the app's process lifetime — so once fetched while
/// the flag was off, flipping it back on in the admin panel would never be
/// noticed until the app restarted. autoDispose lets it drop the moment
/// nothing's watching (i.e. the user leaves Mart) and re-fetch fresh next
/// time it's entered.
final martEnabledProvider = FutureProvider.autoDispose<bool>((ref) async {
  // Re-read on an interval.
  //
  // autoDispose alone was enough while Mart's own HomeScreen was the only
  // watcher: leaving Mart dropped the provider and re-entering re-fetched it.
  // The bottom nav now watches it too, to decide whether to show the Food->Mart
  // disc at all, and that nav is on screen for essentially the whole session --
  // so nothing ever stops watching and the first answer would stick until the
  // app was killed. That is exactly the 'I turned it off and nothing happened'
  // report this came from.
  final refresh = Timer(const Duration(minutes: 2), ref.invalidateSelf);
  ref.onDispose(refresh.cancel);

  final rows =
      await ref.watch(apiClientProvider).get<List<dynamic>>(ApiPaths.featureSettings);

  for (final row in rows) {
    if (row is Map && row['key'] == 'quick_commerce') {
      return row['isEnabled'] != false;
    }
  }
  return true;
});
