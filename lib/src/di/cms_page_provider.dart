import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/api_config.dart';
import 'network_providers.dart';

/// One entry in the About page's feature grid, as the admin panel writes it.
class CmsFeature {
  const CmsFeature({required this.icon, required this.title, required this.description});

  final String icon;
  final String title;
  final String description;
}

/// A CMS-authored page from the admin panel's Pages & Social Media section —
/// `terms`, `privacy`, `support`, or `about` — served publicly at
/// `/food/pages/:key`. Legal pages carry a title/body; `about` carries the app
/// description, version, and feature list instead of `title`/`content`.
class CmsPage {
  const CmsPage({
    this.title = '',
    this.content = '',
    this.version = '',
    this.features = const [],
  });

  final String title;
  final String content;
  final String version;
  final List<CmsFeature> features;

  bool get isEmpty => title.isEmpty && content.isEmpty;
}

final cmsPageProvider = FutureProvider.family<CmsPage?, String>((ref, key) async {
  final json = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>(ApiPaths.cmsPage(key));

  final title = (json['title'] as String? ?? '').trim();
  final content = (json['content'] as String? ?? '').trim();
  final appName = (json['appName'] as String? ?? '').trim();
  final description = (json['description'] as String? ?? '').trim();
  final version = (json['version'] as String? ?? '').trim();
  final features = (json['features'] as List? ?? const [])
      .whereType<Map>()
      .map(
        (f) => CmsFeature(
          icon: (f['icon'] ?? '').toString(),
          title: (f['title'] ?? '').toString().trim(),
          description: (f['description'] ?? '').toString().trim(),
        ),
      )
      .where((f) => f.title.isNotEmpty)
      .toList();

  final page = CmsPage(
    title: title.isEmpty ? appName : title,
    content: content.isEmpty ? description : content,
    version: version,
    features: features,
  );
  return page.isEmpty && page.version.isEmpty && page.features.isEmpty ? null : page;
});

/// The CMS stores rich text; screens render plain paragraphs from it.
// ponytail: tag strip, swap for an HTML renderer if the CMS starts using
// tables or links that matter.
String plainTextFromHtml(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>|</p>|</div>|</li>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
