import 'package:flutter/material.dart';

import '../../../../core/theme/athlos_durations.dart';
import 'expandable_fab.dart';

/// Expandable FAB with Chiron, manual-create, and optional draft-start actions.
class ExpandableWorkoutFab extends StatefulWidget {
  final String chironLabel;
  final String createManualLabel;
  final VoidCallback onChiron;
  final VoidCallback onCreateManual;
  final String? startDraftLabel;
  final VoidCallback? onStartDraft;
  final Object? heroTag;

  const ExpandableWorkoutFab({
    required this.chironLabel,
    required this.createManualLabel,
    required this.onChiron,
    required this.onCreateManual,
    this.startDraftLabel,
    this.onStartDraft,
    this.heroTag,
    super.key,
  });

  @override
  State<ExpandableWorkoutFab> createState() => _ExpandableWorkoutFabState();
}

class _ExpandableWorkoutFabState extends State<ExpandableWorkoutFab> {
  bool _expanded = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  void _onAction(VoidCallback action) {
    action();
    _toggle();
  }

  List<ExpandableFabAction> get _actions => [
    ExpandableFabAction(
      icon: Icons.auto_awesome,
      label: widget.chironLabel,
      onPressed: widget.onChiron,
    ),
    ExpandableFabAction(
      icon: Icons.edit_note,
      label: widget.createManualLabel,
      onPressed: widget.onCreateManual,
    ),
    if (widget.startDraftLabel != null && widget.onStartDraft != null)
      ExpandableFabAction(
        icon: Icons.play_circle_outline,
        label: widget.startDraftLabel!,
        onPressed: widget.onStartDraft!,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ExpandableFabMenu(
          expanded: _expanded,
          actions: _actions,
          onActionSelected: _onAction,
        ),
        FloatingActionButton(
          heroTag: widget.heroTag ?? 'catalog_fab',
          onPressed: _toggle,
          tooltip: _expanded ? '' : widget.createManualLabel,
          child: AnimatedRotation(
            turns: _expanded ? 0.125 : 0,
            duration: AthlosDurations.normal,
            curve: Curves.easeInOut,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
