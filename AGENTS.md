# Agent notes

Grocery Drive is a Flutter app for Android and Windows. One active cloud folder is the source of truth. Each list is one Markdown file of checkbox lines. The app picks a store aisle when it draws an item. Aisles are not written into the file. Version 1 is a basic list: add, check, uncheck, edit, delete, clear completed, several named lists, an offline copy, and sync. Do not add prices, barcodes, recipes, reminders, widgets, a system tray, a share sheet, search, quantity steppers, or an aisle editor.

The license stays MIT. The aisle dictionary is original work in this repo. Automated tests run on Windows only.

Merge keeps an add from either side. An item stays checked if either side checked it. A delete sticks when the other side did not change that item. A union that puts a deleted item back is wrong.

## Checks

`tool/check.ps1` is the gate. Run it before a phase commit. It prints `OK` when the lint and the Windows tests pass. While editing tests, run `dart run tool/deslop.dart`. The rules are in that file. The lint does not decide whether a check is valuable.

Before committing tests you added or changed, follow `.grok/skills/review-tests/SKILL.md`. A sloppy test that lands gets copied by the next agent.

Write a test from the behavior you intend, with a literal expected value, before writing the implementation that should satisfy it.

This repo does not gate on coverage. Coverage numbers go up when tests assert nothing.

Do not skip, delete, or weaken a test to get a green run. Change a test when the intended behavior changed.

`tool/check_live.ps1` talks to real Google Drive and OneDrive. It is not part of `tool/check.ps1`. With no credentials it prints `NEEDS_HUMAN_CREDENTIALS` and exits 2.

## Git

When the phase gate prints `OK` and the test review is done, update `README.md` so it describes only what is built. Commit and `git push origin HEAD`. Do not force-push. Do not commit `secrets/`, client JSON, or tokens.
