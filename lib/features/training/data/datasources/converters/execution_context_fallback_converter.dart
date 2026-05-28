import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../domain/entities/execution_context_fallback.dart';

class ExecutionContextFallbackConverter
    extends TypeConverter<ExecutionContextFallback?, String?> {
  const ExecutionContextFallbackConverter();

  @override
  ExecutionContextFallback? fromSql(String? fromDb) {
    if (fromDb == null || fromDb.isEmpty) return null;
    final decoded = jsonDecode(fromDb);
    if (decoded is! Map<String, dynamic>) return null;
    return ExecutionContextFallback.fromJson(decoded);
  }

  @override
  String? toSql(ExecutionContextFallback? value) {
    if (value == null) return null;
    return jsonEncode(value.toJson());
  }
}
