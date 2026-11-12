# GigaCat Domain Model

The v1 domain separates remotely curated workout structure from user-owned workout activity.
Persistence and transport details are not part of domain entities.

## User

The authenticated person using the app.

- `id`: provider-independent Supabase Auth identity
- `selectedProgramId`: optional explicitly selected `WorkoutProgram`
- `goal`: optional `TrainingGoal` (`loseWeight`, `maintain`, `buildMuscle`)
- `level`: optional `TrainingLevel` (`beginner`, `intermediate`, `advanced`)
- `avatarPath`: optional stored object path; avatar upload is outside Profile v1
- `createdAt`, `updatedAt`: lifecycle timestamps

A user owns many workout sessions and can select one system program. There is no profile-completion state.
Email belongs to the authenticated account, not the synchronized profile.

`TargetSetsPolicy` resolves program overrides before applying the profile matrix:

| Goal / Level | Beginner | Intermediate | Advanced |
| --- | --- | --- | --- |
| loseWeight | 2 | 3 | 3 |
| maintain | 2 | 3 | 3 |
| buildMuscle | 3 | 4 | 4 |

A non-nil exercise `targetSets` overrides this matrix even for an incomplete profile.
With no override, missing either profile input yields 2. Both bundled programs delegate to the profile
by leaving every set override nil. The profile and catalog migrations were applied to the linked project on 2026-11-09.

The local training-preference write atomically updates the profile, every active-session exercise
recommendation, revision and outbox. Accepted remote profiles use the same atomic recommendation
application, without generating new outgoing work. A remote response cannot replace newer local
intent, and explicit failure recovery is version-checked. The profile sheet edits an independent draft,
with nullable selections and explicit Save/Cancel. Auth email is passed to the sheet for display and
is not duplicated in the profile table. Avatar v1 uses a placeholder; uploading remains out of scope.
The policy is never implemented in ViewDataMapper or Views. Workout screens consume resolved
recommendations and preserve recorded sets, manually added rows and entered drafts on refresh.

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
- optional `targetSets` (a program override), `targetReps`
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
- optional `exerciseTargets`: ordered `WorkoutExerciseTarget` snapshots for every assigned exercise,
  including exercises without logged sets

Each target contains the assignment ID, resolved `targetSets`, and the captured `programOverride`.
It is a recommendation, not a cap or the number of visible rows. Profile edits re-evaluate all targets
in an in-progress session against their captured overrides. Catalog edits do not rewrite the session.
Manual completion, completion with program selection, and expiration preserve these values.

Nil targets identify legacy sessions. Completed legacy history remains unknown; active legacy sessions
initialize their recommendations once when resolved. Actual ExerciseLog rows are never changed by
personalization. A completed count greater than the recommendation is valid.

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
