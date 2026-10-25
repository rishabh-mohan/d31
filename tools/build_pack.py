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
import us_colleges  # noqa: E402

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
            # The text reads as the reference screenshots do: both tokens show
            # x3 (Book Stand, NORMAL_STAT_1, is "+3"; Weird Workbook,
            # CONSUME_STAT_30, is "+90"). What a passive item grants is one
            # stat per authored unit (user playtest: the x3 boost was three
            # times too strong), so effects are parsed from that scale;
            # consumable grants keep the x3.
            source = it.get("effectText") or ""
            effect_text = re.sub(r"(?:CONSUME_STAT_|NORMAL_STAT_)(\d+)",
                lambda m: str(int(m.group(1)) * 3), source)
            granted_text = re.sub(r"(CONSUME_STAT_|NORMAL_STAT_)(\d+)",
                lambda m: str(int(m.group(2)) * (3 if m.group(1) == "CONSUME_STAT_" else 1)),
                source)
            effects, raw, flavour = item_effects.parse(granted_text)
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

# Speaker names whose first/last order the catalog gets backwards.
SPEAKER_NAMES = {20: {21: "El Niño", 22: "La Niña"}}


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

    def script(name):
        src = english(load(ENGLISH / f"event/{name}"))
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
        if STORY_ID == 20:
            # User-selected prototype rule, 2026-10-25. The imported graph
            # used 40% and a second random herb; keep this override explicit.
            by_id = {n['id']: n for n in nodes}
            required = {23001, 23002, 23004, 23007, 23008}
            assert required <= by_id.keys(), 'Herb Collecting graph changed'
            by_id[23001]['changer']['funcCode'] = 'SCAVENGE_ITEM'
            for node_id, switch in [(23002, 'GATHER_DOUBLE'),
                                    (23008, 'GATHER_GINSENG')]:
                by_id[node_id]['conditionSet'] = {'conditions': [{
                    'target': switch, 'targetType': 'eventSwitch',
                    'compareType': 'equal', 'value': 1}]}
            by_id[23004]['changer'] = {
                'funcCode': 'DUPLICATE_SCAVENGED_ITEM', 'args': []}
            # No ginseng after a successful glove duplicate (including the
            # imported branch's unrelated trait-155 check).
            by_id[23004]['nextNodeId'] = 23007
        return events, nodes

    events, nodes = script("events.json")

    # Character abilities are events too: global character_events.json holds
    # the Beggar's begging, cookie baking, the potion and robot crafting and
    # the rest, each listing the characters it belongs to in characterIdList.
    # Keep the ones for characters this story can pick; the engine plays an
    # event only for the characters it lists.
    story_chars = {c["id"] for c in load(GLOBAL / "characters.json")["characters"]
                   if STORY_ID in (c.get("availableStoryIds") or [])}
    char_src = english(load(GLOBAL / "events/character_events.json"))
    char_events = [e for e in clean(char_src["events"])
                   if set(e.get("characterIdList") or []) & story_chars]
    for e in char_events:
        if e.get("text"):
            e["name"] = e.pop("text")
        e.pop("index", None)
        e.pop("version", None)
    kept = {e["id"] for e in char_events}
    char_nodes = [n for n in clean(char_src["nodes"]) if n["id"] // 1000 in kept]
    events += char_events
    nodes += char_nodes
    print(f"    {len(char_events)} character events for "
          f"{len(story_chars)} playable characters")
    npcs = {}
    for file in [GLOBAL / "npcs.json", ENGLISH / "data/npcs.json"]:
        for npc in load(file)["npcs"]:
            npcs[npc["id"]] = {"id": npc["id"], "name": " ".join(
                filter(None, [npc.get("firstName"), npc.get("lastName")])).replace("_", " ")}
    # First-then-last reverses these two: the dialogue says "El Niño" eight
    # times and "Niño El" never.
    for npc_id, name in SPEAKER_NAMES.get(STORY_ID, {}).items():
        if npc_id in npcs:
            npcs[npc_id]["name"] = name
    write(out, "events/events.json", {"events": events, "nodes": nodes,
        "speakers": list(npcs.values()), "source": f"1.27.4 story {STORY_ID}; authored translations where available"})
    # Retry Year scripts a female protagonist separately: the friends'
    # genders swap (a male Ji Suin and Jian Lee) and the lines follow.
    if STORY_ID == 20 and (ENGLISH / "event/events_female.json").exists():
        f_events, f_nodes = script("events_female.json")
        f_events += char_events
        f_nodes += char_nodes
        write(out, "events/events_female.json", {"events": f_events,
            "nodes": f_nodes, "speakers": list(npcs.values()),
            "source": f"1.27.4 story {STORY_ID}, female protagonist"})

    switches = clean(load(ENGLISH / "event/event_switches.json"))["eventSwitches"]
    # The character events' own counters (MEDICAL_COUNT, ROBOT_LEVEL, ...).
    declared = {s["name"] for s in switches}
    char_switches = load(GLOBAL / "events/character_event_switches.json")
    for s in clean(next(v for v in char_switches.values() if isinstance(v, list))):
        if s["name"] not in declared:
            switches.append(s)
            declared.add(s["name"])
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


# Departments whose application has a condition the catalog only states in
# prose (enApplyConditionDescription). The native checks each with a compiled
# closure; these are the ones a story-16 or story-20 run can meet. A deluxe
# purchase is treated as owned, since this build has no store.
APPLY_REQUIREMENTS = {
    54001: {"items": [90019]},  # Medicine: Student Recommendation (Elite)
    54002: {"items": [90019]},  # Pharmacy: the same, plus the deluxe
}

# University types that a Korean run cannot apply to: the Retry Academy is
# the failure outcome, and the Taiwanese and study-abroad lists belong to
# other regions' builds.
EXCLUDED_UNIVERSITY_TYPES = {"notUniv", "studyTw", "studyAbroad"}


def build_admissions(out: Path):
    """The CSAT application catalog: every university this story can apply to.

    `deviation` is each department's admission cutoff on the CSAT's standard
    score scale (25.3 .. 80.85). Story-only universities (`onlyAvailableStories`)
    appear only in their own story.

    Written as colleges.json (a pack author edits it to change the colleges),
    with colleges_us.json beside it: the US set Settings can switch to, an
    overlay of names and colours by university id (tools/us_colleges.py).
    """
    unis = clean(load(GLOBAL / "university/universities.json"))["universities"]
    depts = clean(load(GLOBAL / "university/departments.json"))["departments"]
    keep = {}
    for u in unis:
        if u.get("type") in EXCLUDED_UNIVERSITY_TYPES:
            continue
        only = u.get("onlyAvailableStories")
        if only and STORY_ID not in only:
            continue
        keep[u["id"]] = {
            "id": u["id"],
            "name": u.get("engName") or u.get("korName") or f"University {u['id']}",
            "rank": u.get("rank", "none"),
            "colorCode": u.get("colorCode"),
            "storyOnly": bool(only),
        }
    out_depts = []
    for d in depts:
        if d["universityId"] not in keep:
            continue
        # Elite Mode departments cannot be entered from a standard run.
        if "Elite Mode" in (d.get("enApplyConditionDescription") or ""):
            continue
        row = {
            "id": d["id"],
            "universityId": d["universityId"],
            "name": d.get("engName") or d.get("name") or f"Department {d['id']}",
            "deviation": d["deviation"],
        }
        if d.get("enApplyConditionDescription"):
            row["condition"] = d["enApplyConditionDescription"]
        if d["id"] in APPLY_REQUIREMENTS:
            row["requires"] = APPLY_REQUIREMENTS[d["id"]]
        out_depts.append(row)
    write(out, "colleges.json", {"universities": list(keep.values()),
                                 "departments": out_depts})
    # The catalog's name before TODO 41; the loader prefers colleges.json.
    (out / "admissions.json").unlink(missing_ok=True)
    print(f"    {len(keep)} universities, {len(out_depts)} departments")

    us_colleges.check(unis)
    write(out, "colleges_us.json", {"universities": [
        {"id": uid, "name": name, "colorCode": color,
         **({"crest": crest} if crest else {})}
        for uid, (name, color, crest) in us_colleges.US_COLLEGES.items()
        if uid in keep
    ], "departments": [
        d for d in us_colleges.US_DEPARTMENTS if d["universityId"] in keep
    ]})


def build_quizzes(out: Path):
    """The question bank behind the {문제}/{정답}/{오답} choice macros."""
    problems = []
    for p in load(GLOBAL / "school_exam_problems.json")["problemList"]:
        answers = [i for i, o in enumerate(p["options"]) if o.get("isAnswer")]
        if len(answers) != 1:
            continue
        problems.append({
            "id": p["id"],
            "subject": p["subjectType"],
            "text": p["text"],
            "options": [o["text"] for o in p["options"]],
            "answer": answers[0],
        })
    write(out, "quizzes.json", {"problems": problems})
    print(f"    {len(problems)} quiz questions")


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
        # shown in the top bar. Both are account-level in the original.
        # `shared` spends the account wallet instead of a per-run counter;
        # `initial` is then a one-time grant to the account (TODO 84 M04).
        # Refresh is shared too (user, 2026-10-25): the account gets 50 once;
        # earning more is TODO 95.
        "refresh": {"initial": 50, "shared": True},
        "cookies": {"initial": 20, "shared": True},
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
        # Setup offers a protagonist gender only where a pack turns it on. With
        # it on, an NPC listed in genderPairs appears as the opposite gender of
        # the protagonist (forMale is the form a male player meets).
        "setup": {"genderSelection": False, "genderPairs": []},
        "exam": {
            # The CSAT on the last day, then applications and the endings.
            # Scoring is compiled in the original and NOT recovered. Fitted:
            # each subject's score is read off `curve` ([stat, score] points
            # joined by straight lines) and the CSAT is their average, so a
            # balanced student beats a lopsided one with the same total.
            # Calibrated to the user's targets against the cutoffs (25.3 ..
            # 73.24 for regular colleges, median 60), with admissionSpread 2:
            #   10k each: ~10% at the top cutoff, ~50% one tier down (~69);
            #   15k each: ~50% at the top; 15-17k gets into most places;
            #   25k each: ~99% at the top (Korea Dream / Harvard medicine).
            # Below 10k the curve bends down so a weak run lands low.
            "enabled": True,
            "curve": [[0, 20], [1000, 38], [3000, 50], [6000, 60],
                      [10000, 68.94], [15000, 73.24], [25000, 81.84],
                      [50000, 95]],
            # How many departments one CSAT can be sent to.
            "applications": 3,
            # Spread of the admission draw around a cutoff, in standard-score
            # points: a score exactly at the cutoff is a coin flip.
            "admissionSpread": 2,
        },
    }
    if STORY_ID == 20:
        # Retry Year scripts both protagonists; Jian Lee, Ji Suin and Inmul Ko
        # each have a girl and a boy actor.
        rules['setup'] = {'genderSelection': True, 'genderPairs': [
            {'forMale': 9, 'forFemale': 27},
            {'forMale': 3, 'forFemale': 32},
            {'forMale': 8, 'forFemale': 28},
        ]}
        # Keep the observed book baseline (power 5 -> +15 unbuffed). The prior
        # 9x tuning tripled ordinary study to fit exam thresholds; it was not
        # recovered and the user reported inflated beginner-book gains.
        # Exam progression balance remains open; do not alter book payouts to
        # conceal that gap. Recovered exam thresholds remain unchanged.
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
    # The to-do list: the story's fixed dates (exams) plus what events add
    # with ADD_TODO / ADD_TODO_2. It is also what the Calendar shows. Story 16
    # reads it too (FUNC_TODO_DAY(id) == 1, "due tomorrow", ten times).
    todos_file = CAMPAIGN / 'data/todos.json'
    todos = load(todos_file) if todos_file.exists() else {}
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
    print(" colleges")
    build_admissions(out)
    print(" quizzes")
    build_quizzes(out)
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
    import export_pack_mechanics
    export_pack_mechanics.export(out)
    presentation_assets.build(out, story_id=STORY_ID)
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
