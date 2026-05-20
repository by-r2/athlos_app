# Project Context

## Name Origin

The name **Athlos** comes from *Dodekathlos* (Δωδέκαθλος) — the Twelve Labors of Heracles in Greek mythology. The word *athlos* (ἆθλος) means "labor", "trial", or "heroic feat". The app's visual identity and theme follow this Greek mythological line.

## Overview

Athlos is a modular health and fitness app built around independent modules. Development follows a **depth-first** strategy: each module is fully polished (bug-free, feature-complete within zero-cost constraints) before the next one begins. The first public release (1.0.0) ships with **Training** as the most complete free workout tracker possible — including advanced features like cardio support, execution feedback, supersets, training cycles, and AI assistance via Chiron (Gemini free tier). **Diet** follows with the same depth-first approach in subsequent 1.x releases. After the free modules are solid, a decision is made on whether to add more free modules or move to premium features.

The app is designed as a **hub-based** system: a central screen (the Hub) provides access to each module. Each module is a self-contained experience with its own home dashboard and navigation. New modules can be added without restructuring the app.

## Current Implementation Snapshot

- Local-first remains the default runtime mode (Drift on-device), with optional Supabase catalog sync.
- **Cloud sync** (Supabase) backs up profile, body metrics, and training data for signed-in users. **Profile > Dados** shows sync status and retry.
- **Conflict Center** (Profile > Dados > Central de Conflitos) handles runtime duplicate detection for local data:
  - **Local x Verified** pair: user can mark "not duplicate" (suppressed) or "confirmed duplicate" (verified item wins; local is remapped and deleted).
  - **Local x Local** pair: user can mark "not duplicate", "keep A", "keep B", or **attribute-by-attribute merge** (user picks each field, associations are unified, loser is remapped and deleted).
- Global catalog governance (verified x verified conflicts, rule application across devices) is **out of scope for this project** and will be handled in a separate maintenance project.
- The local database `schemaVersion` is defined in `lib/core/database/app_database.dart` (history: [release.md](./release.md#database-migrations-drift)). Exercise catalog maintenance: [catalog_exercises.md](./catalog_exercises.md).
- Automated tests cover duplicate resolution (Conflict Center), training/profile repositories, sync engines, provider wiring, and error/result contracts.

## Modules

| Module       | Status        | Target Version | Description                                         |
| ------------ | ------------- | -------------- | --------------------------------------------------- |
| Training     | 🔨 Building   | 1.0.0          | Workout registration, planning, tracking, cardio, execution feedback, cycles, AI (Chiron) |
| Diet         | 📋 Planned    | 1.x            | Food registration, meals, and caloric control       |
| Assessments  | 💡 Idea       | —              | Physical assessments, body measurements, progress photos |
| Progress     | 💡 Idea       | —              | Consolidated dashboard across all modules           |

See each module's documentation for details:

- [Modules Index](./modules/README.md)
- [Training Module](./modules/training/README.md)
- [Body Metrics Dashboard Spec](./modules/training/features/body_metrics_dashboard.md)
- [Diet Module](./modules/diet/README.md)

## Navigation

### Hub ("Olympus")

The Hub is the app's main screen — a central point from which the user accesses each module. Each module is represented as a card with a quick summary (e.g. last workout, today's macros). Profile/Settings is accessible from the Hub's app bar.

### Module Navigation

Each module has its own bottom navigation bar with sections relevant to that module. Entering a module takes the user into a focused experience; they can return to the Hub at any time.

```
Hub (Olympus)
├── Training → [Home] [Workouts] [History] [Exercises]
├── Diet     → [Home] [Meals]    [Foods]     [Log]
├── (future modules follow the same pattern)
└── Profile (via Hub app bar)
```

Each module's **Home** tab is a dashboard showing relevant summary data for that module.

## Development Strategy

Athlos follows a **depth-first, one-module-at-a-time** approach:

1. **Training** — fully polished, bug-free, with every feature achievable at zero cost (including Chiron AI via Gemini free tier)
2. **Diet** — same treatment: complete and polished before moving on
3. **Decision point** — evaluate whether to add more free modules or start building premium features

The guiding principle is: **maximize the value of each module before starting the next**. No half-finished features — each module ships as the best free version it can be.

## Monetization Strategy

Athlos follows a **freemium** model:

**Free (1.x — local):**
- Training module with all features (exercises, workouts, execution logging, cardio, supersets, cycles, execution feedback, history)
- Chiron AI assistant via Gemini free tier (personalized suggestions, Q&A chat)
- Diet module with all features (food registration, meal builder, caloric control)
- Exercise and food catalogs (pre-loaded)
- Local duplicate detection and user-driven conflict resolution (Conflict Center)
- Full local history
- Manual data export/import (backup)

**Premium (future — requires account):**
- Cloud sync and automatic backup
- Multi-device support
- Advanced progression charts and trend analysis
- Kleos gamification (achievements, streaks, challenges)
- Formatted report exports (PDF)
- Extended AI capacity (beyond free tier limits)

The free tier must be fully functional and valuable on its own — good enough to attract and retain users. Premium features add convenience (sync, backup) and enhanced capabilities that justify a subscription.

## Versioning Strategy

Athlos follows [Semantic Versioning](https://semver.org/) adapted for app releases: `MAJOR.MINOR.PATCH+build`.

| Part | When to increment | Example |
| --- | --- | --- |
| **MAJOR** | Strategic milestone — first public release, backend migration, AI era | `1.0.0`, `2.0.0`, `3.0.0` |
| **MINOR** | New user-facing feature or module added | `1.0.0` → `1.1.0` |
| **PATCH** | Bug fixes, performance improvements, UI polish | `1.1.0` → `1.1.1` |
| **build** (`+N`) | Always incrementing integer for store identification — never resets | `+1`, `+2`, `+3`... |

PATCH resets to 0 when MINOR increments. MINOR resets to 0 when MAJOR increments. Build number never resets.

**Pre-1.0** (`0.x.x`) is development/beta phase — the app is not yet publicly released.

### Release Roadmap

```
0.x.0  — Development / beta (Training + Chiron)
1.0.0  — First public store release (Training fully polished + Chiron AI)
1.x.0  — Diet module (food registration → meal builder → caloric control)
  ...  — Patches between minors
 ?.0.0 — Decision: more free modules OR premium features
 x.0.0 — Backend, auth, cloud sync (Supabase)
 x.0.0 — Gamification (Kleos), integrations, extended AI
```

> **Note:** Major version numbers beyond 1.x are intentionally unassigned. The decision to go premium or add more free modules is made after Diet is complete, based on the state of the app and user feedback.

## Chiron (AI Assistant)

Chiron (Χείρων) is the app's AI assistant — the mythological centaur who mentored Achilles, Heracles, and Jason. **Fully implemented** using the Gemini API free tier (zero cost), Chiron is part of the 1.0.0 release — not a premium feature.

Chiron speaks as the mythological character himself: wise, direct, encouraging, with occasional mythological references. He addresses users based on gender (guerreiro/guerreira, meu pupilo/minha pupila) and acts as an evidence-based personal trainer.

### Current Capabilities

- **Q&A chat** for exercise and training questions via bottom sheet
- **Context-aware responses** — user profile (including owned gear where available), active workouts, execution history, and exercise catalog are injected into the prompt
- **Function calling** — Chiron can take actions on behalf of the user:
  - Create, update, and archive workouts with exercises from the catalog
  - Manage the training cycle (setCycle, getTrainingState)
  - Update profile fields (gender, experience level, training frequency, gym/home, available time, injuries, bio)
  - Adjust profile-owned gear when supported by tools
- **Conversational onboarding** — collects missing profile data naturally during conversation (one field at a time)
- **Gear context for home users** — can reason about available equipment from profile-owned lists and bodyweight-friendly options
- **Progress analysis** — compares weights/reps across execution history, identifies plateaus and progression, suggests deloads or variations
- **Evidence-based training advice** — program change recommendations only when data supports it (plateau 3+ weeks, not just time passing)
- **Model fallback** — primary model (gemini-2.5-flash) with fallback to gemini-2.0-flash on quota exhaustion
- **Thinking model support** — thinkingBudget configuration for gemini-2.5-flash
- **Rate limiting** — client-side RPM guard, retry with exponential backoff and jitter
- **Markdown rendering** — responses rendered with formatting (bold, italic, lists)
- **Tool feedback chips** — real-time visual indicators of actions taken (e.g. "Treino criado", "Ciclo atualizado")
- **Error handling** — distinct error bubbles, thinking indicator during processing, empty response fallback

### Future Ideas

- **Multi-provider AI** — integrate multiple free-tier AI providers (e.g. Groq, Mistral, Cohere, OpenRouter) as fallbacks to multiply daily request capacity
- **Meal suggestions** based on caloric targets and food preferences (after Diet module)
- **Persistent chat history** — save conversations to database for cross-session continuity
- **Streaming responses** — SSE-based streaming for real-time text output

## Future Ideas

- **PWA (Progressive Web App)** — deploy the app as a web application so iOS users (and anyone without the Play Store) can use it via browser (add to home screen). Flutter Web builds are separate from mobile and don't affect Android/iOS builds.
  - **Adaptations needed:** configure Drift with `WasmDatabase` for web (SQLite via sql.js), adapt file-based backup to download/upload, accept that local notifications and background timer don't work on iOS Safari.
  - **Hosting:** free via Vercel (`.vercel.app`) or Netlify (`.netlify.app`).
  - **Gemini API key protection:** for public distribution, a proxy is required to keep the key server-side. Use a Supabase Edge Function (already in the project stack) as a lightweight proxy: `Browser → Edge Function (API key in env var) → Gemini API`. Add rate limiting per IP/session to prevent abuse. Zero additional cost within Supabase free tier (500K invocations/month).
- **Health app integrations** — Apple Health, Google Fit, etc. for importing activity data and body metrics.
- **Kleos (κλέος)** — gamification system named after the Greek concept of eternal glory and renown that heroes pursued. Achievements, streaks, challenges, and progression rewards to keep users motivated on their journey.
- **Assessments** — physical evaluations, body measurements, bioimpedance records, and progress photos to enrich AI context and track body changes over time.
  - **Body metrics timeline** — weight (and other metrics like body fat %, measurements) should not be a single static value in the profile. Instead, each entry is a timestamped record, building a historical timeline. The profile displays the latest value, but the user can view trends, charts, and deltas over time. This is essential for tracking real progress and gives Chiron richer context for recommendations. The current `weight` field in the profile would become just a convenience shortcut to the latest recorded value.
- **Consultations** — log visits to nutritionists, personal trainers, and doctors, keeping all health-related records in one place.
