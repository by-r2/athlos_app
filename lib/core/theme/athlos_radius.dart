import 'package:flutter/material.dart';

/// Border radius tokens for consistent rounding across the app.
///
/// Usage: `BorderRadius.circular(AthlosRadius.md)` or `AthlosRadius.smAll`
abstract class AthlosRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double full = 999;

  static final BorderRadius xsAll = BorderRadius.circular(xs);
  static final BorderRadius smAll = BorderRadius.circular(sm);
  static final BorderRadius mdAll = BorderRadius.circular(md);
  static final BorderRadius lgAll = BorderRadius.circular(lg);
  static final BorderRadius fullAll = BorderRadius.circular(full);
}
