# GigaCat Architecture

This document describes a practical architecture for GigaCat as a solo-developed iOS app.

The goal is to keep the codebase simple, testable, and ready for future offline-first sync without introducing unnecessary complexity too early.

## 1. High-Level Layer Diagram

```text
SwiftUI Views
    ↓
ViewModels (@Observable)
    ↓
Repositories (protocol-based)
    ↓
Local Data Source (SwiftData later)
    +
Remote Data Source (Supabase later)
```

### Direction Rules

- Views talk only to ViewModels.
- ViewModels do not access SwiftData directly.
- ViewModels do not access Supabase directly.
- ViewModels talk to repositories.
- Repositories decide how local and remote data are coordinated.

## 2. Responsibility of Each Layer

## SwiftUI Views

Purpose:
Render UI and send user actions upward.

Responsibilities:

- Show lists, forms, buttons, loading states, and error states.
- Bind user input to ViewModel state.
- Trigger actions such as start session, save set, complete workout.

Must not:

- Read or write SwiftData.
- Call Supabase.
- Contain business rules.

## ViewModels

Purpose:
Prepare screen state for the UI and coordinate user actions.

Responsibilities:

- Expose screen state using Observation.
- Convert repository results into UI-friendly state.
- Handle loading, empty, success, and error states.
- Trigger domain actions such as loading a program or saving an exercise log.

Must not:

- Know storage details.
- Contain sync implementation.
- Grow into large "god objects".

## Use Cases Later

Purpose:
Do not introduce a separate use case layer yet. For now, GigaCat can stay simpler with ViewModels calling repositories directly.

Add use cases later only when:

- Business logic becomes hard to read inside a ViewModel.
- One action needs coordination across multiple repositories.
- Validation or workflow rules become substantial enough to deserve their own unit tests.

Until then, prefer small ViewModels and clear repository APIs.

## Repositories

Purpose:
Provide the domain-facing API for reading and writing app data.

Responsibilities:

- Expose simple methods in domain terms.
- Hide whether data comes from local storage, remote sync, or both.
- Make offline-first behavior predictable.
- Map between persistence models and domain models later when SwiftData is introduced.

## Local Data Source

Purpose:
Store the app's working data on device.

Current status:

- Planned for later.
- SwiftData will become the local source of truth.

Responsibilities later:

- Persist users, programs, workout sessions, and exercise logs.
- Support fast reads for UI.
- Support offline usage without network availability.

## Remote Data Source

Purpose:
Handle authentication and cloud sync.

Current status:

- Planned for later.
- Supabase will be used for auth and sync.

Responsibilities later:

- Manage authenticated user identity.
- Sync user-owned records to cloud.
- Pull remote updates back to local storage.

## 3. Feature Folder Structure

Keep the project feature-first, not layer-first at the top level. This makes it easier for a junior solo developer to find related files quickly.

```text
GigaCat/
  App/
    GigaCatApp.swift
    AppDIContainer.swift

  Core/
    Extensions/
    Utilities/
    DesignSystem/

  Domain/
    Entities/
      User.swift
      WorkoutProgram.swift
      WorkoutDay.swift
      WorkoutDayExercise.swift
      Exercise.swift
      WorkoutSession.swift
      ExerciseLog.swift
    Repositories/
      UserRepository.swift
      WorkoutProgramRepository.swift
      WorkoutRepository.swift

  Data/
    Repositories/
      DefaultUserRepository.swift
      DefaultWorkoutProgramRepository.swift
      DefaultWorkoutRepository.swift
    Local/
      SwiftData/
    Remote/
      Supabase/
    Mappers/

  Features/
    Authentication/
      Views/
      ViewModels/
    Programs/
      Views/
      ViewModels/
    WorkoutSession/
      Views/
      ViewModels/
    History/
      Views/
      ViewModels/
    Progress/
      Views/
      ViewModels/

  PreviewSupport/
  Resources/
```

### Structure Notes

- `Domain` should stay stable and framework-light.
- `Data` contains implementation details.
- `Features` contains screen-specific UI and ViewModels.
- Do not create too many folders before they are needed.
- If a feature is still small, one View and one ViewModel file is enough.

## 4. Data Flow for Saving ExerciseLog

This flow should stay simple and offline-first.

```text
User enters reps/weight/set in SwiftUI screen
    ↓
WorkoutSessionViewModel validates input
    ↓
WorkoutRepository.saveExerciseLog(...)
    ↓
Save to local source of truth first
    ↓
Return updated state to ViewModel
    ↓
UI updates immediately
    ↓
Remote sync happens later when available
```

### Practical Rule

- Save locally first.
- Never block workout logging on network availability.
- Sync to Supabase later in the background.

### What the ViewModel Should Care About

- Current session id
- Selected exercise
- Set number
- Reps
- Weight
- Save result state

### What the Repository Should Care About

- Writing the log to local storage
- Attaching it to the correct `WorkoutSession`
- Marking it for future sync when remote sync exists

## 5. WorkoutSession Lifecycle

`WorkoutSession` needs lifecycle tracking because a workout may begin before it is completed.

Suggested states:

- `inProgress`: User has started the workout and can save exercise logs.
- `completed`: Workout finished successfully.

For MVP, the minimum practical flow is:

```text
No active session
    ↓
User starts workout day
    ↓
WorkoutSession created with status = inProgress and startedAt
    ↓
User saves one or more ExerciseLog entries
    ↓
User completes workout
    ↓
WorkoutSession updated with status = completed and completedAt
```

### Lifecycle Rules

- Only one active `inProgress` session per workout flow unless a future feature requires otherwise.

## 6. PreviewSupport and Mock Data

`PreviewSupport` is allowed to stay simpler than production data infrastructure, but it should still follow clear boundaries.

Current approach:

- `MockSeedData.makeStore()` is the single entry point for building seeded in-memory app data.
- `MockDataStore` acts as the shared in-memory source for mock repositories.
- Mock repository implementations read from the same seeded store so previews and tests stay coherent.

### Organization Rule

Keep `MockSeedData` readable by separating fixture builders by concern:

- users and programs
- workout structure
- sessions and exercise logs

Use `extension MockSeedData` in separate files when the fixture set grows large, instead of introducing many new mock-specific types too early.

### Practical Rule

- Keep `makeStore()` short and orchestration-focused.
- Keep fixture helpers grouped by domain meaning, not by arbitrary code size alone.
- Prefer one shared seeded store over disconnected mock values so feature flows behave consistently in previews and tests.
- `startedAt` is set when the workout begins.
- `completedAt` is set only when the session is completed.
- `ExerciseLog` records belong to a session, not directly to a workout day.

## 6. Repository Responsibilities

Repositories should be small and explicit. They are not generic database wrappers.

## UserRepository

Responsibilities:

- Load current user
- Save or update user
- Change selected program
- Later coordinate user auth identity with local profile state

## WorkoutProgramRepository

Responsibilities:

- Fetch available workout programs
- Fetch workout days for a program
- Fetch exercises for a workout day
- Later cache program data locally

## WorkoutRepository

Responsibilities:

- Fetch workout days for a program
- Fetch exercises for a workout day
- Start a workout session
- Load active session
- Update session status
- Complete a session
- Fetch session history for a user
- Save an exercise log
- Load logs for a session
- Load previous performance for an exercise
- Update or delete logs if editing is supported later

### Repository Design Rules

- Define repository protocols in `Domain`.
- Implement concrete repositories in `Data`.
- Keep methods named in business language, not storage language.
- Do not let Views or ViewModels know whether the repository uses memory, SwiftData, or Supabase.

## 7. What Is Intentionally Not Implemented Yet

The architecture should acknowledge future plans without building them too early.

Not implemented yet:

- SwiftData persistence implementation
- Supabase authentication implementation
- Supabase sync engine
- Conflict resolution strategy for sync
- Background sync scheduler details
- Full AI architecture
- Analytics layer
- Modularization into separate Swift packages
- Advanced caching abstractions
- Generic base repository abstractions

### Why

- The app is being built by a solo junior developer.
- The current priority is a clean structure for workout programs and workout logging.
- Over-engineering early would slow development and make the project harder to understand.
- A separate use case layer is intentionally postponed until the business logic justifies it.

## Recommended Starting Point

Build in this order:

1. Domain entities and repository protocols.
2. Feature Views and small ViewModels.
3. In-memory or simple temporary repository implementations.
4. Workout session flow and exercise logging flow.
5. SwiftData local persistence.
6. Supabase auth and sync.

This keeps GigaCat practical: simple now, but ready to grow into a true offline-first app later.
