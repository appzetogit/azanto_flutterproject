/// 8pt-derived spacing scale. Widget code must never hardcode paddings.
abstract final class AppSpacing {
  /// Screen-edge gutter for Mart.
  ///
  /// One value for every section so rails, cards and headers all start on the
  /// same vertical line. Deliberately not 0: full-bleed text is hard to read,
  /// and the card shadows need somewhere to fall.
  static const gutter = 10.0;

  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}
