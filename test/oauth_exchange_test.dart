import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/data/loopback_oauth.dart';
import 'package:http/http.dart' as http;

void main() {
  test('the phone posts the token once it is back in front', () async {
    final events = <String>[];
    final tokens = await exchangeAfterForeground(
      deferUntilResumed: true,
      waitUntilResumed: () async {
        events.add('wait');
      },
      exchange: () async {
        events.add('post');
        return const LoopbackTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          scopes: ['https://www.googleapis.com/auth/drive'],
        );
      },
    );
    expect(events, ['wait', 'post']);
    expect(tokens.accessToken, 'access-token');
    expect(tokens.refreshToken, 'refresh-token');
  });

  test('the phone retries a token post that Android aborted', () async {
    final events = <String>[];
    var posts = 0;
    final tokens = await exchangeAfterForeground(
      deferUntilResumed: true,
      waitUntilResumed: () async {
        events.add('wait');
      },
      pauseBeforeRetry: () async {},
      exchange: () async {
        posts += 1;
        events.add('post');
        if (posts == 1) {
          throw http.ClientException('Software caused connection abort');
        }
        return const LoopbackTokens(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          scopes: ['Files.ReadWrite'],
        );
      },
    );
    expect(events, ['wait', 'post', 'post']);
    expect(tokens.refreshToken, 'refresh-token');
  });

  test('a connection abort in the foreground is not retried', () async {
    expect(await _foregroundAbort(), 'post|Software caused connection abort');
  });
}

Future<String> _foregroundAbort() async {
  final events = <String>[];
  try {
    await exchangeAfterForeground(
      deferUntilResumed: false,
      waitUntilResumed: () async {
        events.add('wait');
      },
      exchange: () async {
        events.add('post');
        throw http.ClientException('Software caused connection abort');
      },
    );
  } on http.ClientException catch (error) {
    return '${events.join(',')}|${error.message}';
  }
  return events.join(',');
}
