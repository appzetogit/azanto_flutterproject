import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../di/push_providers.dart';
import '../../../../../presentation/branding/theme_provider.dart' as app_theme;
import '../../../../core/local_storage/local_storage.dart';
import '../../../../core/utils/app_haptics.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../di/repository_providers.dart';
import '../../../common/widgets/misc/section_header.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(app_theme.themeProvider);
    final storage = ref.watch(localStorageProvider);
    final notificationsOn =
        storage.getBool(StorageKeys.notificationsEnabled) ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            const SectionHeader(title: 'Appearance'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_rounded),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.settings_brightness_rounded),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) {
                  AppHaptics.selection();
                  ref
                      .read(app_theme.themeProvider.notifier)
                      .setTheme(switch (selection.first) {
                        ThemeMode.dark => 'Dark',
                        ThemeMode.system => 'System',
                        ThemeMode.light => 'Light',
                      });
                },
              ),
            ),
            const SectionHeader(title: 'Notifications'),
            SwitchListTile.adaptive(
              value: notificationsOn,
              title: Text('Order updates', style: context.text.titleMedium),
              subtitle: Text(
                'Packing, dispatch and delivery alerts',
                style: context.text.bodySmall,
              ),
              onChanged: (value) async {
                AppHaptics.selection();
                await storage.setBool(StorageKeys.notificationsEnabled, value);
                final push = ref.read(pushServiceProvider);
                if (value) {
                  // Re-register: turning the switch off dropped the token, so
                  // the backend has no way to reach this device until it is
                  // sent again.
                  await push.registerToken();
                } else {
                  await push.unregisterToken();
                }
                // Rebuild so the switch reflects what was actually persisted.
                ref.invalidate(localStorageProvider);
              },
            ),
            const SectionHeader(title: 'App'),
            ListTile(
              leading: const Icon(Icons.translate_rounded),
              title: Text('Language', style: context.text.titleMedium),
              subtitle: Text('English (India)', style: context.text.bodySmall),
              trailing: Text('Default', style: context.text.bodySmall),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text('App version', style: context.text.titleMedium),
              trailing: Text('1.0.0 (1)', style: context.text.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
