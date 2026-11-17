# Sprint Mod for Mineclonia
Forked from [sprint] by GunshipPenguin  

## Description
Press the Aux1 key while moving forwards or double-tap Forward to sprint.
The Java-style profiles bind Aux1 to Left Ctrl. Stock Luanti binds Aux1 to E.
Sprinting increases walking speed by 30% and widens the field of view. It
continues while you move forwards and have enough food. Sneaking stops it.

The default double-tap window is 350 ms. Change it in the in-game Accessibility
Settings. A window of 0 ms disables double-tap sprinting.

## License
CC0 (see COPYING file)

## Mod developer settings (`init.lua`)
### `mcl_sprint.SPEED`
How fast the player will move when sprinting as opposed to normal 
movement speed. 1.0 represents normal speed so 1.5 would mean that a 
sprinting player would travel 50% faster than a walking player and 
2.4 would mean that a sprinting player would travel 140% faster than 
a walking player.
