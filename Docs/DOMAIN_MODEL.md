# GigaCat Domain Model

The v1 domain separates remotely curated workout structure from user-owned workout activity.
Persistence and transport details are not part of domain entities.

## User

The authenticated person using the app.

- `id`: provider-independent Supabase Auth identity
- `selectedProgramId`: optional explicitly selected `WorkoutProgram`
- `createdAt`, `updatedAt`: lifecycle timestamps

A user owns many workout sessions and can select one system program.

## WorkoutProgram

A reusable training plan.

- `id`: stable catalog identifier
- `authorId`: nil for a system/default program; reserved for possible future user programs
- `audience`: intended audience metadata used by catalog content
- `title`, `description`: display content
- `tags`: catalog filter categories
- `isActive`: whether the program is visible in the active catalog

Only active programs with a nil `authorId` appear in v1 Catalog. Stable ID lookups can still resolve
inactive programs referenced by history.

## WorkoutDay

An ordered planned training day inside a program.

- `id`, `programId`
- `title`
- `orderIndex`

SwiftData keeps an additional `isActive` compatibility flag used to hide removed catalog days while
preserving stable historical lookups.

## WorkoutDayExercise

The ordered relationship between a workout day and a reusable exercise.

- `id`, `workoutDayId`, `exerciseId`
- optional `targetSets`, `targetReps`
- `orderIndex`

Targets are optional because catalog content may intentionally omit them. Historical ID lookups must
remain able to resolve assignments marked inactive by the SwiftData catalog store.

## Exercise

A reusable exercise definition.

- `id`
- `name`
- `muscleGroup`

## WorkoutSession

A user-owned performance of one workout day.

- `id`, `userId`, `workoutDayId`
- `status`: in progress or completed
- `startedAt`, optional `completedAt`

At most one session may be in progress for a user.

## ExerciseLog

One performed set inside a session.

- `id`, `sessionId`, `workoutDayExerciseId`
- `weight`, `reps`, `setNumber`, `performedAt`

The pair of planned exercise and set number is logically unique within a session. Saving it again
updates the existing set.

## Supporting Persistence Models

Sync outbox records queue user mutations for remote delivery. They are infrastructure models, not a
feature-facing domain concept. The v1 persistence schema has no saved-program or marketplace-metadata
entities because Library membership, rankings, ratings, and recommendations are outside the product
scope.

## Relationships

- `User` 1 → many `WorkoutSession`
- `WorkoutProgram` 1 → many `WorkoutDay`
- `WorkoutDay` 1 → many `WorkoutDayExercise`
- `WorkoutDay` 1 → many `WorkoutSession`
- `Exercise` 1 → many `WorkoutDayExercise`
- `WorkoutSession` 1 → many `ExerciseLog`
- `WorkoutDayExercise` 1 → many `ExerciseLog`
