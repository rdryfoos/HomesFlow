# Feature Specification: HomeFlow MVP

**Feature Branch**: `001-mvp`

**Created**: 2026-06-28

**Status**: Draft (clarified + planned)

**Input**: `HomeFlow.prd.md` — full MVP scope for native iOS second-home management.

> IDs inherited from PRD. Do not mint new IDs in this file. See PRD § ID Registry.

## Intended Use

HomeFlow helps primary homeowners manage a second home by sharing procedures, service contacts, and real-time task status with trusted family, caregivers, and guests — from iPhone or iPad, including offline.

## User Scenarios & Testing

### User Story 1 — Admin sets up a home (Priority: P1)

**ID**: US-ADMIN-01

An Admin creates a home profile with address, photos, and key info, then sees it on their dashboard.

**Why this priority**: Without a home, no other feature delivers value. This is the foundation.

**Independent Test**: Admin signs in, creates one home with valid data, and sees it on the dashboard without inviting anyone.

**Acceptance Scenarios**:

1. **AC-HOME-01** — Given authenticated Admin on connected device, when valid home details and photos submitted, then home created and visible on dashboard with correct data.
2. **AC-HOME-02** — Given incomplete/invalid home details, when Admin saves, then validation errors shown and home not created.
3. **AC-HOME-03** — Given Admin edits home offline while another device edits same home, when both reconnect, then most recent timestamp wins and conflict log entry created.
4. **AC-HOME-06** — Given Admin or Edit user uploads home photo, when saved to Storage, then client uploads display-optimized JPEG bounded to a maximum pixel dimension (not full camera resolution).
5. **AC-HOME-07** — Given user previously loaded home photo on this device, when they view dashboard or home detail again, then hero photo renders from local cache without re-downloading from Storage.
6. **AC-HOME-08** — Given home not yet synced to server, when Admin or Edit user attempts photo upload, then upload blocked with actionable guidance to sync first.
7. **AC-HOME-09** — Given iPad regular width home detail, when any section selected, then trailing area shows section content only at the home level (no home hero or horizontal tabs; nested section list | detail allowed).
8. **AC-HOME-10** — Given iPad home detail, when any section selected, then leading column shows compact hero + vertical tabs and trailing area uses three-panel layout (section list + section detail) for Procedures, Contacts, Files, and People.
9. **AC-HOME-11** — Given home detail on any device, when section navigation shown, then labels are Procedures, Contacts, Files, and People.

---

### User Story 2 — Admin invites and manages users (Priority: P1)

**IDs**: US-ADMIN-02, US-ADMIN-03

Admin invites collaborators by email/phone, assigns Edit or Guest roles, and manages permissions per home.

**Why this priority**: Multi-user collaboration is core to the product narrative; roles gate all other flows.

**Independent Test**: Admin invites one Edit user and one Guest; each signs in and sees role-appropriate access only.

**Acceptance Scenarios**:

1. **AC-USER-01** — Given Admin sends invite with role, when invitee accepts, then added to home with assigned role and permissions.
2. **AC-USER-07** — Given Admin creates invite in MVP, when invitee receives shared link or token and signs in with invited email, then invitee can accept (paste token or open link) and join with assigned role.
3. **AC-USER-02** — Given Admin revokes pending invite, when revoked, then invite token invalid and invitee cannot join.
4. **AC-USER-03** — Given offline invite conflict, when sync occurs, then latest timestamp action wins and Admin notified.
5. **AC-USER-04** — Given Edit role assigned, when user signs in, then can create/modify procedures and service providers.
6. **AC-USER-05** — Given Guest role assigned, when guest signs in, then guest-appropriate fields only and edit disabled.
7. **AC-USER-06** — Given concurrent role changes on multiple devices, when sync occurs, then latest timestamp wins and audit entry records prior role.

---

### User Story 3 — Edit user tracks procedures (Priority: P2)

**ID**: US-EDIT-01

Edit user updates procedure step status and manages step structure (add, rename, reorder, delete) so the household sees an accurate checklist.

**Why this priority**: Procedure tracking is the primary ongoing value after setup.

**Independent Test**: Edit user opens a procedure, marks one step Complete, renames another via long-press, adds a step via Add; Admin sees updated checklist and activity log after sync.

**Acceptance Scenarios**:

1. **AC-PROC-01** — Given Edit user marks step Complete, then status updates for permitted users and activity log entry created.
2. **AC-PROC-02** — Given Edit user updates step beyond permission, then update blocked with permission error.
3. **AC-PROC-03** — Given offline step conflict, when reconnect, then latest timestamp wins and overwritten user notified via activity log reference.
4. **AC-PROC-04** — Given Admin or Edit user long-presses a step they can modify, then context menu offers Rename, Delete, Move Up, Move Down.
5. **AC-PROC-05** — Given Admin or Edit user taps Add on Steps section, when they save a title, then new step appends at next sort order and syncs to permitted users.
6. **AC-PROC-06** — Given Admin or Edit user creates, renames, reorders, or deletes a step, when change syncs, then it persists for permitted users and activity log entry created.
7. **AC-PROC-07** — Given Guest views a procedure, then step structure controls (long-press menu, Add step) are unavailable and status is read-only.

---

### User Story 4 — Edit user manages service providers (Priority: P2)

**ID**: US-EDIT-02

Edit user searches, views, and edits service provider contact details.

**Why this priority**: Coordinating repairs and seasonal services is a top homeowner pain point.

**Independent Test**: Edit user edits a provider phone number; change visible to Admin on refresh.

**Acceptance Scenarios**:

1. **AC-HOME-04** — Given Edit user selects provider, when edits contact details, then saved and propagated to permitted users.
2. **AC-HOME-05** — Given Edit vs delete conflict on provider, when sync, then latest timestamp determines final state and editor notified if delete wins.

---

### User Story 5 — Guest accesses limited info (Priority: P3)

**IDs**: US-GUEST-01, US-GUEST-02

Guest sees only guest-appropriate documents and read-only guest procedures.

**Why this priority**: Controlled guest access completes the multi-role model but depends on Admin/Edit setup first.

**Independent Test**: Guest signs in, sees WiFi info and guest procedure, cannot edit or access admin content.

**Acceptance Scenarios**:

1. **AC-GUEST-01** — Given Guest views home info, then only guest-visible fields shown and edit controls disabled.
2. **AC-GUEST-02** — Given Guest deep-links to restricted content, then access denied with clear message.
3. **AC-GUEST-03** — Given visibility changed while Guest offline, when sync, then latest timestamp determines visible content.
4. **AC-GUEST-04** — Given Guest opens guest procedure, then read-only step descriptions and status shown.
5. **AC-GUEST-05** — Given Guest attempts to mark step complete, then change rejected and unauthorized attempt logged.

---

### User Story 6 — Offline sync works reliably (Priority: P1)

**ID**: NFR-OFFL-01 (cross-cutting)

All roles can read and write while offline; sync on reconnect with deterministic conflict rules.

**Why this priority**: PRD mandates offline sync from day one; underpins every other story.

**Independent Test**: User makes change offline, reconnects; change syncs or conflict notification shown per rules.

**Acceptance Scenarios**:

1. **AC-SYNC-01** — Given offline update, when reconnect, then sync runs with timestamp-wins rule and overwrite notification if applicable.
2. **AC-SYNC-02** — Given non-conflicting field edits offline, when sync, then changes merged and audit record created.
3. **AC-SYNC-03** — Given stale cached permissions offline, when sync denied by server, then change reverted and permission error shown.
4. **AC-SYNC-04** — Given local changes or homes pending sync, when user views dashboard, then unsynced homes are visibly indicated and user can pull to refresh while online.

---

### User Story 7 — Accessible, adaptive UI (Priority: P1)

**ID**: NFR-A11Y-01 (cross-cutting)

All primary screens respect iOS accessibility settings, especially Dynamic Type text scaling.

**Why this priority**: HomeFlow serves multi-generational households; accessibility is a first-class product requirement, not polish.

**Independent Test**: Enable largest Dynamic Type and VoiceOver; navigate dashboard → home → procedure; all primary actions remain reachable and readable.

**Acceptance Scenarios**:

1. **AC-A11Y-01** — Given increased iOS text size, when user views dashboard, home detail, or procedures, then text scales, layouts reflow without clipping essential controls, and primary content does not require horizontal scrolling.
2. **AC-A11Y-02** — Given VoiceOver enabled, when user navigates home section tabs, then each tab has a meaningful label and selected state is announced.
3. **AC-A11Y-03** — Given Reduce Motion enabled, when user navigates sections or primary screens, then non-essential animations are reduced or omitted.

---

### Edge Cases

- Admin revokes user access instantly — user loses access on next sync/sign-in.
- Procedure step marked N/A — status persists and excludes step from progress count.
- Step reordered or deleted while another device edits offline — timestamp-wins conflict rules apply (**AC-PROC-03**, **AC-SYNC-01**).
- Removed user — associated content remains; audit trail preserves who made past changes.
- Insufficient permission — action grayed out or blocked with explicit message (never silent failure).
- iPad vs iPhone — same data, rules, and section labels; layout adapts per device class (see **FR-NAV-01**, **AC-HOME-09…11**).
- Dynamic Type at largest accessibility sizes — scroll where needed; never clip primary actions or truncate section labels without accessibility alternatives.

## Requirements

### Functional Requirements

- **FR-AUTH-01**: System MUST authenticate users via Apple Sign-In and/or OAuth (MVP device builds: email/password only until Apple Sign-In entitlement restored — see Assumptions).
- **FR-USER-01**: System MUST enforce Admin / Edit / Guest roles scoped per home.
- **FR-USER-02**: Admins MUST be able to add, edit, remove users and assign roles.
- **FR-HOME-01**: System MUST support add/edit home properties with address, photos (display-optimized at upload, locally cached for hero display), and key info.
- **FR-HOME-02**: System MUST provide a searchable service provider directory with contacts and notes.
- **FR-HOME-03**: System MUST provide categorized documents with visibility controls (UI section label: **Files**).
- **FR-NAV-01**: Home detail MUST expose four sections — **Procedures**, **Contacts**, **Files**, **People** — with device-appropriate navigation: iPhone uses full-bleed hero + horizontal segmented tabs; iPad uses compact left-column hero + vertical icon tabs and a **three-panel** layout (sidebar + section list + section detail) for every section (**AC-HOME-09…11**).
- **FR-PROC-01**: System MUST support procedure lists with status (Not Started / In Progress / Complete / N/A).
- **FR-PROC-02**: Procedures MUST contain ordered steps, each with independent status. Admin and Edit users MUST be able to create, rename, reorder, and delete steps on procedures they can modify (per visibility). Step status updates and structure edits MUST sync offline-capable.
- **FR-PROC-03**: Procedures MUST support notes, photos, and document attachments.
- **FR-GUEST-01**: Guest users MUST see only approved procedures and info.
- **FR-GUEST-02**: System MUST support guest onboarding via email or SMS invite (MVP: shareable invite link + manual token accept — see Assumptions).
- **FR-NOTIF-01**: System SHOULD support optional push notifications for status changes (MVP: defer wiring if needed; UI placeholder acceptable).
- **FR-LOG-01**: System MUST record an activity log of significant changes.

### Non-Functional Requirements

- **NFR-OFFL-01**: Local caching and offline sync MUST be supported from day one.
- **NFR-SYNC-01**: Time-to-sync for updates SHOULD be below 1 second under normal conditions.
- **NFR-PERF-01**: Average screen load SHOULD be under 2 seconds on supported devices.
- **NFR-REL-01**: Target 99.9% crash-free sessions.
- **NFR-SEC-01**: All personal/home/procedure data MUST be encrypted at rest and in transit.
- **NFR-SCALE-01**: Architecture SHOULD support 100,000 concurrent users (no hard load test required for MVP).
- **NFR-A11Y-01**: UI MUST respect iOS accessibility settings — Dynamic Type, VoiceOver, Reduce Motion, and sufficient contrast — and remain usable at all supported content size categories (**AC-A11Y-01…03**).

### Key Entities

- **User** — Authenticated account; may belong to multiple homes with different roles.
- **Home** — Second-home property: address, photos, metadata.
- **Membership** — User ↔ Home link with role (Admin / Edit / Guest).
- **Invite** — Pending invitation token with role, revocable.
- **ServiceProvider** — Vendor contact info scoped to a home.
- **Document** — Categorized file/metadata with visibility level.
- **Procedure** — Named checklist with overall status and category.
- **Step** — Single ordered item within a procedure with its own status, title, and optional notes. Admin/Edit can manage step structure; Guest read-only.
- **ActivityLogEntry** — Audit record of a change (who, what, when).

## Success Criteria

- **SC-01**: Admin can complete first-home setup (create home + invite one user) in under 10 minutes.
- **SC-02**: Edit user can update a procedure step and Admin sees change within one sync cycle.
- **SC-03**: Guest cannot access any Admin-only content in manual security review of all screens.
- **SC-04**: Offline edit syncs correctly in 95% of scripted conflict scenarios (timestamp-wins, merge, permission revert).

## Assumptions

- MVP targets iOS 17+ on iPhone and iPad; no Android/web/desktop.
- **Backend**: Supabase (PostgreSQL, Auth, Storage, Realtime).
- **Auth (MVP)**: Email/password via Supabase Auth only on current device builds. Sign in with Apple UI is placeholder; entitlement deferred until paid Apple Developer Program (required before App Store — see [research.md](./research.md) D12). Full **FR-AUTH-01** satisfied at App Store submission.
- **Invites (MVP)**: Admin shares `homeflow://invite?token=…` via system share sheet; invitee uses **Join with Invite** and pastes token while signed in with invited email (**AC-USER-07**). Automated email/SMS delivery, Universal Links, and deep-link auto-accept are **Out of Scope** for MVP.
- **Push notifications (FR-NOTIF-01)**: Deferred in MVP — Settings UI placeholder only; no APNs wiring.
- Document upload uses standard iOS file/photo pickers; files stored in Supabase Storage.
- Home photos: client resizes before upload (AC-HOME-06); dashboard and iPhone home-detail hero cards use disk/memory cache (AC-HOME-07); photo upload requires home synced first (AC-HOME-08). Signed URLs may be cached for the session; full-resolution originals are not required for hero display in MVP.
- **Dashboard UX**: Home list uses full-bleed photo hero cards with name/address overlay (FR-HOME-01). iPhone cards ~152pt tall; **iPad dashboard cards ~280pt** with top-aligned photos and `locationLabel` (full address or city/state). iPhone home detail repeats full-bleed hero above horizontal section tabs. iPad home detail uses compact hero in leading column only; trailing area is three-panel (section list | detail) per section (**AC-HOME-09…10**, **FR-NAV-01**).
- **Home sections (UI labels)**: **Procedures** | **Contacts** | **Files** | **People**. *Files* is the user-facing name for the document library (FR-HOME-03); data model entity remains *Document*.
- **App branding**: Branded app icon and static launch screen (black background, green house + white wordmark; @1x/@2x/@3x `LaunchLogo` assets ~1.5× prior size, tighter icon-to-text spacing).
- "Most recent timestamp wins" uses server `updated_at` at sync acceptance time.
- Offline: local SwiftData cache + outbox queue; sync on reconnect; pending-sync homes indicated on dashboard (AC-SYNC-04).
- **Step assignees**: Out of MVP scope (prototype shows assignees; ignore for v1).
- **Contacts tab**: Implements **service providers** only (FR-HOME-02); no separate key-contacts entity.
- **Files tab**: Implements **documents** (FR-HOME-03); UI label is Files, not Documents.
- **Accessibility**: Dynamic Type, VoiceOver labels, 44×44 pt minimum tap targets, and Reduce Motion are required from MVP (**NFR-A11Y-01**), not deferred polish.
- **UI reference**: [Figma prototype](https://haze-rabbit-58180688.figma.site) — layout inspiration only; SwiftUI-native iPhone/iPad layouts per plan, PRD wins on behavior.

## Out of Scope (MVP)

- Android, web, desktop clients
- IoT / smart home integration
- In-app chat or social features
- Export to Apple Notes/Reminders (future integration)
- Per-step assignees
- Separate key-contacts entity (use service providers)
- Automated invite email/SMS delivery (MVP uses manual share + token paste per AC-USER-07)
- Universal Links / deep-link auto-accept for invites (`homeflow://` scheme only; paste fallback)
- Sign in with Apple on device builds until paid developer program + entitlement (see research D12)
