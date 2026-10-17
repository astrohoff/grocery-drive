import 'dart:convert';

import 'package:http/http.dart' as http;

class RefreshedAccess {
  const RefreshedAccess({
    required this.accessToken,
    this.refreshToken,
    this.expiresInSeconds,
  });

  final String accessToken;
  final String? refreshToken;
  final int? expiresInSeconds;
}

Future<RefreshedAccess> refreshAccessToken({
  required String tokenUrl,
  required String clientId,
  required String refreshToken,
  String? clientSecret,
  String? scope,
}) async {
  final response = await http.post(
    Uri.parse(tokenUrl),
    body: {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': clientId,
      if (clientSecret != null && clientSecret.isNotEmpty)
        'client_secret': clientSecret,
      if (scope != null && scope.isNotEmpty) 'scope': scope,
    },
  );
  if (response.statusCode != 200) {
    throw StateError('Token refresh failed (${response.statusCode}).');
  }
  return _access(response.body);
}

RefreshedAccess _access(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw StateError('Token refresh did not return an access token.');
  }
  final access = decoded['access_token'] as String? ?? '';
  if (access.isEmpty) {
    throw StateError('Token refresh did not return an access token.');
  }
  final refresh = decoded['refresh_token'] as String?;
  final expires = decoded['expires_in'];
  return RefreshedAccess(
    accessToken: access,
    refreshToken: refresh,
    expiresInSeconds: expires is num ? expires.toInt() : null,
  );
}
