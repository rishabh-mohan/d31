"""The US university set (TODO 41): colleges_us.json.

Every regular Korean university is renamed to a US one, keeping its id,
departments and cutoffs. The rows run from the most selective Korean
university down, so selectivity stays in order. Purdue is asked to be a
top-level college: it takes North Chungcheong University, a rank-eight
(top general tier) catalog whose aerospace, agriculture and robotics
departments fit it. The arts and sports schools (Korea Movie, Drama, Music,
...) get US schools known for the same thing.

Left alone, as the request asks:
  - Basakan and the other story-only "special" universities (Santa, the two
    Retry universities, Deserted Island);
  - the global study-abroad universities, which no US name may duplicate --
    hence no Stanford (Sfantord) and no Oakland University (Oakland).
"""
import csv
from pathlib import Path

# Edit tools/us_colleges.csv, then rebuild the packs (build_pack.py, both
# stories). One row per regular Korean university: korean_id is the key,
# korean_name and rank are there to read by, us_name and us_color (hex, no #)
# are what the US set shows, and us_crest is its emblem under assets/images/
# (tools/fetch_us_seals.py fills it with each school's seal; blank keeps the
# Korean crest). Rows run in the original's rank order.
CSV = Path(__file__).with_name("us_colleges.csv")


def _load():
    with CSV.open(encoding="utf-8", newline="") as f:
        return {
            int(row["korean_id"]): (row["us_name"].strip(),
                                    row["us_color"].strip().lstrip("#") or None,
                                    (row.get("us_crest") or "").strip() or None)
            for row in csv.DictReader(f)
            if row.get("korean_id", "").strip()
        }


# id: (name, colorCode, crest)
US_COLLEGES = _load()

# Words that would echo a global university's name.
GLOBAL_NAME_CLASHES = ("stanford", "oakland", "oxford", "melbourne", "toronto",
                       "tsinghua", "tokyo", "humboldt", "auckland", "nanyang",
                       "peking")


def check(universities):
    """Fails the build if the US set drifts from the catalog it renames.

    `universities` is the global universities.json list."""
    by_id = {u["id"]: u for u in universities}
    regular = {u["id"] for u in universities if u.get("type") is None}
    missing = regular - US_COLLEGES.keys()
    extra = US_COLLEGES.keys() - regular
    assert not missing, f"Korean universities without a US name: {sorted(missing)}"
    assert not extra, f"US names for non-regular universities: {sorted(extra)}"
    names = [n for n, _, _ in US_COLLEGES.values()]
    assert len(set(names)) == len(names), "duplicate US university names"
    globals_ = [by_id[i].get("engName", "") for i in by_id
                if by_id[i].get("type") == "studyAbroad"]
    for name in names:
        low = name.lower()
        assert not any(w in low for w in GLOBAL_NAME_CLASHES), name
        assert name not in globals_, name
