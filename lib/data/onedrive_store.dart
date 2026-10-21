import 'dart:convert';

import 'package:http/http.dart' as http;

import 'cloud_store.dart';

class OneDriveStore implements CloudStore {
  OneDriveStore({required this.accessToken, http.Client? client})
    : _client = client ?? http.Client();

  final Future<String> Function() accessToken;
  final http.Client _client;
  String? _folderId;

  static const _root = 'https://graph.microsoft.com/v1.0';

  @override
  Future<String> ensureRootFolder() async {
    final selected = _folderId;
    if (selected != null) return selected;
    final folder = await createRootFolder('Groceries');
    _folderId = folder.id;
    return folder.id;
  }

  @override
  Future<List<CloudFolder>> listRootFolders() async {
    final folders = <CloudFolder>[];
    String? page = '$_root/me/drive/root/children';
    for (var i = 0; i < 20 && page != null; i++) {
      final body = await _json('GET', page);
      for (final raw in body['value'] as List? ?? const []) {
        final folder = _folderFromItem(raw);
        if (folder != null) folders.add(folder);
      }
      page = body['@odata.nextLink'] as String?;
    }
    folders.sort((a, b) => a.name.compareTo(b.name));
    return folders;
  }

  @override
  Future<CloudFolder> createRootFolder(String name) async {
    final existing = await _folderNamed(name);
    if (existing != null) return existing;
    try {
      final created = await _json('POST', '$_root/me/drive/root/children', {
        'name': name,
        'folder': <String, Object>{},
        '@microsoft.graph.conflictBehavior': 'fail',
      });
      final folder = _folderFromItem(created);
      if (folder == null) {
        throw CloudException('OneDrive did not return a folder id');
      }
      return folder;
    } on CloudException catch (error) {
      if (error.message != 'OneDrive 409') rethrow;
      final again = await _folderNamed(name);
      if (again == null) rethrow;
      return again;
    }
  }

  @override
  Future<void> useFolder(String id) async {
    final Map item;
    try {
      item = await _json(
        'GET',
        '$_root/me/drive/items/$id?select=id,name,folder',
      );
    } on CloudException catch (error) {
      if (error.message == 'OneDrive 404') {
        throw CloudException('missing folder');
      }
      rethrow;
    }
    if (_folderFromItem(item) == null) {
      throw CloudException('missing folder');
    }
    _folderId = id;
  }

  @override
  Future<List<CloudFile>> listMarkdownFiles() async {
    await ensureRootFolder();
    final files = <CloudFile>[];
    String? url = '$_root/me/drive/items/$_folderId/children';
    for (var i = 0; i < 20 && url != null; i++) {
      final page = await _json('GET', url);
      for (final raw in page['value'] as List? ?? const []) {
        final item = raw as Map;
        final name = item['name'] as String? ?? '';
        final id = item['id'] as String?;
        if (id == null || !name.toLowerCase().endsWith('.md')) continue;
        final modified = DateTime.tryParse(
          item['lastModifiedDateTime'] as String? ?? '',
        );
        files.add(
          CloudFile(
            id: id,
            name: name,
            modified: modified ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
      }
      url = page['@odata.nextLink'] as String?;
    }
    files.sort((a, b) => a.name.compareTo(b.name));
    return files;
  }

  @override
  Future<CloudText> read(String fileId) async {
    final item = await _json(
      'GET',
      '$_root/me/drive/items/$fileId?select=eTag',
    );
    final etag = item['eTag'] as String? ?? '';
    if (etag.isEmpty) throw CloudException('OneDrive did not return an etag');
    final text = await _download('$_root/me/drive/items/$fileId/content');
    return CloudText(text: text, etag: etag);
  }

  @override
  Future<String> write(String fileId, String text, String? ifMatchEtag) async {
    final item = await _send(
      'PUT',
      '$_root/me/drive/items/$fileId/content',
      body: utf8.encode(text),
      contentType: 'text/plain; charset=utf-8',
      ifMatch: ifMatchEtag,
    );
    final json = _decode(item.body);
    final etag = json['eTag'] as String? ?? '';
    if (etag.isEmpty) throw CloudException('OneDrive did not return an etag');
    return etag;
  }

  @override
  Future<CloudFile> createMarkdown(String name) async {
    await ensureRootFolder();
    final folderId = _folderId;
    if (folderId == null) {
      throw CloudException('OneDrive did not return a folder id');
    }
    final filename = _filename(name);
    final item = await _send(
      'PUT',
      '$_root/me/drive/items/$folderId:/${Uri.encodeComponent(filename)}:/content',
      body: const [],
      contentType: 'text/plain; charset=utf-8',
    );
    final json = _decode(item.body);
    final id = json['id'] as String?;
    if (id == null) throw CloudException('OneDrive did not return a file id');
    return CloudFile(
      id: id,
      name: json['name'] as String? ?? filename,
      modified:
          DateTime.tryParse(json['lastModifiedDateTime'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  Future<void> rename(String fileId, String name) async {
    await _json('PATCH', '$_root/me/drive/items/$fileId', {
      'name': _filename(name),
    });
  }

  @override
  Future<void> delete(String fileId) async {
    await _send('DELETE', '$_root/me/drive/items/$fileId');
  }

  CloudFolder? _folderFromItem(Object? raw) {
    if (raw is! Map) return null;
    if (raw['folder'] == null) return null;
    final id = raw['id'] as String?;
    final name = raw['name'] as String?;
    if (id == null || name == null) return null;
    return CloudFolder(id: id, name: name);
  }

  Future<CloudFolder?> _folderNamed(String name) async {
    String? page = '$_root/me/drive/root/children';
    for (var i = 0; i < 20 && page != null; i++) {
      final body = await _json('GET', page);
      for (final raw in body['value'] as List? ?? const []) {
        final folder = _folderFromItem(raw);
        if (folder != null && folder.name == name) return folder;
      }
      page = body['@odata.nextLink'] as String?;
    }
    return null;
  }

  Future<Map> _json(String method, String url, [Map? body]) async {
    final response = await _send(
      method,
      url,
      body: body == null ? null : utf8.encode(jsonEncode(body)),
      contentType: body == null ? null : 'application/json',
    );
    if (response.body.isEmpty) return const {};
    return _decode(response.body);
  }

  Map _decode(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map) return json;
    } on FormatException {
      // The message below covers a body that is not JSON.
    }
    throw CloudException('OneDrive returned invalid JSON');
  }

  Future<String> _download(String url) async {
    final token = await accessToken();
    final request = http.Request('GET', Uri.parse(url));
    request.followRedirects = false;
    request.headers['Authorization'] = 'Bearer $token';
    final streamed = await _guard(() => _client.send(request));
    if (streamed.statusCode >= 300 && streamed.statusCode < 400) {
      final location = streamed.headers['location'];
      await streamed.stream.drain<void>();
      if (location == null) {
        throw CloudException('OneDrive download missing location');
      }
      final downloaded = await _guard(() => _client.get(Uri.parse(location)));
      if (downloaded.statusCode < 200 || downloaded.statusCode >= 300) {
        throw CloudException('OneDrive ${downloaded.statusCode}');
      }
      return downloaded.body;
    }
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudException('OneDrive ${response.statusCode}');
    }
    return response.body;
  }

  Future<http.Response> _send(
    String method,
    String url, {
    List<int>? body,
    String? contentType,
    String? ifMatch,
  }) async {
    final token = await accessToken();
    final request = http.Request(method, Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $token';
    if (contentType != null) request.headers['Content-Type'] = contentType;
    if (ifMatch != null) request.headers['If-Match'] = ifMatch;
    if (body != null) request.bodyBytes = body;
    final streamed = await _guard(() => _client.send(request));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 412) throw CloudConflict();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudException('OneDrive ${response.statusCode}');
    }
    return response;
  }

  Future<T> _guard<T>(Future<T> Function() send) async {
    try {
      return await send();
    } on CloudException {
      rethrow;
    } on http.ClientException catch (error) {
      throw CloudException(error.message);
    }
  }

  String _filename(String name) {
    final trimmed = name.trim();
    if (trimmed.toLowerCase().endsWith('.md')) return trimmed;
    return '$trimmed.md';
  }
}
