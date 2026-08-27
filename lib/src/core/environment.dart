final class Environment {
  const Environment._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const finnhubApiKey = String.fromEnvironment('FINNHUB_API_KEY');
  static const newsApiKey = String.fromEnvironment('NEWSAPI_KEY');
  static const platformUrl = String.fromEnvironment('HAPPY_WAKEY_PLATFORM_URL');
  static const sharedAuthUrl = String.fromEnvironment(
    'HAPPY_WAKEY_SHARED_AUTH_URL',
  );
  static const gatewayUrl = String.fromEnvironment('HAPPY_WAKEY_GATEWAY_URL');

  static bool get supabaseConfigured =>
      Uri.tryParse(supabaseUrl)?.hasScheme == true &&
      supabaseAnonKey.isNotEmpty;
}
