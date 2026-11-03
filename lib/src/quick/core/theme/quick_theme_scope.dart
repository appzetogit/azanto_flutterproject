import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/mart_brand.dart';
import '../../ui/common/widgets/misc/status_bar_style.dart';
import 'app_colors.dart';
import 'app_theme.dart';

/// Applies the quick-commerce module's own [ThemeData] to its subtree.
///
/// The Azanto `MaterialApp` is themed for the food vertical, and quick screens
/// depend on this module's component themes and the [AppSemanticColors]
/// extension — without this scope, `context.semantic` falls back to defaults on
/// a theme that never registered the extension.
///
/// The brand comes from [martBrandProvider] — the colour the admin panel
/// publishes for the Mart module. This is the ONE place Mart's palette is
/// decided: every mart screen reads its colours off this `ThemeData` (via
/// `colorScheme` or `context.semantic`) rather than off a constant, so changing
/// the admin setting repaints all of them.
///
/// Light/dark still follows the app-wide ambient brightness so the two
/// verticals never disagree on dark mode.
///
/// It also sets a DEFAULT status-bar style for the whole module, matched to the
/// theme's surface. Most Mart screens set none of their own, and a screen with
/// no style inherits whatever the last one pushed — so arriving at a white
/// listing from the home screen's deep brand header left white icons on white.
/// A screen that paints something else behind the bar (home, with its gradient)
/// wraps itself in its own [StatusBarStyle], which sits deeper and wins.
class QuickThemeScope extends ConsumerWidget {
  const QuickThemeScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brand = QuickBrand.fromSeed(ref.watch(martBrandProvider));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final theme = dark ? AppTheme.dark(brand) : AppTheme.light(brand);
    return Theme(
      data: theme,
      child: StatusBarStyle(
        background: theme.colorScheme.surface,
        child: child,
      ),
    );
  }
}
