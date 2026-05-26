/// Parses a decimal from user input (comma or dot as separator).
double? tryParseProfileDecimal(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}
