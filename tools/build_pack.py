#!/usr/bin/env python3
"""Build the `kss16` content pack for d30mode from the Korean Student Simulator
reference data already extracted in this workspace.

Reproducible: delete packs/kss16 and re-run. Nothing here is hand-edited output --
if you want to change the game, edit the generated pack (it is plain JSON), or
change this script and rebuild.

Sources (read-only):
  korstu4CLAUDE/private-build/korean-base/campaign-localized-v2/story-16/
      non-event campaign data (locations, items, calendar)
  kss/assetpack1_dec/assets/assets/stories/16/
      English 1.27.4 event graph, switches, sets, NPCs
  kss/assetpack1_dec/assets/assets/global_data/
      the English 1.27.4 build's global catalogs (traits, items, levels, books)

Usage:
  python tools/build_pack.py [--out packs/kss16]
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import item_effects  # noqa: E402

sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
D30 = HERE.parent
PROJECTS = D30.parent

CAMPAIGN = (
    PROJECTS
    / "korstu4CLAUDE/private-build/korean-base/campaign-localized-v2/story-16"
)
CAMPAIGN_SRC = (
    PROJECTS / "korstu4CLAUDE/private-build/korean-base/campaign-source/story-16"
)
GLOBAL = PROJECTS / "kss/assetpack1_dec/assets/assets/global_data"
ENGLISH = GLOBAL.parent / "stories/16"

# Keys that are pure plumbing for the original engine: version gates, Firebase
# ids, CDN mirrors of local paths, and the translation bookkeeping. The d30
# engine reads none of them, and they trebled the size of the editable files.
DROP_KEYS = {
    "minVersion",
    "maxVersion",
    "firebaseId",
    "uuid",
    "imgPathFromHttp",
    "backgroundImgFromHttp",
    "startBgmPathFromHttp",
    "originTextVersion",
    "originElseTextVersion",
    "originOptionTextVersion",
    "translatedText",
    "translatedElseText",
    "translatedOptionText",
    "translatedTextVersion",
    "translatedElseTextVersion",
    "translatedOptionTextVersion",
    "nameTw",
    "twName",
    "twDescription",
    "originName",
    "originDescription",
    "originEffectText",
    "korName",
    "korDescription",
    "bannerAdId",
}


def load(path: Path):
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def clean(obj, drop=DROP_KEYS):
    """Recursively drop plumbing keys and nulls that carry no meaning."""
    if isinstance(obj, dict):
        out = {}
        for k, v in obj.items():
            if k in drop:
                continue
            cv = clean(v, drop)
            if cv is None and k not in KEEP_NULL:
                continue
            out[k] = cv
        return out
    if isinstance(obj, list):
        return [clean(v, drop) for v in obj]
    return obj


# Nulls that are load-bearing: the engine distinguishes "absent" from "ends here".
KEEP_NULL = {"nextNodeId", "nextLinkedBoxId", "elseText"}


def write(out: Path, name: str, data, note: str | None = None):
    path = out / name
    path.parent.mkdir(parents=True, exist_ok=True)
    if note and isinstance(data, dict):
        data = {"_note": note, **data}
    with path.open("w", encoding="utf-8", newline="\n") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)
        fh.write("\n")
    kb = path.stat().st_size / 1024
    print(f"  {name:28s} {kb:9.1f} KB")
    return path


# --------------------------------------------------------------------------
# Item effects
#
# KSS keeps item effects in the compiled engine, keyed by item id -- they are
# not in any JSON. To make items modifiable they have to become data, so we
# parse the human-readable `effectText` into structured effects. Anything the
# parser does not recognise is emitted with `effects: []` and an `unparsed`
# field, so it is visible and hand-editable rather than silently dropped.
# --------------------------------------------------------------------------

def build_items(out: Path):
    story_consume = load(CAMPAIGN / "item/story_consume_items.json")["items"]
    story_normal = load(CAMPAIGN / "item/story_normal_items.json")["items"]
    global_consume = load(GLOBAL / "item/global_consume_items.json")["items"]
    global_normal = load(GLOBAL / "item/global_normal_items.json")["items"]

    items = []
    unparsed = 0
    for src, kind, scope in (
        (global_consume, "consume", "global"),
        (global_normal, "normal", "global"),
        (story_consume, "consume", "story"),
        (story_normal, "normal", "story"),
    ):
        for it in src:
            # Reference Store: CONSUME_STAT_30 -> +90 (Weird Workbook),
            # NORMAL_STAT_1 -> +3 (Book Stand), CONSUME_STAT_150 -> +450.
            # Resolve before parsing so UI text and applied effects agree.
            effect_text = re.sub(r"(?:CONSUME_STAT_|NORMAL_STAT_)(\d+)",
                lambda m: str(int(m.group(1)) * 3), it.get("effectText") or "")
            effects, raw, flavour = item_effects.parse(effect_text)
            if raw:
                unparsed += 1
            entry = {
                "id": it["id"],
                "name": it.get("name") or it.get("originName"),
                "kind": kind,
                "scope": scope,
                "description": it.get("description", ""),
                "effectText": effect_text,
                "imgPath": it.get("imgPath"),
                "effects": effects,
            }
            if raw:
                entry["unparsed"] = raw
            if flavour:
                entry["flavour"] = True
            if it.get("maxCount"):
                entry["maxCount"] = it["maxCount"]
            if it.get("detailTypes"):
                entry["detailTypes"] = it["detailTypes"]
            if it.get("locationIdList"):
                entry["locationIdList"] = it["locationIdList"]
            items.append(entry)

    # Later definitions (story) win over global ones with the same id.
    by_id = {it["id"]: it for it in items}
    items = sorted(by_id.values(), key=lambda i: i["id"])
    print(
        f"    {len(items)} items, {unparsed} with effectText the parser could "
        f"not read (left in `unparsed` for hand-editing)"
    )
    return write(
        out,
        "items.json",
        {"items": items},
        "Item effects are DERIVED from effectText -- the original keeps them in "
        "the compiled engine. Entries with an `unparsed` field need effects "
        "written by hand. Edit `effects` freely; see docs/PACK-FORMAT.md.",
    )


# --------------------------------------------------------------------------


def build_events(out: Path):
    def english(obj):
        if isinstance(obj, list):
            return [english(v) for v in obj]
        if not isinstance(obj, dict):
            return obj
        result = {k: english(v) for k, v in obj.items()}
        for translated, target in [("translatedText", "text"),
                ("translatedElseText", "elseText"), ("translatedOptionText", "optionText")]:
            if obj.get(translated) is not None:
                result[target] = obj[translated]
        return result

    src = english(load(ENGLISH / "event/events.json"))
    events = clean(src["events"])
    nodes = clean(src["nodes"])
    for e in events:
        # Events use translatedText for the title, nodes use it for dialogue.
        if e.get("text"):
            e["name"] = e.pop("text")
        e.pop("index", None)
        e.pop("version", None)
    npcs = {}
    for file in [GLOBAL / "npcs.json", ENGLISH / "data/npcs.json"]:
        for npc in load(file)["npcs"]:
            npcs[npc["id"]] = {"id": npc["id"], "name": " ".join(
                filter(None, [npc.get("firstName"), npc.get("lastName")])).replace("_", " ")}
    write(out, "events/events.json", {"events": events, "nodes": nodes,
        "speakers": list(npcs.values()), "source": "English 1.27.4 story 16"})

    switches = clean(load(ENGLISH / "event/event_switches.json"))["eventSwitches"]
    for s in switches:
        s.pop("description", None)
    write(out, "events/switches.json", {"switches": switches})

    sets = clean(load(ENGLISH / "event/event_sets.json"))["eventSets"]
    write(out, "events/sets.json", {"eventSets": sets})
    # Host-triggered global dialogue is separate from random story eligibility.
    system = english(load(GLOBAL / "events/system_events.json"))
    bindings = {"exhaustion": 10000000, "exerciseLevelUp": 10000002}
    host_events = [clean(e) for e in system["events"] if e["id"] in bindings.values()]
    for event in host_events:
        event["name"] = event.pop("text", event["name"])
    by_id = {n["id"]: n for n in system["nodes"]}
    selected = {}
    pending = [e["rootNodeId"] for e in host_events]
    while pending:
        node_id = pending.pop()
        if node_id in selected or node_id not in by_id:
            continue
        node = by_id[node_id]
        selected[node_id] = clean(node)
        if node.get("speakerId") is None:
            selected[node_id]["isHideSpeakerName"] = True
        pending.extend(node[k] for k in ["nextNodeId", "nextNodeIdIfTrue", "nextNodeIdIfFalse"] if node.get(k) is not None)
    write(out, "events/system.json", {"bindings": bindings,
        "events": host_events, "nodes": list(selected.values())})
    print(f"    {len(events)} events, {len(nodes)} nodes, {len(switches)} switches")


def build_commerce(out: Path):
    # Prices/stock observed in the supplied D-31 store screenshot.
    offers = [dict(id=i, itemId=i, price=price, stock=stock)
        for i, price, stock in [(8,1500,2),(3005,9000,1),(18,16000,1),
                               (3028,24000,1),(21,50000,1)]]
    write(out, "commerce.json", {"offers": offers,
        "_note": "First three prices from reference; suit/notebook prices and draw cost are tunable estimates.",
        "stationery": clean(load(GLOBAL / "equipment_items.json"))["equipmentItems"],
        "sets": clean(load(GLOBAL / "equipment_item_sets.json"))["equipmentItemSets"]})


def build_locations(out: Path):
    locs = clean(load(CAMPAIGN / "data/locations.json"))["locations"]
    write(out, "locations.json", {"locations": locs})
    print(f"    {len(locs)} locations")


def build_traits(out: Path):
    traits = clean(load(GLOBAL / "traits.json"))["traitList"]
    write(
        out,
        "traits.json",
        {"traits": traits},
        "effectList is the original engine's own data -- edit values freely.",
    )
    print(f"    {len(traits)} traits")


def build_levels(out: Path):
    study = clean(load(GLOBAL / "study_levels.json"))["levelList"]
    elite = clean(load(GLOBAL / "elite_levels.json"))["levels"]
    exercise = clean(load(CAMPAIGN / "data/exercise_info.json"))
    ptj = clean(load(CAMPAIGN / "data/part_time_job_info.json"))

    # The translation pass localised the part-time *level* names but not the
    # per-location shift names -- `textList` is not in its whitelist, so 80 of
    # 90 strings stayed Korean. The English 1.27.4 build ships those same
    # lists already translated, so lift them. (CLAUDE.md: prefer the English
    # build's own wording over a fresh translation.)
    english_ptj = GLOBAL.parent / "stories/16/data/part_time_job_info.json"
    if english_ptj.exists():
        by_location = {
            e["locationId"]: e.get("textList", [])
            for e in load(english_ptj).get("partTimeJobTextInfoList", [])
            if "locationId" in e
        }
        lifted = 0
        for entry in ptj.get("partTimeJobTextInfoList", []):
            texts = by_location.get(entry.get("locationId"))
            if texts and len(texts) == len(entry.get("textList", [])):
                entry["textList"] = texts
                lifted += 1
        print(f"    lifted English shift names for {lifted} locations")
    write(
        out,
        "levels.json",
        {
            "study": study,
            "elite": elite,
            "exercise": {
                "levels": exercise.get("levelList", []),
                "locationEfficiency": exercise.get("locationEfficiencyList", []),
            },
            "partTimeJob": {
                "levels": ptj.get("levelList", []),
                "textByLocation": ptj.get("partTimeJobTextInfoList", []),
            },
        },
    )
    print(
        f"    study {len(study)}, elite {len(elite)}, "
        f"exercise {len(exercise.get('levelList', []))}, "
        f"part-time {len(ptj.get('levelList', []))}"
    )


def build_books(out: Path):
    books = []
    for subject_dir in sorted((GLOBAL / "book").iterdir()):
        if not subject_dir.is_dir():
            continue
        for f in sorted(subject_dir.glob("[0-9]*_book_*.json")):
            for b in clean(load(f)).get("books", []):
                books.append(b)
    books.sort(key=lambda b: b["id"])
    write(out, "books.json", {"books": books})
    print(f"    {len(books)} books")


def build_calendar_and_manifest(out: Path):
    story = next(
        s for s in load(GLOBAL / "stories.json")["stories"] if s.get("id") == 16
    )
    special = clean(load(CAMPAIGN / "data/special_days.json"))["specialDays"]
    todos = clean(load(CAMPAIGN / "data/todos.json"))

    manifest = {
        "id": "kss16",
        "name": "31-Day Mode",
        "description": story.get("description", ""),
        "formatVersion": 1,
        "source": "Korean Student Simulator story 16, as reference. Local use.",
        "calendar": {
            "startDate": story["startDate"]["dateCode"],
            "endDate": story["endDate"]["dateCode"],
            "birthDate": story["birthDate"]["dateCode"],
            "ticksPerDay": 15,
        },
        "start": {
            "locationId": story.get("startLocationId", 1000),
            "firstName": story.get("maleFirstName", "Basakan"),
            "lastName": story.get("maleLastName", "Kim"),
        },
        # Order is load-bearing: INCREASE_STAT/DECREASE_STAT address subjects
        # by POSITION. Recovered from the Dart enum ordinals in the AOT object
        # dump (analysis/objs.txt): korean=0, math=1, english=2, then the two
        # elective slots tamgoo1=3 / tamgoo2=4, which story 16 fills with
        # science and society.
        "subjects": ["korean", "math", "english", "science", "society"],
        "specialDays": special,
        "todos": todos,
    }
    write(out, "pack.json", manifest)
    print(f"    {manifest['calendar']['startDate']} -> {manifest['calendar']['endDate']}")


def build_rules(out: Path):
    """Every tunable number the engine uses, in one file.

    IMPORTANT: unlike the rest of the pack, these numbers are NOT recovered from
    KSS -- its formulas live in compiled Dart, not in any JSON. They are a
    first-pass model fitted to the data that *is* observable (action weights,
    hpWeight, book power/doneCount, level weight multipliers). Tune freely;
    that is the whole point of the file.
    """
    rules = {
        "_note": "Tuning. NOT recovered from the original -- its formulas are "
        "compiled. Fitted to observable data (action weights, hpWeight, book "
        "power, level weights). Change anything here.",
        "stats": {
            # Every subject starts at 50, as the reference run does.
            "initial": {
                "korean": 50,
                "math": 50,
                "english": 50,
                "science": 50,
                "society": 50,
            },
            "max": 999999,
        },
        "hp": {"initial": 100, "max": 100, "min": 0,
               "exhaustedPenaltyStat": -5,
               "exhaustedForcedSleep": True},
        "money": {"initial": 0, "min": 0},
        # Refresh Tickets redeal the block hand; cookies are the soft currency
        # shown in the top bar.
        "refresh": {"initial": 41},
        "cookies": {"initial": 20},
        "day": {
            "ticksPerDay": 15,
            # How many action blocks are dealt per tick. Compiled in the
            # original; spec says 4-6.
            "blocksPerTick": 4,
            # Only the first 14 ticks are the player's. Tick 14 is the evening
            # slot: no action, and where the day's DATE_..14 content fires.
            "actionTicksPerDay": 14,
            # A Sleep block restores a SMALL amount -- the reference shows
            # +10 at School. Sleep-type locations (Home, Art Museum) give
            # more. It does not end the day.
            "sleepRestoresHp": 10,
            "sleepLocationBonusHp": 5,
        },
        "staminaCost": {
            # cost = base + perWeight * action.hpWeight
            #
            # Fitted to the reference screenshots, whose un-buffed costs are
            # study(hpWeight 1)=16, workout(2.5)=24, part-time(3)=29. A least
            # squares fit over those three lands every one within 1. The
            # buffed shots sit exactly 3 lower, which is the
            # "Indestructible: Stamina Cost -3" trait, so these are the
            # un-buffed baseline.
            "base": 9.5,
            "perWeight": 6.25,
            # Class costs a little less than studying.
            "lesson": 9.5,
        },
        "study": {
            # gained stat = book.power * studyWeight * levelWeight * locationWeight
            # An E-tier textbook is power 5 and the reference Books panel
            # shows it as "+15", so one point of book power is worth 3.
            "studyWeight": 3.0,
            "expPerStudy": 25,
            "hpCostMultiplier": 1.0,
            "comboBonusPercent": 0.05,
            "comboMaxStacks": 5,
        },
        "partTimeJob": {
            # money = baseMoney * levelWeight * locationWeight
            "baseMoney": 500,
            "expPerShift": 60,
            "hpCostMultiplier": 1.0,
        },
        "exercise": {
            "expPerSession": 80,
            "hpCostMultiplier": 1.0,
            "hpMaxPerLevel": 4,
        },
        # Provisional balance, NOT recovered original percentages. AOTopsy's
        # combination/draw calls are unresolved; see docs/STATIONERY.md.
        "stationery": {
            "drawWeights": {"S": 1, "A": 9, "B": 30, "C": 60},
            "redrawCookies": 1,
            "combineWeights": {
                "S": {"S": 100}, "A": {"A": 80, "S": 20},
                "B": {"B": 80, "A": 20}, "C": {"C": 80, "B": 20},
            },
        },
        "traits": {
            # Parked by request: the 244-trait catalog still loads and traits
            # can still be granted, but their effects do nothing.
            "enabled": False,
        },
        "school": {
            # Weekday class: the student is held at School for the first
            #  ticks, and the first block of the hand is a Lesson
            # that Refresh Tickets cannot reroll.
            "lessonsEnabled": True,
            "lessonsOnFirstDay": True,
            "classTicks": 6,
            "locationId": 1000,
            # A lesson's payout is scaled from a real book of its subject,
            # drawn from the lowest  ranks, widening by
            #  each week.
            "lessonRankCap": 3,
            "lessonRankPerWeek": 1,
            "lessonFactor": 1,
            # A lesson rolls its payout inside +/- this fraction of the base,
            # which is what the reference card shows as "+13~35".
            "lessonSpread": 0.45,
        },
        "goals": {
            # PLACEHOLDER. The goal strips above the subject chips. The
            # original generates these in compiled code; see lib/engine/
            # goals.dart.
            # Base rise over the week, before the study-block weighting.
            "weeklyStep": 348,
            # What one study block clicked this week adds to next week's bar.
            # Blocks clicked AFTER the goal is met count here too.
            "perStudyBlock": 12,
            "rewardRatio": 0.74,
        },
        "specialTracks": {
            # The side progressions at School (idol / pro gaming / mechanic /
            # medical / psychic / soccer). KSS runs these in compiled code, so
            # only the switch they advance is recoverable; this is the step
            # size per session.
            "stepPerSession": 1,
        },
        "events": {
            # Chance an eligible random-date event fires on a given tick.
            "randomEventChancePerTick": 0.06,
            "maxEventsPerDay": 1,
            "rankWeights": {"A": 1.0, "B": 2.0, "C": 4.0},
            "priorityOrder": ["veryHigh", "high", "middle", "low"],
        },
        "exam": {
            # Deferred to a later milestone; kept here so the shape is visible.
            "enabled": False,
            "subjectWeights": {
                "korean": 1.0,
                "english": 1.0,
                "math": 1.0,
                "science": 1.0,
                "society": 1.0,
            },
        },
    }
    write(out, "rules.json", rules)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(D30 / "packs" / "kss16"))
    args = ap.parse_args()
    out = Path(args.out).resolve()

    for required in (CAMPAIGN, GLOBAL):
        if not required.exists():
            print(f"missing source tree: {required}", file=sys.stderr)
            return 1

    print(f"building pack -> {out}")
    out.mkdir(parents=True, exist_ok=True)

    print(" manifest")
    build_calendar_and_manifest(out)
    print(" rules")
    build_rules(out)
    print(" locations")
    build_locations(out)
    print(" items")
    build_items(out)
    print(" traits")
    build_traits(out)
    print(" levels")
    build_levels(out)
    print(" books")
    build_books(out)
    print(" events")
    build_events(out)
    build_commerce(out)
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
