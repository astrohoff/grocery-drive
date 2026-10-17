import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/domain/quantity.dart';

void main() {
  test('a trailing parenthetical quantity splits off the name', () {
    expect(itemName('milk (2 gal)'), 'milk');
    expect(quantityLabel('milk (2 gal)'), '2 gal');
    expect(itemName('eggs (3)'), 'eggs');
    expect(quantityLabel('eggs (3)'), '3');
    expect(itemName('butter (1/2 lb)'), 'butter');
    expect(quantityLabel('butter (1/2 lb)'), '1/2 lb');
    expect(itemName('juice (1 1/2 qt)'), 'juice');
    expect(quantityLabel('juice (1 1/2 qt)'), '1 1/2 qt');
    expect(itemName('milk'), 'milk');
    expect(quantityLabel('milk'), '');
    expect(itemName('milk (organic)'), 'milk (organic)');
    expect(quantityLabel('milk (organic)'), '');
  });

  test('composing a line puts a real quantity in parentheses', () {
    expect(composeItemLine('milk', '2 gal'), 'milk (2 gal)');
    expect(composeItemLine('milk', '3'), 'milk (3)');
    expect(composeItemLine('butter', '1/2 lb'), 'butter (1/2 lb)');
    expect(composeItemLine('juice', '1 1/2 qt'), 'juice (1 1/2 qt)');
    expect(composeItemLine('  oat milk  ', '  2  '), 'oat milk (2)');
    expect(composeItemLine('milk', ''), 'milk');
    expect(composeItemLine('milk (2 gal)', ''), 'milk (2 gal)');
    expect(composeItemLine('milk (2 gal)', '3'), 'milk (3)');
    expect(composeItemLine('milk (organic)', '2'), 'milk (organic) (2)');
    expect(composeItemLine('milk', 'gal'), 'milk');
  });
}
