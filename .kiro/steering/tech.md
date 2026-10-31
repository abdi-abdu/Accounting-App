---
inclusion: always
---

# Tech Stack

## Flutter — Web First

- **Target**: Flutter web is the primary build target. Mobile (Android/iOS) is planned but not current.
- **Dart SDK**: `>=3.4.0 <4.0.0`
- Any mobile-specific code must be inside a conditional import or clearly guarded — never mixed into shared code paths.

## State Management — Riverpod (hand-written providers only)

- `flutter_riverpod: ^2.5.1`
- **No `riverpod_generator` / `@riverpod` annotations.** All providers are written by hand: `Provider`, `StreamProvider`, `FutureProvider`, `AsyncNotifierProvider`, `NotifierProvider`.
- Providers are declared next to what they expose (see structure.md for placement rules).

## Routing — GoRouter

- `go_router: ^14.2.0`
- Declarative routing with a `redirect` callback that reacts to `authStateProvider` and `currentProfileProvider`.
- Screens never navigate imperatively on success. They update state and let the router react. This is the established pattern — don't break it.

## Backend — Supabase

- `supabase_flutter: ^2.5.6`
- **Auth**: email/password with email confirmation. Custom Access Token hook (`custom_access_token_hook`) injects `app_role` and `business_id` into every JWT.
- **Database**: Postgres with Row-Level Security. All tenant isolation is enforced by RLS — never by client-side filtering.
- **RPC**: `handle_new_business_signup` is a `SECURITY DEFINER` function — the only client-callable path that creates a business/profile/subscription atomically.
- **Edge Functions**: Deno/TypeScript. The Chapa webhook and the subscription status checker use the `service_role` key and are the only code permitted to write `subscriptions.status`.
- The `supabase_auth_admin` role must have `EXECUTE` on `custom_access_token_hook` and `SELECT` on `profiles` — see the auth hook grants in the baseline migration.
- Supabase credentials (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) are loaded from `.env` via `flutter_dotenv`. Never hardcode them.

## Local / Offline Database — Drift

- `drift: ^2.19.0` with `drift_dev: ^2.19.0` and `build_runner: ^2.4.11`
- **Platform-conditional connection via conditional import only** (see structure.md rule 8). Never use `kIsWeb` or `Platform.*` to branch database logic at runtime.
  - **Web**: `WasmDatabase` over OPFS (`sqlite3.wasm` + `drift_worker.dart.js`). No at-rest encryption — accepted, documented limitation.
  - **Mobile (future)**: `NativeDatabase` via SQLCipher (`sqlcipher_flutter_libs`). Per-device key in `FlutterSecureStorage`.
- All Drift table definitions live in `core/database/tables/` (not inside features).
- Re-run `dart run build_runner build --delete-conflicting-outputs` after any table change.
- Every write goes to the local Drift DB first. Remote sync is queued — never block a write on network availability.

## Localization — ARB files + `appL10nProvider`

- Three languages: `en`, `am` (Amharic/Ge'ez), `om` (Afaan Oromo/Latin).
- Source files: `lib/l10n/app_en.arb`, `app_am.arb`, `app_om.arb`.
- Generated via `flutter gen-l10n` (`generate: true` in `pubspec.yaml`, config in `l10n.yaml`).
- **Always use `appL10nProvider` (from `core/localization/app_l10n_provider.dart`), never `AppLocalizations.of(context)`.** The provider bypasses Flutter's widget-tree locale resolution, which is necessary because Afaan Oromo (`om`) is not in Flutter's supported locale list for Material widgets.
- `app.dart` falls back to `Locale('en')` for the `MaterialApp.router` `locale:` argument when the chosen locale isn't supported by `GlobalMaterialLocalizations` — this only affects framework chrome (default tooltips etc.), not app strings.
- NotoSansEthiopic font (`assets/fonts/NotoSansEthiopic-Regular.ttf`) is required for Amharic to render correctly. It is not bundled — must be downloaded from Google Fonts (see SETUP_GUIDE.md).

## Theming

- Material 3, teal seed color.
- `fontFamilyFallback: ['NotoSansEthiopic']` set in `AppTheme` for Ge'ez script rendering.

## Other Packages

| Package | Purpose |
|---|---|
| `shared_preferences: ^2.2.3` | Locale preference (local only, not synced) |
| `flutter_secure_storage: ^9.2.2` | Mobile DB encryption key storage |
| `connectivity_plus: ^6.0.5` | Offline/online detection (sync logic, Phase 10) |
| `flutter_dotenv: ^5.1.0` | Load `.env` at startup |
| `uuid: ^4.4.0` | Local-first UUID generation for new records |
| `path_provider: ^2.1.3` | Mobile DB file path |
| `path: ^1.9.0` | File path joining |
