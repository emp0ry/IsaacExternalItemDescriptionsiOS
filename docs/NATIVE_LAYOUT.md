# Supported native Isaac layout

This project supports the ARM64 Isaac executable whose `LC_UUID` is:

`F4357753-A25F-30EE-BACF-63709F902895`

Unknown executables fail closed before entity memory is scanned. Offsets must be
revalidated for every new UUID.

## Runtime types

The resolver finds C++ RTTI and primary vtables in the loaded main executable:

- `IsaacRepentance::Entity_Pickup`
- `IsaacRepentance::Entity_Player`
- `IsaacRepentance::Entity_Slot`
- `IsaacRepentance::Entity_Effect`
- `IsaacRepentance::GridEntity_Spikes`

It then takes read-only snapshots with `vm_read_overwrite`. It does not hook the
allocator and does not directly dereference mutable game allocations.

## Verified ARM64 offsets

| Field | Offset | Validation |
| --- | ---: | --- |
| Entity Type / Variant / SubType | `0x38` | Live collectible IDs matched visible pedestals |
| Entity valid / visible / exists / dead bytes | `0x1c0` | Live valid entity bytes were `1,1,1,0` |
| Entity logical position | `0x310` | Player and pedestal movement matched the screen |
| ANM2 layer-state pointer | `0x0f8` | Runtime snapshot and native spritesheet access |
| ANM2 layer count | `0x100` | Six live pedestal layers observed |
| Pickup touched byte | `0x560` | Native pickup init/collision/morph preservation code |
| Pickup forced-blind byte | `0x562` | ARM64 disassembly of native `SetForceBlind` |
| Crane Game prize collectible | `0x570` | ARM64 disassembly of `Entity_Slot::SetPrizeCollectible` |
| Player pocket items | `Entity_Player + 0x1c10` | Live held-card and rune identity matched pocket slots |
| Player collectible-count table | `Entity_Player + 0x1ab8` | Live inventory changes matched collected items |
| Game level curse mask | `Game + 0x0c` | Live Curse of the Blind state matched mask `0x40` |
| Game current room | `Game + 0x21550` | Live room transitions matched room descriptor state |
| Game run seed | `Game + 0x25d44` | Stable within a run and changed when starting a new run |
| Room grid-entity table | `Room + 0x30` | Live Sacrifice Room spikes and activation count |
| Game ItemPool | `Game + 0x242c0` | Native `GetPillEffect` call sites |
| ItemPool pill effect array | `ItemPool + 0xa2c` | ARM64 `GetPillEffect` implementation |
| ItemPool identified-pill bytes | `ItemPool + 0xa68` | Native identification code and state copy |

The iOS `LayerState` stride is `0x90`; its libc++ spritesheet path starts at
`+0x08`. A collectible is hidden if the forced-blind byte is set or layer 1 is
using `gfx/Items/Collectibles/questionmark.png`. An unreadable blind-state
structure fails closed and produces no description.

The current level curse mask is also read from `Game + 0x0c`. Bit `0x40`
identifies Curse of the Blind and suppresses all collectible descriptions,
including pedestals whose sprite-layer state has not caught up yet.

## Supported pickup identities

- Variant `100`: collectibles
- Variant `300`: cards and runes
- Variant `350`: trinkets (including the golden-trinket high flag)
- Variant `70`: pills, only after native identification; effect IDs are resolved
- Type `6`, variant `16`: Crane Game prize collectible
- Type `1000`, variant `76`: Dice Room floor effect; subtype `0...5` maps to faces `1...6`
- Room type `13`, grid type `8`: Sacrifice Room spikes; `VarData + 1` is the next payout

Normal descriptions use the resolved effect plus one, matching upstream EID's
lookup convention. Bit 11 selects the horse-pill table. Golden color 14 uses
the upstream random-effect Golden Pill entry. Unknown pills fail closed.
Cards are revealed by a nonzero native touched flag or by reading the four native
player pocket slots at `Entity_Player + 0x1c10`. Each slot is an 8-byte
`{ id, type }` record; `type == 1` identifies a card/rune. The pocket path handles
iOS drops that create a new entity with `Touched` cleared. This learned identity
lasts only for the current run. A newly discovered floor card is therefore
still hidden until it is actually held by a player.

Transformation progress comes from the player's native collectible-count
table. Active collectibles are remembered after replacement for the duration
of the run, matching the way transformation contribution persists. A native
run seed plus a debounced empty-player state resets this history when a new run
starts.
