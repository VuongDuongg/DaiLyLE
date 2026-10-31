class SupabaseConfig {
  SupabaseConfig._();

  // Replace with your real Supabase Project URL & Anon Key from:
  // Supabase Dashboard -> Project Settings -> API
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://demo-dailyle.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRlbW8tZGFpbHlsZSIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzAwMDAwMDAwLCJleHAiOjIwMDAwMDAwMDB9.signature_placeholder',
  );

  /// Check whether Supabase is configured with real credentials or running in local mock/offline mode
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('demo-dailyle') &&
      !supabaseAnonKey.contains('signature_placeholder');
}
