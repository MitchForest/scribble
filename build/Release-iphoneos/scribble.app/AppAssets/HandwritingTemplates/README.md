# Scribble Export Bundle

This folder contains everything needed to embed the Learning Curve / Cogncur handwriting assets in the Scribble iOS app.

## Contents

| Path | Purpose |
|------|---------|
| `templates/alpha-lower/*.json` | Final per-glyph stroke templates (lowercase). |
| `templates/alpha-upper/*.json` | Final per-glyph stroke templates (uppercase). |
| `manifest.json` | Lists glyph sets, IDs, and provenance. Import this to enumerate available assets. |

## Using in the iOS App

1. **Stroke templates** – Bundle the `templates/**` files in your app resources. The Scribble engine reads each JSON and supplies stroke points and Bézier commands for tracing/validation. Each file’s `metrics` block includes the baseline, x-height, and ascender/descender data needed for guidelines.
2. **Manifest** – Parse `manifest.json` to enumerate glyphs or verify provenance before distribution.

## Regenerating the Bundle

From the repo root:

```bash
python3 import_cogncur_shapes.py            # refresh lowercase (default a–z)
python3 import_cogncur_shapes.py A B ... Z  # refresh uppercase as needed
python3 generate_templates.py               # rebuild templates and manifest
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
PY
```

(_Note_: the repo already ships `import_cogncur_shapes.py` and `generate_templates.py`, so you can regenerate assets anytime Cogncur updates their stroke definitions.)

## Extending

- **Alternates** – Pass additional Cogncur IDs (e.g., `f-alt1`) to `import_cogncur_shapes.py` and add matching entries to `glyphset.yml`.

Happy tracing!
