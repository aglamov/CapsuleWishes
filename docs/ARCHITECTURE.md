# Architecture

This document describes the intended architecture for Capsule Wishes. The current repository is still in the SwiftUI scaffold stage, so this is a target structure for the first production-quality implementation.

## Architectural Goals

- Keep intimate user data local-first.
- Separate domain models from presentation state.
- Make the wish, journal, ritual, and opening flows testable.
- Allow future AI-assisted reflection without coupling the app to a network service.
- Keep the first MVP small enough to build, but structured enough to grow.

## Proposed App Structure

```text
CapsuleWishes/
├── App/
│   ├── CapsuleWishesApp.swift
│   ├── AppRouter.swift
│   └── AppEnvironment.swift
├── Domain/
│   ├── Models/
│   │   ├── WishCapsule.swift
│   │   ├── JournalEntry.swift
│   │   ├── Ritual.swift
│   │   ├── ActionStep.swift
│   │   └── WishTheme.swift
│   ├── Enums/
│   └── UseCases/
├── Data/
│   ├── Persistence/
│   ├── Repositories/
│   └── Migrations/
├── Features/
│   ├── Onboarding/
│   ├── CapsuleList/
│   ├── CapsuleDetail/
│   ├── CreateCapsule/
│   ├── Journal/
│   ├── Rituals/
│   └── Opening/
├── DesignSystem/
│   ├── Colors.swift
│   ├── Typography.swift
│   ├── Components/
│   └── Motion/
└── Services/
    ├── NotificationService.swift
    ├── ReflectionService.swift
    └── MediaStorageService.swift
```

## Layers

### Presentation Layer

SwiftUI views and view models live inside feature folders. Each feature owns its local UI state and delegates persistence or business logic to use cases and repositories.

Examples:

- `CreateCapsuleView`
- `CreateCapsuleViewModel`
- `CapsuleDetailView`
- `JournalEntryEditorView`
- `OpeningCeremonyView`

### Domain Layer

The domain layer describes the product language:

- a wish capsule;
- a ritual;
- a journal entry;
- a small action;
- a wish theme;
- a capsule opening reflection.

Domain code should be independent from SwiftUI.

### Data Layer

The first implementation should use SwiftData for local persistence. Repositories wrap SwiftData access so views are not coupled directly to storage details.

Cloud sync can be added later behind repository interfaces.

### Services Layer

Services handle system capabilities:

- local notifications;
- media import and storage;
- optional reflection or AI assistance;
- export and backup.

## Domain Model

### WishCapsule

```swift
enum CapsuleStatus: String, Codable {
    case draft
    case sealed
    case active
    case readyToOpen
    case opened
    case fulfilled
    case changed
    case released
}

struct WishCapsule {
    let id: UUID
    var title: String
    var intentionText: String
    var desiredOutcome: String?
    var feeling: String?
    var createdAt: Date
    var sealedAt: Date?
    var openAt: Date?
    var openedAt: Date?
    var status: CapsuleStatus
    var colorToken: String
    var symbol: String?
    var energyScore: Double
}
```

### JournalEntry

```swift
enum JournalEntryType: String, Codable {
    case sign
    case smallJoy
    case thought
    case dream
    case gratitude
    case action
    case reflection
}

struct JournalEntry {
    let id: UUID
    var capsuleId: UUID?
    var type: JournalEntryType
    var text: String
    var moodBefore: Int?
    var moodAfter: Int?
    var emotionTags: [String]
    var bodyFeeling: String?
    var significanceScore: Double?
    var createdAt: Date
}
```

### Ritual

```swift
enum RitualType: String, Codable {
    case visualization
    case writing
    case action
    case voice
    case silence
    case symbol
    case time
    case gratitude
    case release
}

struct Ritual {
    let id: UUID
    var title: String
    var type: RitualType
    var description: String
    var durationMinutes: Int
    var difficulty: Int
    var tags: [String]
}
```

### ActionStep

```swift
enum ActionStepStatus: String, Codable {
    case planned
    case completed
    case skipped
}

struct ActionStep {
    let id: UUID
    var capsuleId: UUID
    var text: String
    var status: ActionStepStatus
    var createdAt: Date
    var completedAt: Date?
}
```

### WishTheme

```swift
struct WishTheme {
    let id: UUID
    var name: String
    var confidenceScore: Double
    var sourceEntryCount: Int
    var lastSeenAt: Date
}
```

## Core Use Cases

- `CreateWishCapsule`
- `SealWishCapsule`
- `AddJournalEntry`
- `SuggestRitual`
- `CompleteRitual`
- `AddActionStep`
- `MarkActionStepComplete`
- `PrepareCapsuleOpening`
- `CompleteCapsuleOpening`
- `DetectWishThemes`

## Persistence Strategy

For MVP:

- SwiftData models mirror the domain entities closely.
- Journals and wishes are stored on device.
- Media attachments are stored locally and referenced by URL.
- Notifications use local notification scheduling.

Future:

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

Recommended navigation model:

- `AppRouter` owns root navigation state.
- Feature view models own local screen state.
- Long-lived app settings live in `AppEnvironment`.

Primary tabs or destinations:

- Capsules;
- Journal;
- Rituals;
- Archive;
- Profile / Path.

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
