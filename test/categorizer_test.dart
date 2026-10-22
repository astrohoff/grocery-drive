import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grocery_drive/app.dart';
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

  test('spices land in the spice aisle', () {
    const expected = {
      'salt': 'Spices',
      'pepper': 'Spices',
      'black pepper': 'Spices',
      'cinnamon': 'Spices',
      'cinnamon (1 jar)': 'Spices',
      'paprika': 'Spices',
      'cumin': 'Spices',
      'chili powder': 'Spices',
      'garlic powder': 'Spices',
      'onion powder': 'Spices',
      'oregano': 'Spices',
      'italian seasoning': 'Spices',
      'nutmeg': 'Spices',
      'ginger powder': 'Spices',
      'ground ginger': 'Spices',
      'cayenne': 'Spices',
      'red pepper flakes': 'Spices',
      'crushed red pepper': 'Spices',
      'bay leaf': 'Spices',
      'bay leaves': 'Spices',
      'dried basil': 'Spices',
      'dried parsley': 'Spices',
      'dried oregano': 'Spices',
      'dried thyme': 'Spices',
      'turmeric': 'Spices',
      'curry powder': 'Spices',
      'mustard powder': 'Spices',
      'garlic salt': 'Spices',
      'celery salt': 'Spices',
      'kosher salt': 'Spices',
      'cinnamon rolls': 'Bakery',
      'salted butter': 'Dairy',
      'unsalted butter': 'Dairy',
      'bell pepper': 'Produce',
      'green pepper': 'Produce',
      'red pepper': 'Produce',
      'pepper jack': 'Dairy',
      'pepperoni': 'Meat and Seafood',
      'sliced pepperoni': 'Deli',
      'garlic': 'Produce',
      'garlic cloves': 'Produce',
      'garlic bread': 'Bakery',
      'onion': 'Produce',
      'ginger': 'Produce',
      'ginger root': 'Produce',
      'basil': 'Produce',
      'fresh basil': 'Produce',
      'parsley': 'Produce',
      'thyme': 'Produce',
      'mustard': 'Pantry',
      'curry paste': 'Pantry',
      'vanilla': 'Pantry',
      'vanilla extract': 'Pantry',
      'chicken broth': 'Pantry',
      'spaghetti': 'Pantry',
      'olive oil': 'Pantry',
      'flour': 'Pantry',
      'baking powder': 'Pantry',
      'dr pepper': 'Beverages',
      'diet dr pepper': 'Beverages',
      'epsom salt': 'Personal Care',
      'bath salts': 'Personal Care',
      'salt pork': 'Meat and Seafood',
      'chili beans': 'Canned Goods',
    };
    for (final entry in expected.entries) {
      expect(categorizer.nameFor(entry.key), entry.value, reason: entry.key);
    }
  });

  testWidgets('the bundled aisle file groups cinnamon with spices', (
    tester,
  ) async {
    final bundled = await loadAisleCatalog(rootBundle);
    expect(bundled.nameFor('cinnamon'), 'Spices');
    expect(bundled.nameFor('spaghetti'), 'Pantry');
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
