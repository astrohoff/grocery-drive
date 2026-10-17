class Item {
  const Item(this.name, {this.checked = false});

  final String name;
  final bool checked;

  @override
  bool operator ==(Object other) =>
      other is Item && other.name == name && other.checked == checked;

  @override
  int get hashCode => Object.hash(name, checked);
}
