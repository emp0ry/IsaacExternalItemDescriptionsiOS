# The Stars?, Black Feather and Flip: device checklist

Restart Isaac after replacing the dylib and bundled database together. Use a
disposable run, preferably ordinary Isaac: these console commands and actual
effect uses change the run. Installation does not modify saves or stop the game.

## The Stars? (reversed Stars, card 73)

1. Start a disposable run and move briefly so it has advanced beyond frame zero.
2. `spawnitem c25`: pick up Breakfast.
3. `spawnitem c2`: pick up The Inner Eye afterward.
4. `spawncard 73`: approach the card. Its final preview should show Breakfast's
   icon and localized name, not the active D6 or a starting passive.
5. `giveitem c451`: Tarot Cloth. The preview should show Breakfast and The Inner
   Eye, in that order. It should not include Tarot Cloth as one of these two.
6. Actually use the card and compare the removed items with the preview. The new
   items it spawns are not part of this feature's prediction.

Additional cases:

- Without Tarot Cloth only one eligible item is listed. With only one eligible
  item, do not invent a second; with none, retain the base description alone.
- Remove an item with `remove c25`: it must stop being a removal target.
- Pick up two copies of the same passive: both copies can be listed if both are
  actually owned and Tarot Cloth applies. Duplicate history with only one owned
  copy must not produce two removals of that same copy.
- Test Save and Exit / Continue: history must remain in its native order.
- Start a new run: previous pickup order must not leak. Quest/challenge starter
  protections, Curse of the Blind and ordinary card visibility remain intact.

## Black Feather (trinket 80)

On a fresh ordinary Isaac run, keep Feather on the floor for inspection:

| Action | Expected computed final line |
| --- | --- |
| `spawntrinket t80` | 0 qualifying items, +0 damage |
| `giveitem c215` (Goat Head) | 1, +0.5 |
| `giveitem c216` (Ceremonial Robes) | 2, +1 |
| `giveitem c216` again | 3, +1.5; duplicates count |
| `remove c216` once | 2, +1; refresh without walking away |
| `remove c216` again | 1, +0.5 |
| `giveitem c439` (Mom's Box) | 1, +1 |
| `remove c439` | 1, +0.5 |
| `spawntrinket t17`, pick it up (Black Lipstick) | 2, +1 without Mom's Box |

Daemon's Tail (`spawntrinket t22`) also qualifies. Other counted collectibles are
Abaddon (230), Black Candle (260), Missing Page 2 (262), Safety Pin (339), Match
Book (344) and False PHD (654). Unrelated items must not increase the count.

The normal/golden and Mom's Box combinations follow upstream's callback. Native
qualifying-trinket multipliers include swallowed/golden copies and Mom's Box
effects; these already-multiplied counts are intentionally used as upstream does.
Use naturally obtained golden trinkets for that test: the current Debug Console
rejects raw subtypes above 9999, so `spawn 5.350.32848` is not a supported command.
Check English and Russian; no `{1}` / `{2}` placeholders should remain.

## Flip (existing feature; previously awaiting gameplay verification)

1. `giveitem c711`: Flip. Obtain it before entering an unvisited Treasure Room.
   Inspect a native pedestal showing its translucent alternate item. A newly
   console-spawned pedestal can also be tried, but the game must generate the
   alternate record; EID does not manufacture an invisible second item.
2. The description should include a Flip icon, the alternate item's icon/name,
   and its description in the selected language.
3. Use a charged Flip normally. The newly visible item must match the preview;
   the alternate preview should now point back to the previous item.
4. If the pedestal retains a ghost item after the visible item is collected,
   approach it: its remaining alternate should still be describable when native
   blind/visibility checks allow it.
5. Save/Continue and return to the room. Check that the actual alternate remains
   correct. Curse of the Blind and forced question-mark pedestals must not leak
   either identity.

## Verification boundaries

Host tests exercise native-history layout/span validation, starter/active/quest
exclusions, stale ownership, duplicates and Tarot Cloth simulation. Description
tests cover native result formatting, all 20 languages with English fallback,
Black Feather counts, removal, normal/golden/Box combinations, and unknown state.
Strict ARM64 builds and dependency audits are separate from gameplay acceptance.
The user reported that everything works after this update, before requesting
Glitched Crown. Individual golden/co-op/challenge cases were not separately
reported and are not automatically marked verified by that confirmation.
