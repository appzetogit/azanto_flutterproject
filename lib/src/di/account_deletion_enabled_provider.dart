import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_config.dart';
import 'network_providers.dart';

/// Whether the admin's "Delete Account (customer app)" feature flag is on.
///
/// Same source and shape as [martEnabledProvider]: `feature-settings/public` is
/// public (no token) and returns every feature row, here keyed `account_deletion`
/// and set from the admin panel's Feature Settings page.
///
/// Defaults to ENABLED when the row is missing, the request fails, or the answer
/// has not arrived yet. The safe direction is "show it": a network blip must not
/// remove a control the customer is entitled to, and app stores generally
/// require an account-deletion route to exist for apps that allow sign-up. The
/// delete endpoint enforces the same switch server-side, so a stale `true` here
/// cannot actually delete anything an admin has disallowed — it only means the
/// button is briefly visible and refused on tap.
///
/// `autoDispose` for the same reason Mart's flag uses it: a plain provider would
/// cache its first answer for the rest of the process lifetime, so flipping the
/// flag in the admin panel would go unnoticed until the app was restarted.
/// Dropping it when nothing is watching means re-entering Profile re-reads it.
final accountDeletionEnabledProvider = FutureProvider.autoDispose<bool>((ref) async {
  final rows =
      await ref.watch(apiClientProvider).get<List<dynamic>>(ApiPaths.featureSettings);

  for (final row in rows) {
    if (row is Map && row['key'] == 'account_deletion') {
      return row['isEnabled'] != false;
    }
  }
  return true;
});
