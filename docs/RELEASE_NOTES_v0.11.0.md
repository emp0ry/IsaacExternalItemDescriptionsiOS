# Isaac External Item Descriptions iOS v0.11.0

This update adds native crafting and current-effect inspection, more original
EID synergies, personal pause inventories and optional outcome predictions.
It also fixes pocket-active decoding, rotating pedestal descriptions and
missing collectible quantities.

## Pocket actives and Bag of Crafting

- Pocket actives resolve through the game's real active-slot reference instead
  of using that reference as a collectible ID. This fixes Tainted Cain showing
  Spoon Bender in EID Items when he does not own it.
- Bag of Crafting shows its current ingredient icons and fill progress.
- At 8/8, inspecting the bag displays the game's cached result, including its
  title, icon, quality and full translated description.
- Replacing ingredients refreshes the result. Inspecting it never crafts,
  changes ingredients, advances RNG or adds the result to owned items.
- This is a preview of the actual bag, not a recipe browser or a planner using
  pickups outside it.

## Food and familiar synergies

- Binge Eater adds the original per-food stat bonuses, temporary damage, speed
  penalty and applicable healing changes. Character health conversions remain
  respected, including Tainted Bethany's blood charges and Lost protections.
- Supported BFFS! and Hive Mind familiar descriptions show their changed
  effects without incorrectly multiplying their shared bonus twice.
- No-effect familiar warnings, supported familiar trinkets and Soul of Bethany
  receive their applicable notes. Upgrade-pedestal hints use current ownership
  and do not appear when inspecting an already-owned upgrade.
- Forgotten Lullaby includes clot support and the relevant wisp, Gello and
  other no-effect exceptions in both directions.
- Removing an enabling item removes its conditional bonuses.

## Rotating pedestal descriptions

- Binge Eater and other short item cycles follow the pedestal's current native
  item rather than showing the previous half-cycle's description.
- The display refresh checks only the selected pedestal and redraws on a
  changed identity; it does not accelerate the full memory scan.
- Removed, reused, hidden and stale-room pickups are rejected. Curse of the
  Blind protections remain in effect.
- Glitched Crown retains its separate tap-to-browse five-item interface.

## Current effects, not future rolls

- **Void:** already-absorbed actives appear in a separate clickable EID Items
  section, including duplicate counts. The game's persisted native list is
  authoritative across Continue and consumed single-use effects.
- Absorbed actives are not physical inventory items. Passive collectibles such
  as Brimstone become stat bonuses when absorbed and correctly do not appear
  in Void's active-ability list.
- **Purity:** inspecting the owned item shows its current active aura bonus or
  inactive-until-next-room state, without predicting the next random aura.
- **Modeling Clay:** inspecting the owned trinket shows its already-applied
  room item's description and source. No-effect rooms retain the ordinary
  trinket description; temporary items are not added to physical inventory.

## Personal inventories and duplicate quantities

- EID Items offers a native-player selector for Jacob/Esau and co-op players.
- Collectibles, all four active slots, pockets, swallowed trinkets, absorbed
  actives and transformation counters are scoped to the selected player.
- Selecting a description uses that player's ownership-dependent context,
  rather than borrowing PHD, Car Battery or other effects from a partner.
- Repeated physical collectibles use one row with their current count, such
  as **Brimstone ×3**. Gaining/removing copies refreshes the list; a single copy
  has no unnecessary ×1 suffix.
- Raw counts and active-slot occurrences are merged without counting the same
  physical copy twice. Void and temporary effects do not inflate this quantity.

## Optional next-outcome previews

The **RNG predictions (spoilers)** setting is **off by default**.

- **Crooked Penny:** shows its next heads/tails outcome from copied native RNG
  and room state. Car Battery has a separate second-result line.
- **Eternal D6:** shows whether the next individual eligible pedestal reroll
  replaces or removes the item. The actual Eternal D6 mode of D Infinity is
  supported too.
- With Car Battery, Eternal D6 explicitly labels **first reroll only (1/2)**.
  It does not promise survival of both activations or a future-use count.
- Invalid/unavailable native context suppresses predictions rather than
  guessing. Reading the preview does not advance RNG or invoke an effect.

## Downloads and compatibility

The release includes standalone dylib, rootless `.deb`, complete LiveContainer
framework, embedded bundle, description database, full-build archive and
checksums. Original EID data and resources remain attributed and included with
the original author's permission.

Target: **native Isaac iOS 1.4 / Repentance 1.7.9b.J754**, ARM64, iOS 15+.
Repentance+ and other executable versions are not supported by these offsets.
The dylib has no jailbreak-only runtime dependency; jailbreak injection is
only one loading method. Direct embedding and LiveContainer still require the
appropriate host installation/signing setup.

Fully restart Isaac after updating. Use only one EID loading method. No Isaac
IPA, user saves, account credentials or purchase bypass is distributed.

## Verification and remaining scope

- Host coverage includes native-policy bounds, active-slot decoding, copied
  RNG sequences, personal context isolation, duplicate quantities, conditional
  descriptions and presentation in 20 languages, imports and package layout.
- Strict ARM64 compilation, signature verification and the portable-library
  audit passed locally; the release workflow repeats distribution checks.
- The user confirmed crafting/pocket-active changes, food/familiar changes and
  the Binge Eater refresh fix on the development phone, and subsequently
  reported the other current-effect changes working. This is not a claim that
  every co-op, character, language and loading-mode combination was replayed.
- Duplicate-quantity rendering is host-tested and installed, but its final
  on-device visual check remains pending at publication.
- Per-player ownership of the merged Super Bum familiar remains unverified;
  that personal counter is omitted in co-op rather than attributed incorrectly.
  Void actives are not treated as physically held items by every synergy
  adapter. Book of Virtues pedestal previews still consider all owned actives.
- Older pending checks, including individual tainted-character salvage cases
  and Flip regression coverage, are documented rather than assumed passed.

[Crafting checks](testing-crafting-preview.md) ·
[Food/familiar checks](testing-food-familiars.md) ·
[Current effects and inventory checks](testing-current-effects.md) ·
[Optional outcome checks](testing-outcome-predictions.md) ·
[Website](https://isaaceidios.emp0ry.com/) ·
[Report a problem](https://github.com/emp0ry/IsaacExternalItemDescriptionsiOS/issues)
