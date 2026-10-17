bool isAgentsFile(String filename) =>
    filename.trim().toLowerCase() == 'agents.md';

bool isReservedListName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed.contains('\n')) return false;
  final filename = trimmed.toLowerCase().endsWith('.md')
      ? trimmed
      : '$trimmed.md';
  return isAgentsFile(filename);
}
