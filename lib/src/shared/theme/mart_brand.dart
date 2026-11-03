import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';
import '../../di/network_providers.dart';
import '../../quick/core/theme/app_colors.dart';

/// The Mart brand colour published by the admin panel.
///
/// Mart is not painted by the in-app App Theme picker: its colour is whatever
/// the operator set in Admin → Power Scanning → Mart Module, so every Mart
/// screen can be recoloured without shipping a build. Food keeps the user's
/// pick — only this vertical is operator-owned.
///
/// The value is cached in prefs and served from there on [build], because the
/// settings fetch is a round trip and a cold start would otherwise paint one
/// frame of teal before flipping to the real brand. A failed fetch (offline, or
/// a backend predating the `mart` key) leaves the last known colour standing.
final martBrandProvider =
    NotifierProvider<MartBrandNotifier, Color>(MartBrandNotifier.new);

class MartBrandNotifier extends Notifier<Color> {
  static const _key = 'mart.brand_color';

  @override
  Color build() {
    unawaited(_load());
    return AppColors.tealPrimary;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getInt(_key);
      if (cached != null && ref.mounted) state = Color(cached);

      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>(ApiPaths.powerScanning);
      final mart = json['mart'];
      final color = parseHexColor(mart is Map ? mart['themeColor'] : null);
      if (color == null) return;
      await prefs.setInt(_key, color.toARGB32());
      // `mounted` because this outlives the container in tests and on logout.
      if (ref.mounted) state = color;
    } catch (_) {
      // Offline, or a backend predating the `mart` key: keep what we have
      // rather than snapping back to the default.
    }
  }
}

/// `#RRGGBB` (with or without the hash) → an opaque [Color]; null if malformed.
@visibleForTesting
Color? parseHexColor(Object? value) {
  final raw = value?.toString().trim().replaceFirst('#', '') ?? '';
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(raw)) return null;
  return Color(0xFF000000 | int.parse(raw, radix: 16));
}
