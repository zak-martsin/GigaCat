# GigaCat Architecture

GigaCat is an offline-first SwiftUI application using MVVM, repository boundaries, SwiftData,
Supabase, and dependency injection. This document describes the v1 architecture that the code is
required to follow.

## Layer Boundaries

```text
SwiftUI Views
    ↓
@Observable ViewModels
    ↓
Focused feature services and mappers
    ↓
Domain repository protocols
    ↓
SwiftData repositories          Supabase adapters
local source of truth           auth, catalog download, profile sync
```

- Views render state and forward user actions.
- Views never read SwiftData or call Supabase.
- ViewModels depend on repositories or focused services, not persistence implementations.
- Feature services coordinate multi-repository reads and mutations.
- Data-layer mappers isolate persistence and transport models from domain models.
- `AppCompositionRoot` and `AppContainer` own dependency construction.

## v1 Feature Topology

```text
AuthenticationRoot
    ↓ authenticated
AppShell
    ├── Catalog
    │   ├── Profile sheet
    │   └── Program detail sheet
    ├── Workout
    │   └── Exercise logger
    ├── Progress
    │   └── Full calendar
    └── App-level mini player
```

Library, Nutrition, custom program creation, catalog search, and marketplace ranking do not belong
to the v1 dependency graph.

## Local Source of Truth

SwiftData is the only persistence source read by feature repositories. Workout mutations are saved
locally first and never wait for network availability.

The local model separates:

- catalog structure: program, day, planned exercise, reusable exercise
- user state: selected program
- workout history: session and exercise log
- sync infrastructure: outbox operations

The production app uses one shared SwiftData store on the device. `CurrentUserContext` identifies
the authenticated account inside that store; user-owned reads and writes are scoped by its stable
`userId`. System catalog rows are shared reference data rather than user-owned data, so default
catalog queries do not depend on the current user.

The v1 SwiftData schema contains only active catalog, profile, workout-history, and sync models.
Legacy Library membership and marketplace metadata were removed before release. Existing development
installations created with the old schema must reset their local app data; future post-release schema
changes require an explicit versioned migration plan.

## System Catalog Flow

System programs have no author and are remotely maintained. The catalog refresh flow is:

```text
App becomes usable or active
    ↓
SystemCatalogSyncService downloads one consistent snapshot
    ↓
LocalSystemCatalogStore applies it transactionally to SwiftData
    ↓
AppDataChange.programCatalog is emitted only when local values changed
    ↓
affected ViewModels and the mini player are invalidated; the visible tab reloads
```

The UI always reloads through local repositories; it never renders Supabase DTOs. Failed downloads
leave the last valid local snapshot untouched. A bundled default snapshot supplies first-launch
offline content. An empty or malformed remote snapshot is not allowed to replace usable local data.

Program artwork follows the same local-first boundary. The catalog stores only versioned artwork
metadata in SwiftData. `ProgramArtworkService` resolves that metadata through a device-local file
cache and downloads a missing revision from Supabase Storage. Feature ViewModels receive the local
file URL; Views never call Supabase and keep the shared placeholder when artwork is unavailable.

The bundled snapshot is production data owned by `Data/Local/SwitData/Bootstrap`; production
composition must never depend on `PreviewSupport` or `MockSeedData`. Its stable identifiers and
catalog content mirror the Supabase seed so the first successful refresh updates the same records
instead of replacing preview-only programs. `MockSeedData` may add users, sessions, and logs for
previews and tests, but it consumes the production catalog rather than defining another one.
Bootstrap also backfills missing artwork metadata for those stable bundled programs so development
installations created before artwork support do not need to erase user-owned local data.
This targeted repair is not a replacement for versioned migrations of future released schemas.

Fixture construction is deterministic and fail-fast: callers may supply a fixed date, and invalid
domain values throw instead of being silently removed with `try?`.

`DefaultProgramCatalogRepository` returns only active system programs. `WorkoutProgramRepository`
provides stable identifier and structure lookups, including inactive rows referenced by completed
sessions and exercise logs. It does not duplicate the catalog-list query.

Normal authenticated users receive read-only catalog access through Supabase RLS. Catalog writes are
an administrative migration/content operation, not an app-client capability.

The bundled catalog and every repository implementation share the same visibility contract: the
default catalog contains only active programs whose `authorId` is `nil`. Intentional baseline
changes require a catalog migration, an updated bundled snapshot, a remote comparison, and an
explicit update of the full-snapshot test fingerprint.

## User Sync

Supabase Auth supplies the provider-independent user identifier. `CurrentUserContext` exposes only
that domain ID to repositories. `UserRepository.currentUser()` resolves the matching local profile;
workout sessions, exercise logs, selected-program changes, and outbox operations must remain scoped
to that user. Switching accounts changes the current ID without changing the shared system catalog.
Every session mutation validates that the requested session belongs to the supplied user before any
session, log, profile, revision, or outbox state changes.

Profile and selected-program writes follow the existing offline-first outbox flow:

1. Save the mutation to SwiftData.
2. Queue its outbox operation in the same local transaction.
3. Update the UI immediately.
4. Push pending operations when connectivity and authentication allow it.

Profile conflict resolution in v1 follows the presence of outgoing work rather than comparing
device and server clocks. While a profile operation is pending or syncing, its local value wins and
remote profile pulls must not overwrite it. After the operation succeeds, the Supabase response is
the canonical value applied to SwiftData. When no outgoing profile operation exists, the remote
profile wins and is saved locally only when its value differs. `updatedAt` remains metadata and is
not a conflict-resolution authority. A profile pull records the local revision before its network
request and applies the response only if that revision and the local profile remain unchanged and
no unresolved profile operation exists at the moment of the local write.

`AppShell` owns the single active-scene signal. `AppContainer` handles that signal as one ordered
foreground refresh: download the system catalog, clear an unavailable current selection after a
successful catalog refresh, await the outbox push, then pull the profile when the outbox permits it.
Only completed local changes are routed through `AppDataChangeDispatcher`; Views do not coordinate
these storage operations.

Account transitions are serialized at the authentication boundary. Signing out first awaits sync
deactivation before removing the Supabase session and current local user ID. Authenticating an
account first stops any previous worker, installs the new current user ID, bootstraps that profile,
then activates sync for that ID. The authenticated application surface is shown only after this
sequence completes. Because every outbox operation owns a user ID, one account's work cannot be
claimed by another account's worker pass.

Program availability is enforced on both sides of the offline boundary. PostgreSQL rejects profile
writes that reference an inactive program and clears profile selections when a system program is
deactivated. After a catalog refresh, the app mirrors that rule locally: a missing or inactive
selection is cleared in SwiftData and queued through the normal profile outbox.

Outbox failures are classified at the Supabase boundary. Network timeouts, rate limits, and 5xx server
errors stay pending with backoff and are retried automatically; an invalid session pauses the worker
until authentication activates it again. Neither case blocks local work or requires a user-facing
retry action. Malformed payloads and rejected database writes become terminal failures. Feature code
sees only `ProfileSyncStatus`, never SwiftData outbox entities.

The v1 recovery flow is intentionally local-first. If a successful catalog refresh confirms that the
selected program is unavailable, the app clears the current selection through the normal local
mutation/outbox path and briefly explains that the program is no longer available. Historical workout
data remains readable. If a terminal profile failure cannot be explained by the refreshed catalog,
the app preserves the local selection, blocks remote profile pulls from overwriting it, and shows a
non-blocking account-sync status. The message must not claim the choice is available on other devices
or expose raw server errors. A new selection replaces the older failed operation.

The recovery service can retry or discard a failed operation, but v1 does not expose outbox-management
buttons as the default user flow. Discard, if used by a later support or product flow, must pull the
server profile before removing the failed operation so an offline attempt cannot destroy the only
durable local intent.

Workout sessions and logs are deliberately local-only in v1.

Supabase trigger functions that require `SECURITY DEFINER` are internal database infrastructure.
They must not grant `EXECUTE` to Data API roles such as `anon`, `authenticated`, or `service_role`.
Privilege migrations must be verified against the remote ACL and Supabase security advisors.

## Deterministic UI Tests

Debug builds accept the internal `--ui-testing` launch argument. That mode bypasses Authentication,
uses the bundled catalog with an in-memory mock repository graph, and installs no-op synchronizers.
It must never read production SwiftData, call Supabase, or be available in Release builds.

Functional UI tests always use this mode so their account, selected program, sessions, and logs do
not depend on simulator state or network availability.

## Cache Invalidation

Mutations emit domain-level `AppDataChange` values through one dispatcher. Features never call other
feature ViewModels directly.

`DataLoadTracker` uses revisions so an invalidation received during an in-flight load remains pending;
feature loaders consume that pending revision before their current load finishes. Catalog refresh must
use the same dispatcher; a parallel revision counter in Authentication or a View is not permitted.
Reapplying an identical server snapshot is a no-op and must not disturb an active Workout screen.

Expected v1 invalidation:

| Change | Catalog | Workout | Progress | Mini player |
| --- | --- | --- | --- | --- |
| selected program | yes | yes | yes | immediate reload |
| workout session/log | yes | yes | yes | immediate reload |
| system catalog | yes | yes | yes | immediate reload |

Account changes are lifecycle boundaries, not data invalidations: Authentication recreates the app
shell for the newly resolved `CurrentUserContext`, so `AppDataChange` has no unused current-user case.

## Historical Integrity

Remote catalog entries may be deactivated but workout history must remain readable. Catalog sync may
hide inactive content from discovery while preserving referenced local rows. Repositories therefore
need separate semantics for active catalog lists and stable identifier-based historical lookups.

Destructive catalog replacement is not acceptable when it can orphan `WorkoutSession` or
`ExerciseLog` records.

## Dependency Rules

- Prefer protocols for repositories and external services.
- Keep concrete SwiftData and Supabase types in `Data`.
- Keep domain entities framework-light.
- Keep ViewModels focused; move multi-repository workflows to services.
- Do not add a use-case abstraction unless it clarifies reusable business logic.
- Use the internal DesignSystem instead of feature-local spacing, colors, and radii.
- Add tests at repository, service, mapper, and ViewModel boundaries where behavior changes.
