import json
import re
import unittest
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CATALOGS = ROOT / "Resources" / "Localization"
SOURCES = ROOT / "Sources"
# The languages of the Keyameleon website.
LANGUAGES = {"en", "ar", "es", "fr", "it", "ja", "ko", "zh-Hans", "zh-Hant"}
FORMAT_SPECIFIER = re.compile(r"%(?:(\d+)\$)?(@|lld|d)")


def catalog(name):
    return json.loads((CATALOGS / name).read_text(encoding="utf-8"))["strings"]


def variants(localization):
    """Every string of one localization, keyed by plural category."""
    if "stringUnit" in localization:
        return {"other": localization["stringUnit"]}
    return {
        category: variant["stringUnit"]
        for category, variant in localization["variations"]["plural"].items()
    }


def specifiers(value):
    """Positional and implicit arguments count the same: `%@` is `%1$@`."""
    found = FORMAT_SPECIFIER.findall(value)
    return Counter(
        (int(position) if position else index, kind)
        for index, (position, kind) in enumerate(found, start=1)
    )


class LocalizationTests(unittest.TestCase):
    def test_every_string_is_translated_into_every_language(self):
        for name in ("Localizable.xcstrings", "InfoPlist.xcstrings"):
            for key, entry in catalog(name).items():
                localizations = entry.get("localizations", {})
                with self.subTest(catalog=name, key=key):
                    self.assertEqual(set(localizations), LANGUAGES)
                    english = variants(localizations["en"])["other"]["value"]
                    for language, localization in localizations.items():
                        units = variants(localization)
                        self.assertIn("other", units, language)
                        for category, unit in units.items():
                            self.assertEqual(unit["state"], "translated", f"{language} {category}")
                            self.assertEqual(
                                specifiers(unit["value"]),
                                specifiers(english),
                                f"{language} {category}: {unit['value']}",
                            )

    def test_strings_are_generated_symbols_used_by_the_app(self):
        source = "\n".join(path.read_text(encoding="utf-8") for path in SOURCES.rglob("*.swift"))
        for key, entry in catalog("Localizable.xcstrings").items():
            with self.subTest(key=key):
                self.assertEqual(entry.get("extractionState"), "manual")
                self.assertRegex(source, rf"\.{re.escape(key)}\b")


if __name__ == "__main__":
    unittest.main()
