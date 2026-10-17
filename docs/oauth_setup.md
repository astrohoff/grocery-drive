# OAuth setup

The app reads three compile-time values:

- `GOOGLE_CLIENT_ID`
- `MICROSOFT_CLIENT_ID`
- `GOOGLE_DESKTOP_SECRET`, when the Google desktop client has a secret

Google's scope is `https://www.googleapis.com/auth/drive`. The narrower `drive.file` scope cannot see a file a bot created. The Microsoft app is a public client with delegated `Files.ReadWrite`, `offline_access`, and `User.Read`. Do not create a Microsoft client secret.

Register this Windows redirect on both apps: `http://localhost:8484`.

Register this Android redirect on both apps: `com.astrohoff.grocerydrive:/oauthredirect`.

Android sign-in uses `flutter_appauth`. That plugin has no Windows build, so Windows opens the system browser and listens on the loopback redirect above. Both platforms use authorization-code PKCE and store the refresh token in secure storage.

From the repo root:

```powershell
flutter run -d windows `
  --dart-define=GOOGLE_CLIENT_ID=your-google-client-id `
  --dart-define=MICROSOFT_CLIENT_ID=your-microsoft-client-id `
  --dart-define=GOOGLE_DESKTOP_SECRET=your-google-secret
```

Create these gitignored files before the first sign-in. `refresh_token` can be empty until then.

`secrets/google.json`

```json
{
  "client_id": "your-google-client-id",
  "client_secret": "your-google-secret",
  "refresh_token": ""
}
```

`secrets/microsoft.json`

```json
{
  "client_id": "your-microsoft-client-id",
  "refresh_token": ""
}
```

Sign in once from the repo root. The app keeps the refresh token for the Windows live test. When the JSON file is already there, it also writes `refresh_token` into that file for the headless round-trip. The round-trip creates `Roundtrip.md`, checks it, and deletes it. It does not change `Groceries.md`.

`tool/check_live.ps1` prints `NEEDS_HUMAN_CREDENTIALS` and exits 2 until both files exist. A file with an empty `refresh_token` fails the round-trip.
