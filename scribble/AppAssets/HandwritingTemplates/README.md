# Scribble Export Bundle

This folder contains everything needed to embed the Learning Curve / Cogncur handwriting assets in the Scribble iOS app.

## Contents

| Path | Purpose |
|------|---------|
| `templates/alpha-lower/*.json` | Final per-glyph stroke templates (lowercase). |
| `templates/alpha-upper/*.json` | Final per-glyph stroke templates (uppercase). |
| `manifest.json` | Lists glyph sets, IDs, and provenance. Import this to enumerate available assets. |
| `style.yml` | Shared handwriting metrics (baseline = 0, x-height = 614, ascender = 1296, descender = -682). Use these values to render practice guidelines. |
| `strokes_manual/*.json` | Raw stroke definitions pulled from Cogncur (or manual overrides). Useful for debugging or regenerating templates. |
| `svg_guides/*.svg` | Static previews showing stroke order with handwriting lines, start dots, and numbering. Use for QA or worksheets. |
| `svg_trace_animations/*.svg` | Animated stroke-tracing demos (stroke-dashoffset animation). Optional for educator demos / marketing. |

## Using in the iOS App

1. **Stroke templates** – Bundle the `templates/**` files in your app resources. The Scribble engine reads each JSON and supplies stroke points / Bézier commands for tracing and validation. Each file’s `strokes[].points` array is normalized to the shared coordinate system in `style.yml`.

2. **Metrics** – Load `style.yml` to position practice lines in Swift (baseline, dotted midline, ascender, descender). This keeps UI overlays in sync with the stored stroke data.

3. **Manifest** – Parse `manifest.json` to enumerate glyphs or verify provenance before distribution.

4. **Guides & Animations (optional)** – The SVGs are ready-to-go assets. Convert them to PNG/MP4 if desired, or treat them as reference when implementing native overlays/animations. The animated SVGs draw each stroke sequentially and can be toggled on/off in code by layering your own start dots or numbering.

## Regenerating the Bundle

From the repo root:

```bash
python3 import_cogncur_shapes.py            # refresh lowercase (default a–z)
python3 import_cogncur_shapes.py A B ... Z  # refresh uppercase as needed
python3 build_manual_strokes.py             # optional manual overrides (if you add custom variants)
python3 generate_templates.py               # rebuild templates/manifest/style
python3 generate_trace_animations.py        # rebuild animated SVGs (optional)
```

To rebuild this export folder explicitly:

```bash
python3 - <<'PY'
import shutil
from pathlib import Path
root = Path('.')
export = root / 'export'
if export.exists():
    shutil.rmtree(export)
shutil.copytree(root / 'output' / 'templates', export / 'templates')
shutil.copy2(root / 'output' / 'manifest.json', export / 'manifest.json')
shutil.copy2(root / 'output' / 'style.yml', export / 'style.yml')
shutil.copytree(root / 'work' / 'strokes_manual', export / 'strokes_manual')
shutil.copytree(root / 'work' / 'stroke_viz_manual', export / 'svg_guides')
shutil.copytree(root / 'work' / 'stroke_animations', export / 'svg_trace_animations')
PY
```

(_Note_: the repo already ships `import_cogncur_shapes.py`, `generate_templates.py`, and `generate_trace_animations.py`, so you can regenerate assets anytime Cogncur updates their stroke definitions.)

## Extending

- **Alternates** – Pass additional Cogncur IDs (e.g., `f-alt1`) to `import_cogncur_shapes.py` and add matching entries to `glyphset.yml`.
- **Custom Overlays** – In iOS, you can toggle guidelines, start dots, or numbering dynamically using the metrics instead of relying on the baked-in SVG previews.

Happy tracing!
