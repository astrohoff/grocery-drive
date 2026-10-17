import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/fake_cloud_store.dart';
import 'live_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const cloudName = String.fromEnvironment('CLOUD', defaultValue: 'live');
  if (cloudName != 'fake') {
    runApp(const LiveApp());
    return;
  }
  final support = await _cacheDirectory();
  runApp(
    GroceryApp(
      cloud: FakeCloudStore(directory: support),
      cacheDirectory: support,
    ),
  );
}

Future<Directory> _cacheDirectory() async {
  const override = String.fromEnvironment('GROCERY_CACHE_DIR');
  if (override.isNotEmpty) return Directory(override);
  return getApplicationSupportDirectory();
}
