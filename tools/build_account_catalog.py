"""Builds assets/account/catalog.json: what the account menus list.

Home's subpages (Achievements, Puzzles, Daily Quests) span every campaign,
not one pack, so their catalogs live outside the packs:

  endings      every ending code with its name and cookie reward (endings.json)
  wallpapers   every puzzle with its pieces' conditions and cookie weights
  stories      campaign names
  universities every university with its achievement region:
               korea (regular), special (story-only), global (study abroad),
               taiwan

Like the packs it is generated from the original data and gitignored.

  python tools/build_account_catalog.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import university_names

D30 = Path(__file__).resolve().parent.parent
PROJECTS = D30.parent
GLOBAL = PROJECTS / "kss/assetpack1_dec/assets/assets/global_data"
OUT = D30 / "assets/account/catalog.json"
# The 1.29.3 puzzle catalog captured by tools/import_wallpapers.py, when
# present: it adds wallpaper1013-1015 and otherwise matches 1.27.4.
NEWER_WALLPAPERS = D30 / "references/recovery/wallpapers-1.29.3/wallpapers.json"
WALLPAPER_IMAGES = D30 / "assets/images/kss/images/wallpaper_image"

REGIONS = {None: "korea", "notReal": "special", "studyAbroad": "global",
           "studyTw": "taiwan"}


def load(name: str):
    return json.loads((GLOBAL / name).read_text(encoding="utf-8"))


def main() -> int:
    if not GLOBAL.exists():
        print(f"missing {GLOBAL}", file=sys.stderr)
        return 1
    university_names.check(load("university/universities.json")["universities"])
    endings = [
        {"code": e["endingCode"], "name": e["endingName"],
         **({"cookies": e["cookieCount"]} if e.get("cookieCount") else {})}
        for e in load("endings.json")["endings"]
    ]
    wallpapers = []
    source = (json.loads(NEWER_WALLPAPERS.read_text(encoding="utf-8"))
              if NEWER_WALLPAPERS.exists() else load("wallpapers.json"))
    for w in source["wallpapers"]:
        row = {
            "id": w["id"], "name": w["name"], "description": w["description"],
            "storyId": w["storyId"], "color": w.get("color"),
            "pieces": [
                {k: v for k, v in p.items() if k in ("type", "endingCode",
                                                     "cookieCount")}
                for p in w["pieces"]
            ],
        }
        if w.get("excludeGacha"):
            row["excludeGacha"] = True
        if w.get("gachaWeight"):
            row["gachaWeight"] = w["gachaWeight"]
        # Full-screen art is bundled for this one (see import_wallpapers.py).
        if (WALLPAPER_IMAGES / f"{w['id']}.png").exists():
            row["fullImage"] = True
        wallpapers.append(row)
    stories = {
        str(s["id"]): s.get("engName") or s.get("name")
        for s in load("stories.json")["stories"]
    }
    universities = [
        {"id": u["id"], "name": university_names.display_name(u),
         "rank": u.get("rank", "none"), "colorCode": u.get("colorCode"),
         "region": REGIONS[u.get("type")], "sortId": u.get("sortId", u["id"])}
        for u in load("university/universities.json")["universities"]
        if u.get("type") in REGIONS
    ]
    universities.sort(key=lambda u: (u["sortId"], u["id"]))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({
        "endings": endings, "wallpapers": wallpapers, "stories": stories,
        "universities": universities,
        "rewards": json.loads((D30 / "content/kss/account-rules.json").read_text(encoding="utf-8")),
    }, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{OUT}: {len(endings)} endings, {len(wallpapers)} puzzles, "
          f"{len(universities)} universities")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
