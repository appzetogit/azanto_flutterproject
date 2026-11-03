import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radii.dart';
import 'app_spacing.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData light(QuickBrand brand) => _build(brand, Brightness.light);
  static ThemeData dark(QuickBrand brand) => _build(brand, Brightness.dark);

  static ThemeData _build(QuickBrand brand, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    // The brand colour is whatever the user picked. Green is a *status* colour
    // (success, veg, active) and reaches the UI through `semantic.success`,
    // never through `colorScheme.primary` — having it as primary is what put
    // green on the splash, the buttons, the progress indicators and the focus
    // rings.
    final primaryColor = brand.seed;
    final secondaryColor = brand.accent;

    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
    ).copyWith(
      primary: primaryColor,
      // Decided from the plate's own luminance, not fixed: the yellow flavour
      // is a bright plate needing dark ink, the teal one is deep and needs
      // white (4.53:1). Decided once here so it cannot drift per widget.
      onPrimary: AppColors.onPlate(primaryColor),
      secondary: secondaryColor,
      onSecondary: AppColors.lightSurface,
      tertiary: AppColors.orangeBadge,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      onSurface: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      error: isDark ? const Color(0xFFFF6B7A) : AppColors.danger,
    );

    final semantic =
        isDark ? AppSemanticColors.dark(brand) : AppSemanticColors.light(brand);
    final text = AppTextStyles.textTheme(scheme.onSurface, semantic.textSecondary);
    final background = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      textTheme: text,
      extensions: [semantic],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.rLg),
      ),
      dividerTheme: DividerThemeData(
        color: semantic.border,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: semantic.surfaceAlt,
        selectedColor: scheme.primary.withValues(alpha: 0.12),
        side: BorderSide(color: semantic.border),
        labelStyle: text.titleSmall!,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.rPill),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semantic.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: text.bodyLarge!.copyWith(color: semantic.textSecondary),
        border: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: semantic.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: semantic.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheetTop),
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.rXl),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyLarge!.copyWith(color: semantic.textSecondary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        elevation: 0,
        height: 66,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
      // Without this the caret and selection come from the app-level theme —
      // a violet cursor blinking in a teal search field, because a nested
      // Theme does not otherwise override the root's selection style.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionHandleColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.28),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        iconColor: scheme.onSurface,
      ),
    );
  }
}

/// Sugar so widgets read `context.semantic.border` instead of a lookup dance.
extension AppThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  /// Falls back to the brightness-matched defaults when a quick widget is
  /// shown outside [QuickThemeScope] (e.g. hosted inside a food-vertical
  /// screen), where the app-level theme never registered the extension.
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppSemanticColors.dark(QuickBrand.teal)
          : AppSemanticColors.light(QuickBrand.teal));
}
