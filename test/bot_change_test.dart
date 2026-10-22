import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/app.dart';
import 'package:grocery_drive/data/fake_cloud_store.dart';
import 'package:grocery_drive/data/google_drive_store.dart';
import 'package:grocery_drive/data/onedrive_store.dart';
import 'package:grocery_drive/domain/bot_change.dart';
import 'package:grocery_drive/domain/item.dart';

void main() {
  test('Google Drive consumes bot change files and OneDrive does not', () {
    final google = GoogleDriveStore(accessToken: () async => '');
    final oneDrive = OneDriveStore(accessToken: () async => '');
    expect(
      [google.consumesBotChangeFiles, oneDrive.consumesBotChangeFiles],
      [true, false],
    );
  });

  test('a change file names the list before the last .bot. token', () {
    const names = [
      'Groceries.bot.4f2.md',
      'Party.bot.a.b.md',
      'My.bot.list.bot.x.md',
      ' GROCERIES.BOT.ZZ.MD ',
      'Groceries.md',
      'Groceries.bot.md',
      'bot-instructions.md',
      'Week.bot.md',
    ];
    expect(
      [
        for (final name in names)
          if (isBotChangeFile(name)) name,
      ],
      [
        'Groceries.bot.4f2.md',
        'Party.bot.a.b.md',
        'My.bot.list.bot.x.md',
        ' GROCERIES.BOT.ZZ.MD ',
      ],
    );
    expect(botChangeListFilename('Groceries.bot.4f2.md'), 'Groceries.md');
    expect(botChangeListFilename('Party.bot.a.b.md'), 'Party.md');
    expect(botChangeListFilename('My.bot.list.bot.x.md'), 'My.bot.list.md');
    expect(botChangeListFilename(' GROCERIES.BOT.ZZ.MD '), 'GROCERIES.md');
    expect(botChangeListFilename('Groceries.bot.md'), null);
  });

  test('operation lines check, add, and keep an item they omit', () {
    expect(
      mergedBotChange(
        text: 'add bananas\ncheck milk\nadd milk (2 gal)\n',
        base: const [Item('milk'), Item('eggs')],
        local: const [Item('milk'), Item('eggs')],
        cloud: const [Item('milk'), Item('eggs')],
      ),
      const [
        Item('milk', checked: true),
        Item('eggs'),
        Item('bananas'),
        Item('milk (2 gal)'),
      ],
    );
  });

  test('a remove drops an item that is only on the cloud copy', () {
    expect(
      mergedBotChange(
        text: 'remove juice\n',
        base: const [Item('milk')],
        local: const [Item('milk')],
        cloud: const [Item('milk'), Item('juice'), Item('oats')],
      ),
      const [Item('milk'), Item('oats')],
    );
  });

  test('a local check beats a remove in a change file', () {
    expect(
      mergedBotChange(
        text: 'remove milk\n',
        base: const [Item('milk')],
        local: const [Item('milk', checked: true)],
        cloud: const [Item('milk')],
      ),
      const [Item('milk', checked: true)],
    );
  });

  test('check adds a missing item and uncheck clears one', () {
    expect(
      mergedBotChange(
        text: 'check yogurt\nuncheck bread\n',
        base: const [Item('bread', checked: true)],
        local: const [Item('bread', checked: true)],
        cloud: const [Item('bread', checked: true)],
      ),
      const [Item('bread'), Item('yogurt', checked: true)],
    );
  });

  test('a checklist drops an unchanged item and keeps a local add', () {
    expect(
      mergedBotChange(
        text: '- [ ] milk\n',
        base: const [Item('milk'), Item('eggs')],
        local: const [Item('milk'), Item('eggs'), Item('bananas')],
        cloud: const [Item('milk'), Item('eggs')],
      ),
      const [Item('milk'), Item('bananas')],
    );
  });

  test('a checklist keeps an item that is only on the cloud copy', () {
    expect(
      mergedBotChange(
        text: '- [ ] milk\n',
        base: const [Item('milk')],
        local: const [Item('milk')],
        cloud: const [Item('milk'), Item('juice')],
      ),
      const [Item('milk'), Item('juice')],
    );
  });

  test('an empty change file leaves a local check in place', () {
    expect(
      mergedBotChange(
        text: '\n',
        base: const [Item('milk')],
        local: const [Item('milk', checked: true)],
        cloud: const [Item('milk')],
      ),
      const [Item('milk', checked: true)],
    );
  });

  test('prose and a mixed file are not a change', () {
    const base = [Item('milk')];
    expect(
      mergedBotChange(
        text: 'please add milk\n',
        base: base,
        local: base,
        cloud: base,
      ),
      null,
    );
    expect(
      mergedBotChange(
        text: 'add milk\nhello\n',
        base: base,
        local: base,
        cloud: base,
      ),
      null,
    );
  });

  late Directory cacheDir;
  late FakeCloudStore cloud;

  setUp(() {
    cacheDir = Directory.systemTemp.createTempSync('grocery_drive_bot_change');
    cloud = FakeCloudStore()..applyBotChangeFiles = true;
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

  Future<void> addItem(WidgetTester tester, String name) async {
    await tester.enterText(find.bySemanticsLabel('add-item-field'), name);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
  }

  Future<void> plant(String name, String text) async {
    final created = await cloud.createMarkdown(name);
    final body = await cloud.read(created.id);
    await cloud.write(created.id, text, body.etag);
  }

  Future<List<String>> filenames() async {
    final files = await cloud.listMarkdownFiles();
    return [for (final file in files) file.name];
  }

  Future<String> listText(String name) async {
    final files = await cloud.listMarkdownFiles();
    final file = files.singleWhere((entry) => entry.name == name);
    return (await cloud.read(file.id)).text;
  }

  testWidgets('bot instructions tell Google Drive to add a change file', (
    tester,
  ) async {
    await launch(tester);
    final text = await listText('bot-instructions.md');
    expect(text, contains('OneDrive can edit a list file in place. Do that.'));
    expect(text, contains('Google Drive cannot edit an existing file.'));
    expect(text, contains('Groceries.bot.4f2.md'));
    expect(text, contains('add milk'));
    expect(text, contains('add eggs (3)'));
    expect(text, contains('remove butter'));
    expect(text, contains('check sourdough'));
    expect(text, contains('uncheck milk'));
    expect(text, contains('A file of only checkbox lines is the whole list.'));
    expect(text, contains('A list filename cannot contain `.bot.`.'));
  });

  testWidgets(
    'a Google change file checks milk, adds bananas, and is deleted',
    (tester) async {
      await launch(tester);
      await addItem(tester, 'milk');
      await plant('Groceries.bot.4f2', 'check milk\nadd bananas\n');
      await tester.tap(find.bySemanticsLabel('sync-now'));
      await settle(tester);
      expect(
        itemText(tester, 'milk').style?.decoration,
        TextDecoration.lineThrough,
      );
      expect(find.bySemanticsLabel('item:bananas'), findsOneWidget);
      expect(await listText('Groceries.md'), '- [x] milk\n- [ ] bananas\n');
      expect(await filenames(), ['Groceries.md', 'bot-instructions.md']);
    },
  );

  testWidgets('a change file keeps an item it does not mention', (
    tester,
  ) async {
    await launch(tester);
    await addItem(tester, 'milk');
    await addItem(tester, 'eggs');
    await plant('Groceries.bot.add', 'add bananas\n');
    await tester.tap(find.bySemanticsLabel('sync-now'));
    await settle(tester);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
    expect(find.bySemanticsLabel('item:eggs'), findsOneWidget);
    expect(find.bySemanticsLabel('item:bananas'), findsOneWidget);
    expect(
      await listText('Groceries.md'),
      '- [ ] milk\n- [ ] eggs\n- [ ] bananas\n',
    );
  });

  testWidgets('a local check beats a remove in a Google change file', (
    tester,
  ) async {
    await launch(tester);
    await addItem(tester, 'milk');
    await plant('Groceries.bot.rm', 'remove milk\n');
    cloud.online = false;
    await tester.tap(find.bySemanticsLabel('check:milk'));
    await settle(tester);
    cloud.online = true;
    await tester.tap(find.bySemanticsLabel('sync-now'));
    await settle(tester);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
    expect(
      itemText(tester, 'milk').style?.decoration,
      TextDecoration.lineThrough,
    );
    expect(await listText('Groceries.md'), '- [x] milk\n');
    expect(await filenames(), ['Groceries.md', 'bot-instructions.md']);
  });

  testWidgets('a remove drops juice that is only on the cloud copy', (
    tester,
  ) async {
    await launch(tester);
    await addItem(tester, 'milk');
    final files = await cloud.listMarkdownFiles();
    final groceries = files.singleWhere((file) => file.name == 'Groceries.md');
    final current = await cloud.read(groceries.id);
    await cloud.write(
      groceries.id,
      '${current.text}- [ ] juice\n- [ ] oats\n',
      current.etag,
    );
    await plant('Groceries.bot.j', 'remove juice\n');
    await tester.tap(find.bySemanticsLabel('sync-now'));
    await settle(tester);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
    expect(find.bySemanticsLabel('item:juice'), findsNothing);
    expect(find.bySemanticsLabel('item:oats'), findsOneWidget);
    expect(await listText('Groceries.md'), '- [ ] milk\n- [ ] oats\n');
    expect(await filenames(), ['Groceries.md', 'bot-instructions.md']);
  });

  testWidgets(
    'a checklist change removes an omitted item and keeps a local add',
    (tester) async {
      await launch(tester);
      await addItem(tester, 'milk');
      await addItem(tester, 'eggs');
      final files = await cloud.listMarkdownFiles();
      final groceries = files.singleWhere((file) => file.name == 'Groceries.md');
      final current = await cloud.read(groceries.id);
      await cloud.write(groceries.id, '${current.text}- [ ] oats\n', current.etag);
      await plant('Groceries.bot.snap', '- [ ] milk\n');
      cloud.online = false;
      await addItem(tester, 'bananas');
      cloud.online = true;
      await tester.tap(find.bySemanticsLabel('sync-now'));
      await settle(tester);
      expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
      expect(find.bySemanticsLabel('item:eggs'), findsNothing);
      expect(find.bySemanticsLabel('item:bananas'), findsOneWidget);
      expect(find.bySemanticsLabel('item:oats'), findsOneWidget);
      expect(
        await listText('Groceries.md'),
        '- [ ] milk\n- [ ] bananas\n- [ ] oats\n',
      );
      expect(await filenames(), ['Groceries.md', 'bot-instructions.md']);
    },
  );

  testWidgets('a failed delete does not apply the checklist twice', (
    tester,
  ) async {
    await launch(tester);
    await addItem(tester, 'milk');
    await plant('Groceries.bot.snap', '- [ ] milk\n');
    cloud.online = false;
    await addItem(tester, 'bananas');
    cloud.online = true;
    cloud.deleteFailures = 1;
    await tester.tap(find.bySemanticsLabel('sync-now'));
    await settle(tester);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
    expect(find.bySemanticsLabel('item:bananas'), findsOneWidget);
    expect(await listText('Groceries.bot.snap.md'), '- [ ] milk\n');
    expect(find.bySemanticsLabel('sync-banner'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
    await launch(tester);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
    expect(find.bySemanticsLabel('item:bananas'), findsOneWidget);
    expect(await listText('Groceries.md'), '- [ ] milk\n- [ ] bananas\n');
    expect(await filenames(), ['Groceries.md', 'bot-instructions.md']);
    expect(find.bySemanticsLabel('sync-banner'), findsNothing);
  });

  testWidgets('prose in a change file stays out of the list switcher', (
    tester,
  ) async {
    await launch(tester);
    await addItem(tester, 'milk');
    await plant('Groceries.bot.note', 'please add bananas\n');
    await tester.tap(find.bySemanticsLabel('sync-now'));
    await settle(tester);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
    expect(find.bySemanticsLabel('item:bananas'), findsNothing);
    expect(await listText('Groceries.md'), '- [ ] milk\n');
    expect(await listText('Groceries.bot.note.md'), 'please add bananas\n');
    expect(find.bySemanticsLabel('sync-banner'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('list-switcher'));
    await settle(tester);
    expect(find.bySemanticsLabel('open-list:Groceries'), findsOneWidget);
    expect(find.bySemanticsLabel('open-list:Groceries.bot.note'), findsNothing);
  });

  testWidgets('OneDrive leaves a change file as its own list', (tester) async {
    cloud.applyBotChangeFiles = false;
    await launch(tester);
    await addItem(tester, 'milk');
    await plant('Groceries.bot.1', 'add bananas\n');
    await tester.tap(find.bySemanticsLabel('sync-now'));
    await settle(tester);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
    expect(find.bySemanticsLabel('item:bananas'), findsNothing);
    expect(await listText('Groceries.md'), '- [ ] milk\n');
    expect(await listText('Groceries.bot.1.md'), 'add bananas\n');
    await tester.tap(find.bySemanticsLabel('list-switcher'));
    await settle(tester);
    expect(find.bySemanticsLabel('open-list:Groceries.bot.1'), findsOneWidget);
  });

  testWidgets('a list cannot be named with .bot.', (tester) async {
    cloud.applyBotChangeFiles = false;
    await launch(tester);
    await tester.tap(find.bySemanticsLabel('list-switcher'));
    await settle(tester);
    await tester.enterText(
      find.bySemanticsLabel('create-list-field'),
      'Groceries.bot.1',
    );
    await tester.tap(find.bySemanticsLabel('create-list'));
    await settle(tester);
    expect(find.text('Groceries'), findsWidgets);
    expect(await filenames(), ['Groceries.md', 'bot-instructions.md']);

    await tester.tap(find.bySemanticsLabel('list-switcher'));
    await settle(tester);
    await tester.enterText(find.bySemanticsLabel('create-list-field'), 'Party');
    await tester.tap(find.bySemanticsLabel('create-list'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('list-switcher'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('rename-list:Party'));
    await settle(tester);
    await tester.enterText(
      find.bySemanticsLabel('rename-list-field'),
      'Shop.bot.2',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    expect(find.text('Party'), findsWidgets);
    expect(await filenames(), [
      'Groceries.md',
      'Party.md',
      'bot-instructions.md',
    ]);
  });

  testWidgets('a change file updates the named list', (tester) async {
    await launch(tester);
    await addItem(tester, 'milk');
    await tester.tap(find.bySemanticsLabel('list-switcher'));
    await settle(tester);
    await tester.enterText(find.bySemanticsLabel('create-list-field'), 'Party');
    await tester.tap(find.bySemanticsLabel('create-list'));
    await settle(tester);
    await plant('Party.bot.k', 'add chips\n');
    await tester.tap(find.bySemanticsLabel('sync-now'));
    await settle(tester);
    expect(find.bySemanticsLabel('item:chips'), findsOneWidget);
    expect(await listText('Party.md'), '- [ ] chips\n');
    expect(await listText('Groceries.md'), '- [ ] milk\n');
    expect(await filenames(), [
      'Groceries.md',
      'Party.md',
      'bot-instructions.md',
    ]);
  });

  testWidgets('a change file for a missing list stays in the folder', (
    tester,
  ) async {
    await launch(tester);
    await addItem(tester, 'milk');
    await plant('Party.bot.missing', 'add chips\n');
    await tester.tap(find.bySemanticsLabel('sync-now'));
    await settle(tester);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
    expect(find.bySemanticsLabel('item:chips'), findsNothing);
    expect(await listText('Groceries.md'), '- [ ] milk\n');
    expect(await listText('Party.bot.missing.md'), 'add chips\n');
    expect(find.bySemanticsLabel('sync-banner'), findsOneWidget);
    expect(await filenames(), [
      'Groceries.md',
      'Party.bot.missing.md',
      'bot-instructions.md',
    ]);
  });

  testWidgets('two lists with the same name block a change file', (
    tester,
  ) async {
    await launch(tester);
    await addItem(tester, 'milk');
    final extra = await cloud.createMarkdown('Groceries');
    final extraBody = await cloud.read(extra.id);
    await cloud.write(extra.id, '- [ ] oats\n', extraBody.etag);
    await plant('Groceries.bot.rm', 'remove milk\n');
    await tester.tap(find.bySemanticsLabel('sync-now'));
    await settle(tester);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
    expect(await listText('Groceries.bot.rm.md'), 'remove milk\n');
    expect(find.bySemanticsLabel('sync-banner'), findsOneWidget);
  });
}
