import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../../core/theme/athlos_radius.dart';
import '../../../../../core/theme/athlos_spacing.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../domain/enums/load_mode.dart';
import '../../helpers/load_mode_l10n.dart';
import 'ad_hoc_config_int_field.dart';
import 'ad_hoc_exercise_config_model.dart';

/// Toggles and notes — aligned with workout builder options, sheet layout.
class AdHocExerciseConfigOptionsSection extends StatefulWidget {
  final AdHocExerciseConfig config;
  final ValueChanged<AdHocExerciseConfig> onChanged;

  const AdHocExerciseConfigOptionsSection({
    required this.config,
    required this.onChanged,
    super.key,
  });

  @override
  State<AdHocExerciseConfigOptionsSection> createState() =>
      _AdHocExerciseConfigOptionsSectionState();
}

class _AdHocExerciseConfigOptionsSectionState
    extends State<AdHocExerciseConfigOptionsSection> {
  late bool _showNotes;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _showNotes =
        widget.config.notes != null && widget.config.notes!.trim().isNotEmpty;
    _notesController = TextEditingController(text: widget.config.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickLoadMode() async {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final config = widget.config;
    final effective = config.loadModeOverride ?? config.exercise.defaultLoadMode;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colorScheme.bottomSheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AthlosRadius.lg)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AthlosSpacing.md,
              AthlosSpacing.sm,
              AthlosSpacing.md,
              AthlosSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.workoutFormLoadModePickerTitle,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(AthlosSpacing.sm),
                for (final mode in LoadMode.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.scale_outlined, color: colorScheme.primary),
                    title: Text(localizedLoadModeOptionTitle(mode, l10n)),
                    trailing: mode == effective
                        ? Icon(Icons.check_circle, color: colorScheme.primary)
                        : null,
                    onTap: () {
                      config.loadModeOverride =
                          mode == config.exercise.defaultLoadMode ? null : mode;
                      widget.onChanged(config);
                      Navigator.pop(ctx);
                      setState(() {});
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = widget.config;
    final effectiveLoadMode =
        config.loadModeOverride ?? config.exercise.defaultLoadMode;

    return AthlosBottomSheetContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdHocConfigSectionLabel(
            l10n.workoutFormSectionMoreOptions,
            icon: Icons.more_horiz,
          ),
          if (config.exercise.supportsLoadModeOverride)
            _OptionTile(
              icon: Icons.scale_outlined,
              title: l10n.workoutFormLoadModeFieldLabel,
              subtitle: localizedLoadModeShort(effectiveLoadMode, l10n),
              onTap: _pickLoadMode,
            ),
          if (!config.usesDuration)
            _OptionSwitchTile(
              icon: Icons.local_fire_department_outlined,
              title: l10n.amrapLabel,
              subtitle: l10n.amrapTooltip,
              value: config.isAmrap,
              onChanged: (v) {
                config.isAmrap = v;
                widget.onChanged(config);
                setState(() {});
              },
            ),
          _OptionSwitchTile(
            icon: Icons.swap_horiz,
            title: l10n.unilateralLabel,
            subtitle: l10n.adHocConfigUnilateralHint,
            value: config.isUnilateral,
            onChanged: (v) {
              config.isUnilateral = v;
              widget.onChanged(config);
              setState(() {});
            },
          ),
          _OptionSwitchTile(
            icon: Icons.note_alt_outlined,
            title: l10n.workoutNotesTitle,
            value: _showNotes,
            onChanged: (v) {
              setState(() {
                _showNotes = v;
                if (!v) {
                  config.notes = null;
                  _notesController.clear();
                  widget.onChanged(config);
                }
              });
            },
          ),
          if (_showNotes) ...[
            const Gap(AthlosSpacing.md),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: l10n.exerciseNotesHint,
              ),
              onChanged: (value) {
                config.notes = value.trim().isEmpty ? null : value.trim();
                widget.onChanged(config);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

class _OptionSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionSwitchTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      secondary: Icon(icon, color: colorScheme.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
    );
  }
}
