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
