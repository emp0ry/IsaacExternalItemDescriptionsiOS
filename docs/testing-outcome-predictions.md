# Optional next-outcome predictions

Use disposable runs for commands and item effects. No test command is executed
automatically on the user's current run. Restart Isaac after installing the
updated dylib and descriptions database.

## Enable and disable

The **RNG predictions (spoilers)** setting defaults to off, matching the original
EID's opt-in RNG-reminder behavior. Enable it from the scrollable EID settings
card in the menu or on pause. Turning it off must immediately remove outcome
annotations without affecting ordinary descriptions, Luck, Spindown or crafting
previews. The setting must survive a restart.

## Eternal D6

1. In a disposable run, obtain Eternal D6 (`giveitem c609`). Spawn a test pedestal
   (`spawnitem c25`) and approach it.
2. With predictions enabled, the description must add the next individual
   reroll result: replacement or disappearance. With the setting off, no such
   line appears. Already owned pause-inventory entries must not get a pedestal
   disappearance claim.
3. Use the charged die normally, comparing the prediction with the pedestal's
   actual survival. Repeat across several fresh pedestals and subsequent rooms.
   Merely opening/closing EID Items must not change the result, charge or RNG.
4. With D Infinity (`giveitem c489`), cycle the actual game die to Eternal D6;
   its pedestal prediction must appear only in that actual mode, not just from
   browsing Eternal D6's description inside the inventory UI.
5. With Car Battery (`giveitem c356`), the label must explicitly say **first
   reroll only (1/2)**. A successful first reroll does not promise the pedestal
   survives both activations. Exact future-use counts/second outcomes are not
   implemented for this iOS build.
6. Curse of the Blind, forced-question-mark pedestals, expired pickup pointers,
   non-rerollable objects and unavailable native state must reveal no outcome.

## Crooked Penny

1. In a disposable run, obtain Crooked Penny (`giveitem c485`). Pause, open
   **EID Items**, and select it. The next result is **Heads / Tails** (Russian:
   **Орёл / Решка**), using the selected EID language with English fallback.
2. Resume and use the charged active normally in a room with disposable pickups.
   Heads duplicates eligible pickups; tails removes them and gives a penny.
   The observed result must match the preview. Inspect it again after use and
   after changing rooms: predictions must refresh, not reuse the old result.
3. Obtain Car Battery (`giveitem c356`). Its separate second-result line must
   match the second native activation. Test all observed combinations, especially
   a failed first activation, which consumes an extra original-stream RNG step.
4. A missing/unowned item, invalid RNG record or absent room descriptor must not
   guess heads/tails. Other inventory items must not inherit this prediction.

## Verification status

Host coverage includes opt-in gating, copied RNG sequences, zero-XOR handling,
the original-stream Car Battery advance, native float boundary cases, twenty
language presentation/fallback, and architecture constraints. ARM64 builds and
dependency/signature audits are separate from device gameplay acceptance.

Reference behavior: [original EID predictions](https://github.com/wofsauge/External-Item-Descriptions/blob/master/features/eid_itemprediction.lua)
and [item reminders](https://github.com/wofsauge/External-Item-Descriptions/blob/master/features/eid_holdmapdesc.lua).
This iOS implementation follows the verified native branches where those differ
from the current desktop formulas.
