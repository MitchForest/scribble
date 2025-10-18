# Scribble Refactor Plan

## Context
- Practice lesson flow currently couples all rows to a single `FreePracticeViewModel`. Multi-row behavior (three repetitions) surfaced latent bugs and reveals the need for clearer layering.
- `LessonPracticeView.swift` exceeds 1,000 lines and mixes layout, state orchestration, PencilKit bridging, preview timing, validation feedback, and logging.
- Lack of modular structure (models, view models, coordinators, views, utilities) increases regression risk and slows debugging.
- Goal: move toward explicit MVVM (plus coordinators/services) with per-row state isolation, improved testability, and maintainable module boundaries.

## Guiding Principles
- Separate data models, state machines/coordinators, and SwiftUI views.
- Keep files focused and coherent (targeting 800–1,000 lines at most) by extracting subviews and utilities when it improves clarity.
- Ensure each module has automated tests before refactor completion.
- Maintain incremental delivery: migrate feature by feature with compatibility shims if required.

## Milestones Overview
1. **Audit & Architecture Baseline**
2. **Practice Module Restructure**
3. **ViewModel & Coordinator Introduction**
4. **View Layer Simplification**
5. **Shared Utilities & Services Cleanup**
6. **Testing Infrastructure**
7. _(removed per updated scope)_

---

### Milestone 1 — Audit & Architecture Baseline

**Goal:** Understand current structure, surface hot spots, and agree on target module layout.

- [x] Inventory existing directories/files (especially >500 LOC) and categorize by responsibility.
- [x] Document current dependencies between practice-related files (`LessonPracticeView`, `FreePracticeViewModel`, `CheckpointValidator`, etc.).
- [x] Propose target folder/module tree aligned with MVVM (e.g., `Practice/Models`, `Practice/ViewModels`, `Practice/Views`, `Shared/Utilities`, `Shared/Services`).
- [x] Review plan with team; capture decisions (DI approach, logging strategy, coordinator pattern) in shared notes. _(Settled on coordinator-first orchestration, shared logging utilities, and an 800–1,000 LOC guidance for focused files.)_

Artifacts to produce:
- Updated section in this doc describing the agreed folder structure.
- `.docs/practice-refactor/m1-architecture-baseline.md` (inventory + dependency notes).
- Optional Mermaid diagram showing module relationships.

### Milestone 2 — Practice Module Restructure

**Goal:** Move practice-related models into a dedicated module/namespace without behavioral changes.

- [x] Create `Practice/Models` directory; move data types (`PracticeLesson`, `PracticeUnit`, `HandwritingTemplate`, `LetterTimelineItem`, etc.) there.
- [x] Update imports/module references after moves. _(No code changes required beyond file relocation.)_
- [x] Ensure moved files compile, add TODO markers for future cleanups if necessary.
- [x] Confirm other features (Home, Onboarding) still build.

Deliverables:
- PR moving model files.
- Notes on any coupling uncovered (e.g., cross-feature dependencies that need future decoupling). _Current observation: files rely on global `Models.swift`; consider breaking that up in later milestone._

### Milestone 3 — ViewModel & Coordinator Introduction

**Goal:** Extract state management from SwiftUI views into testable view models/coordinators.

- [x] Define `PracticeSessionController` (or similar) responsible for sequencing repetitions, rows, and overall progress.
- [x] Introduce `RepetitionState` and `RowState` models encapsulating per-row data (letter index, preview phase, drawing snapshots, checkpoints).
- [x] Update `FreePracticeViewModel` to focus on letter timelines; remove row-specific responsibilities.
- [x] Create new view models (`LessonPracticeViewModel`, `PracticeRowViewModel`) exposing Combine/SwiftUI-friendly state. _(LessonPracticeBoard now consumes controller output; row VM event wiring continues under Milestone 4.)_
- [x] Wire SwiftUI views to consume view model outputs instead of manipulating state directly. _(LessonPracticeBoard forwards controller events and derives progress from controller state.)_
- [x] Add unit tests for coordinators (validate state transitions, repetition sequencing).

Artifacts:
- `.docs/practice-refactor/m3-session-controller-design.md` tracks design decisions, current controller behavior, and outstanding tasks.

Dependencies:
- Milestone 2 completed (models in predictable location).

### Milestone 4 — View Layer Simplification

**Goal:** Break large SwiftUI views into focused components driven purely by view-model state.

- [x] Split `LessonPracticeView.swift` into subviews (e.g., `LessonHeaderView`, `PracticeBoardView`, `PracticeRowView`, `FeedbackOverlay`). _(Board and canvas live under `Practice/Views`, with row/overlay components extracted to `Practice/Views/Components`.)_
- [x] Ensure each subview stays within the 800–1,000 line guideline and focuses on presentation. _(New files are well under the limit; `PracticeBoardView.swift` now includes preview wiring and remains a candidate for a future coordinator extraction.)_
- [x] Remove inline logging from views; route diagnostics through view models/coordinators.
- [x] Update previews to use mocked view models for rapid iteration.

Acceptance criteria:
- `LessonPracticeView.swift` reduced to high-level composition.
- No direct mutation of row states from views.

### Milestone 5 — Shared Utilities & Services Cleanup

**Goal:** Centralize reusable functionality and introduce DI-friendly structure.

- [ ] Collect common helpers (e.g., `HapticsManager`, `PencilCanvasView`, `CheckpointValidator`) into `Shared/Utilities` or `Shared/Services`.
- [x] Collect common helpers (e.g., `HapticsManager`, `PencilCanvasView`, `CheckpointValidator`) into `Shared/Utilities` or `Shared/Services`.
- [x] Wrap side-effectful singletons in protocols for easier mocking/testing. _(Practice haptics now consume a `HapticsProviding` dependency with a default system provider.)_
- [ ] Introduce a lightweight dependency container or environment injection strategy for practice module.
- [x] Document usage of shared utilities in this plan. _See `.docs/practice-refactor/m5-shared-services.md` for decisions and follow-ups._

### Milestone 6 — Testing Infrastructure

**Goal:** Ensure refactored architecture has guardrails.

- [ ] Set up test targets mirroring new structure (`PracticeModelsTests`, `PracticeViewModelsTests`, `PracticeCoordinatorsTests`).
- [ ] Write tests for `PracticeSessionController` covering multi-row sequencing and edge cases (clears, repeats).
- [ ] Add snapshot/UI tests validating that non-active rows remain dormant until activated.
- [ ] Automate on CI (if available); otherwise provide scripts/instructions.

## Tracking & Hand-off Notes
- Keep this checklist updated as milestones progress. Mark completed items with `[x]`.
- For each milestone, add bullet notes capturing work done, open issues, or decisions.
- If pausing mid-milestone, include a short “Next steps” snippet so another engineer can resume without re-discovery.
- Consider using sub-docs per milestone (`.docs/practice-refactor/…`) for deeper design docs or diagrams; link them here.

_Last updated: TODO (replace with date & author on first edit)._
