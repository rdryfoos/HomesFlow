# Feature Specification: HomesFlow MVP

**Feature Branch**: `001-mvp`

**Created**: 2026-06-28

**Status**: Draft (clarified + planned)

**Input**: `HomesFlow.prd.md` — full MVP scope for native iOS second-home management.

> IDs inherited from PRD. Do not mint new IDs in this file. See PRD § ID Registry.

## Intended Use

HomesFlow helps primary homeowners manage a second home by sharing procedures, service contacts, and real-time task status with trusted family, caregivers, and guests — from iPhone or iPad, including offline.

## Risk & failure modes

Per `traceability.md` §9.3.

| Failure | User impact | Mitigation / trace |
|---------|-------------|-------------------|
| Unauthorized role escalation | Guest or revoked user changes data | RLS + `PermissionService`; AC-GUEST-02, AC-GUEST-05; fail closed |
| Offline edit conflict | User's change silently lost or wrong status shown | Timestamp-wins + notification; AC-PROC-03, AC-HOME-03, AC-SYNC-01 |
| Home photo upload before sync | Upload fails opaquely | Block until home synced; AC-HOME-08 |
| Guest sees restricted content | Privacy leak across visibility tiers | Repository filters + deny UI; AC-GUEST-01, AC-GUEST-03 |
| Sync failure in low connectivity | Stale UI, duplicate actions | Pending-sync indicators; AC-SYNC-04; offline queue (NFR-OFFL-01) |

## User Scenarios & Testing

### User Story 1 — Owner sets up a home (Priority: P1)

**ID**: US-ADMIN-01

An Owner creates a home profile with address, photos, and key info, then sees it on their dashboard.

**Why this priority**: Without a home, no other feature delivers value. This is the foundation.

**Independent Test**: Owner signs in, creates one home with valid data, and sees it on the dashboard without inviting anyone.

**Acceptance Scenarios**:

1. **AC-HOME-01** — Given authenticated Owner on connected device, when valid home details and photos submitted, then home created and visible on dashboard with correct data.
2. **AC-HOME-02** — Given incomplete/invalid home details, when Owner saves, then validation errors shown and home not created.
3. **AC-HOME-03** — Given Owner edits home offline while another device edits same home, when both reconnect, then most recent timestamp wins and conflict log entry created.
4. **AC-HOME-06** — Given Owner or Manager user uploads home photo, when saved to Storage, then client uploads display-optimized JPEG bounded to a maximum pixel dimension (not full camera resolution).
5. **AC-HOME-07** — Given user previously loaded home photo on this device, when they view dashboard or home detail again, then hero photo renders from local cache without re-downloading from Storage.
6. **AC-HOME-08** — Given home not yet synced to server, when Owner or Manager user attempts photo upload, then upload blocked with actionable guidance to sync first.
7. **AC-HOME-09** — Given iPad regular width home detail, when any section selected, then trailing area shows section content only at the home level (no home hero or horizontal tabs; nested section list | detail allowed).
8. **AC-HOME-10** — Given iPad home detail, when any section selected, then leading column shows compact hero + vertical tabs and trailing area uses three-panel layout (section list + section detail) for Procedures, Contacts, Files, and People.
9. **AC-HOME-11** — Given home detail on any device, when section navigation shown, then labels are Procedures, Contacts, Files, and People.
10. **AC-HOME-12** — Given permitted user views a section list (Contacts, Files, People), then a single add action appears as toolbar primary action with parallel construction (plus icon + accessible label) opening the create sheet; no add action without permission.
11. **AC-HOME-13** — Given user opens file detail, when they tap Preview, then system Quick Look opens (zoom/scroll/playback for supported types); detail shows file summary, metadata, Preview, share, and management actions below.
12. **AC-HOME-14** — Given Owner or Manager adds a file, then camera, photo library, and file browser sources are offered, all feeding the same metadata flow.

---

### User Story 2 — Owner invites and manages users (Priority: P1)

**IDs**: US-ADMIN-02, US-ADMIN-03

Owner invites collaborators by email/phone, assigns Manager or Guest roles, and manages permissions per home.

**Why this priority**: Multi-user collaboration is core to the product narrative; roles gate all other flows.

**Independent Test**: Owner invites one Manager user and one Guest; each signs in and sees role-appropriate access only.

**Acceptance Scenarios**:

1. **AC-USER-01** — Given Owner sends invite with role, when invitee accepts, then added to home with assigned role and permissions.
2. **AC-USER-07** — Given Owner creates invite in MVP, when invitee receives shared link or token and signs in with invited email, then invitee can accept (paste token or open link) and join with assigned role.
3. **AC-USER-02** — Given Owner revokes pending invite, when revoked, then invite token invalid and invitee cannot join.
4. **AC-USER-03** — Given offline invite conflict, when sync occurs, then latest timestamp action wins and Owner notified.
5. **AC-USER-04** — Given Manager role assigned, when user signs in, then can create/modify procedures and service providers.
6. **AC-USER-05** — Given Guest role assigned, when guest signs in, then guest-appropriate fields only and edit disabled.
7. **AC-USER-06** — Given concurrent role changes on multiple devices, when sync occurs, then latest timestamp wins and audit entry records prior role.

---

### User Story 3 — Manager user tracks procedures (Priority: P2)

**ID**: US-EDIT-01

Manager user updates procedure step status and manages step structure (add, rename, reorder, delete) so the household sees an accurate checklist.

**Why this priority**: Procedure tracking is the primary ongoing value after setup.

**Independent Test**: Manager user opens a procedure, marks one step Complete, renames another via long-press, adds a step via Add; Owner sees updated checklist and activity log after sync.

**Acceptance Scenarios**:

1. **AC-PROC-01** — Given Manager user marks step Complete, then status updates for permitted users, the procedures list reflects the new aggregate status and progress immediately, and an activity log entry is created.
2. **AC-PROC-02** — Given Manager user updates step beyond permission, then update blocked with permission error.
3. **AC-PROC-03** — Given offline step conflict, when reconnect, then latest timestamp wins and overwritten user notified via activity log reference.
4. **AC-PROC-04** — Given Owner or Manager user long-presses a step they can modify, then context menu offers Edit, Delete, Move Up, Move Down.
5. **AC-PROC-05** — Given Owner or Manager user taps Add on Steps section, when they save a title, then new step appends at next sort order and syncs to permitted users.
6. **AC-PROC-06** — Given Owner or Manager user creates, renames, reorders, or deletes a step, when change syncs, then it persists for permitted users and activity log entry created.
7. **AC-PROC-07** — Given Guest views a procedure, then step structure controls (long-press menu, Add step) are unavailable and status is read-only.
8. **AC-PROC-08** — Given a step has an attached photo, when user taps Photo attached, then photo opens in a modal preview; step row shows notes below title, pencil Edit left of status ellipsis (when editable), ellipsis rightmost.

---

### User Story 4 — Manager user manages service providers (Priority: P2)

**ID**: US-EDIT-02

Manager user searches, views, and edits service provider contact details.

**Why this priority**: Coordinating repairs and seasonal services is a top homeowner pain point.

**Independent Test**: Manager user edits a provider phone number; change visible to Owner on refresh.

**Acceptance Scenarios**:

1. **AC-HOME-04** — Given Manager user selects provider, when edits contact details, then saved and propagated to permitted users.
2. **AC-HOME-05** — Given Edit vs delete conflict on provider, when sync, then latest timestamp determines final state and editor notified if delete wins.

---

### User Story 5 — Guest accesses limited info (Priority: P3)

**IDs**: US-GUEST-01, US-GUEST-02

Guest sees only guest-appropriate documents and read-only guest procedures.

**Why this priority**: Controlled guest access completes the multi-role model but depends on Owner/Manager setup first.

**Independent Test**: Guest signs in, sees WiFi info and guest procedure, cannot edit or access owner-only content.

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

> **Conflict model evolution** (2026-07-03, from story map): v1 timestamp-wins (AC-SYNC-01) is shipped and verified. The model is being refined to be **data-type-aware**: AC-SYNC-05…07 below. Field-level merge (AC-SYNC-02) is deferred to a post-MVP phase alongside version vectors.

1. **AC-SYNC-01** — Given offline update, when reconnect, then sync runs with timestamp-wins rule and overwrite notification if applicable.
2. **AC-SYNC-02** — Given non-conflicting field edits offline, when sync, then changes merged and audit record created. *(Deferred post-MVP.)*
3. **AC-SYNC-03** — Given stale cached permissions offline, when sync denied by server, then change reverted and permission error shown.
4. **AC-SYNC-04** — Given local changes or homes pending sync, when user views dashboard, then unsynced homes are visibly indicated and user can pull to refresh while online.
5. **AC-SYNC-05** — Given a step is Complete or N/A, when a concurrent offline update conflicts, then sync never silently regresses the terminal status; the conflict is surfaced instead.
6. **AC-SYNC-06** — Given genuinely conflicting status changes from two devices, when both sync, then the conflict is surfaced to a permitted user for human resolution.
7. **AC-SYNC-07** — Given a device is offline, when the user attempts a structural action (step/procedure/provider CRUD, membership changes), then the action is disabled or blocked with clear messaging.

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

### User Story 8 — Log Book (Priority: P2)

**ID**: FR-LOG-02

Owners and Managers write free-form log entries — household-scope or attached to a procedure — viewable in a unified chronological log. Guests are excluded.

**Why this priority**: Added 2026-07-03 from story map planning; extends FR-LOG-01 activity history with user-authored context ("propane topped up", "left the key with the neighbor") that structured status changes cannot capture.

**Independent Test**: Owner writes a household entry and a procedure entry; both appear in the unified log with author and timestamp; a Guest cannot reach the log.

**Acceptance Scenarios**:

1. **AC-LOG-01** — Given an Owner or Manager opens the Log Book, when they save a household-scope entry, then it appears in the unified log with author and timestamp.
2. **AC-LOG-02** — Given an Owner or Manager views a procedure, when they write a procedure-scope entry, then it is attached to the procedure and appears in the unified log.
3. **AC-LOG-03** — Given a permitted user writes an entry offline, when the device reconnects, then the entry syncs append-only and appears for other permitted users.
4. **AC-LOG-04** — Given an entry has synced, when the author edits it, then editing is allowed only within a grace window starting at server receipt; afterwards the entry is immutable.
5. **AC-LOG-05** — Given entries exist at both scopes, when a permitted user opens the unified log, then entries are chronological and filterable by scope.
6. **AC-LOG-06** — Given a Guest is signed in, when they attempt to view the Log Book directly or via deep link, then access is denied with a clear message.

---

### Edge Cases

- Owner revokes user access instantly — user loses access on next sync/sign-in.
- Procedure step marked N/A — status persists and excludes step from progress count.
- Step reordered or deleted while another device edits offline — timestamp-wins conflict rules apply (**AC-PROC-03**, **AC-SYNC-01**).
- Removed user — associated content remains; audit trail preserves who made past changes.
- Insufficient permission — action grayed out or blocked with explicit message (never silent failure).
- iPad vs iPhone — same data, rules, and section labels; layout adapts per device class (see **FR-NAV-01**, **AC-HOME-09…11**).
- Dynamic Type at largest accessibility sizes — scroll where needed; never clip primary actions or truncate section labels without accessibility alternatives.

## Requirements

### Functional Requirements

- **FR-AUTH-01**: System MUST authenticate users via Apple Sign-In and/or OAuth (MVP device builds: email/password only until Apple Sign-In entitlement restored — see Assumptions).
- **FR-USER-01**: System MUST enforce Owner / Manager / Guest roles scoped per home.
- **FR-USER-02**: Owners MUST be able to add, edit, remove users and assign roles.
- **FR-HOME-01**: System MUST support add/edit home properties with address, photos (display-optimized at upload, locally cached for hero display), and key info.
- **FR-HOME-02**: System MUST provide a searchable service provider directory with contacts and notes.
- **FR-HOME-03**: System MUST provide categorized documents with visibility controls (UI section label: **Files**). Permitted users add files from camera, photo library, or file browser; file detail offers Preview via system Quick Look with metadata and actions below.
- **FR-NAV-01**: Home detail MUST expose four sections — **Procedures**, **Contacts**, **Files**, **People** — with device-appropriate navigation: iPhone uses full-bleed hero + horizontal segmented tabs; iPad uses compact left-column hero + vertical icon tabs and a **three-panel** layout (sidebar + section list + section detail) for every section (**AC-HOME-09…11**).
- **FR-PROC-01**: System MUST support procedure lists with status (Not Started / In Progress / Complete / N/A).
- **FR-PROC-02**: Procedures MUST contain ordered steps, each with independent status. Owner and Manager users MUST be able to create, rename, reorder, and delete steps on procedures they can modify (per visibility). Step status updates and structure edits MUST sync offline-capable.
- **FR-PROC-03**: Procedure steps MUST support optional notes and photo attachments; permitted users edit via pencil control or long-press **Edit**; all viewers with access may tap **Photo attached** to preview.
- **FR-GUEST-01**: Guest users MUST see only approved procedures and info.
- **FR-GUEST-02**: System MUST support guest onboarding via email or SMS invite (MVP: shareable invite link + manual token accept — see Assumptions).
- **FR-NOTIF-01**: System SHOULD support optional push notifications for status changes (MVP: defer wiring if needed; UI placeholder acceptable).
- **FR-LOG-01**: System MUST record an activity log of significant changes.
- **FR-LOG-02**: Owners and Managers MUST be able to write free-form Log Book entries at household or procedure scope, shown in a unified chronological log; entries are append-only offline and editable only within a grace window starting at server receipt; Guests have no Log Book access (**AC-LOG-01…06**).

### Non-Functional Requirements

- **NFR-OFFL-01**: Local caching and offline sync MUST be supported from day one.
- **NFR-SYNC-01**: Time-to-sync for updates SHOULD be below 1 second under normal conditions.
- **NFR-PERF-01**: Average screen load SHOULD be under 2 seconds on supported devices. File Quick Look preview MUST stream downloads to a temp file (not load entire payload into memory). Dashboard home-photo prefetch MUST be concurrency-limited.
- **NFR-REL-01**: Target 99.9% crash-free sessions.
- **NFR-SEC-01**: All personal/home/procedure data MUST be encrypted at rest and in transit.
- **NFR-SCALE-01**: Architecture SHOULD support 100,000 concurrent users (no hard load test required for MVP).
- **NFR-A11Y-01**: UI MUST respect iOS accessibility settings — Dynamic Type, VoiceOver, Reduce Motion, and sufficient contrast — and remain usable at all supported content size categories (**AC-A11Y-01…03**).

### Key Entities

- **User** — Authenticated account; may belong to multiple homes with different roles.
- **Home** — Second-home property: address, photos, metadata.
- **Membership** — User ↔ Home link with role (Owner / Manager / Guest).
- **Invite** — Pending invitation token with role, revocable.
- **ServiceProvider** — Vendor contact info scoped to a home.
- **Document** — Categorized file/metadata with visibility level.
- **Procedure** — Named checklist with overall status and category.
- **Step** — Single ordered item within a procedure with its own status, title, optional notes, and optional photo. Owner/Manager can manage step structure; Guest read-only.
- **ActivityLogEntry** — Audit record of a change (who, what, when).
- **LogBookEntry** — User-authored note (household or procedure scope) with author, timestamp, and grace-window editability (FR-LOG-02).

## Success Criteria

- **SC-01**: Owner can complete first-home setup (create home + invite one user) in under 10 minutes.
- **SC-02**: Manager user can update a procedure step and Owner sees change within one sync cycle.
- **SC-03**: Guest cannot access any Owner-only content in manual security review of all screens.
- **SC-04**: Offline edit syncs correctly in 95% of scripted conflict scenarios (timestamp-wins, merge, permission revert).

## Assumptions

- MVP targets iOS 17+ on iPhone and iPad; no Android/web/desktop.
- **Backend**: Supabase (PostgreSQL, Auth, Storage, Realtime).
- **Auth (MVP)**: Email/password via Supabase Auth only on current device builds. Sign in with Apple UI is placeholder; paid Apple Developer Program active — entitlement and Services ID wiring pending (see [research.md](./research.md) D12). Full **FR-AUTH-01** satisfied at App Store submission.
- **Invites (MVP)**: Owner shares `homeflow://invite?token=…` via system share sheet; invitee uses **Join with Invite** and pastes token while signed in with invited email (**AC-USER-07**). Automated email/SMS delivery, Universal Links, and deep-link auto-accept are **Out of Scope** for MVP.
- **Push notifications (FR-NOTIF-01)**: Deferred in MVP — Settings UI placeholder only; no APNs wiring.
- Document upload uses standard iOS file/photo pickers; files stored in Supabase Storage.
- Home photos: client resizes before upload (AC-HOME-06); dashboard and iPhone home-detail hero cards use disk/memory cache (AC-HOME-07); photo upload requires home synced first (AC-HOME-08). Signed URLs may be cached for the session; full-resolution originals are not required for hero display in MVP. Prefetch runs at most two concurrent downloads (NFR-PERF-01). File preview uses streaming download to temp before Quick Look (NFR-PERF-01, AC-HOME-13).
- **Dashboard UX**: Home list uses full-bleed photo hero cards with name/address overlay (FR-HOME-01). iPhone cards ~152pt tall; **iPad dashboard cards ~528pt** with vertically centered photos and `locationLabel` (full address or city/state). iPhone home detail repeats full-bleed hero above horizontal section tabs. iPad home detail uses compact hero in leading column only; trailing area is three-panel (section list | detail) per section (**AC-HOME-09…10**, **FR-NAV-01**).
- **Home sections (UI labels)**: **Procedures** | **Contacts** | **Files** | **People**. *Files* is the user-facing name for the document library (FR-HOME-03); data model entity remains *Document*.
- **App branding**: Branded app icon and static launch screen (black background, green house + white wordmark; @1x/@2x/@3x `LaunchLogo` assets ~1.5× prior size, tighter icon-to-text spacing).
- "Most recent timestamp wins" uses server `updated_at` at sync acceptance time. The conflict model is evolving to be data-type-aware (AC-SYNC-05…07: protect terminal step statuses, human resolution for genuine conflicts, connectivity-gated structural actions); field-level merge (AC-SYNC-02) and version vectors are deferred post-MVP.
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
- Sign in with Apple on device builds until entitlement + Services ID wiring lands (paid program active — see research D12)
