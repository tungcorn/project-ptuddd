# Song content schema (assets/content/songs/<id>.json)

```json
{
  "id": "twinkle-twinkle-little-star",
  "title": "Twinkle, Twinkle, Little Star",
  "artist": "Traditional – lyrics Jane Taylor (1806)",
  "level": "A1",
  "topics": ["nature"],
  "genre": "nursery",
  "lyricsSource": "Jane Taylor, \"The Star\" (1806) – public domain",
  "lines": [
    {"en": "Twinkle, twinkle, little star,", "vi": "Lấp lánh, lấp lánh, ngôi sao nhỏ,"},
    {"en": "How I wonder what you are!", "vi": "Tôi tự hỏi bạn là gì!"}
  ],
  "keywords": ["twinkle", "star", "wonder", "diamond", "sky"]
}
```

Rules:
- `level`: one of A1, A2, B1, B2.
- `topics`: 1–2 of: family, friendship, nature, festival, animals, love, travel, daily-life, feelings, body, work.
- `genre`: one of nursery, folk, holiday, hymn, ballad, pop-rock, acoustic.
- Verify rights separately for composition/lyrics AND recording: public domain with provenance, or an explicit open license allowing redistribution and adaptation (e.g. CC BY 4.0). A public stream or a free download alone is NOT permission. Do not label CC-licensed originals as public domain.
- `lyricsSource` and the catalog's displayed `license` must credit title/author/performer, link the authoritative song source and license, and identify changes (excerpt, re-encoding, translation, lyric normalization/alignment). For CC BY, retain attribution for both lyrics/composition and recording.
- Learning excerpts use a distinct `-learning-clip` id and `(đoạn học)` title. Document exact source interval and generation commands; do not present an excerpt as the full song. CEFR levels are editorial estimates, not certifications.
- 8–16 lines per song (pick the best-known verse(s) + chorus; skip offensive/dated verses). One line = one sung phrase, max ~12 words.
- `vi`: natural, accurate Vietnamese translation of that line (full diacritics).
- `keywords`: 5–8 useful vocabulary words (lowercase base form) that appear in the lyrics, suited to the level.
- UTF-8, valid JSON, 2-space indent. No timestamps (generated later).
