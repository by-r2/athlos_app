# Exercise catalog maintenance

**Single source of truth** for contributors: how the **verified exercise catalog** is authored, named, versioned, and kept compatible with backups and migrations. Other docs link here rather than repeating checklists.

For conflict governance (import, verified vs local, future multi-device rules), see [catalog_governance.md](./catalog_governance.md). This doc is the maintainer guide for the **verified catalog**: Drift seed + schema bumps, ARB labels, backup aliases, and **Supabase `INSERT` + `catalog_version`** when devices pull rows via [catalog_sync_service.dart](../lib/core/services/catalog_sync_service.dart).

## Principles

1. **`exercises.name` is a stable canonical key** — English `camelCase`, ASCII (e.g. `benchPress`, `bulgarianSplitSquat`). It is stored in Drift, referenced by workouts, executions, variations, and backups. **Do not rename lightly**; renames require migration + import aliases (see [Renames and merges](#renames-and-merges-schema-v30)).

2. **User-facing titles are never the raw key** — verified rows are labeled via ARB (`l10n/*.arb`) and [exercise_canonical_display_map.dart](../lib/core/localization/exercise_canonical_display_map.dart) (used by [DomainLabelResolver](../lib/core/localization/domain_label_resolver.dart) for `DomainLabelKind.exercise`). Non-verified (custom) exercises display their stored name as-is.

3. **One catalog row = one training concept** — distinct grips, bars, or attachments that represent the **same** movement for programming purposes may be **folded** into a single row (see merges in [exercise_migration_maps.dart](../lib/core/database/exercise_migration_maps.dart)). Variants that differ materially stay separate and are linked via **variations** (`exercise_variations`).

4. **No equipment FK on exercises** — the legacy `equipments` / `exercise_equipments` catalog was removed (schema v30). Optional context for the user lives in **profile** (`owned_equipment_names`, free-text list). Do not reintroduce per-exercise equipment linkage in the seed unless the product model changes.

5. **Fresh installs vs upgrades** — `onCreate` runs `seedExercises` and loads the **full** inline catalog. **Existing users** only receive **deltas** through `seedExercisesV*` functions invoked from `onUpgrade`, each guarded by `if (from < N)` after bumping `schemaVersion` in [app_database.dart](../lib/core/database/app_database.dart).

## Source files

| Concern | Location |
| --- | --- |
| Main catalog + variations + `seedExercises` | [exercise_seeder.dart](../lib/features/training/data/datasources/exercise_seeder.dart) |
| Versioned deltas (`seedExercisesV8`, `V9`, …) | Same file; lists named `_v*_SeedItems`, `_v*_Variations` |
| Pre–v30 → current name rewrites (backups + migration) | [exercise_migration_maps.dart](../lib/core/database/exercise_migration_maps.dart) |
| Collapsing loser rows into keepers (FK remap + delete) | [exercise_canonical_merge.dart](../lib/core/database/exercise_canonical_merge.dart) |
| Localized display names | `lib/l10n/app_*.arb` + [exercise_canonical_display_map.dart](../lib/core/localization/exercise_canonical_display_map.dart) (`exerciseCanonicalToDisplayMap`; consumed by [domain_label_resolver.dart](../lib/core/localization/domain_label_resolver.dart)) |
| Fuzzy / duplicate-style matching (UI, conflict flow) | [exercise_name_match.dart](../lib/features/training/domain/exercise_name_match.dart) |
| Remote catalog / governance (optional) | `supabase/migrations/*.sql` |

## Naming conventions (canonical `name`)

- **Pattern:** lower camelCase, no spaces, **ASCII only** (e.g. `neutralGripPullUp`, not unicode hyphens in the key).
- **Prefer short, unambiguous tokens:** `backSquat`, `bicepsCurl`, `tricepsPushdown`.
- **Avoid encoding equipment in the key** when that equipment is optional or user-specific; use variations or description text in the future if needed.
- **Align with domain enums** — `muscle_group`, `movement_pattern`, `exercise_type`, and `target_muscle` must use existing enum values.

## Seed shape (`_SeedExercise`)

Each entry supplies: `name`, `MuscleGroup`, optional `ExerciseType` / `MovementPattern`, target-muscle rows (`_p` primary, `_s` secondary, optional `MuscleRegion`), and flags `isBodyweight` / `isIsometric`. Cardio rows often omit `movementPattern` and use `type: ExerciseType.cardio`.

Variations are declared as `_Variation(from, to)` and inserted as **undirected** pairs (both directions) in `seedExercises` / versioned seed helpers.

## Workflow: add a **new** verified exercise

1. Add a `_SeedExercise(...)` to the **main** `_seedItems` list in `exercise_seeder.dart` (grouped by muscle section comments), **or** add it only to `_vNextSeedItems` if it ships exclusively via a new schema bump.
2. Add variation edges if it substitutes another catalog exercise.
3. Add ARB strings (`exerciseCamelCaseKey` or existing naming pattern) — **Portuguese** in `app_pt.arb`; add EN keys if the project maintains `app_en.arb`.
4. Register the canonical key in [exercise_canonical_display_map.dart](../lib/core/localization/exercise_canonical_display_map.dart) (ARB-backed `l10n` getter wired through this map).
5. **Existing installs:** add `seedExercisesV*` containing **only** new rows (and optionally `insertOrIgnore` variation inserts), increment `schemaVersion`, and call the seed from `onUpgrade` under `if (from < N)`.
6. **Remote catalog:** if Postgres is the synced source of verified rows, add a migration under `supabase/migrations/` that `INSERT`s the same canonical `name`, target muscles, and metadata as the Dart seed and bumps **`catalog_version`** (same pattern as sibling SQL files); deploy (`supabase db push` or CI). Omit this only when you intentionally ship verified rows **bundle-only**.
7. Run `dart run build_runner build` if generated code is affected, then `flutter analyze` / relevant tests (backup import tests cover `resolveImportedExerciseCatalogName`).

## Workflow: rename or merge **published** keys

Renaming or deleting a key that may exist in user DBs or JSON backups requires all of:

1. **Drift migration** — `UPDATE exercises SET name = ?` and/or run `applyExerciseCanonicalMerges`-style logic for loser → keeper (see v30 in `app_database.dart`).
2. **[exercise_migration_maps.dart](../lib/core/database/exercise_migration_maps.dart)** — extend `kExerciseRenamePreV30ToCanonical` and/or `kExerciseMergeLosersIntoKeeper`, and update `resolveImportedExerciseCatalogName` if new steps are needed (order: oldest transform first).
3. **Display map** — for **legacy** keys still present in old backups, keep an entry in [exercise_canonical_display_map.dart](../lib/core/localization/exercise_canonical_display_map.dart) mapping the old key to the **same** ARB string as the keeper (patterns like `ezBarCurl`, `ropeTricepsPushdown`, etc.).
4. **Main seeder** — use the **final** canonical name in `_seedItems`; remove merged losers from the seed so new installs match upgraded devices.
5. **Supabase** — if remote catalog rows exist, add a migration there to stay aligned (see repo `supabase/migrations/`).

Never edit a **published** `seedExercisesV*` delta in a way that breaks idempotency for users who already ran it; add a new schema step instead.

## Import / backup compatibility

- `kLastBackupSchemaWithLegacyExerciseNaming` (29) marks backups that may still store pre–v30 `exercises.name` labels.
- Import paths call `resolveImportedExerciseCatalogName` so JSON from old app versions resolves to current keys before linking rows.

## Relation to similarity and Conflict Center

[ExerciseNameMatch](../lib/features/training/domain/exercise_name_match.dart) normalizes strings (trim, lower case, diacritics stripped) for collision checks. Similarity compares the canonical key, localized label, and a **camelCase-to-words** expansion so Portuguese phrases can match English keys (`bulgarianSplitSquat` ↔ “split …”).

## Schema cross-reference (exercises)

The **changelog of every schema version** lives in one place: [release.md — Database migrations](./release.md#database-migrations-drift). Do not copy that timeline here.

When you touch exercises, typical anchors in code are:

- **Canonical renames / merges (v30 lineage):** [exercise_migration_maps.dart](../lib/core/database/exercise_migration_maps.dart), [exercise_canonical_merge.dart](../lib/core/database/exercise_canonical_merge.dart), and the `from < 30` branch in `app_database.dart`.
- **Additive catalog after shipping:** `_v*_SeedItems` / `seedExercisesV*` in [exercise_seeder.dart](../lib/features/training/data/datasources/exercise_seeder.dart), wired from `onUpgrade` alongside `schemaVersion` in `app_database.dart`.

Authoritative **`schemaVersion` integer:** `lib/core/database/app_database.dart`.

## Related documentation

| Document | Role |
| --- | --- |
| [release.md](./release.md#database-migrations-drift) | Canonical **schema changelog** (all tables, not only exercises). |
| [catalog_governance.md](./catalog_governance.md) | Import conflicts, verified vs local, governance workflow. |
| [modules/training/README.md](./modules/training/README.md) | User-visible Training behavior (no duplicated maintainer steps). |
| [architecture.md](./architecture.md) | Stack and structure; points here for exercise semantics. |
