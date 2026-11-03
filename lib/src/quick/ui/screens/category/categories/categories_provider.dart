import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../di/repository_providers.dart';
import '../../../../di/zone_providers.dart';
import '../../../../domain/model/category.dart';

/// All top-level categories, from the admin-curated list.
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  ref.watch(martZoneIdProvider);
  return ref.watch(categoryRepositoryProvider).topLevel();
});

/// The whole category tree, both levels, each row carrying its `parentId`.
///
/// The Categories tab groups children under their real parent, so it needs more
/// than the top level. Same request as [categoriesProvider] — the repository
/// fetches the flat list once and filters it.
final categoryTreeProvider = FutureProvider<List<Category>>((ref) {
  // Counts are zone-scoped, so a change of zone must refetch.
  ref.watch(martZoneIdProvider);
  return ref.watch(categoryRepositoryProvider).all();
});
