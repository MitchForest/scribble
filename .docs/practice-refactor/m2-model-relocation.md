# Milestone 2 · Practice Models Relocation

_Last updated: 2024-04-01 by Codex agent._

## Summary
- Created `scribble/Practice/Models` directory to host practice-domain data structures.
- Relocated the following files without code changes:
  - `PracticeLessonLibrary.swift`
  - `HandwritingTemplate.swift`
  - `HandwritingManifest.swift`
  - `StrokeTraceTemplate.swift`
  - `TraceCheckpointPlan.swift`
  - `CanvasStrokeSample.swift`
- Xcode project uses a synchronized root group, so no project file edits were necessary.
- No import updates required; all references resolve through the existing module scope.

## Observations / Follow-ups
- These models still rely on global types defined in `Models.swift` (e.g., `PracticeDifficulty`, `StrokeSizePreference`). Breaking that file apart is a future milestone task.
- 2024-04-01: `xcodebuild` succeeded against the iPad Pro (11-inch, M4) simulator, confirming the relocated models compile cleanly.
- Consider creating subfolders (e.g., `StrokeTemplates`, `LessonCatalog`) once additional files move over.

## Next Steps
- [x] Trigger a clean build or run the test suite to verify relocation didn’t introduce path issues.
- [ ] Identify any remaining practice-domain models still living in shared root (e.g., structs inside `FreePracticeViewModel.swift`) and queue them for later extraction if applicable.
