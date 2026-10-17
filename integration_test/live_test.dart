import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/data/cloud_accounts.dart';
import 'package:grocery_drive/data/cloud_store.dart';
import 'package:grocery_drive/main.dart' as app;
import 'package:integration_test/integration_test.dart';

// tool/check_live.ps1 runs this against the signed-in cloud. It must not open
// a browser. A missing refresh token fails before the app starts.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const cloud = String.fromEnvironment('CLOUD');
  if (cloud != 'live') {
    testWidgets('live test needs CLOUD=live', (tester) async {
      expect(cloud, 'live', reason: 'Set --dart-define=CLOUD=live');
    });
    return;
  }

  testWidgets('an app add and a remote add both show after sync', (
    tester,
  ) async {
    const storage = FlutterSecureStorage();
    final provider = await storage.read(key: 'provider');
    final refresh = provider == null || provider.isEmpty
        ? null
        : await storage.read(key: '$provider.refresh');
    if (provider == null ||
        provider.isEmpty ||
        refresh == null ||
        refresh.isEmpty) {
      fail('Sign in once in the app so the refresh token is stored.');
    }

    await app.main();
    await _show(tester, find.bySemanticsLabel('add-item-field'));
    expect(find.bySemanticsLabel('add-item-field'), findsOneWidget);
    await tester.enterText(
      find.bySemanticsLabel('add-item-field'),
      'live milk',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _show(tester, find.bySemanticsLabel('item:live milk'));
    expect(find.bySemanticsLabel('item:live milk'), findsOneWidget);

    final store = await CloudAccounts().openStore();
    if (store == null) {
      fail('Sign in once in the app so the refresh token is stored.');
    }
    await _appendLiveBananas(tester, store);

    await tester.tap(find.bySemanticsLabel('sync-now'));
    await _show(tester, find.bySemanticsLabel('aisle:Dairy'));
    expect(find.bySemanticsLabel('aisle:Dairy'), findsOneWidget);
    await _show(tester, find.bySemanticsLabel('item:live milk'));
    expect(find.bySemanticsLabel('item:live milk'), findsOneWidget);
    await _show(tester, find.bySemanticsLabel('aisle:Produce'));
    expect(find.bySemanticsLabel('aisle:Produce'), findsOneWidget);
    await _show(tester, find.bySemanticsLabel('item:live bananas'));
    expect(find.bySemanticsLabel('item:live bananas'), findsOneWidget);
  });
}

Future<void> _appendLiveBananas(WidgetTester tester, CloudStore store) async {
  for (var attempt = 0; attempt < 40; attempt++) {
    final groceries = await _groceries(store);
    if (groceries == null) {
      await tester.pump(const Duration(milliseconds: 250));
      continue;
    }
    final body = await store.read(groceries.id);
    if (!_hasLine(body.text, 'live milk')) {
      await tester.pump(const Duration(milliseconds: 250));
      continue;
    }
    if (_hasLine(body.text, 'live bananas')) return;
    final text = body.text.endsWith('\n') || body.text.isEmpty
        ? '${body.text}- [ ] live bananas\n'
        : '${body.text}\n- [ ] live bananas\n';
    try {
      await store.write(groceries.id, text, body.etag);
      return;
    } on CloudConflict {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }
  fail('Groceries.md did not contain live milk.');
}

Future<CloudFile?> _groceries(CloudStore store) async {
  final files = await store.listMarkdownFiles();
  for (final file in files) {
    if (file.name == 'Groceries.md') return file;
  }
  return null;
}

bool _hasLine(String text, String name) {
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed == '- [ ] $name' ||
        trimmed == '- [x] $name' ||
        trimmed == '- [X] $name') {
      return true;
    }
  }
  return false;
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  final list = find.byType(Scrollable);
  if (list.evaluate().isNotEmpty) {
    tester.state<ScrollableState>(list.first).position.jumpTo(0);
  }
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
    if (list.evaluate().isEmpty) continue;
    await tester.drag(list.first, const Offset(0, -400));
  }
}
