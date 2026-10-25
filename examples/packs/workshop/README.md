# Workshop pack

A small independent pack demonstrating content extensions without engine edits.
Copy this directory to `packs/workshop` in a supported editable pack root and
choose Workshop in the pack selector. No KSS files are required.

Choose Artisan, grant Steady hands, then invoke `ENABLE_BLOCK` with
`["crafting"]` (or its alias `["bench"]`) from an event changer. The crafting
block becomes eligible at the Workshop while Artisan is selected. It stays
unlocked across days and saves until an event invokes `DISABLE_BLOCK`.

Making a keepsake grants five Craft stats. The trait adds three Gold and the
character adds seven Gold through separate callback abilities. `{CRAFT_COUNT}`
can appear in event text. The example deliberately reuses IDs 69 and 70 from
KSS to demonstrate that IDs do not carry behavior between packs.

Definitions:

- `traits.json` / `characters.json`: catalog and setup descriptions.
- `locations.json`: ordinary location actions.
- `mechanics.json`: the custom block, gate, callback, abilities and text macro.
- `rules.json`: initial state and ordinary tuning.

For a playable opening unlock, add an event to `events/events.json`, list its
ID in `rules.events.openingEventIds`, and place
`{"funcCode":"ENABLE_BLOCK","args":["crafting"]}` in a node's changer.
This example leaves the event graph empty so tests can exercise unlock and
removal independently.
