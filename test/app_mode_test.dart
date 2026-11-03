import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:azanto/src/presentation/mode/app_mode.dart';
import 'package:azanto/src/quick/core/local_storage/local_storage.dart';
import 'package:azanto/src/quick/di/repository_providers.dart'
    show localStorageProvider;

/// A cold start always lands in Food, even for a user who closed the app
/// inside Mart. Switching within the session must still work.
class _Storage implements LocalStorage {
  _Storage([this._seed = const {}]);
  final Map<String, Object> _seed;
  late final Map<String, Object> _values = {..._seed};

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

void main() {
  test('cold start opens Food even when Mart was last used', () {
    // The stored value is exactly what the old build() restored from.
    final c = ProviderContainer(overrides: [
      localStorageProvider.overrideWithValue(_Storage({'app.mode': 'quick'})),
    ]);
    addTearDown(c.dispose);

    expect(c.read(appModeProvider), AppMode.food,
        reason: 'a persisted "quick" must not be restored on launch');
  });

  test('switching still works inside the session', () {
    final c = ProviderContainer(
      overrides: [localStorageProvider.overrideWithValue(_Storage())],
    );
    addTearDown(c.dispose);

    c.read(appModeProvider.notifier).set(AppMode.quick);
    expect(c.read(appModeProvider), AppMode.quick);
  });
}
