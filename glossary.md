# HomeFlow Glossary

Domain language for specs, plans, and code. When wording is ambiguous, this file wins (see constitution Hierarchy of Truth).

| Term | Definition |
|------|------------|
| **Home** | A second-home property managed in the app. Users may belong to multiple homes. |
| **Admin** | Primary homeowner. Full control: users, roles, home details, procedures, providers. |
| **Edit user** | Trusted collaborator who can update procedures, providers, and permitted home data. |
| **Guest** | Limited access: guest-appropriate procedures and info only (e.g. WiFi, house rules). Read-only. |
| **Procedure** | A checklist for operating or maintaining a home (e.g. winterizing, arrival prep). |
| **Step** | One item within a procedure. Status: Not Started / In Progress / Complete / N/A. |
| **Service provider** | Vendor or caretaker (propane, electric, lawn care, etc.) with contact details. **UI tab label**: **Contacts**; data model and specs use *service provider* (FR-HOME-02). |
| **Document** | Categorized file or metadata with visibility level (FR-HOME-03). **UI tab label**: **Files** — not “Documents”. |
| **Members** | Household users with access to a home (Admin assigns roles). **UI tab label**: **People**. |
| **Activity log** | Audit record of changes (status updates, role changes, conflicts). |

## UI reference (non-authoritative)

[Figma prototype](https://haze-rabbit-58180688.figma.site) is visual inspiration only. **PRD + spec are authoritative.** Native SwiftUI layouts optimized per device: iPhone `NavigationStack` with horizontal section tabs; iPad home detail uses compact left-column hero + vertical icon tabs and a content-only trailing column (**FR-NAV-01**, **AC-HOME-09…10**) — do not port the web prototype literally.

## Home section tabs (UI labels)

| Tab | Implements |
|-----|------------|
| Procedures | FR-PROC-* |
| Contacts | FR-HOME-02 (service providers) |
| Files | FR-HOME-03 (documents) |
| People | FR-USER-02 (memberships) |

## MVP exclusions

- **Step assignees** — out of scope; steps have status and notes only.
- **Key contacts** as a separate entity — out of scope; use service providers (FR-HOME-02).
