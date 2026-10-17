import 'dart:convert';

import 'aisle.dart';
import 'quantity.dart';

class Categorizer {
  Categorizer._(this.aisles, this._phrases);

  final List<Aisle> aisles;
  final Map<String, String> _phrases;

  static Categorizer fromJsonString(String source) {
    final json = jsonDecode(source) as Map;
    final aisles = [
      for (final raw in json['aisles'] as List)
        Aisle(
          id: (raw as Map)['id'] as String,
          name: raw['name'] as String,
        ),
    ];
    final phrases = <String, String>{};
    for (final raw in json['phrases'] as List) {
      final map = raw as Map;
      final text = _normalize(map['text'] as String);
      if (text.isEmpty) continue;
      phrases.putIfAbsent(text, () => map['aisle'] as String);
    }
    return Categorizer._(aisles, phrases);
  }

  String idFor(String item) {
    final tokens = _tokens(itemName(item));
    final full = _best(tokens, 0, _phrases);
    final dropped = tokens.isNotEmpty && _quantity.hasMatch(tokens.first)
        ? _best(tokens.sublist(1), 1, _phrases)
        : null;
    return _prefer(full, dropped) ?? 'other';
  }

  String nameFor(String item) {
    final id = idFor(item);
    for (final aisle in aisles) {
      if (aisle.id == id) return aisle.name;
    }
    return 'Other';
  }
}

final _quantity = RegExp(r'^\d+(/\d+)?$');

String? _prefer(_Match? left, _Match? right) {
  if (left == null) return right?.aisle;
  if (right == null) return left.aisle;
  if (left.length != right.length) {
    return (left.length > right.length ? left : right).aisle;
  }
  return (left.start <= right.start ? left : right).aisle;
}

_Match? _best(List<String> tokens, int offset, Map<String, String> phrases) {
  final maxN = tokens.length < 4 ? tokens.length : 4;
  for (var length = maxN; length >= 1; length--) {
    for (var index = 0; index <= tokens.length - length; index++) {
      final aisle = phrases[tokens.sublist(index, index + length).join(' ')];
      if (aisle == null) continue;
      return _Match(length, index + offset, aisle);
    }
  }
  return null;
}

class _Match {
  const _Match(this.length, this.start, this.aisle);
  final int length;
  final int start;
  final String aisle;
}

List<String> _tokens(String input) {
  final normalized = _normalize(input);
  if (normalized.isEmpty) return const [];
  return normalized.split(' ');
}

String _normalize(String input) {
  final lower = input.toLowerCase();
  final buffer = StringBuffer();
  for (var i = 0; i < lower.length; i++) {
    final char = lower[i];
    final code = char.codeUnitAt(0);
    final digit = code >= 48 && code <= 57;
    final letter = code >= 97 && code <= 122;
    if (letter || digit) {
      buffer.write(char);
    } else if (char == '/' &&
        i > 0 &&
        i + 1 < lower.length &&
        _isDigit(lower[i - 1]) &&
        _isDigit(lower[i + 1])) {
      buffer.write('/');
    } else {
      buffer.write(' ');
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool _isDigit(String char) {
  final code = char.codeUnitAt(0);
  return code >= 48 && code <= 57;
}
