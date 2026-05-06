import 'package:flutter/material.dart';

/// Text that truncates with ellipsis and exposes the full string via tooltip
/// on long press.
///
/// By default, the tooltip is shown only when the text actually overflows.
class AthlosTruncatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;
  final TextAlign? textAlign;
  final bool showTooltipOnlyWhenOverflow;

  /// When false, never wraps in [Tooltip] — use when a parent needs [onLongPress]
  /// (e.g. list row actions) and would conflict with [TooltipTriggerMode.longPress].
  final bool showOverflowTooltip;

  const AthlosTruncatedText(
    this.text, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.textAlign,
    this.showTooltipOnlyWhenOverflow = true,
    this.showOverflowTooltip = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(style);
    final textDirection = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    final textScaler = MediaQuery.textScalerOf(context);

    final textWidget = Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );

    if (text.trim().isEmpty) return textWidget;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!showOverflowTooltip) return textWidget;

        final hasBoundedWidth = constraints.maxWidth.isFinite;
        final bool shouldShowTooltip;

        if (!showTooltipOnlyWhenOverflow) {
          shouldShowTooltip = true;
        } else if (!hasBoundedWidth) {
          // If width is unbounded, overflow cannot be measured reliably.
          shouldShowTooltip = true;
        } else {
          final painter = TextPainter(
            text: TextSpan(text: text, style: effectiveStyle),
            maxLines: maxLines,
            textDirection: textDirection,
            textAlign: textAlign ?? TextAlign.start,
            locale: locale,
            textScaler: textScaler,
          )..layout(maxWidth: constraints.maxWidth);

          shouldShowTooltip = painter.didExceedMaxLines;
        }

        if (!shouldShowTooltip) return textWidget;

        return Tooltip(
          message: text,
          triggerMode: TooltipTriggerMode.longPress,
          preferBelow: true,
          waitDuration: Duration.zero,
          child: textWidget,
        );
      },
    );
  }
}
