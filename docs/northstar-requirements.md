# Requirements

Checked from this checkout and from the native build report for wowf 1.60.1.70862.
Nothing here was loaded in the Forever client. A mock pass is not a game result.
Guide counts are not feature functionality.

| Requirement | Status | Evidence |
|---|---|---|
| Interface 16001, Forever only | Met in the addon TOCs | Every Northstar TOC in the checkout says 16001. No retail or Classic TOC was added |
| wowf 1.60.1.70862 quest data | Partial, on the PC, not in this checkout | Native report: a data folder of 5414 quests produced Northstar_QuestDB (5176 NPCs, 1030 objects, 2768 items, 49 maps, 77605 spawn points, 37605 clusters, 5 Lua files, 0 warnings). `data/forever` is not in this checkout, so that build was not repeated here |
| Quest database in the package | Built on the PC, not in this checkout | `complete-inputs` holds that QuestDB. Nameplates need it. The arrow naming a mob is not that icon. Not loaded in game from here |
| Codex | Reached merge on the 70862 stage, then the memory measure called nil. Fixed in code, not re-run | `--no-recorded` does not read recordings. The measure now uses `/` paths and reports a missing `Codex.lua` instead of calling nil. `--root` must be the checkout that contains `addon/Northstar/Lookup/Codex.lua` |
| Item database | Met on the PC for the labeled Forever extract. Not a complete gear list | 6818 items, 180 KiB, Forever label, no Season of Discovery cutoff. Left out: 946 name, 11560 slot |
| Profession routes | Table built on the PC. Guides still need a fresh compile | Exit 0, Forever build 1.60.1.70862, no Classic Era rows. First Aid 32, Blacksmithing 442, Leatherworking 513, Alchemy 180, Herbalism 3, Cooking 130, Mining 17, Tailoring 415, Engineering 253, Enchanting 236, Fishing 3, Skinning 3. Season and retired filters still apply |
| Trainer list | Met on the PC | trainers.json and ClassTrainers.lua: 216 curated trainers, 68 guide goals, 0 recorded NPCs |
| Public 70862 CSV cache | Met on the PC, provenance is wago.tools | `stage-ee00ca356\data\sources\wago\1.60.1.70862`. The first eight profession tables, then SpellTotems 1124, SpellCastingRequirements 3299, SpellFocusObject 246, ItemXItemEffect 14561, Map 78, AreaTable 1404, DungeonEncounter 376, LFGDungeons 76, MapDifficulty 142, ContentTuning 100, Mount 144, BattlePetSpecies 122. No Era or beta cache |
| All nine classes, both factions, every race | Guides are present. Horde race folders are baked legs, not a second copy of the guides | A fresh compile writes leveling guides with a faction into `Northstar_Guides_Alliance` and `Northstar_Guides_Horde`. Tauren, Orc, Troll, and Undead (`race Undead`, folder Scourge) start guides are in the Horde part. Dwarf, Gnome, Human, Night Elf, and Skyborne folders in `stage\out\Northstar_Guides` are `Legs.lua` only, from baked legs whose hash still matched. Horde legs did not match, so those four folders were not written. The guides were not dropped. `forge guide bake` writes the missing legs after the 70862 nav pack exists. Not seen in game |
| Dun Morogh race errors | Met for the eight published mismatches | forever-db: 1599, 1715, 1688, 1689 are races 65 (Human+Gnome). 94373, 94374, 94375, 94466 are races 4 (Dwarf). The writer drops a quest the guide race cannot take. The dwarf and gnome Dun Morogh guides were regenerated from that rule. `tests/dun-morogh-races.test.js` and the writer unit test pass. A full `forge build` was not run here |
| Compact current-action bar | Met in code, not in game | Default height 108. Wide guide stays closed unless `ui.wideGuide` is on. Mock tests check the height and a saved wide window |
| Sheet matches the arrow after an accept | Met in the mock, not in game | Accept The Hunt Begins, then Kill Plainstrider for Plainstrider Meat (1/7). Arrival says Here and keeps the action |
| Welcome, About, settings, sidebar | Met in code | Those four say Northstar in text. About names Polestar as the guide credit |
| Fishing | Met as a manual tally | No cast |
| PvP | Met as battleground guides on the bar | Warsong Gulch, Arathi Basin, Alterac Valley, Darkspear Islands when loaded. No world PvP system and no companion command were added |
| Cozy Sleeping Bag | Met as its own guide | `forever/miscellaneous/cozy-sleeping-bag`. Not play-tested on Forever |
| Saved variables and commands | Met | `NorthstarDB`, `NorthstarCharDB`, `/northstar`, `/ns`. Polestar is not renamed |
| Walking grid | Pack stopped on a missing hubs layer. The hubs command now has a public-data path | Checkout nav is wow_classic_beta 1.60.1.70532 and must not ship. `forge nav layers hubs` uses `npcs.json` and `map-frames.json` when the classic-db extract is absent. Roads still read the installed wowf client with `--product wowf`. Not packed here |
| Fresh `forge guide compile` | Exit 0 on the PC: 255 guides, 5766 steps, 3179 warnings | Commit a074694. The 3179 warnings are guide-text diagnostics (a quest accepted and not turned in later, a `craft` before its `learn`, a place name the AreaTable does not have). They are not syntax errors. The summary lines beside them are separate |

## Compile summary, not warnings

The compile's own summary, read against this checkout's counters:

| Summary line | What it is | What to do |
|---|---|---|
| areas: 663 of 2020 place goals | A `goto`, `fly`, `getfp`, `sethome`, `hearth`, or `enter` whose text matched an AreaTable name. The other 1357 texts are not area names (a cave, a quest, a direction). The arrow still has the goal's coordinates | No mass edit. A goal whose text is a real subzone and got no area is a name mismatch to check one by one |
| nodes: none | `travel.json` is not in the 70862 data folder, so no `getfp` received a taxi node id | After the public CSVs `TaxiNodes`, `TaxiPath`, `TaxiPathNode`, and `AreaTrigger` are saved under `wago\1.60.1.70862` from `https://wago.tools/db2/<Table>/csv?build=1.60.1.70862`: `forge data travel --data STAGE\data\forever --sources STAGE\data\sources --build 1.60.1.70862 --forever-build 1.60.1.70862 --grid none --recordings STAGE\empty-recordings` then compile again. `--recordings` must be an empty directory. This does not read the open game |
| heights: none | `spawnz.json` is absent. It is the classic-db spawn extract. The 70862 data build did not have that extract, so NPC and object goals have a map point and no `z` | Do not invent heights. A later classic-db extract is the only source. The arrow uses x,y without z |

Codex exit 0: 19984 items, 139 mounts, 97 pets, 2593 recipes, 35 tabards, 9676 NPCs, 404 rares, 5414 quests, 60 zones, 35 instances, 60 treasures, 1300 objects, 28 files, 6696 KiB, 62.8% item-source coverage. Optional Era `Item.csv` was not in the cache, so Era-only items were not filled. Two reputation-gate sources were not fetched. 47 Lua files passed `loadfile`. That coverage figure is items with a known source, not every item in the game.

Hubs were generated for build 1.60.1.70862 from the public NPC fallback. Roads and `forge nav pack` wait until the game process is closed. Nothing here closes it.

## Feature limits

| Feature | What works | What it is not |
|---|---|---|
| Compact bar | Default 108px route bar. Wide guide stays closed unless `ui.wideGuide` is on. Headline follows the arrow, including after an accept, in the mock | Not seen in the Forever client |
| Class quests | The bar lists compiled class guides whose class, race, and faction fit. All nine classes have compiled guides | Not a claim every class has a full Forever chain |
| Professions | `professions.json` on the stage has the twelve categories and the counts above. Compiled guides have train, buy, and collect steps. The bar shows a skill number only when the client names that profession | Season and retired recipes are filtered. The bar does not cast or craft |
| Fishing | One profession row and a manual tally. The profession table has 3 fishing entries | No cast |
| PvP | The bar lists compiled battleground reputation guides (Warsong Gulch, Arathi Basin, Alterac Valley, Darkspear Islands) and Mounts · PvP. Release in a battleground stays off until the player turns it on | No world PvP guide and no companion command |
| Cozy Sleeping Bag | Its own guide, separate from the leveling route | The guide file says it has not been play-tested on Forever |

## Native commands

Professions, ItemDB, and trainers already succeeded on `F:\wowaddons\Northstar-build\stage-ee00ca356`. Do not repeat them. Rerun the three that stopped, from a checkout of this commit. `STAGE` is that stage. `<checkout>` contains `addon\Northstar\Lookup\Codex.lua` and `guides\`. Do not pass `--recordings` or `--leffe`.

```
forge guide compile --data STAGE\data\forever --root <checkout>
forge data codex --root <checkout> --data STAGE\data\forever --sources STAGE\data\sources --build 1.60.1.70862 --no-recorded --out STAGE\codex --pack STAGE\Northstar_Codex
forge nav layers hubs --dir <grid whose index.json build is 1.60.1.70862 and product wowf> --root STAGE --layers STAGE\data\local\nav-layers
forge nav layers roads --wow <wowf install> --product wowf --offline --root STAGE --layers STAGE\data\local\nav-layers
forge nav pack --root STAGE --dir <that grid> --layers STAGE\data\local\nav-layers --out STAGE\Northstar_Nav --date <YYYY-MM-DD>
forge nav check --out STAGE\Northstar_Nav --root STAGE
```

`forge guide compile` reads translation files in batches of 40. Each batch may run 120 seconds. Codex `--root` is the checkout. Hubs use `npcs.json` and `map-frames.json` when the classic-db extract is absent. Roads read the installed wowf client's ADT files. `--product wowf` does not launch the game and does not read a beta cache.
