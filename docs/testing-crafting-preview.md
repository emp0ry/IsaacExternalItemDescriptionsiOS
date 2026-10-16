# Pocket actives and Bag of Crafting preview

Use a disposable run for commands and crafting. Installing the dylib does not
change saves. Fully restart Isaac after replacing it.

## Pocket reference regression

1. Start/continue Tainted Cain, pause and open **EID Items**.
2. Bag of Crafting (710) must be present; Spoon Bender (3) must not appear unless
   the player really owns it. The startup inventory log must agree with raw
   collectible ownership (a fresh Tainted Cain starts with 710, not 3).
3. With a genuine Spoon Bender in a disposable run, it must still be listed.
4. Check another character with a pocket active (for example Tainted Judas).
   Its actual active appears, not whichever low-numbered collectible matches
   the internal slot reference. Cards, runes, normal/horse pills and their
   knowledge rules must remain unchanged.

## Bag inspection

1. Select the empty bag in **EID Items**: its normal description shows `0/8`.
2. Collect several pickups **with the bag**, not by walking over them. Select it
   again: progress and ingredient icons must match its actual contents.
3. Fill all eight slots. Pause and select Bag of Crafting: the description must
   now show the cached resulting item's own title, icon, quality and complete
   translated description, with the eight ingredients and result arrow.
4. Reopen the list: that predicted item must not appear as owned. Close the
   description without crafting; ingredients, player stats and item count must
   be unchanged.
5. Replace an ingredient, then inspect again: the result must refresh to the
   game's newly displayed result rather than remaining on the old item.
6. Optionally craft normally in the disposable run: the actual resulting item
   must match the preview. The next inspection must show the now-empty bag,
   not a stale result. Merely viewing the preview must never craft anything.
7. Verify English/Russian and the forced pause backdrop. D Infinity and Glitched
   Crown browsing must remain unaffected.
8. Missing/unstable/invalid native data must retain the ordinary bag description
   instead of inventing a result. Repeat after Continue/new-run transitions.

The preview uses the supported iOS build's cached native outcome, including its
seed/unlock decisions. It is not a recipe search engine or a predictor based on
uncollected room pickups. Device acceptance is separate from passing host tests.

The user confirmed the pocket-active fix and bag result preview working on the
development device on 2026-10-16. Runtime logs independently recorded a full
eight-ingredient bag with native cached result 472, inspected without crafting.
