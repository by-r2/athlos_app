/// A workout is a named collection of exercises with their configurations.
class Workout {
  final int id;
  final String name;
  final String? description;
  final int? sortOrder;
  final bool isArchived;
  final DateTime createdAt;

  const Workout({
    required this.id,
    required this.name,
    this.description,
    this.sortOrder,
    this.isArchived = false,
    required this.createdAt,
  });
}
