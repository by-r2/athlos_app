# Training Module

> Status: 🔨 Priority — under active development.

## Features

### Exercise Registration

Detailed exercise records with:

- **Exercise type** — strength or cardio, determining which fields and UX apply
- **Muscle group** targeted (chest, back, legs, cardio, etc.)
- **Specific muscles** worked (e.g. biceps, triceps, rear deltoid)
- **Muscle region** activated — the specific portion of the muscle the exercise emphasizes (e.g. upper chest on incline bench press vs. mid chest on flat bench press)
- **Equipment** required or alternative options
- **Variations** or substitute exercises — modeled as a self-relation between exercises, allowing navigation between alternatives

#### Cardio Exercises

Pre-loaded cardio exercises include treadmill running, stationary bike, rowing machine, elliptical, jump rope, and jumping jacks. Cardio exercises use duration (seconds) and distance (meters) instead of reps and weight.

### Equipment Registration

- Register equipment available in the app
- Link equipment to user profile (indicate which equipment the user owns)

### Workout Builder

- Build workouts as sets of exercises
- Configure per exercise based on type:
  - **Strength**: sets, reps, rest time
  - **Cardio**: sets, duration (goal), rest time
- **Supersets** — link two or more exercises to be executed in alternation without rest between them; rest is taken after completing one round of all linked exercises
- **AI assist (future):** personalized workout suggestions based on user profile (goals, available equipment, history)

### Execution Logging

- Log a workout execution
- **Strength exercises:**
  - Record weight used per set (defaults to last recorded weight from history)
  - Record reps per set (defaults dynamically to last completed set's reps within the session)
  - **Drop sets** — add additional reduced-weight segments within a single set
  - **Performance feedback** — color-coded reps indicate deviation from plan (neutral within ±1 rep of target, warning at ±2-3, error at ±4+)
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
  - **Strength**: sets with weight × reps, color-coded performance indicators, aggregated load feedback
  - **Cardio**: sets with duration and distance
- Performance feedback carried through to history (same color coding and suggestions as during execution)

### User Training Profile

Personal data tracking for progression:

- Weight
- Height
- Age
- General goal (hypertrophy, weight loss, endurance, etc.)
- Desired body aesthetic:
  - **Athletic** — gymnast / calisthenics style
  - **Hypertrophy** — focus on muscle volume
  - **Strength** — focus on load and performance
