import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/domain/item.dart';
import 'package:grocery_drive/domain/markdown_list.dart';

void main() {
  test('saving a list and parsing it returns the same names and checked states', () {
    const items = [
      Item('Milk'),
      Item('eggs', checked: true),
    ];
    expect(parseMarkdown(writeMarkdown(items)), items);
  });

  test('blank lines are ignored', () {
    expect(
      parseMarkdown('- [ ] milk\n\n- [ ] eggs\n'),
      [const Item('milk'), const Item('eggs')],
    );
  });

  test('headings and prose are dropped on save and checkbox items are kept', () {
    const source = '# Groceries\n\nremember the store\n- [ ] milk\n- [x] eggs\n';
    expect(writeMarkdown(parseMarkdown(source)), '- [ ] milk\n- [x] eggs\n');
  });

  test('alternate checkbox syntax parses and save writes one form', () {
    const source = '- [x] milk\n- [X] eggs\n- [ ] bread\n* [ ] jam\n';
    expect(
      writeMarkdown(parseMarkdown(source)),
      '- [x] milk\n- [x] eggs\n- [ ] bread\n- [ ] jam\n',
    );
  });

  test('an empty or whitespace name is rejected', () {
    expect(() => writeMarkdown([const Item('   ')]), throwsArgumentError);
  });

  test('item text cannot contain a newline', () {
    expect(() => writeMarkdown([const Item('milk\neggs')]), throwsArgumentError);
  });

  test('the same item collapses to one line and checked wins', () {
    expect(
      writeMarkdown([const Item('Milk'), const Item('milk', checked: true)]),
      '- [x] Milk\n',
    );
  });
}
