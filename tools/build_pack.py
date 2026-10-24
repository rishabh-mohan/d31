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
import presentation_assets  # noqa: E402

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
STORY_ID = 16


def legacy_label_pairs(relative):
    """Reuse exact Korean -> English labels from the older localized project.

    Only display strings are paired; no rules, IDs, thresholds or graph edges
    are copied. Ambiguous translations are deliberately omitted.
    """
    reference = PROJECTS / 'korstu4CLAUDE/private-build/korean-base/campaign-localized-v2/story-16'
    source = GLOBAL.parent / 'stories/16' / relative
    localized = reference / relative
    if not source.exists() or not localized.exists():
        return {}
    pairs = {}
    def walk(a, b):
        if isinstance(a, list) and isinstance(b, list) and len(a) == len(b):
            for x, y in zip(a, b):
                walk(x, y)
        elif isinstance(a, dict) and isinstance(b, dict):
            if a.get('id') != b.get('id'):
                return
            for key in a.keys() & b.keys():
                x, y = a[key], b[key]
                if key in ('name', 'text') and isinstance(x, str) and isinstance(y, str):
                    if re.search(r'[\uac00-\ud7a3]', x) and y.strip() and not re.search(r'[\uac00-\ud7a3]', y):
                        pairs.setdefault(x, set()).add(y)
                elif isinstance(x, (dict, list)):
                    walk(x, y)
    walk(load(source), load(localized))
    return {source: next(iter(values)) for source, values in pairs.items() if len(values) == 1}

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


# Storyline beats whose prerequisite the shipped data does not carry.
#
# KSS runs an event *set* one beat at a time in compiled code, so a beat can
# rely on that sequencing instead of stating it. 189 "Come On!" -- the teacher
# walking you over to the comic club -- is gated on nothing but its date, and
# fires whether or not 188 "School Comics Contest" ever happened, which reads
# as the teacher reacting to a comic you never drew. Both of 188's branches
# ("Enter" / "No thanks") converge on submitting the comic, so completing 188
# is the whole prerequisite; no branch needs telling apart.
#
# Written as `EVENT_<id> == 2`, the same shape the data uses itself for
# 192 (`EVENT_191 == 2`) and 162 (`EVENT_60 == 2`): 0 unseen, 1 playing,
# 2 finished.
SET_PREREQUISITES = {189: 188}


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
    for e in events:
        required = SET_PREREQUISITES.get(e["id"]) if STORY_ID == 16 else None
        if required is None:
            continue
        e["conditionSet"]["right"]["conditions"].append({
            "type": "defaults", "target": f"EVENT_{required}",
            "compareType": "equal", "value": 2, "targetType": "event"})
    npcs = {}
    for file in [GLOBAL / "npcs.json", ENGLISH / "data/npcs.json"]:
        for npc in load(file)["npcs"]:
            npcs[npc["id"]] = {"id": npc["id"], "name": " ".join(
                filter(None, [npc.get("firstName"), npc.get("lastName")])).replace("_", " ")}
    write(out, "events/events.json", {"events": events, "nodes": nodes,
        "speakers": list(npcs.values()), "source": f"1.27.4 story {STORY_ID}; authored translations where available"})

    switches = clean(load(ENGLISH / "event/event_switches.json"))["eventSwitches"]
    for s in switches:
        s.pop("description", None)
    write(out, "events/switches.json", {"switches": switches})

    sets = clean(load(ENGLISH / "event/event_sets.json"))["eventSets"]
    write(out, "events/sets.json", {"eventSets": sets})
    # Host-triggered global dialogue is separate from random story eligibility.
    system = english(load(GLOBAL / "events/system_events.json"))
    bindings = {"exhaustion": 10000000, "exerciseLevelUp": 10000002,
                "partTimeLevelUp": 10000003}
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


# rank -> the stars the Student ID card shows.
CHARACTER_STARS = {"one": 1, "two": 2, "three": 3}


def build_characters(out: Path):
    """The character-select catalog, filtered to this story.

    The global file carries 65 characters for every story; `availableStoryIds`
    containing 16 is what makes one selectable here, and 26 are. Portraits are
    copied by tools/copy_assets.py from each character's `skeleton.imgPath`.
    """
    chars = clean(load(GLOBAL / "characters.json"))["characters"]
    out_chars = []
    for c in chars:
        if STORY_ID not in (c.get("availableStoryIds") or []):
            continue
        entry = {
            "id": c["id"],
            "name": " ".join(filter(None, [c.get("firstName"), c.get("lastName")])),
            "gender": c.get("genderType"),
            "rank": c.get("rank"),
            "stars": CHARACTER_STARS.get(c.get("rank"), 1),
            "isDefault": c.get("isDefault", False),
            # Display prose. NOT the mechanic: Siho Kang reads "+3" while the
            # structured effect is extraStat 6. The effect is what applies.
            "effectDescription": c.get("effectDescription", ""),
            "portrait": f"characters/{c['id']}.png",
        }
        if c.get("plusEffect"):
            entry["plusEffect"] = c["plusEffect"]
        if c.get("specialFuncCode"):
            entry["specialFuncCode"] = c["specialFuncCode"]
        out_chars.append(entry)
    out_chars.sort(key=lambda c: c["id"])
    write(out, "characters.json", {"characters": out_chars},
          f"Story-{STORY_ID} selectable characters. effectDescription is display prose; "
          "plusEffect is the mechanic.")
    print(f"    {len(out_chars)} of {len(chars)} characters are story {STORY_ID}'s")


def build_badges(out: Path):
    """University badges, joined to the university that issues them.

    The badge screen lists them alphabetically and prints each effect, so the
    name and the effect both have to travel with the record.
    """
    badges = clean(load(GLOBAL / "university_badges.json"))["badges"]
    unis = {u["id"]: u for u in
            clean(load(GLOBAL / "university/universities.json"))["universities"]}
    out_badges = []
    for b in badges:
        uni = unis.get(b["universityId"], {})
        out_badges.append({
            "universityId": b["universityId"],
            "name": uni.get("engName") or uni.get("korName") or
                    f"University {b['universityId']}",
            "rank": uni.get("rank", "none"),
            "colorCode": uni.get("colorCode"),
            "effects": b.get("effect") or [],
        })
    # "(Alphabetical order)", as the screen says.
    out_badges.sort(key=lambda b: b["name"].lower())
    write(out, "badges.json", {"badges": out_badges})
    print(f"    {len(out_badges)} university badges")


def build_locations(out: Path):
    locs = clean(load(CAMPAIGN / "data/locations.json"))["locations"]
    labels = legacy_label_pairs('data/locations.json') if STORY_ID == 20 else {}
    image_paths = presentation_assets.location_images(STORY_ID)
    for loc in locs:
        loc["image"] = image_paths.get(loc["id"])
        for action in loc.get('actions', []):
            if action.get('text') in labels:
                action['text'] = labels[action['text']]
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
    if STORY_ID == 20:
        labels = legacy_label_pairs('data/part_time_job_info.json')
        for level in ptj.get('levelList', []):
            if level.get('name') in labels:
                level['name'] = labels[level['name']]

    # The translation pass localised the part-time *level* names but not the
    # per-location shift names -- `textList` is not in its whitelist, so 80 of
    # 90 strings stayed Korean. The English 1.27.4 build ships those same
    # lists already translated, so lift them. (CLAUDE.md: prefer the English
    # build's own wording over a fresh translation.)
    english_ptj = ENGLISH / "data/part_time_job_info.json"
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
        s for s in load(GLOBAL / "stories.json")["stories"] if s.get("id") == STORY_ID
    )
    special = clean(load(CAMPAIGN / "data/special_days.json"))["specialDays"]
    todos = clean(load(CAMPAIGN / "data/todos.json"))

    manifest = {
        "id": f"kss{STORY_ID}",
        # The trait catalog is global and scopes 104 of its 244 traits to a
        # story; the engine rejects the ones that are not this story's.
        "storyId": STORY_ID,
        "name": "31-Day Mode" if STORY_ID == 16 else "Retry Year",
        "description": story.get("description", ""),
        "formatVersion": 1,
        "source": f"Korean Student Simulator story {STORY_ID}, as reference. Local use.",
        "portStatus": "prototype" if STORY_ID == 20 else "standard",
        "dialogueLanguage": "en",
        "calendar": {
            "startDate": story["startDate"]["dateCode"],
            "endDate": story["endDate"]["dateCode"],
            "birthDate": story["birthDate"]["dateCode"],
            "ticksPerDay": 15,
        },
        "start": {
            # The generic metadata says classroom; story 20's opening places
            # the player in reflection (event 3 + SET_DOK_BANG native callback).
            "locationId": 20007 if STORY_ID == 20 else story.get("startLocationId", 1000),
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
        # shown in the top bar. Both are account-level in the original; until
        # account progression exists, every run simply starts with these.
        "refresh": {"initial": 50},
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
            # Class costs a little less than studying. The reference's
            # first Class block of a run reads -9, so this is the whole
            # lesson cost at exercise level 0 with no trait discount.
            "lesson": 9,
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
            "hpMaxPerLevel": 0,
        },
        # Provisional balance, NOT recovered original percentages. AOTopsy's
        # combination/draw calls are unresolved; see docs/STATIONERY.md.
        "stationery": {
            "drawWeights": {"S": 1, "A": 9, "B": 30, "C": 60},
            "redrawCookies": 1,
            # User-confirmed best-input tier floor; original odds unresolved.
            "combineUpgradeChance": 0.05,
        },
        "traits": {
            # The 244-trait catalog ships its own effectList, so this is the
            # one system that is data rather than a fit. lib/engine/traits.dart
            # reads it.
            "enabled": True,
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
    if STORY_ID == 20:
        rules['school']['lessonsOnFirstDay'] = False
        rules['school']['suppressedBySwitch'] = 'DOK_BANG_ON'
        rules['events'].update({
            # 1's SHOW_ENDING raises START; 169 unlocks 2; 3 is the first-day
            # reflection conversation. All occur before spending a block.
            'openingEventIds': [1, 169, 2, 3],
            'openingContinuationSwitches': {'1': 'START'},
            'scheduledBypassDailyCap': True,
            'checkAtDayStart': True,
            'chainScheduledEvents': True,
            'executeFakeEvents': True,
            'deferEveningRollover': True,
        })
        rules['reflectionRoom'] = {
            'locationId': 20007,
            'exitLocationId': 1000,
            'ordinaryLocationIds': [1000, 2000, 20002, 20003, 20004],
        }
        todos = load(CAMPAIGN / 'data/todos.json')
        rules['tasks'] = {'enabled': True, 'initial': [
            row for rows in todos.values() if isinstance(rows, list)
            for row in rows if isinstance(row, dict) and 'id' in row and 'date' in row
        ]}
    write(out, "rules.json", rules)


def main() -> int:
    global STORY_ID, CAMPAIGN, CAMPAIGN_SRC, ENGLISH
    ap = argparse.ArgumentParser()
    ap.add_argument("--story", type=int, choices=[16, 20], default=16)
    ap.add_argument("--out")
    args = ap.parse_args()
    STORY_ID = args.story
    ENGLISH = GLOBAL.parent / f"stories/{STORY_ID}"
    if STORY_ID != 16:
        CAMPAIGN = ENGLISH
        CAMPAIGN_SRC = ENGLISH
    out = Path(args.out or D30 / "packs" / f"kss{STORY_ID}").resolve()

    for required in (CAMPAIGN, GLOBAL):
        if not required.exists():
            print(f"missing source tree: {required}", file=sys.stderr)
            return 1

    print(f"building pack -> {out}")
    out.mkdir(parents=True, exist_ok=True)

    print(" manifest")
    build_calendar_and_manifest(out)
    print(" characters")
    build_characters(out)
    print(" badges")
    build_badges(out)
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
    presentation_assets.build(out, story_id=STORY_ID)
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
