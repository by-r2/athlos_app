/// How a workout execution session relates to the program cycle.
enum SessionKind {
  /// Started from a saved workout template in the program cycle.
  planned,

  /// Built during execution (treino improvisado).
  adHoc,
}
