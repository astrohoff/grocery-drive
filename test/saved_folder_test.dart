import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/app.dart';
import 'package:grocery_drive/data/fake_cloud_store.dart';
import 'package:grocery_drive/data/local_cache.dart';
import 'package:grocery_drive/list_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory cacheDir;

  setUp(() {
    cacheDir = Directory.systemTemp.createTempSync('grocery_saved_folder');
  });

  tearDown(() {
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  testWidgets('a missing saved folder opens a new Groceries list', (
    tester,
  ) async {
    _writeCache(cacheDir, folderId: 'other-account', text: '');
    final cloud = FakeCloudStore();
    final controller = await _open(cacheDir, cloud);
    addTearDown(controller.dispose);
    expect(controller.cache.folderId, isNot('other-account'));
    expect(controller.title, 'Groceries');

    controller.addItem('milk');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final file = (await cloud.listMarkdownFiles()).singleWhere(
      (item) => item.name == 'Groceries.md',
    );
    expect(file.id, isNot('other-file'));
    expect((await cloud.read(file.id)).text, '- [ ] milk\n');
  });

  testWidgets('a saved file from the other account does not hide the cloud list', (
    tester,
  ) async {
    final cloud = FakeCloudStore();
    final folder = await cloud.createRootFolder('Groceries');
    await cloud.useFolder(folder.id);
    final created = await cloud.createMarkdown('Groceries');
    final body = await cloud.read(created.id);
    await cloud.write(created.id, '- [ ] milk\n', body.etag);
    File('${cacheDir.path}${Platform.pathSeparator}meta.json').writeAsStringSync(
      jsonEncode({
        'folderId': folder.id,
        'lastOpenedId': 'google-file',
        'files': [
          {
            'id': 'google-file',
            'name': 'Groceries.md',
            'etag': 'google-rev',
            'baseText': '',
            'localText': '',
          },
          {
            'id': created.id,
            'name': 'Groceries.md',
            'etag': 'stale',
            'baseText': '',
            'localText': '',
          },
        ],
      }),
    );

    final controller = await _open(cacheDir, cloud);
    addTearDown(controller.dispose);
    expect(controller.title, 'Groceries');
    expect(controller.items.single.name, 'milk');
  });

  testWidgets('an offline open keeps the saved list', (tester) async {
    _writeCache(cacheDir, folderId: 'other-account', text: '- [ ] milk\n');
    final cloud = FakeCloudStore()..online = false;
    final controller = await _open(cacheDir, cloud);
    addTearDown(controller.dispose);
    expect(controller.cache.folderId, 'other-account');
    expect(controller.items.single.name, 'milk');
  });
}

void _writeCache(
  Directory directory, {
  required String folderId,
  required String text,
}) {
  File('${directory.path}${Platform.pathSeparator}meta.json').writeAsStringSync(
    jsonEncode({
      'folderId': folderId,
      'lastOpenedId': 'other-file',
      'files': [
        {
          'id': 'other-file',
          'name': 'Groceries.md',
          'etag': '"{FOREIGN},1"',
          'baseText': text,
          'localText': text,
        },
      ],
    }),
  );
}

Future<ListController> _open(Directory directory, FakeCloudStore cloud) async {
  final controller = ListController(
    cloud: cloud,
    cache: LocalCache(directory),
    categorizer: await loadAisleCatalog(rootBundle),
    instructionsMarkdown: '# instructions\n',
  );
  await controller.open();
  return controller;
}
