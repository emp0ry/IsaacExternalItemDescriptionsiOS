"""Read static EID context tables without executing upstream Lua code."""
from __future__ import annotations

import re
from pathlib import Path


# Reviewed legacy base-description lines in upstream's AB+ translations. The
# original runtime also appends No Effect (Greed), producing duplicate advice
# for these entries. Keep the source database intact and classify these notes
# explicitly so the iOS context adapter can render one mode-appropriate line.
LEGACY_GREED_NOTICES = {
    "5.100.241": {
        "Neovlivňuje režim Greed Mode",
        "Brak efektu w Trybie Chciwym/Greed Mode",
        "Не влияет в Режиме Жадности",
        "Greed modunda işe yaramaz",
    },
}


def greed_no_effect_notes(categories: dict, context_rules: list[dict]) -> dict[str, list[str]]:
    result = {}
    names = {100: "collectibles", 300: "cards", 350: "trinkets"}
    reference = categories.get("conditionals", {}).get("No Effect (Greed)", "")

    def visible(text: str) -> str:
        return re.sub(r"\s+", " ", re.sub(r"\{\{[^}]+\}\}", "", text)).strip().casefold()

    for rule in context_rules:
        if not rule["greed"] or rule["modifier"] != "No Effect (Greed)":
            continue
        target = rule["target"]
        _, variant, subtype = map(int, target.split("."))
        detail = categories.get(names[variant], {}).get(str(subtype), {}).get("description", "")
        aliases = {visible(text) for text in LEGACY_GREED_NOTICES.get(target, ())}
        notices = [line for line in detail.split("#") if
                   re.search(r"\{\{GreedMode(?:Small)?\}\}", line) or
                   visible(line) in aliases or
                   (isinstance(reference, str) and reference and visible(line) == visible(reference))]
        if notices:
            result[target] = notices
    return result


def split_arguments(text: str) -> list[str]:
    result, start, depth, quote, escaped = [], 0, 0, None, False
    for index, char in enumerate(text):
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char in "{([":
            depth += 1
        elif char in "})]":
            depth -= 1
        elif char == "," and depth == 0:
            result.append(text[start:index].strip())
            start = index + 1
    result.append(text[start:].strip())
    return result


def value(text: str):
    text = text.strip()
    if text.startswith("{") and text.endswith("}"):
        parts = [part for part in split_arguments(text[1:-1]) if part]
        keyed = [re.match(r"(?:\[(.*?)\]|([A-Za-z_][A-Za-z_0-9]*))\s*=\s*(.*)", part, re.DOTALL)
                 for part in parts]
        if any(keyed):
            if not all(keyed):
                raise ValueError("mixed Lua table")
            return {str(value(match[1])) if match[1] else match[2]: value(match[3]) for match in keyed}
        return [value(part) for part in parts]
    if re.fullmatch(r"-?\d+(?:\.\d+)?", text):
        return float(text) if "." in text else int(text)
    if text in ("true", "false"):
        return text == "true"
    if len(text) >= 2 and text[0] in "\"'" and text[-1] == text[0]:
        return re.sub(r"\\(.)", lambda m: {"n": "\n", "r": "\r", "t": "\t"}.get(m[1], m[1]), text[1:-1])
    raise ValueError("dynamic Lua expression")


def table(source: str, name: str) -> dict:
    # Remove line comments outside string literals. Braces and commas inside
    # EID markup/localized text must not influence table boundaries.
    source = re.sub(r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|--\[\[.*?\]\]|--[^\n]*''',
                    lambda m: m[1] or "", source, flags=re.DOTALL)
    match = re.search(rf"(?:EID\.descriptions\[languageCode\]\.|local\s+|EID\.){re.escape(name)}\s*=\s*\{{", source)
    if not match:
        return {}
    start, depth, quote, escaped = match.end(), 1, None, False
    end = start
    for end in range(start, len(source)):
        char = source[end]
        if quote:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
        elif char in "\"'":
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                break
    if depth:
        raise ValueError(f"unterminated {name} table")
    result = {}
    position = 1
    for entry in split_arguments(source[start:end]):
        if not entry:
            continue
        keyed = re.match(r"(?:\[(.*?)\]|([A-Za-z_][A-Za-z_0-9]*))\s*=\s*(.*)", entry, re.DOTALL)
        try:
            key = (str(value(keyed[1])) if keyed[1] else keyed[2]) if keyed else str(position)
            parsed = value(keyed[3] if keyed else entry)
        except ValueError:
            continue
        result[key] = parsed
        if not keyed:
            position += 1
    return result


def rules(source: Path) -> tuple[list[dict], dict[str, int], list[str]]:
    data = (source / "features/eid_data.lua").read_text(encoding="utf-8-sig")
    equivalents = table(data, "TaintedToRegularID")
    health = table(data, "HealthUpData")
    for key, number in re.findall(r'EID\.HealthUpData\["([^"]+)"\]\s*=\s*(-?\d+)', data):
        health[key] = int(number)
    healing = table(data, "HealingItemData")
    for key in re.findall(r'EID\.HealingItemData\["([^"]+)"\]\s*=\s*true', data):
        healing[key] = True
    text = (source / "features/eid_conditionals.lua").read_text(encoding="utf-8-sig")
    # Character rules also occur in the later miscellaneous block. Weapon
    # rules have their own strict importer, so do not import that block twice.
    if "------ OVERRIDES / OVERRIDDEN BY -----" in text:
        before, weapons = text.split("------ OVERRIDES / OVERRIDDEN BY -----", 1)
        text = before + weapons.split("----- MISC. ITEM CONDITIONS", 1)[1]
    text = re.sub(r"(?m)^if (?:not EID\.isRepentance|EID\.isRepentancePlus) then\n.*?^(?:end|else [^\n]*end)[ \t]*(?:--[^\n]*)?$",
                  "", text, flags=re.DOTALL)
    text = re.sub(r"(?m)^if EID\.isRepentance then (EID:.*?) end(?: --[^\n]*)?$", r"\1", text)
    result = []
    character_groups = {"SoulBlackChars": [4, 17, 25, 35, 36, 40, 12, 24],
                        'EID.SpecialHeartPlayers["Soul"]': [4, 17, 25, 35, 36, 40],
                        'EID.SpecialHeartPlayers["Black"]': [12, 24]}
    for line in text.splitlines():
        line = re.sub(r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|--[^\n]*''',
                      lambda m: m[1] or "", line)
        call = re.match(r"\s*EID:(AddPlayerConditional|AddClosestPlayerConditional|AddConditional)\((.*)\)\s*(?:--.*)?$", line)
        if not call:
            continue
        args = split_arguments(call[2])
        if len(args) < 2:
            continue
        predicate = {"EID.IsGreedMode": "greed", "EID.CheckForNoRedHealthPlayer": "no_red_health",
                     "EID.CheckForTaintedPlayer": "tainted", "EID.IsHardMode": "hard"}.get(args[1], "")
        greed = predicate == "greed"
        if call[1] == "AddConditional" and not predicate:
            continue
        try:
            targets = value(args[0])
            targets = targets if isinstance(targets, list) else [targets]
            players = [] if predicate else character_groups.get(args[1], None)
            if players is None:
                players = value(args[1])
                players = players if isinstance(players, list) else [players]
            if not predicate and (len(args) < 5 or args[4] != "false"):
                players = players + [int(key) for key, base in equivalents.items() if base in players]
            modifier = value(args[2]) if len(args) > 2 and args[2] != "nil" else ""
        except ValueError:
            continue
        extra = args[3] if len(args) > 3 else ""
        variable = re.search(r'''variableText\s*=\s*("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')''', extra)
        location = re.search(r'''locTable\s*=\s*("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')''', extra)
        if ("variableText" in extra and not variable) or ("locTable" in extra and not location):
            continue  # Dynamic charge/state conditionals need a separate adapter.
        layer = re.search(r"layer\s*=\s*(-?\d+)", extra)
        bullet = re.search(r'''bulletpoint\s*=\s*("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')''', extra)
        for target in targets:
            rule = {"target": f"5.100.{target}" if isinstance(target, int) else target,
                    "players": sorted(set(players)), "greed": greed,
                    "modifier": modifier, "layer": int(layer[1]) if layer else 0}
            rule["closest"] = call[1] == "AddClosestPlayerConditional"
            if predicate:
                rule["predicate"] = predicate
            if location:
                rule["table"] = value(location[1])
            if variable:
                rule["variable"] = value(variable[1])
            if bullet:
                rule["bulletpoint"] = value(bullet[1])
            result.append(rule)
    # This upstream loop uses static item-to-charge rewards, not a read of the
    # current charge count. Expand it without executing the Lua loop.
    for key, charges in table(data, "BloodUpData").items():
        result.append({"target": f"5.100.{key}" if key.isdigit() else key,
                       "players": [36], "greed": False, "layer": 0,
                       "modifier": "Health Up Blood Charges", "variable_literal": str(charges)})
    # Original applyConditionals evaluates higher-priority layers first.
    return sorted(result, key=lambda rule: rule["layer"], reverse=True), health, sorted(healing)


def character_metadata(source: Path) -> dict:
    """Import reviewed Repentance metadata, never Repentance+ XML patches."""
    data = (source / "features/eid_data.lua").read_text(encoding="utf-8-sig")
    wisps = source / "features/eid_xmldata.lua"
    # TaintedToRegularID also maps Esau to Jacob; Esau is not tainted.
    return {"tainted_ids": list(range(21,41)),
            "salvage_trinkets": table(data, "SalvageTrinkets"),
            "salvage_pools": table(data, "SalvageRoomTypes"),
            "salvage_vowels": table(data, "PickupStartsWithVowel"),
            "room_icons": table(data, "RoomTypeToMarkup"),
            "wisps": table(wisps.read_text(encoding="utf-8-sig"), "XMLWisps") if wisps.is_file() else {},
            "wisp_flags": table(data, "WispData")}


def weapon_rules(source: Path) -> list[dict]:
    """Expand only upstream's reviewed weapon block for standard Repentance.

    Mirror AddSynergyConditional and AddOneSidedSynergyConditional in both
    directions. Do not execute Lua or include the AB+-exclusive branch.
    Unknown syntax fails the import rather than silently losing a warning.
    """
    text = (source / "features/eid_conditionals.lua").read_text(encoding="utf-8-sig")
    section = text.split("------ OVERRIDES / OVERRIDDEN BY -----", 1)[1]
    section = section.split("----- MISC. ITEM CONDITIONS", 1)[0]
    equivalents = table((source / "features/eid_data.lua").read_text(encoding="utf-8-sig"),
                        "TaintedToRegularID")
    result, enabled, branches = [], True, []

    def item_key(item):
        if isinstance(item, int) and not isinstance(item, bool):
            return f"5.100.{item}"
        if isinstance(item, str) and re.fullmatch(r"5\.(100|350)\.\d+", item):
            return item
        raise ValueError(f"unsupported weapon item: {item!r}")

    def options(raw):
        if raw == "nil":
            return {}
        if not (raw.startswith("{") and raw.endswith("}")):
            raise ValueError(f"unsupported weapon options: {raw}")
        fields = {}
        for part in split_arguments(raw[1:-1]):
            if not part:
                continue
            key, raw_value = part.split("=", 1)
            key = key.strip()
            if key not in {"layer", "checkLayers", "variableText", "bulletpoint", "uniqueID"}:
                raise ValueError(f"unsupported weapon option: {key}")
            fields[key] = value(raw_value)
        return fields

    def sequence(raw):
        parsed = value(raw)
        return parsed if isinstance(parsed, list) else [parsed]

    def add(targets, triggers, modifier, extra, *, player=False, pedestal=False):
        for target in targets:
            for trigger in triggers:
                target_key = item_key(target)
                if player:
                    players = [trigger] + [int(key) for key, base in equivalents.items() if base == trigger]
                    variable = extra.get("variableText", "")
                    bullet = extra.get("bulletpoint", f"Player{trigger}")
                    owned = ""
                else:
                    players, owned = [], item_key(trigger)
                    variable = (f"{{{{NameOnly{target_key}}}}}" if pedestal else
                                extra.get("variableText", f"{{{{NameOnly{owned}}}}}"))
                    bullet = extra.get("bulletpoint", f"Item{owned}")
                result.append({"target": target_key, "weapon": True, "owned": owned,
                               "players": players, "modifier": modifier,
                               "variable": variable, "bulletpoint": bullet,
                               "layer": extra.get("layer", 0),
                               "check_layers": extra.get("checkLayers", False),
                               "unique_id": extra.get("uniqueID", "")})

    for line in section.splitlines():
        line = re.sub(r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|--[^\n]*''',
                      lambda match: match[1] or "", line).strip()
        if not line:
            continue
        if line in {"if EID.isRepentance then", "if not EID.isRepentance then"}:
            branches.append(enabled)
            enabled = enabled and line == "if EID.isRepentance then"
            continue
        if line == "end":
            enabled = branches.pop()
            continue
        if not enabled:
            continue
        call = re.fullmatch(r"EID:(AddSynergyConditional|AddOneSidedSynergyConditional|AddPlayerConditional)\((.*)\)", line)
        if not call:
            raise ValueError(f"unsupported weapon rule: {line}")
        args = split_arguments(call[2])
        targets, triggers = sequence(args[0]), sequence(args[1])
        modifier = value(args[2])
        if call[1] == "AddSynergyConditional":
            reverse = value(args[3]) if len(args) > 3 and args[3] != "nil" else modifier
            extra = options(args[4]) if len(args) > 4 else {}
            reverse_extra = options(args[5]) if len(args) > 5 and args[5] != "nil" else extra
            add(targets, triggers, modifier, extra)
            add(triggers, targets, reverse, reverse_extra)
        else:
            extra = options(args[3]) if len(args) > 3 else {}
            if call[1] == "AddPlayerConditional":
                add(targets, triggers, modifier, extra, player=True)
            else:
                add(targets, triggers, modifier, extra, pedestal=True)
                add(triggers, targets, modifier, extra)
    if branches:
        raise ValueError("unclosed weapon conditional branch")
    return sorted(result, key=lambda rule: rule["layer"], reverse=True)


def battery_metadata(source: Path) -> dict:
    """Read boolean table patches in the reviewed AB+/Repentance data block."""
    text = (source / "features/eid_data.lua").read_text(encoding="utf-8-sig")
    block = text.split("-- Actives that have no additional effect from Car Battery", 1)[1]
    block = block.split("-- Familiars that have no effect from BFFS!", 1)[0]
    tables = {name: table(block, name) for name in ("CarBatteryNoSynergy", "CarBatteryPedestalWhitelist")}
    enabled, branches = True, []
    for line in block.splitlines():
        line = re.sub(r"--.*", "", line).strip()
        if line in {"if EID.isRepentance then", "if EID.isRepentancePlus then"}:
            branches.append(enabled)
            enabled = enabled and line == "if EID.isRepentance then"
        elif line == "end":
            enabled = branches.pop()
        elif enabled:
            for name, key, flag in re.findall(
                r"EID\.(CarBatteryNoSynergy|CarBatteryPedestalWhitelist)\[(\d+)\]\s*=\s*(true|false|nil)", line):
                tables[name][key] = flag == "true"
    return {"no_synergy": sorted(int(key) for key, flag in tables["CarBatteryNoSynergy"].items() if flag),
            "pedestal_whitelist": sorted(int(key) for key, flag in tables["CarBatteryPedestalWhitelist"].items() if flag)}


def pandora_floor_lines(categories: dict) -> dict[str, str]:
    """Classify the reviewed upstream translations, preserving exact substrings.

    Some older languages omit Void, Dark Room, or Home; never shift their
    later floor labels onto a different reward. Empty separators are ignored.
    Unrecognized layouts remain unhighlighted instead of guessing.
    """
    detail = categories.get("collectibles", {}).get("297", {}).get("description", "")
    parts = [part for part in re.split(r"[#;]", detail) if part.strip()]
    floors = parts[1:]
    has_void = any("???" in part for part in floors)
    indices = []
    if has_void and len(floors) in (13, 14):
        indices = list(range(1, len(floors) + 1))
    elif not has_void and len(floors) in (11, 12):
        indices = list(range(1, 9)) + [10, 11, 13] + ([14] if len(floors) == 12 else [])
    result = {f"normal.{index}": line for index, line in zip(indices, floors)}
    greed = categories.get("conditionals", {}).get("5.100.297 (Greed)")
    if isinstance(greed, list) and len(greed) == 1:
        parts = [part for part in re.split(r"[#;]", greed[0]) if part.strip()]
        # Japanese has an extra single-use heading before its floor header.
        if len(parts) in (7, 8):
            result.update({f"greed.{index}": line for index, line in enumerate(parts[-6:], 1)})
    return result
