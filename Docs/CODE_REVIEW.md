# GigaCat Code Review Guide

This document is a practical code review checklist for GigaCat.

It is written for a solo junior iOS developer, so the goal is not to simulate a large team review process. The goal is to catch bugs, architectural drift, and unnecessary complexity before code grows.

## Review Goal

When reviewing code in GigaCat, prioritize:

- correctness
- simplicity
- architecture consistency
- testability
- future maintainability

Do not optimize for "smart" architecture. Optimize for code that is easy to understand and safe to extend.

## Review Order

Review code in this order:

1. Does the feature work correctly?
2. Does it break the agreed architecture?
3. Is there unnecessary complexity?
4. Is the naming clear?
5. Is the code easy to change later?

## 1. Core Architecture Checks

These checks matter the most for GigaCat.

### UI Layer

Check that:

- SwiftUI Views only render UI and send user actions.
- Views do not contain business logic.
- Views do not access SwiftData directly.
- Views do not access Supabase directly.
- Views do not transform into large, state-heavy files.

Warning signs:

- Database fetch logic inside a View
- Network calls inside a View
- Long button actions with business rules
- Repeated validation logic inside multiple Views

### ViewModel Layer

Check that:

- ViewModels expose screen state clearly.
- ViewModels coordinate user actions without knowing persistence details.
- ViewModels talk to repositories, not directly to storage or Supabase.
- ViewModels stay focused on one screen or one flow.

Warning signs:

- One ViewModel handles multiple unrelated screens
- ViewModel knows too much about storage format
- ViewModel contains sync logic
- ViewModel becomes a dumping ground for all feature logic

### Repository Layer

Check that:

- Repositories expose business-level methods.
- Repositories hide storage details from the UI layer.
- Repository APIs are small and practical.
- Repositories are not generic abstractions without real need.

Warning signs:

- Repository method names sound like database internals
- Too many tiny repositories with almost no logic
- Repositories returning storage-specific models to the UI
- Repository protocols existing without a real second implementation need

## 2. Domain Model Checks

The domain model should stay clean and stable.

Check that:

- Code respects the existing entities in `DOMAIN_MODEL.md`.
- Planned workout data stays separate from logged workout data.
- `Exercise` remains a reusable exercise definition.
- `WorkoutDayExercise` stores planned workout parameters.
- `ExerciseLog` stores actual performed values.
- `WorkoutSession` is the owner of session-based logs.

Warning signs:

- `Exercise` starts storing session-specific values
- `WorkoutDay` starts storing completed workout results
- One model mixes plan data and history data
- New entity-like behavior appears without being reflected in the domain model

## 3. Workout Flow Checks

Workout logging is a core app flow, so review it carefully.

Check that:

- A workout can start cleanly.
- `WorkoutSession` gets `startedAt` when started.
- Session `status` changes correctly.
- `completedAt` is only set when the session is completed.
- `ExerciseLog` always belongs to a valid `WorkoutSession`.
- Reps, weight, and set number are saved correctly.

Warning signs:

- Logs can exist without a session
- Session can be completed without clear status transition
- Set numbering is inconsistent
- Logging depends on internet access

## 4. Offline-First Checks

GigaCat is offline-first, not offline-only.

Check that:

- The app can work without internet for core workout logging flows.
- Saving data does not depend on remote availability.
- Local behavior is treated as the primary path.
- Cloud sync concerns do not leak into UI code.

Warning signs:

- User cannot save workout data offline
- Network errors block local flows
- UI waits on future Supabase logic for basic actions
- Offline and sync responsibilities are mixed into screens

## 5. Simplicity Checks

Because this is a solo junior project, simplicity is a feature.

Check that:

- New abstractions solve a real current problem.
- File structure is still easy to navigate.
- New protocols are justified.
- The solution is understandable after one quick read.

Warning signs:

- Abstractions added "for the future"
- Multiple files created for one tiny behavior
- Complex generic patterns without clear benefit
- A new layer introduced before it is needed

## 6. Swift / SwiftUI Quality Checks

Check that:

- Naming is clear and consistent.
- Optionals are handled safely.
- Force unwraps are avoided.
- State ownership is clear.
- Observation usage is straightforward.
- Repeated code is extracted only when duplication is real.

Warning signs:

- Confusing names like `data`, `item`, `manager`, `handler`
- Hidden side effects in computed properties
- Too many booleans controlling view state
- One file doing too many things

## 7. Testing Checks

Not every change needs heavy tests, but code should stay testable.

Check that:

- Business logic is not trapped inside SwiftUI Views.
- Repository behavior can be tested later.
- ViewModels can be tested without UI.
- Complex logic is separated enough to validate independently.

Warning signs:

- Logic only works through manual tapping in UI
- Important rules exist only inside view code
- Tight coupling makes isolated testing difficult

## 8. Documentation Checks

Code changes should stay aligned with project documents.

Check that:

- Changes still match `PRD.md`.
- Changes still match `DOMAIN_MODEL.md`.
- Changes still match `ARCHITECTURE.md`.
- If reality changed, the docs are updated too.

Warning signs:

- Code introduces behavior not described anywhere
- Domain terms differ between code and docs
- Architecture rules are broken silently

## 9. Common GigaCat Review Questions

Before merging or continuing a feature, ask:

- Is this code simple enough for future me to understand quickly?
- Did I accidentally put business logic in the View?
- Did I accidentally put persistence details in the ViewModel?
- Does this change make workout logging easier or more fragile?
- Am I adding an abstraction because I need it now, or because I fear future change?
- If the internet is unavailable, does the core flow still make sense?

## 10. Review Summary Template

Use this short format when reviewing your own code:

### What is good

- The change solves the intended feature.
- The architecture is still respected.

### What is risky

- List bugs, regressions, or unclear logic.

### What is unnecessarily complex

- List abstractions, files, or patterns that can be simplified.

### What should be improved before continuing

- List the smallest useful next fixes.

## Final Rule

For GigaCat, prefer:

- small files
- clear naming
- direct flows
- fewer abstractions
- local-first behavior

Avoid:

- clever architecture
- future-proofing too early
- large ViewModels
- business logic in Views
- storage details leaking upward
