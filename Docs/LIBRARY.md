# GigaCat Library Feature

This document describes the first MVP implementation of the `Library` feature.

## 1. Purpose

`Library` is responsible for:

- showing programs a user explicitly saved from the shared catalog
- opening the shared program-detail sheet
- selecting a saved program and resolving an active-session conflict
- removing a saved program with a native swipe action
- exposing the future custom-program action in the shared app header

`Library` is not responsible for:

- automatically saving the selected workout program
- deleting programs from the shared catalog
- changing `User.selectedProgramId`
- building custom workout programs in MVP

## 2. Architecture

```text
LibraryView
    ↓
LibraryViewModel
    ├── WorkoutProgramLibraryRepository
    └── ProgramDetailService
            ↓
        Shared repositories
    ↓
Shared local data source
```

The Library list does not need a mapper: it renders only the program title and a shared artwork
placeholder. Opening a row delegates detail composition and actions to the reusable
`ProgramDetailService`. Library does not import or call Home types.

`ProgramDetailSheet`, `ProgramDetailService`, and their shared presentation models live under
`Features/ProgramDetail`. Home and Library each own their presentation state and inject closures
into the same sheet.

Successful Library mutations emit `AppDataChange` values. The application coordinator invalidates
affected tab caches and reloads the global mini player immediately when selection or session state
changes. Library never references Home, Workout, or MiniPlayer ViewModels directly.

## 3. Saved Program Relationship

`SavedWorkoutProgram` represents a user's explicit decision to add a catalog program to their
library. It contains:

- a stable identifier
- the user identifier
- the catalog program identifier
- the date it was saved

Program selection and library membership are independent:

- `User.selectedProgramId` identifies the program currently used by workout flows.
- `SavedWorkoutProgram` identifies a program shown in Library.

Removing a program from Library removes only this relationship. It does not delete the catalog
program or change the selected program.

## 4. Current UI

The screen uses:

- `AppHeaderView` with the existing add and profile actions
- a native `List`
- a compact horizontal row with a color artwork placeholder and program title
- the same program-detail sheet and session conflict dialog used from Home
- a trailing destructive swipe action with full-swipe support
- loading, content, empty, and failure states

The header add action remains a placeholder for custom-program creation. Catalog programs can now
be saved from the shared detail sheet opened on Home or from the global mini player.
Unsaved programs show a circular add button over the artwork. The button is omitted when the
repository reports that the program already belongs to the current user's Library.

## 5. Current Persistence

Library currently uses `MockWorkoutProgramLibraryRepository` backed by the shared
`MockDataStore`. One existing catalog program is saved for the current mock user so the screen
can be exercised before catalog-saving UI is connected.
