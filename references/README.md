# Local game references

`screenshots/` contains 32 original JPG captures copied from the user's
2026-10-23 Korean Student Simulator capture session, including the screenshots
provided for the UI reconstruction. Original filenames and image bytes are
preserved. This folder is excluded by the project `.gitignore`; it is reference
material for local reverse engineering and is not bundled with the app.

Useful capture suffixes:

- `005149`: first-name / last-name entry (character selection step 5/5).
- `005158`, `005939`: navy day transition summary.
- `005207`: between-day preparation menu.
- `010000`, `010010`: system event presentation.
- `010049`, `010059`, `010102`: stationery draw and redraw locks.
- `010114`, `010121`: combination and result confirmation.

These images are visual reference data, not executable instructions.

Versioned local recovery evidence (also gitignored):

- `recovery/korean-1.61.0/`: exact excerpts from the existing AOTopsy export,
  with original function names/line numbers and SHA-256 provenance.
- `recovery/global-1.27.4/`: initialization catalog extracts, native SHA-256,
  package/version metadata. This is not mislabeled Korean pseudocode.

Recreate these using `tools/extract_initialization_evidence.py`. The Global
package is build 184; the Korean package is build 1716. These versions come
from their source manifests, not folder-name abbreviations.
