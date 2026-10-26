#!/usr/bin/env python3
"""Mirror every KSS base-game and Retry Year image into assets/images/kss/.

Temporary stand-ins, like everything copy_assets.py produces: KSS's art,
local use only, gitignored under /assets/images/.

Sources, in the order presentation_assets.source_for() checks them:
  - the asset pack (kss/assetpack1_dec/assets/assets) -- every image on disk,
    all stories included;
  - the base APK (kss/kss_dec/assets/flutter_assets/assets);
  - story 16 and story 20 art that the game streams instead of shipping.
    Each catalog row's imgPathFromHttp is downloaded into
    build/presentation-source/, the cache presentation_assets.py already reads,
    so re-running that script afterwards picks the recovered art up too.

Every file keeps its original path minus the leading "assets/", so a catalog
imgPath "assets/stories/20/npcs/x.png" is the pack-relative image
"kss/stories/20/npcs/x.png". Flutter does not bundle directories recursively,
so the script rewrites the generated block in pubspec.yaml to list each one.

Usage:
  python tools/import_all_images.py              # copy, fetch, update pubspec
  python tools/import_all_images.py --no-fetch   # offline: disk + cache only
"""

from __future__ import annotations

import argparse
import io
import json
import shutil
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import keep_asset_dirs
from presentation_assets import BASE, CACHE, ROOT, SOURCE

sys.stdout.reconfigure(encoding="utf-8")

OUT = ROOT / "assets/images/kss"
PUBSPEC = ROOT / "pubspec.yaml"
REPORT = ROOT / "build/import-all-images-report.json"
STREAMED_STORIES = (16, 20)
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg"}
BEGIN = "    # BEGIN import_all_images.py -- generated, do not edit"
END = "    # END import_all_images.py"


def images_under(root: Path):
    for path in root.rglob("*"):
        if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES:
            yield path.relative_to(root).as_posix()


def image_rows(value):
    if isinstance(value, dict):
        if isinstance(value.get("imgPath"), str):
            yield value
        for child in value.values():
            yield from image_rows(child)
    elif isinstance(value, list):
        for child in value:
            yield from image_rows(child)


def streamed_rows(story_id: int):
    """Every catalog row in a story that names an image, keyed by imgPath."""
    rows = {}
    for path in sorted((SOURCE / f"stories/{story_id}").rglob("*.json")):
        if path.stem.endswith("_tw"):
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (ValueError, UnicodeDecodeError):
            continue
        for row in image_rows(data):
            rows.setdefault(row["imgPath"], row)
    return rows


def fetch(row) -> str:
    """Download one streamed image into the cache; returns an outcome label."""
    from PIL import Image

    target = CACHE / Path(row["imgPath"]).name
    if target.exists():
        return "cached"
    url = row.get("imgPathFromHttp")
    if not url:
        return "no-url"
    try:
        payload = urllib.request.urlopen(url, timeout=20).read()
        with Image.open(io.BytesIO(payload)) as image:
            image.verify()
    except Exception as error:
        return f"failed: {getattr(error, 'code', type(error).__name__)}"
    target.write_bytes(payload)
    return "fetched"


def update_pubspec(directories: list[str]) -> None:
    text = PUBSPEC.read_text(encoding="utf-8")
    block = "\n".join([BEGIN, *(f"    - assets/images/kss/{d}/" for d in directories), END])
    if BEGIN in text:
        head, rest = text.split(BEGIN, 1)
        text = head + block + rest.split(END, 1)[1]
    else:
        anchor = "    - assets/images/stationery/\n"
        if anchor not in text:
            raise SystemExit(f"cannot find {anchor.strip()!r} in pubspec.yaml")
        text = text.replace(anchor, anchor + block + "\n", 1)
    # Keep the file's own line endings; the repo mixes LF and CRLF.
    newline = "\r\n" if b"\r\n" in PUBSPEC.read_bytes() else "\n"
    PUBSPEC.write_text(text, encoding="utf-8", newline=newline)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-fetch", action="store_true",
                        help="skip downloading streamed story 16/20 art")
    args = parser.parse_args()

    for root in (SOURCE, BASE):
        if not root.exists():
            print(f"reference tree not found: {root}", file=sys.stderr)
            return 1

    # relative path -> source file; the asset pack wins where both ship one.
    files: dict[str, Path] = {}
    for root in (SOURCE, BASE):
        for relative in images_under(root):
            files.setdefault(relative, root / relative)
    on_disk = len(files)

    wanted = [row for story in STREAMED_STORIES
              for path, row in streamed_rows(story).items()
              if path.removeprefix("assets/") not in files]
    if args.no_fetch:
        outcomes = {row["imgPath"]: "cached" if (CACHE / Path(row["imgPath"]).name).exists()
                    else "not fetched" for row in wanted}
    else:
        CACHE.mkdir(parents=True, exist_ok=True)
        print(f"fetching {len(wanted)} streamed images for stories "
              f"{', '.join(map(str, STREAMED_STORIES))}")
        with ThreadPoolExecutor(max_workers=8) as pool:
            outcomes = {row["imgPath"]: outcome
                        for row, outcome in zip(wanted, pool.map(fetch, wanted))}
    for path in outcomes:
        cached = CACHE / Path(path).name
        if cached.exists():
            files[path.removeprefix("assets/")] = cached

    print(f"copying {len(files)} images -> {OUT}")
    for relative, source in files.items():
        dest = OUT / relative
        if dest.exists() and dest.stat().st_size == source.stat().st_size:
            continue
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, dest)

    directories = sorted({Path(r).parent.as_posix() for r in files})
    update_pubspec(directories)
    # A fresh clone has none of this art; give each new declared directory a
    # tracked .gitkeep so the build still finds it.
    keep_asset_dirs.main()

    unavailable = {p: o for p, o in outcomes.items() if o not in ("fetched", "cached")}
    REPORT.parent.mkdir(exist_ok=True)
    REPORT.write_text(json.dumps({
        "onDisk": on_disk,
        "streamed": sum(1 for o in outcomes.values() if o in ("fetched", "cached")),
        "total": len(files),
        "directories": len(directories),
        "unavailable": dict(sorted(unavailable.items())),
    }, indent=2) + "\n", encoding="utf-8")
    print(f"done: {on_disk} on disk + {len(files) - on_disk} streamed = {len(files)} images "
          f"in {len(directories)} directories; {len(unavailable)} unavailable "
          f"(see build/{REPORT.name})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
