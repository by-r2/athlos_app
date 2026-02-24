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

  Workout copyWith({
    int? id,
    String? name,
    String? Function()? description,
    int? Function()? sortOrder,
    bool? isArchived,
    DateTime? createdAt,
  }) =>
      Workout(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description != null ? description() : this.description,
        sortOrder: sortOrder != null ? sortOrder() : this.sortOrder,
        isArchived: isArchived ?? this.isArchived,
        createdAt: createdAt ?? this.createdAt,
      );
}
