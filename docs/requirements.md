# Requirements — Athlos

Requirements organized by release phase using [MoSCoW](https://en.wikipedia.org/wiki/MoSCoW_method) prioritization.

- **Must** — essential for the phase to ship
- **Should** — important but not blocking release
- **Could** — desirable if time allows
- **Won't (this phase)** — explicitly deferred to a later phase

---

## V1 — Local & Free

### Epic: Project Setup

| ID | MoSCoW | User Story |
|----|--------|------------|
| S-01 | Must | As a developer, I want the Flutter project scaffolded with Clean Architecture (core, features, l10n) so that the codebase is organized from day one |
| S-02 | Must | As a developer, I want Drift configured with initial migrations so that the local database is ready for use |
| S-03 | Must | As a developer, I want Riverpod set up with code generation so that state management and DI are consistent |
| S-04 | Must | As a developer, I want go_router configured with route constants so that navigation is declarative and centralized |
| S-05 | Must | As a developer, I want the Athlos theme (color scheme, typography, extensions) implemented so that all UI follows the Greek mythology identity |
| S-06 | Must | As a developer, I want i18n configured with PT-BR ARB files so that all strings are localized from the start |

### Epic: Onboarding

| ID | MoSCoW | User Story |
|----|--------|------------|
| O-01 | Must | As a user, I want to choose between Training, Diet, or both modules on first launch so that the interface shows only what's relevant to me |
| O-02 | Should | As a user, I want to change my module selection later in settings so that I can adapt the app as my needs evolve |

### Epic: User Profile

| ID | MoSCoW | User Story |
|----|--------|------------|
| P-01 | Must | As a user, I want to register my weight, height, and age so that the app can track my personal data |
| P-02 | Must | As a user, I want to set my general goal (hypertrophy, weight loss, endurance) so that the app understands what I'm working towards |
| P-03 | Must | As a user, I want to set my desired body aesthetic (athletic, hypertrophy, strength) so that workout suggestions align with my vision |
| P-04 | Should | As a user, I want to update my profile data over time so that my progression is tracked |

### Epic: Equipment

| ID | MoSCoW | User Story |
|----|--------|------------|
| E-01 | Must | As a user, I want to browse a catalog of training equipment so that I can identify what I use |
| E-02 | Must | As a user, I want to mark which equipment I own so that workouts can be tailored to what's available to me |
| E-03 | Should | As a user, I want to add custom equipment so that less common items are also covered |

### Epic: Exercise

| ID | MoSCoW | User Story |
|----|--------|------------|
| X-01 | Must | As a user, I want to browse exercises by muscle group so that I can find exercises for the muscles I want to train |
| X-02 | Must | As a user, I want to see which specific muscles and muscle regions an exercise targets so that I understand its impact in detail |
| X-03 | Must | As a user, I want to see which equipment an exercise requires so that I know if I can perform it |
| X-04 | Must | As a user, I want to see variations and substitute exercises so that I have alternatives when needed |
| X-05 | Should | As a user, I want to add custom exercises so that I can include exercises not yet in the catalog |
| X-06 | Could | As a user, I want to filter exercises by equipment I own so that I only see exercises I can actually do |

### Epic: Workout Builder

| ID | MoSCoW | User Story |
|----|--------|------------|
| W-01 | Must | As a user, I want to create a workout by selecting exercises so that I have a structured training plan |
| W-02 | Must | As a user, I want to define sets, reps, and rest time for each exercise in a workout so that my plan is detailed |
| W-03 | Should | As a user, I want to reorder exercises within a workout so that I can control the training sequence |
| W-04 | Should | As a user, I want to edit and delete existing workouts so that I can keep my plans up to date |
| W-05 | Could | As a user, I want to duplicate an existing workout so that I can quickly create variations |

### Epic: Execution Logging

| ID | MoSCoW | User Story |
|----|--------|------------|
| L-01 | Must | As a user, I want to start a workout execution from a saved workout so that I can follow my plan |
| L-02 | Must | As a user, I want to log the weight used for each set so that my load progression is recorded |
| L-03 | Must | As a user, I want to mark sets as completed during execution so that I track my progress in real time |
| L-04 | Should | As a user, I want a rest timer between sets so that I stay on track with my rest periods |
| L-05 | Should | As a user, I want to view my execution history so that I can see my past workouts and progression |
| L-06 | Could | As a user, I want to see load progression charts per exercise so that I visualize my strength gains over time |

---

## V2 — Backend & Sync

### Epic: Authentication

| ID | MoSCoW | User Story |
|----|--------|------------|
| A-01 | Must | As a user, I want to create an account so that my data is associated with my identity |
| A-02 | Must | As a user, I want to log in and log out so that I can securely access my data |
| A-03 | Should | As a user, I want to sign in with Google/Apple so that registration is frictionless |

### Epic: Cloud Sync

| ID | MoSCoW | User Story |
|----|--------|------------|
| C-01 | Must | As a user, I want my data synced to the cloud so that I don't lose it if I change devices |
| C-02 | Must | As a user, I want offline support with sync when online so that the app works without internet |
| C-03 | Should | As a user, I want to use the app on multiple devices with the same data so that I'm not locked to one phone |

### Epic: Diet Module

| ID | MoSCoW | User Story |
|----|--------|------------|
| D-01 | Must | As a user, I want to register foods with macronutrient data so that I can track what I eat |
| D-02 | Must | As a user, I want to build meals by combining registered foods so that I have structured meal plans |
| D-03 | Must | As a user, I want to see nutritional totals per meal so that I understand my intake |
| D-04 | Must | As a user, I want to see estimated daily kcal and macros so that I track my consumption |
| D-05 | Should | As a user, I want to log caloric expenditure so that I can see my daily caloric balance |
| D-06 | Should | As a user, I want extensible nutritional fields (vitamins, minerals, amino acids) so that I can track detailed data as needed |
| D-07 | Could | As a user, I want caloric expenditure pulled automatically from my logged workouts so that I don't need to enter it manually |

---

## V3 — AI, Integrations & Gamification

### Epic: Quíron (AI Assistant)

| ID | MoSCoW | User Story |
|----|--------|------------|
| Q-01 | Must | As a user, I want AI-generated workout suggestions based on my profile and equipment so that I get personalized training plans |
| Q-02 | Must | As a user, I want a Q&A chat (Quíron) for exercise and nutrition questions so that I have guidance within the app |
| Q-03 | Should | As a user, I want AI-generated meal suggestions based on my goals so that I get personalized diet plans |
| Q-04 | Should | As a user, I want AI trend analysis of my caloric data so that I get actionable recommendations |

### Epic: Health Integrations

| ID | MoSCoW | User Story |
|----|--------|------------|
| H-01 | Should | As a user, I want to import activity data from Apple Health / Google Fit so that my tracking is more complete |
| H-02 | Could | As a user, I want to import body metrics (weight, body fat) from health apps so that my profile updates automatically |

### Epic: Kleos (Gamification)

| ID | MoSCoW | User Story |
|----|--------|------------|
| K-01 | Should | As a user, I want to earn achievements for milestones (first workout, 100kg squat, etc.) so that I feel rewarded for my progress |
| K-02 | Should | As a user, I want workout streaks tracked so that I'm motivated to stay consistent |
| K-03 | Could | As a user, I want periodic challenges (e.g. "Complete 5 workouts this week") so that I have short-term goals to pursue |
| K-04 | Could | As a user, I want a progression/level system so that my overall journey has a sense of advancement |
