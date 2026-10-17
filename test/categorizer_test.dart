import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/domain/categorizer.dart';

void main() {
  late Categorizer categorizer;

  setUp(() {
    categorizer = Categorizer.fromJsonString(
      File('assets/aisles.json').readAsStringSync(),
    );
  });

  test('known items land in these aisles', () {
    const expected = {
      'milk': 'Dairy',
      '2% milk': 'Dairy',
      'oat milk': 'Dairy',
      'eggs': 'Dairy',
      'bananas': 'Produce',
      'chicken breast': 'Meat and Seafood',
      'salmon': 'Meat and Seafood',
      'sourdough': 'Bakery',
      'sliced turkey': 'Deli',
      'ice cream': 'Frozen',
      'frozen peas': 'Frozen',
      'canned tomatoes': 'Canned Goods',
      'chicken broth': 'Pantry',
      'spaghetti': 'Pantry',
      'olive oil': 'Pantry',
      'soda': 'Beverages',
      'potato chips': 'Snacks',
      'paper towels': 'Household',
      'shampoo': 'Personal Care',
      'mystery gadget': 'Other',
    };
    for (final entry in expected.entries) {
      expect(categorizer.nameFor(entry.key), entry.value, reason: entry.key);
    }
  });

  test('the dictionary has at least 400 phrases', () {
    final json = jsonDecode(File('assets/aisles.json').readAsStringSync());
    final phrases = json['phrases'] as List;
    expect(phrases.length, greaterThanOrEqualTo(400));
  });

  test('a parenthetical quantity does not change the aisle', () {
    expect(categorizer.nameFor('milk (2 gal)'), 'Dairy');
    expect(categorizer.nameFor('frozen peas (1 bag)'), 'Frozen');
    expect(categorizer.nameFor('bananas (3)'), 'Produce');
    expect(categorizer.nameFor('paper towels (6 rolls)'), 'Household');
    expect(categorizer.nameFor('corn (2 frozen peas)'), 'Produce');
    expect(categorizer.nameFor('2% milk (1 gal)'), 'Dairy');
  });

  test('the same input returns the same known aisle id', () {
    expect(categorizer.idFor('milk'), 'dairy');
    expect(categorizer.idFor('milk'), 'dairy');
    expect(categorizer.idFor('mystery gadget'), 'other');
    expect(categorizer.idFor(''), 'other');
  });
}
