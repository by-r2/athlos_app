import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../core/presentation/navigation/confirm_navigation_scope.dart';
import '../../../../core/presentation/navigation/navigation_leave_dialogs.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/enums/gender.dart';
import '../helpers/profile_form_utils.dart';
import '../providers/profile_notifier.dart';
import '../widgets/profile_section_header.dart';

/// Full-screen editor for personal data and health fields.
class ProfileOverviewEditScreen extends ConsumerStatefulWidget {
  const ProfileOverviewEditScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ProfileOverviewEditScreen(),
      ),
    );
  }

  @override
  ConsumerState<ProfileOverviewEditScreen> createState() =>
      _ProfileOverviewEditScreenState();
}

class _ProfileOverviewEditScreenState
    extends ConsumerState<ProfileOverviewEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  final _injuriesController = TextEditingController();
  final _bioController = TextEditingController();
  Gender? _selectedGender;
  String? _editBaseline;
  bool _initialized = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _injuriesController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _loadFromProfile(UserProfile profile) {
    _nameController.text = profile.name ?? '';
    _heightController.text = profile.height?.toString() ?? '';
    _ageController.text = profile.age?.toString() ?? '';
    _selectedGender = profile.gender;
    _injuriesController.text = profile.injuries ?? '';
    _bioController.text = profile.bio ?? '';
    _editBaseline = _snapshotEdit();
  }

  String _snapshotEdit() => [
    _nameController.text,
    _heightController.text,
    _ageController.text,
    _injuriesController.text,
    _bioController.text,
    _selectedGender?.name ?? 'null',
  ].join('\u001e');

  bool get _isDirty =>
      _editBaseline != null && _snapshotEdit() != _editBaseline;

  Future<void> _cancel() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await confirmDiscardUnsavedEdits(context);
    if (!mounted) return;
    if (discard) Navigator.of(context).pop();
  }

  Future<void> _save(UserProfile profile) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final heightText = _heightController.text.trim();
    final ageText = _ageController.text.trim();
    final injuries = _injuriesController.text.trim();
    final bio = _bioController.text.trim();

    final updated = profile.copyWith(
      name: () => name.isEmpty ? null : name,
      height: () =>
          heightText.isEmpty ? null : tryParseProfileDecimal(heightText),
      age: () => ageText.isEmpty ? null : int.tryParse(ageText),
      gender: () => _selectedGender,
      injuries: () => injuries.isEmpty ? null : injuries,
      bio: () => bio.isEmpty ? null : bio,
    );

    setState(() => _isSaving = true);
    try {
      await ref.read(profileProvider.notifier).updateProfile(updated);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.genericError)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.value;

    if (profile != null && !_initialized) {
      _loadFromProfile(profile);
      _initialized = true;
    }

    return ConfirmNavigationScope(
      guardActive: _isDirty && !_isSaving,
      onConfirmLeave: confirmDiscardUnsavedEdits,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profileHeroEditProfileAction),
          leading: BackButton(onPressed: _cancel),
        ),
        body: profile == null
            ? Center(
                child: profileAsync.hasError
                    ? Text(l10n.genericError)
                    : const CircularProgressIndicator(),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AthlosSpacing.md),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ProfileSectionHeader(
                              title: l10n.profileSectionPersonal,
                            ),
                            const Gap(AthlosSpacing.sm),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: l10n.nameLabel,
                              ),
                              textCapitalization: TextCapitalization.words,
                              onChanged: (_) => setState(() {}),
                            ),
                            const Gap(AthlosSpacing.md),
                            TextFormField(
                              controller: _heightController,
                              decoration: InputDecoration(
                                labelText: l10n.heightLabel,
                                suffixText: l10n.heightUnit,
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.,]'),
                                ),
                              ],
                              validator: (value) {
                                if (value != null &&
                                    value.isNotEmpty &&
                                    tryParseProfileDecimal(value) == null) {
                                  return l10n.invalidNumber;
                                }
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                            ),
                            const Gap(AthlosSpacing.md),
                            TextFormField(
                              controller: _ageController,
                              decoration: InputDecoration(
                                labelText: l10n.ageLabel,
                                suffixText: l10n.yearsUnit,
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                if (value != null &&
                                    value.isNotEmpty &&
                                    int.tryParse(value) == null) {
                                  return l10n.invalidNumber;
                                }
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                            ),
                            const Gap(AthlosSpacing.md),
                            Text(
                              l10n.profileGender,
                              style: textTheme.titleMedium,
                            ),
                            Wrap(
                              spacing: AthlosSpacing.sm,
                              children: [
                                ChoiceChip(
                                  label: Text(l10n.genderMale),
                                  selected: _selectedGender == Gender.male,
                                  onSelected: (_) => setState(
                                    () => _selectedGender = Gender.male,
                                  ),
                                ),
                                ChoiceChip(
                                  label: Text(l10n.genderFemale),
                                  selected: _selectedGender == Gender.female,
                                  onSelected: (_) => setState(
                                    () => _selectedGender = Gender.female,
                                  ),
                                ),
                                ChoiceChip(
                                  label: Text(l10n.setupChatPreferNotToSay),
                                  selected: _selectedGender == null,
                                  onSelected: (_) =>
                                      setState(() => _selectedGender = null),
                                ),
                              ],
                            ),
                            const Gap(AthlosSpacing.lg),
                            ProfileSectionHeader(
                              title: l10n.profileSectionHealth,
                            ),
                            const Gap(AthlosSpacing.sm),
                            TextFormField(
                              controller: _injuriesController,
                              decoration: InputDecoration(
                                labelText: l10n.injuriesLabel,
                                hintText: l10n.injuriesHint,
                                alignLabelWithHint: true,
                              ),
                              maxLines: 3,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (_) => setState(() {}),
                            ),
                            const Gap(AthlosSpacing.md),
                            TextFormField(
                              controller: _bioController,
                              decoration: InputDecoration(
                                labelText: l10n.bioLabel,
                                hintText: l10n.bioHint,
                                alignLabelWithHint: true,
                              ),
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AthlosSpacing.md),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : _cancel,
                              child: Text(l10n.cancel),
                            ),
                          ),
                          const Gap(AthlosSpacing.smd),
                          Expanded(
                            child: FilledButton(
                              onPressed: _isSaving ? null : () => _save(profile),
                              child: _isSaving
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(l10n.save),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
