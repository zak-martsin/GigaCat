# GigaCat Progress Feature

This document describes the agreed scope and current foundation of the `Progress` feature.

The first implementation focuses on completed workout history. Body weight, training goals,
measurements, photos, HealthKit, and AI insights remain later iterations.

## 1. First History Flow

The main Progress screen will show a compact seven-day week strip:

- previous-week and next-week actions
- completed-workout markers
- a full-calendar action
- navigation to the full calendar with the tapped date selected

The full calendar screen will show:

- one month at a time
- completed-workout markers
- one selected date
- completed sessions for that date
- exercises grouped within each session
- set number, weight, and repetitions for each log

A session is identified by its program title and one-based workout day order.

## 2. History Rules

- Only completed `WorkoutSession` records appear in Progress history.
- A workout belongs to the calendar day containing its `startedAt` value.
- Sessions within one day are ordered by `startedAt`.
- Exercises follow `WorkoutDayExercise.orderIndex`.
- Exercises without performed logs are omitted.
- Sets follow `ExerciseLog.setNumber`.
- The full calendar opens on the date selected in the compact week strip.

## 3. Architecture

```text
ProgressView / ProgressCalendarView
    ↓
ProgressViewModel / ProgressCalendarViewModel
    ↓
ProgressHistoryService + ProgressDateService
    ↓
Repository protocols
    ↓
Shared local source of truth
```

`ProgressHistoryService` loads completed sessions and resolves the workout day, planned
exercise, reusable exercise, and log relationships through existing repositories.

`ProgressDateService` performs calendar calculations shared by the compact week and full
calendar. It does not access persistence or prepare display strings.

`ProgressViewDataMapper` converts the resolved history and calendar periods into
feature-specific ViewData. ViewData remains passive and contains only values needed by Views.

`ProgressViewModel` owns the compact-week presentation state. It loads history through
`ProgressHistoryServicing`, asks `ProgressDateServicing` for week boundaries, delegates
display formatting to `ProgressViewDataMapping`, and creates `ProgressCalendarViewModel` from
its loaded history. Tapping a week day opens the calendar on that date; the general calendar
action opens the current month without a selected date.

`ProgressCalendarViewModel` receives the loaded history context and owns month paging, optional
day selection, the month grid presentation, and the sessions shown for the selected day.
Changing months clears the selection and daily session list until the user selects a visible day.

The main and calendar screens use separate ViewModels because their data and interactions
are different. Shared calculations remain in services rather than being duplicated.
`AppShellView` builds Progress from shared repositories, while `AppDataChangeCoordinator`
invalidates its cached history after workout data changes.

## 4. Current Foundation

Implemented:

- `ProgressHistoryContext`
- completed-session history loading
- exercise and set ordering
- week and month calculations
- session grouping by local calendar day
- ViewData contracts for the weekly strip, month grid, sessions, exercises, and sets
- `ProgressViewDataMapper`
- localized week, month, weekday, time, weight, and repetition presentation
- `ProgressViewModel` loading, empty, and failure states
- compact-week paging UI with a future-week boundary
- `ProgressCalendarViewModel`
- calendar opening on a targeted date
- current-month opening without a selected date
- month paging UI with a current-month boundary
- optional day selection cleared when the displayed month changes
- selected-day exercise and set-log presentation
- program title and one-based workout day order for each session
- history invalidation after a completed workout through `AppDataChangeCoordinator`
- unit tests for history loading, calendar boundaries, ViewData mapping, and both ViewModels

Not implemented yet:

- weekly workout target
- lifted-volume summaries
- workout streaks

## 5. Deferred Progress Areas

- weekly workout target
- lifted-volume summaries
- workout streaks
- body weight entries and charts
- exercise performance trends and personal records
- body measurements
- progress photos
- HealthKit integration
- step tracking
- AI progress insights
