# Grocery lists

This folder is a shared grocery list. Each shopping list is one Markdown file. The filename is the list name, for example `Groceries.md`.

This file, `bot-instructions.md`, is instructions. It is not a shopping list. Do not rename it, delete it, or put items in it. The app restores this file if it changes. A list cannot be named bot-instructions. A list filename cannot contain `.bot.`.

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

## Google Drive

OneDrive can edit a list file in place. Do that. Change the checkbox lines in the existing file.

Google Drive cannot edit an existing file. Do not trash a list, and do not upload a second copy of it. Create a new file in this folder. The name is the list name, then `.bot.`, then a new token, then `.md`. One name for the first list is `Groceries.bot.4f2.md`. Use a different token each time. The app applies the file when it syncs and then deletes it. That file is not a list.

Use one operation on each line:

```
add milk
add eggs (3)
remove butter
check sourdough
uncheck milk
```

- `add` appends an unchecked item. An item that is already on the list stays as it is.
- `remove` deletes that line.
- `check` marks the item checked. A missing item is added checked.
- `uncheck` marks the item unchecked. A missing item is added unchecked.
- Matching ignores capitalization and extra spaces.
- Leave every other item out. An item that is not in the file stays on the list.

A file of only checkbox lines is the whole list. The app merges it. A missing line is removed when that item was already on the list and neither side has changed it. An item added since you read the list stays. Prefer the operation lines so you do not remove an item by leaving it out.
