/// A workout is a named collection of exercises with their configurations.
class Workout {
  final String id;
  final String name;
  final String? description;
  final int? sortOrder;
  final bool isArchived;

  /// Ephemeral template created for in-session building; hidden from lists.
  final bool isDraft;

  final DateTime createdAt;

  const Workout({
    required this.id,
    required this.name,
    this.description,
    this.sortOrder,
    this.isArchived = false,
    this.isDraft = false,
    required this.createdAt,
  });

  Workout copyWith({
    String? id,
    String? name,
    String? Function()? description,
    int? Function()? sortOrder,
    bool? isArchived,
    bool? isDraft,
    DateTime? createdAt,
  }) => Workout(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description != null ? description() : this.description,
    sortOrder: sortOrder != null ? sortOrder() : this.sortOrder,
    isArchived: isArchived ?? this.isArchived,
    isDraft: isDraft ?? this.isDraft,
    createdAt: createdAt ?? this.createdAt,
  );
}
