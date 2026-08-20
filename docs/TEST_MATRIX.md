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
| All-language upstream import | Pass: 20 EID languages; English fallback fills untranslated Repentance entries |
| Menu/game detector | Pass: native player-presence detector with 12-scan menu debounce |
| EID settings | Pass: bottom-right button is available in menus and while paused, hidden during active gameplay; native language picker, layout controls, 140/50 px defaults, credits and dataset version |
| Unknown-pill spoiler guard | Pass: native identified byte required |
| Native pill color-to-effect mapping | Pass: ARM64 ItemPool layout verified |
| Crane Game prize field | Pass: ARM64 setter/layout verified |
| Startup information banner | Removed: settings are reachable from the bottom-right button while in the menu |
| Patcher on fixture IPA | Pass |
| Patcher idempotency | Pass: one `LC_LOAD_DYLIB` |
| Patcher on full user-supplied Isaac IPA | Pass |
| Dylib hash after IPA embedding | Pass |
| Direct embedded-mode launch on device | Pending signed/direct-load regression |
| LiveContainer framework layout/archive | Pass |
| LiveContainer guest `MH_DYLIB` UUID selection | Pass: UUID `F4357753-A25F-30EE-BACF-63709F902895` selected on device |
| LiveContainer 3.8.0 private-app launch | Pass: framework loaded, full database imported, native probe active, no crash |
| Live card/rune entity detection | Pass: native variant 300 observed on device |
| Untouched-card identity guard | Pass: untouched cards stay hidden; held cards are learned from the four native player pocket slots |
| Native item artwork | Pass: exact Isaac collectible/trinket paths and subtype-aware pocket-item artwork rendered beside text |
| Native card/rune/pill artwork | Pass: subtype-aware card and rune frames plus original EID pill-atlas frames |
| Transformation progress | Pass: live persisted PlayerForm counters survived a save reload and reported Conjoined `1/3` plus Bookworm `1/3`; Super Bum uses verified familiar type/variant state |
| Pause detection | Pass: live PauseScreen state changed `0 -> 1 -> 0` on the supported device build |
| Pause inventory | Pass: top-left button rendered 3 current items and all 15 transformations; item 312 selection opened its description; inventory and settings controls hide on resume |
| Dice Room descriptions | Pass: live native face detection and localized effect description |
| Sacrifice Room descriptions | Pass: native grid-spike detection and live next-payout counter |
| Description removal transition | Pass: title, icon, and body now disappear together after collection |
| Live trinket, known pill, and Crane rendering | Pending suitable in-game room |
| Curse of the Blind live regression | Pass: native `0x40` curse mask suppresses the debug collectible pedestal on device |

The old allocator-enumeration development prototype was removed after it proved
unsafe. The current entity scanner has run without a new crash since that
replacement and the language-setter recursion fix.
