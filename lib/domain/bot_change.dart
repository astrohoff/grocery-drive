import 'item.dart';
import 'markdown_list.dart';
import 'merge.dart';

final _botChangeFile = RegExp(r'^(.+)\.bot\.(.+)\.md$', caseSensitive: false);

final _operation = RegExp(
  r'^(add|remove|check|uncheck)\s+(\S(?:.*\S)?)\s*$',
  caseSensitive: false,
);

/// The list file a `{List}.bot.{token}.md` change file applies to.
/// The list name is the text before the last `.bot.`.
String? botChangeListFilename(String filename) {
  final match = _botChangeFile.firstMatch(filename.trim());
  if (match == null) return null;
  final list = match.group(1)!.trim();
  final token = match.group(2)!.trim();
  if (list.isEmpty || token.isEmpty) return null;
  return '$list.md';
}

bool isBotChangeFile(String filename) =>
    botChangeListFilename(filename) != null;

/// The list after applying a Google Drive bot change file.
///
/// Operations apply to [cloud], so a remove can see an item this device
/// has not saved yet. Merge then keeps a local check over that remove.
/// A file of checkbox lines is the bot's whole list. An add that exists
/// only on [cloud] stays. An unchanged item the checklist omits is removed.
/// Returns null when [text] is neither operations nor a checklist.
List<Item>? mergedBotChange({
  required String text,
  required List<Item> base,
  required List<Item> local,
  required List<Item> cloud,
}) {
  final lines = _contentLines(text);
  if (lines.isEmpty) return merge(base, local, cloud);
  final operations = _operations(lines);
  if (operations != null) {
    return merge(base, local, _applyOperations(cloud, operations));
  }
  if (lines.every(isCheckboxLine)) {
    final withCloud = merge(base, local, cloud);
    final withBot = merge(base, local, parseMarkdown(text));
    return merge(base, withCloud, withBot);
  }
  return null;
}

List<String> _contentLines(String text) {
  final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return [
    for (final line in normalized.split('\n'))
      if (line.trim().isNotEmpty) line.trim(),
  ];
}

List<_Operation>? _operations(List<String> lines) {
  final operations = <_Operation>[];
  for (final line in lines) {
    final match = _operation.firstMatch(line);
    if (match == null) return null;
    operations.add(
      _Operation(match.group(1)!.toLowerCase(), match.group(2)!.trim()),
    );
  }
  return operations;
}

List<Item> _applyOperations(List<Item> items, List<_Operation> operations) {
  final next = [...items];
  for (final operation in operations) {
    final id = operation.name.toLowerCase();
    final index = next.indexWhere(
      (item) => item.name.trim().toLowerCase() == id,
    );
    final verb = operation.verb;
    if (verb == 'add') {
      if (index < 0) next.add(Item(operation.name));
    } else if (verb == 'remove') {
      if (index >= 0) next.removeAt(index);
    } else if (verb == 'check') {
      if (index >= 0) {
        next[index] = Item(next[index].name, checked: true);
      } else {
        next.add(Item(operation.name, checked: true));
      }
    } else if (verb == 'uncheck') {
      if (index >= 0) {
        next[index] = Item(next[index].name);
      } else {
        next.add(Item(operation.name));
      }
    }
  }
  return next;
}

class _Operation {
  const _Operation(this.verb, this.name);

  final String verb;
  final String name;
}
