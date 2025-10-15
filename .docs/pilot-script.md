# Educator Pilot Script

## 1. Setup (5 minutes)
- Confirm iPad is on iPadOS 17+ and Apple Pencil paired.
- Launch Scribble MVP build (TestFlight) and ensure stylus-only input is enabled.
- Toggle haptics/left-handed mode per student preference in Settings.
- Verify handwriting templates report version `$(HandwritingAssets.currentVersion())` on Home screen diagnostics sheet.

## 2. Warm-Up (2 minutes)
- Ask the student to draw a free-form line to acclimate to PencilKit canvas.
- Explain the three practice modes (Trace → Ghost → Memory) and the mastery ring visuals.

## 3. Guided Practice Rotation (10 minutes)
1. **Trace Mode**
   - Demonstrate a single stroke and highlight start-dot + warning haptic.
   - Allow the student to complete all strokes; prompt them to restart if they ignore the warning toast.
2. **Ghost Mode**
   - Encourage student to attempt without hints first; allow hint replay once per letter.
   - Observe whether they maintain slant and order without overlays.
3. **Memory Mode**
   - Student writes independently; note any repeated warnings or feedback tips surfaced.
   - Record total score and individual components (shape/order/direction/start).

Repeat the cycle for three letters (recommended: `a`, `l`, `t`) and one mixed session of previously unlocked letters.

## 4. Word Challenge (Optional, 5 minutes)
- If the student has unlocked ≥3 letters, assign a word drill.
- Observe join continuity feedback and note any slant drift when connecting letters.

## 5. Debrief (3 minutes)
- Review mastery rings and unlock banners with the student.
- Ask the student which feedback cues (haptics, tips, animations) were helpful or distracting.
- Capture time-to-80 score for each letter and whether hints were used.

## 6. Educator Notes Template
- Student initials / grade
- Pencil version (Gen 1 / Gen 2)
- Letters practiced + top score per mode
- Hints used? (Y/N per letter)
- Observed pain points (start point, direction, shape, slant)
- Engagement reactions (celebrations, motivation loops)
- Follow-up actions (assign next letters, adjust settings, schedule next session)
