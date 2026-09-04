# Accommo Mobile

Student and accommodation-manager client. Quasar, Vue 3, TypeScript, Pinia, Supabase, Capacitor. Shares one Supabase backend with the sibling `accommo-web` repo (see `../AGENTS.md` if present).

## Commands

- `npm run dev` — Quasar dev server (web target, HMR).
- `npm run build` — production web build.
- `npm run typecheck` — `vue-tsc --noEmit`; run after any routing/type/multi-file change.
- No test suite and no lint script are configured.
- Env: copy `.env.example` to `.env` and fill `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`. `.env.local` (gitignored) overrides `.env` — set `VITE_DEMO_MODE=true` there to bypass all auth/role guards in `router/index.ts` for screen-by-screen UI work with no backend. `VITE_MAPBOX_TOKEN` is also read for map features. `quasar.config.ts` inlines these four via `build.define`, so a new env var must be added there too or it won't reach client code.

## Current state: rebuild in progress

The feature screens were deliberately stripped. Only auth, the app shell, and shared infrastructure remain. **`docs/FEATURES.md` is the specification for everything being rebuilt** — read it before building any screen; it records each screen's purpose, flows, tables, and the UI patterns worth building once and reusing.

The pre-strip code is not lost: branch `pre-rebuild-snapshot` (commit `a6aec03`) has every original screen. Pull up a reference implementation with `git show pre-rebuild-snapshot:src/pages/student/StudentDiscover.vue`.

## Role terminology — read before renaming anything

- App-level UI/routing role is **`manager`** (`/manager/*` routes, `pages/manager/`).
- The **database role enum** is `accommodation_manager`. `stores/auth.ts` maps between them at the DB boundary — preserve that mapping.
- The live database is **fully renamed**: `accommodations` (not `properties`), `accommodations.accommodation_manager_id`, `rooms.accommodation_id`, `accommodation_manager_profiles`, `accommodation_documents`. There is **no `landlord_*` identifier anywhere** — if you see one, the types are stale.
- `src/types/database.gen.ts` is generated from the live project (`xuckyyjzfwtxxiwmxvco`). Regenerate it rather than hand-editing, and regenerate after any migration.

## Data reliability (verified against the live DB)

- **Occupancy must be counted from active leases.** `rooms.current_pax` sits at 0 even for accommodations with active tenants, and `rooms.status` disagrees with the lease data (12 "occupied" rooms vs 32 rooms holding active leases). `rooms.capacity` is reliable for bed totals.
- **`payments` has ~2 rows** against 100+ active leases. Do not build collection/arrears metrics; state rent as *expected* from `leases.monthly_rent`.
- **All review tables are empty** (`tenant_reviews`, `accommodation_reviews`, `accommodation_manager_reviews`) — no ratings features.
- Half of managers have zero accommodations, and the median manager has zero rooms; students hold at most one live lease. Design every screen for the empty and single-item case first.

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

`routes.ts` mounts MainLayout with `[...managerRoutes, ...studentRoutes]` from `router/manager.ts` / `router/student.ts` — register new screens in those files, not in `routes.ts` directly. Router guards in `index.ts` resolve the signed-in user's role via a `users.role` lookup (cached on `authStore.cachedRole`) and redirect `/manager/*` vs `/student/*` accordingly; a route not yet added to those files 404s even for an authenticated user of the right role.

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
