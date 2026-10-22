import 'package:flutter/foundation.dart';

import 'data/cloud_store.dart';
import 'data/local_cache.dart';
import 'domain/bot_change.dart';
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

  Future<void> _pending = Future<void>.value();
  var _closed = false;
  var _botChangeBlocked = false;
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
      await _openSavedFolder();
      synced = !_botChangeBlocked;
    } on CloudException catch (error) {
      // A folder id from the other account cannot be listed. Start fresh.
      if (error.message != 'missing folder') {
        synced = false;
      } else {
        cache.folderId = null;
        cache.files.clear();
        cache.lastOpenedId = null;
        currentId = null;
        try {
          await _refreshFromCloud();
          synced = !_botChangeBlocked;
        } on CloudException {
          synced = false;
        }
      }
    }
    final savedId = cache.lastOpenedId;
    _show(cache.files.containsKey(savedId) ? savedId : _fallbackId());
    ready = true;
    notifyListeners();
    if (synced && currentId != null) await sync();
  }

  Future<void> selectFolder(String id) async {
    final previous = _current;
    if (previous != null && previous.localText != previous.baseText) {
      await _push(previous);
      if (!synced) return;
    }
    try {
      await cloud.useFolder(id);
    } on CloudException {
      synced = false;
      notifyListeners();
      return;
    }
    cache.folderId = id;
    cache.files.clear();
    cache.lastOpenedId = null;
    currentId = null;
    try {
      await _refreshFromCloud();
      synced = !_botChangeBlocked;
    } on CloudException {
      synced = false;
    }
    _show(cache.lastOpenedId ?? _fallbackId());
    await cache.save();
    notifyListeners();
  }

  Future<void> sync() => _enqueue(_syncOnce);

  Future<void> _syncOnce() async {
    final current = _current;
    if (current == null) return;
    try {
      await _refreshFromCloud();
      final remote = await cloud.read(current.id);
      if (remote.etag != current.etag ||
          current.localText != current.baseText) {
        await _applyRemote(current, remote);
      }
      synced = !_botChangeBlocked;
    } on CloudException {
      synced = false;
    }
    await cache.save();
    _show(current.id);
    _notify();
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
    items = [
      for (final item in items)
        if (!item.checked) item,
    ];
    _commit();
  }

  Future<void> createList(String raw) async {
    final name = raw.trim();
    if (name.isEmpty || name.contains('\n') || isReservedListName(name)) return;
    if (_current != null) await sync();
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
    if (synced && currentId != null) await sync();
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
    final openedAnother = currentId == id;
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
    if (openedAnother && synced && currentId != null) await sync();
  }

  Future<void> openList(String id) async {
    if (id == currentId || _closed) return;
    if (_current != null) await sync();
    if (_closed) return;
    cache.lastOpenedId = id;
    _show(id);
    await cache.save();
    _notify();
    await sync();
  }

  void _commit() {
    final current = _current;
    if (current == null) return;
    current.localText = writeMarkdown(items);
    cache.save();
    _notify();
    _push(current);
  }

  Future<void> _push(CachedList current) => _enqueue(() => _send(current));

  Future<void> _send(CachedList current) async {
    final text = current.localText;
    try {
      final etag = await cloud.write(current.id, text, current.etag);
      current.etag = etag;
      current.baseText = text;
      synced = true;
    } on CloudException {
      if (_closed) return;
      synced = false;
    }
    await cache.save();
    _notify();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    if (_closed) return Future<void>.value();
    final run = _pending.then((_) => action());
    _pending = run.then((_) {}, onError: (_, _) {});
    return run;
  }

  void _notify() {
    if (_closed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }

  Future<void> _openSavedFolder() async {
    if (cache.folderId != null) {
      await cloud.useFolder(cache.folderId!);
    }
    await _refreshFromCloud();
  }

  Future<void> _refreshFromCloud() async {
    _botChangeBlocked = false;
    final folderId = await cloud.ensureRootFolder();
    cache.folderId = folderId;
    var remoteFiles = await cloud.listMarkdownFiles();
    if (!remoteFiles.any((file) => file.name == 'Groceries.md')) {
      await cloud.createMarkdown('Groceries');
      remoteFiles = await cloud.listMarkdownFiles();
    }
    final seen = <String>{};
    for (final file in remoteFiles) {
      if (isBotInstructionsFile(file.name)) continue;
      if (cloud.consumesBotChangeFiles && isBotChangeFile(file.name)) continue;
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
          isBotInstructionsFile(file.name) ||
          (cloud.consumesBotChangeFiles && isBotChangeFile(file.name)) ||
          (!seen.contains(id) && id != currentId),
    );
    if (cloud.consumesBotChangeFiles) {
      await _applyBotChangeFiles(remoteFiles);
    }
    await _ensureBotInstructions(remoteFiles);
  }

  Future<void> _applyBotChangeFiles(List<CloudFile> remoteFiles) async {
    final changes =
        remoteFiles.where((file) => isBotChangeFile(file.name)).toList()
          ..sort((a, b) {
            final byTime = a.modified.compareTo(b.modified);
            if (byTime != 0) return byTime;
            return a.name.compareTo(b.name);
          });
    final live = <String>{};
    for (final change in changes) {
      live.add(change.id);
      await _applyBotChangeFile(change);
    }
    cache.appliedBotChanges.removeWhere((id, _) => !live.contains(id));
  }

  Future<void> _applyBotChangeFile(CloudFile change) async {
    final listName = botChangeListFilename(change.name);
    if (listName == null) {
      _botChangeBlocked = true;
      return;
    }
    final matches = [
      for (final file in cache.files.values)
        if (file.name.toLowerCase() == listName.toLowerCase()) file,
    ];
    if (matches.length != 1) {
      _botChangeBlocked = true;
      return;
    }
    final list = matches.single;
    final CloudText changeBody;
    try {
      changeBody = await cloud.read(change.id);
    } on CloudException {
      _botChangeBlocked = true;
      return;
    }
    if (cache.appliedBotChanges[change.id] == changeBody.etag) {
      await _deleteBotChange(change.id);
      return;
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      final CloudText listBody;
      try {
        listBody = await cloud.read(list.id);
      } on CloudException {
        _botChangeBlocked = true;
        return;
      }
      final merged = mergedBotChange(
        text: changeBody.text,
        base: parseMarkdown(list.baseText),
        local: parseMarkdown(list.localText),
        cloud: parseMarkdown(listBody.text),
      );
      if (merged == null) {
        _botChangeBlocked = true;
        return;
      }
      final mergedText = writeMarkdown(merged);
      try {
        if (mergedText == listBody.text) {
          list.etag = listBody.etag;
          list.baseText = mergedText;
          list.localText = mergedText;
        } else {
          final etag = await cloud.write(list.id, mergedText, listBody.etag);
          list.etag = etag;
          list.baseText = mergedText;
          list.localText = mergedText;
        }
        cache.appliedBotChanges[change.id] = changeBody.etag;
        await _deleteBotChange(change.id);
        return;
      } on CloudConflict {
        if (attempt == 1) _botChangeBlocked = true;
      } on CloudException {
        _botChangeBlocked = true;
        return;
      }
    }
  }

  Future<void> _deleteBotChange(String id) async {
    try {
      await cloud.delete(id);
      cache.appliedBotChanges.remove(id);
    } on CloudException catch (error) {
      if (error.message == 'missing file') {
        cache.appliedBotChanges.remove(id);
        return;
      }
      _botChangeBlocked = true;
    }
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

  Future<bool> _applyRemote(
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
      return true;
    }
    try {
      final etag = await cloud.write(current.id, mergedText, remote.etag);
      current.etag = etag;
      current.baseText = mergedText;
      synced = true;
      return true;
    } on CloudConflict {
      if (!retry) {
        synced = false;
        return false;
      }
      final again = await cloud.read(current.id);
      return _applyRemote(current, again, retry: false);
    } on CloudException {
      synced = false;
      return false;
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
