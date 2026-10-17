import 'item.dart';

final _checkbox = RegExp(r'^\s*[-*]\s+\[([ xX])\]\s*(.*?)\s*$');

List<Item> parseMarkdown(String text) {
  final items = <Item>[];
  final seen = <String, int>{};
  final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  for (final line in lines) {
    final match = _checkbox.firstMatch(line);
    if (match == null) continue;
    final name = match.group(2)!.trim();
    if (name.isEmpty || name.contains('\n')) continue;
    final checked = match.group(1)!.toLowerCase() == 'x';
    final id = name.toLowerCase();
    final existing = seen[id];
    if (existing == null) {
      seen[id] = items.length;
      items.add(Item(name, checked: checked));
    } else if (checked && !items[existing].checked) {
      items[existing] = Item(items[existing].name, checked: true);
    }
  }
  return items;
}

String writeMarkdown(List<Item> items) {
  final collapsed = <String, Item>{};
  for (final item in items) {
    final name = item.name.trim();
    if (name.isEmpty || name.contains('\n') || name.contains('\r')) {
      throw ArgumentError('Item name must be one non-empty line.');
    }
    final id = name.toLowerCase();
    final previous = collapsed[id];
    if (previous == null) {
      collapsed[id] = Item(name, checked: item.checked);
    } else if (item.checked && !previous.checked) {
      collapsed[id] = Item(previous.name, checked: true);
    }
  }
  if (collapsed.isEmpty) return '';
  final lines = collapsed.values.map(
    (item) => item.checked ? '- [x] ${item.name}' : '- [ ] ${item.name}',
  );
  return '${lines.join('\n')}\n';
}
