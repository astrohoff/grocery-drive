class CloudFolder {
  const CloudFolder({required this.id, required this.name});

  final String id;
  final String name;
}

class CloudFile {
  const CloudFile({
    required this.id,
    required this.name,
    required this.modified,
  });

  final String id;
  final String name;
  final DateTime modified;
}

class CloudText {
  const CloudText({required this.text, required this.etag});

  final String text;
  final String etag;
}

class CloudException implements Exception {
  CloudException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CloudConflict extends CloudException {
  CloudConflict() : super('conflict');
}

abstract class CloudStore {
  Future<List<CloudFile>> listMarkdownFiles();

  Future<CloudText> read(String fileId);

  Future<String> write(String fileId, String text, String? ifMatchEtag);

  Future<CloudFile> createMarkdown(String name);

  Future<void> rename(String fileId, String name);

  Future<void> delete(String fileId);

  /// Uses the selected folder, or finds or creates a root folder named Groceries.
  /// Returns the folder id the following list and create calls will use.
  Future<String> ensureRootFolder();

  Future<List<CloudFolder>> listRootFolders();

  /// Returns the existing root folder when [name] is already there.
  Future<CloudFolder> createRootFolder(String name);

  Future<void> useFolder(String id);
}
