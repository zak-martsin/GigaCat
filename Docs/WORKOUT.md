# GigaCat Workout Feature

This document describes the current baseline implementation of the `Workout` feature.

The feature lets the user inspect the selected program, navigate its workout days, log performed sets, and finish or cancel the active workout session.

## 1. Purpose

`Workout` is responsible for:

- selecting the correct program and workout day when the feature opens
- showing all days and exercises in the selected program
- showing the previous performance for each exercise
- creating a session when the first set is saved
- saving and updating exercise logs
- completing or cancelling an active session
- notifying other screens when workout data becomes stale

`Workout` is not responsible for:

- program discovery and selection UI
- production persistence details
- SwiftData or Supabase access
- workout history presentation
- notes, timers, or exercise instructions

## 2. Architecture

```text
WorkoutView / WorkoutExerciseView
    ↓
WorkoutViewModel / WorkoutExerciseViewModel
    ↓
WorkoutContextService and mappers
    ↓
Repository protocols
    ↓
Shared local data source
```

### Main Components

- `WorkoutContextService`
  Collects the current user, selected or fallback program, ordered program days, exercises, and active session into `WorkoutContext`.

- `WorkoutViewModel`
  Owns the program-level screen state, selected day, session actions, and creation of the exercise ViewModel.

- `WorkoutExerciseViewModel`
  Owns exercise selection, loaded logs, previous performance, set counts, and set-saving state.

- `WorkoutViewDataMapper`
  Maps program and day content into list-screen view data.

- `WorkoutExerciseDetailViewDataMapper`
  Maps the selected exercise and its logs into detail-screen view data.

- `WorkoutRepository`
  Hides session and exercise-log persistence from the feature.

## 3. Workout Entry Rules

`WorkoutContextService` resolves the program in this order:

1. The user's selected program.
2. The program used by the latest session.
3. The first recommended program.

The initial workout day is resolved in this order:

1. The day of the active session.
2. The day after the latest completed session when it belongs to the same program.
3. The first day of a newly selected program.

Program days and exercises are kept ordered by `orderIndex`.

## 4. Screen Flow

### Workout Screen

The main screen shows:

- the selected program
- a ready or active status
- ordered day chips such as `Day 1`, `Day 2`, and `Day 3`
- an active-session badge on the relevant day
- the exercises for the inspected day
- a fixed finish action when the active session belongs to that day
- a menu containing the cancel action

Selecting a day changes only the inspected day. It does not move an existing active session to another day.

### Exercise Screen

The detail screen shows:

- the exercise position within the day
- previous and next exercise navigation
- exercise artwork placeholder
- exercise name
- compact weight and repetition inputs for each set
- a save button for each set
- an `Add Set` action

Additional sets are local UI state until they are saved. A maximum of 10 sets can be displayed for one exercise.

## 5. Session Lifecycle

Opening Workout does not create a session.

```text
No active session
    ↓
User saves the first valid set
    ↓
WorkoutRepository.saveSet(...)
    ↓
Session and first ExerciseLog are created atomically
    ↓
Session status is inProgress
```

Only one session can be active. Saving a set for a different inspected day is blocked while another day's session is active.

### Finish

Finishing a workout:

- requires an active session for the selected day
- changes its status to `completed`
- sets `completedAt`
- preserves its exercise logs for history
- reloads the Workout context

### Cancel

Cancelling a workout:

- requires an active session for the selected day
- deletes the session
- deletes the session's exercise logs
- reloads the Workout context

Both actions require confirmation in the UI.

## 6. Exercise Logging

Each `ExerciseLog` represents one performed set and is identified within a session by:

- `workoutDayExerciseId`
- `setNumber`

Saving the same planned exercise and set number again updates the existing logical set instead of creating duplicate progress.

The input flow supports:

- integer repetitions
- decimal weight with a dot or comma
- numeric keyboards
- saving planned values without manually entering them
- updating a previously saved set

Program data provides target repetitions and target set count. It does not provide a target weight.

## 7. Previous Performance

`WorkoutExerciseViewModel` loads the latest log for the reusable `Exercise`.

The placeholder weight comes from:

1. The latest saved value for that exercise in the current workout.
2. The user's latest log for that exercise across every workout day and session.

The lookup is scoped by user and reusable exercise identity, not by a specific workout day assignment. This lets the user repeat the latest result by saving the prefilled values without typing them again.

## 8. State Ownership

`WorkoutViewModel` owns:

- `WorkoutContext`
- selected workout day
- context loading state
- finish and cancel state

`WorkoutExerciseViewModel` owns:

- selected exercise
- active-session snapshot for the exercise screen
- logs grouped by planned exercise and set number
- previous exercise performance
- displayed set counts
- log loading and saving state

View data remains outside the ViewModels. Views map current ViewModel state through feature mappers.

## 9. Cross-Feature Invalidation

Home caches presentation state such as the mini player and workout progress. Successful Workout mutations therefore mark Home as stale.

```text
Workout mutation succeeds
    ↓
onWorkoutDataChanged()
    ↓
AppShellView
    ↓
HomeViewModel.invalidate()
    ↓
User returns to Home
    ↓
loadIfNeeded() reloads repository state
```

The callback is emitted after:

- saving or updating a set
- finishing a workout
- cancelling a workout

Failed or blocked mutations do not invalidate Home.

`WorkoutViewModel` and `WorkoutExerciseViewModel` know only about the callback. They do not know that `HomeViewModel` exists. `AppShellView` owns the cross-feature connection.

## 10. Current Persistence

The feature currently uses repository protocols backed by a shared `MockDataStore`.

This preserves the intended production boundary:

- Views and ViewModels depend on repositories.
- Repositories hide the data source.
- SwiftData can replace the mock local store without changing screen responsibilities.
- Supabase synchronization can be added behind the repository layer later.

## 11. Testing Coverage

Current tests cover:

- initial program and day resolution
- day selection
- exercise ordering and navigation
- loading current and previous logs
- session creation on the first saved set
- set saving and updating
- additional set restoration and the 10-set limit
- blocking logs for another active day
- finishing and cancelling sessions
- successful mutation callbacks
- Home reload after invalidation

## 12. Deferred Improvements

The following items are intentionally deferred:

- friendly success and error messages
- workout-start guidance
- exercise notes
- exercise history screen
- timers
- exercise descriptions and media
- production SwiftData persistence
- Supabase synchronization
