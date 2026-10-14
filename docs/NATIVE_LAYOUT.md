# Supported native Isaac layout

This project supports the ARM64 Isaac executable whose `LC_UUID` is:

`F4357753-A25F-30EE-BACF-63709F902895`

Unknown executables fail closed before entity memory is scanned. Offsets must be
revalidated for every new UUID.

## Read-only dynamic description fields

All fields below are for the UUID above, and are bounds/type checked before use:

| Field | Offset | Native reference |
| --- | --- | --- |
| Pandora reward stage | `Game + 0x0` | Pandora branch `0x10058b438`; stage tables `0x10058bb50`, `0x10058dcf8` |
| Pandora late-game route | `Game + 0x4` | Cathedral/Chest branches `0x100590928`, `0x100590358` |
| Move speed | `Player + 0x194c` (float) | Consolation Prize stat comparison `0x100502140` |
| Max fire delay | `Player + 0x1834` (float) | `0x10050214c` |
| Damage | `Player + 0x1844` (float) | `0x100502158` |
| Tear range | `Player + 0x1854` (float) | `0x100502164` |
| Coins / bombs / keys | `Player + 0x16e0 / 0x16dc / 0x16d4` (int32) | Native weighted comparison `0x1005035d8` onwards |
| Bethany soul / blood charges | `Player + 0x2478 / 0x247c` (int32) | Character branches `0x100503610`, `0x100503640` |
| Smelted trinket vector | `Player + 0x1b60` (begin/end/capacity pointers) | Native indexed count access `0x100509680`, `0x1005096d4` |
| Challenge ID | `Game + 0x1cf438` (int32) | Tainted Cain pickup guard `0x100720a68`; Cantripped is 43 |
| Current room index | `Game + 0x21558` (int32) | Tainted Cain pickup guard `0x100720a90`; native excluded index is -12 |
| Current dimension | `Game + 0x21560` (int32) | Tainted Cain pickup guard `0x100720a84`; Death Certificate is dimension 2 |
| Room-type pool maps | `ItemPool + 0x920` normal / `+0x998` Greed (int32 arrays) | `GetPoolForRoom` at `0x100877a3c`, indexed by room type |
| Non-quest-item suppression | `Player + 0x284c` (byte) | `HasCollectible` guard `0x1004eebe0`; checked before reporting effective Belial |

`HasCollectible(59)` at `0x1004eed80` returns true for Judas/Black Judas (types
3/12) with Birthright (619), independently of a raw inventory count of 59.
The presentation snapshot reproduces this branch read-only, including the
suppression guard. The raw inventory and game state are not modified.

The pool mapper's Error Room (type 3) branch performs a random room-type choice.
That branch is not executed or simulated: Error Rooms get no guaranteed-room
pickup claim. The challenge/dimension/index offsets above are statically verified
against the supported executable; gameplay acceptance testing is recorded separately.

Each smelted slot is four bytes: regular and golden signed int16 counts.
Vector bounds, four-byte stride, counts, and the supported trinket-ID range
are checked; malformed snapshots cannot become inventory identities.
The vector validation/decoding policy is also exercised by host tests.

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
| Pickup auto-update-price byte | `0x560` | Native shop-price update code |
| Pickup touched byte | `0x561` | Native pickup init/collision/morph preservation code |
| Pickup forced-blind byte | `0x562` | ARM64 disassembly of native `SetForceBlind` |
| Pickup price | `0x564` | Native `IsShopItem` returns `Price != 0` |
| Pickup Options index | `0x56c` | Live shop and floor pickup instances; positive values identify an `Options?` group |
| Crane Game prize collectible | `0x570` | ARM64 disassembly of `Entity_Slot::SetPrizeCollectible` |
| Player can-fly byte | `Entity_Player + 0x1954` | Live flight state and repeated native `ldrb` call sites in movement/collision paths; must be read as one byte rather than as the adjacent four-byte word |
| Player character type | `Entity_Player + 0x1738` | Repentance ChangePlayerType/character-specific branches read this int32; valid native types are 0–40 |
| Game difficulty | `Game + 0x24f9d8` | Native IsGreedMode at `0x10088c994` reads `(difficulty & ~1) == 2`: normal 0, hard 1, Greed 2, Greedier 3 |
| Player pocket items | `Entity_Player + 0x1c10` | Live held-card and rune identity matched pocket slots |
| Player trinket slots | `Entity_Player + 0x1ab0` | Native GetTrinket call sites and both live slots |
| Player collectible-count table | `Entity_Player + 0x1ab8` | Live inventory changes matched collected items |
| Player transformation counters | `Entity_Player + 0x1c54` | Native 15-entry add/remove, save, and restore loops |
| Game level curse mask | `Game + 0x0c` | Live Curse of the Blind state matched mask `0x40` |
| Game current room | `Game + 0x21550` | Live room transitions matched room descriptor state |
| Game run seed | `Game + 0x25d44` | Stable within a run and changed when starting a new run |
| Game pause-menu state | `Game + 0x10dfd8` | PauseScreen state switch; valid values are `0...3` |
| Room grid-entity table | `Room + 0x30` | Live Sacrifice Room spikes and activation count |
| Room grid width / height | `Room + 0x14` / `+0x18` | Native grid-index conversion and bounds checks |
| Room grid-path table | `Room + 0xe98` | Native `GetGridCollision` and path update code |
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
- Variant `70`: pills; identified colors resolve to effect IDs
- Internal variant `2070`: unidentified pills; native color is retained for artwork without exposing the effect
- Type `6`, variant `16`: Crane Game prize collectible
- Type `1000`, variant `76`: Dice Room floor effect; subtype `0...5` maps to faces `1...6`
- Room type `13`, grid type `8`: Sacrifice Room spikes; `VarData + 1` is the next payout

Normal pill descriptions use the resolved effect plus one, matching upstream
EID's lookup convention. Bit 11 selects the horse-pill table. Golden color 14
uses the upstream random-effect Golden Pill entry. Unknown pills preserve only
their color and render the upstream localized unidentified label.

Floor card/rune/pill visibility mirrors original EID's defaults. The native
price at `Entity_Pickup + 0x564` marks a shop pickup when nonzero, and the
`OptionsPickupIndex` at `+0x56c` marks an `Options?` choice when positive.
Ordinary shop cards and all `Options?` cards are hidden; shop Soul Stones and
shop/`Options?` pills are shown. Reachability uses the native room dimensions
and `Room::_gridPaths`, with the same four-direction search and `path <= 900`
rule as upstream EID. The verified native `CanFly` word bypasses obstruction.
`Pickup::Touched` is deliberately not used as a general card-knowledge flag.

The native `Entity_Player::_playerForms` array has 15 persisted `int32`
counters starting at `+0x1c54`. Isaac copies the complete 60-byte array into
and out of its player save state. EID transformation IDs are mapped to the
native PlayerForm order rather than treated as the same enum:

| EID | Native | Form |
| ---: | ---: | --- |
| 1 | 0 | Guppy |
| 2 | 2 | Fun Guy |
| 3 | 1 | Lord of the Flies |
| 4 | 7 | Conjoined |
| 5 | 5 | Spun |
| 6 | 6 | Yes Mother? |
| 7 | 9 | Oh Crap |
| 8 | 4 | Bob |
| 9 | 8 | Leviathan |
| 10 | 3 | Seraphim |
| 12 | 10 | Bookworm |
| 13 | 12 | Spider Baby |
| 14 | 11 | Adult |
| 15 | 13 | Stompy |

Super Bum is a familiar merge rather than a native PlayerForm. Its partial
progress uses the three source collectible identities, and completion is
verified from the live `Entity_Familiar` type `3`, variant `102`, so the display
remains `3/3` after the source familiars merge. In co-op, each player has an
independent counter array; the overlay displays the highest valid per-player
counter instead of incorrectly summing two players.

The pause browser reads PauseScreen state `1...3` as paused and `0` as live
gameplay. The inventory and settings buttons are enabled only for a verified
paused state; an invalid read fails closed and leaves both controls hidden.
