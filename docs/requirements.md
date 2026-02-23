# Requirements — Athlos

Requirements organized by release phase using [MoSCoW](https://en.wikipedia.org/wiki/MoSCoW_method) prioritization.

- **Must** — essential for the phase to ship
- **Should** — important but not blocking release
- **Could** — desirable if time allows
- **Won't (this phase)** — explicitly deferred to a later phase

---

## V1 — Local & Free

### Epic: Project Setup

| ID | MoSCoW | Requirement |
|----|--------|-------------|
| S-01 | Must | Flutter project scaffolded with Clean Architecture (core/, features/, l10n/) |
| S-02 | Must | Drift configured with initial migrations and AppDatabase |
| S-03 | Must | Riverpod set up with code generation (`@riverpod`) |
| S-04 | Must | go_router configured with route constants and Hub-based navigation |
| S-05 | Must | Athlos theme implemented (color scheme, typography, design tokens) |
| S-06 | Must | i18n configured with PT-BR ARB files |
| S-07 | Must | Error handling foundation (`Result<T>`, `AppException` sealed hierarchy) in `core/errors/` |
| S-08 | Must | Design tokens implemented (`AthlosSpacing`, `AthlosRadius`, `AthlosElevation`, `AthlosDurations`) in `core/theme/` |

### Epic: Hub & Navigation

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| HN-01 | Must | As a user, I want a central Hub screen so that I can access all available modules from one place | Hub displays a card for each active module; tapping a card navigates into the module |
| HN-02 | Must | As a user, I want each module card on the Hub to show a quick summary so that I get an overview without entering the module | Training card shows last workout name and date; Diet card shows today's kcal summary (or empty state if none) |
| HN-03 | Must | As a user, I want to navigate back to the Hub from any module so that I can switch contexts easily | Back/Hub button is always accessible from within a module |
| HN-04 | Must | As a user, I want each module to have its own bottom navigation bar so that I can move between sections within the module | Training: Home, Workouts, Exercises, History; Diet: Home, Meals, Foods, Log |
| HN-05 | Must | As a user, I want to access my profile from the Hub so that I can view and edit my personal data | Profile is accessible via the Hub app bar (not tied to any module) |

### Epic: Onboarding

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| ON-01 | Must | As a user, I want to set up my profile on first launch so that the app knows my basic data | User fills weight, height, age, goal, and body aesthetic; data is saved locally |
| ON-02 | Should | As a user, I want to skip non-essential profile fields and fill them later so that onboarding is quick | Only name is required; other fields can be skipped and completed in Profile |

### Epic: User Profile

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| UP-01 | Must | As a user, I want to register my weight, height, and age so that the app can track my personal data | Fields are saved locally; weight accepts decimals (kg) |
| UP-02 | Must | As a user, I want to set my general goal (hypertrophy, weight loss, endurance) so that the app understands what I'm working towards | Single-select from predefined goals; saved to profile |
| UP-03 | Must | As a user, I want to set my desired body aesthetic (athletic, hypertrophy, strength) so that workout suggestions align with my vision | Single-select from predefined aesthetics; saved to profile |
| UP-04 | Must | As a user, I want to update my profile data at any time so that my progression is tracked | All profile fields are editable from the Profile screen |

### Epic: Equipment

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| EQ-01 | Must | As a user, I want to browse a pre-loaded catalog of training equipment so that I can identify what I use | App ships with a seeded catalog of common equipment (barbell, dumbbell, cables, etc.) |
| EQ-02 | Must | As a user, I want to mark which equipment I own so that workouts can be tailored to what's available to me | Toggle equipment on/off in my profile; selection persists |
| EQ-03 | Should | As a user, I want to add custom equipment so that less common items are also covered | User provides name; custom equipment is saved locally and appears alongside catalog items |
| EQ-04 | Should | As a user, I want to remove equipment from my owned list so that my available gear stays up to date | Unmark equipment via the same toggle used to mark it |

### Epic: Exercise

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| EX-01 | Must | As a user, I want to browse a pre-loaded catalog of exercises so that I don't have to create everything from scratch | App ships with a seeded catalog of common exercises with muscle data and equipment links |
| EX-02 | Must | As a user, I want to browse exercises by muscle group so that I can find exercises for the muscles I want to train | Exercise list is filterable by muscle group; groups shown as filter chips or tabs |
| EX-03 | Must | As a user, I want to see which specific muscles and muscle regions an exercise targets so that I understand its impact in detail | Exercise detail screen shows primary muscle group, specific muscles, and muscle regions |
| EX-04 | Must | As a user, I want to see which equipment an exercise requires so that I know if I can perform it | Exercise detail screen lists required equipment |
| EX-05 | Must | As a user, I want to see variations and substitute exercises so that I have alternatives when needed | Exercise detail screen shows linked variations; tapping navigates to the variation |
| EX-06 | Should | As a user, I want to add custom exercises so that I can include exercises not yet in the catalog | User provides name, muscle group, muscles, and optionally equipment; saved locally |
| EX-07 | Could | As a user, I want to filter exercises by equipment I own so that I only see exercises I can actually do | Toggle filter that cross-references owned equipment with exercise requirements |

### Epic: Workout Builder

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| WK-01 | Must | As a user, I want to create a workout by selecting exercises so that I have a structured training plan | Workout requires a non-empty name and at least one exercise; saved to local database |
| WK-02 | Must | As a user, I want to define sets, reps, and rest time for each exercise in a workout so that my plan is detailed | Each exercise entry has configurable sets (quantity), reps per set, and rest duration |
| WK-03 | Should | As a user, I want to reorder exercises within a workout so that I can control the training sequence | Drag-and-drop or move up/down controls; new order persists on save |
| WK-04 | Must | As a user, I want to edit existing workouts so that I can keep my plans up to date | All workout fields (name, exercises, sets/reps) are editable after creation |
| WK-05 | Must | As a user, I want to delete workouts I no longer use so that my list stays clean | Delete with confirmation dialog; associated execution history is preserved |
| WK-06 | Could | As a user, I want to duplicate an existing workout so that I can quickly create variations | Creates a copy with "(copy)" appended to the name; fully editable |

### Epic: Execution Logging

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| LG-01 | Must | As a user, I want to start a workout execution from a saved workout so that I can follow my plan | Execution screen loads the workout's exercises and set configuration |
| LG-02 | Must | As a user, I want to log the weight used for each set so that my load progression is recorded | Weight input per set; accepts decimals (kg); defaults to last recorded weight for that exercise |
| LG-03 | Must | As a user, I want to mark sets as completed during execution so that I track my progress in real time | Tap to mark/unmark a set as done; visual distinction between completed and pending |
| LG-04 | Should | As a user, I want a rest timer between sets so that I stay on track with my rest periods | Timer starts automatically after marking a set complete; uses rest duration from workout config |
| LG-05 | Must | As a user, I want to view my execution history so that I can see my past workouts | History screen shows list of executions with date, workout name, and duration |
| LG-06 | Could | As a user, I want to see load progression charts per exercise so that I visualize my strength gains over time | Line chart showing weight over time for a selected exercise |

### Epic: Data Backup

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| BK-01 | Should | As a user, I want to export all my data to a file so that I have a backup in case I lose my phone | Export generates a JSON file containing all user data (profile, workouts, executions, foods, meals, logs); file can be saved/shared via OS share sheet |
| BK-02 | Should | As a user, I want to import data from a backup file so that I can restore my data on a new device | Import reads a JSON file and restores all data; prompts confirmation before overwriting existing data |

### Epic: Diet — Food Registration

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| DT-01 | Must | As a user, I want to register foods with macronutrient data so that I can track what I eat | Food record with name, calories, protein, carbs, fat (per 100g or per serving); saved locally |
| DT-02 | Must | As a user, I want to browse a pre-loaded catalog of common foods so that I don't have to register everything manually | App ships with a seeded catalog of common foods with macronutrient data |
| DT-03 | Should | As a user, I want to add custom foods so that I can track items not in the catalog | User provides name and macros; saved locally alongside catalog items |
| DT-04 | Should | As a user, I want extensible nutritional fields (vitamins, minerals, amino acids) so that I can track detailed data as needed | Optional micronutrient fields on food registration; shown when populated |

### Epic: Diet — Meal Builder

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| DT-05 | Must | As a user, I want to build meals by combining registered foods so that I have structured meal plans | Meal contains one or more foods with quantity; nutritional totals auto-calculated |
| DT-06 | Must | As a user, I want to see nutritional totals per meal so that I understand my intake | Meal detail shows summed kcal, protein, carbs, fat |
| DT-07 | Must | As a user, I want to edit and delete meals so that I can keep my plans up to date | All meal fields editable after creation; delete with confirmation |

### Epic: Diet — Caloric Control

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| DT-08 | Must | As a user, I want to see estimated daily kcal and macros so that I track my consumption | Daily log screen aggregates all meals for the day |
| DT-09 | Should | As a user, I want to log caloric expenditure so that I can see my daily caloric balance | Manual entry of activity + estimated kcal burned; daily balance = intake - expenditure |
| DT-10 | Could | As a user, I want caloric expenditure pulled automatically from my logged workouts so that I don't need to enter it manually | Cross-module integration via shared interface in `core/domain/` |

---

## V2 — Backend & Sync

### Epic: Authentication

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| AU-01 | Must | As a user, I want to create an account so that my data is associated with my identity | Email + password registration; account created on backend |
| AU-02 | Must | As a user, I want to log in and log out so that I can securely access my data | Session persists across app restarts; logout clears session |
| AU-03 | Should | As a user, I want to sign in with Google/Apple so that registration is frictionless | OAuth flow via Supabase Auth or Firebase Auth |

### Epic: Cloud Sync

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| SY-01 | Must | As a user, I want my data synced to the cloud so that I don't lose it if I change devices | All local data is pushed to remote on sync |
| SY-02 | Must | As a user, I want the app to work offline and sync when online so that I'm not dependent on internet | Local-first behavior preserved; sync happens automatically when connection is available |
| SY-03 | Should | As a user, I want to use the app on multiple devices with the same data so that I'm not locked to one phone | Conflict resolution strategy for concurrent edits (last-write-wins or merge) |

---

## V3 — AI, Integrations & Gamification

### Epic: Quíron (AI Assistant)

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| QR-01 | Must | As a user, I want AI-generated workout suggestions based on my profile and equipment so that I get personalized training plans | Quíron considers user goal, aesthetic, owned equipment, and history |
| QR-02 | Must | As a user, I want a Q&A chat with Quíron for exercise and nutrition questions so that I have guidance within the app | Chat interface with message history; context-aware responses |
| QR-03 | Should | As a user, I want AI-generated meal suggestions based on my goals so that I get personalized diet plans | Quíron considers caloric targets, macros, and food preferences |
| QR-04 | Should | As a user, I want AI trend analysis of my caloric data so that I get actionable recommendations | Quíron analyzes intake vs. expenditure trends and suggests adjustments |
| QR-05 | Could | As a user, I want conversational onboarding guided by Quíron so that profile setup feels natural | Chat-based alternative to the form; structured setup remains as fallback |

### Epic: Health Integrations

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| HI-01 | Should | As a user, I want to import activity data from Apple Health / Google Fit so that my tracking is more complete | One-way sync of activity/step data into execution history |
| HI-02 | Could | As a user, I want to import body metrics (weight, body fat) from health apps so that my profile updates automatically | Imported metrics feed into body metrics timeline |

### Epic: Kleos (Gamification)

| ID | MoSCoW | User Story | Acceptance Criteria |
|----|--------|------------|---------------------|
| KL-01 | Should | As a user, I want to earn achievements for milestones (first workout, 100kg squat, etc.) so that I feel rewarded | Achievement unlocked notification + persistent badge in profile |
| KL-02 | Should | As a user, I want workout streaks tracked so that I'm motivated to stay consistent | Streak counter on Hub; resets after configurable inactivity period |
| KL-03 | Could | As a user, I want periodic challenges (e.g. "Complete 5 workouts this week") so that I have short-term goals | Weekly/monthly challenges with progress indicator |
| KL-04 | Could | As a user, I want a progression/level system so that my overall journey has a sense of advancement | XP earned from workouts/meals logged; levels with thematic names (Greek heroes) |
