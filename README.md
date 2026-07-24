# GigaCat

GigaCat is an offline-first fitness tracking app built with SwiftUI for iOS.

## Overview

The app is designed around local-first data flow, clean feature boundaries, and simple native UI patterns.
Its goal is to support workout programs, sessions, exercise tracking, and progress features while keeping the codebase modular and testable.

## Tech Stack

- Swift
- SwiftUI
- MVVM
- Repository Pattern
- SwiftData
- Supabase
- Dependency Injection

## Architecture

GigaCat follows these principles:

- UI must not access SwiftData directly
- UI must not access Supabase directly
- ViewModels communicate through repositories and use cases
- Business logic should not live inside Views
- Prefer protocols for repositories and services
- Keep files small, focused, and testable

## Project Structure

```text
GigaCat/
  App/
  Core/
  Data/
  Domain/
  Features/
  PreviewSupport/
  GigaCatTests/
  GigaCatUITests/
```

## Current Domain

- WorkoutProgram
- WorkoutDay
- WorkoutDayExercise
- Exercise
- WorkoutSession
- ExerciseLog

## Project Documentation

- [Architecture](Docs/ARCHITECTURE.md)
- [Domain Model](Docs/DOMAIN_MODEL.md)
- [Home Feature](Docs/HOME.md)
- [Workout Feature](Docs/WORKOUT.md)
- [Code Review Guide](Docs/CODE_REVIEW.md)
- [Product Requirements](Docs/PRD.md)

## Getting Started

1. Open `GigaCat.xcodeproj` in Xcode
2. Select an iPhone simulator
3. Build and run the app

## Development

Run SwiftLint:

```bash
swiftlint lint
```

Auto-fix supported SwiftLint issues:

```bash
swiftlint --fix
```

## Notes

- Prefer reusable components over one-off UI
- Avoid force unwraps
- Reuse existing abstractions before introducing new ones
- Add documentation comments for public protocols, public models, and non-obvious methods
