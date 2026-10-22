import 'dart:convert';
import 'dart:io';

class CachedList {
  CachedList({
    required this.id,
    required this.name,
    required this.etag,
    required this.baseText,
    required this.localText,
  });

  final String id;
  String name;
  String etag;
  String baseText;
  String localText;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'etag': etag,
    'baseText': baseText,
    'localText': localText,
  };

  static CachedList fromJson(Map json) => CachedList(
    id: json['id'] as String,
    name: json['name'] as String,
    etag: json['etag'] as String,
    baseText: json['baseText'] as String,
    localText: json['localText'] as String,
  );
}

class LocalCache {
  LocalCache(this.directory);

  final Directory directory;
  String? folderId;
  String? lastOpenedId;
  final files = <String, CachedList>{};

  /// Change-file id to the etag already merged into the list.
  /// A failed delete must not apply that file again.
  final appliedBotChanges = <String, String>{};

  File get _file => File.fromUri(directory.uri.resolve('meta.json'));

  Future<void> load() async {
    if (!_file.existsSync()) return;
    final json = jsonDecode(_file.readAsStringSync()) as Map;
    folderId = json['folderId'] as String?;
    lastOpenedId = json['lastOpenedId'] as String?;
    files.clear();
    for (final raw in json['files'] as List? ?? const []) {
      final cached = CachedList.fromJson(raw as Map);
      files[cached.id] = cached;
    }
    appliedBotChanges.clear();
    final applied = json['appliedBotChanges'];
    if (applied is Map) {
      for (final entry in applied.entries) {
        appliedBotChanges['${entry.key}'] = '${entry.value}';
      }
    }
  }

  Future<void> save() async {
    if (!directory.existsSync()) directory.createSync(recursive: true);
    final json = {
      'folderId': folderId,
      'lastOpenedId': lastOpenedId,
      'files': [for (final file in files.values) file.toJson()],
      'appliedBotChanges': appliedBotChanges,
    };
    // Sync IO so a widget test's fake clock can finish opening a list.
    // meta.json is a few kilobytes. The handle is closed before this returns.
    _file.writeAsStringSync(jsonEncode(json));
  }
}
