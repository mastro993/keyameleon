import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
UI_ROOT = ROOT / "Sources" / "UI"
VIEW_DECLARATION = re.compile(
    r"(?m)^\s*(?P<access>public|internal|private|fileprivate|package)?\s*"
    r"struct\s+(?P<name>[A-Za-z_]\w*)(?:<[^>\n]*>)?\s*:\s*(?:some\s+)?View\b"
)
PREVIEW_DECLARATION = re.compile(r"#Preview\(\s*\"[^\"]+\"\s*\)")


class PreviewCoverageTests(unittest.TestCase):
    def test_non_private_views_have_named_previews(self):
        missing = []
        for path in sorted(UI_ROOT.rglob("*.swift")):
            if "PreviewSupport" in path.parts:
                continue
            source = path.read_text()
            declarations = [
                match.group("name")
                for match in VIEW_DECLARATION.finditer(source)
                if match.group("access") not in {"private", "fileprivate"}
            ]
            if not declarations:
                continue
            previews = PREVIEW_DECLARATION.findall(source)
            if not previews:
                missing.extend(
                    f"{path.relative_to(ROOT)}::{name}" for name in declarations
                )
        self.assertEqual(missing, [])

    def test_preview_fixtures_are_debug_only(self):
        path = UI_ROOT / "PreviewSupport" / "KeyameleonPreviewFixtures.swift"
        source = path.read_text()
        self.assertTrue(source.lstrip().startswith("#if DEBUG"))
        self.assertTrue(source.rstrip().endswith("#endif"))


if __name__ == "__main__":
    unittest.main()
