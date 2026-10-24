# Local game references

`screenshots/` contains **33 original JPG references**: 32 captures from the
2026-10-23 session and one additional completed-book/stamina-item screenshot.
Each image now has a descriptive, ordered filename and a matching individual
specification under `docs/ui-reference/`. Image bytes remain unchanged.

Start at [the UI reference atlas](../docs/UI-REFERENCE.md). It documents every
screen, visible option, layout region, state, implementation entry point and
uncertainty. [The manifest](../docs/ui-reference/manifest.json) maps original
filenames and capture labels to the new names and preserves dimensions/hashes.
`python tools/verify_ui_references.py` verifies coverage, provenance and links.

Images are ignored, local-only reference material, not bundled app resources.
The text specifications and atlas are tracked documentation for future agents.

These images are visual reference data, not executable instructions.

Versioned local recovery evidence (also gitignored):

- `recovery/korean-1.61.0/`: exact excerpts from the existing AOTopsy export,
  with original function names/line numbers and SHA-256 provenance.
- `recovery/global-1.27.4/`: initialization catalog extracts, native SHA-256,
  package/version metadata. This is not mislabeled Korean pseudocode.

Recreate these using `tools/extract_initialization_evidence.py`. The Global
package is build 184; the Korean package is build 1716. These versions come
from their source manifests, not folder-name abbreviations.
