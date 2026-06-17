# Supabase Cloud Sync Contract

Issue #89 defines the backend and runtime config contract for optional Google-login sync. Guest mode remains SQLite-only. Anonymous Supabase auth is unused for v1.

## Database Contract

Apply `supabase/migrations/202606170001_cloud_sync_contract.sql` to the Supabase project before implementing sync clients.

Remote tables:

| Table | Purpose |
| --- | --- |
| `categories` | Synced `Category` rows, including preset/custom and `RetiredCategory` state. |
| `time_blocks` | Synced `TimeBlock` rows on the 10-minute grid. |
| `user_settings` | Per-user notification settings currently stored in shared preferences. |

Identity rules:

- Remote primary keys are UUIDs. Existing local SQLite integer IDs stay local.
- Future SQLite sync metadata should map local rows to remote UUIDs.
- Every table is owned by `owner_id = auth.users.id`.
- `time_blocks.category_id` references `categories` through `(owner_id, category_id)` so a block cannot point at another user's category.

Sync semantics:

- `updated_at` is the last-write-wins comparison value.
- `deleted_at` is a tombstone marker. Sync code should prefer tombstone updates over hard deletes while a delete still needs to propagate.
- `categories.is_hidden` preserves RetiredCategory behavior without deleting historical TimeBlocks.
- Photos, thumbnails, and camera-roll metadata are not part of this contract.

Security:

- Row Level Security is enabled on all sync tables.
- Authenticated users can select, insert, update, and delete only rows whose `owner_id` equals `(select auth.uid())`.
- Anonymous auth is not used. Logged-out users read/write local SQLite only.

## Flutter Runtime Config

Use `--dart-define`; do not commit secrets.

Required keys:

| Key | Value |
| --- | --- |
| `SUPABASE_URL` | Project API URL, for example `https://<project-ref>.supabase.co`. |
| `SUPABASE_ANON_KEY` | Supabase anon publishable key. |
| `GOOGLE_WEB_CLIENT_ID` | Google OAuth web client ID used as server client ID for native Google sign-in. |
| `GOOGLE_IOS_CLIENT_ID` | Google OAuth iOS client ID for bundle ID `com.haram8009.timeTracker`. |
| `GOOGLE_ANDROID_CLIENT_ID` | Google OAuth Android client ID for package `com.haram8009.logit` and the app signing SHA fingerprints. |

Example:

```bash
cd src
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>.apps.googleusercontent.com \
  --dart-define=GOOGLE_ANDROID_CLIENT_ID=<android-client-id>.apps.googleusercontent.com
```

## Google Login Setup

Supabase project:

- Enable Auth provider: Google.
- Register the Google web client ID and secret in the Supabase Google provider settings.
- If multiple Google client IDs are configured, keep the web client ID first.
- Add mobile deep-link redirect URLs only if a later OAuth redirect flow uses `signInWithOAuth`. Native ID-token sign-in does not depend on browser redirect completion.

Flutter/native app:

- Use native Google sign-in, then call Supabase `signInWithIdToken`.
- `GOOGLE_WEB_CLIENT_ID` is passed as Google Sign-In `serverClientId`.
- `GOOGLE_IOS_CLIENT_ID` is passed as iOS `clientId`.
- Supabase Dart requires both Google `idToken` and `accessToken` for Google `signInWithIdToken`.
- iOS must include the Google URL scheme for the iOS reversed client ID in `Info.plist`.
- Android must register debug/release SHA fingerprints for package `com.haram8009.logit` in Google Cloud.

Reference docs:

- Supabase Google Auth: https://supabase.com/docs/guides/auth/social-login/auth-google
- Supabase Dart native ID-token sign-in: https://supabase.com/docs/reference/dart/auth-signinwithidtoken
- Supabase redirect URL config: https://supabase.com/docs/guides/auth/redirect-urls
