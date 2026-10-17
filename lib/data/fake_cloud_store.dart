import 'dart:convert';
import 'dart:io';

import 'cloud_store.dart';

class FakeCloudStore implements CloudStore {
  FakeCloudStore({this._directory}) {
    _load();
  }

  final Directory? _directory;
  var online = true;
  var _nextId = 1;
  var _nextEtag = 1;
  final _files = <String, _FakeFile>{};

  @override
  Future<void> ensureRootFolder() async {
    _guard();
    final exists = _files.values.any((file) => file.name == 'Groceries.md');
    if (!exists) {
      await createMarkdown('Groceries');
    }
  }

  @override
  Future<List<CloudFile>> listMarkdownFiles() async {
    _guard();
    final files = _files.values.map((file) => file.toCloud()).toList()
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
    _guard();
    final file = _FakeFile(
      id: 'file-${_nextId++}',
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
  Future<void> delete(String fileId) async {
    _guard();
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
    _files.clear();
    for (final raw in json['files'] as List? ?? const []) {
      final saved = _FakeFile.fromJson(raw as Map);
      _files[saved.id] = saved;
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

class _FakeFile {
  _FakeFile({
    required this.id,
    required this.name,
    required this.text,
    required this.etag,
    required this.modified,
  });

  final String id;
  String name;
  String text;
  String etag;
  DateTime modified;

  CloudFile toCloud() => CloudFile(id: id, name: name, modified: modified);

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'text': text,
    'etag': etag,
    'modified': modified.toIso8601String(),
  };

  static _FakeFile fromJson(Map json) => _FakeFile(
    id: json['id'] as String,
    name: json['name'] as String,
    text: json['text'] as String? ?? '',
    etag: json['etag'] as String,
    modified: DateTime.parse(json['modified'] as String),
  );
}
