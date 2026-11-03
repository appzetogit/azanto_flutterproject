import 'package:flutter/material.dart';

/// Azanto Quick brand palette.
///
/// `teal` is the shipped default: a mint-teal brand plate with a deeper teal
/// accent, which keeps the quick vertical clearly distinct from the food
/// vertical's violet while both read as one app. The earlier yellow and green
/// identities stay selectable from Settings.
///
/// Plate lightness varies by brand — yellow is bright, teal is deep — so the
/// foreground painted on a plate is never hardcoded. `AppColors.onPlate` picks
/// dark or white ink from the plate's own luminance.
///
/// The brand itself is [QuickBrand], resolved from the one palette the user
/// picked. The `teal*` constants below are the *default* brand's values, not a
/// palette widgets may reach for directly — reading them pinned mart screens to
/// teal no matter what was chosen.
abstract final class AppColors {
  // Brand teal (default flavour).
  //
  // A deep teal, not the earlier mint: the mint sat at L=0.39 and scored only
  // 2.12:1 against white, so brand icons and prices on white cards read washed
  // out. This is L=0.27 and scores 4.53:1 both as a foreground on white and
  // with white on top of it — the plate is now dark, which is why every
  // on-brand foreground is computed rather than fixed (see `onPlate`).
  static const tealPrimary = Color(0xFF068483);
  static const tealDark = Color(0xFF045353);
  static const tealSoft = Color(0xFFE8F7F7);
  /// Mid tint for hairline borders on a [tealSoft] fill.
  static const tealBorder = Color(0xFFB7E1E1);
  /// Dark-mode counterparts of the teal plate.
  static const tealPlateDark = Color(0xFF133434);
  static const tealSoftDark = Color(0xFF0F2424);

  /// Legible foreground for anything painted on [plate].
  ///
  /// Per-flavour rather than a constant: the yellow flavour is a bright plate
  /// needing dark ink, the teal one is dark and needs white. Deciding from the
  /// plate's own luminance keeps both correct — and any future flavour too.
  static Color onPlate(Color plate) =>
      plate.computeLuminance() > 0.45 ? lightTextPrimary : const Color(0xFFFFFFFF);

  // Azanto exact colors
  static const appzetoYellow = Color(0xFFFFD400);
  static const appzetoGreen = AppColors.tealPrimary;
  static const appzetoDarkGreen = AppColors.tealPrimary;
  static const orangeBadge = Color(0xFFFF6B35);

  // Semantic, flavor-independent tokens.
  static const success = Color(0xFF2FB457);
  static const successSoft = Color(0xFFE6F4EA);
  static const warning = Color(0xFFF59E0B);
  static const warningSoft = Color(0xFFFFF8E7);
  static const danger = Color(0xFFE04444);
  static const dangerSoft = Color(0xFFFCE8E6);
  static const info = Color(0xFF2563EB);
  static const rating = Color(0xFFFFC529);

  static const veg = AppColors.tealPrimary;
  static const nonVeg = Color(0xFFB3261E);

  // Light surfaces
  static const lightBackground = Color(0xFFF8F9FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFF3F4F6);
  static const lightBorder = Color(0xFFE5E7EB);
  static const lightTextPrimary = Color(0xFF181C2E);
  static const lightTextSecondary = Color(0xFF6B7280);

  // Dark surfaces — hand-picked, not an inversion. Cards sit *above* the
  // background by lightness so elevation stays legible without heavy shadows.
  static const darkBackground = Color(0xFF121223);
  static const darkSurface = Color(0xFF1E1E2E);
  static const darkSurfaceAlt = Color(0xFF2A2A3C);
  static const darkBorder = Color(0xFF32324A);
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFFA0A0B2);

  static const discountGradient = [Color(0xFF1E88E5), Color(0xFF1565C0)];

  // Azanto brand surfaces matching home screen.
  static const brandYellow = Color(0xFFFFD400);
  static const brandYellowSoft = Color(0xFFFFF1C5);
  static const brandYellowFaint = Color(0xFFFFF9E6);
  static const brandGreen = AppColors.tealPrimary;
  static const brandOrange = Color(0xFFFF6B35);

  // Dark-mode counterparts
  static const brandYellowDark = Color(0xFF3A3416);
  static const brandYellowSoftDark = Color(0xFF2B2712);
}


/// The brand colours the quick vertical is currently painted in.
///
/// Quick used to carry TWO brand states: this module's `AppThemeFlavor` (which
/// `QuickThemeScope` built its `ThemeData` from) and the shared
/// `quickThemeColorProvider` that Profile → App Theme writes. Only the second
/// reached the shared screens, so a pick there repainted Profile and left every
/// mart screen on the flavour's teal. Both pickers now resolve to one of these,
/// which is the single input to the theme.
@immutable
class QuickBrand {
  const QuickBrand({required this.seed, required this.accent});

  /// The plate/primary colour.
  final Color seed;

  /// The deeper companion used for accents and pressed states.
  final Color accent;

  static const teal = QuickBrand(
    seed: AppColors.tealPrimary,
    accent: AppColors.tealDark,
  );

  /// Builds a brand from a single colour — what the admin panel actually sets.
  ///
  /// The accent is derived rather than configured: it is only ever a pressed /
  /// emphasis shade of the seed, so a second colour field in the panel would be
  /// one more thing to get wrong. -0.12 lightness reproduces the shipped teal
  /// pair (#068483 → #045353) closely enough that the default look is unchanged.
  factory QuickBrand.fromSeed(Color seed) {
    final hsl = HSLColor.fromColor(seed);
    return QuickBrand(
      seed: seed,
      accent: hsl.withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0)).toColor(),
    );
  }

  /// Ink that stays legible on [seed], whichever end of the scale it sits at.
  Color get onSeed => AppColors.onPlate(seed);

  /// The pale wash behind hero and promo cards, mixed from the brand itself so
  /// every pick gets one — hand-picking a tint per colour did not survive the
  /// palette growing past two options.
  Color softOn(Color surface) =>
      Color.alphaBlend(seed.withValues(alpha: 0.12), surface);

  @override
  bool operator ==(Object other) =>
      other is QuickBrand && other.seed == seed && other.accent == accent;

  @override
  int get hashCode => Object.hash(seed, accent);
}

/// Tokens the Material [ColorScheme] has no slot for.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.accent,
    required this.brandSurface,
    required this.brandSurfaceSoft,
    required this.onBrandSurface,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.border,
    required this.surfaceAlt,
    required this.textSecondary,
    required this.cardShadow,
    required this.sheetShadow,
    required this.floatingShadow,
  });

  final Color accent;

  /// The saturated brand plate: app header, bottom-nav highlight, badges.
  final Color brandSurface;

  /// The tinted plate used behind hero and promo cards.
  final Color brandSurfaceSoft;

  /// Text/icon colour that is legible on [brandSurface].
  final Color onBrandSurface;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color border;
  final Color surfaceAlt;
  final Color textSecondary;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> sheetShadow;
  final List<BoxShadow> floatingShadow;

  factory AppSemanticColors.light(QuickBrand brand) => AppSemanticColors(
        accent: brand.accent,
        brandSurface: brand.seed,
        brandSurfaceSoft: brand.softOn(AppColors.lightSurface),
        onBrandSurface: brand.onSeed,
        success: AppColors.success,
        successSoft: AppColors.successSoft,
        warning: AppColors.warning,
        warningSoft: AppColors.warningSoft,
        danger: AppColors.danger,
        dangerSoft: AppColors.dangerSoft,
        border: AppColors.lightBorder,
        surfaceAlt: AppColors.lightSurfaceAlt,
        textSecondary: AppColors.lightTextSecondary,
        cardShadow: const [
          BoxShadow(color: Color(0x0F101613), blurRadius: 16, offset: Offset(0, 4)),
        ],
        sheetShadow: const [
          BoxShadow(color: Color(0x1A101613), blurRadius: 32, offset: Offset(0, -8)),
        ],
        floatingShadow: [
          BoxShadow(
            color: brand.seed.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  factory AppSemanticColors.dark(QuickBrand brand) => AppSemanticColors(
        accent: brand.accent,
        brandSurface: brand.softOn(AppColors.darkSurface),
        brandSurfaceSoft: brand.softOn(AppColors.darkBackground),
        onBrandSurface: AppColors.darkTextPrimary,
        success: const Color(0xFF3DD68C),
        successSoft: const Color(0xFF13301F),
        warning: const Color(0xFFF2B950),
        warningSoft: const Color(0xFF33260D),
        danger: const Color(0xFFFF6B7A),
        dangerSoft: const Color(0xFF3A1319),
        border: AppColors.darkBorder,
        surfaceAlt: AppColors.darkSurfaceAlt,
        textSecondary: AppColors.darkTextSecondary,
        cardShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 6)),
        ],
        sheetShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 36, offset: Offset(0, -10)),
        ],
        floatingShadow: [
          BoxShadow(
            color: brand.seed.withValues(alpha: 0.42),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      );

  @override
  AppSemanticColors copyWith({
    Color? accent,
    Color? brandSurface,
    Color? brandSurfaceSoft,
    Color? onBrandSurface,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? border,
    Color? surfaceAlt,
    Color? textSecondary,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? sheetShadow,
    List<BoxShadow>? floatingShadow,
  }) {
    return AppSemanticColors(
      accent: accent ?? this.accent,
      brandSurface: brandSurface ?? this.brandSurface,
      brandSurfaceSoft: brandSurfaceSoft ?? this.brandSurfaceSoft,
      onBrandSurface: onBrandSurface ?? this.onBrandSurface,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      border: border ?? this.border,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textSecondary: textSecondary ?? this.textSecondary,
      cardShadow: cardShadow ?? this.cardShadow,
      sheetShadow: sheetShadow ?? this.sheetShadow,
      floatingShadow: floatingShadow ?? this.floatingShadow,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      accent: Color.lerp(accent, other.accent, t)!,
      brandSurface: Color.lerp(brandSurface, other.brandSurface, t)!,
      brandSurfaceSoft:
          Color.lerp(brandSurfaceSoft, other.brandSurfaceSoft, t)!,
      onBrandSurface: Color.lerp(onBrandSurface, other.onBrandSurface, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      border: Color.lerp(border, other.border, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      sheetShadow: t < 0.5 ? sheetShadow : other.sheetShadow,
      floatingShadow: t < 0.5 ? floatingShadow : other.floatingShadow,
    );
  }
}
