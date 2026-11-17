# mcWelly gameplay and multiplayer audit

17 November 2026. The target was this Mineclonia fork, its documented co-op additions and its Minecraft Java 26.3 reference. The game runs on Luanti. Minecraft Java and Bedrock clients cannot connect to it.

## What changed

| Player journey | Fault reproduced or identified | Change |
| --- | --- | --- |
| Find a friend's world | Multiplayer initially asked for an address, port, invited name and password | The Windows launcher discovers nearby worlds. Hosts select a save and open it to LAN. Guests select the advertised world. The listing expires when the host leaves. |
| Join a private world elsewhere | Guests had to transcribe four fields | A dedicated host with a reachable address can issue one private invite. The guest reviews its destination and player name before joining. |
| Open a downloaded copy | The double-click entry depended on a developer's sibling test folder and the menu assumed the checkout was named `mineclonia` | The player package includes a clean Windows engine. The launcher resolves the game ID and can also find a local Luanti installation. |
| Craft from the recipe book | Selecting mixed materials could fail even when the grid could make the recipe. Transfer and preview disagreed on ingredient groups. Bulk crafting could lose item metadata. | Preview and transfer use the same ingredient allocation. Failed transfers preserve the grid. Named items retain their identity. |
| Eat the last item in a stack | Callbacks could receive an empty stack or the returned bowl | Callbacks see the original food and can cancel consumption before inventory changes. |
| See friends on the full map | Another player's marker stayed in its old position until terrain changed or someone refreshed | A stationary viewer now sees players move and disappear. Marker-only updates reuse the existing terrain image. |
| Dispense a boat, bucket or bottle | Some chest boats and bamboo rafts turned into generic boats. Full dispensers could discard collected water or mishandle a vacated bottle slot. | Dispensing preserves the boat type, returned container and recovery behaviour. Honey harvesting also updates redstone observers of the block change. |
| Grow sea pickles underwater | Nine seabed materials referenced 72 missing textures, and growth checked for water at the wrong position | Registered variants use existing textures. New growth checks the water above the seabed and lights up underwater. |

## Verification

The fresh registry inspection loaded 245 game mods across the repository. It counted 3,982 items, 3,166 nodes, 320 entities, 217 biomes and 2,472 registered recipes. The scan found no unknown references among the recipe ingredients, drops and declared base items it inspected. All 2,058 distinct static assets in the final scan resolved. Registration covers availability. Behaviour checks below exercised selected player journeys.

- **LAN.** Two stock Luanti 5.18 Windows clients used the actual title menu, launcher and UDP discovery on loopback. The guest opened Multiplayer before the host. Both joined, the guest received three diamonds, disconnected and recovered all three after restarting. A separate check verified stale-listing expiry. A visual check showed the world and owner in the running Multiplayer screen. A disposable existing solo world also passed the save-and-reopen path and recovered its original client profile settings after hosting.
- **Host and account controls.** A game-engine fixture checked 26 network-admission cases. The existing private-server suite exercised first-time invitations, denied sign-ins, guest restrictions, revocation, password reset and inventory persistence across a server restart. Temporary passwords were absent from the normal logs and configuration that suite inspected.
- **Private invitations.** Two stock clients tested invitation issue, cancellation, confirmation and login. The private invitation worked with the complete game loaded. The focused menu check recognised five valid destination forms and rejected seven malformed inputs. The credential and invite were absent from the ten logs and configs it inspected.
- **Full map.** Two stock clients in a map fixture verified live movement and hiding, updates after a block edit, pan, zoom, and that switching to another form closed the map. Moving a marker did not regenerate the terrain image.
- **Gameplay.** All 88 spawn eggs produced their expected named entity and consumed one item. Sixty additional Strider placements included three valid attached baby riders. The player regression suite passed ten cases. Fresh two-client co-op checks exercised one-player sleep, cushions, Crafter pulses, comparators, hoppers, furnace insertion and container recovery.
- **Windows launch.** The double-click entry opened its bundled stock engine from a clean extraction. A separate test with an unreadable disposable LAN identity kept Singleplayer and Direct Connect available and preserved the identity file. PowerShell 7 worked on this PC. Its policy blocked scripts in the older built-in Windows PowerShell.
- **Native client.** The layered Java-style UI, voice and LAN engine patches applied and compiled. Windows denied execution of that binary on the test PC. Runtime verification here used stock Luanti.

## Outstanding differences and coverage

| Area | Current behaviour | Evidence |
| --- | --- | --- |
| Existing solo saves | Stock Luanti uses a separate host character in LAN mode. Returning to Singleplayer restores the original character. The native client has a path for retaining the solo identity on first share. | [Sharing implementation](menu/lan.lua) |
| Different networks | A dedicated invitation still requires network reachability. A managed Wi-Fi network can also isolate players. A two-PC Wi-Fi session, external internet connection and microphone round trip remain unverified. | [Multiplayer guide](FRIENDS.md) |
| Game modes | The fork implements Survival and Creative. Adventure and Spectator are absent. | [Game modes](mods/PLAYER/mcl_gamemode/init.lua) |
| Potent sulfur | The block exists, but its Java environmental effects are unimplemented. | [Sulfur blocks](mods/ITEMS/mcl_sulfur/sulfur_blocks.lua) |
| Command-block minecart | The variant is registered and marked work in progress. It lacks its Java activator-rail action. | [Minecart definitions](mods/ENTITIES/mcl_minecarts/init.lua) |
| Camel Husk | Its rider uses a sword as a substitute for a spear. | [Camel Husk](mods/ENTITIES/mcl_camels/husk.lua) |
| Commands | The title command is self-only and the sound commands omit `/stopsound`. | [Title](mods/HUD/mcl_title/init.lua) · [Sound commands](mods/MISC/mcl_commands/sound.lua) |

The additional towns and cities, cushions and custom map features are intentional fork features. Exact terrain, combat timing, AI and cross-device network behaviour have yet to be verified. Minecraft also has an account-backed Friends List with presence and friend requests. mcWelly currently provides nearby-world discovery and private invitations. [Minecraft Java Edition release notes](https://www.minecraft.net/en-us/article/minecraft-java-edition-26-2)

## Reproduce the checks

Run these from the game directory using PowerShell 7 and Luanti 5.18. Set `$engine` to the executable on the test machine. The tests create disposable worlds.

```powershell
$engine = '.\local\luanti\bin\luanti.exe'
.\tools\tests\Test-LanMultiplayer.ps1 -LuantiExe $engine
.\tools\tests\Test-LanDiscovery.ps1
.\tools\tests\Test-DedicatedInvite.ps1 -LuantiExe $engine
.\tools\tests\Test-PlayerGameplay.ps1 -Engine $engine
.\tools\tests\gameplay\Run.ps1 -LuantiExe $engine
```
