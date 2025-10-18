# Milestone 4 · View Layer Simplification

_Last updated: 2024-04-01 by Codex agent._

## Progress Snapshot
- Practice board now composes lightweight views: `PracticeBoardView` coordinates session state, while `LetterPracticeCanvas` renders declarative `PracticeRowView` instances backed by `PracticeRowViewModel`.
- Row logic (validation, warnings, celebrations, haptics) moved from SwiftUI state into the new `PracticeRowViewModel`, keeping views presentation-only.
- Canvas layout helpers and overlays were split into bite-sized files (`PracticeCanvasGeometry.swift`, `PracticeRowView.swift`, `PracticeRowOverlays.swift`), each comfortably below the 800–1,000 line guideline.
- Legacy controller row-event hooks were retired; `PracticeSessionController` focuses purely on repetition/letter progression data used for progress reporting.

## Next Actions
- Add integration/snapshot tests covering the refactored board and row views.
- Audit logging/diagnostics paths so future instrumentation flows through shared logging utilities instead of ad-hoc calls.
- Continue aligning the controller layer with row view models (e.g., expose structured events for telemetry) if needed for later milestones.
