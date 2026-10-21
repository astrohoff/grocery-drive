import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/data/loopback_oauth.dart';

void main() {
  test('sign-in redirect is the loopback address both providers accept', () {
    expect(oauthRedirectUri, 'http://localhost:8484');
  });
}
