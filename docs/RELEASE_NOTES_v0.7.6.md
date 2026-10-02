# Isaac External Item Descriptions iOS v0.7.6

This maintenance release fixes pickup reachability detection for flying players.

## Changes

- Shows descriptions for obstructed cards, runes, and pills when the player can fly.
- Reads Isaac's native flight state as the one-byte C++ boolean used by the game's movement and collision code.
- Keeps unreachable pickup descriptions hidden for players without flight.
- Adds regression coverage for valid and invalid native flight-state values.

## Compatibility

- Supports the verified Isaac iOS executable UUID `F4357753-A25F-30EE-BACF-63709F902895`.
- The standalone dylib remains independent of jailbreak-only runtimes.
- Includes rootless, standalone dylib, LiveContainer, and embedded distributions.
- No Isaac IPA or copyrighted game bundle is included.
