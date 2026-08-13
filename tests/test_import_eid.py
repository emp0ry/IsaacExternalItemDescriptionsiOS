#!/usr/bin/env python3
"""Focused tests for the user-supplied EID data importer."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "import-eid.py"
SPEC = importlib.util.spec_from_file_location("isaac_eid_importer", SCRIPT)
assert SPEC and SPEC.loader
IMPORTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMPORTER)


class ImportEIDTests(unittest.TestCase):
    def parse(
        self, body: str, names: set[str], *, pill_effect_ids: bool = False
    ) -> dict[int, dict[str, str]]:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "language.lua"
            path.write_text(body, encoding="utf-8")
            return IMPORTER.parse_description_table(path, names, pill_effect_ids=pill_effect_ids)

    def test_unkeyed_base_table(self) -> None:
        entries = self.parse(
            'EID.descriptions[languageCode].trinkets={\n'
            '  {"1", "Swallowed Penny", "{{Coin}} Description"},\n'
            '}\n',
            {"trinkets", "reptrinkets"},
        )
        self.assertEqual(entries[1]["name"], "Swallowed Penny")
        self.assertEqual(entries[1]["description"], "{{Coin}} Description")

    def test_keyed_repentance_override_and_unicode(self) -> None:
        entries = self.parse(
            'local repCards={\n'
            '  [97] = {"97", "Душа Иакова и Исава", "Создаёт Иакова"},\n'
            '}\n',
            {"cards", "repcards"},
        )
        self.assertEqual(entries[97]["name"], "Душа Иакова и Исава")
        self.assertEqual(entries[97]["description"], "Создаёт Иакова")

    def test_parser_stops_at_end_of_selected_table(self) -> None:
        entries = self.parse(
            'EID.descriptions[languageCode].collectibles={\n'
            '  {"1", "One", "First"},\n'
            '}\n'
            'EID.descriptions[languageCode].cards={\n'
            '  {"2", "Two", "Second"},\n'
            '}\n',
            {"collectibles", "repcollectibles"},
        )
        self.assertEqual(set(entries), {1})

    def test_pill_effect_ids_are_adjusted_for_lookup(self) -> None:
        entries = self.parse(
            'EID.descriptions[languageCode].pills={\n'
            '  {"0", "Bad Gas", "Poisons nearby enemies"},\n'
            '}\n',
            {"pills", "reppills"},
            pill_effect_ids=True,
        )
        self.assertEqual(entries[1]["name"], "Bad Gas")

    def test_explicit_repentance_pill_keys_override_shifted_effect_ids(self) -> None:
        entries = self.parse(
            'local repPills={\n'
            '  [42] = {"3", "Explicit Override", "Uses the explicit table key"},\n'
            '  [9999] = {"", "Golden Pill", "Triggers random pill effects"},\n'
            '}\n',
            {"pills", "reppills"},
            pill_effect_ids=True,
        )
        self.assertEqual(entries[42]["name"], "Explicit Override")
        self.assertEqual(entries[9999]["name"], "Golden Pill")

    def test_description_text_is_not_truncated(self) -> None:
        description = "A complete description " * 40
        entries = self.parse(
            'EID.descriptions[languageCode].collectibles={\n'
            f'  {{"1", "One", "{description}"}},\n'
            '}\n',
            {"collectibles", "repcollectibles"},
        )
        self.assertEqual(entries[1]["description"], description)


if __name__ == "__main__":
    unittest.main()
