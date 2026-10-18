import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'cloud_store.dart';
import 'google_scope.dart';

class SignInCancelled implements Exception {}

class LoopbackTokens {
  const LoopbackTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.scopes,
    this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final List<String> scopes;
  final DateTime? expiresAt;
}

Future<LoopbackTokens> signInWithLoopback({
  required String authorizationEndpoint,
  required String tokenEndpoint,
  required String clientId,
  required String redirectUri,
  required List<String> scopes,
  String? clientSecret,
  Map<String, String> extraParameters = const {},
}) async {
  final redirect = Uri.parse(redirectUri);
  final port = redirect.port;
  final verifier = _verifier();
  final state = _verifier();
  final authorize = Uri.parse(authorizationEndpoint).replace(
    queryParameters: {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': scopes.join(' '),
      'code_challenge': _challenge(verifier),
      'code_challenge_method': 'S256',
      'state': state,
      ...extraParameters,
    },
  );

  final HttpServer server;
  try {
    server = await _bind(port);
  } on SocketException {
    throw CloudException(
      'Port $port is already in use. Close the other sign-in window and try again.',
    );
  }

  try {
    await _openBrowser(authorize);
    await for (final request in server.timeout(const Duration(minutes: 5))) {
      final params = request.uri.queryParameters;
      if (!params.containsKey('code') && !params.containsKey('error')) {
        request.response.statusCode = HttpStatus.noContent;
        await request.response.close();
        continue;
      }
      final error = params['error'];
      final code = params['code'];
      final returned = params['state'];
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.set(HttpHeaders.contentTypeHeader, 'text/html; charset=utf-8')
        ..write(
          '<!DOCTYPE html><html><body><p>You can close this window.</p></body></html>',
        );
      await request.response.close();
      if (error == 'access_denied') throw SignInCancelled();
      if (error != null && error.isNotEmpty) {
        throw CloudException('Sign-in failed ($error).');
      }
      if (code == null || code.isEmpty || returned != state) {
        throw CloudException('Sign-in did not return an authorization code.');
      }
      return await _exchange(
        tokenEndpoint: tokenEndpoint,
        clientId: clientId,
        clientSecret: clientSecret,
        code: code,
        redirectUri: redirectUri,
        verifier: verifier,
      );
    }
  } on TimeoutException {
    throw CloudException('Sign-in timed out.');
  } finally {
    await server.close(force: true);
  }
  throw CloudException('Sign-in timed out.');
}

Future<HttpServer> _bind(int port) async {
  try {
    return await HttpServer.bind(
      InternetAddress.loopbackIPv6,
      port,
      v6Only: false,
    );
  } on SocketException {
    return await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  }
}

Future<void> _openBrowser(Uri url) async {
  final result = await Process.run('rundll32', [
    'url.dll,FileProtocolHandler',
    url.toString(),
  ]);
  if (result.exitCode != 0) {
    throw CloudException('Could not open the browser.');
  }
}

Future<LoopbackTokens> _exchange({
  required String tokenEndpoint,
  required String clientId,
  required String? clientSecret,
  required String code,
  required String redirectUri,
  required String verifier,
}) async {
  final response = await http.post(
    Uri.parse(tokenEndpoint),
    body: {
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'client_id': clientId,
      'code_verifier': verifier,
      if (clientSecret != null && clientSecret.isNotEmpty)
        'client_secret': clientSecret,
    },
  );
  if (response.statusCode != 200) {
    throw CloudException('Sign-in failed (${response.statusCode}).');
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map) {
    throw CloudException('Sign-in did not return an access token.');
  }
  final access = decoded['access_token'] as String? ?? '';
  final refresh = decoded['refresh_token'] as String? ?? '';
  if (access.isEmpty) {
    throw CloudException('Sign-in did not return an access token.');
  }
  final expires = decoded['expires_in'];
  final expiresAt = expires is num
      ? DateTime.now().add(Duration(seconds: expires.toInt()))
      : null;
  return LoopbackTokens(
    accessToken: access,
    refreshToken: refresh,
    scopes: scopesFromToken(decoded['scope']),
    expiresAt: expiresAt,
  );
}

String _verifier() {
  const alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
  final random = Random.secure();
  return List.generate(
    64,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}

String _challenge(String verifier) {
  final digest = sha256.convert(utf8.encode(verifier));
  return base64Url.encode(digest.bytes).replaceAll('=', '');
}
