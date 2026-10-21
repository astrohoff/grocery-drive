import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/data/cloud_store.dart';
import 'package:grocery_drive/data/onedrive_store.dart';
import 'package:http/http.dart' as http;

void main() {
  test('useFolder rejects an id onedrive does not have', () async {
    final client = _QueueClient([_response(404, '')]);
    final store = _store(client);
    Object? thrown;
    try {
      await store.useFolder('other-account');
    } on CloudException catch (error) {
      thrown = error.message;
    }
    expect(thrown, 'missing folder');
  });

  test('useFolder rejects a file id', () async {
    final client = _QueueClient([
      _response(200, '{"id":"file-id","name":"Groceries.md"}'),
    ]);
    final store = _store(client);
    Object? thrown;
    try {
      await store.useFolder('file-id');
    } on CloudException catch (error) {
      thrown = error.message;
    }
    expect(thrown, 'missing folder');
  });
}

OneDriveStore _store(_QueueClient client) {
  return OneDriveStore(accessToken: () async => 'token', client: client);
}

http.Response _response(int status, String body) {
  return http.Response(body, status);
}

class _QueueClient extends http.BaseClient {
  _QueueClient(this._responses);

  final List<http.Response> _responses;
  final sent = <http.Request>[];
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
