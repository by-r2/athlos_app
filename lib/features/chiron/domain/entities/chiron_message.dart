enum ChironRole { user, assistant }

class ChironMessage {
  final ChironRole role;
  final String content;
  final DateTime createdAt;

  const ChironMessage({
    required this.role,
    required this.content,
    required this.createdAt,
  });

  ChironMessage copyWith({String? content}) => ChironMessage(
        role: role,
        content: content ?? this.content,
        createdAt: createdAt,
      );
}
