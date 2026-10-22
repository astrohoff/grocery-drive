import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/data/cloud_store.dart';
import 'package:grocery_drive/data/google_drive_store.dart';
import 'package:http/http.dart' as http;

void main() {
  test('read returns the file text and the content revision', () async {
    final client = _QueueClient([
      _response(200, '- [ ] apples\n'),
      _response(200, '{"headRevisionId":"rev-4","version":"9"}'),
    ]);
    final store = _store(client);

    final body = await store.read('file-id');

    expect(body.text, '- [ ] apples\n');
    expect(body.etag, 'rev-4');
    expect(client.sent[1].url.query, 'fields=headRevisionId');
  });

  test('read fails when drive omits the content revision', () async {
    final client = _QueueClient([
      _response(200, '- [ ] apples\n'),
      _response(200, '{"version":"9"}'),
    ]);
    final store = _store(client);
    Object? thrown;
    try {
      await store.read('file-id');
    } on CloudException catch (error) {
      thrown = error.message;
    }
    expect(thrown, 'Google Drive did not return a revision');
  });

  test('write refuses when the content revision changed', () async {
    final client = _QueueClient([
      _response(200, '{"headRevisionId":"rev-5","version":"rev-4"}'),
    ]);
    final store = _store(client);
    Object? thrown;
    try {
      await store.write('file-id', '- [ ] apples\n', 'rev-4');
    } on CloudConflict catch (error) {
      thrown = error.message;
    }
    expect(thrown, 'conflict');
    expect(client.sent.map((request) => request.method).toList(), ['GET']);
  });

  test('write stores the text when the content revision matches', () async {
    final client = _QueueClient([
      _response(200, '{"headRevisionId":"rev-4","version":"9"}'),
      _response(200, ''),
      _response(200, '{"headRevisionId":"rev-6","version":"11"}'),
    ]);
    final store = _store(client);

    final etag = await store.write('file-id', '- [ ] apples\n', 'rev-4');

    expect(etag, 'rev-6');
    final patch = client.sent[1];
    expect(patch.method, 'PATCH');
    expect(patch.body, '- [ ] apples\n');
  });

  test('useFolder rejects an id drive does not have', () async {
    final client = _QueueClient([_response(404, '{}')]);
    final store = _store(client);
    Object? thrown;
    try {
      await store.useFolder('other-account');
    } on CloudException catch (error) {
      thrown = error.message;
    }
    expect(thrown, 'missing folder');
  });
}

GoogleDriveStore _store(_QueueClient client) {
  return GoogleDriveStore(accessToken: () async => 'token', client: client);
}

http.Response _response(int status, String body) {
  return http.Response(
    body,
    status,
    headers: {'content-type': 'application/json'},
  );
}

class _QueueClient extends http.BaseClient {
  _QueueClient(this._responses);

  final List<http.Response> _responses;
  final List<http.Request> sent = [];
  var _index = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final recorded = http.Request(request.method, request.url);
    recorded.bodyBytes = await request.finalize().toBytes();
    sent.add(recorded);
    final response = _responses[_index++];
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
