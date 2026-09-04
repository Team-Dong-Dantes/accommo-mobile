# Accommo Mobile — Feature & Concept Specification

Captured before the rebuild. This is the record of what the app did, so it can be
reconstructed screen by screen. Auth is being kept as working code; everything
below the auth section is being removed and rebuilt from this document.

The backend does not change. Every table named here already exists in Supabase and
is reflected in `src/types/database.gen.ts`.

---

## 1. Core concepts

**Two client apps, one backend.** `accommo-mobile` serves students and
accommodation managers. `accommo-web` serves OSAS/admin. Admin has no surface in
mobile — an admin who signs in on mobile is signed out and told to use the web app.

**Roles.**
- App-level roles are `student` and `manager`.
- The database role enum value is `accommodation_manager`; `stores/auth.ts` maps
  it to `manager` at the DB boundary. Keep that mapping.
- The live database is fully renamed: `accommodations`, `accommodation_manager_id`,
  `rooms.accommodation_id`, `accommodation_manager_profiles`, `accommodation_documents`.
  No `landlord_*` identifier exists. (An earlier revision of this document said
  otherwise; that reflected a stale generated types file, not the database.)

**The domain in one paragraph.** A manager owns one or more *accommodations*
(properties), each containing *rooms*. A student discovers a room, messages the
manager, and is accepted into a *lease* on that room. The lease generates
*payments*. Either side can raise issues: students file *concerns* against their
manager, and *tickets* go to OSAS. OSAS separately requires managers to keep
*accommodation documents* (permits/clearances) current — that is the compliance
system. QR codes identify students for attendance and lookup.

**The shell.** One layout serves both signed-in roles, configured by path prefix
(`/manager` vs `/student`). It provides: a transparent header carrying the
lowercase `accommo` wordmark and a notification bell with unread dot; a 4-item
bottom nav whose last item is the user's avatar; and a floating `+` button opening
a 3-item quick-action menu. Screens that are drill-downs (detail, wizard, scanner)
replace the header with a back arrow + title and hide the bottom nav.

- Manager tabs: Home · Tenants · Messages · Profile.
  Quick actions: OSAS · Concerns · Accommodations.
- Student tabs: Home · Discover · Messages · Profile.
  Quick actions: OSAS · Concerns · Payments.

**Design language.** Teal primary (`#00897b`), grey-1 page background, white
surfaces, rounded cards, 44px minimum touch targets, safe-area aware, Iconify
`lucide:*` icons, reduced-motion respected. Sub-page entry slides in from the
right; everything else cross-fades. `src/pages/UIBible.vue` is the living style
reference — keep it.

**Recurring UI patterns worth rebuilding as shared components:**
- Fixed bottom search bar + filter button opening a filter bottom sheet
  (used by Discover, both Messages screens, Concerns, Tenants, manager Payments).
- Folder-tab workspace card (used by both OSAS screens and tenant/accommodation detail).
- Bottom sheets for edit/detail forms (used throughout both profiles).
- Empty state, loading skeletons, status chips driven by
  `utils/format.ts` (`LEASE`, `ROOM`, `PAYMENT`, `CONCERN`, `COMPLAINT`
  status maps + `statusText`/`statusColor`).

---

## 2. Auth — KEPT AS-IS (do not rebuild)

Files retained: `src/pages/auth/*`, `src/components/auth/*`,
`src/layouts/AuthLayout.vue`, `src/router/auth.ts`, `src/stores/auth.ts`.

**Screens.** GetStarted (`/`) → Login (`/login`) → Register (`/register`) →
RoleSelect (`/register/role`) → ManagerRegister (`/register/manager`).

**Flows.**
- Email/password and Google OAuth sign-in.
- Student registration: composed `full_name` from separate first/last inputs;
  PH mobile input with fixed `+63` prefix accepting exactly 10 digits starting `9`;
  no phone OTP step.
- Manager registration is account-first across Personal → Account → Verification
  steps (no Business step). After documents are submitted the manager is signed
  out and stays pending until OSAS approves.
- Google signup with no `users` row yet enters RegisterPage's profile-completion
  mode; an existing account attempting `/register` is signed out to
  `/login?accountExists=true`.
- Email OTP verification inline; document upload via Cloudinary.

**Store surface** (`stores/auth.ts`): `login`, `loginWithGoogle`, `register`,
`registerManager`, `createStudentAccount`, `finalizeStudentAccount`,
`createManagerAccount`, `finalizeManagerAccount`, `completeGoogleProfile`,
`completeGoogleManagerProfile`, `submitStudentVerificationDocuments`,
`submitManagerVerificationDocuments`, `sendEmailOtp`, `verifyEmailOtp`,
`sendPhoneVerification`, `verifyPhoneVerification`, `ensureUserRow`,
`getSessionProfile`, `formatProfileData`, `uploadDocument`, `clearCachedRole`.
Tables: `users`, `student_profiles`, `verification_documents`.

**Router guards** (`router/index.ts`, keep): demo-mode bypass via
`VITE_DEMO_MODE`; public routes `/`, `/login`, `/register`, `/register/role`,
`/register/manager`; role cached on the auth store to avoid refetching;
role-based protection of `/student/*` and `/manager/*`; unknown role → signed out.

---

## 3. Student features (to rebuild)

### 3.1 Dashboard — `/student/home`
Briefing-style home. At-a-glance cards, dues attention when a payment is due,
lease overview with a pay action, quick links, and a distinct no-lease state for
students not yet accepted anywhere. Tables: `leases`, `payments`.

### 3.2 Discover — `/student/discover`
The room search and listing detail experience; the largest student screen.
Search + filter bottom sheet. Listing detail is a structured scroll:
headline & rent header → room specifications strip → amenities → move-in
financial breakdown → house policies & rules → about the property & location →
listed-by manager profile → other rooms in this property. Actions: share,
view manager profile, and start a conversation (which creates a conversation and
carries an "apply for this room" context into Messages).
Tables: `accommodations`, `accommodation_images`, `rooms`, `users`,
`student_profiles`, `conversations`, `messages`.

### 3.3 Messages — `/student/messages`
Conversation list + Messenger-style thread (teal theme): top header, date
separators, message rows, bottom composer, info action, conversation search and
filter sheet, new-conversation dialog. Shows an apply-for-this-room banner when
arrived from a listing. Full-screen chat mode hides the app shell via
`utils/chatFullscreen.ts`.
Tables: `conversations`, `messages`, `users`, `leases`, `rooms`.

### 3.4 Stay — `/student/stay`
The student's current tenancy: key details, money at a glance, manager contact
with message action, and links to Concerns and Payments. Supports
"request to leave". Distinct no-active-stay state.
Tables: `leases`, `users`.

### 3.5 Payments — `/student/payments`
Payment list and the pay flow: choose payment method, attach proof of payment,
submit. Tables: `leases`, `payments`.

### 3.6 Concerns — `/student/concerns`
Student-to-manager issue reporting. List with search + filter sheet, new-concern
dialog, a step tracker showing progress, the manager's response, and an activity
trail. Empty states distinguish "no reports at all" from "no search matches".
Tables: `concerns`, `leases`.

### 3.7 Support / OSAS workspace — `/student/support`
Folder-tab workspace card. A dense document clearance matrix showing the
student's required documents and their state, with an upload action per row, plus
ticket raising to OSAS (attach a screenshot of the error).
Tables: `tickets`, `verification_documents`.

### 3.8 Profile — `/student/profile`
Identity header with avatar upload, contact details, and bottom sheets for: edit
profile, emergency contact, current accommodation, boarding history, and the
student's own QR code (expandable). Also links to settings and support.
Tables: `users`, `student_profiles`, `leases`, `payments`, `boarding_history`,
`tenant_reviews`, `verification_documents`.

### 3.9 Notifications — `/student/notifications`
List with unread state, mark-one and mark-all-read, retry on failure.
Table: `notifications`.

---

## 4. Manager features (to rebuild)

### 4.1 Dashboard — `/manager/dashboard`
The manager's operational home: occupancy and portfolio summary, payment
activity with a view-all-payments action, tenant and ticket signals, and entry
points to the compliance workspace.
Tables: `accommodations`, `rooms`, `leases`, `accommodation_documents`, `users`, `tickets`.
Occupancy is counted from active leases, not `rooms.current_pax`/`rooms.status`.

### 4.2 Accommodations — `/manager/properties`
Portfolio list with a summary header, per-accommodation cards, and loading
states. Opens accommodation detail.
Tables: `accommodations`, `accommodation_images`, `rooms`.

### 4.3 Accommodation detail — `/manager/properties/:id` *(drill-down component)*
The largest screen in the app. Folder-tab layout covering the accommodation and
its rooms: photo management for the accommodation, its rooms, and shared
facilities; amenities; policies; occupancy overview; and edit forms for both the
accommodation and individual rooms.
Tables: `accommodations`, `accommodation_images`, `accommodation_amenities`,
`accommodation_facilities`, `accommodation_facility_images`,
`accommodation_policies`, `rooms`, `room_images`.

### 4.4 Add accommodation wizard — `/manager/properties/new` *(drill-down)*
Multi-step creation: details, exterior photos, house rules (add/remove), and
permit uploads. Tables written through `stores/manager.ts` (`addProperty`,
`createAccommodationFacilities`, `createVerificationDocument`).

### 4.5 Tenants — `/manager/tenants`
Grouped by room, showing every room even when empty. Per room: current tenants
and pending applicants. Search + filter sheet. Opens tenant profile.
Tables: `leases`, `rooms`, `users`, `payments`.

### 4.6 Tenant profile — `/manager/tenant/:tenantId` *(drill-down)*
Profile hero + folder tabs: overview of the current stay, payments (with a
log-payment dialog), and boarding history. Decision actions: accept/decline an
application, and approve/decline a leave request.
Tables: `users`, `student_profiles`, `leases`, `payments`, `boarding_history`.

### 4.7 Payments — `/manager/payments`
Payment ledger with search and status filters.
Tables: `payments`, `leases`, `rooms`, `accommodations`, `users`.

### 4.8 Messages — `/manager/messages` and chat — `/manager/chat?conv=<id>`
Conversation list (search + filter sheet) and the Messenger-style thread with an
intro profile card, date separators, composer, and a no-conversation-selected
state. Same teal treatment as the student side.
Tables: `conversations`, `messages`, `users`.

### 4.9 Concerns / support — `/manager/support`
Inbox of student concerns with a handle overview, search + filter sheet, and
decision actions: acknowledge, mark in progress, resolve, reject — with a written
response back to the student.
Tables: `concerns`, `leases`, `rooms`.

### 4.10 OSAS compliance — `/manager/osas-compliance`
Folder-tab workspace with multi-property segment chips, property status and
inspection row, a document clearance matrix with per-document upload of renewed
permits/clearances, ticket raising to OSAS, and a no-properties state.
Tables: `accommodations`, `accommodation_documents`, `complaints`.

### 4.11 QR scanner — `/manager/profile/qr-scanner` *(drill-down)*
Camera scanner (`html5-qrcode` mounted on `#qr-reader`) with corner brackets and
a hint bar. On scan, a result sheet identifies the student and offers: mark
attendance, look up, and view tenancy history.
Store: `stores/qr.ts` (`scanStudent`, `clearScan`). Tables: `users`,
`student_profiles`, `leases`.

### 4.12 Profile — `/manager/profile`
Identity, business contact, and bottom sheets for edit profile, business
contact, and my properties. Hosts the QR scanner entry point and links to
settings. Shows manager rating/reviews.
Tables: `users`, `leases`, `rooms`, `accommodation_manager_reviews`.

### 4.13 Settings — `/manager/settings`
Account and app settings.

### 4.14 Notifications — `/manager/notifications`
Same pattern as the student list. Table: `notifications`.

---

## 5. Infrastructure (kept)

- `utils/supabase.ts` — client + demo mode.
- `utils/format.ts` — `formatPeso`, `formatDate`, `formatMonth`,
  `initialsOf`, `normalizePhPhone`, `phNationalDigits`, and the status maps
  `LEASE` / `ROOM` / `PAYMENT` / `CONCERN` / `COMPLAINT` with
  `statusText` / `statusColor`.
- `utils/upload.ts` — `validateFile`, `uploadToCloudinary`, `uploadDocument`.
- `utils/cloudinaryUrl.ts` — `resolveAsset` and friends; call before any
  `<img src>` on a stored asset.
- `utils/validation.ts` — `validationRules`, `getValidationMessage`.
- `utils/avatar.ts` — `restoreGooglePhoto`.
- `utils/chatFullscreen.ts` — global flag hiding the shell during chat.
- `utils/env.ts`, `config.ts`, `transition.ts`.
- `components/shared/EmptyState.vue`.
- Boot files: `deeplink`, `iconify`, `keyboard`, `notify`, `pinia`.

## 6. Stores being removed (rebuild as needed)

- `stores/chat.ts` — `loadConversations`, `loadMessages`, `sendMessage`,
  `ensureConversation`, `markConversationSeen`, `loadTenantsForNewChat`,
  realtime subscriptions + polling fallback.
- `stores/manager.ts` — `loadDashboard`, `loadProperties`, `addProperty`,
  `createAccommodationFacilities`, `createVerificationDocument`,
  `fetchComplianceItems`.
- `stores/qr.ts` — `scanStudent`, `clearScan`.
- `stores/tenant-billing.ts` — `setCurrentTenant`, `logCashPayment`, `markPaymentPaid`.

## 7. Known behaviours to preserve on rebuild

- Manager terminology is `manager` in the app, `accommodation_manager` in the DB.
- Notifications carry an unread dot in the header; count comes from
  `notifications` where `read_at is null` for the current user.
- Avatar resolution order: uploaded/OAuth image → stored initials fallback.
  The shell listens for an `accommo:avatar-change` window event to update live.
- Chat opens full-screen and suppresses the header, footer and FAB.
- Student ticket state and manager compliance both use the same folder-tab
  workspace pattern — build it once.
