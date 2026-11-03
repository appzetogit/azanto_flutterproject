import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared veg-only filter, toggled from both the Home search bar pill and
/// the Profile "Veg Mode" switch so they always reflect the same state.
///
/// Persisted: it reads as a standing preference, not a per-visit one, and the
/// 99 Store filters its rows through it — losing it on restart silently put
/// non-veg dishes back in front of someone who had asked not to see them.
final vegFilterProvider = NotifierProvider<VegFilterNotifier, bool>(() {
  return VegFilterNotifier();
});

class VegFilterNotifier extends Notifier<bool> {
  static const _vegModeKey = 'veg_mode_enabled';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_vegModeKey);
      if (saved != null && saved != state) state = saved;
    } catch (_) {
      // Storage is a convenience here; losing it just means veg mode off.
    }
  }

  void set(bool value) {
    state = value;
    _persist(value);
  }

  void toggle() => set(!state);

  Future<void> _persist(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_vegModeKey, value);
    } catch (_) {
      // Ignored for the same reason as above.
    }
  }
}
