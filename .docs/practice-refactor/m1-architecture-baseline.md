# Milestone 1 · Architecture Baseline

_Last updated: 2024-03-27 by Codex agent._

## 1. Current Landscape Snapshot
- Source root: `scribble/`
- Total Swift files: 23 at root (see `find scribble -maxdepth 1 -name '*.swift'`)
- Notable large files (LOC via `wc -l`):

  | File | Lines | Notes |
  | --- | ---:| --- |
  | `LessonPracticeView.swift` | 1 932 | Practice board, PencilKit bridge, validation, layout |
  | `OnboardingFlowView.swift` | 966 | Entire onboarding flow with nested subviews |
  | `QuickDialogs.swift` | 792 | Reusable dialog system |
  | `Models.swift` | 590 | Mixed app-wide data models |
  | `ProfileCenterView.swift` | 500 | Profile hub UI |
  | `HomeView.swift` | 474 | Dashboard UI |
  | `PracticeDataStore.swift` | 435 | Practice progress persistence |

  Additional practice-relevant files:
  - `FreePracticeViewModel.swift` — 205 LOC (current lesson timeline logic)
  - `PracticeLessonLibrary.swift` — 232 LOC (lesson definitions)
  - `TraceCheckpointPlan.swift` — 226 LOC (validation checkpoints)
  - `PencilCanvasView.swift` — 166 LOC (UIKit bridge)

## 2. Practice Flow Dependency Notes

High-level data flow today:
1. `LessonPracticeView` (SwiftUI) owns:
   - `FreePracticeViewModel` (`@StateObject`) for letter timelines/progress.
   - Direct references to `PracticeDataStore` via `@EnvironmentObject`.
   - Inline state arrays representing each row (`RowState`).
2. `LessonPracticeView` composes:
   - `LetterPracticeCanvas` (within same file) – handles per-row drawing, preview, validation, UI overlays.
   - `PracticeRowGuides`, `PencilCanvasView`, `WordGuidesOverlay`, `PreviewStrokeOverlay`, `FeedbackBubbleView` (all nested in same file).
3. Validation stack:
   - `CheckpointValidator` (elsewhere) + `TraceCheckpointPlan` (precomputed plan) feed into `LessonPracticeView`’s inline logic.
4. Progress persistence:
   - `PracticeDataStore` updates streaks and stats based on callbacks in `LessonPracticeView`.

Identified coupling pain points:
- Single `FreePracticeViewModel` instance shared across all repetitions; row-specific state inferred from view-level arrays.
- UI overlays consume global `currentLetterIndex`, causing future rows to show as “completed”.
- Logging, animation, validation, and state transitions co-located in one monolithic file.
- Global `PracticeDataStore` invoked directly inside UI logic rather than via coordinator/service abstraction.

## 3. Proposed Target Structure (MVVM + Coordinators)

```
scribble/
├─ Practice/
│  ├─ Models/
│  │  ├─ PracticeLesson.swift
│  │  ├─ LetterTimelineItem.swift
│  │  ├─ StrokeTemplates/…
│  ├─ ViewModels/
│  │  ├─ LessonPracticeViewModel.swift
│  │  ├─ PracticeSessionController.swift (coordinator)
│  │  ├─ RepetitionState.swift / RowState.swift
│  ├─ Views/
│  │  ├─ LessonPracticeView.swift (composition only)
│  │  ├─ PracticeBoardView.swift
│  │  ├─ PracticeRowView.swift
│  │  ├─ Components/
│  │  │  ├─ GuidesOverlay.swift
│  │  │  ├─ PreviewOverlay.swift
│  ├─ Services/
│  │  ├─ PracticeDataStore.swift (refined)
│  │  ├─ Haptics/
│  └─ Tests/
│     ├─ ViewModels/
│     ├─ Coordinators/
│     ├─ Snapshot/
├─ Features/
│  ├─ Home/
│  ├─ Onboarding/
│  ├─ Profile/
│  ├─ Settings/
├─ Shared/
│  ├─ Utilities/
│  │  ├─ Logging/
│  │  ├─ Geometry/
│  ├─ Services/
│  │  ├─ Persistence/
│  ├─ UI/
│     ├─ Components/
├─ .docs/
│  ├─ refactor-plan.md
│  └─ practice-refactor/
│     ├─ m1-architecture-baseline.md
```

Implementation notes:
- `PracticeDataStore` likely straddles Practice/Shared; consider moving caching logic into `Shared/Services/Persistence` with practice-specific adapter.
- `Models.swift` should be split and relocated (Practice models vs shared app models).
- Introduce protocols for services (`PracticeProgressStore`, `HapticsProviding`) to decouple from UI.
- Favor Swift package or Xcode group separation later (post-milestone 5).

## 4. Outstanding Items
- Team review of proposed structure (schedule cross-functional discussion; capture decisions back in plan).
- Decide on DI mechanism (Environment vs dedicated container) before Milestone 3.

## 5. Next Steps (Milestone 2 Preview)
- Begin moving practice-domain models into `Practice/Models`.
- Add README or inline docstrings to relocated files summarizing their responsibility.
- Track any cross-feature imports that need abstraction.
