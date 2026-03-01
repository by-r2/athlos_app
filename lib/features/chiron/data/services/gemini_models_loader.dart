import 'dart:convert';

import 'package:http/http.dart' as http;

/// Loads available Gemini model IDs from the API so we don't depend on
/// hardcoded version numbers. Caches the result to avoid repeated requests.
class GeminiModelsLoader {
  GeminiModelsLoader({
    required String apiKey,
    Duration cacheTtl = const Duration(hours: 24),
  })  : _apiKey = apiKey,
        _cacheTtl = cacheTtl;

  final String _apiKey;
  final Duration _cacheTtl;

  List<String>? _cachedIds;
  DateTime? _cachedAt;

  static const _listModelsUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Returns model IDs suitable for chat (generateContent), preferring
  /// Flash / lighter models first. Uses cache when valid.
  /// On API error returns null so caller can use a static fallback list.
  Future<List<String>?> getModelIdsForChat() async {
    if (_cachedIds != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cachedIds;
    }

    try {
      final uri = Uri.parse(_listModelsUrl).replace(
        queryParameters: {'key': _apiKey, 'pageSize': '100'},
      );
      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('List models timeout'),
      );

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>?;
      final models = json?['models'] as List<dynamic>?;
      if (models == null || models.isEmpty) return null;

      final ids = <String>[];
      for (final m in models) {
        if (m is! Map<String, dynamic>) continue;
        final name = m['name'] as String?;
        final methods =
            m['supportedGenerationMethods'] as List<dynamic>?;
        if (name == null ||
            name.isEmpty ||
            methods == null ||
            !methods.any((e) => e.toString().contains('generateContent'))) {
          continue;
        }
        final id = name.startsWith('models/') ? name.substring(7) : name;
        if (id.isNotEmpty) ids.add(id);
      }

      if (ids.isEmpty) return null;

      _sortByPreference(ids);
      _cachedIds = ids;
      _cachedAt = DateTime.now();
      return ids;
    } catch (_) {
      return null;
    }
  }

  /// Prefer flash over pro, and names containing "latest" first.
  void _sortByPreference(List<String> ids) {
    ids.sort((a, b) {
      final aLatest = a.contains('latest') ? 0 : 1;
      final bLatest = b.contains('latest') ? 0 : 1;
      if (aLatest != bLatest) return aLatest.compareTo(bLatest);
      final aFlash = a.contains('flash') ? 0 : 1;
      final bFlash = b.contains('flash') ? 0 : 1;
      if (aFlash != bFlash) return aFlash.compareTo(bFlash);
      return a.compareTo(b);
    });
  }

  void invalidateCache() {
    _cachedIds = null;
    _cachedAt = null;
  }
}
