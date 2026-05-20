import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/services/supabase_config.dart';

/// Shared Supabase access for training cloud sync.
class TrainingRemoteClient {
  supabase.SupabaseClient? get client =>
      isSupabaseConfigured ? supabase.Supabase.instance.client : null;

  String? get currentUserId => client?.auth.currentUser?.id;
}
