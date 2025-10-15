# Regression Plan – Cursive MVP

## Simulator Sweep (Automatable)
- Launch on iPad Pro 11" (M4) simulator.
- For each focus letter (`a, c, d, e, i, l, t, u`):
  - Enter Trace mode, confirm animation completes and warning haptic fires when deviating intentionally.
  - Switch to Ghost mode, trigger hint replay, verify faint overlay fades.
  - Switch to Memory mode, draw freeform, confirm score + tips appear.
- Toggle Settings → left-handed mode; ensure controls mirror and start dots move to mirrored positions.
- Toggle haptics off; confirm warning + success feedback remain silent.
- Execute automated tests:
  - `xcodebuild -scheme scribble -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' test`

## On-Device Verification (Pencil 1 & 2)
- Install TestFlight build on:
  1. iPad (Lightning) + Apple Pencil (1st gen).
  2. iPad Air/Pro (USB-C) + Apple Pencil (2nd gen).
- Confirm stylus palm rejection and hover states (if supported) are stable.
- Validate haptic feedback toggles map to physical sensation (use haptic engine logs).
- Capture `Settings > Diagnostics` screenshot showing content version + build number.

## Persistence Checks
- Complete two letters to unlock third; force-quit app; relaunch and ensure mastery + unlock state persist.
- Bump `manifest.json` version in dev build, relaunch, and confirm data snapshot updates `contentVersion` without crashes (log from `PracticeDataStore`).
- Toggling haptics/left-handed mode should remain sticky across relaunch.

## Pre-Flight Sanity
- Run through pilot script flow (Trace → Ghost → Memory) with at least one student/colleague; note timings.
- Verify TestFlight metadata (screenshots, description, feedback email) up to date before submission.
