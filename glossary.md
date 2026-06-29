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
| **Service provider** | Vendor or caretaker (propane, electric, lawn care, etc.) with contact details. **UI tab label** may read “Contacts”; data model and specs use *service provider* (FR-HOME-02). |
| **Members** | Household users with access to a home (Admin assigns roles). Figma “People” tab → **Members** in code. |
| **Activity log** | Audit record of changes (status updates, role changes, conflicts). |

## UI reference (non-authoritative)

[Figma prototype](https://haze-rabbit-58180688.figma.site) is visual inspiration only. **PRD + spec are authoritative.** Native SwiftUI layouts optimized per device (`NavigationStack` on iPhone, `NavigationSplitView` on iPad) — do not port the web prototype literally.

## MVP exclusions

- **Step assignees** — out of scope; steps have status and notes only.
- **Key contacts** as a separate entity — out of scope; use service providers (FR-HOME-02).
