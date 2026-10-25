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

# id: (name, colorCode), in the original's rank order (ten .. one).
US_COLLEGES = {
    # ten
    2: ("Harvard University", "A51C30"),
    # nine: the arts, culture, sports, music and food schools
    1: ("University of Southern California", "990000"),
    4: ("New York University", "57068C"),
    5: ("University of California, Los Angeles", "2774AE"),
    7: ("Ohio State University", "BB0000"),
    8: ("Juilliard School", "1F2A44"),
    9: ("Cornell University", "B31B1B"),
    # eight
    3: ("Yale University", "00356B"),
    6: ("Massachusetts Institute of Technology", "A31F34"),
    11: ("Princeton University", "E77500"),
    101: ("Purdue University", "CEB888"),
    # seven
    10: ("University of Chicago", "800000"),
    12: ("Columbia University", "1D4F91"),
    13: ("University of Pennsylvania", "011F5B"),
    14: ("Duke University", "012169"),
    15: ("Northwestern University", "4E2A84"),
    102: ("California Institute of Technology", "FF6C0C"),
    # six
    17: ("University of California, Berkeley", "003262"),
    18: ("University of Michigan", "00274C"),
    25: ("Carnegie Mellon University", "C41230"),
    103: ("Georgia Institute of Technology", "B3A369"),
    104: ("University of Illinois Urbana-Champaign", "E84A27"),
    105: ("University of Texas at Austin", "BF5700"),
    # five
    16: ("University of Wisconsin-Madison", "C5050C"),
    20: ("University of Washington", "4B2E83"),
    22: ("University of Virginia", "232D4B"),
    26: ("University of North Carolina at Chapel Hill", "4B9CD3"),
    28: ("University of Florida", "0021A5"),
    106: ("Rice University", "00205B"),
    109: ("Vanderbilt University", "866D4B"),
    113: ("University of Maryland", "E03A3E"),
    114: ("Indiana University Bloomington", "990000"),
    # four
    19: ("Pennsylvania State University", "041E42"),
    21: ("University of Minnesota", "7A0019"),
    107: ("Rutgers University", "CC0033"),
    # three
    27: ("Texas A&M University", "500000"),
    108: ("Virginia Tech", "630031"),
    115: ("Iowa State University", "C8102E"),
    117: ("Michigan State University", "18453B"),
    # two
    29: ("University of Arizona", "AB0520"),
    110: ("University of Colorado Boulder", "CFB87C"),
    # one
    23: ("Arizona State University", "8C1D40"),
    24: ("University of Iowa", "FFCD00"),
    30: ("University of Kansas", "0051BA"),
    31: ("University of Oregon", "154733"),
    32: ("University of Utah", "CC0000"),
    33: ("Kansas State University", "512888"),
    111: ("University of Kentucky", "0033A0"),
    112: ("Oklahoma State University", "FF7300"),
    116: ("University of Nebraska-Lincoln", "E41C38"),
    118: ("Ball State University", "BA0C2F"),
}

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
    names = [n for n, _ in US_COLLEGES.values()]
    assert len(set(names)) == len(names), "duplicate US university names"
    globals_ = [by_id[i].get("engName", "") for i in by_id
                if by_id[i].get("type") == "studyAbroad"]
    for name in names:
        low = name.lower()
        assert not any(w in low for w in GLOBAL_NAME_CLASHES), name
        assert name not in globals_, name
