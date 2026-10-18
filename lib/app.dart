import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/cloud_accounts.dart';
import 'data/cloud_store.dart';
import 'data/local_cache.dart';
import 'domain/categorizer.dart';
import 'list_controller.dart';
import 'ui/list_screen.dart';
import 'ui/settings_screen.dart';

const grocerySeed = Color(0xFF1F7A4D);
const groceryPaper = Color(0xFFF6F3EC);

ThemeData groceryLightTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: grocerySeed),
    scaffoldBackgroundColor: groceryPaper,
    useMaterial3: true,
  );
}

ThemeData groceryDarkTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: grocerySeed,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}

class GroceryApp extends StatelessWidget {
  const GroceryApp({
    required this.cloud,
    required this.cacheDirectory,
    this.accounts,
    this.onAccountChanged,
    this.onSettings,
    super.key,
  });

  final CloudStore cloud;
  final Directory cacheDirectory;
  final CloudAccounts? accounts;
  final Future<void> Function()? onAccountChanged;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grocery Drive',
      theme: groceryLightTheme(),
      darkTheme: groceryDarkTheme(),
      themeMode: ThemeMode.system,
      home: _ListHome(
        cloud: cloud,
        cacheDirectory: cacheDirectory,
        accounts: accounts,
        onAccountChanged: onAccountChanged,
        onSettings: onSettings,
      ),
    );
  }
}

class _ListHome extends StatefulWidget {
  const _ListHome({
    required this.cloud,
    required this.cacheDirectory,
    this.accounts,
    this.onAccountChanged,
    this.onSettings,
  });

  final CloudStore cloud;
  final Directory cacheDirectory;
  final CloudAccounts? accounts;
  final Future<void> Function()? onAccountChanged;
  final VoidCallback? onSettings;

  @override
  State<_ListHome> createState() => _ListHomeState();
}

class _ListHomeState extends State<_ListHome> {
  ListController? _controller;
  Object? _error;
  String? _provider;
  var _settings = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // cache: false so a second widget test does not await a Future that
      // completed inside the previous test's fake-async zone.
      final source = await rootBundle.loadString(
        'assets/aisles.json',
        cache: false,
      );
      final instructions = await rootBundle.loadString(
        'assets/bot_instructions.md',
        cache: false,
      );
      final controller = ListController(
        cloud: widget.cloud,
        cache: LocalCache(widget.cacheDirectory),
        categorizer: Categorizer.fromJsonString(source),
        instructionsMarkdown: instructions,
      );
      await controller.open();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final accounts = widget.accounts;
    String? provider;
    if (accounts != null) {
      try {
        provider = await accounts.provider();
      } on Object {
        provider = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _provider = provider;
      _settings = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Scaffold(body: Center(child: Text('$error')));
    }
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: Text('Loading')));
    }
    final accounts = widget.accounts;
    if (_settings && accounts != null) {
      return SettingsScreen(
        accounts: accounts,
        providerName: _provider,
        controller: controller,
        onSignedIn: () {
          widget.onAccountChanged?.call();
        },
        onClose: () => setState(() => _settings = false),
      );
    }
    return ListScreen(
      controller: controller,
      onSettings: accounts == null ? widget.onSettings : _openSettings,
    );
  }
}
