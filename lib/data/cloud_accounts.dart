import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cloud_store.dart';
import 'google_drive_store.dart';
import 'google_scope.dart';
import 'loopback_oauth.dart';
import 'onedrive_store.dart';
import 'refresh_token.dart';

class CloudAccounts {
  CloudAccounts({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const microsoftClientId = String.fromEnvironment(
    'MICROSOFT_CLIENT_ID',
  );
  static const googleDesktopSecret = String.fromEnvironment(
    'GOOGLE_DESKTOP_SECRET',
  );

  static const _googleScopes = [
    'openid',
    'https://www.googleapis.com/auth/drive',
  ];
  static const _microsoftScopes = [
    'openid',
    'offline_access',
    'Files.ReadWrite',
    'User.Read',
  ];

  final FlutterSecureStorage _storage;
  String? _access;
  DateTime? _accessUntil;
  String? _accessProvider;

  Future<String?> provider() => _storage.read(key: 'provider');

  Future<CloudStore?> openStore() async {
    final name = await provider();
    if (name == 'google') {
      return GoogleDriveStore(accessToken: () => _accessToken('google'));
    }
    if (name == 'microsoft') {
      return OneDriveStore(accessToken: () => _accessToken('microsoft'));
    }
    return null;
  }

  Future<void> signIn(String name) async {
    final google = name == 'google';
    final secret = google && googleDesktopSecret.isNotEmpty
        ? googleDesktopSecret
        : null;
    final tokens = await signInWithLoopback(
      authorizationEndpoint: google
          ? 'https://accounts.google.com/o/oauth2/v2/auth'
          : 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize',
      tokenEndpoint: _tokenUrl(name),
      clientId: google ? googleClientId : microsoftClientId,
      redirectUri: oauthRedirectUri,
      scopes: google ? _googleScopes : _microsoftScopes,
      clientSecret: secret,
      extraParameters: google
          ? const {'access_type': 'offline', 'prompt': 'consent'}
          : const {},
    );
    if (google) {
      requireGoogleDriveScope(tokens.scopes, android: false);
    }
    if (tokens.refreshToken.isEmpty) {
      throw CloudException('$name did not return a refresh token');
    }
    await _storage.write(key: '$name.refresh', value: tokens.refreshToken);
    await _storage.write(key: 'provider', value: name);
    await _writeSecretRefresh(name, tokens.refreshToken);
    _remember(name, tokens.accessToken, tokens.expiresAt);
  }

  Future<void> signOut() async {
    final name = await provider();
    if (name != null) await _storage.delete(key: '$name.refresh');
    await _storage.delete(key: 'provider');
    _access = null;
    _accessUntil = null;
    _accessProvider = null;
  }

  Future<String> _accessToken(String name) async {
    final now = DateTime.now().add(const Duration(minutes: 1));
    if (_accessProvider == name &&
        _access != null &&
        _accessUntil != null &&
        _accessUntil!.isAfter(now)) {
      return _access!;
    }
    final refresh = await _storage.read(key: '$name.refresh');
    if (refresh == null || refresh.isEmpty) {
      throw CloudException('not signed in');
    }
    try {
      return await _refreshedAccess(name, refresh);
    } on CloudException {
      rethrow;
    } catch (error) {
      throw CloudException('$error');
    }
  }

  Future<String> _refreshedAccess(String name, String refresh) async {
    final secret = name == 'google' && googleDesktopSecret.isNotEmpty
        ? googleDesktopSecret
        : null;
    final refreshed = await refreshAccessToken(
      tokenUrl: _tokenUrl(name),
      clientId: name == 'google' ? googleClientId : microsoftClientId,
      refreshToken: refresh,
      clientSecret: secret,
      scope: name == 'microsoft' ? _microsoftScopes.join(' ') : null,
    );
    await _storeRefresh(name, refreshed.refreshToken);
    final until = refreshed.expiresInSeconds == null
        ? null
        : DateTime.now().add(Duration(seconds: refreshed.expiresInSeconds!));
    _remember(name, refreshed.accessToken, until);
    return refreshed.accessToken;
  }

  Future<void> _storeRefresh(String name, String? refresh) async {
    if (refresh == null || refresh.isEmpty) return;
    await _storage.write(key: '$name.refresh', value: refresh);
    await _writeSecretRefresh(name, refresh);
  }

  Future<void> _writeSecretRefresh(String name, String refresh) async {
    final filename = name == 'google'
        ? 'secrets/google.json'
        : 'secrets/microsoft.json';
    final file = File(filename);
    if (!file.existsSync()) return;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return;
      final json = Map<String, Object?>.from(decoded);
      json['refresh_token'] = refresh;
      file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(json)}\n',
      );
    } on Object {
      // Sign-in still stands when the gitignored file cannot be updated.
    }
  }

  void _remember(String name, String? access, DateTime? until) {
    _accessProvider = name;
    _access = access;
    _accessUntil = until;
  }

  String _tokenUrl(String name) {
    if (name == 'google') return 'https://oauth2.googleapis.com/token';
    return 'https://login.microsoftonline.com/common/oauth2/v2.0/token';
  }
}
