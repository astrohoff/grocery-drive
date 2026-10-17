import 'dart:convert';
import 'dart:io';

import 'package:grocery_drive/data/cloud_store.dart';
import 'package:grocery_drive/data/google_drive_store.dart';
import 'package:grocery_drive/data/refresh_token.dart';

Future<void> main() async {
  final secret = _read('secrets/google.json');
  final refresh = secret['refresh_token'] ?? '';
  final clientId = secret['client_id'] ?? '';
  if (clientId.isEmpty) {
    stderr.writeln('secrets/google.json has no client_id.');
    exit(1);
  }
  if (refresh.isEmpty) {
    stderr.writeln(
      'secrets/google.json has no refresh_token. Sign in once from the repo root.',
    );
    exit(1);
  }
  final access = await refreshAccessToken(
    tokenUrl: 'https://oauth2.googleapis.com/token',
    clientId: clientId,
    refreshToken: refresh,
    clientSecret: secret['client_secret'],
  );
  final store = GoogleDriveStore(accessToken: () async => access.accessToken);
  await _roundTrip(store);
}

Future<void> _roundTrip(CloudStore store) async {
  await store.ensureRootFolder();
  final files = await store.listMarkdownFiles();
  for (final file in files) {
    if (file.name == 'Roundtrip.md') await store.delete(file.id);
  }
  final created = await store.createMarkdown('Roundtrip');
  final current = await store.read(created.id);
  await store.write(created.id, '- [ ] apples\n', current.etag);
  final again = await store.read(created.id);
  if (again.text != '- [ ] apples\n') {
    stderr.writeln('checklist did not match');
    try {
      await store.delete(created.id);
    } on Object {
      // The mismatch is already reported.
    }
    exit(1);
  }
  await store.delete(created.id);
  stdout.writeln('OK');
}

Map<String, String> _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('$path is missing.');
    exit(1);
  }
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) {
    stderr.writeln('$path is not a JSON object.');
    exit(1);
  }
  return {
    for (final entry in decoded.entries)
      if (entry.value != null) entry.key.toString(): entry.value.toString(),
  };
}
