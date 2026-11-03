import '../model/category.dart';
import '../model/sub_category.dart';

abstract interface class CategoryRepository {
  /// Admin-curated categories (`GET /food/search/categories/admin`).
  Future<List<Category>> topLevel();

  /// Every category the endpoint returns, both levels, each carrying its
  /// `parentId`. For surfaces that show a parent alongside its own children.
  Future<List<Category>> all();

  /// Second-level groupings for [categoryId]. Derived client-side from the
  /// items in the category — see [SubCategory].
  Future<List<SubCategory>> subCategoriesOf(String categoryId);
}
