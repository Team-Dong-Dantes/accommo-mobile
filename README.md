# accommo-mobile

The student and accommodation-manager client. Quasar (Vue 3 + TypeScript) with
Supabase, packaged for Android with Capacitor and servable as a web SPA.

## Install the dependencies

```bash
npm install
```

## Development

```bash
npm run dev          # dev server at http://localhost:9000
npm run typecheck    # vue-tsc --noEmit; must exit 0
```

## Building

**These are two different targets and they write to two different places.**
Getting this wrong is how the Android app once shipped three-week-old code while
browser testing looked fine.

```bash
npm run build          # web SPA  -> dist/spa          (browser testing only, not a deploy)
npm run build:android  # Android  -> src-capacitor/www (bundled into the APK)
```

`npm run build:android` runs `quasar build -m capacitor -T android`: it compiles
the UI into `src-capacitor/www`, runs `cap sync` to copy it into
`src-capacitor/android/app/src/main/assets/public`, then invokes the native
build. **The native step needs a JDK and the Android SDK.** To produce only the
web bundle and sync — useful for checking what will ship without a JDK:

```bash
npm run build:android -- --skip-pkg
```

Never hand-edit `src-capacitor/www`; Quasar owns it. Everything else under
`src-capacitor/` is an ordinary Capacitor project.

### Releases and the in-app update check

The app is sideloaded from GitHub Releases, so nothing pushes updates the way a
store would. `src/components/shared/UpdateGate.vue` closes that gap: on launch
and on resume it reads the single `public.app_release` row and compares
`latest_version_code` against its own Android `versionCode`.

One integer runs the whole thing — the CI workflow run number. It is the release
tag (`v<run>`), the `versionCode` (passed to Gradle as `ACCOMMO_VERSION_CODE`),
and the `latest_version_code` that the release job PATCHes into Supabase. Local
builds fall back to `versionCode 1`, so nothing changes when you build by hand.

The announce step needs `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in the
repo's GitHub secrets. Without them it warns and skips, and installed apps are
simply never told the release happened.

`min_supported_version_code` is the separate, **manual** lever: raise it and
every build below it shows a blocking wall instead of a dismissible prompt. CI
never touches it. Use it when a shared-backend migration breaks old clients:

```sql
update public.app_release set min_supported_version_code = <run number> where id = 1;
```

The check fails open by design — a network error or a missing row renders
nothing, so a broken check can never lock users out. Android still requires the
user to tap Install; no app can install an APK silently.

### Capacitor configuration

`src-capacitor/capacitor.config.ts`. It must stay TypeScript — `@quasar/app-vite`
v3 dropped `capacitor.config.json`, and the failure mode is quiet: the web bundle
is written, then the build aborts before `cap sync`, so the APK keeps whatever
assets it already had.

### Customize the configuration

See [Configuring quasar.config.js](https://v2.quasar.dev/quasar-cli-vite/quasar-config-file).

## Local demo mode (no backend required)

Preview every screen without a real Supabase project. Create a (gitignored)
`.env.local` with:

```bash
VITE_DEMO_MODE=true
```

Demo auth accepts any email and password. Sign in with an email containing
`student` to open the Student Hub; any other email opens the manager dashboard.

## Database

Migrations live in `supabase/migrations/` and are the schema history for **both**
apps — `accommo-web` reads the same Supabase project and keeps no migrations of
its own. `supabase/.gitignore` and the `supabase/.temp/` entry in this app's
`.gitignore` keep CLI state (project ref, pooler URL) out of the repo; the
migrations themselves are tracked and must stay that way.

After applying a migration, regenerate the types in **both** apps so they stay in
step:

```bash
npx supabase gen types typescript --project-id <ref> > src/types/database.gen.ts
```

## Branching

`development` is the mainline branch. Create feature branches off it (e.g.
`feat/my-feature`) and open a pull request to merge; reserve direct pushes for
small hotfixes.
