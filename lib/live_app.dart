import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/cloud_accounts.dart';
import 'data/cloud_store.dart';
import 'ui/settings_screen.dart';

class LiveApp extends StatefulWidget {
  const LiveApp({super.key});

  @override
  State<LiveApp> createState() => _LiveAppState();
}

class _LiveAppState extends State<LiveApp> {
  final _accounts = CloudAccounts();
  Directory? _cache;
  CloudStore? _store;
  var _ready = false;
  var _settings = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final support = await getApplicationSupportDirectory();
    final cache = Directory('${support.path}${Platform.pathSeparator}live');
    if (!cache.existsSync()) cache.createSync(recursive: true);
    final store = await _accounts.openStore();
    if (!mounted) return;
    setState(() {
      _cache = cache;
      _store = store;
      _settings = store == null;
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _cache == null) {
      return const MaterialApp(
        home: Scaffold(body: Center(child: Text('Loading'))),
      );
    }
    final store = _store;
    if (_settings || store == null) {
      return MaterialApp(
        home: SettingsScreen(
          accounts: _accounts,
          onSignedIn: () async {
            final next = await _accounts.openStore();
            if (!mounted) return;
            setState(() {
              _store = next;
              _settings = next == null;
            });
          },
          onClose: store == null
              ? null
              : () => setState(() => _settings = false),
        ),
      );
    }
    return GroceryApp(
      cloud: store,
      cacheDirectory: _cache!,
      onSettings: () => setState(() => _settings = true),
    );
  }
}
