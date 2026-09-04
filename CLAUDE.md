# Accommo Mobile

Student and accommodation-manager client. Quasar, Vue 3, TypeScript, Pinia, Supabase, Capacitor. Shares one Supabase backend with the sibling `accommo-web` repo (see `../AGENTS.md` if present).

## Current state: rebuild in progress

The feature screens were deliberately stripped. Only auth, the app shell, and shared infrastructure remain. **`docs/FEATURES.md` is the specification for everything being rebuilt** — read it before building any screen; it records each screen's purpose, flows, tables, and the UI patterns worth building once and reusing.

The pre-strip code is not lost: branch `pre-rebuild-snapshot` (commit `a6aec03`) has every original screen. Pull up a reference implementation with `git show pre-rebuild-snapshot:src/pages/student/StudentDiscover.vue`.

## Role terminology — read before renaming anything

- App-level UI/routing role is **`manager`** (`/manager/*` routes, `pages/manager/`).
- The **database role enum** is `accommodation_manager`. `stores/auth.ts` maps between them at the DB boundary — preserve that mapping.
- The **database schema still uses `landlord_*` identifiers**: `landlord_id`, `landlord_profiles`, `landlord_reviews`, `landlords`. These are the DB contract and must NOT be renamed to `manager_*`. Any remaining "landlord" string in `src/` is one of these DB identifiers and is intentional.

## Structure

```
src/
  boot/            Quasar boot files (deeplink, iconify, keyboard, notify, pinia)
  css/
  layouts/         AuthLayout · MainLayout (one shell for both signed-in roles)
  pages/
    auth/          GetStarted, Login, Register, ManagerRegister, RoleSelect
    UIBible.vue (dev-only style reference) · ErrorNotFound.vue
  components/
    auth/          Auth* form primitives, ConnectedGoogleBox, EmailVerifyInline
    layout/        BottomNav · QuickActions
    shared/        EmptyState
  router/          index.ts (guards) · routes.ts · auth.ts
  stores/          auth
  types/           database.gen.ts (generated) · forms.ts · app-types.ts
  utils/           supabase, format, upload, cloudinaryUrl, chatFullscreen, config, transition
```

As features return: pages go in `src/pages/<role>/` with the role prefix (`ManagerDashboard.vue`, `StudentDiscover.vue`); drill-down views (detail screens, wizards, scanners) go in `src/components/<role>/` **without** the prefix and without a `Page` suffix (`PropertyDetail.vue`, `QRScanner.vue`). `pages/` is nav destinations only. Route registration goes in `src/router/<role>.ts`, mounted as children of MainLayout in `routes.ts` — never redeclare a route in both places, the root file's copy is silently shadowed.

## The app shell

`layouts/MainLayout.vue` serves both signed-in roles. It reads the role from the path prefix (`/manager` vs `/student`) and drives bottom tabs, quick actions, and back-button sub-pages from the `SHELLS` config object at the top of its script block. To add a tab, quick action, or a screen needing a back-arrow header, edit that config; do not fork the layout. Nav markup lives in `components/layout/`.

Note: MainLayout is currently unmounted — `routes.ts` has no children for it until feature routes return. The router guards in `index.ts` still redirect signed-in users to `/manager/dashboard` and `/student/home`, which 404 until those routes are rebuilt. That is expected mid-rebuild.

Admin/OSAS has no surface in this app — it lives in `accommo-web`. Do not add admin routes here.

## Efficient Workflow

1. Resolve manager vs. student (vs. auth/shared) before searching.
2. Read only matched files and relevant line ranges. Never `Read` a whole large file when a targeted grep + offset/limit read will do.
3. **`src/types/database.gen.ts` (1600+ lines, generated):** never read in full. Grep for the specific table/interface name only.
4. For files over ~500 lines, grep for the target section first, then Read with offset/limit.
5. Reuse existing components, utilities, types, and visual patterns. Make the smallest correct patch; avoid unrelated refactors.
6. Batch equivalent student and manager edits into one implementation and one verification pass.
7. Never modify `.env` or generated output (`database.gen.ts`).

## Verification Budget

- CSS/copy-only change: `git diff --check -- <files>` and `npm run typecheck`.
- Component or local logic change: the above plus relevant tests when available.
- Routing, auth, shared store, dependency, or multi-file feature change: `npm run typecheck`, then one `npm run build` after the complete batch.
- Do not run a full build after every small edit. No lint script is defined — don't attempt `npm run lint` unless `package.json` changes.
- npm is the package manager (CI uses `npm ci`). Do not reintroduce pnpm lockfiles.

## Shared Backend Changes

The backend is unchanged by the rebuild. If a change touches a table, field, enum, RLS assumption, notification target, or end-to-end workflow shared with `accommo-web`, search usages in both apps, update the migration, update queries/generated types, and verify the end-to-end flow.

Do not commit, push, or create a pull request unless explicitly requested.
