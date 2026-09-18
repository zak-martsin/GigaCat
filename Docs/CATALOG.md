# GigaCat Catalog Feature

Catalog is the v1 entry point for choosing a default workout program. It replaces the broader Home
marketplace concept.

## Responsibilities

- Load active system-owned default programs from `DefaultProgramCatalogRepository`.
- Display one catalog with optional tag filtering.
- Present the profile sheet.
- Present program details, ordered workout days, and exercises.
- Select a program for the current user.
- Start or continue the matching workout.
- Explain and resolve a conflict before replacing an unrelated active session.

Catalog does not implement search, Library membership, custom programs, recommendation sections,
popularity, ratings, or direct persistence access.

## Data Flow

```text
CatalogView
    ↓
CatalogViewModel
    ├── catalog presentation/filtering
    └── ProgramDetail service
    ↓
User, DefaultProgramCatalog, WorkoutProgram, and Workout repositories
```

`DefaultProgramCatalogRepository` is intentionally independent of `CurrentUserContext`: it reads
shared rows whose `authorId` is nil. The current user is resolved separately through
`UserRepository` to determine `selectedProgramId` and to scope session mutations. This keeps account
switching safe in the shared SwiftData store without turning the default catalog into user-owned
data. Production and mock implementations both return only active programs whose `authorId` is
`nil`.

Program details remain a shared supporting feature because the mini player can also open them. Its
v1 actions are select, start, and continue; there is no save-to-Library action.

## Filtering

- `All` is the default filter.
- Available filters are derived from tags on currently visible programs.
- Selecting a filter narrows the single catalog list.
- Tag filtering is local and does not create another remote query.
- Search is not part of v1.

## Loading and Offline Behavior

The catalog ViewModel loads through the local repository only. System catalog synchronization runs
at the application boundary, applies a complete snapshot locally, and emits
`AppDataChange.programCatalog` through the shared dispatcher only when stored values changed. The
visible tab reloads after that invalidation; an identical foreground refresh remains a no-op.

The screen may show cached or bundled defaults while offline. The bundled production snapshot uses
the same stable identifiers and content as the Supabase seed; it is not sourced from preview mocks.
A failed refresh does not replace content with an error if valid local content already exists.

Changing the baseline catalog is an explicit workflow: add a Supabase content migration, update the
bundled JSON, compare the complete remote and bundled snapshots, then update the test fingerprint.

## Selection and Session Rules

- Selecting a program updates `User.selectedProgramId`.
- If there is no active session, the selected program can be started normally.
- If an active session belongs to the same program, the primary action continues it.
- If an active session belongs to another program, Catalog asks for confirmation before cancelling
  that session and switching programs.
- Selection invalidates all three feature caches and reloads the app-level mini player. Progress is
  included because resolving a selection conflict may also finish an active session.

## UI States

Catalog supports loading, content, empty, and failure states. The content state contains:

- a fixed app header with profile action
- horizontal tag filters
- one list/grid of default programs
- program detail sheet
- active-session conflict dialog

The empty state explains that no default programs are currently available; it does not offer a
custom-program builder.
