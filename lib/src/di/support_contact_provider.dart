import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_config.dart';
import 'network_providers.dart';

/// The support phone and email the admin panel publishes.
///
/// These used to be hardcoded in the Help & Support screen, which meant the app
/// kept dialling an old number after the admin changed it. `businessSettings`
/// is public (no token), so this resolves for signed-out users too.
class SupportContact {
  const SupportContact({this.phone, this.email});

  final String? phone;
  final String? email;
}

final supportContactProvider = FutureProvider<SupportContact>((ref) async {
  final json = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>(ApiPaths.businessSettings);

  final phone = json['phone'];
  final number = phone is Map ? (phone['number'] as String?)?.trim() : null;
  final email = (json['email'] as String?)?.trim();

  return SupportContact(
    phone: (number?.isEmpty ?? true) ? null : number,
    email: (email?.isEmpty ?? true) ? null : email,
  );
});
