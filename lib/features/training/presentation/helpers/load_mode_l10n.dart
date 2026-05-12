import '../../../../l10n/app_localizations.dart';
import '../../domain/enums/load_mode.dart';

/// Localized title for a [LoadMode] (workout builder, execution options, etc.).
String localizedLoadModeOptionTitle(LoadMode mode, AppLocalizations l10n) =>
    switch (mode) {
      LoadMode.bodyweight => l10n.loadModeOptionBodyweight,
      LoadMode.weighted => l10n.loadModeOptionWeighted,
      LoadMode.assisted => l10n.loadModeOptionAssisted,
    };

/// Short label for summaries and compact UI (e.g. workout builder card).
String localizedLoadModeShort(LoadMode mode, AppLocalizations l10n) =>
    switch (mode) {
      LoadMode.bodyweight => l10n.loadModeShortBodyweight,
      LoadMode.weighted => l10n.loadModeShortWeighted,
      LoadMode.assisted => l10n.loadModeShortAssisted,
    };
