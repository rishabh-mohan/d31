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


def location_images(story_id=16):
    return {row['id']: art_path(location_source(row))
            for row in read(f'stories/{story_id}/data/locations.json', 'locations')}


def build(out, copy_images=True, story_id=16):
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
    for filename in ['global_data/npcs.json', f'stories/{story_id}/data/npcs.json']:
        for row in read(filename, 'npcs'):
            npcs[str(row['id'])] = actor(row)
    if story_id == 20:
        # User-requested event-only lift for Mum and Ji Suin.
        for npc_id in ('1', '3'):
            if npc_id in npcs:
                npcs[npc_id]['eventOffsetY'] = -24
    characters = {str(row['id']): actor(row)
                  for row in read('global_data/characters.json', 'characters')
                  if story_id in row.get('availableStoryIds', [])}
    backgrounds = {}
    for row in read(f'stories/{story_id}/data/backgroundImgs.json', 'backgroundImgs'):
        path = asset(row.get('imgPath'))
        if path:
            backgrounds[row['imgPath']] = path
    for row in read(f'stories/{story_id}/data/locations.json', 'locations'):
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
    # Story rewards also need their catalog art in receipts and the bag.
    for kind in ('consume', 'normal'):
        for row in read(f'stories/{story_id}/item/story_{kind}_items.json', 'items'):
            source = source_for(row.get('imgPath') or '')
            if source is not None and copy_images:
                dest = images / 'items' / f"{row['id']}.png"
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, dest)
    out.mkdir(parents=True, exist_ok=True)
    (out / 'presentation.json').write_text(json.dumps(data, ensure_ascii=False, indent=1) + '\n', encoding='utf-8')
    (ROOT / 'build').mkdir(exist_ok=True)
    report_name = 'presentation-assets-report.json' if story_id == 16 else f'presentation-assets-report-{story_id}.json'
    (ROOT / 'build' / report_name).write_text(json.dumps({'missing': sorted(set(missing)),
        'npcs': len(npcs), 'characters': len(characters), 'crests': len(badges)}, indent=2), encoding='utf-8')
    print(f'Presentation: {len(npcs)} NPCs, {len(characters)} characters, {len(badges)} crests; '
          f'{len(set(missing))} unavailable source files (see build/{report_name})')
    return data


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--story', type=int, choices=[16, 20], default=16)
    parser.add_argument('--fetch-locations', action='store_true')
    parser.add_argument('--fetch-opening', action='store_true')
    parser.add_argument('--fetch-npc', type=int, action='append', default=[],
                        help='Recover every portrait layer for these story NPC IDs')
    args = parser.parse_args()
    if args.fetch_locations or args.fetch_opening or args.fetch_npc:
        from PIL import Image
        from concurrent.futures import ThreadPoolExecutor
        CACHE.mkdir(parents=True, exist_ok=True)
        def fetch(row):
            relative = row['imgPath'].removeprefix('assets/')
            target = CACHE / Path(relative).name
            if (SOURCE / relative).exists() or target.exists():
                return
            try:
                payload = urllib.request.urlopen(row['imgPathFromHttp'], timeout=12).read()
                import io
                with Image.open(io.BytesIO(payload)) as image:
                    image.verify()
                target.write_bytes(payload)
                print(f"Recovered art {row.get('id', target.name)}")
            except Exception as error:
                print(f"Art {row.get('id', target.name)} unavailable: {type(error).__name__}")
        rows = read(f'stories/{args.story}/data/locations.json', 'locations') if args.fetch_locations else []
        def image_rows(value):
            if isinstance(value, dict):
                if value.get('imgPath') and value.get('imgPathFromHttp'):
                    yield value
                for child in value.values():
                    yield from image_rows(child)
            elif isinstance(value, list):
                for child in value:
                    yield from image_rows(child)
        for actor in read(f'stories/{args.story}/data/npcs.json', 'npcs'):
            if actor['id'] in args.fetch_npc:
                rows.extend(image_rows(actor))
        if args.fetch_opening:
            if args.story != 20:
                parser.error('--fetch-opening currently requires --story 20')
            nodes = read('stories/20/event/events.json', 'nodes')
            opening = [node for node in nodes if node['id'] // 1000 in [1, 169, 2, 3, 4, 211, 6, 7]]
            actors = {node.get('standingId') for node in opening if node.get('standingId')}
            for actor in read('stories/20/data/npcs.json', 'npcs'):
                if actor['id'] in actors:
                    rows.extend(image_rows(actor))
            backgrounds = {node.get('backgroundImg') for node in opening if isinstance(node.get('backgroundImg'), str)}
            rows.extend(row for row in read('stories/20/data/backgroundImgs.json', 'backgroundImgs') if row.get('imgPath') in backgrounds)
        rows = list({row['imgPath']: row for row in rows}.values())
        with ThreadPoolExecutor(max_workers=4) as pool:
            list(pool.map(fetch, rows))
    build(ROOT / f'packs/kss{args.story}', story_id=args.story)
