# Wild Card and Vurp!: native-history previews

Restart Isaac after installing the updated dylib. Use a disposable run: console
commands and using these effects change gameplay. EID itself only reads state.
The existing Abyss, Spindown, icon sizing and native-frame readiness changes remain.

## Wild Card

1. `giveitem c34`: The Book of Belial. Use the active item normally, not through
   a console effect invocation (which may intentionally omit owned-use flags).
2. `spawncard 80`: Wild Card. Its final line should show The Book of Belial with
   its icon. In a fresh run before any eligible use, no extra line is expected.
3. Leave Wild Card on the floor. `spawncard 19`: The Sun. Pick up and use The Sun.
   Approach Wild Card again: the final line should now show The Sun and its icon.
4. Merely picking up, dropping or swapping a different card must not change that
   line. Using Wild Card must not replace the preview with Wild Card itself.
5. Use an ordinary pill, then inspect Wild Card: its effect name and original
   pill color should be shown. Horse pills retain their horse identity.
6. Save and Exit, restart, Continue: the same unused floor Wild Card should still
   show the saved effect. Start a genuinely new run: old history must not leak.

The game owns the special handling for `? Card`, Blank Card, Placebo, Clear Rune
and Glowing Hourglass. Test these by comparing the preview with the actual result,
not by assuming the last pocket item must always be the repeat target.

## Vurp!

1. `giveitem c75`: PHD identifies the current run's pill colors.
2. `spawnpill effect 46`: Vurp! (native zero-based effect ID). The run must have
   assigned Vurp! to a color. If the console reports no color, use another
   disposable run; this command deliberately does not rewrite the pill pool.
3. Leave Vurp! on the floor. Spawn a different pill (`spawnpill 1` through
   `spawnpill 13`), check its effect with EID, pick it up and use it.
4. Approach Vurp!: the final line should show the pill it will create, with its
   real color. Use Vurp! and compare the spawned pill with the preview.
5. Test `spawnpill effect 46 horse`: the resulting pill must be horse-sized.
   A previously used horse pill remains horse-sized even with normal Vurp!.
6. With no previous non-golden pill use, Vurp! produces itself. Golden pills
   must not replace the previous non-golden pill. Repeated Vurp! uses follow the
   game's retained color, not an invented history of dropped pills.
7. Save/Continue and a new run should respectively preserve and reset history.
   Removing PHD/False PHD should retain only the knowledge allowed by native
   ItemPool state; unknown pills must not expose a Vurp! preview.

## Implementation and verification

Primary behavior reference: the pinned original EID commit
`8b59d00c6828e333294639ad2b2b6875eae821cb`, `features/eid_modifiers.lua`
(`WildCardCallback`, `VurpCallback`) and `features/eid_api.lua` history helpers.

Supported executable UUID: `F4357753-A25F-30EE-BACF-63709F902895`.

- Native `UseCard(80)` reads player `+0x2834` type, `+0x2838` ID, `+0x283c`
  extra: pill effect/color, card ID, or active collectible ID/variable data.
  `0xff` is the empty tag. The PlayerData serializer stores the same tuple at
  `+0x6b8..+0x6c0`; no mod-owned persistent history is needed.
- Native `UsePill(46)` at `0x10053dec4` reads the last raw non-golden pill color
  at player `+0x1b40`, falls back to the current pill, and ORs its horse bit.
  The normal-pill completion path at `0x10053e69c` skips gold. PlayerData `+0x40`
  saves/restores the field (`0x100550104`, `0x100525db4`).
- Wild Card shows the native recorded concrete effect. Vurp! shows what the
  resulting color currently means for that player via read-only `GetPillEffect`.
  This intentionally follows native horse-bit behavior and Vurp!'s retained
  color, even where upstream's Lua event-history approximation differs.
- UUID gating, RTTI-validated current players, range checks, and main-thread-only
  native getters remain mandatory. No use-effect call, hook, save write or RNG
  advance is performed. Missing/invalid state leaves the base description alone.
- Host tests cover all 20 languages, concrete active/card/pill names and icons,
  empty/invalid state, unknown-pill protection, normal/horse propagation and
  separate co-op records. Native installation is not a gameplay acceptance test;
  the user confirmed the installed Wild Card / Vurp! update works before the
  subsequent The Stars? / Black Feather request. This does not establish that
  every co-op or special-effect combination in the checklist was exercised.
