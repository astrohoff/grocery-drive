import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/app.dart';
import 'package:grocery_drive/data/cloud_store.dart';
import 'package:grocery_drive/data/fake_cloud_store.dart';

void main() {
  late Directory cacheDir;
  late FakeCloudStore cloud;

  setUp(() {
    cacheDir = Directory.systemTemp.createTempSync('grocery_drive_test');
    cloud = FakeCloudStore();
  });

  tearDown(() {
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> launch(WidgetTester tester) async {
    await tester.pumpWidget(GroceryApp(cloud: cloud, cacheDirectory: cacheDir));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Loading').evaluate().isEmpty) return;
    }
  }

  Text itemText(WidgetTester tester, String name) {
    return tester.widget<Text>(
      find.descendant(
        of: find.bySemanticsLabel('item:$name'),
        matching: find.byType(Text),
      ),
    );
  }

  Future<CloudFile> groceriesFile() async {
    final files = await cloud.listMarkdownFiles();
    return files.singleWhere((file) => file.name == 'Groceries.md');
  }

  Future<void> addItem(WidgetTester tester, String name) async {
    await tester.enterText(find.bySemanticsLabel('add-item-field'), name);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
  }

  Future<void> tapItemAction(
    WidgetTester tester,
    String line,
    String action,
  ) async {
    await tester.tap(find.bySemanticsLabel('item-menu:$line'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('$action:$line'));
    await tester.pump();
    await settle(tester);
  }

  testWidgets('first launch creates Groceries and shows that title', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text('Groceries'), findsWidgets);
    final files = await cloud.listMarkdownFiles();
    expect(files.map((file) => file.name).toList(), [
      'Groceries.md',
      'bot-instructions.md',
    ]);
  });

  testWidgets('the add field is visible and does not request focus', (
    tester,
  ) async {
    await launch(tester);
    expect(find.bySemanticsLabel('add-item-field'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('submitting milk shows it under Dairy once', (tester) async {
    await launch(tester);
    await addItem(tester, 'milk');
    await addItem(tester, 'milk');
    expect(find.bySemanticsLabel('aisle:Dairy'), findsOneWidget);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
  });

  testWidgets('checking a row strikes it through and leaves it in the aisle', (
    tester,
  ) async {
    await launch(tester);
    await addItem(tester, 'milk');
    await tester.tap(find.bySemanticsLabel('check:milk'));
    await settle(tester);
    expect(find.bySemanticsLabel('aisle:Dairy'), findsOneWidget);
    expect(
      itemText(tester, 'milk').style?.decoration,
      TextDecoration.lineThrough,
    );
  });

  testWidgets(
    'clear completed removes checked lines and leaves unchecked lines',
    (tester) async {
      await launch(tester);
      await addItem(tester, 'milk');
      await addItem(tester, 'eggs');
      await tester.tap(find.bySemanticsLabel('check:milk'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('clear-completed'));
      await settle(tester);
      expect(find.bySemanticsLabel('item:milk'), findsNothing);
      expect(find.bySemanticsLabel('item:eggs'), findsOneWidget);
    },
  );

  testWidgets('editing an item renames that line', (tester) async {
    await launch(tester);
    await addItem(tester, 'milk');
    await tapItemAction(tester, 'milk', 'edit');
    await tester.enterText(
      find.bySemanticsLabel('edit-item-field'),
      'oat milk',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.bySemanticsLabel('item:oat milk'), findsOneWidget);
    expect(find.bySemanticsLabel('item:milk'), findsNothing);
  });

  testWidgets('deleting an item removes that line', (tester) async {
    await launch(tester);
    await addItem(tester, 'milk');
    await tapItemAction(tester, 'milk', 'delete');
    expect(find.bySemanticsLabel('item:milk'), findsNothing);
  });

  testWidgets('create, rename, and delete a list', (tester) async {
    await launch(tester);
    await tester.tap(find.bySemanticsLabel('list-switcher'));
    await settle(tester);
    await tester.enterText(find.bySemanticsLabel('create-list-field'), 'Party');
    await tester.tap(find.bySemanticsLabel('create-list'));
    await settle(tester);
    expect(find.text('Party'), findsWidgets);

    await tester.tap(find.bySemanticsLabel('list-switcher'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('rename-list:Party'));
    await settle(tester);
    await tester.enterText(
      find.bySemanticsLabel('rename-list-field'),
      'Weekend',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('Weekend'), findsWidgets);

    await tester.tap(find.bySemanticsLabel('list-switcher'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('delete-list:Weekend'));
    await settle(tester);
    final names = (await cloud.listMarkdownFiles()).map((file) => file.name);
    expect(names, isNot(contains('Weekend.md')));
    expect(names, contains('Groceries.md'));
  });

  testWidgets('switching lists survives a rebuilt app', (tester) async {
    await launch(tester);
    await tester.tap(find.bySemanticsLabel('list-switcher'));
    await settle(tester);
    await tester.enterText(find.bySemanticsLabel('create-list-field'), 'Party');
    await tester.tap(find.bySemanticsLabel('create-list'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('list-switcher'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('open-list:Groceries'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('list-switcher'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('open-list:Party'));
    await settle(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await launch(tester);
    expect(find.text('Party'), findsWidgets);
    expect(find.text('Groceries'), findsNothing);
  });

  testWidgets('an offline edit stays and syncs when the cloud returns', (
    tester,
  ) async {
    await launch(tester);
    cloud.online = false;
    await addItem(tester, 'milk');
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
    expect(find.bySemanticsLabel('sync-banner'), findsOneWidget);

    cloud.online = true;
    await tester.tap(find.bySemanticsLabel('sync-now'));
    await settle(tester);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
    final file = await groceriesFile();
    final body = await cloud.read(file.id);
    expect(body.text, contains('- [ ] milk'));
  });

  testWidgets('a bot append shows up under Produce after sync', (tester) async {
    await launch(tester);
    final file = await groceriesFile();
    final current = await cloud.read(file.id);
    await cloud.write(file.id, '${current.text}- [ ] bananas\n', current.etag);
    await tester.tap(find.bySemanticsLabel('sync-now'));
    await settle(tester);
    expect(find.bySemanticsLabel('aisle:Produce'), findsOneWidget);
    expect(find.bySemanticsLabel('item:bananas'), findsOneWidget);
  });

  testWidgets(
    'the folder has bot instructions and bot-instructions is not a list',
    (tester) async {
      await launch(tester);
      final instructionsFile = (await cloud.listMarkdownFiles()).singleWhere(
        (file) => file.name == 'bot-instructions.md',
      );
      final instructions = await cloud.read(instructionsFile.id);
      expect(instructions.text, contains('- [ ] milk (2 gal)'));
      expect(instructions.text, contains('- [ ] eggs (3)'));
      expect(instructions.text, contains('- [ ] butter (1/2 lb)'));
      expect(instructions.text, contains('milk` and `milk (2)` are different'));

      await tester.tap(find.bySemanticsLabel('list-switcher'));
      await settle(tester);
      expect(find.bySemanticsLabel('open-list:Groceries'), findsOneWidget);
      expect(find.bySemanticsLabel('open-list:bot-instructions'), findsNothing);
      await tester.enterText(
        find.bySemanticsLabel('create-list-field'),
        'bot-instructions',
      );
      await tester.tap(find.bySemanticsLabel('create-list'));
      await settle(tester);
      expect(find.text('Groceries'), findsWidgets);
      expect(find.text('bot-instructions'), findsNothing);

      await tester.tap(find.bySemanticsLabel('list-switcher'));
      await settle(tester);
      await tester.enterText(
        find.bySemanticsLabel('create-list-field'),
        'Party',
      );
      await tester.tap(find.bySemanticsLabel('create-list'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('list-switcher'));
      await settle(tester);
      await tester.tap(find.bySemanticsLabel('rename-list:Party'));
      await settle(tester);
      await tester.enterText(
        find.bySemanticsLabel('rename-list-field'),
        'Bot-Instructions',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await settle(tester);
      expect(find.text('Party'), findsWidgets);
      final names = (await cloud.listMarkdownFiles()).map((file) => file.name);
      expect(
        names
            .where((name) => name.toLowerCase() == 'bot-instructions.md')
            .length,
        1,
      );
      expect(names, contains('Party.md'));
    },
  );

  testWidgets('a rewritten bot-instructions.md is restored on sync', (
    tester,
  ) async {
    await launch(tester);
    final instructionsFile = (await cloud.listMarkdownFiles()).singleWhere(
      (file) => file.name == 'bot-instructions.md',
    );
    await cloud.write(
      instructionsFile.id,
      '# nope\n',
      (await cloud.read(instructionsFile.id)).etag,
    );
    await tester.tap(find.bySemanticsLabel('sync-now'));
    await settle(tester);
    final restored = await cloud.read(instructionsFile.id);
    expect(restored.text, contains('- [ ] milk (2 gal)'));
    expect(restored.text, contains('- [ ] butter (1/2 lb)'));
    expect(restored.text, isNot(contains('# nope')));
  });

  testWidgets('a quantity is stored after the name and keeps the aisle', (
    tester,
  ) async {
    await launch(tester);
    await tester.enterText(find.bySemanticsLabel('add-item-field'), 'milk');
    await tester.enterText(
      find.bySemanticsLabel('add-quantity-field'),
      '2 gal',
    );
    await tester.tap(find.bySemanticsLabel('submit-add'));
    await settle(tester);
    expect(find.bySemanticsLabel('aisle:Dairy'), findsOneWidget);
    expect(find.bySemanticsLabel('item:milk (2 gal)'), findsOneWidget);
    expect(find.text('2 gal'), findsOneWidget);
    final file = await groceriesFile();
    final body = await cloud.read(file.id);
    expect(body.text, contains('- [ ] milk (2 gal)'));
  });

  testWidgets('the same name with and without a quantity are two rows', (
    tester,
  ) async {
    await launch(tester);
    await addItem(tester, 'milk');
    await tester.enterText(find.bySemanticsLabel('add-item-field'), 'milk');
    await tester.enterText(find.bySemanticsLabel('add-quantity-field'), '2');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
    expect(find.bySemanticsLabel('item:milk (2)'), findsOneWidget);
  });

  testWidgets('editing the quantity rewrites that line', (tester) async {
    await launch(tester);
    await tester.enterText(find.bySemanticsLabel('add-item-field'), 'milk');
    await tester.enterText(find.bySemanticsLabel('add-quantity-field'), '2');
    await tester.tap(find.bySemanticsLabel('submit-add'));
    await settle(tester);
    await tapItemAction(tester, 'milk (2)', 'edit');
    await tester.enterText(
      find.bySemanticsLabel('edit-quantity-field'),
      '3 gal',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.bySemanticsLabel('item:milk (3 gal)'), findsOneWidget);
    expect(find.bySemanticsLabel('item:milk (2)'), findsNothing);
    expect(find.text('3 gal'), findsOneWidget);
  });

  testWidgets('a local check and a bot add both survive sync', (tester) async {
    await launch(tester);
    await addItem(tester, 'milk');
    await tester.tap(find.bySemanticsLabel('check:milk'));
    await settle(tester);
    final file = await groceriesFile();
    final current = await cloud.read(file.id);
    await cloud.write(file.id, '${current.text}- [ ] bananas\n', current.etag);
    await tester.tap(find.bySemanticsLabel('sync-now'));
    await settle(tester);
    expect(
      itemText(tester, 'milk').style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(find.bySemanticsLabel('item:bananas'), findsOneWidget);
  });

  testWidgets('escape clears the add field and does not add the item', (
    tester,
  ) async {
    await launch(tester);
    await tester.enterText(find.bySemanticsLabel('add-item-field'), 'kale');
    await tester.enterText(find.bySemanticsLabel('add-quantity-field'), '2');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(_fieldText(tester, 'add-item-field'), '');
    expect(_fieldText(tester, 'add-quantity-field'), '');
    expect(find.bySemanticsLabel('item:kale'), findsNothing);
    expect(find.bySemanticsLabel('item:kale (2)'), findsNothing);
  });

  testWidgets('a row is at least 56 pixels tall', (tester) async {
    await launch(tester);
    await addItem(tester, 'milk');
    expect(
      tester.getSize(find.bySemanticsLabel('item:milk')).height,
      greaterThanOrEqualTo(56),
    );
  });

  testWidgets('the list stays within 720 pixels on a wide window', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await launch(tester);
    final row = find
        .ancestor(
          of: find.bySemanticsLabel('add-item-field'),
          matching: find.byType(Row),
        )
        .first;
    expect(tester.getSize(row).width, lessThanOrEqualTo(720));
  });

  testWidgets('light mode uses the warm page background', (tester) async {
    await launch(tester);
    final context = tester.element(find.bySemanticsLabel('add-item-field'));
    expect(Theme.of(context).scaffoldBackgroundColor, const Color(0xFFF6F3EC));
  });

  testWidgets('dark mode uses the scheme surface', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await launch(tester);
    final context = tester.element(find.bySemanticsLabel('add-item-field'));
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF1F7A4D),
        brightness: Brightness.dark,
      ).surface,
    );
  });

  testWidgets('the aisle header stays pinned while its items scroll', (
    tester,
  ) async {
    await launch(tester);
    for (var i = 0; i < 12; i++) {
      await addItem(tester, 'milk $i');
    }
    final listRect = tester.getRect(find.byType(CustomScrollView));
    await tester.dragFrom(
      Offset(listRect.center.dx, listRect.bottom - 24),
      const Offset(0, -200),
    );
    await settle(tester);
    final position = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(position.pixels, greaterThanOrEqualTo(80));
    final headerTop = tester
        .getTopLeft(find.bySemanticsLabel('aisle:Dairy'))
        .dy;
    final listTop = tester.getTopLeft(find.byType(CustomScrollView)).dy;
    expect(headerTop, listTop);
  });
}

String _fieldText(WidgetTester tester, String label) {
  final field = tester.widget<TextField>(
    find.descendant(
      of: find.bySemanticsLabel(label),
      matching: find.byType(TextField),
    ),
  );
  return field.controller?.text ?? '';
}
