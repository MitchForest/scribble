# MVP Checklist

## Milestone M1 – Trace Prototype
- [x] Import handwriting asset bundle into Xcode project (`AppAssets/HandwritingTemplates/`).
- [x] Render practice row guides using shared metrics (baseline, x-height, ascender).
- [x] Display Trace mode model animation for letter **a** using template strokes.
- [x] Capture PencilKit drawing and overlay live ink atop guides.
- [x] Compute basic score (shape/order/direction/start) and show result banner.
- [x] Trigger warning haptic when start point is incorrect or path deviation exceeds tolerance.

## Milestone M2 – Mode Progression
- [x] Add Ghost mode view with fading scaffold and hint replay button.
- [x] Add Memory mode with guides only and validation on free writing.
- [x] Persist `LetterAttempt` records (scores, tips, hint usage, drawing).
- [x] Surface two context-sensitive tips per attempt.
- [x] Implement mastery ring UI tied to `LetterMastery` best scores.
- [x] Unlock next letter after two Memory-mode scores ≥80; surface unlock banner.

## Milestone M3 – Content & Polish
- [x] Expand Trace/Ghost/Memory flows to remaining seven letters.
- [x] Implement haptic toggle in settings; persist left-handed preference.
- [x] Ensure warning and success haptics respect settings.
- [x] Add VoiceOver labels for guides, buttons, score, and tips.
- [x] Snapshot test guide alignment and stroke overlays for each letter.
- [x] Preload template paths for smooth animation performance.

## Milestone M4 – Pilot Ready
- [x] Conduct simulator regression sweep and document on-device validation plan.
- [x] Finalise educator pilot script (setup, practice flow, observation prompts).
- [x] Verify persistence survives app relaunch and upgrades (`ContentVersion` checks).
- [x] Package TestFlight checklist with release notes and onboarding instructions.
- [x] Gather pilot feedback checklist to capture session notes and follow-ups.

## Next Build – Free Practice Revamp
- [ ] Audit practice architecture to resolve "Modifying state during view update" warnings and document required refactors.
- [ ] Redesign the home screen: remove the letter grid, add a centered “Get Started” CTA, and surface Free vs Guided mode switching (Guided stubbed).
- [ ] Integrate a DiceBear Adventurer avatar in the top-right profile button with resilient caching/offline fallback.
- [ ] Create a gold-gradient circular progress ring around the user name that animates daily XP goal completion.
- [ ] Extend the data model to capture users, daily/weekly XP goals (e.g., 100 XP × 5 days), and per-day XP events with streak tracking.
- [ ] Render a GitHub-style contribution calendar summarizing daily XP vs goal with tooltips and legend.
- [ ] Build the Free Practice workbench with drill presets, editable sentence input, and the handwriting canvas side-by-side.
- [ ] Add playback controls for target sentences: play/pause, per-letter timeline, and dot scrubbing to jump to strokes.
- [ ] Display the active practice line with up/down navigation and per-line reset controls.
- [ ] Introduce a guides toggle that swaps between solid letters and dotted outlines with stroke start hints.
- [ ] Remove finger input, default to Pencil-only, and tie Easy/Medium/Hard difficulty to pen width and correction strength via the profile sheet.
- [ ] Improve stroke evaluation with difficulty-based smoothing, sequential stroke validation, automatic dot advancement, and haptic feedback.
- [ ] Sync timeline/haptic events so completed strokes reveal the next target without manual steps.
- [ ] Expose XP goal configuration, difficulty settings, and avatar preview inside the profile modal.
- [ ] QA the updated flow, validate XP progression updates the ring/calendar, and add instrumentation or tests where practical.
