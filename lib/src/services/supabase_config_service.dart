import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_config.dart';

final class SupabaseConfigService {
  SupabaseConfigService(this._client);
  final SupabaseClient? _client;

  bool get configured => _client != null;

  Future<OnboardingConfig?> fetchOnboarding() async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return null;
    final value = await client
        .from('user_onboarding_state')
        .select('completed,current_step,step_index,updated_at')
        .eq('user_id', user.id)
        .maybeSingle();
    return value == null ? null : OnboardingConfig.fromJson(value);
  }

  Future<void> saveOnboarding(OnboardingConfig onboarding) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    await client.from('user_onboarding_state').upsert({
      'user_id': user.id,
      ...onboarding.toJson(),
    }, onConflict: 'user_id');
  }

  Future<void> saveConfig(AppConfig config) async {
    final client = _client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    final safe = config.toJson()..remove('onboarding');
    await client.from('user_config').upsert({
      'user_id': user.id,
      'config': safe,
    }, onConflict: 'user_id');
  }
}
