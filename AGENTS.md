# Agent notes

Grocery Drive is a Flutter app for Android and Windows. One active cloud folder is the source of truth. Each list is one Markdown file of checkbox lines. The app picks a store aisle when it draws an item. Aisles are not written into the file. Version 1 is a basic list: add, check, uncheck, edit, delete, clear completed, several named lists, an offline copy, and sync. Do not add prices, barcodes, recipes, reminders, widgets, a system tray, a share sheet, search, quantity steppers, or an aisle editor.

The license stays MIT. The aisle dictionary is original work in this repo. Automated tests run on Windows only.

The grocery folder contains `bot-instructions.md`. The app copies it from `assets/bot_instructions.md` and restores it on sync. It is not a list. The list name bot-instructions is reserved.

Google Drive and OneDrive use authorization-code PKCE. Client ids are dart-defines: `GOOGLE_CLIENT_ID`, `MICROSOFT_CLIENT_ID`, and `GOOGLE_DESKTOP_SECRET` when the Google desktop client has one. `tool/build_windows.ps1` compiles them into the Windows release exe, and `tool/build_android.ps1` compiles them into the release APK, both from the gitignored secrets JSON. Launching those builds does not take dart-defines. Refresh tokens stay in secure storage. The Google scope is `https://www.googleapis.com/auth/drive`, not `drive.file`. Microsoft is a public client with `Files.ReadWrite`, `offline_access`, and `User.Read`, and it has no client secret. Windows and Android both use that PKCE flow on `http://localhost:8484`. Each device opens the system browser and listens on that port on itself. On Android the token request waits until the app is in front again, because Android aborts it while the browser is open. Headless live scripts refresh over HTTP with the gitignored secrets JSON. That is not a second sign-in inside the app. A Google sign-in whose granted scopes omit `https://www.googleapis.com/auth/drive` is rejected before the refresh token is stored. Settings lists folders in the drive root and syncs only the selected folder. With no selection yet, the app uses a folder named Groceries.

Merge keeps an add from either side. An item stays checked if either side checked it. A delete sticks when the other side did not change that item. A union that puts a deleted item back is wrong.

## Checks

`tool/check.ps1` is the gate. Run it before a phase commit. It prints `OK` when the lint and the Windows tests pass. While editing tests, run `dart run tool/deslop.dart`. The rules are in that file. The lint does not decide whether a check is valuable.

The cold-start check launches `integration_test/cold_start_test.dart` twice against one temp directory. The first process adds milk. The second process must show Groceries and milk without adding it. `GROCERY_CACHE_DIR` is a dart-define because the Windows runner does not pass environment variables into the app. Widget tests keep an in-memory fake cloud.

Before committing tests you added or changed, follow `.grok/skills/review-tests/SKILL.md`. A sloppy test that lands gets copied by the next agent.

Write a test from the behavior you intend, with a literal expected value, before writing the implementation that should satisfy it.

This repo does not gate on coverage. Coverage numbers go up when tests assert nothing.

Do not skip, delete, or weaken a test to get a green run. Change a test when the intended behavior changed.

`tool/check_live.ps1` talks to real Google Drive and OneDrive. It is not part of `tool/check.ps1`. With no credentials it prints `NEEDS_HUMAN_CREDENTIALS` and exits 2.

## Git

When the phase gate prints `OK` and the test review is done, update `README.md` so it describes only what is built. Commit and `git push origin HEAD`. Do not force-push. Do not commit `secrets/`, client JSON, or tokens.
