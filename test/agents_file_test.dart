import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/domain/agents_file.dart';

void main() {
  test('a list can be named anything except AGENTS', () {
    const names = [
      'AGENTS',
      'agents',
      'AGENTS.md',
      ' agents ',
      'Travel agents',
      'AGENT',
      'Groceries',
      '',
    ];
    expect(
      [for (final name in names) if (isReservedListName(name)) name],
      ['AGENTS', 'agents', 'AGENTS.md', ' agents '],
    );
  });

  test('AGENTS.md is not a grocery list file', () {
    const names = [
      'AGENTS.md',
      'Agents.md',
      ' agents.md ',
      'Groceries.md',
      'Travel agents.md',
    ];
    expect(
      [for (final name in names) if (isAgentsFile(name)) name],
      ['AGENTS.md', 'Agents.md', ' agents.md '],
    );
  });
}
