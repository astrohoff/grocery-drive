import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/cloud_store.dart';
import 'data/local_cache.dart';
import 'domain/categorizer.dart';
import 'list_controller.dart';
import 'ui/list_screen.dart';

class GroceryApp extends StatelessWidget {
  const GroceryApp({
    required this.cloud,
    required this.cacheDirectory,
    super.key,
  });

  final CloudStore cloud;
  final Directory cacheDirectory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grocery Drive',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F7A4D)),
        useMaterial3: true,
      ),
      home: _ListHome(cloud: cloud, cacheDirectory: cacheDirectory),
    );
  }
}

class _ListHome extends StatefulWidget {
  const _ListHome({required this.cloud, required this.cacheDirectory});

  final CloudStore cloud;
  final Directory cacheDirectory;

  @override
  State<_ListHome> createState() => _ListHomeState();
}

class _ListHomeState extends State<_ListHome> {
  ListController? _controller;
  Object? _error;

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
    return ListScreen(controller: controller);
  }
}

class LiveCloudPlaceholder extends StatelessWidget {
  const LiveCloudPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Google Drive and OneDrive are not connected yet. '
              'Run with --dart-define=CLOUD=fake to use a local fake cloud.',
            ),
          ),
        ),
      ),
    );
  }
}
