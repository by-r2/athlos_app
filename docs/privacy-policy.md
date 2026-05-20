# Privacy Policy

**Athlos** — Last updated: March 25, 2026

## Overview

Athlos is a local-first health and fitness app. Your personal training data (profile, workouts, execution history) is stored on your device by default. When you sign in, Athlos may sync your profile and body-metric timeline to your Supabase-backed account so it can be restored on another device. Workouts and execution history remain on-device unless a future release enables additional cloud sync. The app also uses Supabase for verified catalog consistency workflows (catalog governance/sync).

## Data Collection

Athlos does not use advertising trackers or behavior analytics SDKs.  
Personal user content such as profile details, workouts, and execution logs is not automatically uploaded as part of regular local usage. Signed-in profile fields and body-metric entries may be synced to your account when cloud sync is available.

## Data Storage

- **Local storage (default):** profile, workouts, exercises, equipment ownership, execution history, and app preferences.
- **Supabase account sync (signed-in users):** profile fields and body-metric timeline linked to your authenticated account, protected by row-level security so only your account can access them.
- **Supabase catalog sync:** used for official catalog reconciliation events/rules (e.g., verified catalog conflict governance).

## Third-Party Services

Athlos may use:

- **Supabase** for authenticated profile sync (when signed in) and catalog/governance sync related to verified catalog consistency

Athlos does not include:

- Advertising SDKs
- Social media SDKs

## Data Sharing

Athlos does not sell personal data. Data sharing is limited to technical synchronization needs related to catalog governance and only when those flows are used.

## Backup and Export

Athlos supports manual JSON export/import for user backups. Backup files are created and controlled by the user (save/share destination chosen in the system share flow).

## Data Deletion

You can remove local app data by uninstalling the app or clearing app storage in system settings.  
If catalog governance events were synced, related records may remain in Supabase logs according to backend retention policies.

## Children's Privacy

Athlos is not directed to children under 13. The app does not intentionally collect personal data from children.

## Changes to This Policy

If this privacy policy is updated, the date on this page is updated accordingly. Material changes should also be communicated in-app or in release notes.

## Contact

If you have questions about this privacy policy:

- GitHub: [github.com/rafaelc-rb/athlos_app](https://github.com/rafaelc-rb/athlos_app)
