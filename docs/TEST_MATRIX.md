# Test matrix

## v0.10.1 release validation (2026-10-16)

| Area | Result |
| --- | --- |
| Pause-inventory background | User confirmed working after installation on the development iPhone |
| Content-sized description background | User confirmed working; host policy tests cover short/long content, counter space and screen-width limits |
| D Infinity pause browser | User confirmed working; host tests cover all ten standard-Repentance dice, overview wrap and invalid selection handling |
| Saved gameplay background preferences | Temporary pause policy does not write settings; tests cover disabled backgrounds, minimum pause opacity and configured gameplay opacity |
| Strict ARM64 build and package checks | Passed locally for standalone, rootless, LiveContainer and embedded formats before publication |
| Existing Glitched Crown | Native cycle policy tests retained; shared counter control supports the separate pedestal and inventory contexts |
| Every loading mode, language and visibility setting | Not exhaustively replayed on device; the full acceptance checklist is in [pause-description checks](testing-pause-descriptions.md) |

## v0.9.0 release validation (2026-10-16)

| Area | Result |
| --- | --- |
| Strict ARM64 build and public-library audit | Pass locally; no jailbreak runtime dependency |
| Host regression suite | Pass: 20-language advanced/contextual descriptions, pickup/native policies, importer, artwork bounds, startup readiness, and scripts |
| Spindown availability and presentation | Native availability adapter verified; user screenshot confirms the restored arrow-connected chain; unavailable candidates stay hidden |
| Inline item artwork | User confirmed corrected size after transparent-padding crop |
| LiveContainer cold-launch joystick | User confirmed fixed on the affected device after native-frame readiness gating |
| Collection reminder and current-Luck presentation | User screenshots show Twisted Pair's collection reminder and Lodestone's 33.3% line at 3 Luck |
| Void / Black Rune presentation | User screenshot shows separate predictions; exhaustive predicted-versus-actual absorption checks remain pending |
| Flip | Included and host-tested; gameplay verification pending |
| Four new README/website screenshots | Full-resolution supplied PNGs, explanatory captions, and local reference checks |
| Tainted characters, co-op, all loading modes | Previous outstanding checks below still apply; no claim of exhaustive device coverage |

## v0.8.0 release validation (2026-10-14)

| Area | Result |
| --- | --- |
| Strict ARM64 build (`-Wall -Wextra -Werror`) | Pass locally |
| C++ pickup/native-context policy tests | Pass: flight/knowledge rules, smelted-vector validation, effective passive Belial ownership |
| Objective-C contextual-description tests | Pass: character/mode/weapon rules, Car Battery/Tarot Cloth, predictions, wisp data, salvage conditions, personal co-op ownership, and uncapped pill transformations |
| Importer tests | Pass: 24 description/context tests and 2 icon-import tests |
| Bundled data tests | Pass: 6 tests; 20 languages, 335 weapon rules, 165 wisp records |
| Overlay architecture / script syntax | Pass locally |
| Rootless, LiveContainer, embedded, standalone packaging | Pass locally; LiveContainer archive/resources verified |
| Standalone dylib public-library dependency and ad-hoc signature audits | Pass locally; LiveContainer/embedded apps still require host-side signing |
| Native startup/resource/context reads on the development phone | Pass |
| Latest Judas + Birthright / Guppy's Paw regression | User confirmed corrected tooltip after native virtual-ownership fix |
| Tainted Cain and Tainted Lilith gameplay acceptance | Pending: characters are not unlocked on the test account; host coverage is not a gameplay result |
| Every new combination across all loading modes / co-op variants | Not exhaustively gameplay-tested; see [character checks and remaining scope](CHARACTER_CONTEXT_TESTING.md) |

## Established coverage and outstanding checks

The following results record earlier validation. A pass here is not a claim that
every scenario was repeated for v0.8.0 on every installation method.

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
| Unknown-pill spoiler guard | Pass: native identified byte selects real effect; otherwise only localized unidentified label and color are exposed |
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
| Original EID card/pill policy unit matrix | Pass: shop, Soul Stone, Options?, unidentified-pill and obstruction defaults |
| Native room path algorithm | Pass: exact ARM64 room fields plus four-direction `path <= 900` tests; live obstacle-room regression pending |
| Live shop/Options?/Soul Stone policy | Pending suitable in-game pickups after device deployment |
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
