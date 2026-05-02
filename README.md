# Nuzi Inventory

Inventory hunting, but with less alt-hopping and fewer "I swear I had that on somebody."

`Nuzi Inventory` keeps your item search where it belongs:

- search current bag items
- include bank items when you want them
- save alt snapshots and search across characters
- track important items into hotbars
- click tracked equipables to equip them quickly

## Install

1. Drop the `nuzi-inventory` folder into your AAClassic `Addon` directory.
2. Make sure the addon is enabled in game.
3. Click the inventory icon or use `!ib` to open it.

Saved data lives in `nuzi-inventory/.data` so updates do not wipe your tracked items and snapshots.

## Quick Start

1. Open `Nuzi Inventory`.
2. Search for the item you want.
3. Click `Track` on anything you want pinned to a hotbar.
4. Log onto alts and hit `Save This Character` to add their inventory to the shared search.
5. Use the tracked bar controls to choose `2 Bars` or `Categories`.

If you only care about your current character, skip the alt snapshots and just use it as a smarter bag search.

## How To

### Search Items

1. Type part of an item name into the search box.
2. Click `Search`.
3. Toggle `Bank: On/Off` if you want bank results included or hidden.
4. Use the page buttons to move through large result lists.
5. Clear to remove your search results.
6. Refresh to update the list/tracked bars.

Rows show the item name, who has it, where it lives, and the quantity.

### Save Alt Snapshots

Use `Save This Character` on each alt you want indexed.

That snapshot is then included when you search from any other character, which is much nicer than trying to remember which mule is hoarding your good decisions.

### Track Items

Click `Track` on any result to pin it into the tracked hotbars.

Tracked items can be shown in two layouts:

- `2 Bars` for `Equipables` and `Tracked`
- `Categories` for grouped bars like weapons, armor, shields, gliders, and other item types

You can also change `Icons per Row` so bars wrap cleanly instead of becoming a single long noodle across the screen.

### Tracked Hotbars

- `Equipables` are clickable and try to equip the live bag item for the current character.
- non-equipables are visual tracking bars only
- hold `Shift` while dragging a tracked bar to move it
- tracked bar positions are saved through reloads and relogs

## Notes

- Saved alt snapshots only reflect what the character had when you last clicked `Save This Character`.
- Tracked non-equipables are display-only. Direct consumable use is blocked in the API.

2.0.1
