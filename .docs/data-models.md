# Data Models

All MVP data stays local (no sync). Schema below can map to Core Data or SQLite; types shown as canonical SQL.

## 1. Entities

### LetterAttempt
- `id` (UUID, PK)
- `letterId` (TEXT, FK → LetterMastery.letterId)
- `mode` (TEXT enum `trace|ghost|memory`)
- `score` (INTEGER, 0–100)
- `strokeOrderScore` (INTEGER, 0–100)
- `directionScore` (INTEGER, 0–100)
- `shapeScore` (INTEGER, 0–100)
- `startScore` (INTEGER, 0–100)
- `tips` (TEXT JSON array of identifiers)
- `hintUsed` (BOOLEAN)
- `durationMs` (INTEGER)
- `startedAt` (DATETIME, ISO 8601 UTC)
- `completedAt` (DATETIME, ISO 8601 UTC)
- `rawDrawing` (BLOB, compressed `PKDrawing`)

Indexes: `letterId`, `mode`, `completedAt DESC`.

### LetterMastery
- `letterId` (TEXT, PK, matches manifest glyph id)
- `bestScore` (INTEGER)
- `bestMode` (TEXT)
- `attemptCount` (INTEGER)
- `lastPracticedAt` (DATETIME)
- `unlocked` (BOOLEAN)
- `memoryPassCount` (INTEGER) – Memory-mode scores ≥80 accumulated

### Settings
- single-row table keyed by `id = 'default'` (TEXT, PK)
- `isLeftHanded` (BOOLEAN)
- `hapticsEnabled` (BOOLEAN)
- `lastSelectedLetterId` (TEXT)

### ContentVersion (embedded in snapshot)
- `contentVersion` (TEXT, mirrors `manifest.json.version`)
- updated when template bundle ships to keep mastery data in sync

## 2. Data Flows
- **Attempt Storage:** After each drill, persist `LetterAttempt`, update `LetterMastery` aggregates (best score, attempts, last practiced), and auto-unlock the next letter once two Memory-mode scores achieve ≥80.
- **Hint Tracking:** `hintUsed` records whether the student relied on playback to inform future coaching copy.
- **Settings:** Persist left-handed preference and haptics toggle for consistent session setup.
- **Content Version:** Compare stored version to `manifest.json`; reseed mastery defaults when bundle version changes and stamp new version in snapshot.

## 3. Serialization Helpers
- `rawDrawing`: store `PKDrawing.dataRepresentation()` compressed (gzip/NSData); decode on replay.
- `tips`: persist canonical identifiers (e.g., `"start-point"`, `"direction-clockwise"`) so localisation/tuning does not modify stored attempts.

## 4. Future Considerations
- Add `WordAttempt`/`WordMastery` tables when joins practice re-enters scope.
- Extend `Settings` with accessibility toggles (contrast, row height) post-MVP.
- Introduce telemetry table if we later capture per-stroke diagnostics for analytics or remote review.
