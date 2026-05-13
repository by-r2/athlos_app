/// Training focus for a program (mesocycle).
enum ProgramFocus {
  hypertrophy,
  strength,
  endurance,
  custom;

  /// Suggested default rest in seconds for each focus.
  int? get suggestedRestSeconds => switch (this) {
    hypertrophy => 90,
    strength => 180,
    endurance => 45,
    custom => null,
  };
}
