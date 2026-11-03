import '../../../core/errors/failure.dart';
import '../../../domain/model/sale_campaign.dart';
import '../../../domain/model/banner.dart';
import '../../../domain/model/brand.dart';
import '../../../domain/model/category.dart';
import '../../../domain/model/coupon.dart';
import '../../../domain/model/product.dart';
import '../../../domain/model/seller.dart';

/// A horizontally-scrolling product row on the home screen.
class HomeSection {
  const HomeSection({
    required this.id,
    required this.title,
    required this.products,
    this.subtitle = '',
    this.categoryId,
    this.showRanks = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<Product> products;

  /// Set when "See all" should open a category-filtered listing.
  final String? categoryId;

  /// Best-sellers show #1/#2 badges.
  final bool showRanks;

  bool get isEmpty => products.isEmpty;
}

/// Home is composed of independently-loading pieces, so each part carries its
/// own loading flag rather than blocking the whole page on the slowest call.
class HomeState {
  const HomeState({
    this.heroBanners = const [],
    this.topBanners = const [],
    this.categories = const [],
    this.allCategories = const [],
    this.brands = const [],
    this.sellers = const [],
    this.sections = const [],
    this.coupons = const [],
    this.saleCampaign,
    this.campaigns = const [],
    this.selectedCategoryId = '',
    this.isLoadingBanners = true,
    this.isLoadingCategories = true,
    this.isLoadingSections = true,
    this.isLoadingCoupons = true,
    this.isRefreshing = false,
    this.failure,
  });

  /// The header's background media: the hero collection, plus the
  /// home-promotion one, which has no slot of its own and would otherwise stop
  /// being shown anywhere.
  final List<PromoBanner> heroBanners;

  /// The admin-configured sale promotion, or null when none is live.
  final SaleCampaign? saleCampaign;

  /// Every live campaign, keyed by the header category it themes.
  final List<SaleCampaign> campaigns;

  /// Header category currently selected; empty means 'All'.
  final String selectedCategoryId;

  /// The campaign backing the current selection, falling back to the default
  /// (category-less) one so the page always has something to render.
  SaleCampaign? get activeCampaign {
    for (final c in campaigns) {
      if (c.categoryId == selectedCategoryId && selectedCategoryId.isNotEmpty) {
        return c;
      }
    }
    for (final c in campaigns) {
      if (c.categoryId == null) return c;
    }
    return campaigns.isEmpty ? saleCampaign : campaigns.first;
  }

  /// The promotional strip below Nearby stores.
  final List<PromoBanner> topBanners;
  final List<Category> categories;

  /// Every category, both levels, each carrying its `parentId`. `categories`
  /// stays top-level-only because most surfaces want exactly that.
  final List<Category> allCategories;
  final List<Brand> brands;
  final List<Seller> sellers;
  final List<HomeSection> sections;

  /// Live offers from `/food/restaurant/offers`, shown as the offer cards.
  final List<Coupon> coupons;
  final bool isLoadingBanners;
  final bool isLoadingCategories;
  final bool isLoadingSections;
  final bool isLoadingCoupons;
  final bool isRefreshing;
  final Failure? failure;

  bool get isInitialLoad =>
      isLoadingSections && sections.isEmpty && categories.isEmpty;

  bool get isEmpty =>
      !isLoadingSections && sections.isEmpty && categories.isEmpty;

  /// Whether there is a MaavaMart store available in the customer's active zone.
  ///
  /// Evaluates to true while initial load is in progress. Once loading completes,
  /// returns true if backend returns sellers or sections for the active zone,
  /// and false if no MaavaMart store exists in the user's zone.
  bool get hasStoreInZone {
    if (isLoadingSections || isLoadingCategories) return true;
    if (sellers.isNotEmpty) return true;
    if (sections.isNotEmpty || categories.isNotEmpty) return true;
    return false;
  }

  /// Products of a derived section, or empty when it was dropped for having none.
  /// Sections that are not pinned to a bespoke widget above — rendered as
  /// generic product rows so nothing the catalog returned is dropped.
  static const _pinnedSectionIds = {'best-sellers', 'flash'};

  List<HomeSection> get rows =>
      sections.where((s) => !_pinnedSectionIds.contains(s.id)).toList();

  List<Product> productsOf(String sectionId) {
    for (final section in sections) {
      if (section.id == sectionId) return section.products;
    }
    return const [];
  }

  HomeState copyWith({
    List<PromoBanner>? heroBanners,
    List<PromoBanner>? topBanners,
    List<Category>? categories,
    List<Category>? allCategories,
    List<Brand>? brands,
    List<Seller>? sellers,
    List<HomeSection>? sections,
    List<Coupon>? coupons,
    SaleCampaign? saleCampaign,
    List<SaleCampaign>? campaigns,
    String? selectedCategoryId,
    bool? isLoadingBanners,
    bool? isLoadingCategories,
    bool? isLoadingSections,
    bool? isLoadingCoupons,
    bool? isRefreshing,
    Failure? failure,
    bool clearFailure = false,
  }) =>
      HomeState(
        heroBanners: heroBanners ?? this.heroBanners,
        topBanners: topBanners ?? this.topBanners,
        categories: categories ?? this.categories,
        allCategories: allCategories ?? this.allCategories,
        brands: brands ?? this.brands,
        sellers: sellers ?? this.sellers,
        sections: sections ?? this.sections,
        coupons: coupons ?? this.coupons,
        saleCampaign: saleCampaign ?? this.saleCampaign,
        campaigns: campaigns ?? this.campaigns,
        selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
        isLoadingBanners: isLoadingBanners ?? this.isLoadingBanners,
        isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
        isLoadingSections: isLoadingSections ?? this.isLoadingSections,
        isLoadingCoupons: isLoadingCoupons ?? this.isLoadingCoupons,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        failure: clearFailure ? null : (failure ?? this.failure),
      );
}
