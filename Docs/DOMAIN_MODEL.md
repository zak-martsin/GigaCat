# GigaCat Domain Model

This document defines the core domain entities for GigaCat. It focuses on business meaning and relationships, not storage-specific implementation details.

## Modeling Principles

- Keep the domain centered on workout planning and workout logging.
- Use stable identifiers for every entity.
- Model ordering explicitly where sequence matters.
- Separate planned workout structure from completed workout history.
- Associate user-owned records with a single `User`.

## User

### Purpose

Represents the authenticated person using the app. The user owns workout history and other personal data.

### Fields

- `id`: Stable internal identifier.
- `appleUserId`: External identity from Sign in with Apple.
- `selectedProgramId`: Identifier of the currently selected `WorkoutProgram`.
- `createdAt`: When the user record was created.
- `updatedAt`: When the user record was last updated.

### Relationships

- Each `User` can reference one selected `WorkoutProgram`.
- One `User` has many `WorkoutSession` records.

## WorkoutProgram

### Purpose

Represents a predefined training program that organizes workouts into reusable training days.

### Fields

- `id`: Stable program identifier.
- `title`: Program name shown to the user.
- `description`: Short summary of the program.

### Relationships

- One `WorkoutProgram` has many `WorkoutDay` records.

## WorkoutDay

### Purpose

Represents a single planned training day inside a workout program, such as Push, Pull, or Legs.

### Fields

- `id`: Stable workout day identifier.
- `programId`: Identifier of the parent `WorkoutProgram`.
- `title`: User-facing name of the workout day.
- `orderIndex`: Position of the day within the program.

### Relationships

- Each `WorkoutDay` belongs to one `WorkoutProgram`.
- One `WorkoutDay` has many `WorkoutDayExercise` records.
- One `WorkoutDay` can be referenced by many `WorkoutSession` records over time.

## WorkoutDayExercise

### Purpose

Represents an exercise assignment within a planned workout day. This entity exists to model the ordered link between a day and an exercise, and to store planned training parameters separately from the reusable `Exercise` definition.

### Fields

- `id`: Stable workout day exercise identifier.
- `workoutDayId`: Identifier of the parent `WorkoutDay`.
- `exerciseId`: Identifier of the referenced `Exercise`.
- `targetSets`: Planned number of sets for the exercise on that workout day.
- `targetReps`: Planned repetition target for the exercise on that workout day.
- `targetWeight`: Planned weight target for the exercise on that workout day.
- `orderIndex`: Position of the exercise within the workout day.

### Relationships

- Each `WorkoutDayExercise` belongs to one `WorkoutDay`.
- Each `WorkoutDayExercise` references one `Exercise`.

## Exercise

### Purpose

Represents a reusable exercise definition that can appear in workout plans and workout logs. It should contain exercise identity information, not session-specific or plan-specific performance values.

### Fields

- `id`: Stable exercise identifier.
- `name`: Exercise name.
- `muscleGroup`: Primary muscle group associated with the exercise.

### Relationships

- One `Exercise` can appear in many `WorkoutDayExercise` records.
- One `Exercise` can appear in many `ExerciseLog` records.

## WorkoutSession

### Purpose

Represents a workout session performed by a user for a specific workout day. The session lifecycle must support status tracking, including sessions that are in progress and sessions that are completed.

### Fields

- `id`: Stable workout session identifier.
- `userId`: Identifier of the `User` who performed the session.
- `workoutDayId`: Identifier of the planned `WorkoutDay` being executed.
- `status`: Current session state, used to track lifecycle progress.
- `startedAt`: Timestamp when the workout session began.
- `completedAt`: Timestamp when the workout was completed.

### Relationships

- Each `WorkoutSession` belongs to one `User`.
- Each `WorkoutSession` references one `WorkoutDay`.
- One `WorkoutSession` has many `ExerciseLog` records.

## ExerciseLog

### Purpose

Represents a single logged set for an exercise during a workout session. This keeps actual performed values separate from the planned values stored on `WorkoutDayExercise`.

### Fields

- `id`: Stable exercise log identifier.
- `sessionId`: Identifier of the parent `WorkoutSession`.
- `exerciseId`: Identifier of the performed `Exercise`.
- `weight`: Weight used for the set.
- `reps`: Number of repetitions completed.
- `setNumber`: Sequence number of the set within the exercise for that session.

### Relationships

- Each `ExerciseLog` belongs to one `WorkoutSession`.
- Each `ExerciseLog` references one `Exercise`.

## Relationship Summary

- `User` 1 -> many `WorkoutSession`
- `WorkoutProgram` 1 -> many `WorkoutDay`
- `WorkoutDay` 1 -> many `WorkoutDayExercise`
- `WorkoutDay` 1 -> many `WorkoutSession`
- `Exercise` 1 -> many `WorkoutDayExercise`
- `Exercise` 1 -> many `ExerciseLog`
- `WorkoutSession` 1 -> many `ExerciseLog`
