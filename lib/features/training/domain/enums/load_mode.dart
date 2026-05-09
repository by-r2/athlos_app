/// How an exercise's load is interpreted when computing volume and 1RM.
///
/// Decoupled from the equipment used so that a single catalog entry (e.g. "Dip")
/// can be performed in multiple modes — bodyweight on parallels, on a dip
/// machine with external load, or on an assisted machine — without forcing
/// the catalog to duplicate the row per equipment.
///
/// The resolved mode for a given set comes from a cascade:
/// `ExecutionSet.loadModeOverride` (rare) → `WorkoutExercise.loadModeOverride`
/// (set during workout planning) → `Exercise.defaultLoadMode` (catalog default).
enum LoadMode {
  /// Body weight is part of the load. The user enters extra ballast (cinto,
  /// colete, mochila) as a positive value; null/0 means pure bodyweight.
  ///
  /// `effectiveLoad = (bodyWeight × bodyweightLoadFactor) + addedWeight`
  bodyweight,

  /// Only the externally moved weight counts. Used for free weights, machines,
  /// cables, and any exercise where body weight is supported (bench press,
  /// barbell squat, lat pulldown, etc.).
  ///
  /// `effectiveLoad = setWeight`
  weighted,

  /// Body weight minus an external assistance (band, machine counterweight,
  /// spotter pin). The user enters the assistance as a positive value.
  ///
  /// `effectiveLoad = (bodyWeight × bodyweightLoadFactor) − assistedWeight`
  assisted,
}
