import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/shared/theme/mart_brand.dart';
import 'package:azanto/src/presentation/branding/app_colors.dart';
import 'package:azanto/src/presentation/branding/theme_color_provider.dart';
import 'package:azanto/src/presentation/mode/app_mode.dart';
import 'package:azanto/src/shared/theme/active_brand.dart';
import 'package:azanto/src/quick/core/local_storage/local_storage.dart';
import 'package:azanto/src/quick/di/repository_providers.dart'
    show localStorageProvider;
import 'package:shared_preferences/shared_preferences.dart';

const _adminColor = Color(0xFFFF7A00);

class _FixedMartBrand extends MartBrandNotifier {
  @override
  Color build() => _adminColor;
}

/// AppModeNotifier persists through quick's LocalStorage; back it with memory.
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

/// Two owners of one brand static. Profile's "App Theme" row owns **Food**;
/// **Mart** is owned by the operator (Admin → Power Scanning → Mart Module) and
/// must ignore the in-app pick, or the admin colour is silently overridden the
/// moment a customer changes their theme.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(_MemoryStorage()),
        // Stand in for the admin-published colour; the real notifier fetches it.
        martBrandProvider.overrideWith(_FixedMartBrand.new),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('Mart ignores the in-app palette and wears the admin colour', () async {
    final c = container();
    c.read(appModeProvider.notifier).set(AppMode.quick);

    await c.read(themeColorProvider.notifier).setColor(AppThemeColor.pink);
    c.read(activeBrandProvider);
    expect(AppColors.primary, _adminColor);
  });

  test('Food follows the in-app palette, and a mode round-trip restores it',
      () async {
    final c = container();

    await c.read(themeColorProvider.notifier).setColor(AppThemeColor.blue);

    c.read(appModeProvider.notifier).set(AppMode.food);
    c.read(activeBrandProvider);
    expect(AppColors.primary, AppThemeColor.blue.color);

    c.read(appModeProvider.notifier).set(AppMode.quick);
    c.read(activeBrandProvider);
    expect(AppColors.primary, _adminColor);

    c.read(appModeProvider.notifier).set(AppMode.food);
    c.read(activeBrandProvider);
    expect(AppColors.primary, AppThemeColor.blue.color,
        reason: 'the food pick must survive a trip through Mart');
  });

  test('teal is selectable as a palette', () {
    expect(AppThemeColor.values.map((v) => v.name), contains('teal'));
  });
}
