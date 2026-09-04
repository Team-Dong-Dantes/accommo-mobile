# Accommo Mobile

Student and accommodation-manager client. Quasar, Vue 3, TypeScript, Pinia, Supabase, Capacitor. Shares one Supabase backend with the sibling `accommo-web` repo (see `../AGENTS.md` if present).

## Role terminology — read before renaming anything

- App-level UI/routing role is **`manager`** (`/manager/*` routes, `pages/manager/`, `stores/manager.ts`).
- The **database role enum** is `accommodation_manager`. `stores/auth.ts` maps between them at the DB boundary — preserve that mapping.
- The **database schema still uses `landlord_*` identifiers**: `landlord_id`, `landlord_profiles`, `landlord_reviews`, `landlords`. These are the DB contract and must NOT be renamed to `manager_*`. Any remaining "landlord" string in `src/` is one of these DB identifiers and is intentional.

## Structure

```
src/
  boot/            Quasar boot files
  css/
  layouts/         AuthLayout · MainLayout (one shell for both signed-in roles)
  pages/
    auth/          GetStarted, Login, Register, ManagerRegister, RoleSelect
    manager/       Manager*.vue  (manager nav destinations)
    student/       Student*.vue  (all student screens)
    UIBible.vue (dev-only style guide) · ErrorNotFound.vue
  components/
    auth/          Auth* form primitives, ConnectedGoogleBox, EmailVerifyInline
    layout/        BottomNav · QuickActions
    manager/       AddPropertyWizard · PropertyDetail · QRScanner · TenantProfile
                   · AccommodationPhotoPicker
    shared/        EmptyState
  router/          index.ts · routes.ts (root) · auth.ts · manager.ts · student.ts
  stores/          auth · chat · manager · qr · tenant-billing
  shared/
    types/         database.gen.ts (generated) · forms.ts · app-types.ts
    utils/         supabase, avatar, format, upload, validation, env, config, …
```

`pages/` holds **nav destinations** only — the screens reachable from the bottom nav or quick actions. Drill-down views (a detail screen, a wizard, a scanner) are components under `components/<role>/`, even though the router points at them; deep links to them still work. Naming follows the folder: files in `pages/<role>/` carry the role prefix (`ManagerDashboard.vue`, `StudentDiscover.vue`), files in `components/<role>/` do not (`PropertyDetail.vue`, `QRScanner.vue`) and never take a `Page` suffix. Route registration lives in `src/router/<role>.ts`; the root `routes.ts` only composes layouts and spreads those. Do not redeclare a route in both places — the root file's copy is silently shadowed.

## The app shell

`layouts/MainLayout.vue` serves both signed-in roles. It reads the role from the path prefix (`/manager` vs `/student`) and drives everything — bottom tabs, quick actions, and back-button sub-pages — from the `SHELLS` config object at the top of its script block. To add a tab, quick action, or a screen that needs a back-arrow header, edit that config; do not fork the layout. Header/nav markup lives in `components/layout/BottomNav.vue` and `components/layout/QuickActions.vue`.

Admin/OSAS has no surface in this app — it lives in `accommo-web`. Do not add admin routes here.

## Efficient Workflow

1. Resolve manager vs. student (vs. auth/shared) before searching — don't scan both page trees.
2. Read only matched files and relevant line ranges. Never `Read` a whole large file when a targeted grep + offset/limit read will do.
3. **`src/shared/types/database.gen.ts` (1600+ lines, generated):** never read in full. Grep for the specific table/interface name only.
4. **Files over ~500 lines** — grep for the target section/function first, then Read with offset/limit. Current large files: `components/manager/PropertyDetail.vue` (~2900 lines), `pages/student/StudentDiscover.vue` (~1860), `pages/manager/ManagerDashboard.vue` (~1450), `pages/manager/ManagerOSASCompliancePage.vue` (~1280), `pages/student/StudentMessages.vue` (~1240), `components/manager/TenantProfile.vue` (~1070), `pages/student/StudentProfile.vue` (~1040), `pages/student/StudentSupport.vue` (~1030).
5. Reuse existing components, utilities, types, and visual patterns. Make the smallest correct patch; avoid unrelated refactors.
6. Batch equivalent student and manager edits into one implementation and one verification pass.
7. Never modify `.env`, generated output (`database.gen.ts`), or unrelated worktree changes.

## Verification Budget

- CSS/copy-only change: `git diff --check -- <files>` and `npm run typecheck`.
- Component or local logic change: the above plus relevant tests when available.
- Routing, auth, shared store, dependency, or multi-file feature change: `npm run typecheck`, then one `npm run build` after the complete batch.
- Do not run a full build after every small edit. No lint script is defined — don't attempt `npm run lint` unless `package.json` changes.
- npm is the package manager (CI uses `npm ci`). Do not reintroduce pnpm lockfiles.

## Shared Backend Changes

If a change touches a table, field, enum, RLS assumption, notification target, or end-to-end workflow shared with `accommo-web`, search usages in both apps, update the migration, update queries/generated types, and verify the end-to-end flow. See `../AGENTS.md` for the shared table list.

Do not commit, push, or create a pull request unless explicitly requested.
