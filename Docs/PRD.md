PRD — GigaCat

Version: 1.0
Status: Draft
Platform: iOS (iPhone)
Author: Solo Developer
Project Name: GigaCat

⸻

1. Product Overview

Vision

GigaCat is an offline-first fitness tracking application for iPhone that helps users track workouts, monitor progress, and receive AI-powered insights about their training and nutrition.

The application combines workout logging, progress tracking, cloud synchronization, and AI-powered analysis into a single experience.

The goal is not to replace professional trainers, doctors, or nutritionists.

The AI component acts as:

* progress analyst
* nutrition assistant
* fitness insights assistant

The AI must never provide medical advice, injury treatment recommendations, or personalized healthcare guidance.

⸻

2. Product Goals

Business Goals

* Create a production-quality portfolio project.
* Demonstrate modern iOS architecture.
* Demonstrate cloud synchronization.
* Demonstrate AI integration.
* Demonstrate offline-first design.

User Goals

Users should be able to:

* follow training programs
* log workouts
* track body weight
* review training history
* receive AI-generated insights
* receive nutrition assistance
* continue using the app without internet access

⸻

3. Target Audience

Primary audience:

People who already train regularly and want a structured way to track training progress.

User characteristics:

* trains at least 2 times per week
* tracks personal performance
* wants historical data
* wants simple AI assistance
* does not want multiple separate apps

⸻

4. MVP Scope

Included

Authentication

* Sign in with Apple
* persistent user session

Workout Programs

* predefined programs
* program details
* workout day details
* exercise list

Workout Tracking

* log sets
* log repetitions
* log weight
* save workout history
* view previous exercise performance

Progress Tracking

* body weight tracking
* workout statistics
* charts
* historical trends

AI Features

* AI Progress Insights
* AI Nutrition Assistant

Cloud Features

* Supabase Authentication
* Cloud Sync
* User-specific data

Offline Features

* local storage
* offline workout logging
* background synchronization

⸻

5. Out Of Scope (MVP)

The following features must not be implemented in MVP:

* custom workout builder
* trainer/client platform
* social features
* subscriptions
* barcode scanner
* food database
* meal planning
* exercise animations
* Apple Watch support
* iPad support

⸻

6. Functional Requirements

FR-1 Authentication

Description

Users must authenticate using Sign in with Apple.

Acceptance Criteria

* User can sign in with Apple.
* User remains authenticated after app restart.
* User can sign out.
* User data is associated with a unique account.

⸻

FR-2 Workout Programs

Description

Users can browse predefined workout programs.

Acceptance Criteria

* Programs are displayed in a list.
* User can open a program.
* User can view workout days.
* User can view exercises inside workout days.

⸻

FR-3 Workout Logging

Description

Users can record training sessions.

Acceptance Criteria

* User can enter weight.
* User can enter repetitions.
* User can add multiple sets.
* Data is stored locally.
* Data is synchronized later if offline.

⸻

FR-4 Workout History

Acceptance Criteria

* User can view completed workouts.
* User can review previous exercise performance.
* Historical data persists across devices after sync.

⸻

FR-5 Body Weight Tracking

Acceptance Criteria

* User can add body weight entries.
* User can edit entries.
* User can delete entries.
* Historical entries are displayed chronologically.

⸻

FR-6 Progress Charts

Acceptance Criteria

* User can view body weight trends.
* User can view workout frequency trends.
* Charts update automatically when data changes.

⸻

FR-7 AI Progress Insights

Description

AI analyzes training and weight history.

Example Outputs

* consistency summaries
* progress summaries
* trend detection
* workload observations

Restrictions

AI must not:

* diagnose injuries
* prescribe treatment
* provide medical recommendations

Acceptance Criteria

* User can request analysis.
* Historical data is included in context.
* AI returns structured insight responses.

⸻

FR-8 AI Nutrition Assistant

Description

User can ask nutrition-related questions.

Example

Input:

“2 eggs, oatmeal and banana”

Output:

Approximate:

* calories
* protein
* fats
* carbohydrates

Restrictions

AI must provide estimates only.

Acceptance Criteria

* User can submit text.
* AI returns estimated nutrition information.
* Responses contain disclaimer about estimation.

⸻

7. Phase 2 Features

Food Photo Analysis

Using OpenAI Vision:

* image upload
* calorie estimation
* macro estimation

Additional AI Features

* weekly reports
* monthly reports
* workout summaries

Workout Builder

* create custom programs
* edit programs
* duplicate programs

⸻

8. Technical Architecture

Architecture Style

Offline-first Modular Architecture.

Core Layer

Core modules:

* CoreNetworking
* CoreStorage
* CoreAuthentication
* CoreAI
* CoreAnalytics
* CoreDesignSystem
* CoreShared

Feature Layer

Feature modules:

* FeatureAuth
* FeatureProfile
* FeaturePrograms
* FeatureWorkout
* FeatureProgress
* FeatureNutrition
* FeatureAIInsights

⸻

9. Technology Stack

Client

* Swift
* SwiftUI
* SwiftData
* Charts
* Observation
* URLSession
* PhotosPicker

Backend

* Supabase

Services:

* Authentication
* PostgreSQL
* Storage

AI

* OpenAI API

⸻

10. Data Strategy

Local Source Of Truth

SwiftData is the primary local database.

Users must be able to continue using the app without internet access.

Sync Strategy

Local Change

↓

Sync Queue

↓

Repository Layer

↓

Supabase

Requirements

* retry failed uploads
* support background synchronization
* prevent duplicate records

⸻

11. Conceptual Data Model

User

* id
* appleUserId
* createdAt
* updatedAt

WorkoutProgram

* id
* title
* description

WorkoutDay

* id
* programId
* title
* orderIndex

Exercise

* id
* name
* muscleGroup

WorkoutSession

* id
* userId
* workoutDayId
* completedAt

ExerciseLog

* id
* sessionId
* workoutDayExerciseId
* weight
* reps
* setNumber

WeightEntry

* id
* userId
* value
* date

AIInsight

* id
* userId
* content
* createdAt

⸻

12. Security Requirements

* Sign in with Apple only
* secure token storage
* Keychain for sensitive credentials
* HTTPS only
* no API keys in client code
* row level security in Supabase

⸻

13. Non-Functional Requirements

Performance

* app launch under 2 seconds
* workout logging must feel instant

Reliability

* offline functionality required
* sync must recover after network loss

Scalability

* architecture must support additional modules
* architecture must support future premium features

⸻

14. Development Milestones

Milestone 1

Foundation

* project setup
* modular architecture
* navigation
* SwiftData
* dependency injection

Milestone 2

Authentication

* Sign in with Apple
* Supabase Auth

Milestone 3

Workout System

* programs
* exercises
* workout logging
* history

Milestone 4

Progress Tracking

* weight tracking
* charts
* statistics

Milestone 5

Cloud Sync

* repositories
* sync engine
* conflict handling

Milestone 6

AI Features

* OpenAI integration
* progress insights
* nutrition assistant

Milestone 7

Polish

* testing
* bug fixes
* optimization
* release preparation

⸻

15. Definition of Done

The MVP is complete when:

* authentication works
* workout tracking works
* progress tracking works
* cloud synchronization works
* offline mode works
* AI insights work
* AI nutrition assistant works
* architecture follows modular boundaries
* application is stable for daily use
