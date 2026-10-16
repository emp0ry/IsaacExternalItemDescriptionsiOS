# Pause inventory descriptions and D Infinity preview

These changes are presentation-only. They do not switch D Infinity's native
mode, use active items, spend charge or edit save files.

## Readable descriptions on pause

1. Disable **Background** in EID settings, then enter a run and pause.
2. Open **EID Items** and select a short-description item such as Breakfast.
3. Its description must have a dark backdrop even though the global setting is
   off. Its opacity has a pause-inventory minimum of 72%; settings are not changed.
4. Select a long-description item. Its box should grow to the widest laid-out
   text line or title, not retain a large default width for short text.
5. Repeat at different text scales, positions and in Russian/English. The title,
   item, battery, quality and inline icons must fit without changing font size.
6. Resume gameplay: the inventory description and forced background must clear.
   Ordinary floor descriptions must again respect the saved Background toggle
   and opacity. With Background enabled, their boxes also fit their content.

## D Infinity description browser

1. In a disposable run, use `giveitem c489` or obtain D Infinity normally.
2. Pause, open **EID Items**, then select D Infinity.
3. It initially shows its own description and a trailing **0/10 ›** counter.
4. Tap anywhere on its description. Advance through **D1, D4, D6, Eternal D6,
   D7, D8, D10, D12, D20, D100**, then back to D Infinity.
5. Each page uses that die's normal translated description, item icon, quality
   and charge display. The counter stays inside the top-right of the fitted box.
6. Let the regular EID refresh run: the selected page must not reset or advance
   by itself. Reopening D Infinity from the list resets to its overview.
7. Select a different item: there must be no stale counter or clickable die
   browser. Resume: tapping a normal floor description must not cycle dice.
8. Resume and inspect the game's actual D Infinity icon/charge. Merely browsing
   these descriptions must not have changed either one.

## Existing Glitched Crown controls

Inspect an ordinary visible Crown pedestal: its original **0/5 ›** browser (or
the native expanded cycle size) must still work. Curse of the Blind must still
hide an unknown pedestal. Pause-inventory browsing must not replace or alter
the native pedestal cycle.
