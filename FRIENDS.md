# Mineclonia with friends

Run these commands from the game directory in PowerShell 7. Use a clean portable
Luanti installation for the server so the launcher finds this checkout. Luanti
5.18.0 was used to test this build. Keep the checkout named `mineclonia` if you
intend to use an existing Mineclonia world.

## Host a private world

```powershell
New-Item -ItemType Directory -Path .\local -Force
if (-not (Test-Path .\local\friends-server.conf)) {
    Copy-Item .\friends-server.conf.example .\local\friends-server.conf
}
notepad .\local\friends-server.conf
```

1. Set `name` to your Luanti player name and `mcl_friends_allowed_names` to the
   friends' exact names, separated by commas. For a fresh world, put your own
   name in `mcl_friends_invited_name` and choose a temporary `default_password`.
2. Start the server with the command below. Open another Luanti window, select
   **Join Game**, and log in to `127.0.0.1` on port `30000` with your name and
   temporary password. Set a private password through **Esc → Change Password**.
3. To invite someone, stop the server, put their name in `mcl_friends_invited_name`,
   and set a fresh `default_password` for them. Start the server again. Send
   them the password privately. They join with that name and password and set
   their own password in the pause menu. Repeat for each friend.
4. Clear `mcl_friends_invited_name` and `default_password` after registration,
   then restart. Existing players log in with their personal passwords.

```powershell
.\tools\Start-FriendsServer.ps1 -LuantiExe 'C:\path\to\luanti.exe'
```

The server stays out of the public list. Friends on the same network join using
your computer's LAN address and port `30000`. Run `ipconfig` and look for the
IPv4 Address under your active Wi-Fi or Ethernet adapter. Friends enter that
address, the port and their invited name in Luanti's **Join Game** tab. They
only need the Luanti client to join. The host must keep the server running.
[Luanti multiplayer guide](https://docs.luanti.org/for-players/servers/)

For friends on other networks, one option is to share the host device privately
with them through Tailscale. After accepting the share, they use the host's
Tailscale IP and the same Luanti port. Keep the Mineclonia allowlist enabled.
[Tailscale private game server guide](https://tailscale.com/docs/use-cases/personal-or-at-home-use/share-private-game-server)

The server stores its world and log in `local` by default. To use an existing
world, stop its server, back it up, then pass the world directory with `-World`.
One player in an Overworld bed can skip the night while the others stay awake.

## Find the new content

The server profile creates new worlds with Mineclonia's `singlenode` map
generator. Its Dappled Forests have Poplars in three colours, fallen logs,
Red Shrubs and Shelf Mushrooms. Abandoned Camps also generate in other forest
biomes with the newer structure generator. Their chests can point you to
another camp. Craft a cushion from three wool slabs of the same colour, then
right-click it to sit and sneak to get up.

In freshly explored terrain, look for Bees around natural nests, Foxes in taiga
and Dappled Forests, Bogged in swamps, and Breeze and Bogged Trial Spawners in
Trial Chambers. Put a lit campfire below a nest or hive with a clear path for
the smoke before harvesting honey or honeycomb. A Breeze killed by a player
drops rods for Wind Charges and maces.

- Some Abandoned Camp stashes contain a map to an Ancient City. Bring wool to
  muffle footsteps around sculk. Natural shriekers can summon a Warden.
- Look for Pale Gardens with pale oak, hanging moss and Eyeblossoms. After
  dark, look for an aligned Creaking Heart. Hitting its Creaking produces
  resin near the heart.
- Breed Frogs in swamps with slimeballs and raise their tadpoles in different
  climates. Frogs eat small magma cubes to make Froglights. On beaches, breed
  Turtles with seagrass and let their hatchlings grow to collect scutes.
- Sleep regularly to avoid Phantoms. Phantom membranes repair Elytra and brew
  Slow Falling. Look for the Parched at night in deserts, Goats in snowy
  mountain biomes, and Sulfur Cubes around underground sulfur and cinnabar.
- Give an Allay a sample item to have it collect matching drops. Play a nearby
  Note Block to change its drop-off point. Use a Spider Eye to breed Armadillos
  and brush them for scutes to craft Wolf Armour. Grow bamboo near Pandas to
  breed them.
- Brush suspicious gravel in warm ocean ruins for Sniffer Eggs. Set an egg on
  moss to hatch it faster. Adult Sniffers dig up Torchflower Seeds and Pitcher
  Pods. Tame a Nautilus with pufferfish, then saddle it to preserve your oxygen
  underwater. Look for Nautilus Armour in ocean loot.
- Put a carved pumpkin on a copper block to make a Copper Golem and a Copper
  Chest. Put items in its copper chest and provide ordinary chests nearby. The
  golem puts matching items together and can use empty chests.
- Craft a Dried Ghast from eight Ghast Tears around Soul Sand, then waterlog it.
  Feed the Ghastling snowballs to help it grow. Equip the adult with a harness
  to seat up to four players. The first rider steers with movement controls and
  the camera. Jump climbs and sneak dismounts.

## Apply Minecraft Java textures

Use the client JAR from your own Minecraft Java installation. This example uses
26.3. Point `-ClientJar` to the installed version you want to use.

```powershell
.\tools\Import-JavaTextures.ps1 -ClientJar "$env:APPDATA\.minecraft\versions\26.3\26.3.jar"
```

Copy the resulting `mineclonia-java-<version>` folder from `local\textures` to
your Luanti `textures` folder, then select it in the **Content** tab. Each player
does this on their own device. Add `-Force` to rebuild a pack made by the
script. It retains the previous pack as a backup.

`java-texture-library.zip` holds the complete source texture library, including
animation metadata. The manifest lists which textures the pack applies and
which mappings kept the bundled art. For example, the Fox skin still uses
its Animalia atlas and its egg can use the Java 26.3 art. [Luanti texture pack guide](https://docs.luanti.org/for-players/texture-packs/)

## Use the Vibrant Visuals-inspired graphics preset

```powershell
.\tools\Start-VibrantClient.ps1 -LuantiExe 'C:\path\to\luanti.exe'
```

This starts Luanti with a separate graphics config in `local`. On first launch,
it also selects the local Java 26.3 texture pack if present. In the world, open
the gear in your inventory and turn on **Graphics → Vibrant lighting** for
tinted shadows, richer colours and dimension-specific fog. The client preset
enables dynamic shadows, bloom, light shafts, translucent foliage and simulated
sky and sun reflections on water. Each friend can choose their own settings.

On slower devices, lower **Shadow map texture size** to `1024` and turn off
**Volumetric Lighting** in Luanti's settings. For another texture pack, edit
`texture_path` in `local/vibrant-client.conf`. For the usual graphics settings,
start Luanti normally and turn off **Vibrant lighting** in the world.
