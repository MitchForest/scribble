# Validation Revamp Final Plan

## Objectives
- Replace stroke-based evaluation with checkpoint sequencing that only cares about ordered hit detection.
- Keep difficulty differences scoped to corridor tolerance, coverage, and outside-ink allowances.
- Deliver live gradient guidance based on the next unhit checkpoints using existing dot/dash geometry.
- Remove legacy validation utilities and related technical debt.

## Checklist
- [x] Audit current stroke-based validation usage and dependencies.
- [x] Define checkpoint data structures and generation pipeline from template strokes.
- [x] Build real-time checkpoint validator (ordered hit tracking, coverage, tolerance handling).
- [x] Map practice difficulty profiles to new validator thresholds and corridor sizing.
- [x] Port practice canvas integration to new validator, removing stroke index bookkeeping.
- [x] Implement live gradient guidance over existing dots/dashes with progressive fade and real-time updates.
- [x] Remove raster stroke validator, dash planner coupling, and obsolete stroke-report models.
- [x] Update UI warnings, haptics, and success flow to rely on checkpoint results.
- [x] Refresh automated tests to cover beginner/intermediate/expert scenarios and re-hit behaviour.
- [ ] Document new validation behaviour for instructors/support material.

## Notes
- Once a checkpoint is marked hit it remains satisfied; re-tracing does not reset progress.
- Gradient overlay should key off `nextCheckpointIndex`, blending down opacity across the following 5–10 checkpoints.
- Any remaining stroke-specific terminology in templates/UI should be replaced with checkpoint-oriented language.
