import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/domain/bot_instructions.dart';

void main() {
  test('a list can be named anything except bot-instructions', () {
    const names = [
      'bot-instructions',
      'Bot-Instructions',
      'bot-instructions.md',
      ' bot-instructions ',
      'AGENTS',
      'instructions',
      'bot instructions',
      'Groceries',
      'Groceries.bot.1',
      'Shop.bot.a.md',
      'GROCERIES.BOT.ZZ',
      'Week.bot',
      '',
    ];
    expect(
      [
        for (final name in names)
          if (isReservedListName(name)) name,
      ],
      [
        'bot-instructions',
        'Bot-Instructions',
        'bot-instructions.md',
        ' bot-instructions ',
        'Groceries.bot.1',
        'Shop.bot.a.md',
        'GROCERIES.BOT.ZZ',
      ],
    );
  });

  test('bot-instructions.md is not a grocery list file', () {
    const names = [
      'bot-instructions.md',
      'Bot-Instructions.md',
      ' bot-instructions.md ',
      'AGENTS.md',
      'Groceries.md',
    ];
    expect(
      [
        for (final name in names)
          if (isBotInstructionsFile(name)) name,
      ],
      ['bot-instructions.md', 'Bot-Instructions.md', ' bot-instructions.md '],
    );
  });
}
