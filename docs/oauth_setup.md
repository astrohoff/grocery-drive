# OAuth setup

The app never asks for your Google or Microsoft password. You register Grocery Drive with each company, they give you an id for the app, and the first sign-in returns a refresh token. That token is what the app uses afterward to open your Drive or OneDrive.

You need three compile-time values:

| Dart define | Where it comes from |
| --- | --- |
| `GOOGLE_CLIENT_ID` | Google client id |
| `GOOGLE_DESKTOP_SECRET` | Google client secret, when Google shows one |
| `MICROSOFT_CLIENT_ID` | Microsoft application (client) id |

Microsoft is a public client. It has no client secret. Leave its Certificates & secrets page empty.

The refresh token is a different value. Neither console can create it. You sign in from the app, and the app writes it into the gitignored JSON files below.

Google's scope is `https://www.googleapis.com/auth/drive`. The narrower `drive.file` scope cannot see a file a bot created. The Microsoft app uses delegated Microsoft Graph permissions `Files.ReadWrite`, `offline_access`, and `User.Read`. The app also sends `openid` to both providers.

## Redirects

A redirect is the address Google or Microsoft sends the browser back to after you approve access. The app sends this exact string on Windows and on Android, for both providers:

`http://localhost:8484`

The app opens the system browser and listens on that port on the same device. On a phone, `localhost` is the phone, and the phone browser returns to the app there. Both platforms use authorization-code PKCE, which binds the sign-in to this app, and both store the refresh token in secure storage.

Do not register a custom scheme such as `com.astrohoff.grocerydrive:/oauthredirect`. The Google client is a Desktop app, and that client type rejects a custom scheme with `redirect_uri_mismatch`. Microsoft's portal will not save a redirect that has only one slash after the colon, so that address was never a registered redirect either. `http://localhost:8484` is the address Windows already uses.

## Google

Use a normal Google account. A Workspace admin can also use an Internal app, but a personal Gmail account has to be External and stay in Testing.

### Project and Drive API

1. Open [Google Cloud Console](https://console.cloud.google.com/) and sign in with the Google account that will own the grocery folder.
2. Open the project picker in the top bar, choose **New project**, name it `Grocery Drive`, and create it. Select that project before the next step. The rest of these pages apply to the selected project.
3. Open [Google Drive API](https://console.cloud.google.com/apis/library/drive.googleapis.com) and click **Enable**. The same page is under **APIs & Services** > **Library**, searching for `Google Drive API`. Drive calls fail until this is enabled. A billing account is not required.

### Consent screen

The first visit to the Auth platform starts a short setup. If you already finished it, set the same fields on the pages below.

1. Open [Google Auth platform > Branding](https://console.cloud.google.com/auth/branding).
2. App name: `Grocery Drive`. Leave the word Google out of the name. Google rejects that.
3. User support email: your email.
4. Audience: **External**.
5. Contact email: your email. Finish the wizard. Agree to the user-data policy when it asks.

Then open [Audience](https://console.cloud.google.com/auth/audience):

1. Leave the publishing status on **Testing**. Do not click **Publish app**.
2. Under **Test users**, click **Add users** and add the same Google account you will sign in with. Testing mode allows only those accounts, up to 100.
3. Save.

`https://www.googleapis.com/auth/drive` is a restricted scope. Publishing asks Google to verify the app and run a security assessment. Testing mode is the setup this app uses. While the app stays in Testing, a refresh token expires seven days after you consent. Sign in again when that happens. The app overwrites the saved token.

### Drive scope

1. In the [Google Auth platform](https://console.cloud.google.com/auth/overview) left menu, open **Data Access**.
2. Click **Add or remove scopes**.
3. In **Manually add scopes**, paste `https://www.googleapis.com/auth/drive`.
4. Click **Add to table**, then **Update**, then **Save**.

The scope shows up under restricted scopes. That is expected. Also add `openid` the same way if it is not already listed. The app requests it. Do not submit the app for verification.

### Client id and client secret

1. Open [Clients](https://console.cloud.google.com/auth/clients).
2. Click **Create client**.
3. Application type: **Desktop app**. Name it `Grocery Drive desktop`.
4. Leave **Use this client for an AI-powered agent** unchecked. That setting cannot be changed later.
5. Click **Create**.

Google shows a client id and a client secret. Copy both before you close the dialog.

- The client id ends in `.apps.googleusercontent.com`. That is `GOOGLE_CLIENT_ID`.
- The client secret is a string such as `GOCSPX-...`. That is `GOOGLE_DESKTOP_SECRET`.

If you closed the dialog, open the client in the list. The secret is on that page. **Download JSON** saves the same two values as `installed.client_id` and `installed.client_secret`. That downloaded file is not `secrets/google.json`. Copy the two fields out of it. Do not commit the download. Google's filename contains `client_secret`, and those files are gitignored, but keep the download outside the repo anyway.

Create a **Desktop app** client. A **Web application** client does not give you a client secret this app can send, and it requires an HTTPS redirect.

A Desktop client has no redirect box, and it does not need one. Google accepts `http://localhost` on any port for that client type, which covers `http://localhost:8484` on Windows and on Android. If the create form or the client page does show **Authorized redirect URIs**, add `http://localhost:8484` and save. Delete `com.astrohoff.grocerydrive:/oauthredirect` if it is listed. A Desktop client does not accept it.

## Microsoft

The registration can live in any directory you can sign in to. A personal Microsoft account (Outlook, Hotmail, Live) can register an app. The first visit to the Entra admin center asks you to create a directory. Create it. The directory only holds the app registration. The grocery files still go in that account's OneDrive.

The app talks to `https://login.microsoftonline.com/common`, so the registration has to allow personal accounts and work or school accounts.

### Register the app

1. Open the [Microsoft Entra admin center](https://entra.microsoft.com/) and sign in with the account whose OneDrive you will use. The same pages are in [the Azure portal](https://portal.azure.com/) under **Microsoft Entra ID** > **App registrations**.
2. Go to **Identity** > **Applications** > **App registrations**.
3. Click **New registration**.
4. Name: `Grocery Drive`.
5. Supported account types: **Accounts in any organizational directory (Any Microsoft Entra ID tenant - Multitenant) and personal Microsoft accounts (e.g. Skype, Xbox)**.
6. Under **Redirect URI**, choose **Public client/native (mobile & desktop)** and enter `http://localhost:8484`.
7. Click **Register**.

### Copy the application id

On the **Overview** page, copy **Application (client) ID**. It is a GUID. That is `MICROSOFT_CLIENT_ID`.

Leave **Directory (tenant) ID** out of the app. The app always uses the `common` endpoint.

### Redirects and public client

1. Open **Authentication**.
2. If `http://localhost:8484` is not already listed, choose **Add a platform** or **Add Redirect URI**, then **Mobile and desktop applications**.
3. In **Custom redirect URIs**, add `http://localhost:8484` if it is missing. Do not add a custom scheme. The portal rejects `:/`.
4. Leave the suggested URI `https://login.microsoftonline.com/common/oauth2/nativeclient` unchecked. The app does not send it.
5. Click **Configure**, then **Save**.
6. Under **Advanced settings** (on the **Settings** tab, if the page has tabs), set **Allow public client flows** to **Yes**. The label is sometimes **Enable the following mobile and desktop flows**. Save.

Keep the redirect on **Mobile and desktop applications**. A **Web** platform makes Microsoft expect a client secret, and this app does not send one.

Microsoft ignores the port when it matches a `localhost` redirect, so `http://localhost` would also match. Register `http://localhost:8484` anyway, because that is the string the app sends. If the portal stores it with a trailing slash, leave the saved value. The app still sends the address without a slash.

### Graph permissions

1. Open **API permissions**.
2. **User.Read** is already there as a delegated permission. Keep it.
3. Click **Add a permission** > **Microsoft Graph** > **Delegated permissions**.
4. Search for `Files.ReadWrite`, select that permission, and add it. This is the signed-in user's files. Do not select `Files.ReadWrite.All`.
5. Add delegated `offline_access` the same way. It is under OpenId permissions and is what lets Microsoft return a refresh token. The app also requests `openid`, which does not have its own row here.

A personal Microsoft account consents in the browser. You do not need **Grant admin consent** for that. A work or school account can stop on "Need admin approval". Use a personal Microsoft account, or have a tenant admin grant delegated `Files.ReadWrite`, `User.Read`, and `offline_access`.

### No client secret

Do not open **Certificates & secrets** and create a secret. `secrets/microsoft.json` has no `client_secret` field. The live test never sends one.

## Save the values

`secrets/` is gitignored. Create the files from the repo root before the first sign-in. If a file is missing, sign-in still stores the refresh token in secure storage, and the live test cannot see it.

`secrets/google.json`

```json
{
  "client_id": "your-google-client-id",
  "client_secret": "your-google-secret",
  "refresh_token": ""
}
```

Leave `client_secret` as an empty string when the Desktop client has no secret.

`secrets/microsoft.json`

```json
{
  "client_id": "your-microsoft-client-id",
  "refresh_token": ""
}
```

`refresh_token` stays empty until you sign in.

From the repo root, pass the same ids into the app. Omit `GOOGLE_DESKTOP_SECRET` when there is no secret. A missing client id hides that provider's button on Settings.

```powershell
flutter run -d windows `
  --dart-define=GOOGLE_CLIENT_ID=your-google-client-id `
  --dart-define=MICROSOFT_CLIENT_ID=your-microsoft-client-id `
  --dart-define=GOOGLE_DESKTOP_SECRET=your-google-secret
```

These defines are compiled in. Change a value, and run the command again. Hot reload keeps the old id.

`flutter run` needs the defines on every launch because it rebuilds. `tool/build_windows.ps1` and `tool/build_android.ps1` read the client ids from the secrets files. One builds a Windows exe, and the other builds an Android APK. The README sections **Windows app** and **Android app** have the steps. The command above is still how you run a Windows debug build. Android debug is the same defines with `flutter run -d device-id`.

## Sign in, which writes the refresh token

Nothing is listening on port 8484 except this sign-in. Close another Grocery Drive window before you start.

Open **Settings** and click **Sign in with Google**. The system browser opens.

1. Sign in as the test user you added.
2. Google shows a testing warning because the app is unverified. Continue. On the current screen that is **Advanced**, then **Go to Grocery Drive (unsafe)**.
3. Allow the Drive permission. Leave it checked. The consent screen is asking to see, edit, create, and delete all files in that Drive. That is the `drive` scope, and the app needs it to read a list a bot wrote.
4. The browser says you can close the window. On the phone, switch back to Grocery Drive. Settings closes and the list opens. The app creates a folder named Groceries the first time you sign in.

Open `secrets/google.json`. `refresh_token` is now a long string. The app wrote it because the file was already there.

Sign in with Microsoft the same way. The browser lists the Graph permissions you added. Accept them. `secrets/microsoft.json` then has its own `refresh_token`.

The app keeps one signed-in provider at a time. Signing in to the second provider switches the active account. Each JSON file keeps the refresh token from its own sign-in. Sign-out removes the token from secure storage and leaves the JSON files alone.

The app sends Google `access_type=offline` and `prompt=consent`, so each Google sign-in returns a new refresh token and replaces the one in `secrets/google.json`.

## Live check

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\check_live.ps1
```

Until both JSON files exist, the script prints `NEEDS_HUMAN_CREDENTIALS` and exits 2. A file with an empty `refresh_token` fails the round-trip. The round-trip creates `Roundtrip.md` in the Groceries folder, checks it, and deletes it. It does not change `Groceries.md`.

The script reads the client id and the Google secret from those JSON files. You do not pass dart-defines to it yourself.

## When sign-in fails

- The Settings button is missing or disabled. The client id was empty at compile time. Run `flutter run` again with that `--dart-define`.
- Google says the app is blocked, or `access_denied`, and you are not on the test-user list. Add that Google account under **Audience** > **Test users** and stay in Testing.
- `redirect_uri_mismatch` from Google, or Microsoft says the `redirect_uri` is not valid. The app sends `http://localhost:8484`. On Google, confirm the client type is **Desktop app**. On Microsoft, confirm that URI is on **Mobile and desktop applications**. A debug app keeps the old redirect until you `flutter run` again.
- Google returns `invalid_request` and says the client secret is missing. Copy the Desktop client's secret into `GOOGLE_DESKTOP_SECRET` and into `secrets/google.json`.
- Microsoft asks for admin approval. The account is a work or school account. Use a personal Microsoft account, or have an admin grant the three delegated permissions.
- `Port 8484 is already in use`. Close the other sign-in window and try again.
- The browser returns, and the app says the provider did not return a refresh token. On Google, repeat sign-in and accept the Drive permission. On Microsoft, add delegated `offline_access` and sign in again.
- Settings says Google did not grant Drive access, or a Drive call returns `insufficient authentication scopes`. The saved grant has `openid` and not `https://www.googleapis.com/auth/drive`. On **Data Access**, confirm that scope is listed. Sign in with Google again from the repo root and leave the Drive permission checked. Signing out does not replace a token that never received Drive access.
- The live check fails a week after a successful Google sign-in. Testing-mode refresh tokens expire after seven days. Sign in with Google again from the repo root.
