# Phase 0 Setup Guide

Follow these steps in order on your own machine (this scaffold was built in a sandbox without the Flutter SDK, so these commands need to be run locally).

## 1. Install prerequisites (if not already installed)
- Flutter SDK: https://docs.flutter.dev/get-started/install
- Verify with: `flutter doctor` — resolve any red flags before continuing
- Android Studio (for Android) and/or Xcode (for iOS, Mac only)

## 2. Create the base Flutter project (with web enabled)
```bash
flutter create sba_app --org com.yourcompany --platforms web
cd sba_app
```

## 3. Merge this scaffold into the new project
- Delete the `lib/` folder and `pubspec.yaml` that `flutter create` generated
- Copy this scaffold's `lib/`, `pubspec.yaml`, `analysis_options.yaml`, `.env.example`, and `SETUP_GUIDE.md` into your new `sba_app/` project root
- Append the two lines from `.gitignore.additions` into the `.gitignore` that `flutter create` already generated (don't overwrite it — it has platform-specific entries you need)

## 4. Install dependencies
```bash
flutter pub get
```

## 4a. Set up the Amharic font (required before first run)
Download **Noto Sans Ethiopic** from https://fonts.google.com/noto/specimen/Noto+Sans+Ethiopic and place the Regular `.ttf` file at:
```
assets/fonts/NotoSansEthiopic-Regular.ttf
```
This couldn't be bundled automatically (no internet access in the sandbox this scaffold was built in) — see `assets/fonts/README_DOWNLOAD_FONT_HERE.txt` for details. Without this file, Amharic text will render as empty boxes ("tofu").

## 4b. Generate localization code
With `generate: true` already set in `pubspec.yaml`, running `flutter pub get` (step 4) should have already generated `lib/l10n/app_localizations.dart` from the three `.arb` files. If you don't see that file, run:
```bash
flutter gen-l10n
```

**Important:** the Amharic and Afan Oromo strings in the `.arb` files are best-effort translations for Phase 0 proof-of-concept purposes only — have a native speaker review them before this reaches real users. Translation accuracy matters a lot for an accounting tool people trust with their business.

## 5. Set up your Supabase project
1. Create a project at https://supabase.com
2. In your Supabase project dashboard, open the **SQL Editor** and run the entire contents of `Module7_Supabase_Schema.sql` (from our earlier planning session)
3. Go to **Authentication → Hooks** (naming may vary slightly by dashboard version — search "Auth Hooks" if you can't find it) and register `custom_access_token_hook` as the **Custom Access Token** hook. This is what injects `role` and `business_id` into every JWT.
4. Go to **Project Settings → API** and copy your **Project URL** and **anon public key**

## 6. Configure environment variables
```bash
cp .env.example .env
```
Then edit `.env` and paste in your real Supabase URL and anon key.

## 7. Generate Drift's code
```bash
dart run build_runner build --delete-conflicting-outputs
```
This generates `lib/core/database/app_database.g.dart` from the `AppDatabase` class. Re-run this command any time you add or change a Drift table (this becomes routine starting in Phase 2).

## 7a. Set up web offline storage (OPFS + WASM SQLite) — the finicky part
This is the step most likely to need adjustment against Drift's current docs, since the exact files/versions shift:
1. Follow Drift's official **"Using drift on the web"** guide (search "drift web sqlite3 wasm" for the current version) to copy `sqlite3.wasm` and generate the `drift_worker.dart.js` worker file into your project's `web/` folder
2. Serving the app needs COOP/COEP headers enabled for the fast synchronous OPFS path. For local development, run:
   ```bash
   flutter run -d chrome --web-browser-flag "--enable-features=SharedArrayBuffer"
   ```
   (For production hosting, your web server config will need to set the `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp` response headers — the specifics depend on your hosting provider.)
3. If these headers aren't present, Drift falls back to a less durable storage mode automatically (see the `missingFeatures` check already in `connection_web.dart`) rather than failing outright — worth testing both configurations.

## 8. Create a test user
Since real sign-up (UC-01) isn't built until Phase 1, manually create a test user for now:
1. In Supabase, go to **Authentication → Users → Add User**, create a test email/password
2. Go to **Table Editor → businesses**, manually insert a row (any name, `owner_user_id` = the test user's UUID from step above)
3. Go to **Table Editor → profiles**, manually insert a row: `id` = the same user UUID, `business_id` = the business row's id, `role` = `owner`, `full_name` = anything

## 9. Run the app
```bash
flutter run -d chrome
```
You should see: splash screen → login screen → sign in with your test user → home screen showing "Signed in as [name], Role: owner, Business ID: [uuid]" plus a language switcher. Tap through English / አማርኛ / Afaan Oromoo and confirm all three render correctly (Amharic should show actual Ge'ez script, not empty boxes — if it does show boxes, revisit step 4a).

## 10. Verify local offline storage
On web, "verifying encryption" doesn't apply the way it would on mobile — instead, confirm persistence: reload the browser tab after signing in, and confirm you're not bounced back to the login screen unexpectedly, and that the app doesn't error opening its local database. True at-rest encryption is deferred to the mobile build later (Module 5, §1a — an accepted, documented limitation for web).

---

## If Something Doesn't Work

- **`flutter pub get` fails on `sqlcipher_flutter_libs`**: this package is only exercised once the mobile build target is added later — if it causes issues on a web-only setup, it's safe to temporarily comment it out of `pubspec.yaml` and re-add it when Phase-1-for-mobile begins.
- **Web app fails to open the local database, or storage doesn't persist across reloads**: almost always a missing/incorrect OPFS worker setup (step 7a) — double check the COOP/COEP headers are actually being served, and check the browser console for the `missingFeatures` warning logged by `connection_web.dart`.
- **Login succeeds but "No profile found" shows**: double-check the RLS policy `"read profiles in own tenant"` and confirm the `custom_access_token_hook` is actually registered as an Auth Hook — a missing hook means `business_id` never lands in the JWT, and this often silently breaks the very first policy check.
- **`build_runner` errors about missing `part` file**: confirm `app_database.dart` has `part 'app_database.g.dart';` at the top, matching the actual filename.

---

*Once this is working end-to-end, you're ready for Phase 1 of the Implementation Roadmap: real sign-up, tenant bootstrap, and role-based routing.*
