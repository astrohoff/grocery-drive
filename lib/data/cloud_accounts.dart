import 'dart:convert';
import 'dart:io';

import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'cloud_store.dart';
import 'google_drive_store.dart';
import 'loopback_oauth.dart';
import 'onedrive_store.dart';
import 'refresh_token.dart';

class CloudAccounts {
  CloudAccounts({FlutterAppAuth? auth, FlutterSecureStorage? storage})
    : _auth = auth ?? const FlutterAppAuth(),
      _storage = storage ?? const FlutterSecureStorage();

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

  final FlutterAppAuth _auth;
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
    final _Session session;
    try {
      session = Platform.isAndroid
          ? await _androidSignIn(name)
          : await _windowsSignIn(name);
    } on FlutterAppAuthUserCancelledException {
      throw SignInCancelled();
    }
    if (session.refreshToken.isEmpty) {
      throw CloudException('$name did not return a refresh token');
    }
    await _storage.write(key: '$name.refresh', value: session.refreshToken);
    await _storage.write(key: 'provider', value: name);
    await _writeSecretRefresh(name, session.refreshToken);
    _remember(name, session.accessToken, session.expiresAt);
  }

  Future<void> signOut() async {
    final name = await provider();
    if (name != null) await _storage.delete(key: '$name.refresh');
    await _storage.delete(key: 'provider');
    _access = null;
    _accessUntil = null;
    _accessProvider = null;
  }

  Future<_Session> _androidSignIn(String name) async {
    final result = await _auth.authorizeAndExchangeCode(_request(name));
    return _Session(
      accessToken: result.accessToken ?? '',
      refreshToken: result.refreshToken ?? '',
      expiresAt: result.accessTokenExpirationDateTime,
    );
  }

  Future<_Session> _windowsSignIn(String name) async {
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
      redirectUri: _redirect(),
      scopes: google ? _googleScopes : _microsoftScopes,
      clientSecret: secret,
      extraParameters: google
          ? const {'access_type': 'offline', 'prompt': 'consent'}
          : const {},
    );
    return _Session(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresAt: tokens.expiresAt,
    );
  }

  AuthorizationTokenRequest _request(String name) {
    final secret = googleDesktopSecret.isEmpty ? null : googleDesktopSecret;
    if (name == 'google') {
      return AuthorizationTokenRequest(
        googleClientId,
        _redirect(),
        issuer: 'https://accounts.google.com',
        scopes: _googleScopes,
        clientSecret: secret,
        promptValues: const ['consent'],
        additionalParameters: const {'access_type': 'offline'},
        allowInsecureConnections: !Platform.isAndroid,
      );
    }
    return AuthorizationTokenRequest(
      microsoftClientId,
      _redirect(),
      issuer: 'https://login.microsoftonline.com/common/v2.0',
      scopes: _microsoftScopes,
      allowInsecureConnections: !Platform.isAndroid,
    );
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
      if (Platform.isAndroid) {
        return await _androidAccessToken(name, refresh);
      }
      return await _windowsAccessToken(name, refresh);
    } on CloudException {
      rethrow;
    } catch (error) {
      throw CloudException('$error');
    }
  }

  Future<String> _windowsAccessToken(String name, String refresh) async {
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

  Future<String> _androidAccessToken(String name, String refresh) async {
    final secret = name == 'google' && googleDesktopSecret.isNotEmpty
        ? googleDesktopSecret
        : null;
    final response = await _auth.token(
      TokenRequest(
        name == 'google' ? googleClientId : microsoftClientId,
        _redirect(),
        issuer: name == 'google'
            ? 'https://accounts.google.com'
            : 'https://login.microsoftonline.com/common/v2.0',
        refreshToken: refresh,
        clientSecret: secret,
        allowInsecureConnections: !Platform.isAndroid,
      ),
    );
    final access = response.accessToken ?? '';
    if (access.isEmpty) {
      throw CloudException('$name did not return an access token');
    }
    await _storeRefresh(name, response.refreshToken);
    _remember(name, access, response.accessTokenExpirationDateTime);
    return access;
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

  String _redirect() {
    if (Platform.isAndroid) return 'com.astrohoff.grocerydrive:/oauthredirect';
    return 'http://localhost:8484';
  }
}

class _Session {
  const _Session({
    required this.accessToken,
    required this.refreshToken,
    this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime? expiresAt;
}
