# Grocery Drive

Grocery Drive is a Flutter grocery list for Android and Windows. Items are grouped into store aisles on screen. Each list is one Markdown file of checkbox lines, so a bot can edit the same list. Aisles are not written into the file.

The app currently runs against an in-memory fake cloud. Google Drive and OneDrive are not connected yet.

## Run

```powershell
flutter run -d windows --dart-define=CLOUD=fake
```

The window opens on a list named Groceries, with the keyboard down and the add field visible. Type an item and press Enter. The Qty field is optional: `2`, `2 gal`, or `1/2 lb` is stored after the name as `milk (2 gal)`. The same name with a different quantity is a separate row. Check an item to strike it through. Checked items stay until you press Clear. Tap the title to create, rename, open, or delete a list.

A bot can change the open list by editing that Markdown file. The format is in `docs/bot_format.md`. Press the sync button to pull those edits.

If you run without `--dart-define=CLOUD=fake`, the app says the real clouds are not connected.

## Check

From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\check.ps1
```

The script runs the test lint and the widget tests. It prints `OK` when they pass.
