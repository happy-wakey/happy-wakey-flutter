import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_state.dart';

final class AuthSessionSnapshot {
  const AuthSessionSnapshot({
    required this.userId,
    required this.email,
    required this.provider,
    required this.accessToken,
    required this.providerToken,
  });

  final String userId;
  final String email;
  final String provider;
  final String accessToken;
  final String providerToken;
}

final class AuthService {
  AuthService(this._client);

  final SupabaseClient? _client;

  bool get configured => _client != null;
  SupabaseClient? get client => _client;

  AuthSessionSnapshot? get currentSession {
    final session = _client?.auth.currentSession;
    final user = session?.user;
    if (session == null || user == null) return null;
    return AuthSessionSnapshot(
      userId: user.id,
      email: user.email ?? '',
      provider: user.appMetadata['provider']?.toString() ?? '',
      accessToken: session.accessToken,
      providerToken: session.providerToken ?? '',
    );
  }

  Stream<AuthSessionSnapshot?> get sessionChanges {
    final client = _client;
    if (client == null) return const Stream.empty();
    return client.auth.onAuthStateChange.map((_) => currentSession);
  }

  Future<void> startLogin(AuthProvider provider) async {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured for this build');
    }
    final oauth = switch (provider) {
      AuthProvider.google => OAuthProvider.google,
      AuthProvider.apple => OAuthProvider.apple,
      AuthProvider.azure => OAuthProvider.azure,
    };
    final scopes = switch (provider) {
      AuthProvider.google =>
        'openid email profile https://www.googleapis.com/auth/calendar.readonly',
      AuthProvider.azure =>
        'openid email profile offline_access Calendars.Read',
      AuthProvider.apple => 'name email',
    };
    final launched = await client.auth.signInWithOAuth(
      oauth,
      redirectTo: kIsWeb
          ? Uri.base.replace(path: '/', query: null, fragment: null).toString()
          : 'com.happywakey.app://login-callback',
      scopes: scopes,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
    if (!launched) throw StateError('The OAuth browser could not be opened');
  }

  Future<void> logout() async => _client?.auth.signOut();
}
