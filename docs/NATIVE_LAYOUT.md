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
| Pickup forced-blind byte | `0x562` | ARM64 disassembly of native `SetForceBlind` |
| Crane Game prize collectible | `0x570` | ARM64 disassembly of `Entity_Slot::SetPrizeCollectible` |
| Game ItemPool | `Game + 0x242c0` | Native `GetPillEffect` call sites |
| ItemPool pill effect array | `ItemPool + 0xa2c` | ARM64 `GetPillEffect` implementation |
| ItemPool identified-pill bytes | `ItemPool + 0xa68` | Native identification code and state copy |

The iOS `LayerState` stride is `0x90`; its libc++ spritesheet path starts at
`+0x08`. A collectible is hidden if the forced-blind byte is set or layer 1 is
using `gfx/Items/Collectibles/questionmark.png`. An unreadable blind-state
structure fails closed and produces no description.

## Supported pickup identities

- Variant `100`: collectibles
- Variant `300`: cards and runes
- Variant `350`: trinkets (including the golden-trinket high flag)
- Variant `70`: pills, only after native identification; effect IDs are resolved
- Type `6`, variant `16`: Crane Game prize collectible

Normal descriptions use the resolved effect plus one, matching upstream EID's
lookup convention. Bit 11 selects the horse-pill table. Golden color 14 uses
the upstream random-effect Golden Pill entry. Unknown pills fail closed.
