import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/widgets/feedback/athlos_messenger.dart';
import '../../../../l10n/app_localizations.dart';

/// Renders the widget under [boundaryKey] to a PNG and opens the system share sheet.
Future<void> shareRepaintBoundaryAsPng({
  required BuildContext context,
  required GlobalKey boundaryKey,
  required String shareText,
  required String fileName,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final pixelRatio = MediaQuery.devicePixelRatioOf(context).clamp(2.0, 4.0);

  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted) return;
  final object = boundaryKey.currentContext?.findRenderObject();
  final boundary = object is RenderRepaintBoundary ? object : null;
  if (boundary == null || !boundary.hasSize) {
    context.showAthlosErrorSnack(l10n.workoutShareSummaryShareError);
    return;
  }

  try {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null) {
      throw StateError('PNG encode returned null');
    }
    final bytes = byteData.buffer.asUint8List();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: shareText),
    );
  } on Exception catch (_) {
    if (!context.mounted) return;
    context.showAthlosErrorSnack(l10n.workoutShareSummaryShareError);
  }
}
