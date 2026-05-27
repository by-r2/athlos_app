# Training Module

> Status: ✅ Feature-complete for 1.x — polish and maintenance.

## Current Features

### Exercise registration

Exercise records support type (strength/cardio), muscle group, target muscles and optional **region**, **variations** (`exercise_variations`), and cardio metrics where applicable.

**Verified catalog** vs **custom** exercises, naming, seeding, migrations, and why equipment is not FK-linked: **[catalog_exercises.md](../../catalog_exercises.md)** (product summary only here; implementation detail stays in that file).

#### Cardio Exercises

Pre-loaded cardio exercises include treadmill running, stationary bike, rowing machine, elliptical, jump rope, and jumping jacks. Cardio exercises use duration (seconds) and distance (meters) instead of reps and weight.

### Owned equipment (profile)

Users keep an **owned gear** list on Profile (replacing the old equipment Drift catalog). Scope and migration context: [catalog_exercises.md § Principles](../../catalog_exercises.md#principles).

### Workout Builder

- Build workouts as sets of exercises
- Configure per exercise based on type:
  - **Strength**: sets, reps, rest time
  - **Cardio**: sets, duration (goal), rest time
- **Supersets** — link two or more exercises to be executed in alternation without rest between them; rest is taken after completing one round of all linked exercises
- **Training cycle** — ordered rotation of active workouts (e.g. A → B → C → A); managed via setCycle
- **AI assist via Chiron** — create, update, and archive workouts through conversational commands; Chiron uses the verified exercise catalog and profile context (including owned gear) where relevant

### Execution Logging

- Log a workout execution
- **Strength exercises:**
  - Record weight used per set (defaults to last recorded weight from history)
  - Load mode per exercise: `weighted`, `bodyweight`, or `assisted`
  - Bodyweight load uses `bodyweightLoadFactor` and supports ballast/help in the same weight input (`+kg` / `-kg`)
  - Body weight is snapshotted per completed set for stable historical tonnage
  - Record reps per set (defaults dynamically to last completed set's reps within the session)
  - **Drop sets** — add additional reduced-weight segments within a single set
  - **Performance feedback** — color-coded reps indicate deviation from plan (neutral within +-1 rep of target, warning at +-2-3, error at +-4+)
  - **Load suggestions** — aggregated feedback after completing sets suggesting to increase, decrease, or maintain weight based on rep performance
- **Cardio exercises:**
  - **Timer mode** — dedicated stopwatch that counts up with:
    - Ready state with play button and goal display
    - Running state with elapsed time, progress bar, and goal reference
    - Goal reached badge and overtime tracking when exceeding planned duration
    - Pause/resume support
    - Finishing state with editable duration and optional distance input
  - **Manual entry** — option to skip the timer and input duration/distance directly
- **Rest timer** between sets with configurable duration, skip, and extend controls
- **Superset flow** — after completing a set in a superset group, automatically transitions to the next exercise in the group before triggering rest

### Execution History

- View past workout executions with date, name, and duration
- Detailed breakdown per exercise showing:
  - **Strength**: sets with weight x reps, color-coded performance indicators, aggregated load feedback
  - **Cardio**: sets with duration and distance
- Weekly volume cards and trend chart use kg tonnage (warmups excluded), not set count
- Performance feedback carried through to history (same color coding and suggestions as during execution)

### User Training Profile

Personal data tracking for progression and AI context:

- Weight, height, age
- Gender (male / female / not informed)
- General goal (hypertrophy, weight loss, endurance, etc.)
- Desired body aesthetic (athletic, hypertrophy, strength)
- Experience level (beginner, intermediate, advanced)
- Training frequency (days per week)
- Trains at gym (yes/no) — determines equipment approach
- Available training time (minutes per session)
- Injuries — free-text list of current injuries for exercise selection
- Bio — accumulated notes from Chiron conversations (preferences, context)

## Periodization Roadmap

> Status: ✅ Implemented — all phases (1-10) complete, plus supplementary improvements.

Evolution of the training module to support real-world periodization concepts, structured progression, and advanced training metrics — while keeping the experience simple for casual users.

### Design Principle

**Depth for those who seek it, simplicity for those who don't.** Casual users open the app, execute their workout, log weight and reps, done. Advanced users get RPE, PRs, weekly volume, periodization — all available but never in the way.

### Problems with the Current Model

#### 1. Rest days in the cycle are artificial

`CycleStepType.rest` treats rest as a programmed step in the cycle. In reality, rest is simply the day the user doesn't train. The cycle should be a queue of workouts (A → B → C), not a sequence of workouts and rest days.

If the user skips a day (sick, gym closed, travel), the cycle loses sync. Users who train 6x/week (e.g. PPL) have no rest in their cycle — it's Push → Pull → Legs → repeat.

#### 2. No concept of a training program (mesocycle)

Workouts exist in isolation. There's no grouping by purpose, duration, or training phase. A personal trainer builds a **program** — a package of workouts with a goal, a duration, and progression rules. The app doesn't have this.

#### 3. No structured progression

No rules like "+2.5kg per week on squat" or "+1 set per week". All progression is reactive (user remembers, or Chiron notices from history) rather than proactive.

#### 4. No awareness of training phases

No distinction between hypertrophy, strength, endurance, or deload blocks. These phases dictate volume, intensity, rep ranges, and rest — but the app treats every session identically.

### Planned Features

#### Phase 1: Simplify the Cycle

**Remove `CycleStepType.rest`** — the cycle becomes a simple ordered list of workout IDs. When the user executes, they pick up the next workout in the queue. Rest is implicit (the day the user doesn't train).

- Remove `CycleStepType` enum
- `cycle_steps` table becomes: `id`, `orderIndex`, `workoutId` (non-nullable)
- Migration: drop existing rest steps, compact ordering
- Update Chiron's `setCycle` tool accordingly

#### Phase 2: Rep Ranges and Set Types

Replace fixed `reps` with a range and introduce set types.

##### 2a. Rep Ranges

Currently `WorkoutExercise.reps` is a fixed `int` (e.g. 10). Real programs prescribe **ranges** (e.g. 8-12). The user picks a weight where they can do at least the minimum; when they hit the maximum with good form, they increase weight. This is fundamental to how progression works.

- Replace `reps` (int?) with `minReps` (int?) + `maxReps` (int?) on `WorkoutExercise`
- When min == max, it behaves as a fixed target (backward compatible)
- Load suggestion logic: hit maxReps on all sets → suggest weight increase next session

##### 2b. AMRAP Sets

"As Many Reps As Possible" — common in programs like 5/3/1. The target is a minimum rep count but the user goes to near-failure.

- Add `isAmrap` boolean to `WorkoutExercise` (default: false)
- AMRAP sets show a distinct badge in execution UI
- The recorded reps feed directly into 1RM estimation and progression decisions

#### Phase 3: Training Program (Mesocycle)

Introduce the **Program** entity — a named, time-bound container for the training cycle.

```
Program
├── name: "PPL Hipertrofia"
├── focus: hypertrophy | strength | endurance | custom
├── durationMode: sessions | rotations
├── durationValue: 12 (sessions) or 4 (rotations)
├── currentProgress: 7 (sessions completed)
├── defaultRestSeconds: 90 (nullable — override per phase/focus)
├── isActive: true
├── createdAt / archivedAt
└── cycle: [Push, Pull, Legs] (ordered workout IDs)
```

**Focus is not deload.** Deload is a recovery strategy within a block, not a training goal. See Phase 4 below.

**Rest adapts to focus:** hypertrophy 60-90s, strength 3-5min, endurance 30-45s. The program's `defaultRestSeconds` provides a phase-appropriate default. Per-exercise rest in the workout template still takes priority when set.

**Key behaviors:**
- Only one active program at a time
- When the program's duration is reached, prompt for review (Chiron or UI)
- Archiving a program preserves it and its execution history
- Starting a new program archives the previous one
- Programs are optional — users can still train without one (free cycle mode)

#### Phase 4: Deload Strategy

Deload is a recovery mechanism, **not a separate program type**. It's a temporary reduction applied to the current program.

```
DeloadConfig (part of Program, nullable)
├── frequency: 4 (every N rotations, nullable = manual only)
├── strategy: reduceVolume | reduceIntensity | reduceBoth
├── volumeMultiplier: 0.6 (keep 60% of sets)
├── intensityMultiplier: 0.5 (use 50% of working weight)
```

**How it works:**
- **Reduce volume** — same weight, fewer sets (e.g. 4 sets → 2 sets)
- **Reduce intensity** — same sets/reps, lighter weight (50-60% of working weight)
- **Reduce both** — fewer sets + lighter weight

**Key behaviors:**
- When deload is due, the app/Chiron prompts: "Hora do deload. Quer uma semana leve?"
- During deload, execution screen shows adjusted targets (dimmed original + active deload target)
- Deload sessions count toward program progress
- Deload is optional — user can skip or trigger manually

#### Phase 5: Progression Rules

Per-exercise progression rules within a program:

```
ProgressionRule
├── programId
├── exerciseId
├── type: incrementWeight | incrementReps | incrementSets
├── value: 2.5 (kg) or 1 (rep/set)
├── frequency: everySession | everyRotation
├── condition: hitsMaxReps | completesAllSets | rpeBelow (nullable)
```

**Key behaviors:**
- When starting a session, the app suggests the target weight/reps based on progression rules + last execution
- Progression triggers respect conditions (e.g. only increase weight if user hit maxReps on all working sets last session)
- Chiron can create progression rules when building a program
- Rules are optional — users who don't set them get the current behavior (manual)

#### Phase 6: Training Metrics

New data points and computed analytics to enrich the training experience.

##### 6a. RPE / RIR (optional per set)

- Add optional `rpe` field (integer 1-10) to `ExecutionSet`
- UI: small optional input after completing a set (skip = not recorded)
- Chiron uses RPE data for better load recommendations
- Progression rules can use RPE as condition (e.g. increase weight when RPE < 7)

##### 6b. Estimated 1RM and PRs

- Computed from execution history using Epley formula: `1RM = weight × (1 + reps/30)`
- Drop-set segments and unilateral limbs each contribute discrete load×reps probes; PR keeps the best estimated 1RM across probes
- For bodyweight exercises: use total load (body weight + added weight) in the formula
- Show per-exercise PR badge in history and exercise detail
- Chiron can reference 1RM for percentage-based programming

##### 6c. Weekly Volume per Muscle Group

- Aggregate working sets (excluding warmup) × muscle group from executions in the last 7 days
- Display on Training Home dashboard (optional card)
- Flag under-volume or over-volume based on experience level guidelines
- Typical targets: beginner 10-14 sets/muscle/week, intermediate 14-20, advanced 20+

##### 6d. Bodyweight Exercise Support

Currently, the `Exercise` entity has no way to indicate it's a bodyweight exercise. This is needed for accurate load and volume calculations.

- Add `isBodyweight` boolean to `Exercise` (default: false)
- Seed existing bodyweight exercises (pull-up, dip, push-up, etc.) with `isBodyweight: true`
- **Load calculation:** total load = profile weight + set weight (added weight / ballast)
  - `set.weight` = 0 or null → pure bodyweight (load = body weight)
  - `set.weight` = 10 → weighted bodyweight with 10kg ballast (load = body weight + 10)
- Used in volume totals, 1RM estimation, and progression tracking

#### Phase 7: Warmup Sets

- Add `isWarmup` boolean to `ExecutionSet` (default: false)
- Warmup sets are visually distinct during execution (dimmed, smaller)
- Excluded from volume calculations, load suggestions, progression tracking, and PR detection
- Optional: Chiron can suggest a warmup ramp based on the working weight

#### Phase 8: Execution Notes per Exercise

- Add optional `notes` field to `ExecutionSet` (or per exercise within execution)
- Allows context like "shoulder pain on last rep", "try wider grip next time"
- Chiron can read these notes for future recommendations

#### Phase 9: Body Weight Timeline

- New `body_metrics` table: `id`, `weight`, `bodyFatPercent` (nullable), `recordedAt`
- Profile `weight` becomes a convenience getter for the latest record
- Weekly prompt to record weight (dismissible, non-intrusive)
- Chart view in Profile showing weight trend over time
- Chiron uses the timeline for cutting/bulking analysis
- Bodyweight exercise load calculations reference the latest recorded weight

#### Phase 10: Progress Visualization

Charts and records computed from existing execution data — zero additional user input.

##### 10a. Per-Exercise Load Chart

- Line chart showing weight (or estimated 1RM) over time for a selected exercise
- Accessible from exercise detail or execution history
- Time range: last 30 days / 90 days / all time

##### 10b. PR History

- Dedicated screen listing personal records across all exercises
- Auto-detected from execution history (heaviest weight, most reps at a given weight, highest estimated 1RM)
- PR badge shown inline in execution history entries

##### 10c. Weekly Volume Trend

- Bar chart showing total working sets per muscle group per **calendar** week (Monday–Sunday)
- Accessible from Training Home dashboard (tapping the volume card from Phase 6c)
- Highlights under-volume and over-volume zones

**UI approach:** charts live in **dedicated detail screens** reached by tapping summary cards or exercise entries — never on the main flow. Training Home shows at most 1-2 small summary cards (e.g. "volume this week", "recent PR"); tapping drills into the chart. The principle is: **surface → summary card, drill-down → full chart**. No carousels, no chart walls.

> **Note:** progress data (PRs, volume trends, weekly frequency streaks, total finished sessions) are the natural input for the future **Kleos** gamification module — achievements, streaks, and challenges built on top of real training metrics. Cycle-order streaks are not tracked; session totals are derived from execution history.

### Future Considerations (low priority)

- **Tempo / cadence** — prescribed speed per exercise phase (e.g. 3-1-2-0). Discarded: too much interaction overhead for most users.
- **Chiron proactive** — Chiron initiating conversations based on events (program completion, PR, volume alerts). Mapped as future evolution.

### Implemented supplementary improvements

- **L/R tracking for unilateral exercises** — `leftReps`, `leftWeight`, `rightReps`, `rightWeight` on `ExecutionSet` (schema v23). UI in execution screen and history detail.
- **Chiron read tools** — `getWeeklyVolume`, `getEstimated1RM` for data-driven recommendations.
- **Chiron write tools** — `createProgram`, `archiveProgram`, `setDeloadActive` for full program management.
- **Chiron warmup tool** — `suggestWarmup` generates warmup ramp based on working weight.
- **`defaultRestSeconds` fallback** — program's default rest applied when exercise has no specific rest configured.
- **Program completion prompt** — UI dialog when all planned sessions are completed, with option to archive.
- **Automatic load suggestion** — snackbar suggesting weight increase when all working sets hit maxReps (no progression rule required).
- **PR badge in execution history** — trophy icon on sets that match the exercise's current personal record.
- **Set notes in Chiron context** — already included in prompt builder's execution history.

### Chiron Integration

With periodization, Chiron gains **proactive triggers**:

- "Teu bloco de hipertrofia acabou (12 sessões). Quer que eu monte um bloco de força agora?"
- "Já são 4 rotações sem deload. Recomendo uma semana leve."
- "Teu agachamento deveria estar em 75kg essa semana pela progressão. Bora?"
- "Teu volume de peito tá em 8 séries/semana — abaixo do ideal pra hipertrofia. Quer que eu ajuste?"
- "Teu peso caiu 2kg nas últimas 3 semanas. Se tá em cutting, tá funcionando. Se não, revisa a dieta."
- "Teu RPE tá abaixo de 7 nos últimos 3 treinos de supino. Hora de subir a carga."
- "Bati pull-up 80kg (corpo + 10kg lastro) × 8. Novo PR! 1RM estimado: 101kg."

Implemented Chiron tools:
- `createProgram` / `archiveProgram` — full program lifecycle management
- `setDeloadActive` — enter/exit deload mode
- `setProgressionRules` — bulk replace progression rules for a program
- `getWeeklyVolume` — read weekly working sets per muscle group
- `getEstimated1RM` — read estimated 1RM for any exercise
- `suggestWarmup` — generate warmup ramp from working weight
- `getTrainingState` — enhanced with program details, deload config, progression rules, body weight timeline, defaultRestSeconds

### UX Principles

- **All new features are optional** — casual users are unaffected
- **No new mandatory fields** — RPE, warmup toggle, AMRAP, notes are all skippable
- **Calculated metrics are passive** — shown in dedicated screens/cards, never blocking flows
- **Progressive disclosure** — program/periodization is there for who wants it; free cycle mode remains the default
- **Chiron as guide** — advanced features are discoverable through conversation ("Chiron, monta um programa pra mim")
- **No UI pollution** — advanced fields (RPE, notes) appear as collapsed/optional inputs, not as mandatory form fields

### Migration Strategy

Each phase is a separate schema version bump. Phases are independent enough to ship incrementally:

1. Phase 1 (cycle simplification) can ship alone — it's a fix, not a feature
2. Phase 2 (rep ranges, AMRAP) is independent — improves workout templates
3. Phase 3 (program) depends on Phase 1
4. Phase 4 (deload) depends on Phase 3
5. Phase 5 (progression) depends on Phase 3
6. Phases 6-9 (metrics, warmup, notes, body weight) are independent of each other
7. Phase 10 (charts) depends on Phases 6b, 6c; benefits from 9

Recommended order: **1 → 2 → 6a → 7 → 8 → 3 → 4 → 5 → 6b → 6c → 6d → 9 → 10**

Rationale: start with the fix (1), then the fundamental model improvement (2: rep ranges), then low-effort high-value additions (RPE, warmup, notes), then the bigger structural changes (program, deload, progression), then computed metrics, then body weight timeline, and finally visualization (which needs the computed data to exist first). Kleos gamification comes later as a separate module built on top of these metrics.
