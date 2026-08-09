# Student Interface — Overview

Documentation for the student-facing side of **Accommo Mobile**.
Covers the student journey, routes, data model, and how the Student Dashboard
loads its data.

> Owner: Dev B (student module lives in `src/modules/student/`).
> This doc is kept at the repo root and does not touch module code.

---

## 1. Student Journey

```
Get Started → Register (student) → Confirm email → Sign In → Student Hub
```

1. **Get Started** (`/`) — landing page with the role choice
2. **Register** (`/register`) — 4-step wizard:
   | Step | Title | Fields |
   |------|-------|--------|
   | 1 | Personal | Full name, sex, phone (+63) |
   | 2 | Account | Email (`@gmail.com` / `@isu.edu.ph`), password with strength rules |
   | 3 | Academic | College, program (filtered by college), year level |
   | 4 | Verification | ISU Student ID, School ID upload, Assessment of Fees upload |
3. **Email confirmation** — registration sends a confirmation email; account
   status is `pending` until verified (handled by a DB trigger on `auth.users`)
4. **Sign In** (`/login`) — email/password or Google OAuth
5. **Student Hub** (`/student/dashboard`) — current stay + next payment

---

## 2. Routes

| Path | Page | File |
|------|------|------|
| `/` | Get Started | `src/modules/auth/pages/GetStartedPage.vue` |
| `/register` | Student registration | `src/modules/auth/pages/RegisterPage.vue` |
| `/login` | Sign in | `src/modules/auth/pages/LoginPage.vue` |
| `/student/dashboard` | Student Hub | `src/modules/student/pages/StudentDashboard.vue` |

Student-only routes are registered in
`src/modules/student/router/routes.ts` (owned by Dev B).

---

## 3. Data Model (student-related)

| Table | Purpose | Key columns |
|-------|---------|-------------|
| `users` | Shared identity | `id`, `email`, `role` (`student`), `full_name`, `initials`, `sex`, `phone`, `status` |
| `student_profiles` | Enrollment proof | `user_id`, `student_id`, `college`, `program`, `year_level`, `school_id_url`, `assessment_of_fees_url` |
| `leases` | Active stays | `student_id`, `room_id`, `landlord_id`, `status`, `start_date`, `end_date`, `monthly_rent` |
| `payments` | Rent payments | `lease_id`, `amount`, `status` (`due`/`overdue`/`pending_verification`/`paid`), `month`, `description` |
| `rooms` / `properties` | Location info | linked via `leases.room_id` → `rooms.property_id` → `properties` |

### Registration flow (server-side)
1. `supabase.auth.signUp(...)` creates the auth user (with profile metadata)
2. `users` row is ensured (idempotent upsert, `onConflict: 'id'`)
3. `student_profiles` row is inserted with college/program/year/ID + uploaded docs
4. Student signs out → confirms email → signs in

### Dashboard queries (`StudentDashboard.vue`)
- Current stay: `leases` where `student_id = user.id` and `status = 'active'`,
  joined to `rooms` → `properties`
- Next payment: first `payments` row for that lease with status in
  `('due', 'overdue', 'pending_verification')`, ordered by `month`

---

## 4. Google Sign-In

`/register` also supports Google OAuth. After Google auth, the student lands on
the same wizard in "Complete Profile" mode (`isGoogleMode`), which skips the
email/password step and calls `completeGoogleProfile` to fill the profile rows.

---

## 5. Demo / Preview Mode (local only)

To browse the student UI without a real Supabase project:

```
# in .env.local (gitignored)
VITE_DEMO_MODE=true
```

In demo mode the router skips auth guards and data queries resolve to empty
results, so every screen renders with its empty states. Registration and login
complete locally. Remove the flag (or delete `.env.local`) to go back to real
Supabase.

---

## 6. Notes for Contributors

- The student module is owned by **Dev B** — do not edit files under
  `src/modules/student/` without coordinating.
- Adding a student page: create it in `src/modules/student/pages/` and register
  the route in `src/modules/student/router/routes.ts`.
- Auth, `supabase.ts`, and the auth store are shared — coordinate changes
  (see `WORKFLOW.md`).
