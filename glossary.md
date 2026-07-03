# HomesFlow Glossary

Domain language for specs, plans, and code. When wording is ambiguous, this file wins (see constitution Hierarchy of Truth).

| Term | Definition |
|------|------------|
| **Home** | A second-home property managed in the app. Users may belong to multiple homes. |
| **Owner** | Primary homeowner. Full control: users, roles, home details, procedures, providers. |
| **Manager user** | Trusted collaborator who can update procedures, providers, and permitted home data. |
| **Guest** | Limited access: guest-appropriate procedures and info only (e.g. WiFi, house rules). Read-only. |
| **Procedure** | A checklist for operating or maintaining a home (e.g. winterizing, arrival prep). |
| **Step** | One item within a procedure. Status: Not Started / In Progress / Complete / N/A. |
| **Service provider** | Vendor or caretaker (propane, electric, lawn care, etc.) with contact details. **UI tab label**: **Contacts**; data model and specs use *service provider* (FR-HOME-02). |
| **Document** | Categorized file or metadata with visibility level (FR-HOME-03). **UI tab label**: **Files** — not “Documents”. |
| **Members** | Household users with access to a home (Owner assigns roles). **UI tab label**: **People**. |
| **Activity log** | Audit record of changes (status updates, role changes, conflicts). System-generated (FR-LOG-01); distinct from the Communications Log. |
| **Communications Log** | **UI / product name** for user-authored free-form entries (spec: **Log Book**, FR-LOG-02). Household- or procedure-scope notes in a unified chronological view. Owner/Manager only; no Guest access. Not the Activity log. |
| **Log Book** | Spec/PRD term for the Communications Log (FR-LOG-02). Same feature — use *Communications Log* in UI copy to avoid confusion with system logging. |
| **Grace window** | The 10 minutes after server receipt during which a Communications Log entry's author may still edit it; immutable afterwards (AC-LOG-04). |
| **Occurrence time** | Wall-clock time when the user performed an action on device (e.g. marked a step Complete, wrote a log entry). Governs **chronological ordering** in unified timelines — not server receipt order, outbox queue order, or entity `updated_at` used for conflict resolution. |
| **Offline-capable mutations** | Changes allowed without connectivity: step **status** updates, step **notes**, home field edits, Communications Log **append**. Structural actions require connectivity (AC-SYNC-07). |
| **Terminal status** | Complete or N/A on a step. Sync never silently regresses a terminal status (AC-SYNC-05). |
| **Data-type-aware conflict model** | Conflict resolution varies by data type: timestamp-wins for most edits, terminal-status protection for steps, connectivity-gating for structural actions, append-only for Log Book (AC-SYNC-01, 05…07). Resolution is automatic; the losing user is notified with re-apply guidance (AC-SYNC-06). |
| **Structural action** | Creating, renaming, reordering, or deleting steps/procedures/providers, or membership changes. Requires connectivity (AC-SYNC-07). |
| **Version vector** | Deferred post-MVP mechanism to replace device timestamps for conflict ordering (pairs with field-level merge, AC-SYNC-02). |

## UI reference (non-authoritative)

[Figma prototype](https://haze-rabbit-58180688.figma.site) is visual inspiration only. **PRD + spec are authoritative.** Native SwiftUI layouts optimized per device: iPhone `NavigationStack` with horizontal section tabs; iPad home detail uses compact left-column hero + vertical icon tabs and a content-only trailing column (**FR-NAV-01**, **AC-HOME-09…10**) — do not port the web prototype literally.

## Home section tabs (UI labels)

| Tab | Implements |
|-----|------------|
| Procedures | FR-PROC-* |
| Contacts | FR-HOME-02 (service providers) |
| Files | FR-HOME-03 (documents) |
| People | FR-USER-02 (memberships) |

On **iPad**, each tab uses a three-panel layout: sidebar (home context + tabs) + section list + section detail (**FR-NAV-01**, **AC-HOME-10**).

## MVP exclusions

- **Step assignees** — out of scope; steps have status and notes only.
- **Key contacts** as a separate entity — out of scope; use service providers (FR-HOME-02).
