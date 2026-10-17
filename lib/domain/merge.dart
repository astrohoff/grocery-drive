import 'item.dart';

List<Item> merge(List<Item> base, List<Item> local, List<Item> remote) {
  final baseSide = _index(base);
  final localSide = _index(local);
  final remoteSide = _index(remote);
  final result = <Item>[];
  final used = <String>{};

  void add(String id, bool checked) {
    if (!used.add(id)) return;
    final name = localSide.names[id] ?? remoteSide.names[id] ?? baseSide.names[id]!;
    result.add(Item(name, checked: checked));
  }

  for (final id in baseSide.order) {
    final inLocal = localSide.checked.containsKey(id);
    final inRemote = remoteSide.checked.containsKey(id);
    final baseChecked = baseSide.checked[id]!;
    if (inLocal && inRemote) {
      final localChecked = localSide.checked[id]!;
      final remoteChecked = remoteSide.checked[id]!;
      if (localChecked == remoteChecked) {
        add(id, localChecked);
      } else if (localChecked == baseChecked) {
        add(id, remoteChecked);
      } else if (remoteChecked == baseChecked) {
        add(id, localChecked);
      } else {
        add(id, true);
      }
    } else if (!inLocal && inRemote) {
      final remoteChecked = remoteSide.checked[id]!;
      if (remoteChecked != baseChecked) add(id, remoteChecked);
    } else if (inLocal && !inRemote) {
      final localChecked = localSide.checked[id]!;
      if (localChecked != baseChecked) add(id, localChecked);
    }
  }

  for (final id in localSide.order) {
    if (baseSide.checked.containsKey(id)) continue;
    if (remoteSide.checked.containsKey(id)) {
      final localChecked = localSide.checked[id]!;
      final remoteChecked = remoteSide.checked[id]!;
      add(id, localChecked == remoteChecked ? localChecked : true);
    } else {
      add(id, localSide.checked[id]!);
    }
  }
  for (final id in remoteSide.order) {
    if (baseSide.checked.containsKey(id) || localSide.checked.containsKey(id)) {
      continue;
    }
    add(id, remoteSide.checked[id]!);
  }
  return result;
}

class _Side {
  _Side(this.order, this.names, this.checked);

  final List<String> order;
  final Map<String, String> names;
  final Map<String, bool> checked;
}

_Side _index(List<Item> items) {
  final order = <String>[];
  final names = <String, String>{};
  final checked = <String, bool>{};
  for (final item in items) {
    final name = item.name.trim();
    final id = name.toLowerCase();
    final previous = checked[id];
    if (previous == null) {
      order.add(id);
      names[id] = name;
      checked[id] = item.checked;
    } else if (item.checked && !previous) {
      checked[id] = true;
    }
  }
  return _Side(order, names, checked);
}
