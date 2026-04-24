# Architecture

This document describes the working architecture for Capsule Wishes. The app currently uses a feature-first SwiftUI structure with SwiftData persistence kept local-first.

## Architectural Goals

- Keep intimate user data local-first.
- Separate domain models from presentation state.
- Make the wish, journal, ritual, and opening flows testable.
- Allow future AI-assisted reflection without coupling the app to a network service.
- Keep the first MVP small enough to build, but structured enough to grow.

## Current App Structure

```text
CapsuleWishes/
├── App/
│   ├── CapsuleWishesApp.swift
│   └── ContentView.swift
├── Domain/
│   ├── Models/
│   │   ├── WishCapsule.swift
│   │   └── JournalEntry.swift
│   ├── Enums/
│   │   ├── CapsuleStatus.swift
│   │   └── JournalEntryType.swift
├── Data/
│   ├── Persistence/
│   │   └── SwiftDataContainer.swift
├── Features/
│   ├── Capsules/
│   ├── Journal/
├── DesignSystem/
│   ├── Backgrounds/
│   ├── Buttons/
│   ├── Components/
│   └── Palette/
└── Utilities/
    └── Color+Hex.swift
```

## Layers

### Presentation Layer

SwiftUI views live inside feature folders. Each feature owns its local UI state. For the current MVP, views use SwiftData queries directly to keep the implementation small and readable.

Examples:

- `CreateCapsuleView`
- `CapsuleDetailView`
- `CapsuleListView`
- `JournalView`

### Domain Layer

The domain layer describes the product language:

- a wish capsule;
- a journal entry;
- capsule and journal status/type enums.

Domain code should stay independent from SwiftUI unless a specific UI helper belongs elsewhere. Visual helpers live in `DesignSystem` or `Utilities`.

### Data Layer

The first implementation uses SwiftData for local persistence. `SwiftDataContainer` owns model container setup. Repositories can be introduced later when query logic, migrations, iCloud sync, notifications, or tests need a stable abstraction.

Cloud sync can be added later behind repository interfaces.

### Services Layer

Services handle system capabilities:

- local notifications;
- media import and storage;
- optional reflection or AI assistance;
- export and backup.

## Current Domain Model

### WishCapsule

```swift
@Model
final class WishCapsule {
    var id: UUID
    var title: String
    var intentionText: String
    var desiredFeeling: String
    var createdAt: Date
    var sealedAt: Date
    var openAt: Date
    var openedAt: Date?
    var statusRawValue: String
    var colorHex: String
    var symbol: String
}

enum CapsuleStatus: String, Codable, CaseIterable {
    case sealed
    case opened
    case fulfilled
    case unfolding
    case changed
    case released
}
```

### JournalEntry

```swift
@Model
final class JournalEntry {
    var id: UUID
    var capsuleID: UUID?
    var typeRawValue: String
    var text: String
    var createdAt: Date
}

enum JournalEntryType: String, Codable, CaseIterable, Identifiable {
    case sign
    case smallJoy
    case thought
    case dream
    case gratitude
    case step
}
```

## Future Domain Candidates

- `Ritual`
- `ActionStep`
- `WishTheme`
- `OpeningReflection`

These should be introduced when the product flow needs them, not as empty abstractions.

## Core Flows

- Create wish capsule.
- Add journal entry.
- Link journal entry to capsule.
- Show capsule opening readiness.
- Complete capsule opening with an outcome status.

## Persistence Strategy

For MVP:

- SwiftData models mirror the domain entities closely.
- Journals and wishes are stored on device.
- The model container is created in `Data/Persistence/SwiftDataContainer.swift`.

Future:

- local notification scheduling for capsule openings;
- media attachments stored locally and referenced by URL;
- encrypted iCloud sync;
- export/import;
- optional AI reflection with explicit consent;
- local-only mode as a first-class setting.

## Privacy Principles

The app stores highly personal material. Architecture should assume:

- local-first persistence;
- no analytics on journal text by default;
- explicit consent before any AI or cloud processing;
- ability to delete all personal data;
- clear data export story.

## State and Navigation

Current navigation model:

- `ContentView` owns the root tab shell.
- Feature views own local screen state with SwiftUI state wrappers.
- SwiftData queries currently provide persisted state directly to screens.

Future navigation additions:

- introduce `AppRouter` when onboarding, archive, and deep links make root navigation more complex;
- introduce feature view models when a screen gains non-trivial business logic;
- introduce `AppEnvironment` for long-lived settings and service dependencies.

Primary tabs or destinations:

- Capsules;
- Journal;
- Rituals;
- Archive.

## Testing Strategy

Unit tests:

- status transitions for capsules;
- opening date logic;
- journal entry creation;
- ritual completion;
- wish theme detection;
- repository behavior with in-memory SwiftData.

UI tests:

- onboarding completion;
- capsule creation;
- journal entry creation;
- opening flow.

Snapshot or visual checks should be considered for the capsule animation states once the UI matures.

## Future AI Boundary

AI can be useful for:

- summarizing recurring themes;
- suggesting reflection prompts;
- helping rephrase vague wishes;
- detecting emotional patterns from entries.

AI should not:

- diagnose the user;
- claim certainty about mental state;
- make supernatural guarantees;
- create dependency through authoritative predictions.

The app should frame AI suggestions as reflections, never as truth.
