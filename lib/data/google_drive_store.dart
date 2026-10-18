import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'cloud_store.dart';

class GoogleDriveStore implements CloudStore {
  GoogleDriveStore({required this.accessToken, http.Client? client})
    : _client = client ?? http.Client() {
    _drive = drive.DriveApi(_BearerClient(_client, accessToken));
  }

  final Future<String> Function() accessToken;
  final http.Client _client;
  late final drive.DriveApi _drive;
  String? _folderId;

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
    String? page;
    for (var i = 0; i < 20 && (i == 0 || page != null); i++) {
      final listed = await _api(
        () => _drive.files.list(
          q: "mimeType = 'application/vnd.google-apps.folder' and 'root' in parents and trashed = false",
          spaces: 'drive',
          pageSize: 100,
          pageToken: page,
          $fields: 'nextPageToken,files(id,name)',
        ),
      );
      for (final file in listed.files ?? const <drive.File>[]) {
        final id = file.id;
        final name = file.name;
        if (id == null || name == null) continue;
        folders.add(CloudFolder(id: id, name: name));
      }
      page = listed.nextPageToken;
      if (page == null) break;
    }
    folders.sort((a, b) => a.name.compareTo(b.name));
    return folders;
  }

  @override
  Future<CloudFolder> createRootFolder(String name) async {
    final listed = await _api(
      () => _drive.files.list(
        q: "mimeType = 'application/vnd.google-apps.folder' and name = '${_queryText(name)}' and trashed = false",
        spaces: 'drive',
        pageSize: 10,
        $fields: 'files(id,name)',
      ),
    );
    final existing = listed.files ?? const <drive.File>[];
    final found = existing.isEmpty ? null : existing.first;
    final foundId = found?.id;
    if (foundId != null) {
      return CloudFolder(id: foundId, name: found?.name ?? name);
    }
    final created = await _api(
      () => _drive.files.create(
        drive.File()
          ..name = name
          ..mimeType = 'application/vnd.google-apps.folder',
      ),
    );
    final id = created.id;
    if (id == null) {
      throw CloudException('Google Drive did not return a folder id');
    }
    return CloudFolder(id: id, name: created.name ?? name);
  }

  @override
  Future<void> useFolder(String id) async {
    _folderId = id;
  }

  @override
  Future<List<CloudFile>> listMarkdownFiles() async {
    await ensureRootFolder();
    final files = <CloudFile>[];
    String? page;
    for (var i = 0; i < 20 && (i == 0 || page != null); i++) {
      final listed = await _api(
        () => _drive.files.list(
          q: "'$_folderId' in parents and trashed = false",
          pageSize: 100,
          pageToken: page,
          $fields: 'nextPageToken,files(id,name,modifiedTime)',
        ),
      );
      for (final file in listed.files ?? const <drive.File>[]) {
        final name = file.name ?? '';
        final id = file.id;
        if (id == null || !name.toLowerCase().endsWith('.md')) continue;
        files.add(
          CloudFile(
            id: id,
            name: name,
            modified:
                file.modifiedTime ?? DateTime.fromMillisecondsSinceEpoch(0),
          ),
        );
      }
      page = listed.nextPageToken;
      if (page == null) break;
    }
    files.sort((a, b) => a.name.compareTo(b.name));
    return files;
  }

  @override
  Future<CloudText> read(String fileId) async {
    final token = await accessToken();
    final response = await _request(
      () => _client.get(
        _fileUri(fileId, 'alt=media'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final header = response.headers['etag'] ?? '';
    final etag = header.isNotEmpty ? header : await _metadataEtag(fileId);
    return CloudText(text: response.body, etag: etag);
  }

  @override
  Future<String> write(String fileId, String text, String? ifMatchEtag) async {
    final token = await accessToken();
    final response = await _request(
      () => _client.patch(
        Uri.parse(
          'https://www.googleapis.com/upload/drive/v3/files/${Uri.encodeComponent(fileId)}?uploadType=media',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'text/plain; charset=utf-8',
          'If-Match': ?ifMatchEtag,
        },
        body: text,
      ),
    );
    final header = response.headers['etag'] ?? '';
    if (header.isNotEmpty) return header;
    return _metadataEtag(fileId);
  }

  @override
  Future<CloudFile> createMarkdown(String name) async {
    await ensureRootFolder();
    final folderId = _folderId;
    if (folderId == null) {
      throw CloudException('Google Drive did not return a folder id');
    }
    final created = await _api(
      () => _drive.files.create(
        drive.File()
          ..name = _filename(name)
          ..parents = [folderId]
          ..mimeType = 'text/markdown',
      ),
    );
    final id = created.id;
    if (id == null) {
      throw CloudException('Google Drive did not return a file id');
    }
    return CloudFile(
      id: id,
      name: created.name ?? _filename(name),
      modified: created.modifiedTime ?? DateTime.now(),
    );
  }

  @override
  Future<void> rename(String fileId, String name) async {
    await _api(
      () => _drive.files.update(drive.File()..name = _filename(name), fileId),
    );
  }

  @override
  Future<void> delete(String fileId) async {
    await _api(() => _drive.files.delete(fileId));
  }

  Future<T> _api<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on CloudException {
      rethrow;
    } catch (error) {
      throw CloudException('$error');
    }
  }

  Future<http.Response> _request(Future<http.Response> Function() send) async {
    try {
      final response = await send();
      if (response.statusCode == 412) throw CloudConflict();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CloudException('Google Drive ${response.statusCode}');
      }
      return response;
    } on CloudException {
      rethrow;
    } on http.ClientException catch (error) {
      throw CloudException(error.message);
    }
  }

  Future<String> _metadataEtag(String fileId) async {
    final token = await accessToken();
    final response = await _request(
      () => _client.get(
        _fileUri(fileId, 'fields=id'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final etag = response.headers['etag'] ?? '';
    if (etag.isEmpty) {
      throw CloudException('Google Drive did not return an etag');
    }
    return etag;
  }

  Uri _fileUri(String fileId, String query) {
    final id = Uri.encodeComponent(fileId);
    return Uri.parse('https://www.googleapis.com/drive/v3/files/$id?$query');
  }

  String _filename(String name) {
    final trimmed = name.trim();
    if (trimmed.toLowerCase().endsWith('.md')) return trimmed;
    return '$trimmed.md';
  }

  String _queryText(String name) =>
      name.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}

class _BearerClient extends http.BaseClient {
  _BearerClient(this._inner, this._token);

  final http.Client _inner;
  final Future<String> Function() _token;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['Authorization'] = 'Bearer ${await _token()}';
    final response = await _inner.send(request);
    if (response.statusCode == 412) {
      await response.stream.drain<void>();
      throw CloudConflict();
    }
    return response;
  }
}
