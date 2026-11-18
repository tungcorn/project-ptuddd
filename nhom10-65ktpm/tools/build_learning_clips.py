"""Rebuild only the licensed learning excerpts; never synthesize vocals.

From the group folder: python tools/build_learning_clips.py
Needs ffmpeg/ffprobe on PATH, numpy and Pillow (same cover generator as before).
Download originals separately as documented in docs/noi-dung-bai-hat.md.
Stored timestamps were derived from faster-whisper small word alignment;
listen and adjust learning_clips.json when reviewing lyric synchronization.
"""
from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

from generate_media import make_cover

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / "src/assets"


def stamp(seconds: float) -> str:
    cs = round(seconds * 100)
    minutes, remainder = divmod(cs, 6000)
    return f"[{minutes:02d}:{remainder // 100:02d}.{remainder % 100:02d}]"


def main() -> None:
    manifest = json.loads((ROOT / "tools/learning_clips.json").read_text(encoding="utf-8"))
    catalog_path = ASSETS / "content/catalog.json"
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    prepared = []
    # Validate every original before writing any assets.
    for entry in manifest:
        sid = entry["id"]
        source = ROOT / entry["file"]
        song = json.loads((ASSETS / f"content/songs/{sid}.json").read_text(encoding="utf-8"))
        if hashlib.sha256(source.read_bytes()).hexdigest() != entry["sha256"]:
            raise ValueError(f"{sid}: original SHA-256 mismatch; review source before rebuilding")
        starts = entry["lineStartsSec"]
        if not (len(starts) == len(song["lines"]) and
                entry["startSec"] <= starts[0] and
                all(a < b for a, b in zip(starts, starts[1:])) and
                starts[-1] < entry["lineEndSec"] < entry["endSec"]):
            raise ValueError(f"{sid}: invalid line count or excerpt boundaries")
        source_duration = float(subprocess.check_output([
            "ffprobe", "-v", "error", "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1", str(source)
        ], text=True))
        if not (0 <= entry["startSec"] < entry["endSec"] <= source_duration):
            raise ValueError(f"{sid}: excerpt outside source recording")
        prepared.append((entry, song, source))

    for entry, song, source in prepared:
        sid = entry["id"]
        duration = entry["endSec"] - entry["startSec"]
        audio = ASSETS / f"audio/{sid}.mp3"
        filters = (f"atrim=start={entry['startSec']}:end={entry['endSec']},"
                   f"asetpts=PTS-STARTPTS,afade=t=in:st=0:d=0.1,"
                   f"afade=t=out:st={duration - 2}:d=2")
        subprocess.run([
            "ffmpeg", "-v", "error", "-y", "-i", str(source), "-map_metadata", "-1",
            "-vn", "-af", filters, "-ar", "44100", "-ac", "1",
            "-c:a", "libmp3lame", "-b:a", "96k",
            "-metadata", f"title={song['title']}",
            "-metadata", f"artist={entry['performer']}",
            "-metadata", f"copyright={entry['license']} {entry['licenseUrl']}",
            "-metadata", f"comment=Excerpt from {entry['sourceUrl']}", str(audio)
        ], check=True)
        lrc = [f"[ti:{song['title']}]", f"[ar:{song['artist']}]",
               "[by:SingLearn - Nhom 10 (faster-whisper small alignment)]"]
        lrc += [stamp(start - entry["startSec"]) + line["en"]
                for start, line in zip(entry["lineStartsSec"], song["lines"])]
        lrc.append(stamp(entry["lineEndSec"] - entry["startSec"]))
        (ASSETS / f"lyrics/{sid}.lrc").write_text("\n".join(lrc) + "\n", encoding="utf-8")
        color = make_cover(song, ASSETS / f"covers/{sid}.png")
        item = {key: song[key] for key in ("id", "title", "artist", "level", "topics", "genre", "keywords")}
        item.update({
            "durationMs": round(duration * 1000),
            "audio": f"assets/audio/{sid}.mp3",
            "lrc": f"assets/lyrics/{sid}.lrc",
            "cover": f"assets/covers/{sid}.png", "color": color,
            "license": (f"Lời: {song['lyricsSource']}. Bản thu: {entry['performer']} — "
                        f"{entry['license']} ({entry['licenseUrl']}); {entry['sourceUrl']}. "
                        f"Đoạn {entry['startSec']:g}–{entry['endSec']:g} giây của bản gốc; "
                        "Nhóm 10 cắt đoạn, chuyển mã MP3 mono 96 kbps và thêm fade."),
            "recording": {key: entry[key] for key in ("performer", "license", "licenseUrl", "sourceUrl")},
            "translations": [line["vi"] for line in song["lines"]],
        })
        index = next((i for i, s in enumerate(catalog["songs"]) if s["id"] == sid), None)
        if index is None:
            catalog["songs"].append(item)
        else:
            catalog["songs"][index] = item
        print(f"{sid}: {duration:g}s, {len(song['lines'])} lines, {audio.stat().st_size} bytes")
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
