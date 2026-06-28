# HomeFlow: Second Home Management App

### TL;DR

HomeFlow is a responsive iOS app (iPhone and iPad) that empowers primary homeowners to easily manage a second home by sharing key information, procedures, and real-time statuses with trusted people such as family, caregivers, and guests. The app supports multiple user roles with granular access, organization of key house information (contact/service providers, procedures), and persistent procedure tracking—all tailored for usability on mobile devices.

---

## Goals

### User Goals

* Simple onboarding for setting up one or more homes and inviting trusted users
* Effortless sharing and updating of home procedures and information
* Easily track what needs to get done and its status at a glance
* Granular permissions, so only the right people see or change sensitive information
* Quickly find essential service contacts or documents

### Non-Goals

* No Android, web, or desktop version in initial release
* Not a connected IoT/smart home device management app
* No real-time chat or social community features at launch

---

## User Stories

**Persona: Primary Homeowner (Admin)**

* **US-ADMIN-01** — As an Admin, I want to add my second home's details, so that I can manage it remotely.
* **US-ADMIN-02** — As an Admin, I want to invite adult children and service providers as users, so that they can help manage the home or access info they need.
* **US-ADMIN-03** — As an Admin, I want to assign permissions to Edit or Guest users for each home, so that only trusted users see confidential info.

**Persona: Adult Child/Caregiver (Edit User)**

* **US-EDIT-01** — As an Edit user, I want to update maintenance tasks, so that others can see what's done or outstanding.
* **US-EDIT-02** — As an Edit user, I want to view and modify service provider details, so I can coordinate repairs or services if needed.

**Persona: Guest (Guest User)**

* **US-GUEST-01** — As a Guest, I want to see only guest-appropriate information (like WiFi codes/rules), so my access is controlled and simple.
* **US-GUEST-02** — As a Guest, I want to view house procedures for guests, so I know what is expected during my stay.

---

## Functional Requirements

* **FR-USER-01** (Priority: Critical) — Multi-role (Admin, Edit, Guest) invitation and access logic, scoped per home.
* **FR-AUTH-01** (Priority: Critical) — Secure user authentication via OAuth or Apple ID sign-in.
* **FR-USER-02** (Priority: Critical) — Admins can add, edit, remove users and assign roles.
* **FR-HOME-01** (Priority: High) — Add/edit home properties with address, photos, and key info.
* **FR-HOME-02** (Priority: High) — Service provider directory (propane, electric, internet, lawn care, etc.) with contacts and notes.
* **FR-HOME-03** (Priority: High) — Editable, categorized documents for important details.
* **FR-PROC-01** (Priority: High) — Add/edit procedure lists (e.g., winterizing, arrival prep) with persistent status (Not Started / In Progress / Complete / N/A).
* **FR-PROC-02** (Priority: High) — Procedures contain steps, each with their own status.
* **FR-PROC-03** (Priority: High) — Attach notes, photos, or documents to procedures.
* **FR-GUEST-01** (Priority: Medium) — Guest users view only approved procedures and info.
* **FR-GUEST-02** (Priority: Medium) — Quick guest onboarding via email or SMS invite.
* **FR-NOTIF-01** (Priority: Medium) — Optional push notifications for changed statuses and new assignments.
* **FR-LOG-01** (Priority: Medium) — History log of changes for accountability.

---

## User Experience

**Entry Point & First-Time User Experience**

* Users download from the iOS App Store (phone or tablet UI).
* Guided onboarding flow for primary homeowner: add first home, basic info, invite additional users (with roles).
* Onboarding screens explain role types and permissions.

**Core Experience**

* **Step 1:** Log in (Apple ID or standard credentials).
  * Minimal friction—Apple biometric sign-in if available.
* **Step 2:** Dashboard shows homes managed/accessible.
  * At-a-glance indicators for open tasks, updates.
* **Step 3:** Tap into a home for detail view.
  * Tabs or sections for Procedures, Service Providers, Documents.
  * Procedures list shows statuses; tap to drill into steps, update status, add comments or files.
  * Service provider list is searchable and editable by permitted users.
  * Document library holds house manuals, WiFi info, care instructions (segmented by visibility).
* **Step 4:** User administration (Admins only): manage house users/roles from settings.
  * Clear prompts for what each user can access/change.
* **Step 5:** Share information (Admins/Editors): quick share/copy/forward useful info to guests.
  * UI guides when info is visible to Guest role or more restricted.
* **Step 6:** Updates are saved instantly; history of changes is visible.

**Advanced Features & Edge Cases**

* Admin can revoke access instantly if trust changes.
* Steps within a procedure can be skipped/marked N/A (for flexibility).
* If a user is removed, clarify what happens to associated procedures/notes.
* Error handling: Unavailable features gracefully grayed out, clear messages if permissions are insufficient.

**UI/UX Highlights**

* Responsive adaptive UI for all iPhone/iPad orientations.
* High-contrast text, large tap targets for accessibility.
* Role-based UI: Users only see actions/features they're permitted for.
* Large, visible status indicators for tasks.

---

## Narrative

Imagine Diane, a homeowner who spends most of her time in Florida, but owns a cherished oceanfront home in Maine. She worries each spring about getting the lawn tended, propane checked, and everything ready for summer visits. Previously, Diane painstakingly emailed procedures, WiFi passwords, and lawn schedules to family and caretakers—never sure if vital steps were missed or what had already been done. With HomeFlow, Diane sets up her second home's profile in minutes, delegating tasks and sharing info with her adult children, trusted handyman, and future guests. Each person sees only what they need, gets notified of tasks, and can update status, providing Jane peace of mind from anywhere. No more confusion—just clarity, control, and time saved for everyone.

---

## Success Metrics

### User-Centric Metrics

* Daily/Monthly Active Users, split by role
* % of users who invite others to collaborate
* Average number of procedures per home actively tracked
* User satisfaction/NPS surveys (in-app)

### Business Metrics (intentionally left blank for now)

### Technical Metrics

* **NFR-REL-01** — 99.9% crash-free sessions
* **NFR-SYNC-01** — Time-to-sync for updates below 1 second
* **NFR-PERF-01** — Sub-2s average screen load times (across devices)

### Tracking Plan

* User registration & login events
* Home added, user invited, role/permission assigned
* Procedure created, step/status updated
* Service provider created/edited
* App open/session start
* Push notifications clicked

---

## Technical Considerations

### Technical Needs

* Modular back-end (user management, home/entities, permissions, procedures)
* Secure API for all data operations (OAuth)
* **NFR-OFFL-01** — Local data caching and offline sync as a core requirement from day one
* Optimized UI code for responsive Apple device rendering

### Integration Points

* Apple Sign-In and/or OAuth
* iOS notification services (APNs)
* (Future) Export/sync with Apple Notes/Reminders

### Data Storage & Privacy

* **NFR-SEC-01** — Encrypted storage for all personal/home/procedure data
* Granular access controls for user/entity relationships
* Compliance with Apple privacy requirements (App Store)

### Scalability & Performance

* **NFR-SCALE-01** — Designed for 100,000 concurrent users
* Efficient background sync for status updates

### Potential Challenges

* Securely managing partial access to entities (i.e., procedure-level permissions)
* Multi-device sync consistency
* Minimizing onboarding friction for less technical users

---

## Milestones & Sequencing

### Project Estimate

* Medium: 2–4 weeks (Lean MVP for core features, 2 platforms, basic flows)

### Team Size & Composition

* Small Team: 2 people (Product/Design/QA, Engineering)

### Suggested Phases

*(To be defined in feature plan.)*

---

## Acceptance Criteria

> Each AC is atomic — one independently testable assertion. IDs are immutable; see `traceability.md`.

### US-ADMIN-01 / FR-HOME-01 — Admin adds second home details

* **AC-HOME-01** — Given an authenticated Admin on a connected device, when they submit valid home details and photos, then the home is created and visible in their dashboard with correct data.
* **AC-HOME-02** — Given an Admin submits incomplete/invalid home details, when they attempt to save, then validation errors are shown and the home is not created.
* **AC-HOME-03** — Given an Admin edits home details while offline and another device edits the same home before sync, when both devices reconnect, then the version with the most recent timestamp is applied and a conflict log entry is created for audit.

### US-ADMIN-02 / FR-USER-01 — Admin invites users

* **AC-USER-01** — Given an Admin provides an email/phone and role and sends an invite, when the invite is accepted, then the invitee is added to the home with the assigned role and receives appropriate permissions immediately.
* **AC-USER-02** — Given an Admin re-sends or revokes an invite before acceptance, when they revoke, then the invite token becomes invalid and the invitee cannot join with that token.
* **AC-USER-03** — Given an Admin invites a user while offline and the invite is processed on another device first, when sync occurs, then the most recent action (invite or revoke) by timestamp determines invite state and the Admin receives a notification of the resolved outcome.

### US-ADMIN-03 / FR-USER-02 — Admin assigns permissions

* **AC-USER-04** — Given an Admin assigns an Edit role to a user, when the user signs in, then they can create and modify procedures and service providers for that home.
* **AC-USER-05** — Given an Admin assigns a Guest role to a user, when the guest signs in, then they see only guest-appropriate fields (e.g., WiFi, guest procedures) and cannot edit protected data.
* **AC-USER-06** — Given concurrent role changes occur on multiple devices, when devices sync, then the change with the most recent timestamp wins and an admin-visible audit entry records the prior role.

### US-EDIT-01 / FR-PROC-02 — Edit user updates maintenance tasks

* **AC-PROC-01** — Given an Edit user views a procedure, when they mark a step Complete, then the step status updates for all users with appropriate visibility and an activity log entry is created.
* **AC-PROC-02** — Given an Edit user attempts to update a step beyond their permission (e.g., another home's admin-only step), when they submit the change, then the app blocks the update and shows a permission error.
* **AC-PROC-03** — Given an Edit user updates a step while offline and another user updates the same step before sync, when both devices reconnect, then the update with the most recent timestamp is persisted and the other user receives a notification about the overwritten change with reference to the activity log.

### US-EDIT-02 / FR-HOME-02 — Edit user manages service providers

* **AC-HOME-04** — Given an Edit user opens the service provider directory, when they search and select a provider, then they can edit contact details and changes are saved and propagated to permitted users.
* **AC-HOME-05** — Given an Edit user edits a provider entry that an Admin later deletes on another device before sync, when both devices sync, then the most recent timestamp between edit and delete determines final state; if delete is most recent the provider is removed and the editor receives a notification that their edit was removed due to delete.

### US-GUEST-01 / FR-GUEST-01 — Guest sees guest-appropriate info only

* **AC-GUEST-01** — Given a Guest signs in to a home, when they view info, then only fields marked for Guest visibility are shown and edit controls are disabled.
* **AC-GUEST-02** — Given a Guest tries to access a restricted procedure or document via deep link, when the app evaluates permissions, then access is denied and a clear message is shown explaining limitations.
* **AC-GUEST-03** — Given the Guest receives updated guest-visibility content while offline and another actor changes visibility before sync, when devices sync, then the most recent timestamp determines visibility and Guests see the latest allowed content.

### US-GUEST-02 / FR-GUEST-01 — Guest views guest procedures

* **AC-GUEST-04** — Given a Guest opens a guest procedure, when they view it, then they can see step descriptions and read-only status but cannot change step statuses.
* **AC-GUEST-05** — Given a Guest attempts to mark a guest step complete, when they submit, then the app rejects the change and logs the attempted unauthorized action for audit.

### Cross-cutting / NFR-OFFL-01 — Offline sync & conflict resolution

* **AC-SYNC-01** — Given any user makes an update while offline, when the device reconnects, then the client syncs changes and the server resolves conflicts with most-recent timestamp wins; the client surfaces a notification when their offline change was overwritten.
* **AC-SYNC-02** — Given two users modify different fields of the same entity while offline, when sync occurs, then both non-conflicting changes are merged and persisted, and an audit record notes the combined update.
* **AC-SYNC-03** — Given a user attempts an action that depends on stale permissions cached offline, when syncing, then if the server denies the action, the client reverts the change and shows a permission error with guidance to retry.

---

## ID Registry (authoritative)

| ID | Type | Summary |
|----|------|---------|
| US-ADMIN-01 | User Story | Admin adds home details |
| US-ADMIN-02 | User Story | Admin invites users |
| US-ADMIN-03 | User Story | Admin assigns permissions |
| US-EDIT-01 | User Story | Edit user updates tasks |
| US-EDIT-02 | User Story | Edit user manages providers |
| US-GUEST-01 | User Story | Guest sees limited info |
| US-GUEST-02 | User Story | Guest views guest procedures |
| FR-USER-01 | FR | Multi-role access per home |
| FR-AUTH-01 | FR | OAuth / Apple sign-in |
| FR-USER-02 | FR | Admin user management |
| FR-HOME-01 | FR | Home CRUD |
| FR-HOME-02 | FR | Service provider directory |
| FR-HOME-03 | FR | Document library |
| FR-PROC-01 | FR | Procedure lists with status |
| FR-PROC-02 | FR | Procedure steps with status |
| FR-PROC-03 | FR | Procedure attachments |
| FR-GUEST-01 | FR | Guest visibility scope |
| FR-GUEST-02 | FR | Guest invite onboarding |
| FR-NOTIF-01 | FR | Push notifications |
| FR-LOG-01 | FR | Activity history log |
| NFR-OFFL-01 | NFR | Offline sync core requirement |
| NFR-SYNC-01 | NFR | Sync under 1 second |
| NFR-PERF-01 | NFR | Screen load under 2 seconds |
| NFR-REL-01 | NFR | 99.9% crash-free sessions |
| NFR-SEC-01 | NFR | Encrypted storage |
| NFR-SCALE-01 | NFR | 100k concurrent users |
| AC-HOME-01 … AC-HOME-05 | AC | Home & provider scenarios |
| AC-USER-01 … AC-USER-06 | AC | User invite & role scenarios |
| AC-PROC-01 … AC-PROC-03 | AC | Procedure step scenarios |
| AC-GUEST-01 … AC-GUEST-05 | AC | Guest access scenarios |
| AC-SYNC-01 … AC-SYNC-03 | AC | Offline sync scenarios |
