# CSA system: handover notes

Written 2026-10-03. This file contains **no secrets**. Anything marked
"not in git" has to be recreated or handed over privately.

## What is in this repo

| Part | Folder | What it is |
|---|---|---|
| Mobile app | `flutter_projects/my_first_flutter` | Flutter app for citizens (Android now, iOS being prepared) |
| Admin web | `admin-web` | React + Vite admin portal for CSA staff |
| Mobile API | `csa_backend/csa_mobile_api` | Django REST API for the app (port 8000) |
| Admin API | `csa_backend/csa_admin_api` | Django REST API for the admin portal (port 8001) |
| Shared models | `csa_backend/csa_shared_models` | Models both APIs use |
| DB setup | `csa_backend/db_setup` | SQL to create the database roles (no passwords in it) |

Both APIs use one PostgreSQL database (`csa_db`) with separate roles:
`mobile_api_user`, `admin_api_user` (runtime) and `csa_migrator` (migrations only).
See `csa_backend/SPLIT_ARCHITECTURE.md` and `csa_backend/HTTPS_AND_TOKEN_SETUP.md`.

## Running things locally (Windows)

**APIs.** From `csa_backend`:

```
.\run_server.ps1 -App mobile     # https://<lan-ip>:8000
.\run_server.ps1 -App admin      # https://127.0.0.1:8001
```

This runs uvicorn with HTTPS and DEBUG off. It needs a real `SECRET_KEY` in each
API's `.env` and the certificates (below). Each API has its own `venv`.

**Admin web.** From `admin-web`: `npm install`, then `npm run dev` (http://localhost:5173).
The dev server proxies to the admin API. If the API is on HTTPS, start it with
`ADMIN_API_TARGET=https://127.0.0.1:8001`. Chrome must trust the CSA CA
(import `csa_backend/certs/ca.crt` into the Windows "Trusted Root" store).

**Mobile app.** From `flutter_projects/my_first_flutter`: `flutter pub get`, then `flutter run`.
The app trusts the CSA CA through `assets/certs/csa_ca.pem`.
After a hot reload that changes a const class, use hot restart (`R`). The splash screen
only shows on a cold start.

**Tests.** `flutter test` in the app folder, and `flutter analyze`.

## Things that are NOT in git (recreate them)

| What | Where it goes | How |
|---|---|---|
| Backend `.env` files | `csa_mobile_api/.env`, `csa_admin_api/.env` | Copy each `.env.example`. Use two **different** `SECRET_KEY` values. |
| Admin web `.env` | `admin-web/.env` | Copy `.env.example`. |
| Firebase service-account key | `csa_backend/csa_project/firebase-adminsdk.json` | Create a new key in Google Cloud (see "Open security items"). |
| `firebase_options.dart`, `google-services.json` | `lib/`, `android/app/` | Run `flutterfire configure --project=ascmob-app` (needs access to that Firebase project). |
| HTTPS certificates | `csa_backend/certs/` | `bash csa_backend/certs/make_certs.sh <lan-ip>`. The CA private key and server key are gitignored. If you make a new CA, rebuild the app with the new `ca.crt` as `assets/certs/csa_ca.pem`. |
| Android release keystore | See "Android signing" | Not in the repo. |

Database roles and passwords: follow the comments at the top of
`csa_backend/db_setup/01_roles_and_grants.sql`.

## Android signing

- App ID: `gh.gov.csa.app`. The release build reads `android/key.properties`, which is
  gitignored and points to a keystore file with alias `csa-release`.
- On the previous developer's PC the keystore is a single file outside the repo
  (`...\csa-signing\csa-release.jks`, created 2026-10-03). **It must be handed over securely
  and backed up.** Losing it can block updates to a published app, unless the app uses
  Google Play App Signing.

## iPhone (not finished)

Already done: iOS bundle ID is `gh.gov.csa.app`, a Firebase iOS app is registered for it,
and a native splash and push-notification setup exist. **None of it has been built or run on an
iPhone**, because there was no Mac.

Still to do:
1. Enrol the CSA in the Apple Developer Program (as an organisation; Apple verifies it, which takes days).
2. Build via a cloud service (e.g. Codemagic) or a Mac, and send builds to TestFlight.
3. Upload an APNs key to Firebase (Project settings, then Cloud Messaging, then the iOS app).
4. Replace the default Flutter app icon with a 1024x1024 CSA logo (no transparency).
5. Rename the home-screen name from "My First Flutter" to the CSA name (`CFBundleDisplayName`).
6. Serve `apple-app-site-association` on csa.gov.gh with `<TEAMID>.gh.gov.csa.app` so shared links open the app.
   The Android equivalent (`assetlinks.json`) is also served from csa_mobile_api and needs the release key's fingerprint.
7. Add in-app account deletion (Apple requires it because users can register). Not built yet.

## Open security items

1. **Leaked Firebase service-account keys are in git history.** Two keys for
   `firebase-adminsdk-fbsvc@ascmob-app.iam.gserviceaccount.com` were committed and later removed
   (commit `7f6e3c6a`). They remain in the old Gitea history, not on GitHub.
   Key IDs to delete: `db8596b09e3d…` and `3047223ff138…`.
   Order: create a new key, save it as `firebase-adminsdk.json`, restart the admin API,
   test a push, **then** delete the two old keys. The admin API still loads the old key from that
   file today.
2. **Rotate the database passwords** for all three roles. A password appeared in a chat session, and
   a comment in the SQL file suggests a password was committed at some point. Treat the current ones
   as compromised.
3. **Rotate the Rancard SMS API key.** `csa_mobile_api/.env.example` says it was previously
   hardcoded in `accounts/views.py`.
4. **Remove test staff accounts** (`@example.com`) before go-live.
5. **`csa_backend/csa_mobile_api/tokens.json` is tracked in git.** It holds test JWT access tokens for
   two `@example.com` accounts. They expired in August 2026, so the risk is low, but the file should be
   removed from git and gitignored.

## State of the work at handover

- Everything done recently is **uncommitted** on branch `feature/mcetoday`.
- Remotes: `github` (https://github.com/csa-development/app.git) is the real one. `origin`
  (internal Gitea, 10.1.7.10) was unreachable and is not used.
- GitHub got a clean, single-commit snapshot of this branch (force pushed) because the old history
  contained the leaked keys. Do not push the old history there. If GitHub reports a secret in a push,
  stop and check.
- Mobile OTP expiry is 2 minutes. Shared article links use https://csa.gov.gh.
- Offline banner has a swipe-up-to-dismiss behaviour on purpose.
- Windows desktop and macOS/Linux builds exist in the Flutter project but are not shipped; their IDs are still `com.example...`.
