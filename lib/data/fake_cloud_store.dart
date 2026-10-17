import 'cloud_store.dart';

class FakeCloudStore implements CloudStore {
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
    return file.etag;
  }

  @override
  Future<CloudFile> createMarkdown(String name) async {
    _guard();
    final filename = _filename(name);
    final file = _FakeFile(
      id: 'file-${_nextId++}',
      name: filename,
      text: '',
      etag: '${_nextEtag++}',
      modified: DateTime.now(),
    );
    _files[file.id] = file;
    return file.toCloud();
  }

  @override
  Future<void> rename(String fileId, String name) async {
    _guard();
    final file = _files[fileId];
    if (file == null) throw CloudException('missing file');
    file.name = _filename(name);
    file.modified = DateTime.now();
  }

  @override
  Future<void> delete(String fileId) async {
    _guard();
    if (_files.remove(fileId) == null) throw CloudException('missing file');
  }

  void _guard() {
    if (!online) throw CloudException('offline');
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
}
