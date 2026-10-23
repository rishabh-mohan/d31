#!/usr/bin/env python3
"""Copy placeholder art out of the Korean Student Simulator reference trees.

These are **temporary stand-ins** so the UI can be built against real images
instead of grey boxes. They are KSS's art, not ours: local use only, never
redistributed. `assets/images/` is gitignored for exactly that reason.

Everything lands under `assets/images/`, and the pack references it by a path
relative to that directory ("backgrounds/park.png"). The engine resolves such
a path against the pack directory first and the bundled assets second, so a
later pack can ship its own art without touching code.

Usage:
  python tools/copy_assets.py
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
D30 = HERE.parent
PROJECTS = D30.parent

KSS = PROJECTS / "kss/assetpack1_dec/assets/assets"
BG14 = KSS / "stories/14/backgroundImgs"
NPCS16 = KSS / "stories/16/npcs"
MODULES = KSS / "images/modules"

OUT = D30 / "assets" / "images"

# Story 14's backgrounds are the only ones present on disk as files (story
# 16 streams its own), so they stand in for story 16's locations. Mapped by
# feel, not by meaning -- these are placeholders.
BACKGROUNDS = {
    "park": "fd31fde0-0282-11ee-b0c9-fdb1052b04a0.png",      # 공원
    "study_cafe": "d3750c10-02df-11ee-9982-81b28a5bf9b9.png", # 스터디카페
    "hallway": "0953c6d0-0c5a-11ef-81a7-571007f9d6b7.png",    # 복도
    "university": "257edcc0-0c76-11ef-81a7-571007f9d6b7.png", # 대학
    "university2": "f2985b30-0c9b-11ef-a9c0-f7d533c38241.png",# 대학2
    "alley": "92143f30-0225-11ee-a05a-25b2ab36f585.png",      # 골목길
    "factory": "78757670-1823-11ee-945b-25f1819863ae.png",    # 공장
    "night_park": "9ae91e10-09ee-11ef-8e4a-43f2d93e96a1.png", # 밤공원
    "dark": "963681f0-0283-11ee-b0c9-fdb1052b04a0.png",       # 검은색
}

# Which background each of story 16's locations borrows.
LOCATION_BACKGROUND = {
    1000: "hallway",      # School
    2000: "study_cafe",   # Home
    16000: "university2", # Art Museum
    16001: "factory",     # Gold Mine
    16002: "park",        # Park
    16003: "study_cafe",  # Reading Room
    16004: "study_cafe",  # Cafe
    16005: "factory",     # Gym
    16006: "alley",       # PC Bang
    16007: "park",        # Soccer Practice Field
    16008: "factory",     # Studio
}

# A finished character portrait, used as the player stand-in.
CHARACTER = NPCS16 / "19a22820-4826-11f0-ba11-7be87f7e9617.png"

UI_ICONS = {
    "cookie.png": MODULES / "../cookie_parade/cookie_default.png",
}


def copy(src: Path, dst: Path) -> bool:
    if not src.exists():
        print(f"  MISSING {src}")
        return False
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    return True


def main() -> int:
    if not KSS.exists():
        print(f"reference tree not found: {KSS}", file=sys.stderr)
        return 1

    print(f"copying placeholder art -> {OUT}")

    n = 0
    print(" backgrounds")
    for name, filename in BACKGROUNDS.items():
        if copy(BG14 / filename, OUT / "backgrounds" / f"{name}.png"):
            n += 1

    print(" character")
    copy(CHARACTER, OUT / "character" / "portrait.png")

    print(" stationery")
    equipment = json.loads((KSS / "global_data/equipment_items.json").read_text(encoding="utf-8"))["equipmentItems"]
    for item in equipment:
        source = KSS / item["imgPath"].removeprefix("assets/")
        copy(source, OUT / "stationery" / f"{item['id']}.png")

    print(" ui")
    for name, src in UI_ICONS.items():
        copy(src.resolve(), OUT / "ui" / name)

    print(" items")
    items_src = MODULES / "item"
    items = 0
    if items_src.exists():
        pack_items = D30 / "packs" / "kss16" / "items.json"
        wanted = None
        if pack_items.exists():
            with pack_items.open(encoding="utf-8") as fh:
                wanted = {i["id"] for i in json.load(fh)["items"]}
        for src in sorted(items_src.glob("*.png")):
            item_id = int(src.stem) if src.stem.isdigit() else None
            if wanted is not None and item_id not in wanted:
                continue
            if copy(src, OUT / "items" / src.name):
                items += 1

    print(f"done: {n} backgrounds, 1 character, {len(UI_ICONS)} ui, {items} items")

    # Write the location -> background mapping into the pack so the UI reads
    # it as data rather than hardcoding it.
    locations_file = D30 / "packs" / "kss16" / "locations.json"
    if locations_file.exists():
        with locations_file.open(encoding="utf-8") as fh:
            data = json.load(fh)
        for loc in data["locations"]:
            name = LOCATION_BACKGROUND.get(loc["id"])
            if name:
                loc["image"] = f"backgrounds/{name}.png"
        with locations_file.open("w", encoding="utf-8", newline="\n") as fh:
            json.dump(data, fh, ensure_ascii=False, indent=1)
            fh.write("\n")
        print(f" wrote `image` onto {len(data['locations'])} locations")
    else:
        print(" (pack not built yet -- run tools/build_pack.py, then re-run this)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
