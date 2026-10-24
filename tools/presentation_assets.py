"""Local-only presentation catalog and assets from the read-only English trees."""
import json
import shutil
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT.parent / 'kss/assetpack1_dec/assets/assets'
BASE = ROOT.parent / 'kss/kss_dec/assets/flutter_assets/assets'
CACHE = ROOT / 'build/presentation-source'
FALLBACKS = {
    16000: 'f2985b30-0c9b-11ef-a9c0-f7d533c38241.png',
    16001: '78757670-1823-11ee-945b-25f1819863ae.png',
    16002: 'fd31fde0-0282-11ee-b0c9-fdb1052b04a0.png',
    16003: 'd3750c10-02df-11ee-9982-81b28a5bf9b9.png',
    16004: 'd3750c10-02df-11ee-9982-81b28a5bf9b9.png',
    16005: '78757670-1823-11ee-945b-25f1819863ae.png',
    16006: '92143f30-0225-11ee-a05a-25b2ab36f585.png',
    16007: 'fd31fde0-0282-11ee-b0c9-fdb1052b04a0.png',
    16008: '78757670-1823-11ee-945b-25f1819863ae.png',
}


def source_for(path):
    relative = path.removeprefix('assets/')
    return next((p for p in [SOURCE / relative, BASE / relative,
                            CACHE / Path(path).name] if p.is_file()), None)


def location_source(row):
    path = row['imgPath']
    if source_for(path) is None and row['id'] in FALLBACKS:
        return f"assets/stories/14/backgroundImgs/{FALLBACKS[row['id']]}"
    return path


def read(relative, key):
    return json.loads((SOURCE / relative).read_text(encoding='utf-8'))[key]


def art_path(path):
    return f'scene/{Path(path).name}' if path else None


def location_images():
    return {row['id']: art_path(location_source(row))
            for row in read('stories/16/data/locations.json', 'locations')}


def build(out, copy_images=True):
    missing = []
    images = ROOT / 'assets/images'

    def asset(path):
        if not path:
            return None
        source = source_for(path)
        if source is None:
            missing.append(path)
            return None
        target = art_path(path)
        if copy_images:
            dest = images / target
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, dest)
        return target

    def actor(row):
        return {
            'skeleton': asset((row.get('skeleton') or {}).get('imgPath')),
            'expressions': {x['name']: asset(x.get('imgPath')) for x in row.get('expressions', [])},
            'clothes': {x['name']: asset(x.get('imgPath')) for x in row.get('clothesList', [])},
            'otherLayers': {x['name']: asset(x.get('imgPath')) for x in row.get('otherLayerList', [])},
        }

    npcs = {}
    for filename in ['global_data/npcs.json', 'stories/16/data/npcs.json']:
        for row in read(filename, 'npcs'):
            npcs[str(row['id'])] = actor(row)
    characters = {str(row['id']): actor(row)
                  for row in read('global_data/characters.json', 'characters')
                  if 16 in row.get('availableStoryIds', [])}
    backgrounds = {}
    for row in read('stories/16/data/backgroundImgs.json', 'backgroundImgs'):
        path = asset(row.get('imgPath'))
        if path:
            backgrounds[row['imgPath']] = path
    for row in read('stories/16/data/locations.json', 'locations'):
        path = asset(location_source(row))
        if path:
            backgrounds[row['imgPath']] = path
    badges = {}
    for row in read('global_data/university/universities.json', 'universities'):
        # The base APK contains the university crests separately from the asset pack.
        path = asset(f"assets/images/university/{row['id']}.png")
        if path:
            badges[str(row['id'])] = path
    data = {'npcs': npcs, 'characters': characters, 'backgrounds': backgrounds, 'badges': badges}
    out.mkdir(parents=True, exist_ok=True)
    (out / 'presentation.json').write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    (ROOT / 'build').mkdir(exist_ok=True)
    (ROOT / 'build/presentation-assets-report.json').write_text(json.dumps({'missing': sorted(set(missing)),
        'npcs': len(npcs), 'characters': len(characters), 'crests': len(badges)}, indent=2), encoding='utf-8')
    print(f'Presentation: {len(npcs)} NPCs, {len(characters)} characters, {len(badges)} crests; '
          f'{len(set(missing))} unavailable source files (see build/presentation-assets-report.json)')
    return data


if __name__ == '__main__':
    import sys
    if '--fetch-locations' in sys.argv:
        from PIL import Image
        CACHE.mkdir(parents=True, exist_ok=True)
        for row in read('stories/16/data/locations.json', 'locations'):
            relative = row['imgPath'].removeprefix('assets/')
            target = CACHE / Path(relative).name
            if (SOURCE / relative).exists() or target.exists():
                continue
            try:
                payload = urllib.request.urlopen(row['imgPathFromHttp'], timeout=30).read()
                import io
                with Image.open(io.BytesIO(payload)) as image:
                    image.verify()
                target.write_bytes(payload)
                print(f"Recovered location art {row['id']}")
            except Exception as error:
                print(f"Location {row['id']} unavailable: {type(error).__name__}")
    build(ROOT / 'packs/kss16')
