"""Read static EID context tables without executing upstream Lua code."""
from __future__ import annotations

import re
import ast
import math
from pathlib import Path
from eid_lua import decode_escapes


def black_feather_metadata(source: Path) -> dict:
    path = source / "features/eid_data.lua"
    if not path.is_file():
        return {}
    text = path.read_text(encoding="utf-8-sig")
    items = table(text, "BlackFeatherItems")
    trinkets = table(text, "BlackFeatherTrinkets")
    # Standard Repentance adds False PHD. Do not import Repentance+ branches.
    for match in re.finditer(r"(?m)^if EID\.isRepentance then EID\.BlackFeatherItems\[(\d+)\] = (true|false) end\s*$", text):
        items[match[1]] = match[2] == "true"
    for entries, maximum in ((items, 732), (trinkets, 189)):
        for identifier, enabled in entries.items():
            if not identifier.isdigit() or not 1 <= int(identifier) <= maximum or type(enabled) is not bool:
                raise ValueError("invalid Black Feather metadata")
    return {"collectibles": sorted(int(key) for key, enabled in items.items() if enabled),
            "trinkets": sorted(int(key) for key, enabled in trinkets.items() if enabled)} if items and trinkets else {}


def abyss_locusts(source: Path) -> dict:
    """Read only standard Repentance's attributed XML export, never the rep+ file."""
    path = source / "features/eid_xmldata.lua"
    entries = table(path.read_text(encoding="utf-8-sig"), "XMLLocusts") if path.is_file() else {}
    for identifier, row in entries.items():
        if not identifier.isdigit() or not 1 <= int(identifier) <= 732 or not isinstance(row, list) or len(row) != 14:
            raise ValueError(f"invalid Abyss locust record: {identifier}")
        for index in (0, 1, 2, 9, 10, 11, 12, 13):
            number = row[index]
            if type(number) not in (int, float) or not math.isfinite(number) or not 0 <= number <= 100:
                raise ValueError(f"invalid Abyss numeric field: {identifier}/{index}")
        if type(row[0]) is not int or not 1 <= row[0] <= 64 or row[1] <= 0 or row[2] <= 0 or any(row[i] > 1 for i in (9, 10, 11)):
            raise ValueError(f"invalid Abyss amount/scale/speed/chance: {identifier}")
        for flags in row[3:9]:
            if not isinstance(flags, list) or not 1 <= len(flags) <= 128 or any(type(flag) is not int or not -1 <= flag <= 127 for flag in flags):
                raise ValueError(f"invalid Abyss flags: {identifier}")
    return entries


def _abyss_plural(text: str, amount: int, language: str) -> str:
    """Finite text substitutions matching the upstream Abyss grammar; no Lua execution."""
    multiple = amount > 1
    replacements = {"pluralize": "s" if multiple else "", "pluralize_y": "ies" if multiple else "y"}
    if language == "ru":
        last, last_two = amount % 10, amount % 100
        noun = "саранча" if last == 1 and last_two != 11 else "саранчи" if 2 <= last <= 4 and not 12 <= last_two <= 14 else "саранч"
        text = text.replace("саранча{pluralize}", noun)
        replacements.update(pluralize="", pluralize_y="")
    elif language == "cs_cz":
        text = text.replace("kobylka{pluralize}", "kobylka" if amount == 1 else "kobylky" if amount <= 4 else "kobylek")
        replacements.update(plural_e="e" if multiple else "", plural_ay="y" if multiple else "a")
    elif language == "de":
        replacements.update(singular_r="" if multiple else "r", plural_e="e" if multiple else "",
            plural_en="en" if multiple else "", plural_n="n" if multiple else "",
            plural_e_sing_en="e" if multiple else "en", plural_e_sing_es="e" if multiple else "es",
            plural_s="s" if multiple else "")
    elif language == "it":
        replacements.update(plural_a_e="e" if multiple else "a", plural_o_i="i" if multiple else "o", plural_e_i="i" if multiple else "e")
    elif language == "spa":
        replacements.update(plural_s="s" if multiple else "", plural_es="es" if multiple else "", plural_zon="zones" if multiple else "zón")
    elif language == "ro_ro":
        if multiple:
            text = text.replace("lăcustă", "lăcuste")
        replacements.update(pluralize_m="i" if multiple else "", pluralize_f="e" if multiple else "")
    elif language == "pl":
        form = 0 if amount == 1 else 1 if 2 <= amount % 10 <= 4 and not 12 <= amount % 100 <= 14 else 2
        text = re.sub(r"\{plural:([^|]+)\|([^|]+)\|([^}]+)\}", lambda match: match[form + 1], text)
    for token, replacement in replacements.items():
        text = text.replace("{" + token + "}", replacement)
    return text


def abyss_descriptions(locusts: dict, categories: dict, english: dict, language: str) -> dict:
    """Pre-render the original Abyss callback for this executable's finite locust set.

    The supported native locusts.xml has been compared against all 17 standard
    EID records. No game XML is distributed. Repentance applies only the FIRST
    flag in EACH effect array, even when that flag has no visible description.
    Damage is not multiplied by quality (that is a Repentance+ feature).
    """
    if not locusts:
        return {}
    texts = dict(english.get("abyss_texts", {}))
    texts.update(categories.get("abyss_texts", {}))
    if not texts.get("InfoText") or not texts.get("DamageMult"):
        return {}
    grammar = language if categories.get("abyss_texts", {}).get("InfoText") else "en_us"
    effects = {**english.get("abyss_effects", {}), **categories.get("abyss_effects", {})}
    tears = {**english.get("tear_flags", {}), **categories.get("tear_flags", {})}
    overrides = {**english.get("abyss_synergies", {}), **categories.get("abyss_synergies", {})}
    default = [1, 1, 1, [-1], [-1], [-1], [-1], [-1], [-1], 1, 1, 1, 1, 1]

    def replace(text, **values):
        for key, value in values.items():
            text = text.replace("{" + key + "}", str(value))
        return text

    def render(identifier, row):
        override = overrides.get(identifier)
        if isinstance(override, str) and override:
            return override
        amount, scale, speed = row[:3]
        damage = replace(texts["DamageMult"], **{"1": f"{row[12]:g}"})
        size = texts.get("SizeSmall" if scale < 1 else "SizeBig", "") if scale != 1 else ""
        velocity = texts.get("SpeedSlow" if speed < 1 else "SpeedDash" if speed >= 6 else "SpeedFast", "") if speed != 1 else ""
        headline = texts.get("InfoTextPlural", texts["InfoText"]) if amount > 1 else texts["InfoText"]
        lines = [replace(headline, amount=amount, size=size, speed=velocity, dmg=damage)]

        def chance(index):
            # Preserve upstream's priority: chance3/chance2 only override chance1
            # when they are below one, including a valid zero probability.
            value = row[9 + index] if index and row[9 + index] < 1 else row[9]
            return replace(texts.get("Chance", ""), **{"1": f"{value * 100:.2f}".rstrip("0").rstrip(".")}) if value != 1 else ""

        if row[13] != 1:
            lines.append(replace(texts["DamageMult"], **{"1": f"{row[13]:g}"}) + chance(0))
        for table_name, offset in ((effects, 3), (tears, 6)):
            for index in range(3):
                description = table_name.get(str(row[offset + index][0]))
                if isinstance(description, str) and description:
                    lines.append(description + chance(index))
        return _abyss_plural("#".join(re.sub(r"[ \t]+", " ", line).strip() for line in lines), amount, grammar)

    return {identifier: render(identifier, row) for identifier, row in {"default": default, **locusts}.items()}


def luck_formulas(source: Path) -> dict:
    """Export arithmetic trees, not executable Lua, for standard Repentance."""
    text = (source / "features/eid_data.lua").read_text(encoding="utf-8-sig")
    text = text.split("-- Luck formulas", 1)[1].split("-- Number of Health Ups", 1)[0]
    operations = {ast.Add: "add", ast.Sub: "sub", ast.Mult: "mul", ast.Div: "div"}

    def tree(node):
        if isinstance(node, ast.Constant) and type(node.value) in (int, float):
            return node.value
        if isinstance(node, ast.Name) and node.id == "luck":
            return {"op": "luck"}
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
            return {"op": "neg", "args": [tree(node.operand)]}
        if isinstance(node, ast.BinOp) and type(node.op) in operations:
            return {"op": operations[type(node.op)], "args": [tree(node.left), tree(node.right)]}
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and not node.keywords and \
                node.func.id in {"min", "max", "floor", "ceil"}:
            return {"op": node.func.id, "args": [tree(arg) for arg in node.args]}
        raise ValueError(f"unsupported luck expression: {ast.dump(node)}")

    formulas, enabled, branches = {}, True, []
    for line in text.splitlines():
        line = re.sub(r"--.*", "", line).strip()
        if line in {"if EID.isRepentance then", "if EID.isRepentancePlus then"}:
            branches.append(enabled)
            enabled = enabled and line == "if EID.isRepentance then"
        elif line == "end":
            enabled = branches.pop()
        elif enabled:
            match = re.fullmatch(r'EID\.LuckFormulas\["([^"]+)"\] = function\(luck\) return (.+) end', line)
            if match:
                formulas[match[1]] = tree(ast.parse(match[2].replace("math.", ""), mode="eval").body)
            elif line and line != "EID.LuckFormulas = {}":
                raise ValueError(f"unsupported luck formula declaration: {line}")
    if branches:
        raise ValueError("unclosed luck formula branch")
    return formulas


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
        return decode_escapes(text[1:-1])
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
        unlock = re.fullmatch(r"function\(\)return(not)?EID:HaveNotUnlockedAchievement\((82|366)\)end",
                              re.sub(r"\s+", "", args[1])) if call[1] == "AddConditional" else None
        if unlock:
            predicate = "achievement_unlocked" if unlock[1] else "achievement_locked"
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
            if unlock:
                rule["achievement"] = int(unlock[2])
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


def familiar_metadata(source: Path) -> dict:
    """Import the reviewed familiar block, excluding Repentance+ patches.

    Keep ownership/eligibility separate from translated replacement text. A
    missing translation must not make an unrelated item eligible for a buff.
    """
    text = (source / "features/eid_data.lua").read_text(encoding="utf-8-sig")
    block = text.split("-- Familiars that have no effect from BFFS!", 1)[1]
    block = block.split("-- Tainted character", 1)[0]
    names = {"BFFSNoSynergy": "no_synergy", "BFFSPedestalWhitelist": "pedestal_whitelist",
             "HiveMindFamiliars": "hive_mind", "BFFSIgnore": "bffs_ignore"}
    tables = {name: table(block, name) for name in names}
    enabled, branches = True, []
    for line in block.splitlines():
        line = re.sub(r"--.*", "", line).strip()
        if line in {"if EID.isRepentance then", "if EID.isRepentancePlus then"}:
            branches.append(enabled)
            enabled = enabled and line == "if EID.isRepentance then"
        elif line == "end":
            if not branches:
                raise ValueError("unexpected familiar metadata branch end")
            enabled = branches.pop()
        elif enabled:
            for name, key, flag in re.findall(
                    r"EID\.(BFFSNoSynergy|BFFSPedestalWhitelist|HiveMindFamiliars|BFFSIgnore)\[(\d+)\]\s*=\s*(true|false|nil)", line):
                tables[name][key] = flag == "true"
    if branches:
        raise ValueError("unclosed familiar metadata branch")
    for entries in tables.values():
        if any(not key.isdigit() or not 1 <= int(key) <= 732 or type(flag) is not bool
               for key, flag in entries.items()):
            raise ValueError("invalid familiar metadata")
    return {names[name]: sorted(int(key) for key, flag in entries.items() if flag)
            for name, entries in tables.items()}


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
