import 'dart:convert';
import 'dart:io';

import 'cloud_store.dart';

class FakeCloudStore implements CloudStore {
  FakeCloudStore({this._directory}) {
    _load();
  }

  final Directory? _directory;
  var online = true;

  /// Widget tests set this for the Google Drive bot change files.
  var applyBotChangeFiles = false;

  /// This many deletes throw and leave the file in place.
  var deleteFailures = 0;

  var _nextId = 1;
  var _nextEtag = 1;
  String? _activeFolderId;
  final _folders = <String, _FakeFolder>{};
  final _files = <String, _FakeFile>{};

  @override
  Future<String> ensureRootFolder() async {
    _guard();
    final selected = _activeFolderId;
    if (selected != null) return selected;
    final folder = await createRootFolder('Groceries');
    _activeFolderId = folder.id;
    _save();
    return folder.id;
  }

  @override
  Future<List<CloudFolder>> listRootFolders() async {
    _guard();
    final folders = [
      for (final folder in _folders.values)
        CloudFolder(id: folder.id, name: folder.name),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return folders;
  }

  @override
  Future<CloudFolder> createRootFolder(String name) async {
    _guard();
    final trimmed = name.trim();
    for (final folder in _folders.values) {
      if (folder.name == trimmed) {
        return CloudFolder(id: folder.id, name: folder.name);
      }
    }
    final folder = _FakeFolder(id: 'folder-${_nextId++}', name: trimmed);
    _folders[folder.id] = folder;
    _save();
    return CloudFolder(id: folder.id, name: folder.name);
  }

  @override
  Future<void> useFolder(String id) async {
    _guard();
    if (!_folders.containsKey(id)) throw CloudException('missing folder');
    _activeFolderId = id;
  }

  @override
  Future<List<CloudFile>> listMarkdownFiles() async {
    await ensureRootFolder();
    final folderId = _activeFolderId;
    final files =
        _files.values
            .where((file) => file.folderId == folderId)
            .map((file) => file.toCloud())
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return files;
  }

  @override
  Future<CloudText> read(String fileId) async {
    _guard();
    final file = _files[fileId];
    if (file == null) throw CloudException('missing file');
    return CloudText(text: file.text, etag: file.etag);
  }

  @override
  Future<String> write(String fileId, String text, String? ifMatchEtag) async {
    _guard();
    final file = _files[fileId];
    if (file == null) throw CloudException('missing file');
    if (ifMatchEtag != null && ifMatchEtag != file.etag) throw CloudConflict();
    file.text = text;
    file.etag = '${_nextEtag++}';
    file.modified = DateTime.now();
    _save();
    return file.etag;
  }

  @override
  Future<CloudFile> createMarkdown(String name) async {
    await ensureRootFolder();
    final folderId = _activeFolderId;
    if (folderId == null) {
      throw CloudException('missing folder');
    }
    final file = _FakeFile(
      id: 'file-${_nextId++}',
      folderId: folderId,
      name: _filename(name),
      text: '',
      etag: '${_nextEtag++}',
      modified: DateTime.now(),
    );
    _files[file.id] = file;
    _save();
    return file.toCloud();
  }

  @override
  Future<void> rename(String fileId, String name) async {
    _guard();
    final file = _files[fileId];
    if (file == null) throw CloudException('missing file');
    file.name = _filename(name);
    file.modified = DateTime.now();
    _save();
  }

  @override
  bool get consumesBotChangeFiles => applyBotChangeFiles;

  @override
  Future<void> delete(String fileId) async {
    _guard();
    if (deleteFailures > 0) {
      deleteFailures -= 1;
      throw CloudException('delete failed');
    }
    if (_files.remove(fileId) == null) throw CloudException('missing file');
    _save();
  }

  void _guard() {
    if (!online) throw CloudException('offline');
  }

  void _load() {
    final directory = _directory;
    if (directory == null) return;
    final file = File.fromUri(directory.uri.resolve('cloud.json'));
    if (!file.existsSync()) return;
    final json = jsonDecode(file.readAsStringSync()) as Map;
    _nextId = json['nextId'] as int? ?? 1;
    _nextEtag = json['nextEtag'] as int? ?? 1;
    _folders.clear();
    for (final raw in json['folders'] as List? ?? const []) {
      final saved = _FakeFolder.fromJson(raw as Map);
      _folders[saved.id] = saved;
    }
    _files.clear();
    for (final raw in json['files'] as List? ?? const []) {
      final saved = _FakeFile.fromJson(raw as Map);
      _files[saved.id] = saved;
    }
    _attachOrphans();
  }

  void _attachOrphans() {
    final orphans = [
      for (final file in _files.values)
        if (file.folderId.isEmpty || !_folders.containsKey(file.folderId)) file,
    ];
    if (orphans.isEmpty) return;
    final home = _folders.values.where((folder) => folder.name == 'Groceries');
    final String homeId;
    if (home.isEmpty) {
      homeId = 'folder-${_nextId++}';
      _folders[homeId] = _FakeFolder(id: homeId, name: 'Groceries');
    } else {
      homeId = home.first.id;
    }
    for (final file in orphans) {
      file.folderId = homeId;
    }
  }

  void _save() {
    final directory = _directory;
    if (directory == null) return;
    if (!directory.existsSync()) directory.createSync(recursive: true);
    final file = File.fromUri(directory.uri.resolve('cloud.json'));
    final json = {
      'nextId': _nextId,
      'nextEtag': _nextEtag,
      'folders': [for (final folder in _folders.values) folder.toJson()],
      'files': [for (final saved in _files.values) saved.toJson()],
    };
    file.writeAsStringSync(jsonEncode(json));
  }

  String _filename(String name) {
    final trimmed = name.trim();
    if (trimmed.toLowerCase().endsWith('.md')) return trimmed;
    return '$trimmed.md';
  }
}

class _FakeFolder {
  _FakeFolder({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, String> toJson() => {'id': id, 'name': name};

  static _FakeFolder fromJson(Map json) =>
      _FakeFolder(id: json['id'] as String, name: json['name'] as String);
}

class _FakeFile {
  _FakeFile({
    required this.id,
    required this.folderId,
    required this.name,
    required this.text,
    required this.etag,
    required this.modified,
  });

  final String id;
  String folderId;
  String name;
  String text;
  String etag;
  DateTime modified;

  CloudFile toCloud() => CloudFile(id: id, name: name, modified: modified);

  Map<String, Object> toJson() => {
    'id': id,
    'folderId': folderId,
    'name': name,
    'text': text,
    'etag': etag,
    'modified': modified.toIso8601String(),
  };

  static _FakeFile fromJson(Map json) => _FakeFile(
    id: json['id'] as String,
    folderId: json['folderId'] as String? ?? '',
    name: json['name'] as String,
    text: json['text'] as String? ?? '',
    etag: json['etag'] as String,
    modified: DateTime.parse(json['modified'] as String),
  );
}
