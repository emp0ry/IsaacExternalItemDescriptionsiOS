#!/usr/bin/env python3
"""Validate the attributed description database shipped in release artifacts."""

from __future__ import annotations

import json
import re
import unittest
from pathlib import Path


DATABASE = Path(__file__).resolve().parents[1] / "data" / "descriptions.json"
LANGUAGES = {
    "bul", "cs_cz", "de", "el_gr", "en_us", "spa", "fr", "it", "ja_jp",
    "ko_kr", "nl_nl", "pl", "pt", "pt_br", "ro_ro", "ru", "tr_tr",
    "uk_ua", "vi", "zh_cn",
}


class BundledDescriptionsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.payload = json.loads(DATABASE.read_text(encoding="utf-8"))

    def test_source_and_version_metadata(self) -> None:
        self.assertEqual(
            self.payload["source"],
            "https://github.com/wofsauge/External-Item-Descriptions",
        )
        self.assertRegex(self.payload["source_commit"], re.compile(r"^[0-9a-f]{40}$"))
        self.assertEqual(self.payload["game_version"], "rep")
        self.assertEqual(self.payload["compatible_isaac_version"], "1.7.9b")

    def test_all_upstream_languages_are_present(self) -> None:
        self.assertEqual(set(self.payload["languages"]), LANGUAGES)

    def test_english_reference_tables_are_complete(self) -> None:
        english = self.payload["languages"]["en_us"]
        self.assertEqual(len(english["collectibles"]), 732)
        self.assertEqual(len(english["trinkets"]), 189)
        self.assertEqual(len(english["cards"]), 97)
        self.assertEqual(len(english["pills"]), 51)
        self.assertEqual(len(english["horsepills"]), 51)


if __name__ == "__main__":
    unittest.main()
