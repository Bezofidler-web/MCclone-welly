# mcl_villages:

A fork of Rochambeau's "Settlements" mod converted for use in Mineclonia.

## Using the mod:

This mod adds settlements on world generation.

And, in Creative Mode; also comes with a debug tool for spawning in villages.

## Settlements

New terrain can generate villages, towns and cities on the village placement
grid. Each tier has plains, desert, savanna, snowy plains and taiga styles.
Towns are less common than villages. Cities are rarer and need room for their
main roads and side streets.

| Settlement | What to look for |
| --- | --- |
| Village | Farms, homes and ordinary villager trading. Some villages have a green with a well and bell frame. |
| Town | A market square, fish and produce stalls, and a bakery. The bakery has provisions and the market chest has a City Explorer Map. |
| City | A raised civic square, side streets, a smithy and a cartography counter. The smithy has metal supplies, and the square chest has a Trial Explorer Map. |

Generated city villagers start at Apprentice when they take a job. Armourers
and cartographers start at Journeyman. The primary cost of a city offer is
reduced by 15% of its base amount, rounded down with a minimum saving of one
item for base costs of four or more. Normal demand and reputation still apply.

Use `/locate structure mcl_villages:city_plains` or
`/locate structure mcl_villages:town_savannah` with the `maphack` privilege.
The other biome suffixes are `desert`, `snowy` and `taiga`. Villager explorer
maps for each biome can find any of its settlement tiers.

The custom terrain generator and v7 with the new structure generator enabled
generate all three tiers. The legacy generator and its `/spawnstruct village`
debug command still use the older village layouts. The upgraded world
generation applies as you explore new terrain.

[Sources and licences for the adapted buildings](schematics/settlements/ASSETS.md).

##  Credits

Basic conversion of Settlements mod for compatibility with Mineclone 2, plus new schematics: MysticTempest
Seed-based Village Generation, multi-threading, bugfixes: kay27
Further improvements for Mineclonia by cora and Codiac.
Largely reworked by halon

## License

(c) Copyright Rochambeau (2018)

This program is free software. It comes without any warranty, to
the extent permitted by applicable law. You can redistribute it
and/or modify it under the terms of the Do What The Fuck You Want
To Public License, Version 2, as published by Sam Hocevar. See
http://sam.zoy.org/wtfpl/COPYING for more details.

## Media credits:

This mod is based on "ruins" by BlockMen

Completely new schematics for Mineclone 2:
MysticTempest - CC-BY-SA 4.0

Updated and new schematics for Mineclonia:
Codiac

