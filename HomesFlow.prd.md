# HomesFlow: Second Home Management App

### TL;DR

HomesFlow is a responsive iOS app (iPhone and iPad) that empowers primary homeowners to easily manage a second home by sharing key information, procedures, and real-time statuses with trusted people such as family, caregivers, and guests. The app supports multiple user roles with granular access, organization of key house information (contact/service providers, procedures), and persistent procedure tracking—all tailored for usability on mobile devices.

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

**Persona: Primary Homeowner (Owner)**

* **US-ADMIN-01** — As an Owner, I want to add my second home's details, so that I can manage it remotely.
* **US-ADMIN-02** — As an Owner, I want to invite adult children and service providers as users, so that they can help manage the home or access info they need.
* **US-ADMIN-03** — As an Owner, I want to assign permissions to Manager or Guest users for each home, so that only trusted users see confidential info.

**Persona: Adult Child/Caregiver (Edit User)**

* **US-EDIT-01** — As a Manager user, I want to update maintenance tasks, so that others can see what's done or outstanding.
* **US-EDIT-02** — As a Manager user, I want to view and modify service provider details, so I can coordinate repairs or services if needed.

**Persona: Guest (Guest User)**

* **US-GUEST-01** — As a Guest, I want to see only guest-appropriate information (like WiFi codes/rules), so my access is controlled and simple.
* **US-GUEST-02** — As a Guest, I want to view house procedures for guests, so I know what is expected during my stay.

---

## Functional Requirements

* **FR-USER-01** (Priority: Critical) — Multi-role (Owner, Manager, Guest) invitation and access logic, scoped per home.
* **FR-AUTH-01** (Priority: Critical) — Secure user authentication via OAuth or Apple ID sign-in.
* **FR-USER-02** (Priority: Critical) — Owners can add, edit, remove users and assign roles.
* **FR-HOME-01** (Priority: High) — Add/edit home properties with address, photos (display-optimized at upload and cached locally for hero display), and key info.
* **FR-HOME-02** (Priority: High) — Service provider directory (propane, electric, internet, lawn care, etc.) with contacts and notes.
* **FR-HOME-03** (Priority: High) — Editable, categorized documents for important details (UI section label: **Files**).
* **FR-NAV-01** (Priority: High) — Home detail MUST expose four sections labeled **Procedures**, **Contacts**, **Files**, and **People** with device-appropriate navigation (iPhone: hero + horizontal tabs; iPad: compact left-column hero + vertical icon tabs, with a **three-panel** layout — sidebar, section list, and section detail — for every section).
* **FR-PROC-01** (Priority: High) — Add/edit procedure lists (e.g., winterizing, arrival prep) with persistent status (Not Started / In Progress / Complete / N/A).
* **FR-PROC-02** (Priority: High) — Procedures contain ordered steps, each with its own status. Owner and Manager users can **create, rename, reorder, and delete** steps on procedures they can modify (per visibility). Guests have read-only access to step content and status.
* **FR-PROC-03** (Priority: High) — Attach optional notes and photos to individual procedure steps (document attachments remain on the Files tab per FR-HOME-03).
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
  * **iPhone**: hero cards at standard height (~152pt). **iPad**: tall hero cards (~528pt) with vertically centered photos, home name, and address (or city/state when the full address is long) so wide layouts do not over-crop the image.
* **Step 3:** Tap into a home for detail view.
  * Four sections, always labeled **Procedures**, **Contacts**, **Files**, and **People** (Files is the user-facing name for the document library).
  * **iPhone**: full-bleed home hero at top; horizontal segmented control for the four sections below.
  * **iPad**: no large hero above main content. Leading column shows a **compact home hero** (photo, name, address) that sets which home is in focus, then **vertical icon tabs** for Procedures, Contacts, Files, and People. The trailing area uses a **three-panel** pattern for **every** section: nested list (middle) and detail (right) inside the trailing column — e.g. procedure list | procedure detail, contact list | contact detail, file list | preview, member list | member detail. No duplicate home hero and no horizontal tab bar in the trailing area.
  * Return to **My Homes** from iPad home detail to switch homes (sidebar is not a persistent home picker while viewing a home).
  * Procedures list shows statuses; tap to drill into steps, update status, add comments or files.
  * On procedure detail: **tap** a step to toggle complete; **long-press** a step (Owner/Manager) to edit, delete, or reorder; tap the **pencil** to edit notes/photos; tap **Photo attached** to preview; **Add** on the Steps section to create a new step.
  * Service provider list is searchable and editable by permitted users.
  * Files library holds house manuals, WiFi info, care instructions (segmented by visibility).
* **Step 4:** User administration (Owners only): manage house users/roles from settings.
  * Clear prompts for what each user can access/change.
* **Step 5:** Share information (Owners/Managers): quick share/copy/forward useful info to guests.
  * UI guides when info is visible to Guest role or more restricted.
* **Step 6:** Updates are saved instantly; history of changes is visible.

**Advanced Features & Edge Cases**

* Owner can revoke access instantly if trust changes.
* Steps within a procedure can be skipped/marked N/A (for flexibility).
* Owner and Manager users can add, rename, reorder, or remove steps; changes sync and appear in the activity log.
* If a user is removed, clarify what happens to associated procedures/notes.
* Error handling: Unavailable features gracefully grayed out, clear messages if permissions are insufficient.

**UI/UX Highlights**

* Responsive adaptive UI for all iPhone/iPad orientations; iPhone and iPad use the same four section labels with layout adapted per device class.
* **Accessibility (first-class)**: UI MUST respect iOS system settings — especially **Dynamic Type / text size**, VoiceOver, Reduce Motion, and sufficient contrast. Layouts MUST reflow at larger text sizes without clipping essential controls or requiring horizontal scrolling for primary content.
* Procedure steps use checklist gestures: tap to complete, long-press for structure edits (Owner/Manager only).
* Home section tabs use friendly SF Symbol icons paired with labels; minimum 44×44 pt tap targets.
* **Launch screen**: black background; green house icon + white **HomesFlow** wordmark at ~1.5× prior size with tighter icon-to-text spacing (@1x/@2x/@3x PNG assets in `LaunchLogo` imageset).
* High-contrast text, large tap targets for accessibility.
* Role-based UI: Users only see actions/features they're permitted for.
* Large, visible status indicators for tasks.

---

## Narrative

Imagine Diane, a homeowner who spends most of her time in Florida, but owns a cherished oceanfront home in Maine. She worries each spring about getting the lawn tended, propane checked, and everything ready for summer visits. Previously, Diane painstakingly emailed procedures, WiFi passwords, and lawn schedules to family and caretakers—never sure if vital steps were missed or what had already been done. With HomesFlow, Diane sets up her second home's profile in minutes, delegating tasks and sharing info with her adult children, trusted handyman, and future guests. Each person sees only what they need, gets notified of tasks, and can update status, providing Jane peace of mind from anywhere. No more confusion—just clarity, control, and time saved for everyone.

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
* **NFR-A11Y-01** — UI MUST respect iOS accessibility settings (Dynamic Type, VoiceOver, Reduce Motion, contrast) and remain usable at all supported content size categories

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

### US-ADMIN-01 / FR-HOME-01 — Owner adds second home details

* **AC-HOME-01** — Given an authenticated Owner on a connected device, when they submit valid home details and photos, then the home is created and visible in their dashboard with correct data.
* **AC-HOME-02** — Given an Owner submits incomplete/invalid home details, when they attempt to save, then validation errors are shown and the home is not created.
* **AC-HOME-03** — Given an Owner edits home details while offline and another device edits the same home before sync, when both devices reconnect, then the version with the most recent timestamp is applied and a conflict log entry is created for audit.
* **AC-HOME-06** — Given an Owner or Manager user uploads a home photo, when the photo is saved to Storage, then the client uploads a display-optimized JPEG bounded to a maximum pixel dimension (not full camera resolution).
* **AC-HOME-07** — Given a user has previously loaded a home photo on this device, when they view the dashboard or home detail again, then the hero photo renders from local cache without re-downloading from Storage.
* **AC-HOME-08** — Given a home record has not yet synced to the server, when an Owner or Manager user attempts to upload a photo, then the upload is blocked and the user sees actionable guidance to sync first (e.g., pull to refresh while online).
* **AC-HOME-09** — Given a user views home detail on iPad (regular horizontal size class), when any section is selected, then the trailing area shows section content only — no full-bleed home hero and no horizontal section tab bar at the home level (nested section list | detail splits are allowed inside the trailing area).
* **AC-HOME-10** — Given a user opens a home on iPad, when home detail is shown, then the leading column displays a compact home hero (photo, name, address) and vertically stacked tappable section entries with icon and label for Procedures, Contacts, Files, and People; the trailing area shows the selected section using a three-panel layout (sidebar already visible + section list + section detail) for **all four** sections.
* **AC-HOME-11** — Given a user views home detail on any device, when section navigation is shown, then section labels read Procedures, Contacts, Files, and People (Files implements the document library).

### US-ADMIN-02 / FR-USER-01 — Owner invites users

* **AC-USER-01** — Given an Owner provides an email/phone and role and sends an invite, when the invite is accepted, then the invitee is added to the home with the assigned role and receives appropriate permissions immediately.
* **AC-USER-07** — Given an Owner creates an invite in MVP, when the invitee receives the shared invite link or token and signs in with the invited email, then they can accept the invite (paste token or open link) and join the home with the assigned role.
* **AC-USER-02** — Given an Owner re-sends or revokes an invite before acceptance, when they revoke, then the invite token becomes invalid and the invitee cannot join with that token.
* **AC-USER-03** — Given an Owner invites a user while offline and the invite is processed on another device first, when sync occurs, then the most recent action (invite or revoke) by timestamp determines invite state and the Owner receives a notification of the resolved outcome.

### US-ADMIN-03 / FR-USER-02 — Owner assigns permissions

* **AC-USER-04** — Given an Owner assigns a Manager role to a user, when the user signs in, then they can create and modify procedures and service providers for that home.
* **AC-USER-05** — Given an Owner assigns a Guest role to a user, when the guest signs in, then they see only guest-appropriate fields (e.g., WiFi, guest procedures) and cannot edit protected data.
* **AC-USER-06** — Given concurrent role changes occur on multiple devices, when devices sync, then the change with the most recent timestamp wins and an owner-visible audit entry records the prior role.

### US-EDIT-01 / FR-PROC-02 — Manager user updates maintenance tasks

* **AC-PROC-01** — Given a Manager user views a procedure, when they mark a step Complete, then the step status updates for all users with appropriate visibility, the procedure's aggregate status and progress in the procedures list update immediately, and an activity log entry is created.
* **AC-PROC-02** — Given a Manager user attempts to update a step beyond their permission (e.g., another home's owner-only procedure or step), when they submit the change, then the app blocks the update and shows a permission error.
* **AC-PROC-03** — Given a Manager user updates a step while offline and another user updates the same step before sync, when both devices reconnect, then the update with the most recent timestamp is persisted and the other user receives a notification about the overwritten change with reference to the activity log.
* **AC-PROC-04** — Given an Owner or Manager user long-presses a step on a procedure they can modify, when the context menu appears, then Edit, Delete, Move Up, and Move Down are available.
* **AC-PROC-05** — Given an Owner or Manager user taps Add on the Steps section, when they enter a title and save, then a new step is appended at the next sort order and appears for permitted users after sync.
* **AC-PROC-06** — Given an Owner or Manager user creates, renames, reorders, or deletes a step, when the change syncs, then it persists for permitted users and an activity log entry is created.
* **AC-PROC-07** — Given a Guest views a procedure, when they interact with steps, then step structure controls (long-press menu, Add step) are not available and step status remains read-only.
* **AC-PROC-08** — Given a user views a step with an attached photo, when they tap **Photo attached**, then the photo opens in a modal preview; step rows show notes below the title, a tappable photo indicator when present, a pencil **Edit** control (when permitted) to the left of the status ellipsis menu, and the ellipsis menu remains rightmost.

### US-EDIT-02 / FR-HOME-02 — Manager user manages service providers

* **AC-HOME-04** — Given a Manager user opens the service provider directory, when they search and select a provider, then they can edit contact details and changes are saved and propagated to permitted users.
* **AC-HOME-05** — Given a Manager user edits a provider entry that an Owner later deletes on another device before sync, when both devices sync, then the most recent timestamp between edit and delete determines final state; if delete is most recent the provider is removed and the editor receives a notification that their edit was removed due to delete.

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
* **AC-SYNC-04** — Given local changes or homes are pending sync to the server, when the user views the dashboard, then unsynced homes are visibly indicated and the user can pull to refresh to retry sync while online.

### Cross-cutting / NFR-A11Y-01 — Accessibility

* **AC-A11Y-01** — Given the user has increased text size via iOS Settings (Dynamic Type / Accessibility sizes), when they view dashboard, home detail, or procedure screens, then primary text and controls scale, layouts reflow without clipping essential actions, and primary reading content does not require horizontal scrolling.
* **AC-A11Y-02** — Given VoiceOver is enabled, when the user navigates home section tabs (horizontal on iPhone, vertical on iPad), then each tab exposes a combined accessibility label (section name + role), selected state is announced, and interactive controls have meaningful hints where non-obvious.
* **AC-A11Y-03** — Given Reduce Motion is enabled in iOS Settings, when the user navigates between sections or primary screens, then non-essential motion animations are omitted or reduced per system preference.

---

## ID Registry (authoritative)

| ID | Type | Summary |
|----|------|---------|
| US-ADMIN-01 | User Story | Owner adds home details |
| US-ADMIN-02 | User Story | Owner invites users |
| US-ADMIN-03 | User Story | Owner assigns permissions |
| US-EDIT-01 | User Story | Manager user updates tasks |
| US-EDIT-02 | User Story | Manager user manages providers |
| US-GUEST-01 | User Story | Guest sees limited info |
| US-GUEST-02 | User Story | Guest views guest procedures |
| FR-USER-01 | FR | Multi-role access per home |
| FR-AUTH-01 | FR | OAuth / Apple sign-in |
| FR-USER-02 | FR | Owner user management |
| FR-HOME-01 | FR | Home CRUD |
| FR-HOME-02 | FR | Service provider directory |
| FR-HOME-03 | FR | Document library (UI: Files) |
| FR-NAV-01 | FR | Home section navigation shell |
| FR-PROC-01 | FR | Procedure lists with status |
| FR-PROC-02 | FR | Procedure steps: status + CRUD/reorder |
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
| NFR-A11Y-01 | NFR | iOS accessibility compliance |
| AC-HOME-01 … AC-HOME-11 | AC | Home, provider & navigation scenarios |
| AC-USER-01 … AC-USER-07 | AC | User invite & role scenarios |
| AC-PROC-01 … AC-PROC-08 | AC | Procedure step scenarios |
| AC-GUEST-01 … AC-GUEST-05 | AC | Guest access scenarios |
| AC-SYNC-01 … AC-SYNC-04 | AC | Offline sync scenarios |
| AC-A11Y-01 … AC-A11Y-03 | AC | Accessibility scenarios |
