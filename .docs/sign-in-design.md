# Sign-In Landing Animation Plan

## Goals
- Reinforce Scribble’s handwriting focus the moment the screen loads.
- Keep hero content (headline, streak chip, primary actions) perfectly legible.
- Make motion feel intentional, slow, and premium rather than like a looping screensaver.
- Respect Reduce Motion accessibility settings and offer a lightweight fallback.

## Experience Principles
- **Layered depth:** Animated letterforms sit behind core UI, blending into the gradient backdrop.
- **Calm rhythm:** Long ease curves, gentle drift, and 6–12 s lifetimes keep motion soothing.
- **Brand lexicon:** Rotate through curated words like “flow”, “focus”, “confidence”, “practice”, “scribble”.
- **Balanced contrast:** Opacity stays ≤8% with a soft blur so typography reads as texture, not copy.

## Motion System
- Maintain 3–5 words alive simultaneously with staggered spawn times (~900 ms cadence).
- Randomize position (safe-area aware), rotation buckets (0°, 15°, 30°, 60°, 90°), and scale (0.7–1.5×).
- Each word fades in/out over 2–3 s, drifts slightly, and scales 1.05× before dissolving.
- Tint words via a stepped palette to harmonize with the existing hero gradient.
- Add a subtle center vignette or mask to keep primary content brightest.

## Implementation Outline (SwiftUI)
1. Create `HomeAnimatedLetterBackground` using `TimelineView(.animation)` + `Canvas`.
2. Model `AnimatedWord` with birth time, duration, randomized transform seed, and word string.
3. On each timeline tick, resolve active words into draw instructions: position, rotation, scale, opacity.
4. Blur the canvas (`.blur(radius: 4)`) and blend with `.plusDarker` to keep contrast gentle.
5. Spawn words in a background `Task`, trimming expired items to cap memory/CPU usage.
6. Wrap the background in `if !reduceMotion` guard; provide static gradient fallback otherwise.

## QA Checklist
- Profile on iPad/iPhone (older + current) to ensure frame rates stay ≥55 fps.
- Verify hero text and buttons remain AA contrast compliant.
- Test Reduce Motion toggle, dark/light modes, and landscape orientation.
- Confirm tap targets and scroll performance remain unaffected.

## Next Steps
1. Prototype in a SwiftUI preview and tune timing/opacities.
2. Gather quick stakeholder feedback (motion capture or video).
3. Implement accessibility toggle and ship behind a feature flag.
