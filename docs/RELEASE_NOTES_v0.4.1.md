# Isaac External Item Descriptions iOS v0.4.1

This release improves pocket-item artwork parity and transformation tracking.

## Changes

- Fixed card artwork to follow Isaac's actual `ui_cardspills.anm2` CardFronts frame mapping.
- Fixed rune artwork to use the same subtype-aware CardFronts animation mapping as cards.
- Fixed pill artwork by using original EID's explicit 14-frame `Pills` animation instead of guessing PNG grid positions.
- Fixed transformation progress leaking into a new run by adding a native run/player identity reset signal in addition to the existing gameplay/menu reset.
- Kept full downloadable release packaging for rootless jailbreak, LiveContainer, embedded builds, descriptions, and checksums.

## Known issue

- Curse of the Blind item descriptions may still appear in some cases.
