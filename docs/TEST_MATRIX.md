# Test matrix

| Area | Result |
| --- | --- |
| ARM64 iOS dylib build | Pass |
| Public-system-library dependency audit | Pass |
| Jailbreak-only symbol audit | Pass |
| Rootless ElleKit package build/install | Pass |
| Constructor bootstrap in real Isaac process | Pass |
| Entity RTTI/vtable resolution | Pass |
| Fixed entity-pool snapshot discovery | Pass |
| Nearest-pedestal switching while moving | Pass |
| English/Russian collectible import | Pass: 732 / 732 each |
| English/Russian trinket import | Pass: 189 / 189 each |
| English/Russian card/rune import | Pass: 97 / 97 each |
| English/Russian pill import | Pass: 51 normal + 51 horse each |
| Unknown-pill spoiler guard | Pass: native identified byte required |
| Native pill color-to-effect mapping | Pass: ARM64 ItemPool layout verified |
| Crane Game prize field | Pass: ARM64 setter/layout verified |
| Startup-only EN/RU selector | Pass: repeated on-device launch and selection |
| Patcher on fixture IPA | Pass |
| Patcher idempotency | Pass: one `LC_LOAD_DYLIB` |
| Patcher on full user-supplied Isaac IPA | Pass |
| Dylib hash after IPA embedding | Pass |
| Direct embedded-mode launch on device | Pending signed/direct-load regression |
| Live card/rune entity detection | Pass: native variant 300 observed on device |
| Untouched-card identity guard | Pass: untouched cards stay hidden; held cards are learned from the four native player pocket slots |
| Native item artwork | Pass: exact Isaac collectible/trinket paths, card-atlas crops, card fallback, and one static native white pill icon rendered beside text |
| Live trinket, known pill, and Crane rendering | Pending suitable in-game room |
| Curse of the Blind live regression | Pending suitable seeded floor |

The old allocator-enumeration development prototype was removed after it proved
unsafe. The current entity scanner has run without a new crash since that
replacement and the language-setter recursion fix.
