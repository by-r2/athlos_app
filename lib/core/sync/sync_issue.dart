import 'dart:convert';

/// A persisted record of a sync failure that can be surfaced in the UI.
class SyncIssue {
  final String id;
  final DateTime occurredAtUtc;
  final String tableName;
  final String message;

  const SyncIssue({
    required this.id,
    required this.occurredAtUtc,
    required this.tableName,
    required this.message,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'occurredAtUtc': occurredAtUtc.toIso8601String(),
        'tableName': tableName,
        'message': message,
      };

  static SyncIssue fromJson(Map<String, dynamic> json) => SyncIssue(
        id: json['id'] as String,
        occurredAtUtc: DateTime.parse(json['occurredAtUtc'] as String).toUtc(),
        tableName: json['tableName'] as String,
        message: json['message'] as String,
      );

  static List<SyncIssue> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <SyncIssue>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SyncIssue.fromJson)
        .toList();
  }

  static String encodeList(List<SyncIssue> issues) =>
      jsonEncode(issues.map((e) => e.toJson()).toList());
}

