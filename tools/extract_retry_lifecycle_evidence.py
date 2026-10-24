"""Copy Retry Year recovery evidence to an ignored, local-only reference file."""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECTS = ROOT.parent
SOURCE = PROJECTS / 'kss/assetpack1_dec/assets/assets/stories/20/event/events.json'
NATIVE = PROJECTS / 'korstu4CLAUDE/private-build/korean-base/analysis/decompiled/app/app.dart'


def main():
    data = json.loads(SOURCE.read_text(encoding='utf-8'))
    native = NATIVE.read_text(encoding='utf-8')
    chunks = ['# Retry Year lifecycle evidence (local only)',
              f'Event source: {SOURCE}\nSHA256: {hashlib.sha256(SOURCE.read_bytes()).hexdigest()}',
              f'Korean native pseudocode: {NATIVE}\nSHA256: {hashlib.sha256(NATIVE.read_bytes()).hexdigest()}']
    for name in ['sub_be91d0', 'sub_be99c0']:
        match = re.search(r'^dynamic ' + name + r'\(\)', native, re.M)
        if not match:
            raise RuntimeError(f'Missing native function {name}')
        end = re.search(r'^dynamic ', native[match.end():], re.M)
        stop = match.end() + end.start() if end else len(native)
        line = native[:match.start()].count('\n') + 1
        chunks.append(f'## {name} (line {line})\n```dart\n{native[match.start():stop]}\n```')
    ids = [1, 169, 2, 3, 4, 5, 12, 211, 6, 7]
    selected = {
        'events': [e for e in data['events'] if e['id'] in ids],
        'nodes': [n for n in data['nodes'] if n['id'] // 1000 in ids],
    }
    chunks.append('## Original opening, release and reset graphs\n```json\n' +
                  json.dumps(selected, ensure_ascii=False, indent=1) + '\n```')
    target = ROOT / 'references/recovery/RETRY-YEAR-LIFECYCLE.md'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text('\n\n'.join(chunks) + '\n', encoding='utf-8')
    print(f'Wrote local evidence: {target}')


if __name__ == '__main__':
    main()
