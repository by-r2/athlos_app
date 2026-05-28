import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../core/theme/athlos_bottom_sheet.dart';
import '../../../../core/theme/athlos_component_sizes.dart';
import '../../../../core/theme/athlos_screen_button_styles.dart';
import '../../../../core/theme/athlos_spacing.dart';
import '../../../../core/widgets/layout/athlos_stacked_actions.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/body_metric.dart';
import '../providers/body_metric_notifier.dart';

double? tryParseBodyMetricDecimal(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

String formatBodyMetricWeight(double weight) =>
    weight % 1 == 0 ? weight.toInt().toString() : weight.toStringAsFixed(1);

/// Bottom sheet to add a weight / body-fat measurement.
Future<void> showBodyMetricRecordSheet({
  required BuildContext context,
  required WidgetRef ref,
}) {
  return showAthlosModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: athlosBottomSheetBodyPadding(sheetContext),
      child: const _BodyMetricRecordSheetBody(),
    ),
  );
}

/// Scrollable history of body-metric entries.
Future<void> showBodyMetricHistorySheet({
  required BuildContext context,
  required List<BodyMetric> metrics,
}) {
  if (metrics.isEmpty) return Future.value();

  final l10n = AppLocalizations.of(context)!;

  return showAthlosModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    wrapInShell: false,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) {
        final locale = Localizations.localeOf(ctx).toString();
        final dateFormat = intl.DateFormat.yMMMd(locale);
        final textTheme = Theme.of(ctx).textTheme;
        final colorScheme = Theme.of(ctx).colorScheme;

        return AthlosBottomSheetShell(
          expand: true,
          child: Expanded(
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(ctx).bottom + AthlosSpacing.md,
              ),
              children: [
                AthlosBottomSheetHeader(
                  title: l10n.bodyMetricsHistory,
                  subtitle: l10n.bodyMetricsHistorySubtitle,
                  icon: Icons.history_rounded,
                ),
                ...metrics.asMap().entries.map((entry) {
                  final index = entry.key;
                  final m = entry.value;
                  final weightStr = formatBodyMetricWeight(m.weight);
                  return Column(
                    key: ValueKey(m.id),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index > 0) const Divider(height: 1),
                      ListTile(
                        minTileHeight: AthlosComponentSizes.listItemMinHeight,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AthlosSpacing.md,
                        ),
                        title: Text('$weightStr kg'),
                        subtitle: Text(
                          dateFormat.format(m.recordedAt.toLocal()),
                        ),
                        trailing: m.bodyFatPercent != null
                            ? Text(
                                '${m.bodyFatPercent!.toStringAsFixed(1)}%',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              )
                            : null,
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _BodyMetricRecordSheetBody extends ConsumerStatefulWidget {
  const _BodyMetricRecordSheetBody();

  @override
  ConsumerState<_BodyMetricRecordSheetBody> createState() =>
      _BodyMetricRecordSheetBodyState();
}

class _BodyMetricRecordSheetBodyState
    extends ConsumerState<_BodyMetricRecordSheetBody> {
  final _weightCtrl = TextEditingController();
  final _bfCtrl = TextEditingController();

  @override
  void dispose() {
    _weightCtrl.dispose();
    _bfCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations l10n) async {
    final w = tryParseBodyMetricDecimal(_weightCtrl.text);
    if (w == null || w <= 0) return;
    final bf = tryParseBodyMetricDecimal(_bfCtrl.text);
    await ref
        .read(bodyMetricListProvider.notifier)
        .add(weight: w, bodyFatPercent: bf);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AthlosBottomSheetHeader(
          title: l10n.bodyMetricsAddSheetTitle,
          subtitle: l10n.bodyMetricsAddSheetSubtitle,
          icon: Icons.monitor_weight_outlined,
          padding: EdgeInsets.zero,
        ),
        const Gap(AthlosSpacing.md),
        AthlosBottomSheetContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _weightCtrl,
                decoration: InputDecoration(
                  labelText: l10n.bodyMetricsWeightLabel,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                autofocus: true,
                textInputAction: TextInputAction.next,
              ),
              const Gap(AthlosSpacing.md),
              TextField(
                controller: _bfCtrl,
                decoration: InputDecoration(
                  labelText: l10n.bodyMetricsBodyFatLabel,
                  hintText: l10n.bodyMetricsBodyFatHint,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(l10n),
              ),
            ],
          ),
        ),
        const Gap(AthlosSpacing.lg),
        AthlosStackedActions(
          children: [
            TextButton(
              style: AthlosScreenButtonStyles.stackedGhost(context),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              style: AthlosScreenButtonStyles.stackedFilled(context),
              onPressed: () => _save(l10n),
              child: Text(l10n.bodyMetricsSaveAction),
            ),
          ],
        ),
      ],
    );
  }
}
