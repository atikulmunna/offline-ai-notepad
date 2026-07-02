import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/app_background.dart';
import '../domain/app_theme_mode.dart';
import '../providers/appearance_providers.dart';

/// Opens the appearance settings (theme mode + animated background) as a modal
/// bottom sheet, matching the other settings sheets on the home page.
Future<void> showAppearanceSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _AppearanceSheet(),
  );
}

class _AppearanceSheet extends ConsumerWidget {
  const _AppearanceSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    final state = ref.watch(appearanceControllerProvider);
    final controller = ref.read(appearanceControllerProvider.notifier);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appearance', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Pick a theme and an animated backdrop for your library.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: surfaces.mutedText,
              ),
            ),
            const SizedBox(height: 20),
            Text('Theme', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            SegmentedButton<AppThemeMode>(
              segments: [
                for (final mode in AppThemeMode.values)
                  ButtonSegment(value: mode, label: Text(mode.label)),
              ],
              selected: {state.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  controller.setThemeMode(selection.first),
            ),
            const SizedBox(height: 24),
            Text('Library background', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Plays behind your notes. The editor always stays calm and black.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: surfaces.mutedText,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final background in AppBackground.values)
                  _BackgroundChip(
                    background: background,
                    selected: state.background == background,
                    onTap: () => controller.setBackground(background),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Assistant', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: state.smartSuggestions,
              onChanged: controller.setSmartSuggestions,
              title: const Text('Smart suggestions'),
              subtitle: Text(
                'Suggest a title and folder while you write, on device.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: surfaces.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundChip extends StatelessWidget {
  const _BackgroundChip({
    required this.background,
    required this.selected,
    required this.onTap,
  });

  final AppBackground background;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (background) {
        AppBackground.none => Icons.block_rounded,
        AppBackground.particles => Icons.blur_on_rounded,
        AppBackground.snow => Icons.ac_unit_rounded,
        AppBackground.geometric => Icons.category_rounded,
        AppBackground.space => Icons.auto_awesome_rounded,
        AppBackground.shuffle => Icons.shuffle_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = theme.extension<AppSurfaces>()!;
    return ChoiceChip(
      avatar: Icon(
        _icon,
        size: 18,
        color: selected ? theme.colorScheme.onPrimary : surfaces.mutedText,
      ),
      label: Text(background.label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
