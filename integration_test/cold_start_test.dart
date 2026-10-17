import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/main.dart' as app;
import 'package:integration_test/integration_test.dart';

// tool/check.ps1 launches this file twice against one directory. The second
// process finds phase.txt and must show milk without typing it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const raw = String.fromEnvironment('GROCERY_CACHE_DIR');
  if (raw.isEmpty) {
    testWidgets('cold start needs GROCERY_CACHE_DIR', (tester) async {
      expect(
        raw,
        'a directory shared by both launches',
        reason: 'Set --dart-define=GROCERY_CACHE_DIR',
      );
    });
    return;
  }

  final directory = Directory(raw);
  final phase = File.fromUri(directory.uri.resolve('phase.txt'));
  if (phase.existsSync()) {
    testWidgets('a restarted process shows Groceries and milk under Dairy', (
      tester,
    ) async {
      await app.main();
      await _until(tester, find.bySemanticsLabel('item:milk'));
      expect(find.text('Groceries'), findsWidgets);
      expect(find.bySemanticsLabel('aisle:Dairy'), findsOneWidget);
      expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
      expect(_groceriesText(directory), '- [ ] milk\n');
    });
    return;
  }

  testWidgets('the first process saves milk', (tester) async {
    await app.main();
    await _until(tester, find.text('Groceries'));
    await tester.enterText(find.bySemanticsLabel('add-item-field'), 'milk');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await _until(tester, find.bySemanticsLabel('item:milk'));
    String text = '';
    for (var i = 0; i < 50; i++) {
      text = _groceriesText(directory);
      if (text == '- [ ] milk\n') break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(text, '- [ ] milk\n');
    expect(find.bySemanticsLabel('aisle:Dairy'), findsOneWidget);
    phase.writeAsStringSync('saved');
  });
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
}

String _groceriesText(Directory directory) {
  final file = File.fromUri(directory.uri.resolve('cloud.json'));
  if (!file.existsSync()) return '';
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map;
    for (final raw in json['files'] as List? ?? const []) {
      final saved = raw as Map;
      if (saved['name'] == 'Groceries.md') {
        return saved['text'] as String? ?? '';
      }
    }
  } on FormatException {
    return '';
  }
  return '';
}
