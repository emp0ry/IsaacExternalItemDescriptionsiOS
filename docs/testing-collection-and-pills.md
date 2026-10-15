# Collection and pill test checklist

Acceptance checklist for the v0.9.0 collection and pill additions. Use a disposable run: console commands change gameplay. EID itself only reads game state. Host coverage and a screenshot do not imply that every combination has been gameplay-tested.

## Collection page

1. Use a normal, unseeded run. Pick a collectible that is still missing from the collection page in the current save slot, and spawn its pedestal with `spawnitem c<ID>`.
2. The final description line should say that the item needs to be picked up for the collection page, in the selected EID language.
3. Pick it up, spawn another copy, and check that the reminder disappears immediately. Exchanging an active item does not make it uncollected again.
4. Save and continue. The reminder should stay absent. Another save slot must use its own collection flags.
5. Already-collected items, hidden quest collectibles, pause-inventory entries, and runs whose persistent progress is read-only should not get this reminder. Curse of the Blind must still suppress the entire collectible description.

The reminder helps with the item-collection requirement; it does not mean that all requirements for Dead God are complete. It neither reads Game Center nor grants an achievement.

## Distinctive cards and runes

Spawn beside the player, or inspect a naturally generated shop pickup:

| Command | Identity | Expected shop description |
| --- | --- | --- |
| `spawncard 43` | Credit Card | Visible |
| `spawncard 41` | Black Rune | Visible |
| `spawncard 49` | Dice Shard | Visible |
| `spawncard 50` | Emergency Contact | Visible |
| `spawncard 51` | Holy Card | Visible |
| `spawncard 55` | Rune Shard | Visible |
| `spawncard 78` | Cracked Key | Visible |
| `spawncard 80` | Wild Card | Visible |
| `spawncard 81` | Soul of Isaac | Visible |
| `spawncard 1` | The Fool | Hidden until purchased; visible on a reachable free pedestal |
| `spawncard 42` | Chaos Card | Hidden until purchased: its green pickup model is shared |
| `spawncard 32` | Jera | Hidden until purchased: its rune shape is shared |

Console spawns are free pickups, not automatically shop stock. A free card in a shop therefore does not test the purchasable-card rule. `Options?` masking remains protected for every card.

## PHD and False PHD

1. In a fresh run without pill-identifying items, `spawnpill 1` should remain unidentified unless that color was already used.
2. `giveitem c75` (PHD): unknown colors become identified; negative effects should display their positive native replacement. Color artwork must not change with the effect name.
3. Test False PHD separately in a fresh run with `giveitem c654`. A stat-down pill should append `+0.6` damage; the horse version should append `+1.2`. Appropriate non-stat bad pills append one black heart. Neutral/positive effects must not invent a reward.
4. Useful effect commands: `spawnpill effect 15` (Tears Down), `spawnpill effect 47` (Shot Speed Down), `spawnpill effect 22` (Paralysis), `spawnpill effect 42` (I'm Excited), `spawnpill effect 49` (Experimental Pill). Add `horse` for a horse pill.
5. If the console says an effect is not in the run's pill pool, choose another listed effect or another disposable run. It does not indicate an EID failure.
6. Experimental Pill with PHD: no stat decrease. With False PHD: no stat increase, plus damage. With both: the opposing stat filters cancel, but the False PHD damage bonus remains. Virgo/Lucky Foot prevent the decrease without identifying all pills themselves.
7. Verify floor pickups and held pills in the paused inventory. In co-op, descriptions must use the selected/nearest player's effect and must not award a partner's False PHD bonus to that player.
8. On a disposable run with Tears Down in its pool, keep the same pill nearby. `giveitem c75`, `giveitem c654`: Tears Down and the False PHD damage reward. `remove c654`: Tears Up, no False PHD reward. Give False PHD again, then `remove c75`: False PHD-only behavior. Finally `remove c654`: no False PHD reward. Repeat while staying paused in the console and after resuming; no restart or room change should be necessary.
9. A color already identified by the game can stay identified after the item is removed. That retained knowledge must never keep a removed item's damage or black-heart reward alive.

## Native verification

Supported executable UUID: `F4357753-A25F-30EE-BACF-63709F902895` (native iOS 1.4, Repentance 1.7.9b).

- Selected `PersistentGameData`: manager global at image `+0xac2428`, object `+0x204d0`; collection flags `+0xa68` (733 bytes), read-only guard `+1`, filename string `+0x10`. The collection menu and loader independently confirm this layout.
- Read-only `ItemPool::GetPillEffect`: image `+0x879bf0`, ABI `(ItemPool *, uint32_t color, Entity_Player *) -> int32_t`. This is not the mutating pill randomizer at `+0x87b4a0`.
- Read-only `Entity_Player::HasCollectible`: image `+0x4eeb74`. PHD/False PHD/Virgo/Lucky Foot flags are queried at the same main-thread boundary as the effect, carried with the identity, and override any older background ownership snapshot. A verified zero clears synergies; unavailable state does not reuse a previous reward.
- Collection reads and entity discovery stay off the main thread. The small native pill query runs only on the main thread, after revalidating the current player vector and its RTTI. No hooks, executable-memory writes, or jailbreak APIs are required.
- Host tests cover invalid collection flags, masking, all 20 language fallbacks, False PHD reward classification, horse/Experimental pills, and co-op isolation. Full `make test dylib audit EXTRA_CFLAGS='-Wall -Wextra -Werror'` must pass before installation.
