import 'dart:io';

/// Mechanical bans for tests. This file is the source of those rules.
/// It does not decide whether a check is valuable. The review-tests skill does.
///
/// Flags, by rule name:
/// - no-expect: a test or testWidgets body with no expect(
/// - expect-bool: expect(true or expect(false
/// - weak-assertion: every expect in a test uses only isNull, isNotNull,
///   isEmpty, isNotEmpty, isTrue, isFalse, or isA<...>()
/// - skip-or-retry: skip:, retry:, or @Skip
/// - mock: mockito, when(, or verify(
/// - conditional-expect: an if or else branch that contains expect(, or a try
///   that contains expect( whose catch is empty or also contains expect(
/// - no-app-import: a test file that does not import package:grocery_drive/
/// - mirrored-call: an expect( whose actual and expected arguments call the
///   same function
///
/// greaterThanOrEqualTo is not a weak matcher. The phrase-count floor uses it.
void main() {
  final root = File(Platform.script.toFilePath()).parent.parent;
  final findings = <Finding>[];
  for (final dirName in ['test', 'integration_test']) {
    final dir = Directory.fromUri(root.uri.resolve('$dirName/'));
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      findings.addAll(scanFile(entity, root));
    }
  }
  findings.sort((a, b) {
    final byPath = a.path.compareTo(b.path);
    if (byPath != 0) return byPath;
    final byLine = a.line.compareTo(b.line);
    if (byLine != 0) return byLine;
    return a.rule.compareTo(b.rule);
  });
  if (findings.isEmpty) {
    stdout.writeln('deslop: ok');
    exit(0);
  }
  for (final finding in findings) {
    stdout.writeln(
      '${finding.path}:${finding.line}: ${finding.rule}: ${finding.detail}',
    );
  }
  exit(1);
}

class Finding {
  Finding(this.path, this.line, this.rule, this.detail);
  final String path;
  final int line;
  final String rule;
  final String detail;
}

List<Finding> scanFile(File file, Directory root) {
  final source = file.readAsStringSync();
  final relative = _relative(file.path, root.path);
  final findings = <Finding>[];
  if (!RegExp(
    r'''^\s*import\s+['"]package:grocery_drive/''',
    multiLine: true,
  ).hasMatch(source)) {
    findings.add(
      Finding(relative, 1, 'no-app-import', 'file does not import the app'),
    );
  }

  final code = stripNonCode(source);
  findings.addAll(_scanCalls(code, relative));

  final invocation = RegExp(r'\b(testWidgets|test)\s*\(');
  for (final match in invocation.allMatches(code)) {
    final open = match.end - 1;
    final close = matchDelimiter(code, open, '(', ')');
    if (close < 0) continue;
    final call = code.substring(match.start, close + 1);
    final callLine = lineOf(code, match.start);
    if (RegExp(r'\bskip\s*:').hasMatch(call)) {
      findings.add(Finding(relative, callLine, 'skip-or-retry', 'skip:'));
    }
    if (RegExp(r'\bretry\s*:').hasMatch(call)) {
      findings.add(Finding(relative, callLine, 'skip-or-retry', 'retry:'));
    }
    final body = _callbackBody(code, open, close);
    if (body == null) continue;
    final bodyText = code.substring(body.start, body.end);
    if (!bodyText.contains('expect(')) {
      findings.add(
        Finding(relative, callLine, 'no-expect', 'test body has no expect('),
      );
    } else if (_onlyWeakExpects(bodyText)) {
      findings.add(
        Finding(
          relative,
          callLine,
          'weak-assertion',
          'every expect uses a weak matcher',
        ),
      );
    }
    findings.addAll(_expectFindings(bodyText, relative, body.start, code));
    findings.addAll(_controlFindings(bodyText, relative, body.start, code));
  }
  return findings;
}

void _addFileLevel(String code, String relative, List<Finding> findings) {
  if (code.contains('@Skip')) {
    findings.add(
      Finding(relative, lineOf(code, code.indexOf('@Skip')), 'skip-or-retry', '@Skip'),
    );
  }
}

List<Finding> _scanCalls(String code, String relative) {
  final findings = <Finding>[];
  _addFileLevel(code, relative, findings);
  final patterns = <String, RegExp>{
    'mockito': RegExp(r'\bmockito\b'),
    'when(': RegExp(r'\bwhen\s*\('),
    'verify(': RegExp(r'\bverify\s*\('),
  };
  for (final entry in patterns.entries) {
    final match = entry.value.firstMatch(code);
    if (match == null) continue;
    findings.add(
      Finding(relative, lineOf(code, match.start), 'mock', entry.key),
    );
  }
  final boolExpect = RegExp(r'\bexpect\s*\(\s*(true|false)\s*[,)]');
  for (final match in boolExpect.allMatches(code)) {
    findings.add(
      Finding(
        relative,
        lineOf(code, match.start),
        'expect-bool',
        'expect(${match.group(1)})',
      ),
    );
  }
  return findings;
}

class _Span {
  _Span(this.start, this.end);
  final int start;
  final int end;
}

_Span? _callbackBody(String code, int openParen, int closeParen) {
  final header = code.substring(openParen, closeParen);
  final braced = RegExp(r'\)\s*(?:async|sync\*)?\s*\{').firstMatch(header);
  if (braced != null) {
    final brace = openParen + braced.end - 1;
    final end = matchDelimiter(code, brace, '{', '}');
    if (end < 0) return null;
    return _Span(brace + 1, end);
  }
  final arrow = RegExp(r'\)\s*(?:async\s*)?=>').firstMatch(header);
  if (arrow == null) return null;
  return _Span(openParen + arrow.end, closeParen);
}

bool _onlyWeakExpects(String body) {
  final expects = _expectCalls(body);
  if (expects.isEmpty) return false;
  return expects.every((call) {
    final args = _topLevelArgs(call.substring(call.indexOf('(')));
    if (args.length < 2) return false;
    return _isWeakMatcher(args[1].trim());
  });
}

bool _isWeakMatcher(String matcher) {
  const names = {
    'isNull',
    'isNotNull',
    'isEmpty',
    'isNotEmpty',
    'isTrue',
    'isFalse',
  };
  if (names.contains(matcher)) return true;
  return RegExp(r'^isA\s*<[\s\S]+>\s*\(\s*\)$').hasMatch(matcher);
}

List<Finding> _expectFindings(
  String body,
  String relative,
  int bodyStart,
  String code,
) {
  final findings = <Finding>[];
  for (final call in _expectCallSpans(body)) {
    final args = _topLevelArgs(call.text.substring(call.text.indexOf('(')));
    if (args.length < 2) continue;
    final actualCalls = _callNames(args[0]);
    final expectedCalls = _callNames(args[1]);
    final shared = actualCalls.intersection(expectedCalls);
    if (shared.isEmpty) continue;
    findings.add(
      Finding(
        relative,
        lineOf(code, bodyStart + call.start),
        'mirrored-call',
        'both sides call ${shared.join(', ')}',
      ),
    );
  }
  return findings;
}

List<Finding> _controlFindings(
  String body,
  String relative,
  int bodyStart,
  String code,
) {
  final findings = <Finding>[];
  for (var i = 0; i < body.length; i++) {
    final rest = body.substring(i);
    final ifMatch = RegExp(r'^if\s*\(').firstMatch(rest);
    if (ifMatch != null && _boundaryBefore(body, i)) {
      final open = i + ifMatch.end - 1;
      final close = matchDelimiter(body, open, '(', ')');
      if (close < 0) continue;
      final statement = _statementAfter(body, close + 1);
      if (statement != null && statement.text.contains('expect(')) {
        findings.add(
          Finding(
            relative,
            lineOf(code, bodyStart + i),
            'conditional-expect',
            'if branch contains expect(',
          ),
        );
      }
      if (statement != null) {
        final after = statement.end;
        final elseMatch = RegExp(r'^\s*else\b').firstMatch(body.substring(after));
        if (elseMatch != null) {
          final elseAt = after + elseMatch.start;
          final elseBody = _statementAfter(body, after + elseMatch.end);
          if (elseBody != null &&
              !RegExp(r'^\s*if\s*\(').hasMatch(elseBody.text) &&
              elseBody.text.contains('expect(')) {
            findings.add(
              Finding(
                relative,
                lineOf(code, bodyStart + elseAt),
                'conditional-expect',
                'else branch contains expect(',
              ),
            );
          }
        }
      }
      continue;
    }
    final tryMatch = RegExp(r'^try\s*\{').firstMatch(rest);
    if (tryMatch != null && _boundaryBefore(body, i)) {
      final brace = i + tryMatch.end - 1;
      final tryEnd = matchDelimiter(body, brace, '{', '}');
      if (tryEnd < 0) continue;
      final tryBody = body.substring(brace + 1, tryEnd);
      final catchMatch = RegExp(
        r'^\s*(?:on\s+[^{;]+?)?catch\s*\([^)]*\)\s*\{',
      ).firstMatch(body.substring(tryEnd + 1));
      if (catchMatch == null || !tryBody.contains('expect(')) continue;
      final catchBrace = tryEnd + 1 + catchMatch.end - 1;
      final catchEnd = matchDelimiter(body, catchBrace, '{', '}');
      if (catchEnd < 0) continue;
      final catchBody = body.substring(catchBrace + 1, catchEnd).trim();
      if (catchBody.isEmpty || catchBody.contains('expect(')) {
        findings.add(
          Finding(
            relative,
            lineOf(code, bodyStart + i),
            'conditional-expect',
            'try/catch contains expect(',
          ),
        );
      }
      continue;
    }
  }
  return findings;
}

class _Statement {
  _Statement(this.text, this.end);
  final String text;
  final int end;
}

_Statement? _statementAfter(String code, int start) {
  var i = start;
  while (i < code.length && code[i].trim().isEmpty) {
    i++;
  }
  if (i >= code.length) return null;
  if (code[i] == '{') {
    final end = matchDelimiter(code, i, '{', '}');
    if (end < 0) return null;
    return _Statement(code.substring(i, end + 1), end + 1);
  }
  final end = code.indexOf(';', i);
  if (end < 0) return null;
  return _Statement(code.substring(i, end + 1), end + 1);
}

bool _boundaryBefore(String code, int index) {
  if (index == 0) return true;
  final previous = code[index - 1];
  return !_isIdent(previous);
}

bool _isIdent(String char) {
  final unit = char.codeUnitAt(0);
  return unit == 95 ||
      (unit >= 48 && unit <= 57) ||
      (unit >= 65 && unit <= 90) ||
      (unit >= 97 && unit <= 122);
}

class _CallSpan {
  _CallSpan(this.start, this.text);
  final int start;
  final String text;
}

List<String> _expectCalls(String body) =>
    _expectCallSpans(body).map((span) => span.text).toList();

List<_CallSpan> _expectCallSpans(String body) {
  final spans = <_CallSpan>[];
  final pattern = RegExp(r'\bexpect\s*\(');
  for (final match in pattern.allMatches(body)) {
    final open = match.end - 1;
    final close = matchDelimiter(body, open, '(', ')');
    if (close < 0) continue;
    spans.add(_CallSpan(match.start, body.substring(match.start, close + 1)));
  }
  return spans;
}

List<String> _topLevelArgs(String parenthesized) {
  final open = parenthesized.indexOf('(');
  if (open < 0) return const [];
  final close = matchDelimiter(parenthesized, open, '(', ')');
  if (close < 0) return const [];
  final inner = parenthesized.substring(open + 1, close);
  final args = <String>[];
  final current = StringBuffer();
  var paren = 0;
  var brace = 0;
  var bracket = 0;
  for (var i = 0; i < inner.length; i++) {
    final char = inner[i];
    if (char == '(') paren++;
    if (char == ')') paren--;
    if (char == '{') brace++;
    if (char == '}') brace--;
    if (char == '[') bracket++;
    if (char == ']') bracket--;
    if (char == ',' && paren == 0 && brace == 0 && bracket == 0) {
      args.add(current.toString());
      current.clear();
      continue;
    }
    current.write(char);
  }
  if (current.isNotEmpty) args.add(current.toString());
  return args;
}

Set<String> _callNames(String code) {
  const ignored = {
    'if',
    'for',
    'while',
    'switch',
    'catch',
    'on',
    'expect',
  };
  final names = <String>{};
  for (final match in RegExp(r'\b([A-Za-z_][A-Za-z0-9_]*)\s*\(').allMatches(code)) {
    final name = match.group(1)!;
    if (!ignored.contains(name)) names.add(name);
  }
  return names;
}

int matchDelimiter(String code, int openIndex, String open, String close) {
  var depth = 0;
  for (var i = openIndex; i < code.length; i++) {
    if (code.startsWith(open, i)) depth++;
    if (code.startsWith(close, i)) {
      depth--;
      if (depth == 0) return i;
    }
  }
  return -1;
}

int lineOf(String code, int index) {
  var line = 1;
  final end = index < code.length ? index : code.length;
  for (var i = 0; i < end; i++) {
    if (code[i] == '\n') line++;
  }
  return line;
}

String _relative(String path, String root) {
  final normalizedRoot = root.endsWith(Platform.pathSeparator)
      ? root
      : '$root${Platform.pathSeparator}';
  final normalized = File(path).absolute.path;
  final rootAbs = Directory(normalizedRoot).absolute.path;
  final prefix = rootAbs.endsWith(Platform.pathSeparator)
      ? rootAbs
      : '$rootAbs${Platform.pathSeparator}';
  if (normalized.toLowerCase().startsWith(prefix.toLowerCase())) {
    return normalized.substring(prefix.length).replaceAll('\\', '/');
  }
  return normalized.replaceAll('\\', '/');
}

/// Replaces comments and string contents with spaces. Newlines stay so indexes
/// still point at the same lines. Interpolation braces stay so delimiters match.
String stripNonCode(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      while (i < source.length && source[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    if (source.startsWith('/*', i)) {
      out.write('  ');
      i += 2;
      while (i < source.length && !source.startsWith('*/', i)) {
        out.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      if (i < source.length) {
        out.write('  ');
        i += 2;
      }
      continue;
    }
    final consumed = _consumeString(source, i, out);
    if (consumed != i) {
      i = consumed;
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
}

int _consumeString(String source, int start, StringBuffer out) {
  var i = start;
  var raw = false;
  if (source[i] == 'r' &&
      (i == 0 || !_isIdent(source[i - 1])) &&
      i + 1 < source.length &&
      (source[i + 1] == "'" || source[i + 1] == '"')) {
    raw = true;
    out.write(' ');
    i++;
  }
  if (i >= source.length) return start;
  final quote = source[i];
  if (quote != "'" && quote != '"') return start;
  final triple = i + 2 < source.length &&
      source[i + 1] == quote &&
      source[i + 2] == quote;
  final marker = triple ? quote * 3 : quote;
  out.write(' ' * marker.length);
  i += marker.length;
  while (i < source.length) {
    if (source.startsWith(marker, i)) {
      out.write(' ' * marker.length);
      return i + marker.length;
    }
    final char = source[i];
    if (!raw && char == r'\') {
      out.write(' ');
      i++;
      if (i < source.length) {
        out.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      continue;
    }
    if (!raw && char == r'$' && i + 1 < source.length) {
      if (source[i + 1] == '{') {
        out.write(char);
        i++;
        final brace = i;
        final end = matchDelimiter(source, brace, '{', '}');
        if (end < 0) {
          out.write(source[i]);
          i++;
          continue;
        }
        out.write(_stripInterpolation(source.substring(brace, end + 1)));
        i = end + 1;
        continue;
      }
      out.write(' ');
      i++;
      while (i < source.length && _isIdent(source[i])) {
        out.write(' ');
        i++;
      }
      continue;
    }
    out.write(char == '\n' ? '\n' : ' ');
    i++;
  }
  return i;
}

String _stripInterpolation(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final consumed = _consumeString(source, i, out);
    if (consumed != i) {
      i = consumed;
      continue;
    }
    if (source.startsWith('//', i)) {
      while (i < source.length && source[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
}
