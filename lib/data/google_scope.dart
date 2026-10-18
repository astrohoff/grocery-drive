import 'cloud_store.dart';

const googleDriveScope = 'https://www.googleapis.com/auth/drive';

/// Space-separated `scope` field from a token response. Missing means none.
List<String> scopesFromToken(Object? scope) {
  if (scope is! String || scope.trim().isEmpty) return const [];
  return scope.split(RegExp(r'\s+'));
}

/// Android reports null scopes when the grant matches the request.
/// Windows always has a scope string. An empty list is a refusal.
void requireGoogleDriveScope(List<String>? scopes, {required bool android}) {
  if (android && scopes == null) return;
  final granted = scopes ?? const <String>[];
  if (!granted.contains(googleDriveScope)) {
    throw CloudException(
      'Google did not grant Drive access. Sign in again and leave the Drive permission checked.',
    );
  }
}
