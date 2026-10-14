#!/usr/bin/env python3
"""Regression checks for original EID's dynamically assigned stat icon aliases."""

import importlib.util
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "tools/import-eid-assets.py"
SPEC = importlib.util.spec_from_file_location("eid_asset_importer", SCRIPT)
IMPORTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMPORTER)


class InlineIconTests(unittest.TestCase):
    def test_all_stat_aliases_select_repentance_not_afterbirth_frames(self):
        lines = []
        for index, token in enumerate(IMPORTER.REPENTANCE_STAT_TOKENS):
            lines.extend((f'["{token}REP"] = {{"Stats", {index}, 10, 10}},',
                          f'["{token}AB"] = {{"Stats", {index+12}, 10, 10}},'))
        mapping = IMPORTER.parse_inline_icons("\n".join(lines))
        for index, token in enumerate(IMPORTER.REPENTANCE_STAT_TOKENS):
            self.assertEqual(mapping[token], {"animation":"Stats", "frame":index})
            self.assertEqual(mapping[token], mapping[token+"REP"])
            self.assertNotEqual(mapping[token], mapping[token+"AB"])

    def test_heart_and_quality_frames_stay_unchanged(self):
        mapping = IMPORTER.parse_inline_icons('["Heart"] = {"hearts", 0, 10, 9},')
        self.assertEqual(mapping["Heart"], {"animation":"hearts", "frame":0})
        self.assertEqual(mapping["Quality4"], {"animation":"Quality", "frame":4})
        self.assertNotIn("Damage", mapping)


if __name__ == "__main__":
    unittest.main()
