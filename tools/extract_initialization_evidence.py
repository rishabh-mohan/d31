"""Preserve existing AOTopsy evidence under its actual regional version.

Reads original analysis/catalogs without modifying them. Does not manufacture
pseudocode for the Global build, whose native has no local AOTopsy export.
"""
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECTS = ROOT.parent
KOREAN = PROJECTS / 'korstu4CLAUDE/private-build/korean-base/analysis'
SOURCE = KOREAN / 'decompiled/app/app.dart'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    regions = {
        'korean': PROJECTS / 'korstu4CLAUDE/native/ko161/manifest.json',
        'global': PROJECTS / 'kss/manifest.json',
    }
    source = SOURCE.read_text(encoding='utf-8')
    # Top-level function boundaries, preserving the decompiler's exact text.
    functions = list(re.finditer(r'^dynamic ([^\n]+) \{', source, re.M))
    markers = ['"_firstTraitList"', '"_badgeIdList"',
        '"character_make_firstName"', '"character_make_lastName"',
        '"character_make_trait_"', '"character_make_badge_"',
        '"character_make_tamgoo1"']
    chosen = []
    for index, match in enumerate(functions):
        end = functions[index + 1].start() if index + 1 < len(functions) else len(source)
        block = source[match.start():end]
        if any(marker in block for marker in markers):
            chosen.append((match.group(1), source[:match.start()].count('\n') + 1, block))
    for region, manifest_path in regions.items():
        manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
        directory = ROOT / f'references/recovery/{region}-{manifest["version_name"]}'
        directory.mkdir(parents=True, exist_ok=True)
        provenance = {key: manifest[key] for key in ['package_name', 'version_name', 'version_code']}
        provenance['manifest_path'] = str(manifest_path.relative_to(PROJECTS))
        if region == 'korean':
            provenance.update(pseudocode_source=str(SOURCE.relative_to(PROJECTS)),
                pseudocode_sha256=digest(SOURCE), tool='Existing AOTopsy v1.6.0 export',
                functions=[{'name': name, 'source_line': line} for name, line, _ in chosen],
                caveat='Derived installed Korean native; unresolved dispatch and patched UI may remain.')
            text = '// Existing AOTopsy pseudocode; Korean version ' + manifest['version_name'] + '\n'
            text += '// Unresolved stub() calls are not evidence for missing rules or percentages.\n\n'
            text += '\n'.join(f'// Source line {line}: {name}\n{block}' for name, line, block in chosen)
            (directory / 'initialization-pseudocode.dart.txt').write_text(text, encoding='utf-8')
        else:
            native = PROJECTS / 'kss/arm64_dec/lib/arm64-v8a/libapp.so'
            catalogs = PROJECTS / 'kss/assetpack1_dec/assets/assets/global_data'
            provenance.update(native_path=str(native.relative_to(PROJECTS)), native_sha256=digest(native),
                pseudocode_available=False,
                caveat='No Global AOTopsy export was found; Korean pseudocode is not relabeled as Global.')
            snapshot = {}
            for filename, key in [('characters.json', 'characters'), ('traits.json', 'traitList'),
                    ('university_badges.json', 'badges')]:
                rows = json.loads((catalogs / filename).read_text(encoding='utf-8'))[key]
                fields = ['id', 'firstName', 'lastName', 'rank', 'isDefault', 'availableStoryIds',
                    'effectDescription', 'plusEffect', 'specialFuncCode'] if key == 'characters' else (
                    ['universityId', 'effect'] if key == 'badges' else
                    ['id', 'name', 'rank', 'isDefault', 'description', 'effectList'])
                snapshot[key] = [{field: row[field] for field in fields if field in row} for row in rows]
            (directory / 'initialization-catalogs.json').write_text(
                json.dumps(snapshot, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        (directory / 'provenance.json').write_text(
            json.dumps(provenance, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        print(f'{region} {manifest["version_name"]}: {directory.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
