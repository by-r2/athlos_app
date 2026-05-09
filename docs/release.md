# Release

Everything needed to build, sign, and publish the app.

## App Identity

| Platform | Identifier | Display Name |
| --- | --- | --- |
| Android | `com.athlos.app` (`applicationId` in `build.gradle.kts`) | `Athlos` (`AndroidManifest.xml`) |
| iOS | `com.athlos.app` (`PRODUCT_BUNDLE_IDENTIFIER` in Xcode) | `Athlos` (`Info.plist`) |

**The application ID is permanent** — it cannot be changed after the first store upload. The stores use it to identify the app across all updates.

## Versioning

Format: `MAJOR.MINOR.PATCH+build` (Semantic Versioning).

| Part | When to increment | Resets? |
| --- | --- | --- |
| **MAJOR** | Strategic milestone (first public release, backend migration, AI era) | MINOR and PATCH reset to 0 |
| **MINOR** | New user-facing feature or module | PATCH resets to 0 |
| **PATCH** | Bug fixes, performance, UI polish | — |
| **build** (`+N`) | Every build uploaded to a store | **Never resets** — always incrementing |

Version is set in `pubspec.yaml`:

```yaml
version: 1.6.0+9
#        ^^^^^ ^
#        │     └── build number (store identifier, always increasing)
#        └── semantic version (user-facing)
```

Both `versionName` (Android) and `CFBundleShortVersionString` (iOS) are derived from this automatically by Flutter.

See [Versioning Strategy](./context.md#versioning-strategy) for the full release roadmap.

## Git Tagging (Release Standard)

Release tags must follow this standard:

- **Name format:** `vMAJOR.MINOR.PATCH` (example: `v1.6.0`)
- **Tag type:** **annotated tag** (always use `git tag -a`, never lightweight tags for releases)
- **Tag message format:** `vX.Y.Z — <main release theme>`

Recommended flow:

```bash
# 1) Commit the release bump
git commit -m "chore(release): bump version to 1.6.0+9"

# 2) Create annotated tag
git tag -a v1.6.0 -m "v1.6.0 — Training periodization and program model evolution"

# 3) Publish commit and tag
git push origin main
git push origin v1.6.0
```

Quick checks:

```bash
# Local annotated tag details (must show Tagger)
git show -s v1.6.0

# Remote tag and peeled commit
git ls-remote --tags origin "v1.6.0*"
```

## Android Signing

### Keystore

Release builds are signed with a dedicated keystore. The keystore file and credentials are **never committed to git** (protected by `android/.gitignore`).

| File | Location | Git |
| --- | --- | --- |
| Keystore | `android/app/athlos-release.jks` | Ignored (`**/*.jks`) |
| Credentials | `android/key.properties` | Ignored (`key.properties`) |

`key.properties` format:

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=athlos
storeFile=app/athlos-release.jks
```

`build.gradle.kts` reads `key.properties` at build time. If the file is missing (e.g. CI without secrets, or a new dev machine), it falls back to debug signing so development builds still work.

### Keystore Safety

> **The keystore and its password must never be lost.** If you lose the keystore, you cannot update the app on the Play Store — you would have to publish a new app with a new application ID. Back up the `.jks` file and the password in a secure location (password manager, encrypted drive, etc.).

### Generating a New Keystore (if needed)

```bash
keytool -genkey -v \
  -keystore android/app/athlos-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias athlos \
  -storepass <password> -keypass <password> \
  -dname "CN=Athlos, OU=Mobile, O=Athlos, L=Brazil, ST=BR, C=BR"
```

Then create `android/key.properties` with the matching credentials.

## Database Migrations (Drift)

### Schema Versioning

The database schema version is an integer in `app_database.dart` (the snippet here is illustrative — **prefer reading the getter in source**):

```dart
@override
int get schemaVersion => 35;

// increment whenever you ship a migration; keep this doc’s version list aligned
```

- **Version 1** baseline.
- **Version 2** cardio support (`type`, `duration`, `distance`, nullable reps, `rest_seconds` → `rest`).
- **Version 3** target muscle role + movement pattern + catalog seeds V3.
- **Versions 4–9** profile/training model evolution.
- **Version 10** canonical mapping fields (`catalog_remote_id`) on catalog tables.
- **Version 11** catalog seed expansion (including seated leg curl entries).
- **Version 12** local governance tables (`catalog_governance_events`, `catalog_governance_applied_rules`).
- **Version 13** local duplicate feedback table.
- **Versions 14–21** training periodization foundation (cycle simplification, rep ranges/AMRAP, RPE, warmup sets, programs, deload, progression rules, bodyweight flag).
- **Versions 22–24** profile/body metrics evolution (timeline table + weight migration from `user_profiles`).
- **Versions 25–27** mandatory program model, execution snapshot support, catalog seed expansion, and unilateral execution flag.
- **Version 28** isometric exercise flag, reps→duration migration for isometric history, and isometric catalog expansion (seedV7).
- **Version 29** training streak counters on `user_profiles`.
- **Version 30** removal of local equipment catalog tables (`equipments`, links); `owned_equipment_names` on profile; exercise canonical renames + merges (see [catalog_exercises.md](./catalog_exercises.md)).
- **Version 31** `seedExercisesV8` — additive squat variants and variation edges (details in `exercise_seeder.dart`).
- **Version 32** `seedExercisesV9` — additive catalog rows + variation edges (details in `exercise_seeder.dart`).
- **Version 33** `seedExercisesV33` — additive cardio/abs rows (`stairClimbing`, `verticalClimber`, `jacobsLadder`, `russianTwist`) + variation edges; pair with matching `supabase/migrations/*.sql` and `catalog_version` when Postgres sync is used (details in `exercise_seeder.dart`, [catalog_exercises.md](./catalog_exercises.md)).
- **Version 34** bodyweight volume model v2: `exercises.default_load_mode`, `exercises.bodyweight_load_factor`, `workout_exercises.load_mode_override`, migration from legacy `is_bodyweight`, seed factors via `seedExercisesV34`.
- **Version 35** execution snapshot and cleanup: `execution_sets.body_weight_snapshot`, `execution_sets.load_mode_override`, removal of `execution_sets.notes` and `workout_executions.notes` (recreate-and-copy migrations).

### How Migrations Work

`onCreate` runs when a user installs the app for the first time — it creates all tables and seeds catalog data.

`onUpgrade` runs when an existing user updates to a new version with a higher schema version. It uses guarded `if (from < N)` blocks so each migration runs exactly once per user, in ascending order.

### Migration Rules

1. **Never modify an existing migration step** — it may have already run on user devices
2. **Always increment `schemaVersion`** when adding a new step
3. **Test migrations** — install the old version, add data, then update to the new version and verify data is preserved
4. **Use `transaction()` for complex migrations** — Drift wraps each step in a transaction by default, but be explicit for multi-statement operations

### When to Add a Migration

| Change | Action |
| --- | --- |
| New table | `await m.createTable(newTable)` |
| New column (nullable or with default) | `await m.addColumn(table, table.newColumn)` |
| Remove column | `await m.alterTable(TableMigration(table))` |
| Rename column | `await m.alterTable(TableMigration(table, columnTransformer: {...}))` |
| New seed data for existing table | Insert rows inside the migration step |

### Evolving the exercise catalog

Verified exercises: `onCreate` runs `seedExercises` (**full** inline catalog). Upgrades rely on guarded `seedExercisesV*` deltas and a higher **`schemaVersion`**.

All maintainer workflows (new row, rename, merge, ARB/resolver, backup aliases, equipment model) live in **[catalog_exercises.md](./catalog_exercises.md)** — duplicating steps here goes stale.

Conflict / governance matrix for imports remains in **[catalog_governance.md](./catalog_governance.md)**.

## App Icons

Generated by `flutter_launcher_icons` from `flutter_launcher_icons.yaml`.

Source image: `assets/athlos-icon-1024.png` (converted from `assets/athlos-icon-flat.svg`).

To regenerate after changing the source icon:

```bash
dart run flutter_launcher_icons
```

## Splash Screen

Generated by `flutter_native_splash` from `flutter_native_splash.yaml`.

Source images: `assets/splash_logo.png` and `assets/splash_logo_dark.png` (symbol only, transparent background, converted from `assets/athlos-symbol.svg`).

To regenerate after changing the source:

```bash
dart run flutter_native_splash:create
```

## Building for Release

### Android (APK / App Bundle)

```bash
# App Bundle (recommended for Play Store)
flutter build appbundle

# APK (for direct distribution)
flutter build apk
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS

```bash
flutter build ipa
```

Requires Xcode, an Apple Developer account, and provisioning profiles.

## Pre-Release Checklist

```
Identity:
- [x] Application ID set (com.athlos.app)
- [x] Display name set (Athlos)
- [x] App icons generated (Android + iOS)
- [x] Splash screen generated

Signing:
- [x] Release keystore generated
- [x] key.properties configured
- [x] build.gradle.kts reads signing config
- [x] Keystore backed up securely

Database:
- [x] `schemaVersion` in `app_database.dart` bumped whenever migrations or catalog deltas ship; changelog in this doc’s migration section above
- [x] Incremental migration strategy in place
- [x] Destructive dev fallback guarded with kDebugMode (runs only in debug, never in release)

Quality:
- [x] flutter analyze (no issues)
- [x] flutter test (core/repository/usecase/provider coverage)

Store:
- [ ] Privacy policy URL
- [ ] Store listing (title, description, screenshots, feature graphic)
- [ ] Content rating questionnaire
- [ ] Target audience and content declarations
```
