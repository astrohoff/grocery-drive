import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/domain/item.dart';
import 'package:grocery_drive/domain/merge.dart';

void main() {
  test('an item added on only one side is kept', () {
    expect(
      merge(
        [const Item('milk')],
        [const Item('milk'), const Item('eggs')],
        [const Item('milk')],
      ),
      [const Item('milk'), const Item('eggs')],
    );
  });

  test('an item deleted on one side is gone when the other side did not change it', () {
    expect(
      merge(
        [const Item('milk'), const Item('eggs')],
        [const Item('milk')],
        [const Item('milk'), const Item('eggs')],
      ),
      [const Item('milk')],
    );
  });

  test('a check sticks when the other side did not change the item', () {
    expect(
      merge(
        [const Item('milk')],
        [const Item('milk', checked: true)],
        [const Item('milk')],
      ),
      [const Item('milk', checked: true)],
    );
  });

  test('an uncheck sticks when the other side did not change the item', () {
    expect(
      merge(
        [const Item('milk', checked: true)],
        [const Item('milk')],
        [const Item('milk', checked: true)],
      ),
      [const Item('milk')],
    );
  });

  test('adds on both sides survive with local adds before remote adds', () {
    expect(
      merge(
        [const Item('milk')],
        [const Item('milk'), const Item('eggs')],
        [const Item('milk'), const Item('bread')],
      ),
      [const Item('milk'), const Item('eggs'), const Item('bread')],
    );
  });

  test('merging a result with itself returns the same items', () {
    final merged = merge(
      [const Item('milk'), const Item('eggs')],
      [const Item('milk'), const Item('eggs'), const Item('bread')],
      [const Item('milk'), const Item('eggs')],
    );
    expect(merged, [
      const Item('milk'),
      const Item('eggs'),
      const Item('bread'),
    ]);
    expect(merge(merged, merged, merged), merged);
  });

  test('a check beats a delete from the other side', () {
    expect(
      merge(
        [const Item('milk')],
        [const Item('milk', checked: true)],
        const [],
      ),
      [const Item('milk', checked: true)],
    );
  });

  test('existing order is kept', () {
    expect(
      merge(
        [const Item('eggs'), const Item('milk')],
        [const Item('eggs'), const Item('milk')],
        [const Item('eggs'), const Item('milk')],
      ),
      [const Item('eggs'), const Item('milk')],
    );
  });

  test('checked wins when both sides differ from the base', () {
    expect(
      merge(
        const [],
        [const Item('milk', checked: true)],
        [const Item('milk')],
      ),
      [const Item('milk', checked: true)],
    );
  });
}
