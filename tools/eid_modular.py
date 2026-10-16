"""Compile original EID's finite Repentance modular descriptions into data.

No upstream Lua is executed, on the build host or on iOS. Only literal tables,
reviewed module behaviors and finite localized pluralization rules are accepted.
The native context adapter still handles live ownership, character warnings,
unlocks and synergies. Repentance+ data is deliberately not loaded.
"""
from __future__ import annotations

import ast
import copy
import re
from pathlib import Path

from eid_context import table

PREFIXES = {"C_ID": "5.100.", "T_ID": "5.350.", "Pill_ID": "5.70.", "Card_ID": "5.300."}
NESTED = {"EffectList", "RightEye", "LeftEye", "RoomEffect", "TimedEffect", "OnUseEffect", "HeldEffect"}
CUSTOM = NESTED | {"Spawns", "TearEffect", "FullMapping", "LuckChance", "ItemDescription", "Variables"}
HEALTH = {
    "Soul": {"RedHeart": "SoulHeart", "FullHealth": "", "HealingRed": "", "EmptyHeart": "SoulHeart", "RottenHeart": ""},
    "Black": {"RedHeart": "BlackHeart", "FullHealth": "", "HealingRed": "", "EmptyHeart": "BlackHeart", "RottenHeart": ""},
    "Coin": {"RedHeart": "CoinHeart", "HealingRed": "HealingCoin", "EmptyHeart": "EmptyCoinHeart", "SoulHeart": "", "BlackHeart": ""},
    "None": {name: "" for name in ("RedHeart", "CoinHeart", "FullHealth", "HealingRed", "HealingCoin", "SoulHeart", "BlackHeart", "BoneHeart", "EternalHeart", "GoldenHeart", "RottenHeart", "BrokenHeart", "EmptyHeart", "EmptyCoinHeart")},
}


def integer_expression(text: str) -> int:
    node = ast.parse(text.replace("HorseID", "2048"), mode="eval").body
    def read(value):
        if isinstance(value, ast.Constant) and type(value.value) is int:
            return value.value
        if isinstance(value, ast.BinOp) and isinstance(value.op, ast.Add):
            return read(value.left) + read(value.right)
        raise ValueError(f"unsupported modular ID expression: {text}")
    return read(node)


def normalize(text: str) -> str:
    text = re.sub(r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|--\[\[.*?\]\]|--[^\n]*''',
                  lambda m: m[1] or "", text, flags=re.S)
    def key(match):
        return '["' + PREFIXES[match[1]] + str(integer_expression(match[2])) + '"]'
    text = re.sub(r"\[\s*(C_ID|T_ID|Pill_ID|Card_ID)\s*\.\.\s*([^\]]+)\]", key, text)
    return re.sub(r"=\s*(-?\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)", lambda m: "= " + str(float(m[1])/float(m[2])), text)


def behaviors(source: Path) -> dict:
    text = (source / "features/eid_modular_descriptions.lua").read_text(encoding="utf-8-sig")
    text = text.split("-- Metatable", 1)[0]
    result = {}
    for match in re.finditer(r'^    \["([^"\n]+)"\]\s*=\s*\{(.*?)(?=^    \["|^\})', text, re.M | re.S):
        name, body = match.groups()
        prefix = body.split("BehaviorFunc", 1)[0]
        priority = re.search(r"Priority\s*=\s*(-?\d+)", prefix)
        if not priority:
            raise ValueError(f"missing modular priority: {name}")
        row = {"Priority": int(priority[1])}
        for field in ("Arrow", "InvertArrow", "HideSign", "IsMultiplier"):
            row[field] = bool(re.search(field + r"\s*=\s*true", prefix))
        icon = re.search(r'Icon\s*=\s*"([^"\n]+)"', prefix)
        if icon:
            row["Icon"] = icon[1]
        elif name == "Spawns":
            row["Icons"] = table("local icons = {" + prefix.split("Icon = {", 1)[1], "icons")
        if "BehaviorFunc" in body and name not in CUSTOM:
            raise ValueError(f"unreviewed modular callback: {name}")
        result[name] = row
    return result


def pluralizer(path: Path, english: Path):
    text = path.read_text(encoding="utf-8-sig") if path.is_file() else ""
    if "PluralizeFunction = function" not in text:
        text = english.read_text(encoding="utf-8-sig")
    body = text.split("PluralizeFunction = function", 1)[1].split("\nEID.descriptions", 1)[0]
    pairs = re.findall(r'ReplaceVariableStr\(text, "([^"]+)", amount > 1 and "([^"]*)" or "([^"]*)"\)', body)
    forms = table(body, "forms")
    replacements = re.findall(r'text = text:gsub\("([^"\n]+)", "([^"\n]*)"\)', body)
    def apply(text, amount):
        if forms:
            number = abs(amount)
            form = 1 if number % 10 == 1 and number % 100 != 11 else 2 if 2 <= number % 10 <= 4 and not 12 <= number % 100 <= 14 else 3
            for row in forms.values():
                text = text.replace(row[0] + "{pluralize}", row[form])
            text = text.replace("{pluralize_y}", "").replace("{pluralize}", "")
        if "local function pluralize(one, few, many)" in body:
            form = 1 if amount == 1 else 2 if 2 <= amount % 10 <= 4 and not 12 <= amount % 100 <= 14 else 3
            text = re.sub(r"\{plural:([^|]+)\|([^|]+)\|([^}]+)\}", lambda m: m[form], text)
        if amount > 1:
            for before, after in replacements:
                text = text.replace(before, after)
        for token, multiple, single in pairs:
            text = text.replace("{" + token + "}", multiple if amount > 1 else single)
        return text
    return apply


def pretty(value):
    return f"{value:.2f}".rstrip("0").rstrip(".") if type(value) in (int, float) else str(value).lower() if type(value) is bool else str(value)


class Generator:
    def __init__(self, modules, data, templates, plural):
        self.modules, self.data, self.templates, self.plural = modules, data, templates, plural

    def fragment(self, name):
        if name not in self.templates:
            raise ValueError(f"missing modular translation: {name}")
        return self.templates[name]

    def formatted(self, name, value, fragment=None):
        row = self.modules[name]
        fragment = self.fragment(name) if fragment is None else fragment
        if not isinstance(fragment, str):
            raise ValueError(f"invalid module fragment: {name}")
        amount = value
        if isinstance(value, list):
            if len(value) != 2:
                raise ValueError(f"invalid module range: {name}")
            formatted = pretty(value[0]) + "-" + pretty(value[1])
            amount = value[1]
        elif type(value) in (int, float):
            sign = "" if row["HideSign"] else "x" if row["IsMultiplier"] else "+" if value > 0 else ""
            formatted = sign + pretty(value)
        else:
            formatted, amount = pretty(value), 1
        fragment = fragment.replace("{value}", formatted)
        decoration = ""
        if row["Arrow"]:
            positive = amount >= (1 if row["IsMultiplier"] else 0)
            if row["InvertArrow"]:
                positive = not positive
            decoration = "↑ " if positive else "↓ "
        decoration += row.get("Icon", "")
        return self.plural(re.sub("  +", " ", decoration + " " + fragment).lstrip(), amount)

    def generate(self, data, depth=0):
        if depth > 10:
            raise ValueError("recursive modular description")
        if not isinstance(data, dict):
            return ""
        lines = []
        for name in sorted(data, key=lambda key: -self.modules.get(key, {}).get("Priority", -100000)):
            if name == "Duration":
                continue
            if name not in self.modules:
                raise ValueError(f"unreviewed modular entry: {name}")
            value = data[name]
            if value is False or value is None:
                continue
            if name in NESTED:
                header = self.templates.get(name, "")
                if name == "TimedEffect":
                    header = self.plural(header.replace("{value}", pretty(value["Duration"])), value["Duration"])
                nested = self.generate(value, depth+1)
                nested = "#".join("{{IND}}" + line for line in nested.split("#") if line)
                fragment = "#".join(part for part in (header, nested) if part)
                marker = "{VAR:" + name.upper() + "}"
                existing = "#".join(lines)
                if marker in existing:
                    lines = [existing.replace(marker, fragment)]
                elif fragment:
                    lines.append(fragment)
            elif name == "Spawns":
                fragment = ""
                for kind, number in value.items():
                    fragment += self.modules[name]["Icons"].get(kind, "") + " " + self.formatted(name, number, self.fragment(name)[kind])
                lines.append(fragment)
            elif name == "TearEffect":
                for effect in value if isinstance(value, list) else [value]:
                    lines.append(self.fragment(name)[effect])
            elif name == "FullMapping":
                row = self.fragment(name)
                lines.append(row["BaseDesc"].replace("{exception}", row.get(value, "")).rstrip())
            elif name == "ItemDescription":
                for key in value if isinstance(value, list) else [value]:
                    lines.append(self.generate(self.data.get(key), depth+1))
            elif name == "Variables":
                def replace(match):
                    key = match[1]
                    kind, number = re.fullmatch(r"(.*?)(\d*)", key).groups()
                    entry = value.get(kind, value.get(number, value.get(key)))
                    if entry is None:
                        raise ValueError(f"unresolved modular variable: {key}")
                    return "-".join(map(pretty, entry)) if isinstance(entry, list) else pretty(entry)
                lines = [re.sub(r"\{VAR:([^}]+)\}", replace, "#".join(lines))]
            elif name == "LuckChance":
                # These targets are not yet enabled in upstream's fully automated
                # set. Existing native luck formulas handle their live state.
                raise ValueError("live luck module cannot be precomputed")
            else:
                lines.append(self.formatted(name, value))
        return re.sub("#+", "#", "#".join(lines)).strip("#")


def import_modular(source: Path, languages: dict) -> dict:
    base = source / "descriptions/ab+/item_data.lua"
    if not base.is_file():
        return {}
    base_text = normalize(base.read_text(encoding="utf-8-sig"))
    rep_text = normalize((source / "descriptions/rep/item_data.lua").read_text(encoding="utf-8-sig"))
    enabled = table(base_text, "FullyAutomatedDescriptions")
    enabled.update(table(rep_text, "automatedRep"))
    for key in re.findall(r'EID\.FullyAutomatedDescriptions\["([^"]+)"\]\s*=\s*nil', rep_text):
        enabled.pop(key, None)
    data = table(base_text, "ItemData")
    data.update(table(rep_text, "itemData"))
    modules = behaviors(source)
    english = table((source / "descriptions/modular/en_us.lua").read_text(encoding="utf-8-sig"), "ModularDescriptions")
    for code, pack in languages.items():
        path = source / "descriptions/modular" / (code + ".lua")
        text = normalize(path.read_text(encoding="utf-8-sig")) if path.is_file() else ""
        templates = {**english, **table(text, "ModularDescriptions")}
        ignored = table(text, "IgnoreFullyAutomatedDescriptions")
        plural = pluralizer(source / "descriptions/ab+" / (code + ".lua"), source / "descriptions/ab+/en_us.lua")
        generator = Generator(modules, data, templates, plural)
        output = {}
        for key in sorted(data):
            standard = key
            variant, subtype = map(int, key.split(".")[1:])
            if variant == 70 and subtype > 2048:
                standard = "5.70." + str(subtype - 2048)
            if not enabled.get(key, enabled.get(standard)) or ignored.get(key) or ignored.get(standard):
                continue
            original = data[key]
            row = {"Red": generator.generate(original)}
            # Empty output falls back to legacy data in the original API too.
            if not row["Red"]:
                continue
            for heart, replacements in HEALTH.items():
                adapted = copy.deepcopy(original)
                for before, after in replacements.items():
                    amount = adapted.pop(before, None)
                    if amount is not None and after:
                        adapted[after] = amount + adapted.get(after, 0)
                row[heart] = generator.generate(adapted)
            export_key = "5.1070." + str(subtype-2048) if variant == 70 and subtype>2048 else key
            output[export_key] = row
        pack["modular_descriptions"] = output
    return {"format": 1, "enabled": sorted(key for key, value in enabled.items() if value),
            "item_count": len(data), "module_count": len(modules)}
