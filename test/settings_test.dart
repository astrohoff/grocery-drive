import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/app.dart';
import 'package:grocery_drive/data/cloud_accounts.dart';
import 'package:grocery_drive/data/fake_cloud_store.dart';
import 'package:grocery_drive/data/local_cache.dart';
import 'package:grocery_drive/list_controller.dart';
import 'package:grocery_drive/ui/list_screen.dart';
import 'package:grocery_drive/ui/settings_screen.dart';

void main() {
  late Directory cacheDir;
  late FakeCloudStore cloud;

  setUp(() {
    cacheDir = Directory.systemTemp.createTempSync('grocery_drive_settings');
    cloud = FakeCloudStore();
  });

  tearDown(() {
    if (cacheDir.existsSync()) cacheDir.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> until(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return;
    }
  }

  Future<ListController> openController() async {
    final controller = ListController(
      cloud: cloud,
      cache: LocalCache(cacheDir),
      categorizer: await loadAisleCatalog(rootBundle),
      instructionsMarkdown: await rootBundle.loadString(
        'assets/bot_instructions.md',
        cache: false,
      ),
    );
    await controller.open();
    return controller;
  }

  Future<String> seedMarket() async {
    await cloud.ensureRootFolder();
    final groceries = await cloud.createMarkdown('Groceries');
    final body = await cloud.read(groceries.id);
    await cloud.write(groceries.id, '- [ ] milk\n', body.etag);
    final market = await cloud.createRootFolder('Market');
    await cloud.useFolder(market.id);
    final marketList = await cloud.createMarkdown('Groceries');
    final marketBody = await cloud.read(marketList.id);
    await cloud.write(marketList.id, '- [ ] bread\n', marketBody.etag);
    final home = (await cloud.listRootFolders()).singleWhere(
      (folder) => folder.name == 'Groceries',
    );
    await cloud.useFolder(home.id);
    return groceries.id;
  }

  Future<void> tall(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> showSettings(
    WidgetTester tester,
    ListController controller, {
    String? providerName,
  }) async {
    await tall(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          accounts: CloudAccounts(),
          providerName: providerName,
          controller: controller,
          onSignedIn: () {},
        ),
      ),
    );
  }

  testWidgets('settings names the signed-in provider', (tester) async {
    await tall(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          accounts: CloudAccounts(),
          providerName: 'google',
          onSignedIn: () {},
        ),
      ),
    );
    expect(find.text('Signed in to Google Drive'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          accounts: CloudAccounts(),
          providerName: 'microsoft',
          onSignedIn: () {},
        ),
      ),
    );
    expect(find.text('Signed in to OneDrive'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(accounts: CloudAccounts(), onSignedIn: () {}),
      ),
    );
    expect(find.text('Not signed in'), findsOneWidget);
  });

  testWidgets('settings shows the MIT notice', (tester) async {
    await tall(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(accounts: CloudAccounts(), onSignedIn: () {}),
      ),
    );
    expect(
      find.text('Grocery Drive is released under the MIT License.'),
      findsOneWidget,
    );
    expect(find.text('Copyright (c) 2026 astrohoff'), findsOneWidget);
  });

  testWidgets('choosing Market shows bread and leaves the Groceries file', (
    tester,
  ) async {
    final milkId = await seedMarket();
    final controller = await openController();
    await showSettings(tester, controller, providerName: 'microsoft');
    await until(tester, find.bySemanticsLabel('folder:Market'));
    await tester.tap(find.bySemanticsLabel('folder:Market'));
    await settle(tester);
    expect(
      find.descendant(
        of: find.bySemanticsLabel('folder:Market'),
        matching: find.text('Current folder'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.bySemanticsLabel('folder:Groceries'),
        matching: find.text('Current folder'),
      ),
      findsNothing,
    );

    await tester.pumpWidget(
      MaterialApp(home: ListScreen(controller: controller)),
    );
    await settle(tester);
    expect(find.bySemanticsLabel('item:bread'), findsOneWidget);
    expect(find.bySemanticsLabel('item:milk'), findsNothing);
    expect((await cloud.read(milkId)).text, '- [ ] milk\n');
  });

  testWidgets('Use Groceries folder returns to the existing Groceries folder', (
    tester,
  ) async {
    final milkId = await seedMarket();
    final controller = await openController();
    await showSettings(tester, controller);
    await until(tester, find.bySemanticsLabel('folder:Market'));
    await tester.tap(find.bySemanticsLabel('folder:Market'));
    await settle(tester);
    expect(
      find.descendant(
        of: find.bySemanticsLabel('folder:Market'),
        matching: find.text('Current folder'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel('create-groceries-folder'));
    await settle(tester);
    expect(
      find.descendant(
        of: find.bySemanticsLabel('folder:Groceries'),
        matching: find.text('Current folder'),
      ),
      findsOneWidget,
    );
    expect(
      (await cloud.listRootFolders())
          .where((folder) => folder.name == 'Groceries')
          .length,
      1,
    );
    await tester.pumpWidget(
      MaterialApp(home: ListScreen(controller: controller)),
    );
    await settle(tester);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
    expect(find.bySemanticsLabel('item:bread'), findsNothing);
    expect((await cloud.read(milkId)).text, '- [ ] milk\n');
  });

  testWidgets('an unsynced edit stays in the current folder', (tester) async {
    await cloud.ensureRootFolder();
    await cloud.createRootFolder('Market');
    final controller = await openController();
    await showSettings(tester, controller);
    await until(tester, find.bySemanticsLabel('folder:Market'));
    cloud.online = false;
    controller.addItem('milk');
    await tester.pump();
    await until(tester, find.bySemanticsLabel('folder:Market'));
    await tester.tap(find.bySemanticsLabel('folder:Market'));
    await settle(tester);
    expect(
      find.descendant(
        of: find.bySemanticsLabel('folder:Groceries'),
        matching: find.text('Current folder'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.bySemanticsLabel('folder:Market'),
        matching: find.text('Current folder'),
      ),
      findsNothing,
    );
    await tester.pumpWidget(
      MaterialApp(home: ListScreen(controller: controller)),
    );
    await settle(tester);
    expect(find.bySemanticsLabel('item:milk'), findsOneWidget);
  });

  testWidgets('settings sync writes a local edit', (tester) async {
    final controller = await openController();
    cloud.online = false;
    controller.addItem('juice');
    cloud.online = true;
    await showSettings(tester, controller);
    await until(tester, find.bySemanticsLabel('settings-sync'));
    await tester.tap(find.bySemanticsLabel('settings-sync'));
    await settle(tester);
    final file = (await cloud.listMarkdownFiles()).singleWhere(
      (item) => item.name == 'Groceries.md',
    );
    expect((await cloud.read(file.id)).text, '- [ ] juice\n');
  });
}
