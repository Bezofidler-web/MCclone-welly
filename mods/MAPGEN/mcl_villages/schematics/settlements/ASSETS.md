# Settlement schematics adapted from GDMC

The four `gdmc_*.mts` files are modified conversions of hand-built schematics by the [GDMC team](https://github.com/williamcwi/GDMC/tree/4aeb4b80264f1c0d80867b6fc9efbb5b2e962727). Upstream history credits the schematic additions and market-stall move to `hkl9`.

The adapted files are distributed under [Apache License 2.0](LICENSE-GDMC.txt). The included licence is the full, unmodified [upstream licence](https://github.com/williamcwi/GDMC/blob/4aeb4b80264f1c0d80867b6fc9efbb5b2e962727/LICENSE).

| Mineclonia file | Upstream source | Changes for settlement generation |
| --- | --- | --- |
| `gdmc_market_stall_fish.mts` | [Stall 1](https://github.com/williamcwi/GDMC/blob/4aeb4b80264f1c0d80867b6fc9efbb5b2e962727/schematics/stall/stall_1.schematic) | Preserved the blue and grey canopy. Added an empty fisherman’s barrel, replaced glowstone and barriers with timber and lanterns, and opened access around the counter. |
| `gdmc_market_stall_produce.mts` | [Stall 3](https://github.com/williamcwi/GDMC/blob/4aeb4b80264f1c0d80867b6fc9efbb5b2e962727/schematics/stall/stall_3.schematic) | Preserved the yellow and red canopy. Added a composter and produce, replaced glowstone and barriers with timber and lanterns, and opened access around the counter. |
| `gdmc_bakery.mts` | [Bakery 2](https://github.com/williamcwi/GDMC/blob/4aeb4b80264f1c0d80867b6fc9efbb5b2e962727/schematics/bakery/bakery_2.schematic) | Centred the porch entrance, fitted oak doors, shifted a counter, put a smoker at floor level and furnished the loft with shelving. Preserved the ladder, chimney and cake displays and added one Mineclonia chest downstairs. |
| `gdmc_smithy.mts` | [Blacksmith 2](https://github.com/williamcwi/GDMC/blob/4aeb4b80264f1c0d80867b6fc9efbb5b2e962727/schematics/blacksmith/blacksmith_2.schematic) | Opened the double doorway and built up its threshold, added a blast furnace and replaced the open lava, brewing stand and cauldron with masonry and work surfaces. Preserved the chimney, bars and worn anvil and added one Mineclonia chest near the entrance. |

Each conversion retains its source footprint, translates rotations and slab halves to Luanti node parameters, and uses Mineclonia’s oak and masonry blocks for biome substitutions. Each adds one village path marker at the front entrance. The conversion omits source chest blocks, inventories, tile entities and other Minecraft metadata. The two new chests are empty in the schematics for Mineclonia to stock during world generation.
