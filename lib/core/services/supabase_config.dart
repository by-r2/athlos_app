/// Supabase project configuration.
///
/// Pass via `--dart-define` at build time:
///   flutter run --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// The anon key only grants read access to public catalog tables
/// protected by RLS, so it is safe to embed in the client binary.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

bool get isSupabaseConfigured =>
    supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
