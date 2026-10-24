"""Verify the local screenshot atlas without modifying images or app content.

Requires Pillow (also used when validating recovered presentation assets).
Run from any directory: python tools/verify_ui_references.py
"""
import hashlib
import json
import re
from pathlib import Path
from urllib.parse import unquote

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main():
    records = json.loads((ROOT / 'docs/ui-reference/manifest.json').read_text(encoding='utf-8'))['images']
    errors = []
    for field in ['id', 'original', 'image', 'document']:
        if len({r[field] for r in records}) != len(records):
            errors.append(f'Duplicate manifest {field}')
    documented_images = set()
    documented_specs = set()
    for record in records:
        image = (ROOT / record['image']).resolve()
        document = (ROOT / record['document']).resolve()
        if not image.is_relative_to(ROOT.resolve()) or not document.is_relative_to(ROOT.resolve()):
            errors.append(f"Path outside workspace: {record['id']}")
            continue
        documented_images.add(image)
        documented_specs.add(document)
        if not image.is_file():
            errors.append(f'Missing image: {image.name}')
        else:
            if hashlib.sha256(image.read_bytes()).hexdigest() != record['sha256']:
                errors.append(f'Image bytes changed: {image.name}')
            with Image.open(image) as picture:
                if picture.size != (record['width'], record['height']):
                    errors.append(f'Image dimensions changed: {image.name}')
        if not document.is_file():
            errors.append(f'Missing specification: {document.name}')
        else:
            text = document.read_text(encoding='utf-8')
            for heading in ['Visible state', 'Layout map', 'Text, options and controls',
                            'Fine-tuning checklist', 'What this picture does not establish',
                            'Implementation entry points', 'Compare with']:
                if f'## {heading}' not in text:
                    errors.append(f'{document.name}: missing {heading}')
            if record['original'] not in text or record['sha256'] not in text:
                errors.append(f'{document.name}: incomplete provenance')
            if image.stem != document.stem:
                errors.append(f'Mismatched image/spec names: {document.name}')
    actual_images = {p.resolve() for p in (ROOT / 'references/screenshots').iterdir()
                     if p.suffix.lower() in {'.png', '.jpg', '.jpeg', '.webp'}}
    actual_specs = {p.resolve() for p in (ROOT / 'docs/ui-reference').glob('*.md')}
    if actual_images != documented_images:
        errors.append(f'Image coverage mismatch: {sorted(str(p) for p in actual_images ^ documented_images)}')
    if actual_specs != documented_specs:
        errors.append(f'Spec coverage mismatch: {sorted(str(p) for p in actual_specs ^ documented_specs)}')
    documents = [*actual_specs, ROOT / 'docs/UI-REFERENCE.md', ROOT / 'references/screenshots/README.md']
    for document in documents:
        for target in re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', document.read_text(encoding='utf-8')):
            if target.startswith(('https://', 'http://', '#')):
                continue
            path = unquote(target.split('#')[0].strip('<>'))
            if path and not (document.parent / path).exists():
                errors.append(f'{document.name}: broken local link {target}')
    if errors:
        raise SystemExit('\n'.join(errors))
    print(f'OK: {len(records)} images, {len(actual_specs)} individual specs, original hashes/dimensions intact; all atlas links resolve.')


if __name__ == '__main__':
    main()
