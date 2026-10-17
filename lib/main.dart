import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/fake_cloud_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const cloudName = String.fromEnvironment('CLOUD', defaultValue: 'live');
  if (cloudName != 'fake') {
    runApp(const LiveCloudPlaceholder());
    return;
  }
  final support = await getApplicationSupportDirectory();
  runApp(GroceryApp(cloud: FakeCloudStore(), cacheDirectory: support));
}
