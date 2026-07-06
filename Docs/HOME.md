# GigaCat Home Feature

This document describes the current `Home` feature in GigaCat.

The goal of the feature is to give the user a single entry point for discovering workout programs, reviewing the currently selected program, and resuming or starting training.

## 1. Purpose

`Home` is responsible for:

- showing recommended workout programs
- showing popular workout programs
- filtering programs by tags
- searching programs by keywords
- presenting program details
- showing the mini player entry point for the current workout state
- opening profile from a reusable header action

`Home` is not responsible for:

- workout logging UI
- direct data persistence
- direct SwiftData reads
- direct Supabase access

## 2. Architecture Inside Home

The feature follows the project MVVM rules and keeps business logic outside SwiftUI views.

```text
HomeView
    ↓
HomeViewModel
    ↓
Home services and mappers
    ↓
Repositories
```

### Main Files

- `Features/Home/Views/HomeView.swift`
  Renders the screen, wires sheets and overlays, and forwards user actions upward.

- `Features/Home/ViewModels/HomeViewModel.swift`
  Owns screen state, coordinates loading, and delegates feature logic to services.

- `Features/Home/Services/HomeProgramDiscoveryService.swift`
  Handles tag availability, tag filtering, and keyword search.

- `Features/Home/Services/HomePresentationService.swift`
  Builds UI-ready Home data from repository results.

- `Features/Home/Services/HomeSessionCoordinator.swift`
  Handles session-related decisions and mutations used by Home.

- `Features/Home/Mappers/HomeViewDataMapper.swift`
  Maps domain and repository data into Home-specific view data.

- `Features/Home/Mappers/HomeAlertBuilder.swift`
  Builds user-facing alert content for Home session flows.

## 3. Repository Dependencies

`HomeViewModel` depends on multiple repositories because the screen combines discovery, selection, and session state.

### `UserRepository`

Used for:

- reading the current user
- reading and updating the selected program

### `HomeRepository`

Used for:

- fetching the curated Home catalog
- providing Home-specific metadata such as:
  - recommended flag
  - popular flag
  - rating score

This repository exists because that metadata is discovery-oriented presentation data, not core program structure.

### `WorkoutProgramRepository`

Used for:

- fetching workout programs
- fetching workout days
- fetching workout day exercises

### `WorkoutRepository`

Used for:

- reading the active session
- reading completed sessions
- reading exercise logs
- completing or deleting sessions

## 4. Home Data Flow

When `Home` loads:

1. `HomeView` triggers `loadIfNeeded()`.
2. `HomeViewModel` loads the current user from `UserRepository`.
3. `HomeViewModel` fetches the Home catalog from `HomeRepository`.
4. `HomePresentationService` maps catalog entries into `ProgramSectionItem`.
5. `HomePresentationService` builds:
   - selected program summary
   - mini player state
   - progress text for active sessions
6. `HomeProgramDiscoveryService` exposes:
   - available tags
   - tag-filtered programs
   - search results

The view renders only prepared screen state. It does not compute business rules by itself.

## 5. Screen Composition

The Home screen currently contains these parts:

### Fixed Header

- Uses the reusable `AppHeaderView`
- Stays outside the scrollable content
- Shows `search` and `profile` actions

### Tag Scroller

- Horizontal list of available tags
- Uses `WorkoutProgram.tags` as the source of truth
- Selecting a tag switches the content mode to tag results

### Recommended Section

- Horizontal card list
- Visible only when no tag filter is active
- Uses the `isRecommended` catalog flag

### Popular Section

- Vertical list
- Visible only when no tag filter is active
- Uses the `isPopular` catalog flag

### Tag Result Section

- Replaces the recommended and popular sections when a tag is selected
- Uses the same row presentation style as popular programs

### Search Sheet

- Opens from the header search action
- Searches by title, description, and tags
- Selecting a result opens program details

### Program Detail Sheet

- Shows the selected program details
- Exposes primary action based on current Home state:
  - choose program
  - start
  - continue

### Session Conflict Dialog

- Appears when the user tries to switch to another program while an unfinished session is active
- Makes the risk explicit before mutating session state

## 6. Home-Specific View Data

`Home` uses feature-specific view data instead of passing raw domain models directly into every view.

Examples:

- `ProgramSectionItem`
- `SelectedProgramSummary`
- `ProgramDetail`
- `MiniPlayerState`

These types exist because the Home UI needs:

- combined data from several repositories
- already-formatted text
- UI-specific flags such as `isSelected`, `isRecommended`, and `hasActiveSession`

This keeps SwiftUI views simple and prevents repeated mapping logic inside the UI layer.

## 7. Search and Filtering Rules

Search and filtering are handled by `HomeProgramDiscoveryService`.

### Tags

- Available tags are derived from actual program data.
- Tag order is controlled by a preferred Home order.
- `all` is always present as the default mode.

### Search

- Query is normalized with case-insensitive and diacritic-insensitive matching.
- Search works across:
  - program title
  - program description
  - tag titles
- All typed tokens must match the searchable text.

## 8. Mini Player and Session Rules

The mini player reflects the current workout situation.

### No Selected Program

- Title tells the user that no program is selected
- No workout action is available

### Selected Program, No Active Session

- Home shows the next workout day for the selected program
- Primary action is `Start`

### Active Session

- Home shows:
  - program title
  - workout day title
  - completion progress
- Primary action is `Continue`

### Session Expiration

- A session is considered expired after 8 hours of inactivity
- Inactivity is measured from the latest session activity:
  - latest exercise log time if logs exist
  - otherwise session start time

### Program Switching Conflict

- If an active session belongs to a different selected program, Home blocks the switch
- The user must decide whether to:
  - finish the session
  - cancel the session
  - dismiss and keep the current session unchanged

## 9. Progress Calculation

Session completion progress on Home is based on planned sets versus logged sets.

Rules:

- planned set count comes from `WorkoutDayExercise.targetSets`
- logged progress is grouped by `workoutDayExerciseId`
- duplicate logs for the same set number do not overcount progress
- progress is capped by the planned number of sets

This allows Home to show reliable completion percentage for the active workout day.

## 10. Mock Data

At the moment, Home is backed by mock repositories and mock domain data.

Mocks include:

- users
- workout programs
- workout days
- workout day exercises
- exercises
- workout sessions
- exercise logs
- Home catalog metadata

This keeps the feature testable and lets UI work continue before SwiftData and sync are introduced.

## 11. Rules For Extending Home

When adding new behavior to `Home`, prefer these rules:

- add UI composition changes in `Views`
- keep `HomeView` focused on layout and event forwarding
- keep `HomeViewModel` focused on orchestration, not low-level logic
- put search and filtering rules into `HomeProgramDiscoveryService`
- put session decisions and mutations into `HomeSessionCoordinator`
- put UI mapping into `HomeViewDataMapper`
- keep alerts constructed by `HomeAlertBuilder`
- do not access SwiftData or Supabase from `Home`
- prefer feature-specific view data over formatting domain models inside SwiftUI views

## 12. Testing Priorities

The most valuable tests for `Home` are:

- unit tests for search and tag filtering
- unit tests for session progress calculation
- unit tests for next workout day selection
- unit tests for session conflict and expiration flows
- integration-style ViewModel tests with mock repositories

## 13. Current Boundaries

The current Home feature intentionally stops at discovery and routing concerns.

It does not yet own:

- full workout execution UI
- exercise logging flow
- library persistence flow
- production recommendation logic
- production popularity logic

Those concerns should continue to live outside `Home`, with `Home` acting as the entry and discovery surface.
