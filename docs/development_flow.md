# Development Flow — Athlos

How to implement features following Clean Architecture, from the innermost layer outward.

## Feature Implementation Order

### 1. Domain (innermost — pure Dart, no dependencies)

Define **what** the app does.

1. **Enums** — finite types needed by the entity (e.g. `MuscleGroup`, `TrainingGoal`)
   - Location: `features/<module>/domain/enums/`
2. **Entity** — pure data class representing the business concept
   - Location: `features/<module>/domain/entities/`
   - No framework imports — only Dart and other domain types
3. **Repository interface** — contract defining available operations
   - Location: `features/<module>/domain/repositories/`
   - Uses only domain entities and enums as types
   - All methods return `Future<Result<T>>` — never throw
4. **Use Case** (when there is business logic) — single-responsibility operation
   - Location: `features/<module>/domain/usecases/`
   - Single `call()` method, making the class callable
   - Receives repository interfaces via constructor
   - Returns `Result<T>` — orchestrates, validates, and transforms
   - Pure Dart only — no framework imports
   - Use a dedicated params class when more than 2 parameters
   - Skip for simple CRUD with no logic (the controller calls the repository directly)

### 2. Data (implementation — Drift, Riverpod)

Define **how** data is obtained and stored.

5. **Drift table** — database schema for the entity
   - Location: `features/<module>/data/datasources/tables/`
   - Table names in plural (`Equipments`, `Exercises`)
   - Use `textEnum<T>()` for enum columns
   - Create junction tables for many-to-many relations
6. **Register table** in `AppDatabase` — add to `@DriftDatabase(tables: [...])`
   - Location: `core/database/app_database.dart`
   - Import the enum if the table uses `textEnum`
7. **DAO** — queries organized by feature
   - Location: `features/<module>/data/datasources/daos/`
   - Annotate with `@DriftAccessor(tables: [...])`
   - Register in `AppDatabase` `daos: [...]`
8. **Repository implementation** — concrete class that implements the domain interface
   - Location: `features/<module>/data/repositories/`
   - Receives a DAO via constructor
   - Maps Drift generated classes → domain entities (`_toDomain`)
   - Import `app_database.dart` for Companion classes
   - **Catches all data-layer exceptions** and wraps into `Result.failure(AppException)`
   - Never throws — always returns `Result<T>`
9. **Providers** — Riverpod providers for DAO, repository, and use cases
   - Location: `features/<module>/data/repositories/` (DAO + repository providers)
   - Location: `features/<module>/domain/usecases/` (use case providers)
   - DAO provider watches `appDatabaseProvider`
   - Repository provider watches the DAO provider
   - Use Case provider watches the repository provider(s)
   - Use `@riverpod` annotation

### 3. Code Generation

10. **Run build_runner** to generate `.g.dart` files:
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```
    Or use watch mode during development:
    ```bash
    dart run build_runner watch --delete-conflicting-outputs
    ```

### 4. Presentation (UI — Flutter, Riverpod)

Define **how** data is displayed and interacted with.

11. **Provider** — UI state management (when needed beyond simple reads)
    - Location: `features/<module>/presentation/providers/`
    - Use `AsyncNotifier` / `Notifier` with `@riverpod`
    - Calls Use Cases (or repositories for simple CRUD)
    - Unwraps `Result<T>` via `getOrThrow()`:
      ```dart
      // In build() — Riverpod converts exceptions to AsyncError
      final result = await repository.getAll();
      return result.getOrThrow();

      // In mutations — exception propagates to UI caller
      final result = await repository.delete(id);
      result.getOrThrow();
      ref.invalidateSelf();
      ```
12. **Screen** — main page for the feature
    - Location: `features/<module>/presentation/screens/`
    - Use `ConsumerWidget` or `ConsumerStatefulWidget`
    - Consume providers via `ref.watch`
    - Use `AsyncValue.when(data:, error:, loading:)` for async state
13. **Widgets** — feature-specific reusable components
    - Location: `features/<module>/presentation/widgets/`
    - Global reusable widgets go in `core/widgets/<type>/`
14. **Route** — register the screen in go_router
    - Add path constant to `core/router/route_paths.dart`
    - Add `GoRoute` to `core/router/app_router.dart`

### 5. Internationalization

15. **Strings** — add user-facing text to ARB file
    - Location: `l10n/app_pt.arb`
    - Use `AppLocalizations.of(context)!.keyName` in widgets
16. **Regenerate**:
    ```bash
    flutter gen-l10n
    ```

### 6. Validate

17. **Analyze** — check for errors and lint warnings:
    ```bash
    flutter analyze
    ```
18. **Test** (when applicable):
    ```bash
    flutter test
    ```

## Dependency Direction

```
Presentation → Domain ← Data
     ↓            ↑         ↓
 (screens)    (entities)  (SQLite)
 (controllers)(usecases)  (DAOs)
 (widgets)   (interfaces) (repos)
              (enums)
```

- **Domain** imports nothing from Data or Presentation
- **Data** imports Domain (to implement interfaces and return domain types)
- **Presentation** imports Domain (to use entities, enums, and Use Cases via providers)
- **Presentation never accesses Data directly** — always through Use Case or repository providers

## Error Handling Flow

```
DAO throws → Repository catches → returns Failure(AppException)
                                      ↓
                                  Use Case receives Result<T>
                                  (validates, transforms, composes)
                                      ↓
                                  returns Result<T>
                                      ↓
                                  Provider unwraps via getOrThrow()
                                      ↓
                                  build(): Riverpod catches → AsyncError
                                  mutations: exception propagates to UI
                                      ↓
                                  UI: AsyncValue.when() for reads
                                       try/catch for mutations
```

**Key rules:**
- Repositories **never throw** — they catch and wrap into `Result.failure()`
- Use Cases **never throw** — they return `Result<T>`
- Providers use `getOrThrow()` — in `build()`, Riverpod auto-converts to `AsyncError`; in mutations, exceptions propagate to the caller
- UI wraps mutation calls in `try/catch` with error snackbar feedback

## Checklist Template

When implementing a new feature, copy this checklist:

```
Domain:
- [ ] Domain enum(s)
- [ ] Domain entity
- [ ] Repository interface (methods return Result<T>)
- [ ] Use Case(s) (if business logic exists)

Data:
- [ ] Drift table(s)
- [ ] Register in AppDatabase
- [ ] DAO
- [ ] Register DAO in AppDatabase
- [ ] Repository implementation (catches exceptions → Result)
- [ ] Riverpod providers (DAO + Repository + Use Cases)

Code Generation:
- [ ] build_runner

Presentation:
- [ ] Provider (AsyncNotifier, if needed)
- [ ] Screen
- [ ] Widgets (feature-specific in presentation/, reusable in core/widgets/<type>/)
- [ ] Route

i18n & Validation:
- [ ] ARB strings
- [ ] flutter gen-l10n
- [ ] flutter analyze
```
