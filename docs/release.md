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
version: 1.1.0+2
#        ^^^^^ ^
#        │     └── build number (store identifier, always increasing)
#        └── semantic version (user-facing)
```

Both `versionName` (Android) and `CFBundleShortVersionString` (iOS) are derived from this automatically by Flutter.

See [Versioning Strategy](./context.md#versioning-strategy) for the full release roadmap.

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

The database schema version is an integer in `app_database.dart`:

```dart
@override
int get schemaVersion => 3;  // increment when schema changes
```

- **Version 1** is the baseline for the first public release (1.0.0).
- **Version 2** added cardio support (exercise type, duration/distance, nullable reps, rest rename).
- **Version 3** added target muscle role, movement pattern, and catalog seeds V3.
- Development used versions 1–10 before release; the migration strategy detects these and recreates the database automatically.

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

### Evolving the Catalog (Exercises & Equipment)

Catalog items (exercises, equipment) are seeded on first install via `onCreate`. **Existing users only receive new catalog items through migrations.**

#### Workflow for adding catalog items after 1.0.0

1. **Add items to the main seeder** — update `equipment_seeder.dart` / `exercise_seeder.dart` with the new items so fresh installs get the full catalog.
2. **Create a versioned seed function** — e.g. `seedEquipmentsV2(db)` in the same seeder file, containing only the new items.
3. **Bump `schemaVersion`** and add a migration guard in `onUpgrade`:

```dart
// app_database.dart
@override
int get schemaVersion => 3;  // or next version when adding a new migration

onUpgrade: (m, from, to) async {
  // ... dev wipe block ...

  if (from < 2) {
    await seedEquipmentsV2(this);
    await seedExercisesV2(this);
  }
  // if (from < 3) { ... }
},
```

4. **Add ARB translations** for the new items.
5. **Publish** — new users get everything from `onCreate`; existing users get the delta from `onUpgrade`.

#### Key rules

- The main seeder files always contain the **full catalog** (all versions combined).
- Each `seedXxxVN()` function contains **only the delta** for that version.
- Never modify a published versioned seed — if an item needs correction, add a new version with an UPDATE or DELETE+INSERT.
- Schema changes (new tables, columns) and catalog additions can share the same version bump.

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
- [x] Schema version set to 3 (v1.1.0 — cardio, target muscle role, movement pattern, seeds V3)
- [x] Incremental migration strategy in place
- [x] Destructive dev fallback guarded with kDebugMode (runs only in debug, never in release)

Store:
- [ ] Privacy policy URL
- [ ] Store listing (title, description, screenshots, feature graphic)
- [ ] Content rating questionnaire
- [ ] Target audience and content declarations
```
