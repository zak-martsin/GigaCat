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

Program titles are intentionally omitted. A session is identified by its workout day title.

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

The main and calendar screens use separate ViewModels because their data and interactions
are different. Shared calculations remain in services rather than being duplicated.

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
- unit tests for history loading, calendar boundaries, and ViewData mapping

Not implemented yet:

- `ProgressViewModel`
- `ProgressCalendarViewModel`
- compact week UI
- full calendar UI
- cross-feature invalidation

## 5. Deferred Progress Areas

- weekly workout target
- body weight entries and charts
- exercise performance trends and personal records
- body measurements
- progress photos
- HealthKit integration
- step tracking
- AI progress insights
