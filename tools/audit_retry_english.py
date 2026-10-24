"""Verify shipped English story-20 dialogue against the generated pack.

Reads old projects/APKs without modifying them. Generated game text and the
evidence report stay in gitignored build/. No translation service is used.
"""
import hashlib
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECTS = ROOT.parent
KOREAN = re.compile(r'[\uac00-\ud7a3]')
MACROS = re.compile(r'\{[^{}]*\}|<[^<>]*>')
FIELDS = ('text', 'elseText', 'optionText')


def display_fields(obj, path=''):
    if isinstance(obj, list):
        for i, value in enumerate(obj):
            yield from display_fields(value, f'{path}/{i}')
    elif isinstance(obj, dict):
        for field in FIELDS:
            if field not in obj:
                continue
            value = obj.get(field)
            translated = obj.get('translated' + field[0].upper() + field[1:])
            if translated is not None:
                value = translated
            if isinstance(value, str) and value.strip():
                yield f'{path}/{field}', value
        for key, value in obj.items():
            if isinstance(value, (dict, list)):
                yield from display_fields(value, f'{path}/{key}')


def coverage(label, payload):
    data = json.loads(payload)
    fields = list(display_fields(data))
    gaps = [(path, value) for path, value in fields
            if KOREAN.search(MACROS.sub('', value))]
    return {
        'source': label,
        'sha256': hashlib.sha256(payload).hexdigest(),
        'events': len(data.get('events', [])),
        'nodeRecords': len(data.get('nodes', [])),
        'nonemptyDisplayFields': len(fields),
        'koreanProseFields': len(gaps),
        'koreanMacroFields': sum(bool(KOREAN.search(value)) for _, value in fields)
                             - len(gaps),
        'gaps': gaps,
    }


def main():
    reports = []
    relative = 'assets/assets/stories/20/event/events.json'
    candidates = [
        PROJECTS / 'kss/assetpack1_dec' / relative,
        PROJECTS / 'korstu4/mod-decoded' / relative,
        ROOT / 'packs/kss20/events/events.json',
    ]
    for file in candidates:
        if file.is_file():
            reports.append(coverage(str(file.relative_to(PROJECTS)), file.read_bytes()))
    archive = PROJECTS / 'kor2/Korean Student Simulator apks/asset_pack_1_en.apk'
    if archive.is_file():
        with zipfile.ZipFile(archive) as source:
            reports.append(coverage(str(archive.relative_to(PROJECTS)) + '!' + relative,
                                    source.read(relative)))
    target = ROOT / 'build/retry-english-audit.json'
    target.parent.mkdir(exist_ok=True)
    target.write_text(json.dumps(reports, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for report in reports:
        print(f"{report['source']}: {report['nonemptyDisplayFields']} display fields; "
              f"{report['koreanProseFields']} Korean prose fields")
    if not reports or any(r['koreanProseFields'] for r in reports):
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
