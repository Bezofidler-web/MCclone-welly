# Mineclonia mod: beds
Original mod by `Blockmen` shared under [MIT] --> [beds](https://github.com/BlockMen/beds)
This mod was heavily modified by the authors below.

## Authors of source code
* Originally by `BlockMen` [MIT]
* Various `Minetest developers and contributors` [MIT]
Modified by:
* Various `Mineclone and Mineclonia developers and contributors` [GPL-3.0-or-later](https://www.gnu.org/licenses/gpl-3.0.html)
* Various changes (e.g. Straw bed) by `Fhelron` [GPL-3.0-or-later](https://www.gnu.org/licenses/gpl-3.0.html)

## Authors of media (textures)
* `BlockMen` ([CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/))
* `Fhelron` ([CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/)) --> [`textures:`](mcl_beds_straw_bed.png, mcl_beds_straw_bed_inv.png)

## Information
This mod adds a bed to Mineclonia which allows to skip the night.
To sleep, rightclick the bed.
Another feature is a controlled respawning. If you have slept in bed your respawn point is set to the beds location and you will respawn there after
death.

Use `mcl_playersSleepingPercentage` to set the percentage of Overworld players
who must sleep to skip the night. Set it to `0` for one-player sleep or above
`100` to disable night skipping.

mcl_beds.is_night([ time of day ]) - returns wether it's night with optional argument of a mineclonia time of day value between 0 and 1
