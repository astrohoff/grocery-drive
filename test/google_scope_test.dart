import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/data/cloud_store.dart';
import 'package:grocery_drive/data/google_scope.dart';

void main() {
  test('a token scope string splits on whitespace', () {
    expect(scopesFromToken(null), const <String>[]);
    expect(scopesFromToken(''), const <String>[]);
    expect(scopesFromToken('openid'), const ['openid']);
    expect(
      scopesFromToken('openid https://www.googleapis.com/auth/drive'),
      const ['openid', 'https://www.googleapis.com/auth/drive'],
    );
  });

  test('windows rejects a google grant that omits drive', () {
    expect(
      _refusal(['openid'], android: false),
      'Google did not grant Drive access. Sign in again and leave the Drive permission checked.',
    );
    expect(
      _refusal(null, android: false),
      'Google did not grant Drive access. Sign in again and leave the Drive permission checked.',
    );
  });

  test('android accepts a matching grant and still requires drive when scopes are listed', () {
    expect(_refusal(null, android: true), '');
    expect(
      _refusal(const [
        'openid',
        'https://www.googleapis.com/auth/drive',
      ], android: true),
      '',
    );
    expect(
      _refusal(const ['openid'], android: true),
      'Google did not grant Drive access. Sign in again and leave the Drive permission checked.',
    );
    expect(
      _refusal(const ['https://www.googleapis.com/auth/drive'], android: false),
      '',
    );
  });
}

String _refusal(List<String>? scopes, {required bool android}) {
  try {
    requireGoogleDriveScope(scopes, android: android);
  } on CloudException catch (error) {
    return error.message;
  }
  return '';
}
