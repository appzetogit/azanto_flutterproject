import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/presentation/branding/app_colors.dart';
import 'package:azanto/src/presentation/branding/app_theme.dart';
import 'package:azanto/src/presentation/branding/theme_color_provider.dart';
import 'package:azanto/src/presentation/mode/app_mode.dart';
import 'package:azanto/src/shared/theme/active_brand.dart';
import 'package:azanto/src/shared/theme/mart_brand.dart';
import 'package:azanto/src/quick/core/local_storage/local_storage.dart';
import 'package:azanto/src/quick/di/repository_providers.dart' show localStorageProvider;
import 'package:shared_preferences/shared_preferences.dart';

/// Mart's colour comes from the admin panel over the network; pin it so this
/// test measures the module switch rather than a fetch.
const _adminMartColor = Color(0xFFFF7A00);

class _FixedMartBrand extends MartBrandNotifier {
  @override
  Color build() => _adminMartColor;
}

/// In-memory stand-in for the key-value store `main()` injects. The active
/// brand depends on the persisted module, so the provider graph needs one.
class _MemoryStorage implements LocalStorage {
  final _values = <String, Object>{};

  @override
  String? getString(String key) => _values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => _values[key] = value;
  @override
  bool? getBool(String key) => _values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;
  @override
  List<String> getStringList(String key) =>
      (_values[key] as List<String>?) ?? const [];
  @override
  Future<void> setStringList(String key, List<String> value) async =>
      _values[key] = value;
  @override
  Future<void> remove(String key) async => _values.remove(key);
}

/// Guards the app-theme-color feature: picking a color must repaint widgets
/// that read [AppColors] without an app restart. Regresses if someone
/// reintroduces a hardcoded brand hex or marks a brand-colored widget `const`.
///
/// Reads through `activeBrandProvider`, which is the single writer of
/// [AppColors.primary] — it combines the picked palette with the active module
/// so the shared screens follow whichever vertical the user is in.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Tests mutate the global AppColors; reset so order doesn't matter.
    AppColors.primary = AppThemeColor.azanto.color;
    AppColors.primaryButton = AppThemeColor.azanto.buttonColor;
  });

  test('derived shades follow primary and stay in the brand hue', () {
    AppColors.primary = AppThemeColor.blue.color;
    final blueHue = HSLColor.fromColor(AppColors.primary).hue;

    for (final shade in [
      AppColors.primaryLight,
      AppColors.primaryDeep,
      AppColors.primaryDeepText,
      AppColors.primaryTint,
      AppColors.primaryTintStrong,
      AppColors.primarySoft,
      AppColors.primaryTintDark,
      AppColors.primaryTintDarkStrong,
    ]) {
      // Tolerance is wide for the darkest shades: at very low lightness the
      // 8-bit round-trip through toColor() quantizes hue noticeably.
      expect(HSLColor.fromColor(shade).hue, closeTo(blueHue, 6.0));
    }

    // Ordering by lightness is what makes tints read as tints.
    double l(Color c) => HSLColor.fromColor(c).lightness;
    expect(l(AppColors.primaryTint), greaterThan(l(AppColors.primaryTintStrong)));
    expect(l(AppColors.primaryTintStrong), greaterThan(l(AppColors.primarySoft)));
    expect(l(AppColors.primarySoft), greaterThan(l(AppColors.primaryDeep)));
    expect(l(AppColors.primaryDeep), greaterThan(l(AppColors.primaryTintDark)));
  });

  testWidgets('changing the theme color repaints a live widget tree', (tester) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageProvider.overrideWithValue(_MemoryStorage())],
        child: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            ref.watch(activeBrandProvider); // what the real app root does
            return MaterialApp(
              theme: buildLightTheme(),
              home: Scaffold(
                body: Column(
                  children: [
                    ColoredBox(
                      key: const Key('direct'),
                      color: AppColors.primary,
                      child: const SizedBox(width: 10, height: 10),
                    ),
                    ColoredBox(
                      key: const Key('tint'),
                      color: AppColors.primaryTint,
                      child: const SizedBox(width: 10, height: 10),
                    ),
                    Builder(
                      builder: (c) => ColoredBox(
                        key: const Key('themed'),
                        color: Theme.of(c).colorScheme.primary,
                        child: const SizedBox(width: 10, height: 10),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );

    // Keyed lookup, not index: Scaffold/Material paint their own ColoredBoxes.
    Color painted(String key) => tester.widget<ColoredBox>(find.byKey(Key(key))).color;

    // Violet is the shipped default palette, and Food is the default module.
    expect(painted('direct'), AppThemeColor.azanto.color);
    expect(painted('themed'), AppThemeColor.azanto.color, reason: 'ThemeData must carry the brand color');
    final defaultTint = painted('tint');

    await capturedRef.read(themeColorProvider.notifier).setColor(AppThemeColor.green);
    await tester.pumpAndSettle();

    expect(painted('direct'), AppThemeColor.green.color, reason: 'direct AppColors read must update');
    expect(painted('themed'), AppThemeColor.green.color, reason: 'Theme.of() consumers must update');
    expect(painted('tint'), isNot(defaultTint), reason: 'derived tints must update too');
  });

  testWidgets('switching module recolours the shared screens immediately', (tester) async {
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(_MemoryStorage()),
          martBrandProvider.overrideWith(_FixedMartBrand.new),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            capturedRef = ref;
            ref.watch(activeBrandProvider);
            return MaterialApp(
              theme: buildLightTheme(),
              home: Scaffold(
                body: ColoredBox(
                  key: const Key('shared'),
                  color: AppColors.primary,
                  child: const SizedBox(width: 10, height: 10),
                ),
              ),
            );
          },
        ),
      ),
    );

    Color painted() =>
        tester.widget<ColoredBox>(find.byKey(const Key('shared'))).color;

    // Food is the default module: the shared screen wears the food palette.
    expect(painted(), AppThemeColor.azanto.color);

    capturedRef.read(appModeProvider.notifier).set(AppMode.quick);
    await tester.pumpAndSettle();

    // Same widget, no rebuild of the tree, no restart — Mart's admin colour.
    expect(painted(), _adminMartColor,
        reason: 'shared screens must follow the active module');

    capturedRef.read(appModeProvider.notifier).set(AppMode.food);
    await tester.pumpAndSettle();

    expect(painted(), AppThemeColor.azanto.color,
        reason: 'switching back must restore the food brand');
  });
}
