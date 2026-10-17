# Grocery Drive

Grocery Drive is a Flutter grocery list for Android and Windows. Items are grouped into store aisles on screen. Each list is one Markdown file of checkbox lines, so a bot can edit the same list. Aisles are not written into the file.

The lists live in one folder named Groceries on Google Drive or OneDrive. The app creates that folder the first time you sign in. Sign-in is in Settings. Google and Microsoft credentials are required. The setup steps are in `docs/oauth_setup.md`.

## Run

Real clouds, from the repo root, after the client ids in `docs/oauth_setup.md` are filled in:

```powershell
flutter run -d windows `
  --dart-define=GOOGLE_CLIENT_ID=your-google-client-id `
  --dart-define=MICROSOFT_CLIENT_ID=your-microsoft-client-id `
  --dart-define=GOOGLE_DESKTOP_SECRET=your-google-secret
```

Omit `GOOGLE_DESKTOP_SECRET` when the Google desktop client has no secret. A missing client id disables that provider's sign-in button.

A local fake cloud needs no account:

```powershell
flutter run -d windows --dart-define=CLOUD=fake
```

The window opens on the list you used last, or on Groceries the first time, with the keyboard down and the add field visible. Type an item and press Enter. The Qty field is optional: `2`, `2 gal`, or `1/2 lb` is stored after the name as `milk (2 gal)`. The same name with a different quantity is a separate row. Check an item to strike it through. Checked items stay until you press Clear. Tap the title to create, rename, open, or delete a list.

Quit the app and start it again with the same command. The window opens on the same list, including the items you added.

A bot can change the open list by editing that Markdown file. The grocery folder also contains `bot-instructions.md`, which the app writes and restores, with examples of the quantity format. A list cannot be named bot-instructions. The format is in `docs/bot_format.md`. Press the sync button to pull those edits. If the network fails, the list stays on screen and a banner says Not synced.

## Check

From the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\check.ps1
```

The script runs the test lint, the widget tests, and a Windows restart test against the fake cloud. It prints `OK` when they pass.

The real-cloud check is separate:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\check_live.ps1
```

Until `secrets/google.json` and `secrets/microsoft.json` exist, it prints `NEEDS_HUMAN_CREDENTIALS` and exits 2. That exit is expected before the setup in `docs/oauth_setup.md`. A secrets file with an empty refresh token fails the round-trip instead of passing.
