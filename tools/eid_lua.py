"""Decode Lua literal string escapes without evaluating Lua code."""
import re


def decode_escapes(text: str) -> str:
    def replace(match):
        token = match[1]
        if token.isdigit():
            value = int(token)
            if value > 255:
                raise ValueError("Lua decimal escape exceeds one byte")
            return chr(value)
        if token.startswith("x") and len(token) == 3:
            return chr(int(token[1:], 16))
        return {"a":"\a", "b":"\b", "f":"\f", "n":"\n", "r":"\r", "t":"\t", "v":"\v"}.get(token, token)
    return re.sub(r"\\(\d{1,3}|x[0-9a-fA-F]{2}|.)", replace, text, flags=re.S)
