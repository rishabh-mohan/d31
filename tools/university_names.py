"""Pack-owned real-name overlay for the imported Global/Taiwan universities.

IDs, crests, ranks, effects and admission rules remain the imported data.
See docs/UNIVERSITY-NAMES.md for sources and identity inferences.
"""
import json
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / 'content/kss/university-names.json'
DATA = json.loads(SOURCE.read_text(encoding='utf-8'))
assert DATA['version'] == 1, 'Unsupported university-name overlay version'
NAMES = DATA['names']


def check(universities):
    expected = {str(u['id']) for u in universities
                if u.get('type') in ('studyAbroad', 'studyTw')}
    assert expected == NAMES.keys(), 'Global/Taiwan name overlay must cover the imported IDs exactly'
    assert all(isinstance(n, str) and n.strip() for n in NAMES.values())
    assert len(set(NAMES.values())) == len(NAMES), 'Duplicate corrected university names'


def display_name(university):
    if university.get('type') in ('studyAbroad', 'studyTw'):
        return NAMES.get(str(university['id'])) or university.get('engName') or university.get('korName')
    return university.get('engName') or university.get('korName')
