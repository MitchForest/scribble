# Validation Overhaul Plan

This document defines the end-to-end plan for replacing the current raster-coverage validator with the **Beadway** stroke validation model. It serves as the canonical checklist for engineering and design until completion.

---

## 1. Objectives
- Ensure every stroke is validated via ordered bead checkpoints inside a configurable corridor.
- Support continuous handwriting (no forced lifts) while rejecting out-of-order transitions.
- Handle shared start/end dots (loops) without false positives.
- Expose intuitive difficulty dials that map to beginner, intermediate, and expert presets.
- Remove the existing loop-distance heuristics and global coverage dependence.

---

## 2. Foundational Principles
- **Simplicity first:** each decision is geometric (point-in-circle, arc-length progress) with minimum state.
- **Sequential focus:** only one stroke is “active”; failure resets the entire letter.
- **Kid-oriented feedback:** validation rules mirror the comet bead UI (head + short tail).
- **Deterministic tolerances:** all thresholds derive from the difficulty profile; no hidden magic numbers.

---

## 3. Difficulty Dials (per stroke)

| Dial | Description | Beginner | Intermediate | Expert |
| --- | --- | --- | --- | --- |
| Corridor radius `r` (% of x-height) | Lane width around template path | 12% | 8% | 4.5% |
| Head bead radius `RbHead` | Target radius for next bead | 1.6 × r | 1.3 × r | 1.1 × r |
| Tail bead radius `RbTail` | Radius for lookahead beads | 1.3 × r | 1.15 × r | 1.0 × r |
| Bead spacing (% arclength) | Distance between bead centers | 8% | 6% | 4% |
| Required beads hit (in order) | Fraction of beads required to pass | ≥ 75% | ≥ 85% | ≥ 92% |
| Max adjacent skips | Forgiveness for missing successive beads | 2 | 1 | 0 |
| Backtrack tolerance (normalized) | Allowable regression in progress | 0.04 | 0.025 | 0.015 |
| Start/End multiplier | Radius scaling for start/end dots | 1.3 × r | 1.1 × r | 1.0 × r |
| Direction gate (cosine) | Optional forward-direction threshold | Off | ≥ 0.60 | ≥ 0.75 |

*These presets live in `PracticeDifficultyProfile` and fully replace raster coverage defaults.*

---

## 4. Dash-Order Processing Checklist

1. **Prepare template stroke**
   - Sample ordered polyline points with cumulative arclength.
   - Apply the dashed-stroke pattern (`dashLength`, `gapLength`) to generate sequential dash segments.
   - Record each dash’s start/end progress and owning stroke.

2. **Flatten dash sequence**
   - Concatenate all stroke dashes in order.
   - Assign a global dash index so loops and shared coordinates still preserve the intended order.

3. **Runtime tracking**
   - Maintain a pointer to the next expected dash, plus per-dash coverage/outside stats.
   - For every sample, project onto the pointer stroke to accumulate coverage and detect outside marks.
   - Detect out-of-order attempts by projecting onto all strokes and comparing the resulting dash index with the pointer.

4. **Completion rules**
   - Mark a dash complete once coverage ≥ threshold.
   - Fail if the learner reaches a later dash before completing the pointer dash (`outOfOrder`).
   - Fail at evaluation end if coverage is insufficient or outside markings exceed the difficulty allowance.

5. **UI feedback**
   - Render the existing dashed guide.
   - Overlay filled segments for every completed dash; no extra dots or arrows.

---

## 5. Implementation Work Items

### Complete
- [x] Refactor `PracticeDifficultyProfile.validationConfiguration` to expose dash-based corridor and tolerance settings.
- [x] Build dash sequence preprocessing that mirrors the rendered dashed guides.
- [x] Replace validator logic with dash-order/coverage/outside checks (no bead heuristics or loop distance heuristics).
- [x] Update failure reasons and reports to surface dash completion counts per stroke.
- [x] Simplify the UI to fill dashed guides as dashes are validated (no additional overlays).
- [x] Refresh unit coverage for dash order, coverage thresholds, outside tolerance, and loop letters.

### In Progress / Remaining
- [ ] Document the dash-order validation model and difficulty presets in README/export docs.

---

## 6. Testing Strategy

- **Unit tests:** deterministic PKDrawings covering dash completion, dash skipping, insufficient coverage, outside ink, and loop letters (e.g., lowercase `a`).
- **Manual QA checklist:** continuous pen-down flow on loop letters (`a`, `g`), dot letters (`i`, `j`), left-handed practice, and aggressive scribbles outside the dashed guide.
- **Visual sanity:** ensure dashed guides fill progressively without additional overlays or flicker.
- **Telemetry hooks (optional):** log dash-order violations and outside-ink ratios to tune thresholds post-launch.

---

## 7. Rollout Notes

- Feature flag the dash-order validator behind a runtime switch for pilot testing if needed.
- Provide migration path for persisted progress data if validator semantics change scoring.
- Coordinate with curriculum team for updated coaching tips that mention “fill the dash in order.”

--- 

*Document owner: Validation working group. Update after each milestone.* 
