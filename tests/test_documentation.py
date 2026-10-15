#!/usr/bin/env python3
"""Check local screenshot references and published version/resource metadata."""

import json
import plistlib
import re
import struct
import unittest
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
SCREENSHOTS = {
    "eid-absorption-preview.png",
    "eid-spindown-preview.png",
    "eid-collection-reminder.png",
    "eid-current-luck.png",
}


class Page(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.elements = []
        self.feed(source)

    def handle_starttag(self, tag, attrs):
        self.elements.append((tag, dict(attrs)))


class DocumentationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.readme = (ROOT / "README.md").read_text(encoding="utf-8")
        cls.html = (ROOT / "docs/index.html").read_text(encoding="utf-8")
        cls.page = Page(cls.html)

    def test_new_screenshots_in_both_galleries(self):
        images = {attrs.get("src"): attrs for tag, attrs in self.page.elements if tag == "img"}
        for name in SCREENSHOTS:
            with self.subTest(screenshot=name):
                self.assertIn(f'docs/images/{name}', self.readme)
                attrs = images[f"images/{name}"]
                self.assertGreater(len(attrs.get("alt", "")), 30)
                self.assertEqual(attrs.get("width"), "2436")
                self.assertEqual(attrs.get("height"), "1125")
                data = (ROOT / "docs/images" / name).read_bytes()
                self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
                self.assertEqual(struct.unpack(">II", data[16:24]), (2436, 1125))

    def test_local_website_references(self):
        ids = {attrs["id"] for _, attrs in self.page.elements if "id" in attrs}
        for tag, attrs in self.page.elements:
            for attribute in ("src", "href"):
                value = attrs.get(attribute, "")
                url = urlsplit(value)
                if not value or url.scheme or url.netloc:
                    continue
                if url.path:
                    self.assertTrue((ROOT / "docs" / unquote(url.path)).is_file(), (tag, value))
                elif url.fragment:
                    self.assertIn(unquote(url.fragment), ids)

    def test_readme_image_references(self):
        paths = re.findall(r'(?:src="|!\[[^\]]*\]\()([^"\s)]+\.png)', self.readme)
        self.assertTrue(paths)
        for path in paths:
            self.assertTrue((ROOT / path).is_file(), path)

    def test_version_and_resource_pin_agree(self):
        control = (ROOT / "package/control").read_text(encoding="utf-8")
        version = re.search(r"^Version: (.+)$", control, re.MULTILINE).group(1)
        info = plistlib.loads((ROOT / "livecontainer/Info.plist").read_bytes())
        self.assertEqual(info["CFBundleShortVersionString"], version)
        self.assertIn(f"What's new in v{version}", self.readme)
        self.assertTrue((ROOT / f"docs/RELEASE_NOTES_v{version}.md").is_file())
        metadata = re.search(r'<script type="application/ld\+json">(.*?)</script>', self.html).group(1)
        self.assertEqual(json.loads(metadata)["softwareVersion"], version)
        database = json.loads((ROOT / "data/descriptions.json").read_text(encoding="utf-8"))
        workflow = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
        self.assertIn(f"ref: {database['source_commit']}", workflow)


if __name__ == "__main__":
    unittest.main()
