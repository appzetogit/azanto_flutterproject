import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/category.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/smart_scan.dart';
import '../../../common/widgets/cards/category_card.dart';
import '../../../common/widgets/inputs/search_bar_widget.dart';
import '../../../common/widgets/loaders/list_skeleton.dart';
import '../../../common/widgets/misc/sound_refresh_indicator.dart';
import '../../../common/widgets/misc/staggered_entrance.dart';
import '../../../common/widgets/misc/status_bar_style.dart';
import '../../../common/widgets/states/empty_state_widget.dart';
import '../../../common/widgets/states/error_state_widget.dart';
import 'categories_provider.dart';
import '../../../common/widgets/misc/mart_view_cart_bar.dart';
import '../../../../../presentation/cart/widgets/floating_view_cart_bar.dart';

/// The Categories tab: every top-level category as a section, with its own
/// subcategories in a 4-column grid.
///
/// It used to embed the HOME screen's `DeliveryHeader` — delivery ETA, address,
/// category strip and all — and then place a second search bar underneath it.
/// That produced two search fields stacked on one screen, and an empty category
/// strip, because the embedded header was constructed with no categories to
/// show. This screen has a header of its own now: a title and one search bar.
///
/// Sections used to be four hardcoded buckets ('Grocery & Kitchen', 'Snacks &
/// Drinks', …) filled by keyword-matching category names, so a category could
/// land under a heading it had nothing to do with, and anything unmatched fell
/// into 'Household Essentials'. Categories carry a real `parentId` now.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key, this.showAppBar = false});

  final bool showAppBar;

  /// Parents that actually have children, each paired with them.
  ///
  /// A parent with nothing under it is skipped: a heading over an empty grid
  /// reads as a section that failed to load. When the catalogue has no tree at
  /// all yet, everything top-level is shown in one section so the tab is still
  /// usable.
  List<(String, List<Category>)> _sections(List<Category> tree) {
    final childrenOf = <String, List<Category>>{};
    for (final category in tree) {
      if (category.isCore) continue;
      childrenOf.putIfAbsent(category.parentId, () => []).add(category);
    }

    final core = tree.where((c) => c.isCore).toList();
    final sections = [
      for (final parent in core)
        if (childrenOf[parent.id] case final children?)
          if (children.isNotEmpty) (parent.name, children),
    ];

    if (sections.isNotEmpty) return sections;
    return core.isEmpty ? const [] : [('All categories', core)];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(categoryTreeProvider);
    final headerColor = context.colors.surface;

    return StatusBarStyle(
      // The header is a plain surface, not the home screen's brand gradient.
      // This screen used to hardcode dark icons while showing whatever header
      // it had inherited, so the clock sat unreadable on a deep purple plate.
      background: headerColor,
      child: Scaffold(
        backgroundColor: context.colors.surface,
        appBar: showAppBar
            ? AppBar(title: const Text('All Categories'), elevation: 0)
            : null,
        body: Stack(
          // The bar sits on the window edge; a clipping Stack would
          // shave its shadow and its lower corners.
          clipBehavior: Clip.none,
          children: [
            Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: headerColor,
                border: const Border(
                  bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: SafeArea(
                bottom: false,
                top: !showAppBar,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!showAppBar)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.gutter,
                          10,
                          AppSpacing.gutter,
                          2,
                        ),
                        child: Text(
                          'All Categories',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: -0.3,
                            color: context.colors.onSurface,
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        6,
                        AppSpacing.gutter,
                        10,
                      ),
                      child: SearchBarWidget(
                        readOnly: true,
                        hintRotation: const [
                          'sugar',
                          'Milk',
                          'Fresh Vegetables',
                          'Atta & Rice',
                        ],
                        onTap: () => context.push(RoutePaths.search),
                        onScanTap: () => SmartScan.run(context, ref),
                        onMicTap: () =>
                            context.push('${RoutePaths.search}?voice=1'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: treeAsync.when(
                loading: () => const CategoryGridSkeleton(count: 12, columns: 4),
                error: (error, _) => ErrorStateWidget(
                  failure: ErrorMapper.toFailure(error),
                  onRetry: () => ref.invalidate(categoryTreeProvider),
                ),
                data: (tree) {
                  final sections = _sections(tree);
                  if (sections.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.category_outlined,
                      title: 'No categories yet',
                      message:
                          'Our catalog is being set up for your area. Check back shortly.',
                    );
                  }

                  return SoundRefreshIndicator(
                    onRefresh: () async => ref.invalidate(categoryTreeProvider),
                    child: ListView.builder(
                      // Clears the floating cart bar, which overlays the
                      // last row rather than pushing it up.
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.gutter,
                        4,
                        AppSpacing.gutter,
                        FloatingViewCartBar.reservedBottomSpace(context),
                      ),
                      itemCount: sections.length,
                      itemBuilder: (context, index) {
                        final (title, children) = sections[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
                              child: Text(
                                title,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19,
                                  color: const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: children.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 8,
                                childAspectRatio: 0.72,
                              ),
                              itemBuilder: (context, gridIndex) {
                                final category = children[gridIndex];
                                return StaggeredEntrance(
                                  index: gridIndex,
                                  child: CategoryCard(
                                    category: category,
                                    size: 70,
                                    onTap: () => context.push(
                                      RoutePaths.subCategoryOf(category.id),
                                      extra: category,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
            // The shared bar, floating over the content: it renders a
            // Positioned.fill and cannot sit in bottomNavigationBar.
            const MartViewCartBar(),
          ],
        ),
      ),
    );
  }
}
