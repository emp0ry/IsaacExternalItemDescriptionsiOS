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

    def test_advanced_standard_repentance_tables_are_bundled(self) -> None:
        self.assertGreaterEqual(len(self.payload["luck_formulas"]), 40)
        self.assertGreaterEqual(len(self.payload["golden_trinket_data"]), 70)
        self.assertEqual(self.payload["golden_trinket_data"]["35"], 2)
        english = self.payload["languages"]["en_us"]
        self.assertTrue(english["golden_trinket_effects"]["53"])
        self.assertIn("{1}", english["context_strings"]["LuckModifier"])
        self.assertIn("{1}", english["context_strings"]["VariableCharge"])
        self.assertIn("{1}", english["context_strings"]["GlitchedCrownToggleInfo"])

    def test_black_feather_metadata_and_language_fallback(self) -> None:
        self.assertEqual(self.payload["black_feather_metadata"], {
            "collectibles":[215,216,230,260,262,339,344,654], "trinkets":[17,22]})
        english = self.payload["languages"]["en_us"]["context_strings"]["BlackFeatherInformation"]
        self.assertIn("{1}", english)
        self.assertIn("{2}", english)
        for code, language in self.payload["languages"].items():
            text = language["context_strings"].get("BlackFeatherInformation",english)
            self.assertIn("{1}", text, code)
            self.assertIn("{2}", text, code)

    def test_abyss_standard_records_and_localized_previews(self) -> None:
        locusts = self.payload["abyss_locusts"]
        self.assertEqual(len(locusts), 17)
        self.assertEqual(locusts["149"][6], [4, 12])
        self.assertEqual(locusts["4"][12], 3)
        self.assertEqual(locusts["10"][0], 2)
        self.assertEqual(locusts["153"][0], 4)
        english = self.payload["languages"]["en_us"]["abyss_descriptions"]
        self.assertEqual(english["default"], "1 locust (1x Isaac's damage)")
        self.assertEqual(english["2"], "3 locusts (1x Isaac's damage)")
        self.assertEqual(english["4"], "1 big locust (3x Isaac's damage)")
        self.assertEqual(english["149"], "1 big slow locust (1.5x Isaac's damage)#poison")
        self.assertEqual(english["494"], "1 locust (1x Isaac's damage)#electricity on hit")
        self.assertEqual(self.payload["languages"]["ru"]["abyss_descriptions"]["153"], "4 саранчи (1x урона персонажа)")
        self.assertIn("gafanhotos", self.payload["languages"]["pt_br"]["abyss_descriptions"]["2"])
        for code, language in self.payload["languages"].items():
            entries = language["abyss_descriptions"]
            self.assertEqual(set(entries), {"default", *locusts}, code)
            for text in entries.values():
                self.assertIsInstance(text, str)
                self.assertTrue(text, code)
                self.assertNotRegex(text, r"(?<!\{)\{(?:amount|size|speed|dmg|plural[^}]*|1)\}(?!\})")

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
