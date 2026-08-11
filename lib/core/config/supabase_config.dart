/// Supabase connection config. Read from --dart-define, defaulting to the
/// local dev stack (shifted ports — see supabase/config.toml).
///
/// Override at build/run time:
///   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=<anon-key>
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://127.0.0.1:54333',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0',
  );

  /// True when the app was told to talk to Supabase. Offline (no config) → app
  /// runs fully local as before.
  static const bool syncEnabled =
      bool.fromEnvironment('SUPABASE_ENABLED', defaultValue: true);
}
