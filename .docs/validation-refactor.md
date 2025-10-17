# Validation Refactor Checklist

- [x] Audit current validation flow and catalog every usage of the legacy stroke analyzer, its parameters, and downstream consumers (UI warnings, haptics, analytics, persistence).
- [x] Design the raster-based validation architecture, covering buffer resolution, brush multipliers, coverage thresholds, start/end zones, arclength bins, direction metrics, and data payloads for the UI.
- [x] Implement the raster validator module with supporting rasterization utilities, live progress tracking, and PencilKit integration hooks required by `LessonPracticeView`.
- [x] Replace legacy analyzer invocations with the new validator, migrate configuration models to the new parameter set, and remove obsolete corridor/tube code and data structures.
- [x] Update UI feedback, messaging, haptics, and storage/analytics logic to consume the new result fields and eliminate assumptions tied to inside/forward ratios.
- [x] Add automated tests or instrumentation for key pass/fail scenarios, perform manual QA across difficulty levels, and document tuning knobs or follow-up tasks once the baseline ships.

## New Validation Approach

Minimal baseline we’ve shipped:

1. **Start gate** – Ignore all ink until the pencil enters the start dot. If the learner scribbles inside the stroke bounds without touching the dot we flag “start at the green dot.”
2. **Raster coverage** – Render the template corridor (“tube”) once, redraw the student ink with a brush ~1.6–1.7× wider, then measure `covered / tube`. Passing is a single percentage check (current defaults: 0.90 beginner, 0.94 intermediate, 0.97 expert).
3. **End gate** – Require the pencil to reach the end dot; otherwise fail with “trace to the yellow dot.”

No arclength bins, no direction heuristics—just the pieces kids understand and we can explain in one sentence.

### Practical defaults

* Tube width factor (vs. row height): 0.12 beginner / 0.085 intermediate / 0.05 expert.
* Student brush width: 1.7× / 1.55× / 1.4× the tube width.
* Coverage thresholds: 0.90 / 0.94 / 0.97.
* Start/end dot radius: 1.6× tube radius (clamped to the visual dot size).

### Implementation sketch

* Flatten PencilKit samples, assign them to strokes strictly in order.
* Only capture samples after the start dot is touched; mark completion when the end dot is reached.
* For coverage, stroke the template path with the tube width, replay the captured samples with the wider brush, and compute overlap / tube pixels on a 2× buffer.
* Failure reasons are exactly three strings: start, end, or coverage.

## Follow-up & Tuning Notes

- [ ] Revisit tube and brush multipliers once we have kid telemetry so the corridor feels fair across handwriting styles.
- [ ] Adjust coverage thresholds and dot radii per difficulty as we gather pass/fail data from classrooms.
- [ ] Add an optional debug overlay that visualizes template vs. student coverage to speed up internal QA and future tuning.
