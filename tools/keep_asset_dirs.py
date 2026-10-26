"""Make every asset directory pubspec.yaml declares exist, with a .gitkeep.

Flutter refuses to build when a declared asset directory is missing. The
generated packs (packs/) and imported art (assets/images/, assets/account/)
are local-only and gitignored, so a fresh clone would not have those
directories at all. Each declared directory therefore carries an empty
.gitkeep, which .gitignore re-includes; the generated content around it
stays ignored.

    python tools/keep_asset_dirs.py          # create missing dirs + .gitkeep

tools/import_all_images.py runs this after rewriting its pubspec block.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PUBSPEC = ROOT / "pubspec.yaml"
ASSET_LINE = re.compile(r"^\s+-\s+([^\s#]+/)\s*(#.*)?$")


def declared_directories() -> list[str]:
    """Directory entries (ending in /) under flutter: assets:."""
    dirs: list[str] = []
    in_assets = False
    for line in PUBSPEC.read_text(encoding="utf-8").splitlines():
        if re.match(r"^  assets:\s*$", line):
            in_assets = True
            continue
        if in_assets:
            if line.strip() == "" or line.lstrip().startswith("#"):
                continue
            match = ASSET_LINE.match(line)
            if match:
                dirs.append(match.group(1))
            elif not line.startswith("    "):
                in_assets = False
    return dirs


def main() -> None:
    created = 0
    for d in declared_directories():
        keep = ROOT / d / ".gitkeep"
        if not keep.exists():
            keep.parent.mkdir(parents=True, exist_ok=True)
            keep.write_text("", encoding="utf-8")
            created += 1
    print(f"{len(declared_directories())} declared asset directories; {created} .gitkeep files added")


if __name__ == "__main__":
    main()
