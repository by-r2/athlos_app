import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/last_module_provider.dart';
import '../../../../core/sync/sync_issue.dart';
import '../../../../core/sync/sync_issue_prefs.dart';

final syncIssueCenterProvider = FutureProvider.autoDispose<List<SyncIssue>>((
  ref,
) async {
  final prefs = ref.watch(sharedPreferencesProvider);
  final store = SyncIssuePrefs(prefs);
  return store.getAll();
});

