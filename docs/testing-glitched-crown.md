# Glitched Crown: native-cycle device checklist

Restart Isaac after replacing the dylib and database together. Use a disposable
run. EID itself only reads state; the following console commands change gameplay.

## Basic test

1. `giveitem c689`: Glitched Crown.
2. `spawnitem c25`: a new Breakfast pedestal. It should now cycle between five
   items. If this particular spawn does not cycle, enter an unvisited Treasure
   Room while holding Crown; EID does not manufacture a cycle for fixed items.
3. Approach without collecting it. EID should show a Glitched Crown overview:
   five actual item icons and localized names, plus `0/5 ›` inside the header's
   top-right corner. There should be no floating button outside the description.
4. Tap the description (title or body). `1/5` through `5/5` should show each item's full description,
   appropriate icon, quality, transformations and active-item charge indicator.
5. Keep reading one selected description while the pedestal continues flashing.
   The selected description must not jump or reset every native switch.
6. After the final item, the next tap returns to the overview.

The displayed cycle is anchored consistently in native circular order, not to
whichever item happened to be visible when the 0.25-second overlay scan ran.
Duplicate native IDs appear only once, as in EID. Cycles with fewer than five
unique items use the normal pickup description rather than an incomplete list.

## Isolation, changes and regression tests

- `spawnitem c2`: create a second independent cycling pedestal. Move between
  them and verify that each has its own list/selection, without mixed variants.
- Pick up a pedestal: its overview/counter must disappear or switch to another
  genuinely nearby pickup. No invisible control should block the game sticks.
- Reroll the pedestal with a charged D6. Its newly generated list should replace
  the old one and return to overview. Merely cycling does not constitute a reroll.
- Open pause settings or EID Items: the cycle indicator must hide and the old
  description must stop claiming touches. Selecting an
  inventory item should show that item's normal description, not a floor cycle.
- Save and Exit / Continue: compare the overview with the native pedestal's
  current cycle. Start a new run: no old pedestal list/selection should leak.
- Curse of the Blind and forced question-mark sprites must hide the entire list,
  individual previews and counter. Check again after the blindness is removed.
- Switch English/Russian and another language. The next-description hint should
  refer to the iOS chevron, not an unavailable desktop Tab/map key.
- Verify a LiveContainer cold launch and ordinary game touch controls. No new
  UIWindow, game-view reparenting, injected touch or gameplay hook is used.

## Existing modifiers

- `giveitem c723`: Spindown Dice. In individual Crown views, the chain must belong
  to that selected item's ID. The overview must not show a chain for an invented
  Glitched Crown pickup. Locked candidates remain skipped completely.
- `giveitem c706`: Abyss. Individual item views should show their hypothetical
  locust information; the overview should remain the five-item list.
- `giveitem c711`: Flip. Test a native pedestal with an alternate record, ideally
  in an unvisited Treasure Room. Flip information still refers to that pedestal's
  native opposite side; the cycle reader never creates an alternate.
- Collection-page reminders apply to inspected individual items, never to the
  synthetic Glitched Crown overview itself.

Void/Black Rune room-stat predictions are deliberately suppressed inside cycle
previews: the selected hypothetical item may not match the live room's current
absorption eligibility. The mod does not imply it has predicted the pickup's
timing or controlled which cycling item Isaac actually collects.

## Recorded verification

Reference: original EID commit `8b59d00c6828e333294639ad2b2b6875eae821cb`,
`GlitchedCrownCallback` and `WatchForGlitchedCrown`. This implementation uses the
native queue, like the REPENTOGON-backed path, rather than sampling every frame.
Supported executable UUID: `F4357753-A25F-30EE-BACF-63709F902895`.

Host checks cover all circular rotations, duplicate rotations, unsupported IDs,
array bounds, the five-unique-item threshold, localization/fallback in all 20
languages, overview versus selected descriptions and adapting the input hint.
Touch/visibility architecture checks and strict ARM64/dependency audits are
separate from gameplay scenarios. The user confirmed the installed Crown build
works, then requested description-wide tapping and the inset counter instead of
a floating button. The user also confirmed that revised build works. This is
basic device acceptance, not a claim that every co-op/reroll/combined-modifier
scenario above has been independently exercised.
