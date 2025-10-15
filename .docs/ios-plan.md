# Scribble iOS: MVP Spec (Cursive v1)

**Goal:** Ship a stylus‑first cursive handwriting MVP using the **Scribble‑Extract** templates. Each practice line shows **top** (ascender), **dotted middle** (x‑height), and **bottom** (baseline) guides. Modes: **Trace → Ghost → Memory**, with stroke‑order + direction validation, XP, haptics, and short success animations.

---

## 1) Dependencies & Project Setup

* **iOS 17+**, **iPadOS 17+** (Apple Pencil focus).
* **Swift/SwiftUI** app, with **PencilKit** for ink capture.
* Bundle the `/output` from Scribble‑Extract in `AppAssets/HandwritingTemplates/`.
* App targets: iPad first; universal allowed but layout optimized for landscape tablet.

---

## 2) Data Contract (from Scribble‑Extract)

* `manifest.json` — index of glyphs/sets.
* Per‑glyph JSON — bezier paths per stroke + metrics:

  ```json
  {
    "id":"a.lower",
    "script":"cursive",
    "metrics":{"unitsPerEm":1000,"baseline":0,"xHeight":450,"ascender":700,"descender":-250,"targetSlantDeg":12},
    "strokes":[{"order":1,"beziers":[["M",...],["C",...]],"start":[...],"end":[...]}],
    "joins":{"entry":[...],"exit":[...],"allowedLift":true},
    "tolerances":{"maxPathDeviationPx":8,...}
  }
  ```

---

## 3) Line Guides (top / dotted middle / bottom)

**Per practice row** we render three horizontal guides:

* **Top line (ascender line):** solid.
* **Middle line (x‑height):** **dotted**.
* **Bottom line (baseline):** solid.

**Layout constants (configurable):**

* `rowHeight = 180pt` (from baseline to baseline)
* `ascenderHeight = 120pt` above baseline, `descenderDepth = 60pt` below baseline
* Line stroke width: `1.5pt`
* Colors: `top/bottom` = `UIColor.label` at 40% opacity; `middle dotted` = 30% opacity
* Dotted pattern: dash `4pt` / gap `6pt`

**Coordinate system per row:** baseline y = 0; convert from template units/em to points using scale `S = (xHeightPts / metrics.xHeight)`.

**SwiftUI line guides:**

```swift
struct PracticeRowGuides: View {
    let width: CGFloat
    let ascender: CGFloat // pts above baseline
    let descender: CGFloat // pts below baseline
    let dottedGap: CGFloat = 6
    let dottedDash: CGFloat = 4

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Baseline (y=0)
            Path { p in p.move(to: .init(x: 0, y: ascender)); p.addLine(to: .init(x: width, y: ascender)) }
                .stroke(.primary.opacity(0.4), lineWidth: 1.5)
            // Dotted x-height line (ascender - xHeight)
            Path { p in p.move(to: .init(x: 0, y: ascender -  (ascender - 0))); p.addLine(to: .init(x: width, y: ascender - (ascender - 0))) }
                .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4,6]))
                .foregroundStyle(.primary.opacity(0.3))
            // Top ascender line
            Path { p in p.move(to: .init(x: 0, y: 0)); p.addLine(to: .init(x: width, y: 0)) }
                .stroke(.primary.opacity(0.4), lineWidth: 1.5)
            // Optional descender line (below baseline)
            Path { p in p.move(to: .init(x: 0, y: ascender + descender)); p.addLine(to: .init(x: width, y: ascender + descender)) }
                .stroke(.primary.opacity(0.2), lineWidth: 1.0)
        }
        .frame(height: ascender + descender)
    }
}
```

*Note:* We render the **top (ascender)** at `y=0`, **dotted middle** at `y = ascender - xHeight`, **bottom (baseline)** at `y = ascender`.

---

## 4) Rendering Pipeline

1. **Scale + place template** into row coordinates using metrics (ascender/xHeight/descender).
2. **Model stroke animation** (Trace mode): animate each stroke with `strokeEnd` from 0→1; show arrowheads.
3. **Guides**: dashed outline SVG (optional) overlaid faintly in Trace/Ghost.
4. **Capture layer**: a `PKCanvasView` on top for stylus input.

**Model stroke view (SwiftUI + CAShapeLayer):**

```swift
final class BezierStrokeLayer: CAShapeLayer {
    func configure(path: CGPath) {
        self.path = path
        self.lineWidth = 6
        self.fillColor = UIColor.clear.cgColor
        self.strokeColor = UIColor.secondaryLabel.cgColor
        self.lineCap = .round
        self.lineJoin = .round
        self.strokeEnd = 0
    }
    func animateDraw(_ duration: CFTimeInterval) {
        let anim = CABasicAnimation(keyPath: "strokeEnd")
        anim.fromValue = 0; anim.toValue = 1; anim.duration = duration
        self.add(anim, forKey: "strokeEnd")
        self.strokeEnd = 1
    }
}
```

---

## 5) Input & Capture (PencilKit)

* Use `PKCanvasView` bridged via `UIViewRepresentable`.
* Disable finger drawing when Pencil present; enable palm rejection.
* Capture `PKDrawing` strokes; downsample to points with timestamps.

```swift
struct PencilCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    func makeUIView(context: Context) -> PKCanvasView {
        let v = PKCanvasView(); v.drawing = drawing
        v.allowsFingerDrawing = false
        v.backgroundColor = .clear
        v.tool = PKInkingTool(.pen, width: 6)
        return v
    }
    func updateUIView(_ uiView: PKCanvasView, context: Context) { uiView.drawing = drawing }
}
```

---

## 6) Modes & Flow

* **Trace**: show full model animation + thick dashed outlines. Require user to trace with hard snap at start dot.
* **Ghost**: faint path; hints available on tap; partial scaffolds.
* **Memory**: guides only; no path; evaluate freeform.

**Drill flow:** Model → User attempt → Validate → Feedback → XP → Next.

---

## 7) Validation (Order, Direction, Shape, Joins)

**Inputs:** user `PKStrokePoint`s; template strokes.

**Algorithm skeleton:**

1. **Cluster user ink into strokes** by time gap + lift events.
2. **Match** each user stroke to the expected template stroke `k` using start‑point proximity and dynamic time warping on resampled polylines.
3. **Order check**: ensure matched indices are 1..N in order.
4. **Direction check**: compute mean tangent dot with template; penalize sign flips.
5. **Shape error**: resample both to N points; compute mean perpendicular distance + Hausdorff cap.
6. **Join continuity (words)**: ensure `exit`→next `entry` gap < tolerance and angle Δ < threshold.

**Scoring:** 0–100 weighted: `shape 40 + order 25 + direction 20 + start-point 10 + join 5`.

**Tolerances (default; tweakable in template):**

* `maxPathDeviationPx = 8`, `maxStartErrorPx = 12`, `slantToleranceDeg = 5`, `joinGapPx = 10`.

---

## 8) Feedback & Haptics

* **Immediate tips (max 2):**

  * Wrong start → “Start at the top dot.”
  * Direction → “Trace this loop clockwise.”
  * Shape → “Close the loop tighter.”
* **Haptics:** `UINotificationFeedbackGenerator.success()` on pass; `impactOccurred(intensity: 0.5)` on good stroke segments.
* **Celebration:** small confetti / mascot bounce on ≥80 score (0.6s).

---

## 9) XP & Progression

* XP per letter: base 50 + bonus (score/2).
* 3‑star thresholds: 60 / 80 / 95.
* Streaks: +10% XP per consecutive pass.
* Unlock next letter after ≥80 twice.

---

## 10) Composition for Words (Cursive)

* Compose letters into a word by placing glyph `i+1` so its `entry` aligns with glyph `i` `exit`.
* Render a **single practice row** per word with same guides.
* Validation additionally enforces join continuity per adjacent pair.

---

## 11) Performance

* Pre‑parse and cache CGPaths per glyph.
* Use a lightweight resampler (e.g., 128 points per stroke) for comparisons.
* Offload validation to a background queue; UI shows spinner <150ms.

---

## 12) Persistence

* Local `SQLite` or `CoreData` store:

  * `Attempt(letterId, mode, score, ts, errors[])`
  * `Mastery(letterId → bestScore, lastTs, attempts)`

---

## 13) Accessibility & Settings

* Left‑handed mode: flip slant hint; offset UI buttons.
* High‑contrast guides; adjustable line thickness; larger row height.
* Audio cues on/off; haptics on/off.

---

## 14) Minimal Screens

* **Home / Map:** pick letter/word; show mastery rings.
* **Drill Screen:** guides + model + canvas + progress bar.
* **Results Toast:** score, two tips, “Replay” button.

---

## 15) Testing

* Unit tests: scaling from metrics to points; stroke matcher; score invariants.
* Snapshot tests: guides alignment; model animation path.
* Pilot script with 5 kids; measure time to ≥80 on 5 letters.

---

## 16) MVP Definition of Done

* Letters: cursive subset (a, c, d, e, i, l, t, u) with templates.
* Modes: Trace, Ghost, Memory fully working.
* Validation: order + direction + shape; basic joins for 2‑letter combos.
* Guides: **top line**, **dotted middle line**, **bottom line** visible on every practice row.
* Haptics + a single celebration animation.
* XP + simple progression; basic local persistence.

---

## 17) Example: Placing a Glyph on a Row

```swift
struct GlyphPlacement {
    let metrics: TemplateMetrics // from JSON
    let rowAscender: CGFloat // e.g., 120
    let rowDescender: CGFloat // e.g., 60
    let xHeightPts: CGFloat { rowAscender - (rowAscender * (1 - metrics.xHeight / metrics.ascender)) }

    func scaleFactor() -> CGFloat { (rowAscender - 0) / CGFloat(metrics.ascender) }

    func transform(path: CGPath, at xOffset: CGFloat) -> CGPath {
        let s = scaleFactor()
        var t = CGAffineTransform.identity
            .translatedBy(x: xOffset, y: rowAscender)
            .scaledBy(x: s, y: -s) // flip y to CoreGraphics up
        return path.copy(using: &t) ?? path
    }
}
```

---

## 18) Roadmap After MVP

* Full cursive alphabet + common joins; word banks.
* Printable worksheets mirroring guides.
* Teacher view + error heatmaps.
* ML personalization (predict typical errors, adjust drills).
