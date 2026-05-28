import 'package:flutter/material.dart';

import '../../../../core/widgets/layout/athlos_section.dart';

/// Kleos section — reuses [AthlosSection] for header layout.
class KleosSection extends StatelessWidget {
  const KleosSection({
    super.key,
    required this.title,
    required this.child,
    this.hint,
    this.icon,
  });

  final String title;
  final String? hint;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AthlosSection(
      title: title,
      subtitle: hint,
      icon: icon,
      child: child,
    );
  }
}
