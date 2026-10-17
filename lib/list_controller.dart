import 'package:flutter/foundation.dart';

import 'data/cloud_store.dart';
import 'data/local_cache.dart';
import 'domain/bot_instructions.dart';
import 'domain/categorizer.dart';
import 'domain/item.dart';
import 'domain/markdown_list.dart';
import 'domain/merge.dart';

class GroceryListSummary {
  const GroceryListSummary({required this.id, required this.name});

  final String id;
  final String name;
}

class ListController extends ChangeNotifier {
  ListController({
    required this.cloud,
    required this.cache,
    required this.categorizer,
    required this.instructionsMarkdown,
  });

  final CloudStore cloud;
  final LocalCache cache;
  final Categorizer categorizer;
  final String instructionsMarkdown;

  bool ready = false;
  bool synced = true;
  String title = '';
  String? currentId;
  List<Item> items = const [];

  List<GroceryListSummary> get lists => [
    for (final file in cache.files.values)
      GroceryListSummary(id: file.id, name: _displayName(file.name)),
  ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Future<void> open() async {
    await cache.load();
    try {
      await _refreshFromCloud();
      synced = true;
    } on CloudException {
      synced = false;
    }
    _show(cache.lastOpenedId ?? _fallbackId());
    ready = true;
    notifyListeners();
    if (synced && currentId != null) await sync();
  }

  Future<void> sync() async {
    final current = _current;
    if (current == null) return;
    try {
      await _refreshFromCloud();
      final remote = await cloud.read(current.id);
      if (remote.etag != current.etag || current.localText != current.baseText) {
        await _applyRemote(current, remote);
      }
      synced = true;
    } on CloudException {
      synced = false;
    }
    await cache.save();
    _show(current.id);
    notifyListeners();
  }

  void addItem(String raw) {
    final name = raw.trim();
    if (name.isEmpty || name.contains('\n')) return;
    final id = name.toLowerCase();
    if (items.any((item) => item.name.trim().toLowerCase() == id)) return;
    items = [...items, Item(name)];
    _commit();
  }

  void toggle(String name) {
    final id = name.trim().toLowerCase();
    items = [
      for (final item in items)
        if (item.name.trim().toLowerCase() == id)
          Item(item.name, checked: !item.checked)
        else
          item,
    ];
    _commit();
  }

  void renameItem(String from, String raw) {
    final name = raw.trim();
    if (name.isEmpty || name.contains('\n')) return;
    final id = from.trim().toLowerCase();
    items = [
      for (final item in items)
        if (item.name.trim().toLowerCase() == id)
          Item(name, checked: item.checked)
        else
          item,
    ];
    _commit();
  }

  void deleteItem(String name) {
    final id = name.trim().toLowerCase();
    items = [
      for (final item in items)
        if (item.name.trim().toLowerCase() != id) item,
    ];
    _commit();
  }

  void clearCompleted() {
    items = [for (final item in items) if (!item.checked) item];
    _commit();
  }

  Future<void> createList(String raw) async {
    final name = raw.trim();
    if (name.isEmpty || name.contains('\n') || isReservedListName(name)) return;
    try {
      final created = await cloud.createMarkdown(name);
      final body = await cloud.read(created.id);
      cache.files[created.id] = CachedList(
        id: created.id,
        name: created.name,
        etag: body.etag,
        baseText: body.text,
        localText: body.text,
      );
      cache.lastOpenedId = created.id;
      synced = true;
      _show(created.id);
    } on CloudException {
      synced = false;
    }
    await cache.save();
    notifyListeners();
  }

  Future<void> renameList(String id, String raw) async {
    final name = raw.trim();
    final file = cache.files[id];
    if (file == null ||
        name.isEmpty ||
        name.contains('\n') ||
        isReservedListName(name)) {
      return;
    }
    try {
      await cloud.rename(id, name);
      file.name = name.toLowerCase().endsWith('.md') ? name : '$name.md';
      synced = true;
    } on CloudException {
      synced = false;
    }
    _show(currentId);
    await cache.save();
    notifyListeners();
  }

  Future<void> deleteList(String id) async {
    final file = cache.files[id];
    if (file == null) return;
    try {
      await cloud.delete(id);
      cache.files.remove(id);
      if (cache.lastOpenedId == id || currentId == id) {
        cache.lastOpenedId = _fallbackId();
      }
      synced = true;
      _show(cache.lastOpenedId);
    } on CloudException {
      synced = false;
    }
    await cache.save();
    notifyListeners();
  }

  void openList(String id) {
    cache.lastOpenedId = id;
    _show(id);
    cache.save();
    notifyListeners();
  }

  void _commit() {
    final current = _current;
    if (current == null) return;
    current.localText = writeMarkdown(items);
    cache.save();
    notifyListeners();
    _push(current);
  }

  Future<void> _push(CachedList current) async {
    try {
      final etag = await cloud.write(
        current.id,
        current.localText,
        current.etag,
      );
      current.etag = etag;
      current.baseText = current.localText;
      synced = true;
    } on CloudException {
      synced = false;
    }
    await cache.save();
    notifyListeners();
  }

  Future<void> _refreshFromCloud() async {
    await cloud.ensureRootFolder();
    final remoteFiles = await cloud.listMarkdownFiles();
    final seen = <String>{};
    for (final file in remoteFiles) {
      if (isBotInstructionsFile(file.name)) continue;
      seen.add(file.id);
      final existing = cache.files[file.id];
      if (existing == null) {
        final body = await cloud.read(file.id);
        cache.files[file.id] = CachedList(
          id: file.id,
          name: file.name,
          etag: body.etag,
          baseText: body.text,
          localText: body.text,
        );
      } else {
        existing.name = file.name;
      }
    }
    cache.files.removeWhere(
      (id, file) =>
          isBotInstructionsFile(file.name) || (!seen.contains(id) && id != currentId),
    );
    await _ensureBotInstructions(remoteFiles);
  }

  Future<void> _ensureBotInstructions(List<CloudFile> remoteFiles) async {
    final existing = [
      for (final file in remoteFiles)
        if (isBotInstructionsFile(file.name)) file,
    ];
    if (existing.isEmpty) {
      final created = await cloud.createMarkdown('bot-instructions');
      final body = await cloud.read(created.id);
      await cloud.write(created.id, instructionsMarkdown, body.etag);
      return;
    }
    for (final file in existing) {
      final body = await cloud.read(file.id);
      if (body.text == instructionsMarkdown) continue;
      try {
        await cloud.write(file.id, instructionsMarkdown, body.etag);
      } on CloudConflict {
        final again = await cloud.read(file.id);
        if (again.text != instructionsMarkdown) {
          await cloud.write(file.id, instructionsMarkdown, again.etag);
        }
      }
    }
  }

  Future<void> _applyRemote(
    CachedList current,
    CloudText remote, {
    bool retry = true,
  }) async {
    final merged = merge(
      parseMarkdown(current.baseText),
      parseMarkdown(current.localText),
      parseMarkdown(remote.text),
    );
    final mergedText = writeMarkdown(merged);
    current.localText = mergedText;
    if (mergedText == remote.text) {
      current.baseText = remote.text;
      current.etag = remote.etag;
      return;
    }
    try {
      final etag = await cloud.write(current.id, mergedText, remote.etag);
      current.etag = etag;
      current.baseText = mergedText;
      synced = true;
    } on CloudConflict {
      if (!retry) {
        synced = false;
        return;
      }
      final again = await cloud.read(current.id);
      await _applyRemote(current, again, retry: false);
    } on CloudException {
      synced = false;
    }
  }

  void _show(String? id) {
    final file = id == null ? null : cache.files[id];
    if (file == null) {
      currentId = null;
      title = '';
      items = const [];
      return;
    }
    currentId = file.id;
    cache.lastOpenedId = file.id;
    title = _displayName(file.name);
    items = parseMarkdown(file.localText);
  }

  CachedList? get _current {
    final id = currentId;
    if (id == null) return null;
    return cache.files[id];
  }

  String? _fallbackId() {
    if (cache.files.isEmpty) return null;
    return cache.files.values.first.id;
  }

  String _displayName(String filename) {
    return filename.toLowerCase().endsWith('.md')
        ? filename.substring(0, filename.length - 3)
        : filename;
  }
}
