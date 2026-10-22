import 'bot_change.dart';

bool isBotInstructionsFile(String filename) =>
    filename.trim().toLowerCase() == 'bot-instructions.md';

bool isReservedListName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed.contains('\n')) return false;
  final filename = trimmed.toLowerCase().endsWith('.md')
      ? trimmed
      : '$trimmed.md';
  return isBotInstructionsFile(filename) || isBotChangeFile(filename);
}
