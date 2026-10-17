# Grocery lists

This folder is a shared grocery list. Each shopping list is one Markdown file. The filename is the list name, for example `Groceries.md`.

This file, `AGENTS.md`, is instructions. It is not a shopping list. Do not rename it, delete it, or put items in it. The app restores this file if it changes. A list cannot be named AGENTS.

## How to edit a list

The body of a list is only checkbox lines. One item per line. Do not add headings, aisle names, categories, ids, or HTML comments. The app chooses the aisle on screen from the item name.

```
- [ ] milk
- [ ] eggs (3)
- [ ] milk (2 gal)
- [ ] butter (1/2 lb)
- [x] sourdough
```

- An unchecked item is `- [ ] ` followed by the name.
- A checked item is `- [x] `.
- To add an item, append an unchecked line at the end.
- To check an item, change that line from `- [ ] ` to `- [x] `.
- To uncheck it, change it back to `- [ ] `.
- To remove an item, delete that whole line.
- Do not put a line break inside an item name.

## Quantity

A quantity is optional. Put it in parentheses after the name. The number comes first. A unit is optional.

- No quantity: `- [ ] milk`
- Count only: `- [ ] eggs (3)`
- Number and unit: `- [ ] milk (2 gal)`
- Fraction: `- [ ] butter (1/2 lb)`
- Mixed number: `- [ ] juice (1 1/2 qt)`

`milk` and `milk (2)` are different items. Leave them as two lines. Do not add the numbers together.

Parentheses that do not start with a number are part of the name, not a quantity. `- [ ] milk (organic)` is one item named `milk (organic)`.

The aisle comes from the name only. `milk (2 gal)` is still milk. Do not write the aisle into the file.
