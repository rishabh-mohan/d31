"""Fetches each US university's seal for the US set's crests.

For every row of tools/us_colleges.csv, reads the school's English Wikipedia
infobox, takes its `image` (the seal, for most universities; `seal`, then
`logo`, when it has none), and saves Wikipedia's PNG rendering as
assets/images/colleges/us/<korean_id>.png. The row's `us_crest` column is
filled with that path, which the pack builder writes into colleges_us.json.

The images are trademarks of their universities and stay local: assets/images
is gitignored, like the rest of the art. Replace any file by hand (keep the
name) to use a different emblem; existing files are kept unless --force.

  python tools/fetch_us_seals.py [--force]
"""
from __future__ import annotations

import csv
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

D30 = Path(__file__).resolve().parent.parent
CSV = D30 / "tools/us_colleges.csv"
OUT = D30 / "assets/images/colleges/us"
API = "https://en.wikipedia.org/w/api.php"
UA = "d30mode-dev/0.1 (personal project; seal fetcher)"

# Article titles that differ from the CSV's display name.
TITLES = {
    "University of Wisconsin-Madison": "University of Wisconsin–Madison",
    "University of Nebraska-Lincoln": "University of Nebraska–Lincoln",
    "University of Illinois Urbana-Champaign": "University of Illinois Urbana-Champaign",
    "Juilliard School": "Juilliard School",
}


def fetch(url: str) -> bytes:
    """GET with backoff: Wikimedia answers bursts with 429."""
    for attempt in range(6):
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code != 429 or attempt == 5:
                raise
            wait = int(e.headers.get("Retry-After") or 0) or 5 * (attempt + 1)
            time.sleep(min(wait, 60))
    raise RuntimeError("unreachable")


def get(params: dict) -> dict:
    url = API + "?" + urllib.parse.urlencode({**params, "format": "json"})
    return json.loads(fetch(url))


def infobox_file(title: str) -> str | None:
    data = get({"action": "parse", "page": title, "prop": "wikitext",
                "section": 0, "redirects": 1})
    text = data.get("parse", {}).get("wikitext", {}).get("*", "")
    for key in ("image", "seal", "logo", "image_name"):
        m = re.search(rf"^\s*\|\s*{key}\s*=\s*(.+?)\s*$", text, re.M)
        if not m:
            continue
        value = m.group(1)
        value = re.sub(r"<!--.*?-->", "", value).strip()
        value = re.sub(r"^\[\[(?:File|Image):", "", value)
        value = value.split("|")[0].strip(" ]")
        if re.search(r"\.(svg|png|jpg|jpeg|gif)$", value, re.I):
            return value
    return None


def thumb_url(filename: str, width: int = 400) -> str | None:
    data = get({"action": "query", "titles": f"File:{filename}",
                "prop": "imageinfo", "iiprop": "url", "iiurlwidth": width})
    for page in data.get("query", {}).get("pages", {}).values():
        info = (page.get("imageinfo") or [{}])[0]
        return info.get("thumburl") or info.get("url")
    return None


def main() -> int:
    force = "--force" in sys.argv
    with CSV.open(encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    OUT.mkdir(parents=True, exist_ok=True)
    missing = []
    for row in rows:
        uid = row["korean_id"].strip()
        target = OUT / f"{uid}.png"
        rel = f"colleges/us/{uid}.png"
        if target.exists() and not force:
            row["us_crest"] = rel
            continue
        name = row["us_name"].strip()
        try:
            filename = infobox_file(TITLES.get(name, name))
            url = thumb_url(filename) if filename else None
            if not url:
                raise LookupError("no infobox image")
            target.write_bytes(fetch(url))
            row["us_crest"] = rel
            print(f"{uid:>4} {name}: {filename}")
        except Exception as e:  # noqa: BLE001 - report and carry on
            missing.append(name)
            row.setdefault("us_crest", "")
            print(f"{uid:>4} {name}: FAILED ({e})")
        time.sleep(2)
    fields = ["korean_id", "korean_name", "rank", "us_name", "us_color",
              "us_crest"]
    with CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for row in rows:
            w.writerow({k: row.get(k, "") for k in fields})
    if missing:
        print("No seal found for: " + ", ".join(missing))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
