#!/usr/bin/env python3
"""Turn Korean Student Simulator's human-readable item `effectText` into data.

Why this exists: KSS keeps item effects in compiled Dart, keyed by item id.
They are in no JSON file, so a rebuild that wants editable items has to
recover them. The one machine-readable description of each item that *does*
ship is its `effectText` -- the line shown to the player -- and it turns out to
be written in a small, consistent sublanguage ("All study stats +200",
"Exercise Efficiency +10% at [Workout Areas]"). This module parses it.

Everything it cannot read is returned as `unparsed` rather than guessed at, so
the gap is visible in the pack and can be filled in by hand.

Emitted effect shapes are documented in docs/PACK-FORMAT.md.
"""

from __future__ import annotations

import re

# CONSUME_STAT_<n> / NORMAL_STAT_<n> are the original engine's scaling tokens:
# the number is the base, the engine multiplies it. We keep the base and let
# rules.json carry the multiplier.
STAT_TOKEN = r"(?:CONSUME_STAT_|NORMAL_STAT_)?"
NUM = r"([\d,]+(?:\.\d+)?)"

SUBJECTS = {
    "korean": "korean",
    "english": "english",
    "math": "math",
    "maths": "math",
    "science": "science",
    "humanities": "society",
    "society": "society",
    "all subjects": "all",
    "all subject": "all",
    "all study": "all",
    "all stats": "all",
    "all": "all",
    "random subject": "random",
    "a random subject": "random",
    "random": "random",
    "desired": "chosen",
    "selected": "chosen",
    "first elective": "elective1",
    "elective 1": "elective1",
    "first inquiry": "elective1",
    "second elective": "elective2",
    "elective 2": "elective2",
    "inquiry 2": "elective2",
    "elective": "elective",
    "lessons": "lesson",
}

# Location scopes written as {TOKEN} or [Phrase] or "at the museum".
SCOPES = {
    "home": {"locationId": 2000},
    "school": {"locationId": 1000},
    "the museum": {"locationId": 16000},
    "museum": {"locationId": 16000},
    "gold mine": {"locationId": 16001},
    "cafe": {"locationId": 16004},
    "workout areas": {"locationType": "exercise"},
    "study locations": {"locationType": "study"},
    "part-time locations": {"locationType": "partTimeJob"},
}

# Lines that describe no mechanical effect at all. Matched as whole strings
# (case-insensitive) or by a distinctive fragment.
FLAVOUR_FRAGMENTS = (
    "worship it",
    "pretty bottle",
    "upgrade material given by",
    "what is this",
    "rough around the edges",
    "holding onto this when she was feeling nervous",
    "magic show",
    "purchased cheaply from peddlers",
    "see the opponent's weaknesses",
    "required for museum admission",
    "temporary",
)


def _n(s: str) -> float:
    v = float(s.replace(",", ""))
    return int(v) if v.is_integer() else v


def _subject(word: str) -> str | None:
    w = word.strip().lower().rstrip("s") if word else ""
    return SUBJECTS.get(word.strip().lower()) or SUBJECTS.get(w)


def _scope(text: str) -> dict | None:
    """Find a trailing location scope: `at {HOME}`, `at [Study Locations]`,
    `at the museum`."""
    m = re.search(r"\bat\s+[\{\[]?\s*([A-Za-z \-']+?)\s*[\}\]]?\s*$", text, re.I)
    if not m:
        return None
    return SCOPES.get(m.group(1).strip().lower())


def _duration(text: str) -> str | None:
    t = text.lower()
    if "for a week" in t or "for one week" in t:
        return "week"
    if "for the day" in t or "for one day" in t or "for a day" in t:
        return "day"
    return None


def _conditions(text: str) -> list:
    """`[If Exercise Level >= 8]` -> engine condition list."""
    out = []
    for m in re.finditer(
        r"\[\s*if\s+([A-Za-z \-]+?)\s*(?:≥|>=|at least)\s*(\d+)\s*\]", text, re.I
    ):
        target = m.group(1).strip().upper().replace(" ", "_").replace("-", "_")
        out.append(
            {"target": target, "compareType": "greaterEqual", "intValue": int(m.group(2))}
        )
    return out


# --------------------------------------------------------------------------
# Rules, tried in order. Each returns a list of effects (possibly empty) or
# None to fall through to the next rule. All of them run; a text may yield
# several effects ("All study stats +200, Stamina consumption -3 for the day").
# --------------------------------------------------------------------------


def _rule_study_efficiency(t: str, ctx: dict) -> list:
    out = []
    pat = (
        r"(?:study|sleep|exercise|part-?time)\s+(?:efficiency|earnings)"
    )
    for m in re.finditer(
        r"(?:study\s+efficiency(?:\s+for\s+([A-Za-z 0-9\-]+?))?|"
        r"([A-Za-z 0-9\-]+?)\s+study\s+efficiency)"
        rf"\s*([+-])\s*{STAT_TOKEN}{NUM}",
        t,
        re.I,
    ):
        subj = _subject(m.group(1) or m.group(2) or "all") or "all"
        sign = -1 if m.group(3) == "-" else 1
        out.append(
            {
                "type": "studyEfficiency",
                "subject": subj,
                "value": sign * _n(m.group(4)),
            }
        )
    return out


def _rule_exercise_efficiency(t: str, ctx: dict) -> list:
    out = []
    for m in re.finditer(
        rf"exercise\s+efficiency\s*([+-])?\s*{STAT_TOKEN}{NUM}\s*(%?)", t, re.I
    ):
        sign = -1 if m.group(1) == "-" else 1
        key = "percent" if m.group(3) == "%" else "value"
        out.append({"type": "exerciseEfficiency", key: sign * _n(m.group(2))})
    return out


def _rule_parttime_earnings(t: str, ctx: dict) -> list:
    out = []
    for m in re.finditer(
        rf"part-?time\s+(?:job\s+)?(?:earnings|efficiency)\s*([+-])?\s*{NUM}\s*(%?)",
        t,
        re.I,
    ):
        sign = -1 if m.group(1) == "-" else 1
        key = "percent" if m.group(3) == "%" else "value"
        out.append({"type": "partTimeEarnings", key: sign * _n(m.group(2))})
    return out


def _rule_sleep_efficiency(t: str, ctx: dict) -> list:
    out = []
    for m in re.finditer(rf"sleep\s+efficiency\s*([+-])?\s*{NUM}", t, re.I):
        sign = -1 if m.group(1) == "-" else 1
        out.append({"type": "sleepEfficiency", "value": sign * _n(m.group(2))})
    return out


def _rule_stat_range(t: str, ctx: dict) -> list:
    """`+200~600 to desired study stat`, `(CONSUME_STAT_20 - CONSUME_STAT_200)
    for a random subject`, `Selected study stat +200~600`."""
    out = []
    for m in re.finditer(
        rf"{STAT_TOKEN}{NUM}\s*(?:~|-|to)\s*{STAT_TOKEN}{NUM}", t, re.I
    ):
        lo, hi = _n(m.group(1)), _n(m.group(2))
        if hi <= lo:
            continue
        before = t[: m.start()]
        after = t[m.end() :]
        # A money range ("5000-50000 Gold") is not a stat range; _rule_money
        # owns it. Without this the two rules both fire on the same text.
        if re.match(r"\s*(?:gold|won|money)\b", after, re.I):
            continue
        if not re.search(r"\bstats?\b", before + " " + after, re.I):
            continue
        subj = None
        for chunk in (after, before):
            sm = re.search(
                r"(desired|selected|random subject|a random subject|random|all subjects?"
                r"|all study|korean|english|maths?|science|humanities)",
                chunk,
                re.I,
            )
            if sm:
                subj = _subject(sm.group(1))
                break
        if subj:
            out.append({"type": "stat", "subject": subj, "range": [lo, hi]})
    return out


def _rule_stat(t: str, ctx: dict) -> list:
    """The workhorse: `All study stats +200`, `Korean Stat +1500`,
    `Science, Humanities stats +CONSUME_STAT_75 each`,
    `Stats +CONSUME_STAT_30 for a random subject`."""
    out = []
    pat = (
        r"((?:(?:all\s+)?(?:subject|study|inquiry|elective)\s*)*"
        r"(?:korean|english|maths?|science|humanities|society|all\s+subjects?|"
        r"all\s+stats?|all|elective\s*[12]?|first\s+elective|second\s+elective|"
        r"first\s+inquiry|inquiry\s*2|random\s+subject|random|desired|selected)"
        r"(?:\s*(?:,|\band\b)\s*(?:korean|english|maths?|science|humanities|society))*)"
        rf"\s*(?:subject\s*)?(?:study\s*)?stats?\s*([+-])\s*{STAT_TOKEN}{NUM}"
    )
    # Luna's Hat ("When sleeping, random subject study stat +30") is only the
    # onSleep trigger below; reading its tail here too granted it at once.
    plain = re.sub(r"when\s+sleeping,?\s+", "\0", t, flags=re.I)
    for m in re.finditer(pat, plain, re.I):
        if plain[: m.start()].endswith("\0"):
            continue
        phrase, sign, num = m.group(1), m.group(2), m.group(3)
        value = _n(num) * (-1 if sign == "-" else 1)
        # A comma or "and" list ("Science, Humanities stats +75 each",
        # "Science and Humanities Stats +150") is several effects.
        parts = [p.strip() for p in re.split(r",|\band\b", phrase, flags=re.I) if p.strip()]
        subs = []
        for p in parts:
            s = _subject(re.sub(r"\b(subject|study|stats?)\b", "", p, flags=re.I).strip())
            if s:
                subs.append(s)
        if not subs:
            s = _subject(phrase)
            subs = [s] if s else []
        for s in subs:
            out.append({"type": "stat", "subject": s, "value": value})

    # "Stats +CONSUME_STAT_30 for a random subject" -- subject comes after.
    for m in re.finditer(
        rf"\bstats?\s*([+-])\s*{STAT_TOKEN}{NUM}\s+for\s+(?:an?\s+)?(random\s+subject|random)",
        t,
        re.I,
    ):
        value = _n(m.group(2)) * (-1 if m.group(1) == "-" else 1)
        out.append({"type": "stat", "subject": "random", "value": value})

    # "Gain +400 to desired study stat"
    for m in re.finditer(
        rf"gain(?:ed)?\s*\+?{NUM}\s+to\s+(desired|selected)\s+study\s+stat", t, re.I
    ):
        out.append({"type": "stat", "subject": "chosen", "value": _n(m.group(1))})

    # "Elective stats each +1000"
    for m in re.finditer(rf"elective\s+stats?\s+each\s*\+{NUM}", t, re.I):
        v = _n(m.group(1))
        out.append({"type": "stat", "subject": "elective1", "value": v})
        out.append({"type": "stat", "subject": "elective2", "value": v})

    # Bare subject with no "stat" noun at all: "Korean +300", "Math +CONSUME_STAT_150".
    if not out:
        for m in re.finditer(
            rf"^\s*(korean|english|maths?|science|humanities|society)\s*([+-])\s*"
            rf"{STAT_TOKEN}{NUM}\s*$",
            t,
            re.I,
        ):
            out.append(
                {
                    "type": "stat",
                    "subject": _subject(m.group(1)),
                    "value": _n(m.group(3)) * (-1 if m.group(2) == "-" else 1),
                }
            )

    # "When sleeping, random subject study stat +30"
    for m in re.finditer(
        rf"when\s+sleeping,?\s+random\s+subject\s+study\s+stat\s*\+{NUM}", t, re.I
    ):
        out.append(
            {
                "type": "stat",
                "subject": "random",
                "value": _n(m.group(1)),
                "trigger": "onSleep",
            }
        )
    return out


def _rule_hp(t: str, ctx: dict) -> list:
    out = []
    for m in re.finditer(rf"\bstamina\s*([+-])\s*{NUM}", t, re.I):
        out.append(
            {"type": "hp", "value": _n(m.group(2)) * (-1 if m.group(1) == "-" else 1)}
        )
    for m in re.finditer(rf"stamina\s+(?:cost|consumption)\s*([+-])\s*{NUM}", t, re.I):
        out.append(
            {
                "type": "hpCost",
                "value": _n(m.group(2)) * (-1 if m.group(1) == "-" else 1),
            }
        )
    if re.search(r"current\s+stamina\s*x\s*2", t, re.I):
        out.append({"type": "hpMultiply", "factor": 2})
    m = re.search(
        rf"set\s+current\s+stamina\s+to\s+a\s+random\s+value\s+between\s+{NUM}\s+and\s+{NUM}",
        t,
        re.I,
    )
    if m:
        out.append({"type": "hpSet", "range": [_n(m.group(1)), _n(m.group(2))]})
    if re.search(r"maintain\s+stamina\s+at\s+1\s+instead\s+of\s+exhaustion", t, re.I):
        out.append({"type": "surviveExhaustion", "chance": 0.5})
    # Drop a bare `hp` that a `hpCost` match already consumed.
    kinds = {e["type"] for e in out}
    if "hpCost" in kinds:
        out = [e for e in out if e["type"] != "hp"]
    return out


def _rule_money(t: str, ctx: dict) -> list:
    out = []
    m = re.search(rf"\(?\s*{NUM}\s*[-~]\s*{NUM}\s*(?:gold|won)\s*\)?", t, re.I)
    if m:
        return [{"type": "money", "range": [_n(m.group(1)), _n(m.group(2))]}]
    for m in re.finditer(rf"([+-]?)\s*{NUM}\s*(?:gold|won|money)\b", t, re.I):
        v = _n(m.group(2))
        out.append({"type": "money", "value": -v if m.group(1) == "-" else v})
    for m in re.finditer(rf"gained?\s*\+{NUM}\s+money", t, re.I):
        out.append({"type": "money", "value": _n(m.group(1))})
    # De-duplicate: the two patterns above can both match "Gained +1500 money".
    seen, uniq = set(), []
    for e in out:
        k = json_key(e)
        if k not in seen:
            seen.add(k)
            uniq.append(e)
    return uniq


def _rule_exp(t: str, ctx: dict) -> list:
    out = []
    for m in re.finditer(rf"exercise\s+exp\s*([+-])?\s*{NUM}", t, re.I):
        out.append(
            {
                "type": "exerciseExp",
                "value": _n(m.group(2)) * (-1 if m.group(1) == "-" else 1),
            }
        )
    for m in re.finditer(rf"part-?time\s+exp\s*([+-])?\s*{NUM}", t, re.I):
        out.append(
            {
                "type": "partTimeExp",
                "value": _n(m.group(2)) * (-1 if m.group(1) == "-" else 1),
            }
        )
    # "Read Count for Humanities +2, Science +2": every `<subject> +n` pair in
    # the list after the phrase, not just the first (Academic Potion, A05).
    for m in re.finditer(
        rf"read\s+count\s+for\s+((?:[A-Za-z]+\s*\+{NUM}\s*(?:,|and)?\s*)+)",
        t,
        re.I,
    ):
        for pair in re.finditer(rf"([A-Za-z]+)\s*\+{NUM}", m.group(1)):
            out.append(
                {
                    "type": "readCount",
                    "subject": _subject(pair.group(1)) or "all",
                    "value": _n(pair.group(2)),
                }
            )
    return out


def _rule_meta(t: str, ctx: dict) -> list:
    out = []
    for m in re.finditer(
        rf"weekly\s+goals\s+rewards?\s*\+{NUM}\s*%", t, re.I
    ):
        out.append({"type": "goalReward", "percent": _n(m.group(1))})
    for m in re.finditer(
        rf"universit(?:y|ies)[’']?s?\s+acceptance\s+rate\s*\+{NUM}\s*%", t, re.I
    ):
        out.append({"type": "acceptanceRate", "percent": _n(m.group(1))})
    m = re.search(r"cures\s+([A-Za-z ]+)", t, re.I)
    if m:
        out.append({"type": "cureTrait", "trait": m.group(1).strip()})
    if re.search(r"remove\s+all\s+negative\s+traits", t, re.I):
        out.append({"type": "removeTraits", "traitType": "bad"})
    m = re.search(rf"get\s+{NUM}\s+(coffees?)\b", t, re.I)
    if m:
        out.append({"type": "acquireItem", "itemId": 1, "count": int(_n(m.group(1)))})
    if re.search(r"obtain\s+a\s+random\s+item", t, re.I):
        out.append({"type": "acquireItemRandom", "count": 1})
    m = re.search(r"random\s+chance\s+to\s+obtain\s+an?\s+([A-Za-z ]+)", t, re.I)
    if m:
        out.append(
            {"type": "acquireItemRandom", "count": 1, "named": m.group(1).strip()}
        )
    m = re.search(r"restore\s+(library|cafe|home|school|park)\s+location", t, re.I)
    if m:
        ids = {
            "library": 16003,
            "cafe": 16004,
            "home": 2000,
            "school": 1000,
            "park": 16002,
        }
        out.append({"type": "unlockLocation", "locationId": ids[m.group(1).lower()]})
    # Retry Year's promotion exam is passed on a proficiency the notes and
    # guides raise (the native itemEffectTeacherPaper and its siblings add
    # exactly these amounts to EXAM_POINT), and the kit reads back.
    m = re.search(rf"promotion\s+exam\s+proficiency\s*\+{NUM}\s*%", t, re.I)
    if m:
        out.append({"type": "switchAdd", "switch": "EXAM_POINT",
                    "value": int(_n(m.group(1)))})
    if re.search(r"check\s+current\s+promotion\s+exam\s+proficiency", t, re.I):
        out.append({"type": "report", "switch": "EXAM_POINT",
                    "label": "Promotion Exam Proficiency", "suffix": "%",
                    "keepItem": True})
    if re.search(r"check\s+predicted\s+grades", t, re.I):
        out.append({"type": "ui", "action": "predictedGrades"})
    if re.search(r"check\s+abilities", t, re.I):
        out.append({"type": "ui", "action": "checkAbilities"})
    if re.search(r"all\s+stats?\s+increase\b", t, re.I):
        out.append({"type": "stat", "subject": "all", "value": 1, "note": "unspecified amount in source text"})
    # "Prevent X", "X defense" -- these gate a bad event; the engine does it
    # with an event switch, so emit the switch guard shape.
    m = re.search(r"(?:prevent|defen[cs]e(?:\s+against)?)\s+([A-Za-z \-']+)", t, re.I)
    if not m:
        m = re.search(r"([A-Za-z \-']+?)\s+defen[cs]e\s*$", t, re.I)
    if m:
        out.append({"type": "preventEvent", "label": m.group(1).strip()})
    return out


# --------------------------------------------------------------------------
# Hand-authored effects, per story, for items whose effectText cannot say
# what the item does. Each entry REPLACES the parsed effects; `note` is
# copied to the pack as `effectNote` so the evidence travels with the data.
# Evidence and provisional values are listed in docs/EFFECTS-REFERENCE.md
# ("Item effects, 2026-10-25"). Everything here is plain pack data: the
# engine has no branch on these item IDs.
# --------------------------------------------------------------------------

# Read-only "is the next sing-off's opponent already drawn?" The target is
# drawn by SET_SING_TARGET when SING_SW becomes 1 (events 31, 221) and read by
# FUNC_SING_TARGET at the results (220) and the champion match (227, which
# keeps the last target once SING_POINT >= 15). Character 67 always wins.
_SING_DRAWN = {"any": [
    {"eq": [{"field": "characterId"}, 67]},
    {"eq": [{"switch": "SING_SW"}, 1]},
    {"eq": [{"switch": "SING_SW"}, 2]},
    {"all": [{"eq": [{"switch": "SING_SW"}, 3]},
             {"gte": [{"switch": "SING_POINT"}, 15]}]},
]}

OVERLAYS: dict[int, dict[int, dict]] = {
    16: {
        # Bizarre Author's Note. The native itemEffectWebtoonGuideBook reads
        # DRAW_* against TARGET_DRAW_* and gives the note back (addItem
        # 20018), so it is kept. This engine's drawing model does not keep
        # DRAW_* yet, so the view shows the student's abilities (study stats
        # and levels) and adds the comic progress rows once a target is set.
        20018: {
            "effects": [{
                "type": "ui", "action": "checkAbilities", "keepItem": True,
                "progress": [
                    {"label": "Drawings", "value": "DRAW_COUNT",
                     "target": "TARGET_DRAW_COUNT"},
                    {"label": "Korean", "value": "DRAW_KOREAN",
                     "target": "TARGET_DRAW_KOREAN"},
                    {"label": "Maths", "value": "DRAW_MATH",
                     "target": "TARGET_DRAW_MATH"},
                    {"label": "English", "value": "DRAW_ENGLISH",
                     "target": "TARGET_DRAW_ENGLISH"},
                    {"label": "Inquiry", "value": "DRAW_TAMGOO",
                     "target": "TARGET_DRAW_TAMGOO"},
                ],
            }],
            "note": "Kept on use: native itemEffectWebtoonGuideBook re-adds "
                    "20018. View layout is this project's design.",
        },
    },
    20: {
        # Recipe. Native itemEffectRecipe gives the recipe back (addItem
        # 80011), so it is a kept reference. The three potions and their
        # ingredients are the Foodcraft graph's own (event 120, nodes
        # 120005/120019/120033), each for the chef's 1000 Gold fee.
        80011: {
            "effects": [{
                "type": "ui", "action": "recipes", "keepItem": True,
                "fee": 1000,
                "where": "Bring the ingredients to the Mountain Chef "
                         "(Foodcraft).",
                "recipes": [
                    {"output": 80012, "inputs": [80003, 80004, 80007]},
                    {"output": 80013, "inputs": [80005, 80006, 80007]},
                    {"output": 80014, "inputs": [80003, 80004, 80005]},
                ],
            }],
            "note": "Kept on use: native itemEffectRecipe re-adds 80011. "
                    "Recipes from Foodcraft (event 120). View layout is "
                    "this project's design.",
        },
        # Strawberry Milk. The native itemEffectStrawberryMilk applies the
        # constant 50 the way Chocolate Milk (Stamina +50) does; the effect
        # text hides it ("???"). Event 210 branches on still holding it.
        80041: {
            "effects": [{"type": "hp", "value": 50, "provisional": True}],
            "note": "PROVISIONAL Stamina +50: native handler constant 50, "
                    "sign/target not fully decoded.",
        },
        # Bug Spray and Sturdy Ladder are read by their event graphs
        # (39/129-132 and 109-113 branch on FUNC_ITEM_COUNT), like the
        # other prevention items.
        90002: {
            "effects": [{"type": "preventEvent", "label": "cockroach"}],
            "note": "Held: the cockroach events branch on it.",
        },
        90005: {
            "effects": [{"type": "preventEvent",
                         "label": "falling from the bunk bed"}],
            "note": "Held: the bunk-bed events branch on it.",
        },
        # Scouter: a kept checking tool. Same rule as the sing-off and the
        # IS_SING_WIN choice label (FUNC_SING_TARGET); only reads state.
        90021: {
            "effects": [{
                "type": "report", "keepItem": True,
                "text": {"if": [
                    {"eq": [{"switch": "SING_WIN"}, 1]},
                    "Scouter: there is no sing-off left to forecast.",
                    {"if": [
                        _SING_DRAWN,
                        {"if": [
                            {"predicate": "FUNC_SING_TARGET"},
                            "Scouter: with your practice so far, you will "
                            "win the next sing-off.",
                            "Scouter: with your practice so far, you will "
                            "lose the next sing-off.",
                        ]},
                        "Scouter: no sing-off opponent has been decided "
                        "yet.",
                    ]},
                ]},
            }],
            "note": "Kept checking tool; reads FUNC_SING_TARGET, draws "
                    "nothing.",
        },
    },
}


def overlay(story: int, item_id: int) -> dict | None:
    """The hand-authored effects for this story's item, or None."""
    return OVERLAYS.get(story, {}).get(item_id)


RULES = (
    _rule_study_efficiency,
    _rule_exercise_efficiency,
    _rule_parttime_earnings,
    _rule_sleep_efficiency,
    _rule_stat_range,
    _rule_stat,
    _rule_hp,
    _rule_money,
    _rule_exp,
    _rule_meta,
)


def json_key(e: dict) -> str:
    return "|".join(f"{k}={e[k]}" for k in sorted(e))


def parse(effect_text: str | None) -> tuple[list, str | None, bool]:
    """-> (effects, unparsed_text_or_None, is_flavour)"""
    if not effect_text or not effect_text.strip():
        return [], None, False
    text = " ".join(effect_text.split())
    low = text.lower()

    if any(f in low for f in FLAVOUR_FRAGMENTS):
        return [], None, True

    effects: list[dict] = []
    ctx: dict = {}
    for rule in RULES:
        try:
            effects.extend(rule(text, ctx) or [])
        except Exception as exc:  # a bad regex must not kill the build
            print(f"    rule {rule.__name__} failed on {text!r}: {exc}")

    # A range result supersedes the plain-value result for the same subject.
    ranged = {e.get("subject") for e in effects if "range" in e and e["type"] == "stat"}
    if ranged:
        effects = [
            e
            for e in effects
            if not (e["type"] == "stat" and "value" in e and e.get("subject") in ranged)
        ]

    seen, uniq = set(), []
    for e in effects:
        k = json_key(e)
        if k not in seen:
            seen.add(k)
            uniq.append(e)
    effects = uniq

    if not effects:
        return [], text, False

    scope = _scope(text)
    duration = _duration(text)
    conditions = _conditions(text)
    for e in effects:
        if scope and e["type"] in (
            "studyEfficiency",
            "exerciseEfficiency",
            "partTimeEarnings",
            "sleepEfficiency",
        ):
            e["scope"] = scope
        if duration:
            e["duration"] = duration
        if conditions:
            e["conditions"] = conditions
    return effects, None, False
