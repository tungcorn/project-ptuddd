"""Import real (open-licence) recordings and auto-sync their LRC lyrics.

For every entry of ``tools/recordings.json``:

1. Decode the source recording (any format PyAV/FFmpeg reads: ogg, flac,
   mp3, wav...), down-mix to mono and re-encode it as MP3 into
   ``src/assets/audio/<id>.mp3``.
2. Run faster-whisper with word timestamps (the song's lyrics are passed as
   the initial prompt so the singing is recognised as those words).
3. Align the recognised words with the canonical lyric lines of
   ``src/assets/content/songs/<id>.json`` (difflib sequence alignment on
   normalised tokens). Each line starts at its first matched word; lines
   without a match are interpolated between their neighbours.
4. Write ``src/assets/lyrics/<id>.lrc`` and update the song's entry in
   ``src/assets/content/catalog.json`` (duration, licence, credits).

A per-song report (share of lyric words matched) is printed; songs below
``--min-match`` are left untouched so they can be checked by hand.

Usage (from the repo's ``nhom10-65ktpm`` folder)::

    python tools/align_recordings.py                # all entries
    python tools/align_recordings.py jingle-bells   # some ids
    python tools/align_recordings.py --dry-run jingle-bells

Requires: ``pip install faster-whisper lameenc numpy``.
"""
from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from pathlib import Path

import av
import lameenc
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
SONGS = SRC / "assets" / "content" / "songs"
CATALOG = SRC / "assets" / "content" / "catalog.json"
AUDIO_DIR = SRC / "assets" / "audio"
LRC_DIR = SRC / "assets" / "lyrics"
MANIFEST = ROOT / "tools" / "recordings.json"
SR = 16000  # whisper input rate
OUT_SR = 44100


def norm(word: str) -> str:
    w = word.lower().replace("’", "'")
    w = re.sub(r"[^a-z0-9']", "", w)
    return w.strip("'")


def tokens(text: str) -> list[str]:
    return [t for t in (norm(w) for w in re.split(r"[\s\-–—]+", text)) if t]


def decode(path: Path, rate: int) -> np.ndarray:
    """Decodes any audio file to mono float32 at [rate]."""
    chunks = []
    with av.open(str(path)) as f:
        stream = f.streams.audio[0]
        res = av.AudioResampler(format="flt", layout="mono", rate=rate)
        for packet in f.demux(stream):
            try:
                frames = packet.decode()
            except av.error.InvalidDataError:
                continue  # skip a corrupt packet instead of failing the file
            for frame in frames:
                for r in res.resample(frame):
                    chunks.append(r.to_ndarray().reshape(-1))
        for r in res.resample(None):
            chunks.append(r.to_ndarray().reshape(-1))
    return np.concatenate(chunks).astype(np.float32)


def trim(pcm: np.ndarray, rate: int, end_sec: float | None) -> np.ndarray:
    if not end_sec:
        return pcm
    out = pcm[: int(end_sec * rate)].copy()
    fade = min(len(out), int(2.0 * rate))
    out[-fade:] *= np.linspace(1.0, 0.0, fade, dtype=np.float32)
    return out


def encode_mp3(pcm: np.ndarray, out: Path, kbps: int) -> int:
    peak = float(np.max(np.abs(pcm))) or 1.0
    pcm = pcm / peak * 0.95
    enc = lameenc.Encoder()
    enc.set_bit_rate(kbps)
    enc.set_in_sample_rate(OUT_SR)
    enc.set_channels(1)
    enc.set_quality(2)
    data = enc.encode((pcm * 32767).astype(np.int16).tobytes()) + enc.flush()
    out.write_bytes(data)
    return int(len(pcm) / OUT_SR * 1000)


def transcribe(model, audio16k: np.ndarray, prompt: str, condition: bool = True) -> list[tuple[str, float, float]]:
    segments, _ = model.transcribe(
        audio16k,
        language="en",
        word_timestamps=True,
        initial_prompt=prompt[:800],
        condition_on_previous_text=condition,
        vad_filter=False,
        beam_size=5,
    )
    words = []
    for seg in segments:
        for w in seg.words or []:
            t = norm(w.word)
            if t:
                words.append((t, float(w.start), float(w.end)))
    return words


def align(lines: list[str], words: list[tuple[str, float, float]]):
    """Returns (start seconds per line or None, matched ratio)."""
    lyric = []  # (token, line index)
    for i, ln in enumerate(lines):
        lyric += [(t, i) for t in tokens(ln)]
    rec = [w[0] for w in words]
    sm = difflib.SequenceMatcher(a=[t for t, _ in lyric], b=rec, autojunk=False)
    first = [None] * len(lines)
    matched = 0
    for a, b, n in sm.get_matching_blocks():
        for k in range(n):
            li = lyric[a + k][1]
            matched += 1
            if first[li] is None:
                _, ws, we = words[b + k]
                # Whisper often stretches a line's first word back over the
                # preceding silence/intro; an over-long first word starts
                # roughly half a second before it ends.
                first[li] = we - 0.5 if we - ws > 0.7 else ws
    return first, matched / max(1, len(lyric))


def fill_gaps(starts: list[float | None], total: float) -> list[float]:
    n = len(starts)
    out = list(starts)
    known = [i for i, s in enumerate(out) if s is not None]
    if not known:
        return [total * i / (n + 1) for i in range(n)]
    for i in range(n):
        if out[i] is not None:
            continue
        prev = max((k for k in known if k < i), default=None)
        nxt = min((k for k in known if k > i), default=None)
        if prev is not None and nxt is not None:
            out[i] = out[prev] + (out[nxt] - out[prev]) * (i - prev) / (nxt - prev)
        elif prev is not None:
            out[i] = min(total - 1, out[prev] + 3.0 * (i - prev))
        else:
            out[i] = max(0.0, out[nxt] - 3.0 * (nxt - i))
    # Keep strictly increasing.
    for i in range(1, n):
        if out[i] <= out[i - 1]:
            out[i] = out[i - 1] + 0.5
    return out


def fmt(sec: float) -> str:
    ms = max(0, int(round(sec * 1000)))
    m, rem = divmod(ms, 60000)
    s, cs = divmod(rem, 1000)
    return f"[{m:02d}:{s:02d}.{cs // 10:02d}]"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--model", default="small.en")
    ap.add_argument("--device", default="cpu")
    ap.add_argument("--kbps", type=int, default=96)
    ap.add_argument("--min-match", type=float, default=0.5)
    ap.add_argument("--dry-run", action="store_true", help="only report alignment")
    ap.add_argument("--manifest", type=Path, default=MANIFEST)
    args = ap.parse_args()

    from faster_whisper import WhisperModel

    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    entries = [e for e in manifest if not args.ids or e["id"] in args.ids]
    try:
        model = WhisperModel(args.model, device=args.device,
                             compute_type="float16" if args.device == "cuda" else "int8")
    except Exception as e:  # CUDA libs missing -> CPU
        print(f"! {e}; falling back to CPU", file=sys.stderr)
        model = WhisperModel(args.model, device="cpu", compute_type="int8")

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    by_id = {s["id"]: s for s in catalog["songs"]}
    failed = []
    for e in entries:
        sid = e["id"]
        song = json.loads((SONGS / f"{sid}.json").read_text(encoding="utf-8"))
        lines = [ln["en"] for ln in song["lines"]]
        src = (ROOT / e["file"]).resolve()
        end_sec = e.get("endSec")  # optional: cut a medley / trailing part
        a16 = trim(decode(src, SR), SR, end_sec)
        total = len(a16) / SR
        words = transcribe(model, a16, " ".join(lines), not e.get("noContext", False))
        # optional: ignore (hallucinated) words inside an instrumental intro
        words = [w for w in words if w[1] >= e.get("vocalStart", 0)]
        starts, ratio = align(lines, words)
        unmatched = sum(1 for s in starts if s is None)
        print(f"{sid:40s} match={ratio:5.0%} lines_without_match={unmatched}/{len(lines)} "
              f"dur={total:5.1f}s words={len(words)}")
        if ratio < e.get("minMatch", args.min_match):
            failed.append(sid)
            print("  ! below --min-match, skipped. Heard: "
                  + " ".join(f"{w[0]}@{w[1]:.0f}" for w in words[:160]))
            continue
        starts = fill_gaps(starts, total)
        if args.dry_run:
            for s, ln in zip(starts, lines):
                print(f"   {fmt(s)} {ln}")
            continue
        dur_ms = encode_mp3(trim(decode(src, OUT_SR), OUT_SR, end_sec), AUDIO_DIR / f"{sid}.mp3", args.kbps)
        lrc = [
            f"[ti:{song['title']}]",
            f"[ar:{song['artist']}]",
            f"[length:{dur_ms // 60000:02d}:{dur_ms // 1000 % 60:02d}]",
            "[by:SingLearn - Nhom 10 (auto-aligned, faster-whisper)]",
        ]
        lrc += [f"{fmt(s)}{ln}" for s, ln in zip(starts, lines)]
        # End marker: last line ends at the last recognised word (or +4 s).
        last_word = max((w[2] for w in words), default=starts[-1] + 4)
        lrc.append(fmt(min(dur_ms / 1000, max(last_word, starts[-1]) + 1.0)))
        (LRC_DIR / f"{sid}.lrc").write_text("\n".join(lrc) + "\n", encoding="utf-8")
        entry = by_id.get(sid)
        if entry is None:  # new song: create its catalog entry and cover
            sys.path.insert(0, str(ROOT / "tools"))
            from generate_media import COVER_DIR, make_cover
            entry = {
                "id": sid,
                "cover": f"assets/covers/{sid}.png",
                "lrc": f"assets/lyrics/{sid}.lrc",
                "color": make_cover(song, COVER_DIR / f"{sid}.png"),
            }
            catalog["songs"].append(entry)
            by_id[sid] = entry
        for k in ("title", "artist", "level", "topics", "genre"):
            entry[k] = song[k]
        entry["durationMs"] = dur_ms
        entry["audio"] = f"assets/audio/{sid}.mp3"
        entry["license"] = (f"Lời: {song['lyricsSource']}. Bản thu: {e['performer']} – "
                            f"{e['license']} ({e['sourceUrl']}).")
        entry["recording"] = {k: e[k] for k in ("performer", "license", "sourceUrl")}
        entry["translations"] = [ln["vi"] for ln in song["lines"]]
        entry["keywords"] = song["keywords"]
    if not args.dry_run:
        CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    if failed:
        print("Needs manual check:", ", ".join(failed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
