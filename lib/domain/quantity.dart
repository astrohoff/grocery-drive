final _trailingQuantity = RegExp(
  r'^(.*?)\s+\(('
  r'\d+\s+\d+/\d+'
  r'|\d+/\d+'
  r'|\d+(?:\.\d+)?'
  r')(?:\s+([^)]*))?\)\s*$',
);

final _typedQuantity = RegExp(
  r'^('
  r'\d+\s+\d+/\d+'
  r'|\d+/\d+'
  r'|\d+(?:\.\d+)?'
  r')(?:\s+([^()]+))?$',
);

/// Grocery name with a trailing quantity parenthetical removed.
///
/// `milk (organic)` stays whole because `organic` is not a quantity.
String itemName(String line) {
  final match = _trailingQuantity.firstMatch(line.trim());
  if (match == null) return line.trim();
  final name = match.group(1)!.trim();
  if (name.isEmpty) return line.trim();
  return name;
}

/// `2 gal`, `3`, `1/2 lb`, or empty when the line has no quantity.
String quantityLabel(String line) {
  final match = _trailingQuantity.firstMatch(line.trim());
  if (match == null) return '';
  if (match.group(1)!.trim().isEmpty) return '';
  return _label(match.group(2)!, match.group(3));
}

/// Stored checklist line. [quantity] is what was typed, such as `2 gal`.
///
/// An empty quantity keeps [name]. A typed value that does not start with a
/// number is ignored. A typed quantity replaces one already present on [name].
String composeItemLine(String name, String quantity) {
  final typed = quantity.trim().replaceAll(RegExp(r'\s+'), ' ');
  final match = _typedQuantity.firstMatch(typed);
  if (match == null) return name.trim();
  final bare = itemName(name);
  return '$bare (${_label(match.group(1)!, match.group(2))})';
}

String _label(String amount, String? unit) {
  final cleaned = unit?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  if (cleaned.isEmpty) return amount;
  return '$amount $cleaned';
}
