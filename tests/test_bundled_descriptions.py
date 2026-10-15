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
        self.assertEqual(len(english["dice"]), 6)
        self.assertEqual(len(english["sacrifice"]), 12)
        self.assertEqual(english["strings"]["unidentified_pill"], "Unidentified Pill")
        self.assertEqual(
            self.payload["languages"]["ru"]["strings"]["unidentified_pill"],
            "Неизвестная пилюля",
        )
        self.assertEqual(english["dice"]["4"]["name"], "Dice Room effects (4/6)")
        self.assertEqual(
            english["sacrifice"]["1"]["name"],
            "Next Sacrifice Room payout (1/12)",
        )

    def test_room_titles_do_not_keep_markup_brackets(self) -> None:
        for language in self.payload["languages"].values():
            for category in ("dice", "sacrifice"):
                for entry in language[category].values():
                    self.assertFalse(entry["name"].startswith("["))

    def test_pill_synergy_and_collection_reference_strings(self) -> None:
        for code in ("en_us", "ru"):
            strings = self.payload["languages"][code]["context_strings"]
            for key in ("CollectionPageInfo", "FalsePHDHeart", "FalsePHDDamage",
                        "FalsePHDHorseDamage", "ExperimentalPillPHD", "ExperimentalPillFalsePHD"):
                self.assertTrue(strings[key], (code, key))
        self.assertEqual(len(self.payload["pill_metadata"]), 50)
        self.assertEqual(self.payload["pill_metadata"]["15"]["class"], "3-")
        self.assertEqual(self.payload["pill_metadata"]["47"]["class"], "1-")

    def test_extended_character_metadata_and_reference_tables_are_bundled(self) -> None:
        english = self.payload["languages"]["en_us"]
        metadata = self.payload["character_metadata"]
        self.assertEqual(set(metadata["tainted_ids"]), set(range(21,41)))
        self.assertGreaterEqual(len(metadata["wisps"]), 165)
        self.assertEqual(metadata["wisps"]["35"][2], 4)
        self.assertTrue(metadata["wisp_flags"]["NoWisp"]["636"])
        self.assertNotIn("111",metadata["wisp_flags"]["SingleRoom"])  # Repentance+ only.
        self.assertEqual(len(english["book_of_belial"]), 32)
        self.assertIn("Tainted Lilith",english["BFFSSynergies"])
        self.assertIn("NoWisps",english["wisp_texts"])
        self.assertEqual(metadata["salvage_pools"]["3"],"5.10.6")

    def test_birthright_names_match_native_character_ids_not_lua_array_indices(self) -> None:
        names = ["Isaac", "Magdalene", "Cain", "Judas", "???", "Eve", "Samson", "Azazel",
                 "Lazarus", "Eden", "The Lost", "Lazarus Risen", "Black Judas", "Lilith", "Keeper",
                 "Apollyon", "The Forgotten", "The Forgotten Soul", "Bethany", "Jacob", "Esau",
                 "Tainted Isaac", "Tainted Magdalene", "Tainted Cain", "Tainted Judas", "Tainted ???",
                 "Tainted Eve", "Tainted Samson", "Tainted Azazel", "Tainted Lazarus", "Tainted Eden",
                 "Tainted Lost", "Tainted Lilith", "Tainted Keeper", "Tainted Apollyon", "Tainted Forgotten",
                 "Tainted Bethany", "Tainted Jacob", "Dead Tainted Lazarus", "Tainted Jacob's Soul",
                 "Tainted Forgotten Soul"]
        english = self.payload["languages"]["en_us"]["birthright"]
        self.assertEqual(set(english), {str(index) for index in range(41)})
        for identifier, name in enumerate(names):
            self.assertEqual(english[str(identifier)][0], name)
        russian = self.payload["languages"]["ru"]["birthright"]
        self.assertEqual(russian["0"][0], "Исаак")
        self.assertEqual(russian["9"][0], "Эдем")
        self.assertEqual(russian["10"][0], "Потерянный")
        self.assertEqual(russian["14"][0], "Хранитель")


if __name__ == "__main__":
    unittest.main()
