# GigaCat v1 Product Requirements

Status: implementation contract

Platform: iPhone, iOS 26

Product goal: a finished, reliable personal workout tracker and portfolio project.

## Product Direction

GigaCat v1 is intentionally narrow. It helps an authenticated user choose a curated workout
program, log workouts offline, and review completed training history. The app is not a program
marketplace and does not attempt to cover nutrition or coaching in this release.

The signed-in application has exactly three primary tabs:

1. Catalog
2. Workout
3. Progress

Authentication, the profile sheet, program details, the exercise logger, and the full progress
calendar are supporting flows rather than additional tabs.

## v1 Scope

### Authentication and Profile

- Sign up, sign in, session restoration, and sign out use Supabase Auth.
- The profile sheet remains available from Catalog.
- The selected program belongs to the current user.

### Catalog

- Show only active system-owned default programs.
- Keep tag filters derived from the available catalog so the catalog can grow later.
- Open a program detail sheet with its description, days, and exercises.
- Let the user select a program.
- Start or continue the relevant workout while preserving active-session conflict protection.
- Refresh the catalog from Supabase and keep SwiftData as the UI-facing source of truth.

Catalog v1 does not include search, custom programs, Library membership, ratings, popularity,
recommendation sections, or user-generated programs.

### Workout

- Show the explicitly selected program and its ordered workout days.
- Do not silently select a recommended or historical fallback program.
- Show a clear empty state when no program is selected.
- Create a session atomically when the first valid set is saved.
- Save and update weight and repetitions locally.
- Show previous exercise performance.
- Finish or cancel the active session.
- Remain usable without a network connection.

### Progress

- Show the compact weekly calendar and completed-workout markers.
- Show the full monthly calendar and completed sessions for a selected date.
- Show performed exercises and sets for completed sessions.

The existing Progress implementation is preserved for v1. Measurements, lifted-volume summaries,
streaks, charts, photos, HealthKit, and body-weight tracking are later work.

## Explicitly Out of Scope

- Nutrition, food search, barcode scanning, and calorie calculation
- AI assistants and AI-generated insights
- Library or saved-program collections
- Custom program builder
- Catalog search
- Ratings, reviews, popularity, and recommendation ranking
- Social and trainer/client features
- Subscriptions
- Apple Watch and iPad-specific experiences
- Cross-device synchronization of workout sessions and exercise logs

Out-of-scope areas may be reconsidered after v1, but the v1 dependency graph must not contain
placeholder tabs, repositories, or actions for them.

## Data and Sync Contract

- SwiftData is the local source of truth for feature reads and workout writes.
- Views and ViewModels never access SwiftData or Supabase directly.
- The remote catalog is read-only for normal authenticated users.
- Catalog refreshes are applied to SwiftData before feature caches are invalidated.
- Network failure must not erase a previously cached catalog or block workout logging.
- User profile and selected-program changes use the existing outbox-based synchronization flow.
- Workout history remains local-only in v1; documentation and UI must not promise cross-device
  workout sync.

## v1 Completion Criteria

- The authenticated shell exposes only Catalog, Workout, and Progress.
- A first launch can show default programs without requiring a successful live catalog request.
- Selecting a program updates Catalog, Workout, and the mini player consistently.
- Logging, finishing, and cancelling a workout correctly refresh Workout and Progress.
- Catalog refresh uses one application-level invalidation path.
- Removed product areas are absent from the active dependency graph and UI.
- Historical workout data remains readable when a catalog item is deactivated remotely.
- Unit tests, SwiftLint, and the app build pass.
- Architecture and feature documentation match the implemented behavior.
