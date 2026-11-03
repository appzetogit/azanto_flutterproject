import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/model/category.dart';
import '../../../common/widgets/cards/category_card.dart';

/// One section per top-level category, each showing that category's own
/// subcategories in a 4-column grid.
///
/// The sections used to be four hardcoded blocks of invented subcategories
/// ('Paan Corner', 'Kitchenware & Appliances') carrying made-up ids, matched to
/// real categories by fuzzy name. Every tile pushed a route for an id the
/// backend had never heard of, so the whole grid was dead — and any category
/// that matched none of the four blocks was given four OTHER top-level
/// categories as its "subcategories".
///
/// Categories carry a real `parentId` now, so the tree is the admin's.
class AllCategorySectionsFeed extends StatelessWidget {
  const AllCategorySectionsFeed({
    super.key,
    required this.categories,
    required this.onCategoryTap,
  });

  /// Every category, both levels. Parents are matched to their children here.
  final List<Category> categories;

  final ValueChanged<String> onCategoryTap;

  /// Top-level categories that actually have children, each with them.
  ///
  /// A parent with no subcategories is skipped rather than padded out: an
  /// empty grid under a heading reads as a section that failed to load.
  List<(Category, List<Category>)> get _sections {
    final childrenOf = <String, List<Category>>{};
    for (final category in categories) {
      if (category.isCore) continue;
      childrenOf.putIfAbsent(category.parentId, () => []).add(category);
    }

    return [
      for (final parent in categories.where((c) => c.isCore))
        if (childrenOf[parent.id] case final children?)
          if (children.isNotEmpty) (parent, children),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    if (sections.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (parent, children) in sections) ...[
          Padding(
            padding:
                EdgeInsets.fromLTRB(AppSpacing.gutter, 16, AppSpacing.gutter, 10),
            child: Text(
              parent.name,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 19,
                color: const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: children.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, index) {
                final child = children[index];
                return CategoryCard(
                  category: child,
                  size: 70,
                  onTap: () => onCategoryTap(child.id),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
