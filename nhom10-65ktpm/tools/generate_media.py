"""Generate SingLearn demo media from song content JSON.

For every song without a source recording in ``src/assets/content/songs/<id>.json``
this script produces:

* ``src/assets/audio/<id>.mp3`` – a self-made recording: a synthesized
  backing track (chords, bass, light percussion) plus every lyric line read
  by the Windows SAPI text-to-speech voice, each line starting on a bar.
* ``src/assets/lyrics/<id>.lrc`` – LRC lyrics whose timestamps are the exact
  positions where each line was placed in the mix (so sync is correct by
  construction, not hand-estimated).
* ``src/assets/covers/<id>.png`` – a generated cover image.
* ``src/assets/content/catalog.json`` – song metadata index used by the app.

Requirements: Windows (System.Speech), Python 3.10+, numpy, lameenc, pillow.
Run from the ``nhom10-65ktpm`` folder:

    python tools/generate_media.py

Songs registered in ``tools/recordings.json`` or ``tools/learning_clips.json``
are excluded, including when explicitly selected on the command line.
The lyrics used for TTS are public domain; the generated audio/covers are original
work of Nhóm 10 and released under CC BY 4.0 together with the app.
"""

from __future__ import annotations

import colorsys
import hashlib
import json
import math
import os
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
SONGS_DIR = SRC / "assets" / "content" / "songs"
AUDIO_DIR = SRC / "assets" / "audio"
LRC_DIR = SRC / "assets" / "lyrics"
COVER_DIR = SRC / "assets" / "covers"
CATALOG = SRC / "assets" / "content" / "catalog.json"

SR = 22050
LEVEL_TTS_RATE = {"A1": -3, "A2": -2, "B1": -1, "B2": 0}
LEVEL_BPM = {"A1": 84, "A2": 92, "B1": 96, "B2": 100}
INTRO_BARS = 2
OUTRO_BARS = 2
RECORDING_LICENSE = (
    "Bản ghi do Nhóm 10 tự tạo (nhạc nền tổng hợp + giọng đọc TTS), CC BY 4.0"
)

# Chord progressions as semitone offsets of the chord root from the key.
PROGRESSIONS = [
    [0, 7, 9, 5],  # I V vi IV
    [0, 5, 7, 0],  # I IV V I
    [0, 9, 5, 7],  # I vi IV V
    [0, 5, 0, 7],  # I IV I V
]
MINOR_ROOTS = {9, 2, 4}  # vi, ii, iii are minor in a major key


def seed_of(song_id: str) -> int:
    return int(hashlib.sha1(song_id.encode()).hexdigest()[:8], 16)


# --------------------------------------------------------------------------- TTS
def synthesize_lines(lines: list[str], voice: str, rate: int, out_dir: Path) -> list[Path]:
    """Render every line to its own 22.05 kHz mono WAV with Windows SAPI."""
    script_lines = [
        "Add-Type -AssemblyName System.Speech",
        "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer",
        f"$s.SelectVoice('{voice}')",
        f"$s.Rate = {rate}",
        "$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo("
        f"{SR}, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, "
        "[System.Speech.AudioFormat.AudioChannel]::Mono)",
    ]
    paths = []
    for i, text in enumerate(lines):
        path = out_dir / f"line_{i:02d}.wav"
        paths.append(path)
        safe = text.replace("'", "''")
        script_lines += [
            f"$s.SetOutputToWaveFile('{path}', $fmt)",
            f"$s.Speak('{safe}')",
        ]
    script_lines.append("$s.Dispose()")
    ps1 = out_dir / "tts.ps1"
    ps1.write_text("\n".join(script_lines), encoding="utf-8-sig")
    subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(ps1)],
        check=True,
    )
    return paths


def read_wav(path: Path) -> np.ndarray:
    with wave.open(str(path), "rb") as w:
        assert w.getframerate() == SR and w.getnchannels() == 1
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)
    audio = data.astype(np.float32) / 32768.0
    # Trim leading/trailing silence so placement is tight.
    idx = np.where(np.abs(audio) > 0.01)[0]
    if len(idx) == 0:
        return audio
    return audio[max(0, idx[0] - 200): idx[-1] + 400]


# ----------------------------------------------------------------------- music
def midi_to_hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


def tone(freq: float, dur: float, kind: str = "pad") -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    if kind == "pad":
        sig = (np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(4 * np.pi * freq * t)
               + 0.12 * np.sin(6 * np.pi * freq * t))
        attack = np.minimum(1.0, t / 0.25)
        release = np.minimum(1.0, (dur - t) / 0.35)
        env = np.clip(attack * release, 0, 1)
    elif kind == "pluck":
        sig = np.sin(2 * np.pi * freq * t) + 0.5 * np.sin(4 * np.pi * freq * t)
        env = np.exp(-t * 5.0)
    else:  # bass
        sig = np.sin(2 * np.pi * freq * t) + 0.2 * np.sin(4 * np.pi * freq * t)
        env = np.exp(-t * 2.2) * np.minimum(1.0, t / 0.01)
    return (sig * env).astype(np.float32)


def drum(kind: str) -> np.ndarray:
    if kind == "kick":
        dur = 0.18
        t = np.arange(int(dur * SR)) / SR
        f = 110 * np.exp(-t * 25) + 45
        return (np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 18)).astype(np.float32)
    dur = 0.05
    t = np.arange(int(dur * SR)) / SR
    rng = np.random.default_rng(7)
    return (rng.uniform(-1, 1, len(t)) * np.exp(-t * 90) * 0.35).astype(np.float32)


def backing_track(n_bars: int, bpm: int, key: int, prog: list[int]) -> np.ndarray:
    beat = 60.0 / bpm
    bar = 4 * beat
    total = np.zeros(int((n_bars * bar + 1.0) * SR), dtype=np.float32)
    kick, hat = drum("kick"), drum("hat")

    def add(sig: np.ndarray, at: float, gain: float) -> None:
        i = int(at * SR)
        j = min(len(total), i + len(sig))
        total[i:j] += sig[: j - i] * gain

    for b in range(n_bars):
        root_off = prog[b % len(prog)]
        minor = (root_off % 12) in MINOR_ROOTS
        root = 48 + key + root_off  # around C3
        third = root + (3 if minor else 4)
        fifth = root + 7
        start = b * bar
        for note in (root + 12, third + 12, fifth + 12):
            add(tone(midi_to_hz(note), bar, "pad"), start, 0.05)
        for k in range(4):  # bass on every beat, root/fifth alternating
            add(tone(midi_to_hz(root - 12 + (7 if k % 2 else 0)), beat, "bass"), start + k * beat, 0.16)
        arp = [root + 24, third + 24, fifth + 24, third + 24]
        for k in range(8):  # eighth-note arpeggio
            add(tone(midi_to_hz(arp[k % 4]), beat / 2, "pluck"), start + k * beat / 2, 0.035)
        for k in range(4):
            if k % 2 == 0:
                add(kick, start + k * beat, 0.32)
            add(hat, start + k * beat + beat / 2, 0.5)
    return total


# ---------------------------------------------------------------------- covers
TOPIC_EMOJI_FREE_LABEL = {
    "nursery": "Thiếu nhi", "folk": "Dân ca", "holiday": "Lễ hội",
    "hymn": "Thánh ca", "ballad": "Ballad",
    "pop-rock": "Pop Rock", "acoustic": "Acoustic",
}


def make_cover(song: dict, path: Path) -> str:
    seed = seed_of(song["id"])
    hue = (seed % 360) / 360.0
    c1 = colorsys.hsv_to_rgb(hue, 0.55, 0.85)
    c2 = colorsys.hsv_to_rgb((hue + 0.12) % 1, 0.75, 0.45)
    size = 320
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            k = (x + y) / (2 * size)
            px[x, y] = tuple(int(255 * (c1[i] * (1 - k) + c2[i] * k)) for i in range(3))
    draw = ImageDraw.Draw(img)
    # Decorative circles (like vinyl rings).
    cx, cy = size * 0.78, size * 0.25
    for r in range(18, 110, 14):
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255, 60), width=2)
    fonts = Path(os.environ.get("WINDIR", "C:/Windows")) / "Fonts"
    title_font = ImageFont.truetype(str(fonts / "segoeuib.ttf"), 30)
    small_font = ImageFont.truetype(str(fonts / "segoeui.ttf"), 20)
    words = song["title"].split()
    lines, cur = [], ""
    for w in words:
        test = (cur + " " + w).strip()
        if draw.textlength(test, font=title_font) > size - 40:
            lines.append(cur)
            cur = w
        else:
            cur = test
    lines.append(cur)
    y = size - 40 - 36 * len(lines) - 30
    for ln in lines:
        draw.text((20, y), ln, font=title_font, fill="white")
        y += 36
    draw.text((20, size - 50), f"{song['level']} · {TOPIC_EMOJI_FREE_LABEL[song['genre']]}",
              font=small_font, fill=(255, 255, 255))
    img.save(path, optimize=True)
    return "#%02x%02x%02x" % tuple(int(255 * v) for v in c2)


# ------------------------------------------------------------------------ main
def fmt_lrc(ms: int) -> str:
    m, rem = divmod(ms, 60000)
    s, cs = divmod(rem, 1000)
    return f"[{m:02d}:{s:02d}.{cs // 10:02d}]"


def build_song(song: dict, tmp: Path) -> dict:
    # Cover-only callers do not need the optional TTS MP3 encoder.
    import lameenc

    level = song["level"]
    seed = seed_of(song["id"])
    voice = "Microsoft Zira Desktop" if seed % 2 == 0 else "Microsoft David Desktop"
    bpm = LEVEL_BPM[level]
    bar = 4 * 60.0 / bpm
    key = seed % 7  # C..F#
    prog = PROGRESSIONS[seed % len(PROGRESSIONS)]

    texts = [ln["en"] for ln in song["lines"]]
    wavs = [read_wav(p) for p in synthesize_lines(texts, voice, LEVEL_TTS_RATE[level], tmp)]

    placements = []
    cursor_bar = INTRO_BARS
    for w in wavs:
        dur = len(w) / SR
        bars = max(1, math.ceil((dur + 0.7) / bar))
        placements.append((cursor_bar, bars))
        cursor_bar += bars
    n_bars = cursor_bar + OUTRO_BARS
    mix = backing_track(n_bars, bpm, key, prog)
    vocal = np.zeros_like(mix)
    starts_ms = []
    for (b, _), w in zip(placements, wavs):
        at = b * bar + 0.08
        i = int(at * SR)
        vocal[i:i + len(w)] += w
        starts_ms.append(int(b * bar * 1000))
    # Duck the backing track while the voice is present.
    env = np.convolve(np.abs(vocal), np.ones(2048) / 2048, mode="same")
    duck = 1.0 - 0.45 * np.clip(env * 12, 0, 1)
    out = mix * duck * 0.9 + vocal * 1.15
    end = int((n_bars * bar + 0.5) * SR)
    out = out[:end]
    fade = int(1.5 * SR)
    out[-fade:] *= np.linspace(1, 0, fade)
    out /= max(1e-6, float(np.max(np.abs(out)))) / 0.92
    pcm = (out * 32767).astype(np.int16)

    enc = lameenc.Encoder()
    enc.set_bit_rate(48)
    enc.set_in_sample_rate(SR)
    enc.set_channels(1)
    enc.set_quality(2)
    mp3 = enc.encode(pcm.tobytes()) + enc.flush()
    (AUDIO_DIR / f"{song['id']}.mp3").write_bytes(mp3)

    duration_ms = int(len(pcm) / SR * 1000)
    lrc = [
        f"[ti:{song['title']}]",
        f"[ar:{song['artist']}]",
        f"[length:{duration_ms // 60000:02d}:{duration_ms // 1000 % 60:02d}]",
        "[by:SingLearn - Nhom 10]",
    ]
    lrc += [f"{fmt_lrc(ms)}{t}" for ms, t in zip(starts_ms, texts)]
    lrc.append(f"{fmt_lrc(int(n_bars * bar * 1000) - int(OUTRO_BARS * bar * 1000))}")
    (LRC_DIR / f"{song['id']}.lrc").write_text("\n".join(lrc) + "\n", encoding="utf-8")

    color = make_cover(song, COVER_DIR / f"{song['id']}.png")
    return {
        "id": song["id"],
        "title": song["title"],
        "artist": song["artist"],
        "level": level,
        "topics": song["topics"],
        "genre": song["genre"],
        "durationMs": duration_ms,
        "audio": f"assets/audio/{song['id']}.mp3",
        "lrc": f"assets/lyrics/{song['id']}.lrc",
        "cover": f"assets/covers/{song['id']}.png",
        "color": color,
        "license": f"Lời: {song['lyricsSource']}. {RECORDING_LICENSE}.",
        "keywords": song["keywords"],
        "translations": [ln["vi"] for ln in song["lines"]],
    }


def main() -> None:
    for d in (AUDIO_DIR, LRC_DIR, COVER_DIR):
        d.mkdir(parents=True, exist_ok=True)
    only = set(sys.argv[1:])
    songs = [json.loads(p.read_text(encoding="utf-8")) for p in sorted(SONGS_DIR.glob("*.json"))]
    # Both aligned recordings and licensed learning clips have real audio.
    # Never regenerate their audio/LRC/covers or replace their catalog entries.
    real = set()
    for name in ("recordings.json", "learning_clips.json"):
        manifest = Path(__file__).with_name(name)
        if manifest.exists():
            real.update(e["id"] for e in json.loads(manifest.read_text(encoding="utf-8")))
    old = json.loads(CATALOG.read_text(encoding="utf-8"))["songs"] if CATALOG.exists() else []
    catalog = [e for e in old if e["id"] in real] if not only else []
    for song in songs:
        if song["id"] in real or (only and song["id"] not in only):
            continue
        with tempfile.TemporaryDirectory() as tmp:
            entry = build_song(song, Path(tmp))
        catalog.append(entry)
        print(f"{song['id']}: {entry['durationMs'] / 1000:.1f}s", flush=True)
    if not only:
        level_order = {"A1": 0, "A2": 1, "B1": 2, "B2": 3}
        catalog.sort(key=lambda e: (level_order[e["level"]], e["title"]))
        CATALOG.write_text(json.dumps({"version": 1, "songs": catalog}, ensure_ascii=False, indent=1),
                           encoding="utf-8")


if __name__ == "__main__":
    main()
