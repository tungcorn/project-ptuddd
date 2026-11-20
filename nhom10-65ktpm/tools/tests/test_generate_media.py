"""Regression tests for TTS orchestration, without SAPI or real media writes.

Run: python -I -m unittest discover -s nhom10-65ktpm/tools/tests -v
Rendering dependencies and build_song are mocked; all writes use a temp tree.
"""
from __future__ import annotations

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

TOOLS = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("generate_media_under_test", TOOLS / "generate_media.py")
media = importlib.util.module_from_spec(SPEC)
# These tests exercise selection/catalog preservation, not audio/image rendering.
with patch.dict(sys.modules, {"numpy": Mock(), "PIL": Mock()}):
    SPEC.loader.exec_module(media)


class RecordingProtectionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="singlearn-media-test-")
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.songs = root / "songs"
        self.songs.mkdir()
        self.outputs = {name: root / name for name in ("audio", "lyrics", "covers")}
        for folder in self.outputs.values():
            folder.mkdir()
        self.catalog = root / "catalog.json"
        self.original_entries = json.loads(media.CATALOG.read_text(encoding="utf-8"))["songs"]
        self.clips = json.loads((TOOLS / "learning_clips.json").read_text(encoding="utf-8"))
        self.recordings = json.loads((TOOLS / "recordings.json").read_text(encoding="utf-8"))
        self.clip_ids = {entry["id"] for entry in self.clips}
        self.protected = self.clip_ids | {entry["id"] for entry in self.recordings}
        self.assertEqual(self.clip_ids, {
            "coffee-learning-clip", "learn-to-fly-learning-clip", "little-tomcat-learning-clip",
        })
        self.assertTrue(self.protected <= {entry["id"] for entry in self.original_entries})
        self.catalog.write_text(json.dumps({"version": 1, "songs": self.original_entries}), encoding="utf-8")
        for song_id in self.protected | {"synthetic-demo"}:
            (self.songs / f"{song_id}.json").write_text(json.dumps({"id": song_id}), encoding="utf-8")
        self.original_files = {}
        for song_id in self.protected:
            for kind, ext in (("audio", "mp3"), ("lyrics", "lrc"), ("covers", "png")):
                path = self.outputs[kind] / f"{song_id}.{ext}"
                original = f"original:{song_id}:{kind}".encode()
                path.write_bytes(original)
                self.original_files[path] = original
        for attr, value in {
            "SONGS_DIR": self.songs,
            "AUDIO_DIR": self.outputs["audio"],
            "LRC_DIR": self.outputs["lyrics"],
            "COVER_DIR": self.outputs["covers"],
            "CATALOG": self.catalog,
        }.items():
            patcher = patch.object(media, attr, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def fake_build(self, song, tmp):
        song_id = song["id"]
        for kind, ext in (("audio", "mp3"), ("lyrics", "lrc"), ("covers", "png")):
            (self.outputs[kind] / f"{song_id}.{ext}").write_bytes(b"regenerated TTS fixture")
        return {"id": song_id, "title": song_id, "level": "A1", "durationMs": 1000,
                "license": "synthetic test metadata"}

    def assert_recordings_unchanged(self):
        for path, original in self.original_files.items():
            with self.subTest(file=path.name):
                self.assertEqual(path.read_bytes(), original)

    def run_main(self, *selected):
        with patch.object(sys, "argv", ["generate_media.py", *selected]), \
                patch.object(media, "build_song", side_effect=self.fake_build) as build, \
                contextlib.redirect_stdout(io.StringIO()):
            media.main()
        return build

    def test_full_generation_preserves_real_media_and_catalog_entries(self):
        build = self.run_main()
        self.assertEqual([call.args[0]["id"] for call in build.call_args_list], ["synthetic-demo"])
        self.assert_recordings_unchanged()
        entries = json.loads(self.catalog.read_text(encoding="utf-8"))["songs"]
        by_id = {entry["id"]: entry for entry in entries}
        for original in self.original_entries:
            if original["id"] in self.protected:
                with self.subTest(song=original["id"]):
                    self.assertEqual(by_id[original["id"]], original)
        self.assertEqual(len(entries), len(self.protected) + 1)
        self.assertEqual(by_id["synthetic-demo"]["license"], "synthetic test metadata")

    def test_explicit_learning_clip_ids_are_not_regenerated(self):
        before = self.catalog.read_bytes()
        build = self.run_main(*sorted(self.clip_ids))
        build.assert_not_called()
        self.assert_recordings_unchanged()
        self.assertEqual(self.catalog.read_bytes(), before)

    def test_explicit_legacy_recordings_remain_protected(self):
        before = self.catalog.read_bytes()
        build = self.run_main(*(entry["id"] for entry in self.recordings))
        build.assert_not_called()
        self.assert_recordings_unchanged()
        self.assertEqual(self.catalog.read_bytes(), before)


if __name__ == "__main__":
    unittest.main()
