import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/presentation/navigation/confirm_navigation_scope.dart';
import '../../../../core/presentation/navigation/navigation_leave_dialogs.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/repositories/training_providers.dart';
import '../../domain/entities/deload_config.dart';
import '../../domain/entities/training_program.dart';
import '../../domain/enums/deload_strategy.dart';
import '../../domain/enums/duration_mode.dart';
import '../../domain/enums/program_focus.dart';
import '../providers/program_notifier.dart';

/// Screen to create or edit a training program (mesocycle).
///
/// Slim form: name, focus, duration, rest, deload config, activate switch.
/// Cycle and progression rules are managed in ProgramDetailScreen.
class ProgramFormScreen extends ConsumerStatefulWidget {
  final String? programId;

  const ProgramFormScreen({super.key, this.programId});

  @override
  ConsumerState<ProgramFormScreen> createState() => _ProgramFormScreenState();
}

class _ProgramFormScreenState extends ConsumerState<ProgramFormScreen> {
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _restController = TextEditingController();
  final _deloadFreqController = TextEditingController();
  final _deloadVolController = TextEditingController(text: '0.6');
  final _deloadIntController = TextEditingController(text: '0.5');
  ProgramFocus _focus = ProgramFocus.hypertrophy;
  DurationMode _durationMode = DurationMode.sessions;
  bool _activate = true;
  bool _loaded = false;
  bool _saving = false;
  bool _dirty = false;
  bool _deloadEnabled = false;
  DeloadStrategy _deloadStrategy = DeloadStrategy.reduceVolume;

  bool get _isEditing => widget.programId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _restController.dispose();
    _deloadFreqController.dispose();
    _deloadVolController.dispose();
    _deloadIntController.dispose();
    super.dispose();
  }

  void _loadExisting(TrainingProgram p) {
    if (_loaded) return;
    _loaded = true;
    _nameController.text = p.name;
    _focus = p.focus;
    _durationMode = p.durationMode;
    _durationController.text = p.durationValue.toString();
    if (p.defaultRestSeconds != null) {
      _restController.text = p.defaultRestSeconds.toString();
    }
    _activate = p.isActive;
    if (p.deloadConfig != null) {
      _deloadEnabled = true;
      _deloadStrategy = p.deloadConfig!.strategy;
      if (p.deloadConfig!.frequency != null) {
        _deloadFreqController.text = p.deloadConfig!.frequency.toString();
      }
      _deloadVolController.text = p.deloadConfig!.volumeMultiplier.toString();
      _deloadIntController.text = p.deloadConfig!.intensityMultiplier
          .toString();
    }
    _dirty = false;
  }

  void _touchEdit() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final durationValue = int.tryParse(_durationController.text.trim());
    if (durationValue == null || durationValue <= 0) return;
    final rest = int.tryParse(_restController.text.trim());

    DeloadConfig? deloadConfig;
    if (_deloadEnabled) {
      final freq = int.tryParse(_deloadFreqController.text.trim());
      final vol = double.tryParse(_deloadVolController.text.trim()) ?? 0.6;
      final intensity =
          double.tryParse(_deloadIntController.text.trim()) ?? 0.5;
      deloadConfig = DeloadConfig(
        frequency: freq,
        strategy: _deloadStrategy,
        volumeMultiplier: vol,
        intensityMultiplier: intensity,
      );
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(programRepositoryProvider);

      if (_isEditing) {
        final program = TrainingProgram(
          id: widget.programId!,
          name: name,
          focus: _focus,
          durationMode: _durationMode,
          durationValue: durationValue,
          defaultRestSeconds: rest,
          deloadConfig: deloadConfig,
          createdAt: DateTime.now(),
        );
        (await repo.update(program)).getOrThrow();
      } else {
        final program = TrainingProgram(
          id: '',
          name: name,
          focus: _focus,
          durationMode: _durationMode,
          durationValue: durationValue,
          defaultRestSeconds: rest,
          isActive: _activate,
          deloadConfig: deloadConfig,
          createdAt: DateTime.now(),
        );
        final id = (await repo.create(program)).getOrThrow();
        if (_activate) {
          (await repo.activate(id)).getOrThrow();
        }
      }

      ref.invalidate(programListProvider);
      ref.invalidate(activeProgramProvider);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? l10n.programUpdated : l10n.programCreated,
            ),
          ),
        );
        context.pop();
      }
    } on Exception catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.genericError)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _updateFocusRest(ProgramFocus focus) {
    _touchEdit();
    setState(() {
      _focus = focus;
      if (_restController.text.isEmpty) {
        final suggested = focus.suggestedRestSeconds;
        if (suggested != null) {
          _restController.text = suggested.toString();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isEditing) {
      final programsAsync = ref.watch(programListProvider);
      final program = programsAsync.value
          ?.where((p) => p.id == widget.programId)
          .firstOrNull;
      if (program != null) {
        _loadExisting(program);
      }
    }

    final canSave =
        _nameController.text.trim().isNotEmpty &&
        (_durationController.text.trim().isNotEmpty);

    return ConfirmNavigationScope(
      guardActive: _dirty,
      onConfirmLeave: confirmDiscardUnsavedEdits,
      onLeaveConfirmed: (ctx) {
        if (ctx.mounted) ctx.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? l10n.programEditTitle : l10n.programCreateTitle,
          ),
          actions: [
            TextButton(
              onPressed: canSave && !_saving ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.programSaveAction),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AthlosSpacing.md),
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.programNameLabel,
                hintText: l10n.programNameHint,
              ),
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                _touchEdit();
                setState(() {});
              },
            ),
            const SizedBox(height: AthlosSpacing.lg),

            Text(
              l10n.programFocusLabel,
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AthlosSpacing.sm),
            Wrap(
              spacing: AthlosSpacing.sm,
              children: ProgramFocus.values.map((f) {
                final label = switch (f) {
                  ProgramFocus.hypertrophy => l10n.programFocusHypertrophy,
                  ProgramFocus.strength => l10n.programFocusStrength,
                  ProgramFocus.endurance => l10n.programFocusEndurance,
                  ProgramFocus.custom => l10n.programFocusCustom,
                };
                return ChoiceChip(
                  label: Text(label),
                  selected: _focus == f,
                  onSelected: (_) => _updateFocusRest(f),
                );
              }).toList(),
            ),
            const SizedBox(height: AthlosSpacing.lg),

            Text(
              l10n.programDurationModeLabel,
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AthlosSpacing.sm),
            SegmentedButton<DurationMode>(
              segments: [
                ButtonSegment(
                  value: DurationMode.sessions,
                  label: Text(l10n.programDurationModeSessions),
                ),
                ButtonSegment(
                  value: DurationMode.rotations,
                  label: Text(l10n.programDurationModeRotations),
                ),
              ],
              selected: {_durationMode},
              onSelectionChanged: (s) {
                _touchEdit();
                setState(() => _durationMode = s.first);
              },
            ),
            const SizedBox(height: AthlosSpacing.md),

            TextField(
              controller: _durationController,
              decoration: InputDecoration(
                labelText: l10n.programDurationValueLabel,
                hintText: _durationMode == DurationMode.sessions
                    ? l10n.programDurationValueHintSessions
                    : l10n.programDurationValueHintRotations,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                _touchEdit();
                setState(() {});
              },
            ),
            const SizedBox(height: AthlosSpacing.md),

            TextField(
              controller: _restController,
              decoration: InputDecoration(
                labelText: l10n.programDefaultRestLabel,
                hintText: l10n.programDefaultRestHint,
                suffixText: 's',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) {
                _touchEdit();
                setState(() {});
              },
            ),

            const SizedBox(height: AthlosSpacing.lg),
            Text(
              l10n.deloadSectionTitle,
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.deloadEnableLabel),
              value: _deloadEnabled,
              onChanged: (v) {
                _touchEdit();
                setState(() => _deloadEnabled = v);
              },
            ),
            if (_deloadEnabled) ...[
              const SizedBox(height: AthlosSpacing.sm),
              Text(
                l10n.deloadStrategyLabel,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AthlosSpacing.xs),
              Wrap(
                spacing: AthlosSpacing.sm,
                children: DeloadStrategy.values.map((s) {
                  final label = switch (s) {
                    DeloadStrategy.reduceVolume =>
                      l10n.deloadStrategyReduceVolume,
                    DeloadStrategy.reduceIntensity =>
                      l10n.deloadStrategyReduceIntensity,
                    DeloadStrategy.reduceBoth => l10n.deloadStrategyReduceBoth,
                  };
                  return ChoiceChip(
                    label: Text(label),
                    selected: _deloadStrategy == s,
                    onSelected: (_) {
                      _touchEdit();
                      setState(() => _deloadStrategy = s);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AthlosSpacing.md),
              TextField(
                controller: _deloadFreqController,
                decoration: InputDecoration(
                  labelText: l10n.deloadFrequencyLabel,
                  hintText: l10n.deloadFrequencyManualHint,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) {
                  _touchEdit();
                  setState(() {});
                },
              ),
              const SizedBox(height: AthlosSpacing.md),
              if (_deloadStrategy != DeloadStrategy.reduceIntensity)
                TextField(
                  controller: _deloadVolController,
                  decoration: InputDecoration(
                    labelText: l10n.deloadVolumeMultiplierLabel,
                    hintText: l10n.deloadVolumeMultiplierHint,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) {
                    _touchEdit();
                    setState(() {});
                  },
                ),
              if (_deloadStrategy != DeloadStrategy.reduceIntensity)
                const SizedBox(height: AthlosSpacing.md),
              if (_deloadStrategy != DeloadStrategy.reduceVolume)
                TextField(
                  controller: _deloadIntController,
                  decoration: InputDecoration(
                    labelText: l10n.deloadIntensityMultiplierLabel,
                    hintText: l10n.deloadIntensityMultiplierHint,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) {
                    _touchEdit();
                    setState(() {});
                  },
                ),
            ],

            if (!_isEditing) ...[
              const SizedBox(height: AthlosSpacing.lg),
              SwitchListTile(
                title: Text(l10n.programActivateAndSave),
                value: _activate,
                onChanged: (v) {
                  _touchEdit();
                  setState(() => _activate = v);
                },
              ),
            ],
            const SizedBox(height: AthlosSpacing.fabClearance),
          ],
        ),
      ),
    );
  }
}
