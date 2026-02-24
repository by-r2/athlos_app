# Project Context

## Name Origin

The name **Athlos** comes from *Dodekathlos* (Δωδέκαθλος) — the Twelve Labors of Heracles in Greek mythology. The word *athlos* (ἆθλος) means "labor", "trial", or "heroic feat". The app's visual identity and theme follow this Greek mythological line.

## Overview

Athlos is a modular health and fitness app built around independent modules. The first public release (1.0.0) ships with **Training** only — a fully functional, local-first workout tracker at zero cost. **Diet** is added incrementally in subsequent 1.x releases. Other modules are planned for future major versions.

The app is designed as a **hub-based** system: a central screen (the Hub) provides access to each module. Each module is a self-contained experience with its own home dashboard and navigation. New modules can be added without restructuring the app.

## Modules

| Module       | Status        | Target Version | Description                                         |
| ------------ | ------------- | -------------- | --------------------------------------------------- |
| Training     | 🔨 Building   | 1.0.0          | Workout registration, planning, and tracking        |
| Diet         | 📋 Planned    | 1.1–1.3        | Food registration, meals, and caloric control       |
| Assessments  | 💡 Idea       | —              | Physical assessments, body measurements, progress photos |
| Progress     | 💡 Idea       | —              | Consolidated dashboard across all modules           |

See each module's documentation for details:

- [Training Module](./modules/training.md)
- [Diet Module](./modules/diet.md)

## Navigation

### Hub ("Olympus")

The Hub is the app's main screen — a central point from which the user accesses each module. Each module is represented as a card with a quick summary (e.g. last workout, today's macros). Profile/Settings is accessible from the Hub's app bar.

### Module Navigation

Each module has its own bottom navigation bar with sections relevant to that module. Entering a module takes the user into a focused experience; they can return to the Hub at any time.

```
Hub (Olympus)
├── Training → [Home] [Workouts] [Exercises] [History]
├── Diet     → [Home] [Meals]    [Foods]     [Log]
├── (future modules follow the same pattern)
└── Profile (via Hub app bar)
```

Each module's **Home** tab is a dashboard showing relevant summary data for that module.

## Monetization Strategy

Athlos follows a **freemium** model:

**Free (1.x — local):**
- Training module with all core features (1.0.0)
- Diet module with all core features (1.1–1.3)
- Exercise and food catalogs (pre-loaded)
- Workout builder, meal builder, execution logging
- Full local history
- Manual data export/import (backup)

**Premium (2.x+ — requires account):**
- Cloud sync and automatic backup
- Multi-device support
- Quíron AI assistant (personalized suggestions, Q&A chat)
- Advanced progression charts and trend analysis
- Kleos gamification (achievements, streaks, challenges)
- Formatted report exports (PDF)

The free tier must be fully functional and valuable on its own — good enough to attract and retain users. Premium features add convenience (sync, backup) and intelligence (AI, analytics) that justify a subscription.

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
0.1.0  — Training core (current baseline)
0.2.0  — Training polish (custom exercises/equipment, filters)
0.3.0  — Data backup (export/import JSON)
  ...  — Bug fixes, stabilization
1.0.0  — First public store release (Training only)
1.1.0  — Diet: Food registration
1.2.0  — Diet: Meal builder
1.3.0  — Diet: Caloric control
1.4.0  — Load progression charts
  ...  — Patches between minors
2.0.0  — Backend, auth, cloud sync (Supabase)
3.0.0  — AI (Quíron), gamification (Kleos), integrations
```

## Future Ideas

- **AI assistant (Chiron / Χείρων)** — inspired by Chiron, the wise centaur from Greek mythology who mentored heroes like Achilles and Heracles. The idea is to use Chiron as the AI persona, reinforcing the mythological theme. Features include personalized workout/diet suggestions and a Q&A chat. Could have its own card on the Hub.
  - **Conversational onboarding** — instead of the current form-based profile setup, Chiron could conduct a natural chat to understand the user's profile (goals, aesthetic, training style, experience level, equipment, etc.). The conversation format allows the user to ask *why* Chiron is asking each question and get contextual explanations, making the process more human and less like filling out a form. The structured setup would remain as a fallback/quick option. This approach also opens the door for Chiron to gather richer context that static forms can't capture (e.g. injury history, schedule preferences, past training experience).
- **Health app integrations** — Apple Health, Google Fit, etc. for importing activity data and body metrics.
- **Kleos (κλέος)** — gamification system named after the Greek concept of eternal glory and renown that heroes pursued. Achievements, streaks, challenges, and progression rewards to keep users motivated on their journey.
- **Assessments** — physical evaluations, body measurements, bioimpedance records, and progress photos to enrich AI context and track body changes over time.
  - **Body metrics timeline** — weight (and other metrics like body fat %, measurements) should not be a single static value in the profile. Instead, each entry is a timestamped record, building a historical timeline. The profile displays the latest value, but the user can view trends, charts, and deltas over time. This is essential for tracking real progress and gives Chiron richer context for recommendations. The current `weight` field in the profile would become just a convenience shortcut to the latest recorded value.
- **Consultations** — log visits to nutritionists, personal trainers, and doctors, keeping all health-related records in one place.
