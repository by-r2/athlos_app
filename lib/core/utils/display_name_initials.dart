/// Derives one or two uppercase initials from a display name.
///
/// - Multiple words: first character of the first word + first character of the
///   last word (e.g. "Rafael Silva" → "RS").
/// - Single word: first character only (e.g. "Rafael" → "R").
/// - Empty or whitespace-only: `null`.
String? displayNameInitials(String? displayName) {
  if (displayName == null) return null;

  final parts = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return null;

  String firstChar(String word) {
    final runes = word.runes;
    if (runes.isEmpty) return '';
    return String.fromCharCode(runes.first).toUpperCase();
  }

  if (parts.length == 1) {
    final initial = firstChar(parts.first);
    return initial.isEmpty ? null : initial;
  }

  final first = firstChar(parts.first);
  final last = firstChar(parts.last);
  if (first.isEmpty && last.isEmpty) return null;
  if (last.isEmpty) return first.isEmpty ? null : first;
  if (first.isEmpty) return last;
  return '$first$last';
}
