"""Import reviewed original EID duplicate, charge and miscellaneous rules.

No Lua is executed. Runtime predicates are an explicit portable whitelist;
AB+-exclusive and Repentance+ branches never enter the exported rules.
"""
from __future__ import annotations
import re
from pathlib import Path
from eid_context import split_arguments, value, black_feather_metadata, table


def supplemental_rules(source: Path) -> list[dict]:
    text = (source / "features/eid_conditionals.lua").read_text(encoding="utf-8-sig")
    sections = []
    if "------ DUPLICATE COPIES OF ITEMS ------" in text:
        sections.append(text.split("------ DUPLICATE COPIES OF ITEMS ------", 1)[1]
                        .split("------ OVERRIDES / OVERRIDDEN BY", 1)[0])
    if "----- MISC. ITEM CONDITIONS" in text:
        sections.append(text.split("----- MISC. ITEM CONDITIONS", 1)[1])
    result = []

    def seq(raw):
        parsed = value(raw)
        return parsed if isinstance(parsed, list) else [parsed]

    def key(item):
        if type(item) is int and 1 <= item <= 732:
            return f"5.100.{item}"
        if isinstance(item, str) and re.fullmatch(r"5\.(?:100|350|300|70)(?:\.\d+)?", item):
            return item
        raise ValueError(f"unsupported supplemental item {item!r}")

    def options(raw):
        if raw == "nil":
            return {}
        parsed = value(raw)
        if not isinstance(parsed, dict) or set(parsed) - {
                "layer", "checkLayers", "uniqueID", "lineColor", "replaceColor",
                "variableText", "bulletpoint", "noFallback", "noTable"}:
            raise ValueError(f"unsupported supplemental options {raw}")
        return parsed

    def add(targets, triggers, modifier, extra, reminder=True, pedestal=False, predicate="", params=None):
        for target in targets:
            target_key = key(target)
            for trigger in triggers:
                owned = key(trigger) if trigger is not None else ""
                result.append({"target": target_key, "owned": owned, "predicate": predicate,
                    "params": params or {}, "modifier": modifier or "", "reminder": reminder,
                    "variable": extra.get("variableText", "{{NameOnly" +
                        (target_key if pedestal else owned) + "}}" if owned else ""),
                    "bulletpoint": extra.get("bulletpoint", "Item" + owned if owned else ""),
                    "layer": extra.get("layer", 0), "check_layers": extra.get("checkLayers", False),
                    "unique_id": extra.get("uniqueID", ""), "line_color": extra.get("lineColor", ""),
                    "replace_color": extra.get("replaceColor", ""), "no_table": extra.get("noTable", False)})

    dynamic = {"EID.PlayersHaveRestock": "restock", "EID.InStageVoid": "stage_void",
               "EID.InStageNoTreasureRoom": "stage_no_treasure", "EID.InStageTheShop": "stage_shop",
               "EID.CheckForMultipleActives": "multiple_actives",
               "EID.CheckForMultipleChargeableActives": "multiple_chargeable_actives"}
    for section in sections:
        enabled, branches = True, []
        for raw_line in section.splitlines():
            line = re.sub(r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|--[^\n]*''',
                          lambda m: m[1] or "", raw_line).strip()
            if not line:
                continue
            inline = re.fullmatch(r"if (not EID\.isRepentance|EID\.isRepentance(?:Plus)?) then (EID:.*) end", line)
            if inline:
                if not enabled or inline[1] != "EID.isRepentance":
                    continue
                line = inline[2]
            elif line in {"if EID.isRepentance then", "if not EID.isRepentance then", "if EID.isRepentancePlus then"}:
                branches.append(enabled)
                enabled = enabled and line == "if EID.isRepentance then"
                continue
            elif line == "end":
                if not branches:
                    raise ValueError("unexpected supplemental branch end")
                enabled = branches.pop()
                continue
            if not enabled:
                continue
            if line.startswith("for k,_ in pairs(EID.BlackFeather"):
                meta = black_feather_metadata(source)
                trinket = "BlackFeatherTrinkets" in line
                ids = [f"5.350.{i}" if trinket else i for i in meta.get("trinkets" if trinket else "collectibles", [])]
                add(ids, ["5.350.80"], "Black Feather", {"lineColor": "BlinkGray"})
                continue
            call = re.fullmatch(r"EID:(AddSelfConditional|AddItemConditional|AddSynergyConditional|AddOneSidedSynergyConditional|AddConditional)\((.*)\)", line)
            if not call:
                # Character conditions are handled by the existing importer.
                if line.startswith(("EID:AddPlayerConditional(", "EID:AddClosestPlayerConditional(")):
                    continue
                raise ValueError(f"unsupported supplemental statement: {line}")
            args = split_arguments(call[2])
            targets = seq(args[0])
            if call[1] == "AddSelfConditional":
                extra = options(args[2]) if len(args) > 2 else {}
                include = len(args) < 4 or args[3] != "false"
                for target in targets:
                    add([target], [target,347,485] if include else [target], value(args[1]),
                        {**extra,"uniqueID":"self-copy:"+key(target)}, False)
                continue
            modifier = value(args[2]) if len(args) > 2 and args[2] != "nil" else ""
            if modifier=="PandorasBoxStrangeKeyEffect":
                continue  # Existing floor adapter renders/highlights this once.
            if call[1] == "AddConditional":
                # These are already supplied by the character/mode importer.
                if args[1] in {"EID.IsHardMode", "EID.IsGreedMode", "EID.CheckForTaintedPlayer"}:
                    continue
                # Native gold-bomb and subplayer counting require additional
                # validated state; do not guess those unrelated predicates.
                if args[1] in {"EID.PlayersHaveGoldenBomb", "EID.MultiplePlayerCharacters"}:
                    continue
                predicate, params = dynamic.get(args[1], ""), {}
                compact = re.sub(r"\s+", "", args[1])
                charge = re.fullmatch(r"function\(.*?\)returnEID:(CheckPlayersForActiveChargeType|CheckActiveChargeType)\((.*?)\)end", compact)
                if charge:
                    values = split_arguments(charge[2])
                    target_charge = charge[1] == "CheckActiveChargeType"
                    if target_charge:
                        if values.pop(0) != "descObj.ObjSubType":
                            raise ValueError("unsupported target charge expression")
                    predicate = "target_charge" if target_charge else "player_charge"
                    params = {"max": None if values[0] == "nil" else value(values[0]),
                              "type": None if values[1] == "nil" else value(values[1])}
                    if len(values) > 2:
                        params["required" if target_charge else "check_pocket"] = value(values[2])
                if not predicate:
                    raise ValueError(f"unsupported supplemental predicate: {args[1]}")
                add(targets, [None], modifier, options(args[3]) if len(args) > 3 else {}, predicate=predicate, params=params)
                continue
            triggers = seq(args[1])
            if call[1] == "AddSynergyConditional":
                reverse = value(args[3]) if len(args) > 3 and args[3] != "nil" else modifier
                extra = options(args[4]) if len(args) > 4 else {}
                reverse_extra = options(args[5]) if len(args) > 5 and args[5] != "nil" else extra
                reminder = len(args) < 7 or args[6] != "false"
                add(targets, triggers, modifier, extra, reminder)
                add(triggers, targets, reverse, reverse_extra, reminder)
            else:
                extra = options(args[3]) if len(args) > 3 else {}
                reminder = len(args) < 5 or args[4] != "false"
                add(targets, triggers, modifier, extra, reminder, call[1] == "AddOneSidedSynergyConditional")
                if call[1] == "AddOneSidedSynergyConditional":
                    add(triggers, targets, modifier, extra, reminder)
        if branches:
            raise ValueError("unclosed supplemental branch")
    return sorted(result, key=lambda rule: rule["layer"], reverse=True)
