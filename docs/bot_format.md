# List file format

Each list is one `.md` file in the active folder. The filename is the list name. The app starts with a folder named Groceries. The name bot-instructions is reserved.

The folder also contains `bot-instructions.md`. That file is instructions for a bot, not a shopping list. The app writes it and restores it on sync. Do not rename it, delete it, or put items in it.

The body of a list is only lines of `- [ ] item` or `- [x] item`.

A quantity, with or without a unit, goes in parentheses after the name: `- [ ] milk (2 gal)`, `- [ ] eggs (3)`, `- [ ] butter (1/2 lb)`. The name is everything before that parenthesis. `milk` and `milk (2)` are different lines. A parenthesis that does not start with a number, such as `milk (organic)`, is part of the name.

Do not add headings, categories, ids, or HTML comments.

To add an item, append an unchecked line. To check it, change the line to `- [x]`. To remove it, delete the line.

The app groups lines into aisles on screen from the item name. The quantity is not an aisle, and the file has no aisle information.

OneDrive can edit a list file in place. Google Drive cannot. On Google Drive, a bot adds a change file instead of trashing the list or uploading a second copy. The name is the list name, then `.bot.`, then a new token, then `.md`, for example `Groceries.bot.4f2.md`. The app applies that file on sync and deletes it. The file is not a list. A list filename cannot contain `.bot.`.

The change file is one operation per line: `add milk`, `add eggs (3)`, `remove butter`, `check sourdough`, `uncheck milk`. An item that is not mentioned stays. A file of only checkbox lines is the whole list. A missing line is removed when that item was already on the list and neither side has changed it. An item added since the bot read the list stays. `bot-instructions.md` in the folder has the same rules.
