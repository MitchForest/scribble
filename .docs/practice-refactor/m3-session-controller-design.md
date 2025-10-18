# Milestone 3 · Session Controller Design Notes

_Last updated: 2024-03-27 by Codex agent._

## Objectives
- Decouple row/repetition state from SwiftUI views.
- Introduce `PracticeSessionController` to orchestrate repetitions and letter progression.
- Lay groundwork for per-row view models and easier testing.

## Current Deliverables
- `Practice/Coordinators/PracticeSessionController.swift`
  - Holds `State` with repetitions, active repetition index, global letter index, lesson/settings metadata.
  - Emits state via `CurrentValueSubject` for Combine-friendly observation.
  - Handles core events (`start`, `letterCompleted`, `replay`, `clearAll`, `updateSettings`).
  - Implements row/letter progression: marks the current repetition complete, advances to the next repetition, and only increments the global letter index after the final repetition finishes.
  - Rebuilds repetition state on replay/clear by constructing fresh `RepetitionState` instances.
- `Practice/ViewModels/LessonPracticeViewModel.swift`
  - Wraps the controller for SwiftUI consumption.
  - Provides `handle(event:)` passthrough.
- `Practice/ViewModels/PracticeRowViewModel.swift`
  - Observes controller state for a specific repetition and exposes the active `RowState`.
  - Currently surfaces a read-only snapshot; event handling will be added once input wiring is defined.
- `Practice/Models/PracticeTimeline.swift`
  - Provides `PracticeTimeline` and `PracticeTimelineBuilder` to centralize text → template conversion.
  - `FreePracticeViewModel` now publishes a `timelineSnapshot` built via this helper (progress APIs remain temporarily for backwards compatibility).
- `Practice/Models/RepetitionState.swift`
  - Initializes per-letter phases (active letter preview vs. frozen) for each repetition.
  - `RowState` tracks preview progress, celebration flags, checkpoint counters, active samples, and ignore reasons.
  - Provides helpers to update the active letter and mark letters complete.
- `LessonPracticeBoard`
  - Instantiates the session controller/view model alongside the legacy free-practice view model.
  - Forwards lifecycle events (`start`, `replay`, `clearAll`, `letterCompleted`) to the controller and derives progress from controller state while legacy helpers remain for compatibility.
- `PracticeSessionControllerTests`
  - Verifies repetition-to-letter sequencing, clear/reset behaviour, and timeline update handling.

## Outstanding Tasks (Milestone 3)
- None (complete).

## Considerations
- Row-level event surfaces exist on `PracticeSessionController`, with UI wiring tracked under Milestone 4.
- Need to decide on dependency injection for `PracticeDataStore`, `HapticsManager`, etc.—likely via protocols passed into the controller.
- Repetition initialization currently rebuilds row state from templates; keep an eye on performance once template loading is profiled.
- `LessonPracticeViewModel` currently expects a fully constructed controller; during integration we may add convenience initializers that build the controller from `PracticeDataStore` and `FreePracticeViewModel`.
