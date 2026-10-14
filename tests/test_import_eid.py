#!/usr/bin/env python3
"""Focused tests for the user-supplied EID data importer."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "tools" / "import-eid.py"
sys.path.insert(0, str(SCRIPT.parent))
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

    def test_context_tables_preserve_markup_commas_and_multiline_pairs(self) -> None:
        from eid_context import table
        parsed = table('EID.descriptions[languageCode].RedToX = {\n'
                       ' ["Red to None"] = {"↑ {{Heart}} +{1}, Health", "",\n'
                       ' "quoted \\"text\\"", "replacement"}, -- ignored {\n'
                       '}\n', "RedToX")
        self.assertEqual(parsed["Red to None"],
                         ["↑ {{Heart}} +{1}, Health", "", 'quoted "text"', "replacement"])

    def test_context_tables_preserve_repentance_replace_semantics(self) -> None:
        from eid_context import table
        parsed = table('local repConditions = {\n'
                       ' ["5.100.549"] = {"↑ {{Tears}} +0.4 Fire rate"},\n'
                       '}\n', "repConditions")
        self.assertEqual(parsed["5.100.549"], ["↑ {{Tears}} +0.4 Fire rate"])

    def test_named_and_nested_tables_preserve_wisp_and_room_metadata(self) -> None:
        from eid_context import table
        self.assertEqual(table('EID.WispData = {SingleRoom = {[164] = true}, NoWisp = {[636] = true}}',
                               "WispData"), {"SingleRoom":{"164":True},"NoWisp":{"636":True}})
        self.assertEqual(table('EID.descriptions[languageCode].BookOfVirtuesWispTexts = '
                              '{StatDescription = "{ringIcon} {damage}", NoWisps = "No Wisps"}',
                              "BookOfVirtuesWispTexts")["NoWisps"], "No Wisps")
        self.assertEqual(table('EID.RoomTypeToMarkup = {"{{Room}}", --[[comment]] "{{Shop}}"}',
                               "RoomTypeToMarkup"), {"1":"{{Room}}","2":"{{Shop}}"})

    def test_character_rules_include_later_blocks_and_preserve_predicate_and_table(self) -> None:
        from eid_context import rules
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "features").mkdir()
            (root / "features/eid_data.lua").write_text('EID.TaintedToRegularID = {[23] = 2}', encoding="utf-8")
            (root / "features/eid_conditionals.lua").write_text(
                'EID:AddPlayerConditional(247, 13, "Lilith", {locTable = "BFFSSynergies"}, false)\n'
                '------ DUPLICATE COPIES OF ITEMS\n'
                '------ OVERRIDES / OVERRIDDEN BY -----\n'
                'EID:AddPlayerConditional(52, 7, "Overrides")\n'
                '----- MISC. ITEM CONDITIONS\n'
                'EID:AddPlayerConditional(600, {2,7,13,16})\n'
                'EID:AddConditional(81, EID.CheckForNoRedHealthPlayer)\n'
                'EID:AddConditional(482, EID.CheckForTaintedPlayer)\n'
                'if not EID.isRepentance then\n'
                'EID:AddConditional(208, EID.IsHardMode)\nend\n', encoding="utf-8")
            imported, _, _ = rules(root)
            self.assertEqual({item["target"] for item in imported}, {"5.100.247","5.100.600","5.100.81","5.100.482"})
            self.assertEqual(next(item for item in imported if item["target"] == "5.100.247")["table"], "BFFSSynergies")
            self.assertIn(23,next(item for item in imported if item["target"] == "5.100.600")["players"])
            self.assertEqual(next(item for item in imported if item["target"] == "5.100.81")["predicate"], "no_red_health")

    def test_context_tables_accept_numeric_decimal_pairs_and_lua_array_indices(self) -> None:
        from eid_context import table
        self.assertEqual(table('EID.descriptions[languageCode].carBattery = {[93] = {6.5, 13}}',
                               "carBattery")["93"], [6.5,13])
        self.assertEqual(table('EID.descriptions[languageCode].VoidNames = {"Speed", "Tears", "Damage"}',
                               "VoidNames"), {"1":"Speed","2":"Tears","3":"Damage"})

    def test_birthright_import_converts_lua_indices_to_native_player_type_only(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "upstream"
            base = root / "descriptions/ab+"
            rep = root / "descriptions/rep"
            base.mkdir(parents=True)
            rep.mkdir(parents=True)
            (base / "en_us.lua").write_text(
                'local languageCode = "en_us"\n'
                'EID.descriptions[languageCode].VoidNames = {"Speed", "Tears"}\n', encoding="utf-8")
            (rep / "en_us.lua").write_text(
                'local languageCode = "en_us"\n'
                'EID.descriptions[languageCode].birthright = {\n'
                '{"Isaac", "", "Isaac effect"}, {"Magdalene", "", "Magdalene effect"},\n'
                '[10] = {"Eden", "", "Eden effect"}, [11] = {"The Lost", "", "Lost effect"},\n'
                '[41] = {"Tainted Forgotten Soul", "", "Soul effect"}}\n', encoding="utf-8")
            output = Path(directory) / "descriptions.json"
            subprocess.check_call([sys.executable,str(SCRIPT),str(root),str(output)])
            imported = json.loads(output.read_text(encoding="utf-8"))["languages"]["en_us"]
            self.assertEqual(imported["birthright"]["0"][0], "Isaac")
            self.assertEqual(imported["birthright"]["1"][0], "Magdalene")
            self.assertEqual(imported["birthright"]["9"][0], "Eden")
            self.assertEqual(imported["birthright"]["10"][2], "Lost effect")
            self.assertEqual(imported["birthright"]["40"][0], "Tainted Forgotten Soul")
            self.assertNotIn("41", imported["birthright"])
            self.assertEqual(imported["stat_names"], {"1":"Speed","2":"Tears"})

    def test_pandora_floor_classifier_does_not_shift_missing_floors(self) -> None:
        from eid_context import pandora_floor_lines
        lines = ["Intro"] + [f"Floor{i}: Reward" for i in range(1,9)] + ["Sheol", "Cathedral", "Chest", "Home"]
        result = pandora_floor_lines({"collectibles":{"297":{"description":"#".join(lines)}}})
        self.assertNotIn("normal.9",result)
        self.assertNotIn("normal.12",result)
        self.assertEqual(result["normal.10"],"Sheol")
        self.assertEqual(result["normal.13"],"Chest")
        self.assertEqual(result["normal.14"],"Home")

    def test_legacy_greed_notes_are_classified_without_matching_enemy_names(self) -> None:
        from eid_context import greed_no_effect_notes
        rules = [{"target": "5.100.241", "greed": True, "modifier": "No Effect (Greed)"},
                 {"target": "5.350.84", "greed": True, "modifier": "No Effect (Greed)"}]
        categories = {"collectibles": {"241": {"description": "Room rewards#Не влияет в Режиме Жадности "}},
                      "trinkets": {"84": {"description": "Greed and Super Greed cannot spawn"}}}
        self.assertEqual(greed_no_effect_notes(categories, rules),
                         {"5.100.241": ["Не влияет в Режиме Жадности "]})
        self.assertEqual(categories["collectibles"]["241"]["description"],
                         "Room rewards#Не влияет в Режиме Жадности ")

    def weapon_rules(self, body: str) -> list[dict]:
        from eid_context import weapon_rules
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "features").mkdir()
            (root / "features/eid_data.lua").write_text(
                'EID.TaintedToRegularID = {[28] = 7}\n', encoding="utf-8")
            (root / "features/eid_conditionals.lua").write_text(
                '------ OVERRIDES / OVERRIDDEN BY -----\n' + body +
                '\n----- MISC. ITEM CONDITIONS ------\n', encoding="utf-8")
            return weapon_rules(root)

    def test_weapon_rules_expand_both_directions_and_priority(self) -> None:
        rules = self.weapon_rules(
            'EID:AddSynergyConditional({533, "5.350.144"}, 52, "Overridden", "Overrides", '
            '{layer = 800, checkLayers = true})\n')
        self.assertEqual(len(rules), 4)
        self.assertEqual(rules[0]["target"], "5.100.533")
        self.assertEqual(rules[0]["owned"], "5.100.52")
        self.assertEqual(rules[0]["variable"], "{{NameOnly5.100.52}}")
        self.assertEqual(rules[0]["layer"], 800)
        self.assertTrue(rules[0]["check_layers"])
        self.assertEqual(rules[2]["modifier"], "Overrides")
        self.assertEqual(rules[2]["owned"], "5.100.533")

    def test_weapon_rules_exclude_abplus_only_branches(self) -> None:
        rules = self.weapon_rules(
            'if not EID.isRepentance then\n'
            ' EID:AddSynergyConditional(374, 52, "Overridden", "Overrides")\n'
            'end\n'
            'if EID.isRepentance then\n'
            ' EID:AddSynergyConditional(597, 52, "Overridden", "Overrides")\n'
            'end\n')
        self.assertEqual({rule["target"] for rule in rules}, {"5.100.597", "5.100.52"})

    def test_one_sided_weapon_synergy_keeps_the_same_priority_name(self) -> None:
        rules = self.weapon_rules(
            'EID:AddOneSidedSynergyConditional(168, 118, "Epic Fetus Brimstone", '
            '{layer = 900, checkLayers = true})\n')
        self.assertEqual(rules[0]["variable"], "{{NameOnly5.100.168}}")
        self.assertEqual(rules[1]["variable"], "{{NameOnly5.100.168}}")
        self.assertEqual(rules[0]["bulletpoint"], "Item5.100.118")
        self.assertEqual(rules[1]["bulletpoint"], "Item5.100.168")

    def test_weapon_character_rules_include_tainted_and_explicit_variables(self) -> None:
        rules = self.weapon_rules(
            'EID:AddPlayerConditional(52, 7, "Overrides", {layer = 790, '
            'checkLayers = true, variableText = "{{NameOnlyC118}}"})\n')
        self.assertEqual(rules[0]["players"], [7, 28])
        self.assertEqual(rules[0]["variable"], "{{NameOnlyC118}}")

    def test_unknown_weapon_options_fail_instead_of_silently_guessing(self) -> None:
        with self.assertRaises(ValueError):
            self.weapon_rules('EID:AddSynergyConditional(533, 52, "Overridden", '
                              '"Overrides", {unsupported = true})\n')

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

    def test_room_description_header_assignment(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "language.lua"
            path.write_text(
                'EID.descriptions[languageCode].diceHeader = "[Dice Room effects]"\n',
                encoding="utf-8",
            )
            self.assertEqual(
                IMPORTER.parse_string_assignment(path, "diceHeader"),
                "[Dice Room effects]",
            )

    def test_room_header_brackets_are_removed_for_display(self) -> None:
        self.assertEqual(
            IMPORTER.display_room_header("[Dice Room effects]", "dice"),
            "Dice Room effects",
        )

    def test_unidentified_pill_translation_assignment(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "language.lua"
            path.write_text(
                'EID.descriptions[languageCode].unidentifiedPill = "Неизвестная пилюля"\n',
                encoding="utf-8",
            )
            self.assertEqual(
                IMPORTER.parse_string_assignment(path, "unidentifiedPill"),
                "Неизвестная пилюля",
            )
        self.assertEqual(
            IMPORTER.display_room_header("[Next Sacrifice Room payout]", "sacrifice"),
            "Next Sacrifice Room payout",
        )

    def test_discovers_union_of_base_and_repentance_languages(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            base = root / "descriptions" / "ab+"
            rep = root / "descriptions" / "rep"
            base.mkdir(parents=True)
            rep.mkdir(parents=True)
            (base / "en_us.lua").write_text('local languageCode = "en_us"\n', encoding="utf-8")
            (rep / "en_us.lua").write_text('local languageCode = "en_us"\n', encoding="utf-8")
            (base / "bul.lua").write_text('local languageCode = "bul"\n', encoding="utf-8")
            discovered = IMPORTER.discover_language_files(root)
            self.assertEqual(set(discovered), {"en_us", "bul"})
            self.assertEqual(len(discovered["en_us"]), 2)
            self.assertEqual(len(discovered["bul"]), 1)

    def test_output_metadata_targets_standard_repentance(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "upstream"
            output = Path(directory) / "descriptions.json"
            base = root / "descriptions" / "ab+"
            rep = root / "descriptions" / "rep"
            base.mkdir(parents=True)
            rep.mkdir(parents=True)
            table = ('local languageCode = "{code}"\n'
                     'EID.descriptions[languageCode].collectibles={{\n'
                     '  {{"1", "One", "Description"}},\n'
                     '}}\n')
            (base / "en_us.lua").write_text(table.format(code="en_us"), encoding="utf-8")
            (rep / "en_us.lua").write_text('local languageCode = "en_us"\n', encoding="utf-8")
            (base / "bul.lua").write_text(table.format(code="bul"), encoding="utf-8")
            subprocess.check_call([sys.executable, str(SCRIPT), str(root), str(output)])
            payload = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(
                payload["source"],
                "https://github.com/wofsauge/External-Item-Descriptions",
            )
            self.assertEqual(payload["game_version"], "rep")
            self.assertEqual(payload["compatible_isaac_version"], "1.7.9b")
            self.assertEqual(set(payload["languages"]), {"en_us", "bul"})


if __name__ == "__main__":
    unittest.main()
