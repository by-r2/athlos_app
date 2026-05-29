import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/athlos_spacing.dart';

/// Numeric field for bottom-sheet exercise config (same style as workout builder).
class AdHocConfigNumberField extends StatefulWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final String? suffix;

  const AdHocConfigNumberField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix,
    super.key,
  });

  @override
  State<AdHocConfigNumberField> createState() => _AdHocConfigNumberFieldState();
}

class _AdHocConfigNumberFieldState extends State<AdHocConfigNumberField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(AdHocConfigNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value.toString()) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.next,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        suffixText: widget.suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AthlosSpacing.xs,
          vertical: AthlosSpacing.sm,
        ),
      ),
      onChanged: (text) {
        final parsed = int.tryParse(text);
        if (parsed != null && parsed > 0) widget.onChanged(parsed);
      },
    );
  }
}

/// Two-column row of [AdHocConfigNumberField] widgets.
class AdHocConfigMetricRow extends StatelessWidget {
  final List<Widget> children;

  const AdHocConfigMetricRow({required this.children, super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: AthlosSpacing.sm),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// Section title with optional leading icon.
class AdHocConfigSectionLabel extends StatelessWidget {
  final String label;
  final IconData? icon;

  const AdHocConfigSectionLabel(this.label, {this.icon, super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AthlosSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: AthlosSpacing.xs),
          ],
          Text(
            label,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
