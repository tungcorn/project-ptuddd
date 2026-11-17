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
- `genre`: one of nursery, folk, holiday, hymn, ballad.
- Lyrics MUST be public domain (traditional or published before 1929). Use the standard public-domain text only. No modern copyrighted adaptations.
- 8–16 lines per song (pick the best-known verse(s) + chorus; skip offensive/dated verses). One line = one sung phrase, max ~12 words.
- `vi`: natural, accurate Vietnamese translation of that line (full diacritics).
- `keywords`: 5–8 useful vocabulary words (lowercase base form) that appear in the lyrics, suited to the level.
- UTF-8, valid JSON, 2-space indent. No timestamps (generated later).
