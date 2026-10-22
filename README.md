# Grocery Drive

Grocery Drive is a Flutter grocery list for Android and Windows. Items are grouped into store aisles on screen. Each list is one Markdown file of checkbox lines, so a bot can edit the same list. Aisles are not written into the file.

Open the app and type an item. Press Enter to add it. Check an item to strike it through. Checked items stay until you press Clear. Tap the title to switch, create, rename, or delete a list. The add field sits under the title. Escape clears it.

Settings is where you sign in to Google Drive or OneDrive, choose a folder, and sync. Use the Groceries folder, which the app creates, or pick another folder in the drive root. The app syncs that folder only. Google and Microsoft credentials are required. The setup steps are in `docs/oauth_setup.md`.

## Run

Real clouds, from the repo root, after the client ids in `docs/oauth_setup.md` are filled in:

```powershell
flutter run -d windows `
  --dart-define=GOOGLE_CLIENT_ID=your-google-client-id `
  --dart-define=MICROSOFT_CLIENT_ID=your-microsoft-client-id `
  --dart-define=GOOGLE_DESKTOP_SECRET=your-google-secret
```

Omit `GOOGLE_DESKTOP_SECRET` when the Google desktop client has no secret. A missing client id disables that provider's sign-in button.

Android uses the same ids. Connect a phone with USB debugging, or start an emulator, and read its id from `flutter devices`. Replace `device-id` below:

```powershell
flutter run -d device-id `
  --dart-define=GOOGLE_CLIENT_ID=your-google-client-id `
  --dart-define=MICROSOFT_CLIENT_ID=your-microsoft-client-id `
  --dart-define=GOOGLE_DESKTOP_SECRET=your-google-secret
```

A local fake cloud needs no account:

```powershell
flutter run -d windows --dart-define=CLOUD=fake
```

On Android, use the device id in place of `windows`.

The window opens on the list you used last, or on Groceries the first time, with the keyboard down and the add field visible. The Qty field is optional: `2`, `2 gal`, or `1/2 lb` is stored after the name as `milk (2 gal)`. The same name with a different quantity is a separate row.

Quit the app and start it again with the same command. The window opens on the same list, including the items you added.

A bot can change the open list by editing that Markdown file. The grocery folder also contains `bot-instructions.md`, which the app writes and restores, with examples of the quantity format. A list cannot be named bot-instructions. The format is in `docs/bot_format.md`. Opening or closing the app, and opening or closing a list, syncs with the cloud. Press the sync button to sync while a list stays open. A failed upload or a failed sync leaves the list on screen and a banner says Not synced.

## Windows app

`flutter run` rebuilds a debug app, so that command needs the ids every time. To start the app without them, build the Windows release once. From the repo root, after `secrets/google.json` and `secrets/microsoft.json` contain the client ids:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_windows.ps1
```

The script reads those files and compiles the ids into the executable. It does not print them. When it finishes, start:

`build\windows\x64\runner\Release\grocery_drive.exe`

Leave the other files in that `Release` folder next to the exe. A shortcut can point at the exe. Launching it does not take `--dart-define`. Sign-in stays in Windows secure storage, shared with the debug app, so a new build does not sign you out. Rebuild when a client id or the Google secret changes.

Starting the exe from the repo root also updates `secrets/*.json` on sign-in. Starting it from the `Release` folder stores the sign-in for the app and leaves those files unchanged.

## Android app

`flutter run` rebuilds a debug app, so that command needs the ids every time. A release APK keeps them. From the repo root, after the secrets files contain the client ids:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_android.ps1
```

The script reads those files and compiles the ids into the APK. It does not print them. The file is:

`build\app\outputs\flutter-apk\app-release.apk`

Install that file on a connected device. This does not rebuild, so the ids stay in the APK:

```powershell
flutter install -d device-id --use-application-binary=build\app\outputs\flutter-apk\app-release.apk
```

Open `grocery_drive` from the phone launcher after that. Launching it does not take `--dart-define`. Sign-in stays on the phone until you uninstall the app. A phone sign-in does not update `secrets/*.json`. Rebuild the APK when a client id or the Google secret changes. The phone opens the system browser and returns through `http://localhost:8484`, the same redirect as Windows. Switch back to the app when the browser says you can close the window. Android finishes sign-in after that. `docs/oauth_setup.md` has the registration. A debug `flutter run` keeps the previous redirect until you run it again.

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
