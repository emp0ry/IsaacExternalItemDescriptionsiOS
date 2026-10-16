# Isaac External Item Descriptions iOS v0.10.1

This update makes pause-inventory descriptions easier to read and adds a
read-only D Infinity description browser.

## Readable descriptions while paused

- Selecting an item in **EID Items** always shows a dark background over the
  light pause menu, even when the normal Background setting is off.
- The pause-inventory background has a minimum opacity of **72%**. A more opaque
  saved value is preserved; no saved toggle or opacity is overwritten.
- Resuming clears the inventory selection and restores the normal gameplay
  background preference.

## Background width follows the content

- Description boxes fit the actual title and widest laid-out body line instead
  of keeping a long default width for short descriptions.
- Item artwork, battery/charge and quality symbols, inline icons and the preview
  counter are included in the layout.
- Long descriptions still wrap within the available screen width. The change
  does not reduce the text's font size.
- Background bounds are updated after the final header layout, including when
  the title is hidden or the overlay host is reattached.

## D Infinity: inspect every die

Select D Infinity in **EID Items**, then tap its description to advance through:

**D Infinity overview → D1 → D4 → D6 → Eternal D6 → D7 → D8 → D10 → D12 → D20
→ D100 → overview.**

- The counter appears inside the description's top-right corner as **0/10 ›**.
- Every die has its own translated description, icon, quality and charge display.
- Periodic EID refreshes keep the selected page. Choosing the item again resets
  to its overview; selecting another item or resuming clears the browser.
- This is **description browsing only**. It does not switch the game's actual
  D Infinity mode, invoke its effect, spend charge or edit saves.
- Glitched Crown keeps its existing separate pedestal-cycle browser.

## Downloads

| Setup | File |
| --- | --- |
| Rootless jailbreak / ElleKit | `IsaacExternalItemDescriptions-rootless.deb` |
| LiveContainer private app | `IsaacExternalItemDescriptions-LiveContainer.framework.zip` |
| Direct embedding | `IsaacExternalItemDescriptions-Embedded.zip` |
| Complete archive | `IsaacExternalItemDescriptions-Full-Build.zip` |
| Manual setup | `IsaacExternalItemDescriptions.dylib`, `descriptions.json` |

Description data, original EID artwork and translations remain included in the
complete packages, with attribution and the original author's permission.
`SHA256SUMS` covers the individual distribution files. Fully restart Isaac after
updating and use only one loading method per installation.

## Compatibility and verification

The target remains **native Isaac iOS 1.4 / Repentance 1.7.9b.J754**, ARM64,
with standard-Repentance data. Repentance+ is not the target of this port.

The user confirmed the three changes working on the development iPhone. Local
regression tests cover dice ordering/wrap, background policy, fitted-width bounds,
existing description/native policies, imports, package layout and documentation.
The strict ARM64 build and portable-library audit passed before publication; the
release workflow repeats them for the published packages. This is not a claim
of exhaustive device testing of every language, setting and loading mode.

The dylib still has no jailbreak-only runtime dependency. No Isaac IPA, user
saves, account credentials or purchase bypass is distributed.

[Test checklist](testing-pause-descriptions.md) ·
[Website](https://isaaceidios.emp0ry.com/) ·
[Report a problem](https://github.com/emp0ry/IsaacExternalItemDescriptionsiOS/issues)
