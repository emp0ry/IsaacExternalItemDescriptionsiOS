# Advanced EID previews: device checklist

Use a disposable run and avoid syncing debug-generated progress to Steam.
The mod only reads native state. Console commands below deliberately change
the run when entered by the tester; they are not run automatically.

## Golden trinkets / Mom's Box

`spawntrinket t35` (Curved Horn): ordinary description gives +2 damage.
`giveitem c439` (Mom's Box): the same floor trinket should show +4, highlighted
gold. Remove Mom's Box with `remove c439`: it returns to +2 immediately after
the next refresh. A naturally golden Curved Horn gives +4 alone and +6 with
Mom's Box. Test Tick/Petrified Poop separately because they have special rules.

## Current Luck chances

`spawnitem c617` (Lodestone), then `giveitem c46` (Lucky Foot): at +1 Luck,
the extra line should show 20%. Another Lucky Foot makes +2 Luck and 25%.
Five total Lucky Feet from a zero-luck character should show 100%. Compare
the actual HUD Luck rather than assuming the character starts at zero.
Remove them and check that the line updates; at zero Luck upstream leaves
only its ordinary base description.

## Spindown Dice

`giveitem c723`, `spawnitem c10`: three results should be 9, 8, 7 when those
IDs are present/visible in the native config. Add `giveitem c356`: results
become 8, 6, 4. Try a missing/hidden ID boundary and Dad's Note separately.
Use `spawnitem c284` if D100 (`c283`) is still locked on the selected save:
D100 should be absent from the preview; only the eligible lower ID is shown.
Apply Spindown and compare the actual result to the preview.
The three results must form a single arrow-connected paragraph, with one
Spindown prefix. Long text may wrap to the available width; individual uses
must not insert forced line breaks or repeat the prefix. Check with Car Battery.
Do not assume every user's D100 is locked; use another known locked boundary
when necessary. An unlocked but never-picked-up item must remain eligible.
Repeat after changing save slots, and with a newly earned unlock.

Run restrictions use the native effect's exact availability flags, including
Greed/challenge/character conditions. Ineligible candidates must not appear,
even as crossed-out icons or warning rows. Hidden/nonexistent entries do not appear. Car Battery must skip
ineligible entries independently on both triggers. At `c2`, the chain should
include `c1`, then the localized disappearance message. Dad's Note must stop
even Car Battery's second trigger. Removing Spindown must remove the preview.

## Mimic charges

- `giveitem c286`, `spawncard 5`: The Emperor costs 4 charges in iOS Repentance.
- `giveitem c263`, `spawnrune jera`: Clear Rune costs 12 charges.
- `giveitem c348`: approach a known pill; Placebo's charge line should match
  that effect's native metadata. Unknown pills must have no charge line.
- `giveitem c451` with Blank Card: test a card with a Tarot Cloth/Blank Card
  special note and verify the extra text. Remove the active to remove its line.

Active replacements can remove an earlier test active: check actual ownership.

## Flip

Included in the build; live device verification is pending.

`giveitem c711` before entering a newly generated item room. A pedestal with
an alternate silhouette should show its real alternate icon/name/description.
Use Flip: original/alternate descriptions should swap. Test an empty pedestal
after picking up one side. Existing pedestals spawned before Flip do not
necessarily have an alternate record; the mod must not invent one.
Curse of the Blind / forced question marks must hide both sides.

## Void / Black Rune

`giveitem c477`, spawn a single passive (for example `spawnitem c25`), and
compare the two predicted stat increases with the actual use. Repeat with
two passives, an active, and Moving Box (`spawnitem c523`). The active should
not add Void stat gains except Moving Box. Holding `spawnrune black rune`
should show its separate prediction and count active pedestals too.

Before using either, wait several seconds and open/close EID repeatedly:
the result must not change from viewing the overlay. Changes caused by actual
gameplay/other RNG consumption are normal. Test an Options? group, a shop
purchase absorbed above the player's head, and multiple room transitions.
Report expected vs actual HUD values; the log contains copied-RNG validation
messages, not authentication secrets or save contents.

## Regression checks

- PHD + False PHD and removal of either still update correctly.
- Curse of the Blind, unknown cards/pills, flight/reachability and shop rules
  remain intact.
- Existing battery/title/icon font sizes are unchanged.
- EID settings and pause inventory remain clickable and hide during gameplay.
- Repeat launch/Continue in native Isaac and LiveContainer separately.

## Inline artwork and cold-start controls

- `spawnitem c297` (Pandora's Box): the inline Bible and Red Key should have
  comparable visible height to the other body-text icons. Text and battery
  sizes should remain unchanged. Check Spindown's inline results as well.
- On the affected LiveContainer device, replace the app-specific EID framework
  with the test archive, then fully restart Isaac. Before touching either side
  of the screen, check for the previously stuck joystick in the upper-left.
- Check the menu settings button, Continue, both gameplay sticks, pause settings
  and EID Items. Repeat a full launch and a background/foreground cycle.
- The log should record `Isaac render host ready after native frames` before
  `bootstrap`. No new UIKit window or simulated touch should be required.

The user confirmed the LiveContainer cold-launch joystick fix and inline artwork
sizes on the affected device. The supplied Spindown screenshot also confirms the
arrow-connected presentation. These results do not cover every device or preview.

Host tests: `make test dylib audit EXTRA_CFLAGS='-Wall -Wextra -Werror'`.
Device result checklist is intentionally not marked passed by a successful build.
