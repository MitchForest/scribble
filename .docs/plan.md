# Scribble MVP Product Plan

## 1. Product Vision
- Deliver an iPad-first cursive handwriting coach that mirrors classroom practice with immediate, specific feedback.
- Use stylus input, stroke-by-stroke guidance, and progressively reduced scaffolding so students move from guided tracing to confident free writing.
- Optimise for short, repeatable sessions (3–5 minutes) that build mastery of foundational cursive strokes.

## 2. Target Users & Success Criteria
- Primary: Grade 2–4 students learning or reinforcing cursive handwriting with teacher/parent facilitation.
- Secondary: Educators who need structured practice sets and quick insight into student progress.
- Success metrics (MVP): 80% of pilot students reach ≥80 score on eight focus letters within two sessions; average session length ~4 minutes; positive qualitative feedback on clarity of tips and enjoyment.

## 3. MVP Scope
- **Letters covered:** a, c, d, e, i, l, t, u (lowercase cursive).
- **Practice modes:** Trace → Ghost → Memory, each with tailored guidance and validation.
- **Feedback loop:** On-device validation for stroke order, direction, and shape with concise coaching tips and a single score per attempt.
- **No auth or syncing**; all data stored locally on device.

Out of scope: teacher dashboards, multiplayer components, cloud sync, uppercase set, word drills, deep analytics, complex gamification systems.

## 4. Experience Flow
1. **Home / Letter Map**
   - Displays letter tiles with mastery rings, lock/unlock state, and last attempt score.
   - Primary navigation: focus letters organised in recommended order.
2. **Lesson Entry**
   - Pre-lesson card summarising target letter, mode progression, and recent best score.
3. **Drill Session**
   - Practice row with ascender/dotted middle/baseline guides.
   - Template overlay depending on mode:
     - Trace: animated model stroke-by-stroke with start dot lock.
     - Ghost: faint scaffold, optional hint replay.
     - Memory: guides only; free writing.
   - PencilKit capture layer and progress indicator per stroke.
   - Real-time cue: single warning haptic + on-screen prompt when user starts at the wrong point or deviates beyond tolerance.
4. **Validation & Feedback**
   - Instant score (0–100) derived from template match metrics.
   - Up to two actionable tips plus haptic confirmation on completion.
   - “Improve & Retry” or “Next Letter” choices.
5. **Progression**
   - Unlock next letter after two ≥80 scores in Memory mode.

## 5. Content & Assets
- Bundled templates from `export/templates` (stroke points, metrics, tolerances).
- SVG guides and animations serve as QA references; in-app rendering uses native paths.
- Shared metrics from `export/style.yml` ensure guide alignment across modes.

## 6. Feedback & Haptics
- **Scoring:** Shape (40), Order (25), Direction (20), Start (15). Joins deferred.
- **Haptics:** single warning tap on deviation; success notification haptic on completion ≥80.
- **Tips:** concise guidance aligned to common errors (start-point reminder, direction correction, shape tightening, slant alignment).
- **Visual cues:** progress dots per stroke, modal banner summarising score and key tip.

## 7. Technology & Architecture
- SwiftUI shell with PencilKit canvas for stylus capture.
- Stroke validation engine comparing PencilKit strokes to template paths (resampling + dynamic warping).
- Local persistence via lightweight store recording attempts, best score, unlock status, and left-handed preference (details in `.docs/data-models.md`).
- Asset management: bundle `export/` contents under `AppAssets/HandwritingTemplates/`.
- Offline-first; no networking.

## 8. Accessibility & Settings
- Left-handed mode (UI mirroring, slant hint adjustments).
- Support VoiceOver descriptions for tips and scores.
- Additional toggles (audio, high contrast, row height) deferred to post-MVP.

## 9. Milestones
- **M1 – Trace Prototype (Week 2):** Single letter Trace mode with animation, PencilKit capture, basic score feedback.
- **M2 – Mode Progression (Week 4):** Ghost/Memory scaffolds, validation scoring, tip messaging, simple letter unlock.
- **M3 – Content & Polish (Week 6):** Full eight-letter set, haptic warning + success states, voice-over copy, persistence for attempts and mastery.
- **M4 – Pilot Ready (Week 8):** Stability, educator pilot script, TestFlight build.

## 10. Risks & Mitigations
- **Stroke validation accuracy** → start with generous tolerances, gather sample drawings, iterate rapidly.
- **Session fatigue** → keep drills short, rotate letters, surface simple mastery rings.
- **Asset alignment bugs** → automated snapshot tests for guide + template overlays; reference SVGs for QA.
- **Hardware variance** → target iPadOS 17 baseline, validate on Pencil 1 & 2 hardware.
