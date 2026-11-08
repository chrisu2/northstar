# Requirements

Checked from this checkout and from the native build report for wowf 1.60.1.70862.
Nothing here was loaded in the Forever client. A mock pass is not a game result.
Guide counts are not feature functionality.

| Requirement | Status | Evidence |
|---|---|---|
| Interface 16001, Forever only | Met in the addon TOCs | Every Northstar TOC in the checkout says 16001. No retail or Classic TOC was added |
| wowf 1.60.1.70862 quest data | Partial, on the PC, not in this checkout | Native report: a data folder of 5414 quests produced Northstar_QuestDB (5176 NPCs, 1030 objects, 2768 items, 49 maps, 77605 spawn points, 37605 clusters, 5 Lua files, 0 warnings). `data/forever` is not in this checkout, so that build was not repeated here |
| Quest database in the package | Built on the PC, not in this checkout | `complete-inputs` holds that QuestDB. Nameplates need it. The arrow naming a mob is not that icon. Not loaded in game from here |
| Codex | Command is specified, not run here | `forge data codex` with `--no-recorded` does not read `data/codex/recorded.json` and does not take `--recordings`. It still reads the checkout's attunement and journal tables. A missing Era `1.15.9.70003` cache warns and does not fill items |
| Item database | Partial. The previous PC run is not a Forever gear list | That run printed "from Classic Era build 1.60.1.70862" and left out 886 name, 2168 season, 11560 slot, keeping 4710 items. The season cutoff is Season of Discovery (id 190000) and was applied to a Forever build. The code now labels a 1.60 build as Forever and does not apply that cutoff. Name and slot filters still run. Not re-run on the 70862 CSVs here |
| Profession routes | Compiled routes are in the checkout. A fresh profession table was blocked and is now unblocked in code | The compiled guides contain train, buy, and collect steps. `forge data professions --build 1.60.1.70862` then failed looking for a `wow_classic_era` cache after the 70862 tables had already loaded. That lookup was SpellTotems, SpellCastingRequirements, SpellFocusObject, and the unconditional Era row fill. A missing gap table is now empty, with the public URL `https://wago.tools/db2/<Table>/csv?build=1.60.1.70862`. No Era cache is required. Not re-run on the PC cache here |
| Trainer list | Met on the PC | trainers.json and ClassTrainers.lua: 216 curated trainers, 68 guide goals, 0 recorded NPCs |
| Public 70862 CSV cache | Met on the PC, provenance is wago.tools | `Northstar-build\sources\wago\1.60.1.70862`. SkillLine 154, SkillLineAbility 7853, SpellName 32482, SpellEffect 43506, SpellReagents 3319, ItemSparse 19324, Item 32007, ItemEffect 12693. Not a client extract |
| All nine classes, both factions, every race part | Met as compiled guides and as the sheet filter | Selection test reads the compiled Lua. A class guide is listed only when class, race, and faction fit. Not seen in game |
| Dun Morogh race errors | Met for the eight published mismatches | forever-db: 1599, 1715, 1688, 1689 are races 65 (Human+Gnome). 94373, 94374, 94375, 94466 are races 4 (Dwarf). The writer drops a quest the guide race cannot take. The dwarf and gnome Dun Morogh guides were regenerated from that rule. `tests/dun-morogh-races.test.js` and the writer unit test pass. A full `forge build` was not run here |
| Compact current-action bar | Met in code, not in game | Default height 108. Wide guide stays closed unless `ui.wideGuide` is on. Mock tests check the height and a saved wide window |
| Sheet matches the arrow after an accept | Met in the mock, not in game | Accept The Hunt Begins, then Kill Plainstrider for Plainstrider Meat (1/7). Arrival says Here and keeps the action |
| Welcome, About, settings, sidebar | Met in code | Those four say Northstar in text. About names Polestar as the guide credit |
| Fishing | Met as a manual tally | No cast |
| PvP | Met as battleground guides on the bar | Warsong Gulch, Arathi Basin, Alterac Valley, Darkspear Islands when loaded. No world PvP system and no companion command were added |
| Cozy Sleeping Bag | Met as its own guide | `forever/miscellaneous/cozy-sleeping-bag`. Not play-tested on Forever |
| Saved variables and commands | Met | `NorthstarDB`, `NorthstarCharDB`, `/northstar`, `/ns`. Polestar is not renamed |
| Walking grid | Missing from this checkout on purpose | The copy in git is wow_classic_beta 1.60.1.70532. Do not pack it. Pack the existing wowf 1.60.1.70862 grid. Not packed here |
| Fresh `forge guide compile` of every guide | Not run here | It needs the 70862 data folder and professions.json. The earlier PC compile exited 1 with 301 errors, including these eight race errors and the missing profession tables |

## Native commands

Run these from a checkout of this commit. Do not point them at private recordings, and do not read the live client. `DATA` is the folder that already wrote the 5414 quests. `SRC` is `F:\wowaddons\Northstar-build\sources`. `STAGE` is a directory whose `data\forever` is `DATA` and whose `data\sources` is `SRC`. `OUT` is `F:\wowaddons\Northstar-build\complete-inputs`.

If a profession warning names a missing table, save that public CSV at `SRC\wago\1.60.1.70862\<Table>.csv`. The URL is `https://wago.tools/db2/<Table>/csv?build=1.60.1.70862`. The four the 70862 cache may still lack are SpellTotems, SpellCastingRequirements, SpellFocusObject, and ItemXItemEffect.

```
forge data professions --data DATA --sources SRC --build 1.60.1.70862 --out DATA\professions.json
forge data itemdb --offline --build 1.60.1.70862 --sources SRC --root STAGE --out OUT\Northstar_ItemDB
forge data codex --root STAGE --data DATA --sources SRC --build 1.60.1.70862 --no-recorded --out OUT\codex --pack OUT\Northstar_Codex
```

Codex still needs the checkout's `data\codex\attunements.json` and `journal-quests.json` under `STAGE`. It must not be given `--recordings` or `--local-extras`.

Trainers already succeeded. Repeating it without private sessions:

```
forge data trainers --data DATA --guides <checkout>\guides --recordings <an empty directory> --out DATA\trainers.json --lua OUT\ClassTrainers.lua
```

Grid. Read the grid's `index.json` first. `build` must be `1.60.1.70862` and `product` must be `wowf`. Then:

```
forge nav pack --root STAGE --dir <that grid> --layers <its nav-layers, if present> --out OUT\Northstar_Nav --date <YYYY-MM-DD>
forge nav check --out OUT\Northstar_Nav --root STAGE
```

Do not pass `--leffe`. Do not use `addon\Northstar_Nav` from the checkout. `PACK.json` in the output records the grid product and build. QuestDB is already in `complete-inputs` and does not need another run.
