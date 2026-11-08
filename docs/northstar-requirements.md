# Requirements against this checkout

Checked from the code and the mock client. Nothing in this list was loaded
in World of Warcraft: Forever from here. A mock pass is not a game result.

| Requirement | Status | Where |
|---|---|---|
| Interface 16001, no retail or Classic TOC | Met in the addon TOCs | Code and the guide/UI zip |
| wowf 1.60.1.70862 data only, no beta grid in the test package | Met for the zip (nav packs left out). The committed walking grid is still wow_classic_beta 1.60.1.70532 and is not shipped | Package |
| Compact current action, not the tall inherited sheet | Met in code: the default bar is 108px, quest line plus Steps. Class, Trade, and PvP grow the same bar for their rows | Code. Mock test checks the height. Not seen in game |
| Old wide guide does not open by itself | Met in code: `ui.wideGuide` defaults off, and a saved `ui.journal = false` is put back on login unless `ui.wideGuide` is set | Code. Mock test. Not seen in game |
| Arrow and sheet show the same current action, including after an accept | Met in code: the sheet refreshes on step and waypoint changes and uses the arrow's line, with the log count | Mock test only. Not seen in game |
| Arrival keeps the action instead of only saying Arrived | Met in code: the distance line says Here and the action line stays | Code. Not seen in game |
| Welcome, About, settings, sidebar are not the Polestar wordmark | Met in code: those four say Northstar in text. About names Polestar as the guide credit | Code. Not seen in game |
| All twelve profession guides | Met in the compiled `Northstar_Guides` already in the checkout | Package. Not seen in game |
| Fishing is a manual tally, no cast | Met in code | Not seen in game |
| Class guides for all nine classes, filtered by race and faction | Met in the compiled packs. The bar lists a class guide only when its class, race, and faction fit the character. Atiesh is shared by Priest, Mage, Warlock, and Druid. Not a claim every class has a full Forever chain, and not seen in game | Package and the selection test |
| Horde and Alliance leveling, and every race part | Met in the compiled packs: both faction folders and Human, Night Elf, Dwarf, Gnome, Orc, Undead (Scourge legs plus `forever/horde/undead/01-tirisfal-glades`), Tauren, Troll, Skyborne | Package. Not seen in game |
| New quests for every class, race, and both factions, old quests kept | Partial. The published forever-db is build 1.60.1.70532, not 70862. The merger keeps pfQuest rows the Questie store does not have. That is not live coverage | Code and forever-db. Unverified in game |
| PvP as battleground guides, not a made-up PvP system | Met as a PvP control on the bar that lists the battleground guides already compiled. World PvP and a companion command are not invented | Code. Not seen in game |
| Cozy Sleeping Bag separate from the leveling route | Met: its own button, its own guide id | Code and package. Not seen in game |
| Northstar saved variables and commands, Polestar left alone | Met: `NorthstarDB`, `NorthstarCharDB`, `/northstar`, `/ns` | Code |
| Quest-mob nameplates | Missing from the package. They need `Northstar_QuestDB`, which is not built. The arrow naming a mob is not that icon | Code. Unverified in game |
| Codex, quest database, item database, recorder, beta nav | Missing on purpose. Login says Codex is not installed | Package |
| Dun Morogh race errors | Still open in the generated source. Dwarf steps offer warlock quests whose published races are Human and Gnome (1599, 1715, 1688, 1689). Gnome steps offer shaman quests whose published races are Dwarf (94373, 94374, 94375, 94466). Those files are generated, so they were not edited here. A fresh `forge guide compile` against a 70862 data folder still stops on them. The copies already compiled into the race packs are what the package contains | Generated guides. Not rewritten |
| Profession and trainer tables for a rebuild | Not built here. The compiled profession guides already contain train, buy, and collect steps with named trainers. Rebuilding them needs `forge data professions --data <70862 data folder> --sources <checkout>/data/sources` and `forge data trainers --data <that folder> --guides <checkout>/guides --recordings <checkout>/data/recordings`. The profession command reads cached wago tables, not the wowf client, so it was not run as a substitute for 70862 | Unchanged |
