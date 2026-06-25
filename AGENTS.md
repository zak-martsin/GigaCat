GigaCat AI Development Rules

Project Overview

GigaCat is an offline-first fitness tracking application built with SwiftUI.

Architecture

* MVVM
* Repository Pattern
* Offline First
* SwiftData as local source of truth
* Supabase for cloud sync
* Dependency Injection

Rules

* UI must not access SwiftData directly.
* UI must not access Supabase directly.
* ViewModels communicate only through repositories/use cases.
* Business logic should not live inside Views.
* Prefer protocols for repositories and services.
* Keep code testable.
* Avoid force unwraps.
* Avoid massive ViewModels.

Development Workflow

Before implementing a feature:

1. Understand domain model.
2. Check existing architecture.
3. Reuse existing abstractions.
4. Prefer small focused files.

Documentation Rules

* Add documentation comments for public protocols, public models, and non-obvious methods.
* Use Swift documentation comments with `///`.
* Do not document obvious code.
* Documentation must explain intent, not repeat the code.
* For complex flows, add a short `// MARK:` section.
* Keep comments short and useful.

Current Domain

* WorkoutProgram
* WorkoutDay
* WorkoutDayExercise
* Exercise
* WorkoutSession
* ExerciseLog
