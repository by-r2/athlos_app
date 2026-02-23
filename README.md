# Athlos

A workout and diet tracking app inspired by Greek mythology. Built with Flutter.

## Documentation

| Document | Description |
| --- | --- |
| [Project Context](./docs/context.md) | Vision, modules, and future ideas |
| [Architecture](./docs/architecture.md) | Stack, app structure, and evolution plan |
| [Requirements](./docs/REQUIREMENTS.md) | User stories by phase (V1, V2, V3) |
| [Training Module](./docs/modules/training.md) | Training module features |
| [Diet Module](./docs/modules/diet.md) | Diet module features |
| [Development Flow](./docs/development_flow.md) | Step-by-step guide to implement features |

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.11)
- Dart SDK (bundled with Flutter)
- Android Studio / Xcode (for emulators)

### Setup

```bash
# Clone the repository
git clone <repo-url> && cd athlos_app

# Install dependencies
flutter pub get

# Generate code (Riverpod, Drift, i18n)
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### Useful Commands

```bash
# Watch mode — regenerates on file changes
dart run build_runner watch --delete-conflicting-outputs

# Regenerate i18n after editing .arb files
flutter gen-l10n

# Run static analysis
flutter analyze

# Run tests
flutter test
```

## Tech Stack

| Layer | Technology |
| --- | --- |
| Framework | Flutter |
| State + DI | Riverpod (code generation) |
| Database | SQLite via Drift |
| Navigation | go_router |
| Design | Material 3 (custom Greek theme) |
| i18n | ARB files (PT-BR) |

## Project Structure

```
lib/
├── core/
│   ├── database/       # Drift database setup
│   ├── router/         # go_router configuration
│   ├── theme/          # Material 3 theme (colors, typography)
│   ├── utils/          # Helpers and constants
│   └── widgets/        # Global reusable widgets
├── features/
│   ├── training/       # Training module
│   │   ├── domain/     # Entities + repository interfaces
│   │   ├── data/       # Data sources, models, repositories
│   │   └── presentation/   # Screens, widgets, controllers
│   ├── diet/           # Diet module (same structure)
│   └── profile/        # User profile (same structure)
├── l10n/               # ARB internationalization files
└── main.dart
```

## Commit Convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/).

### Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

| Type | Description |
| --- | --- |
| `feat` | A new feature |
| `fix` | A bug fix |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `style` | Formatting, missing semicolons, etc. (no code change) |
| `docs` | Documentation only changes |
| `test` | Adding or updating tests |
| `chore` | Build process, dependencies, CI, tooling |
| `perf` | Performance improvement |
| `ci` | CI/CD configuration |

### Scopes

Use the module or area affected: `training`, `diet`, `profile`, `core`, `db`, `router`, `theme`, `i18n`, `deps`.

### Examples

```
feat(training): add exercise entity and drift table
fix(db): handle null muscle region in exercise migration
refactor(core): extract reusable card widget
chore(deps): update riverpod to 3.x
docs: add getting started instructions to README
```

## License

[MIT](./LICENSE)
