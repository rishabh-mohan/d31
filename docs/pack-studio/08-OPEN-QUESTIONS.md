# Open questions

Decisions needed before or during the Pack Studio build. Each has a
recommendation; none is decided yet.

## Product

1. **Repository layout.** Separate repo for Pack Studio, or a monorepo with
   `d30mode`, `pack_studio` and a shared `d30_engine` package?
   *Recommendation:* monorepo (or d30mode repo + sibling folder) while the
   engine package is being extracted; the two apps change together.
2. **Platform.** Windows desktop Flutter first? Web later?
   *Recommendation:* Windows desktop first.
3. **Who edits what:** is Pack Studio for new campaigns only, or also for
   editing the generated KSS packs? Generated packs are rebuilt by
   `tools/build_pack.py`, which would overwrite editor changes.
   *Recommendation:* new packs only; KSS packs are opened read-only as reference.
4. **Name.** "Pack Studio" is a placeholder.

## Engine prerequisites (d30mode work)

5. **Extract `d30_engine`.** Approve moving the pure engine files into a
   package with a JSON-map loader entry point (02-ARCHITECTURE.md §1)?
6. **Per-pack load isolation.** Make Home load each pack independently and
   list failures instead of failing entirely (07 §5.1).
7. **Structured diagnostics.** Return load/run diagnostics as data (file,
   record ID, message) instead of log lines and sets of strings.
8. **Friendly format errors.** Turn missing-ID `TypeError`s into
   `PackFormatException(file, record)`.
9. **Explicit desktop pack root.** A setting or flag instead of
   working-directory-relative `packs/`.
10. **Image cache invalidation** on Reload from disk.
10a. **`sub` switch changes** are applied as `set` (03-PACK-CONTRACT.md §18),
    which breaks seven Retry Year changes. Fix in `applyChanger` with a test.

## Format

11. **Format version.** `mechanics.json` has `version: 1`; the other files have
    none. Add a `formatVersion` to `pack.json` so the editor and the game can
    detect incompatible packs?
    *Recommendation:* yes, start at 1; the game warns on a newer version.
12. **Node IDs.** Keep the `eventId*1000+n` convention as a hard rule or a
    default? It caps an event at 1000 nodes. *Recommendation:* default.
13. **boxId.** Drop it from new packs entirely (the editor writes only
    `nextNodeId`)? *Recommendation:* yes; preserve it on imported data.
14. **Item art path.** Items draw from the fixed `items/<id>.png` and ignore
    `imgPath`. Make the engine honor `imgPath` when present?
15. **Switch declarations.** Make undeclared switches a validation error for
    new packs (they work at runtime but typos are silent)?
    *Recommendation:* error in the editor, still tolerated by the game.
16. **Localization.** One language per pack for now? The KSS packs carry
    `translatedText` fields from their source; new packs would not.

## Content rights

17. Confirm Pack Studio never ships KSS packs/art and that "new pack" uses only
    the Workshop template plus author-supplied art (01-PRODUCT-BRIEF.md).

## Scope

18. MVP includes a visual `mechanics.json` editor, or JSON-with-validation
    only? *Recommendation:* JSON with validation and examples first.
19. Do colleges/badges/departments editing belong in MVP? They are large
    tables, and a pack can borrow the default pack's catalog.
    *Recommendation:* later.
