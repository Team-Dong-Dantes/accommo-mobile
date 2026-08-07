# Accommo Mobile — Workflow Guide

## Team
- **Dev A** — Landlord interface
- **Dev B** — Student interface

---

## 1. Directory Structure

```
src/
  modules/
    auth/                  ← Auth pages (login, register) — touch sparingly
      pages/
      components/
      router/
        routes.ts
    landlord/              ← Dev A owns this (entirely)
      pages/
        LandlordDashboard.vue
      components/
      router/
        routes.ts          ← Landlord-only routes
    student/               ← Dev B owns this (entirely)
      pages/
        StudentDashboard.vue
      components/
      router/
        routes.ts          ← Student-only routes
  shared/                  ← Both contribute, coordinate changes
    pages/
      ErrorNotFound.vue
    components/
    composables/
    utils/
      config.ts
      supabase.ts
      upload.ts
    types/
      database.ts
      database.gen.ts
  layouts/                 ← Shared (MainLayout, AuthLayout)
  stores/                  ← Shared (auth store)
  router/
    index.ts               ← Auto-imports all module routes
    routes.ts              ← Combines module routes
```
src/
  modules/
    landlord/              ← Dev A owns this (entirely)
      pages/
      components/
      router/
        routes.ts          ← Landlord-only routes
    student/               ← Dev B owns this (entirely)
      pages/
      components/
      router/
        routes.ts          ← Student-only routes
  shared/                  ← Both contribute, coordinate changes
    components/            ← Reusable (PropertyCard, LoadingSpinner, etc.)
    composables/
    utils/
    types/
  layouts/                 ← Shared (MainLayout, AuthLayout)
  stores/                  ← Shared (auth store, etc.)
  router/
    index.ts               ← Auto-imports both module routes
```

**One rule:** never edit a file inside the other dev's module folder.

---

## 2. GitHub & Branch Strategy

```
master (protected)          ← stable, deployable
  └── feat/landlord-xxxxx   ← Dev A (PR into master)
  └── feat/student-yyyyy    ← Dev B (PR into master)
deploy                      ← auto-deployed branch
```

### Workflow:
1. **Create an Issue** on GitHub for each task (e.g., "Add landlord property form")
2. **Branch from `master`** with naming convention:
   - `feat/landlord-<short-description>` (Dev A)
   - `feat/student-<short-description>` (Dev B)
3. **Work in your module** — commit and push regularly
4. **Open a Pull Request (PR)** on GitHub:
   - Title: `feat: add property form`
   - Description: "Closes #3" (links to the issue)
   - Assign the other dev as **Reviewer**
5. **Review** — the reviewer checks the diff, comments, approves
6. **Merge** — once approved, click "Squash and merge" on GitHub
7. **Delete the branch** (GitHub offers this after merge)

---

## 3. Pull Request Rules

- **Every PR needs 1 review** from the other dev before merging
- **No pushing directly to `master`** — always through a PR (branch protection enforces this)
- **Keep PRs small** — one feature per PR, ideally under 300 lines changed
- **Write a description** — what changed and why. Link the issue with "Closes #N"

### PR Checklist (before opening):
- [ ] Code compiles (`npm run build`)
- [ ] Lint passes (`npm run lint`)
- [ ] No console.log / debug code left in
- [ ] Added route in your module's `routes.ts` (not the other's)
- [ ] If you modified `shared/`, `layouts/`, or `stores/` — told the other dev

---

## 4. Adding a New Page

### Dev A (Landlord)
```
git checkout master && git pull
git checkout -b feat/landlord-my-properties
# Create: src/modules/landlord/pages/MyPropertiesPage.vue
# Add route in: src/modules/landlord/router/routes.ts
# Add nav link in: src/layouts/MainLayout.vue (only shared file you touch)
git add . && git commit -m "feat: add my properties page"
git push -u origin feat/landlord-my-properties
# Open PR on GitHub → assign Dev B as reviewer
```

### Dev B (Student)
```
git checkout master && git pull
git checkout -b feat/student-payment-history
# Create: src/modules/student/pages/PaymentHistoryPage.vue
# Add route in: src/modules/student/router/routes.ts
# Add nav link in: src/layouts/MainLayout.vue (only shared file you touch)
git add . && git commit -m "feat: add payment history page"
git push -u origin feat/student-payment-history
# Open PR on GitHub → assign Dev A as reviewer
```

---

## 5. Shared Code

When you need a component or utility that the other dev might also use:

1. Build it in **your own module first**
2. If the other dev needs it, **move it** to `src/shared/components/` or `src/shared/utils/`
3. **Tell the other dev** before moving — they may need to update imports

**Examples of shared candidates:**
- `PropertyCard` (both show listings)
- `LoadingSpinner` / `EmptyState`
- Date formatting utils
- Database type definitions

---

## 6. What to Coordinate

| Situation | Action |
|-----------|--------|
| Adding a nav item to MainLayout | Quick chat — minimal conflict |
| Modifying the auth store | Tell the other dev — affects both |
| Modifying a shared component | Tell the other dev — might break their UI |
| Adding a new Supabase table/migration | Coordinate — both may need new queries |
| Changing route paths | Tell the other dev — might affect links |
| Upgrading a dependency | Create a separate PR, both test |

---

## 7. Issues & Project Board (Recommended)

1. **Create an Issue** per task: https://github.com/Team-Dong-Dantes/accommo-mobile/issues
2. **GitHub Project Board**: go to repo → Projects → create a board with columns:
   - `To Do` → `In Progress` → `In Review` → `Done`
3. **Link PRs to Issues** by writing "Closes #3" in the PR description

---

## 8. Running the App

```bash
npm run dev        # Quasar dev server (http://localhost:9000)
npm run build      # Production build
npm run lint       # Run before every PR
```

---

## 9. Deployment

Only `master` gets deployed. When the team agrees it's release time:

```bash
git checkout master && git pull
git checkout deploy
git merge master
git push
```

No one works on the `deploy` branch directly.

---

## 10. Branch Protection Setup (GitHub)

To enforce PR reviews on master, go to each repo's **Settings → Branches → Add rule**:
- Branch name pattern: `master`
- ☑ Require a pull request before merging
- ☑ Require approvals (1)
- ☐ Dismiss stale pull request approvals (optional)
- ☐ Include administrators (optional)

This prevents accidental pushes to `master` and ensures every change is reviewed.
