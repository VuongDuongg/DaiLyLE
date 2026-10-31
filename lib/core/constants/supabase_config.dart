class SupabaseConfig {
  SupabaseConfig._();

  // Real Supabase Project URL & Anon Key for Dailyle
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bagyfwoxfzubqlaqmufn.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJhZ3lmd294Znp1YnFsYXFtdWZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTM0Mjc0MDAsImV4cCI6MjEwOTAwMzQwMH0.yfRe4-768J_n7oEMovkQ2jm90SvRxck8-tnuwxv7aBk',
  );

  /// Check whether Supabase is configured with real credentials or running in local mock/offline mode
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      !supabaseUrl.contains('demo-dailyle') &&
      !supabaseAnonKey.contains('signature_placeholder');
}
