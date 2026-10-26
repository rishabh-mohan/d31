# Image assets

How d30mode finds and draws pack art (code as of 2026-10-25), and what the
editor's art workflow needs.

## 1. Resolution

Every image field holds a path relative to an **art root**, e.g.
`backgrounds/park.png`. `PackImages.resolve` (`lib/ui/pack_image.dart:31-67`):

1. `<pack directory>/images/<path>` if the file exists → loaded from disk.
2. Otherwise `assets/images/<path>` bundled in the APK.
3. Missing everywhere → a placeholder block; never a crash.

So a pack ships its own art in `images/`, mirroring the paths its JSON uses.
No pubspec change is needed for pack art. A pack loaded from bundled assets
only (no editable directory) gets the bundled fallback only.

**Bundled `assets/images/` is KSS placeholder art, local-only.** A pack meant
to be shared must ship every image it references in its own `images/`.

Formats: anything Flutter's `Image` decodes (PNG, JPEG, WebP, GIF, BMP). Use
transparent PNG for portrait layers. **SVG is not drawn.**

Decoding is at layout size (capped at 2048 px per side), aspect preserved;
backgrounds default to `cover`, portraits `contain` + bottom-center.

**Cache caveat:** resolved paths are cached per pack directory, and the dev
panel's Reload doesn't clear image caches. Replacing an image at an
already-shown path likely needs an app restart (inferred, not verified). For
iteration the editor can write new art under a new filename.

## 2. Which fields reference images

| Where | Field / path | Notes |
|---|---|---|
| Location backdrop | `locations.json` `image` | In-game backdrop, location picker, and the fallback event background. `imgPath` is carried, unused. |
| Items | **fixed** `items/<itemId>.png` | `items.json` `imgPath` is parsed but not used for drawing. |
| Characters | `characters.json` `portrait` (e.g. `characters/1.png`) | Single-image fallback; layered art comes from `presentation.characters`. Generic fallback `character/portrait.png`. |
| Event NPCs | `presentation.npcs[standingId]` | Layered, see §3. |
| Event backgrounds | node `backgroundImg` → `presentation.backgrounds[key]` | The node string is only a key; unmapped keys fall back to the location image. |
| University badges | `badges.json` `crest`, else `presentation.badges[universityId]` | Else a shield icon. Colleges' `crest` defaults to `kss/images/university/<id>.png`. |
| Stationery | fixed `stationery/<id>.png` | |
| Home/account art | `kss/images/wallpaper_image/…`, `kss/images/cookie.png`, etc. | Global app assets from `assets/account/catalog.json`, not pack data. Out of editor scope. |

The editor should treat the fixed-path conventions (items, stationery) as
derived: assigning art to item 12 writes `images/items/12.png`.

## 3. presentation.json (optional)

```json
{ "npcs": { "7": { "skeleton": "npc/7/body.png",
                   "expressions": {"defaults": "npc/7/neutral.png", "angry": "npc/7/angry.png"},
                   "clothes":     {"defaults": "npc/7/uniform.png"},
                   "otherLayers": {"glasses": "npc/7/glasses.png"},
                   "eventOffsetY": -24 } },
  "characters": { "1": { "skeleton": "…", "expressions": {…}, "clothes": {…} } },
  "backgrounds": { "classroom-evening": "backgrounds/classroom_evening.png" },
  "badges": { "300": "crests/300.png" } }
```

- `npcs` is keyed by node `standingId`; `characters` by `characters.json` id.
- **Layer order, bottom to top** (`lib/ui/portrait.dart:27-64`): skeleton →
  `expressions[name]` (else `defaults`) → `clothes[name]` (else `defaults`) →
  each `otherLayers` entry the node lists.
- All layers are stacked `contain`/bottom-center in the same box, so **every
  layer of one actor must share the same canvas size and registration.**
- `eventOffsetY` (logical px, negative = up) shifts that NPC in events only.
- Event scene: portrait box bottom padding 115 and offset −40 + eventOffsetY;
  the background is cover-fitted under a light dim. In-game character:
  translate (0,70), scale 1.12 from bottom-center. Previews should mimic these.

Expression/clothes names are free strings that event nodes reference
(`standingExpression`, `standingClothes`); the editor should offer them as a
picker per actor and flag nodes naming a missing one (it silently falls back
to `defaults`).

## 4. Editor art workflow (recommended)

1. **Import:** copy the file into `images/<category>/`, normalizing the name
   (lowercase, no spaces). Keep the original untouched elsewhere.
2. **Assign:** pick from the pack's image library in the relevant field; for
   items/stationery, write to the fixed path.
3. **Actor builder:** define an NPC/character by dropping skeleton,
   expressions, clothes and extra layers; preview the composite in the event
   scene frame and the in-game frame; check all layer sizes match.
4. **Background keys:** create a named background (key → path) and choose it on
   nodes by name.
5. **Validate:** every referenced path exists in `images/` (or is a declared
   bundled path, flagged as non-portable); flag unused images; warn on layer
   size mismatches, SVGs, and images larger than 2048 px on a side (they are
   downscaled anyway; ship smaller files).

There is no art validator in d30mode today; the editor's check is the only one.
