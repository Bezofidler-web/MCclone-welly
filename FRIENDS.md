# Mineclonia with friends

## Play together on the same Wi-Fi or Ethernet network

On each Windows PC, extract the mcWelly player ZIP and double-click
**Play Mineclonia.cmd** inside the **mineclonia** folder. The player ZIP includes
Luanti 5.18. The source checkout also accepts an extracted Luanti installation
in `local\luanti` or a `luanti.exe` available on your PATH.

1. **Host:** open **Multiplayer → Host World**, choose your player name on the
   first visit, then select a save or create a new world. Select **Open to LAN**.
2. **Friend:** open **Multiplayer** on the same network. The host's world appears
   with its name and owner. Select it and press **Join World**. Choose your
   player name on the first visit. Use the same name and Windows user on the
   same PC to recover your inventory next time.
3. The host can keep playing. Leaving the world ends the session and removes
   it from the list within a few seconds. One person sleeping can skip the night.

Anyone on the local network can join a LAN world while it is open. The host
keeps the world controls. For an invitation-only game, use a private server
as described below.

**Existing saves:** with standard Luanti, the solo character and the named
LAN host have separate inventories and positions. A world first shared with
standard Luanti keeps that named host. Your original solo character is still
in Singleplayer. The optional native client supports retaining the solo
character when first sharing a world. To share a world you are already
playing, use **Options → Open to LAN** or `/openlan`, then **Save and continue**.
The native pause menu also includes **Open to LAN**.

If the world stays missing, wait until the host sees **World open to LAN**.
Check both players have opened the mcWelly launcher and selected the same
local network. Guest Wi-Fi that isolates devices can prevent discovery and
play. Reopen the launcher after changing networks. A school-managed PC may
also require an approved PowerShell installation or local network permission.

## Play on different networks

Nearby worlds are discovered on the local network. For friends elsewhere, use
a dedicated world with an address both devices can reach. The host can set
`mcl_friends_invite_address` in the private server config to enable a single
pasteable invitation. Automatic internet matchmaking and a relay service are
currently unavailable.

For example, set `mcl_friends_invite_address = play.example.org:30000`,
substituting the hostname or IP address your group uses. Restart the server
after changing the config. In **Server Controls → Accounts**, enter the
friend's player name, choose **Invite** and send them the private invite.
They choose **Multiplayer → Join with Invite → Review Invite**, check the
host, player name and destination, then choose **Join World**. The invite
contains their temporary login. Confirming remembers the address, port and
player name. After changing their password, the guest opens **Direct Connect**
and enters their own password on future visits.

### Join an existing private server manually

1. Install [Luanti 5.18.0](https://www.luanti.org/en/downloads/) for your
   device. On Windows, extract the ZIP and open `bin\luanti.exe`. Luanti is the
   only download you need on the same network as the host. The server sends
   its gameplay content when you connect, so you can join without Minecraft,
   a Mineclonia download or a separate texture pack.
2. Pick your **player name** and tell the host so they can invite it. Use
   1–20 letters, digits, underscores or hyphens, with the same capitalisation
   each time. Your chosen name appears in game and identifies your saved
   inventory and progress.
3. In Luanti, open **Join Game**. Fill in the server address, port (usually
   `30000`), exact name and temporary password from the host. Press
   **Login** on your first visit and every time you return. In the
   custom Mineclonia title screen, open **Multiplayer → Direct Connect**, enter the same
   details and press **Join Server**.
4. Once inside, use **Esc → Change Password** to set your own password.
   Keep it for the next time you join. The host needs to be running the
   server whenever you play.

For friends on different networks, the host needs an address you can reach.
If the host shares their device through Tailscale, also install Tailscale,
accept the share, and use the host's Tailscale address. A server that is
already reachable at the address the host gives you only requires Luanti.
[Luanti multiplayer guide](https://docs.luanti.org/for-players/servers/) ·
[Tailscale private game server guide](https://tailscale.com/docs/use-cases/personal-or-at-home-use/share-private-game-server)

## Host a private world

From the `mineclonia` game directory, run this in PowerShell 7. Replace
`Odhran` with the exact name you want. Keep the checkout named `mineclonia`
when reusing an existing Mineclonia world.

```powershell
.\tools\Start-FriendsServer.ps1 -HostName Odhran -World '.\local\friends-world'
```

1. Keep the server window open. It creates a private config in
   `local\friends-server.conf` and shows a temporary password in the console
   the first time it creates the host account. Once it is listening, open
   **Play Mineclonia.cmd** or Luanti and log in at `127.0.0.1:30000`. Change
   your password with **Esc → Change Password**.
2. In game, enter `/servercontrols` or open **Server Controls** from the
   inventory. Open **Accounts**, type your friend's chosen name and select
   **Invite**. Copy the temporary password and send it privately with the
   exact name, address and port. You can invite multiple friends while the
   world is running. Ask each player to change their password after joining.
   Manage invitations from the host PC or through an encrypted private
   network such as Tailscale.
3. Keep using the same `-World` path to retain terrain, player progress and
   accounts. To host an existing world, stop it, back it up and pass its
   directory with `-World`. Pass `-LuantiExe` with the path to Luanti 5.18.0
   if the bundled local copy is unavailable.

**Accounts** also lets the host allow an existing account, reset a guest's
password, or remove their access while keeping their saved progress. If you
lose the host password, stop the server and run the same command once with
`-ResetHostPassword`. Existing allowlists still work. When moving off the
old config-based invitation flow, clear `mcl_friends_invited_name` and
`default_password` once any outstanding invitations have been used.
If a guest password is exposed, use **Remove access**, reset the password and
restart the server before restoring access. The restart clears connections
that were already loading.

Keep `server_announce = false` to keep the world off the public list. Wait for
Luanti to report that it's listening. Startup can take a few minutes while
Luanti reads the game's assets. The launcher lists local network
addresses with the UDP port. Send friends on your Wi-Fi or Ethernet network
the address on that adapter and the port. On another network, use the address
from your chosen hosting or private networking setup. If players see a
timeout, check that the server is running and that their network and the
host firewall allow traffic to the Luanti UDP port.
[Luanti server setup](https://docs.luanti.org/for-server-hosts/setup/)

The configured host can open **Server Controls** directly from the survival
or creative inventory, from **Options**, or with `/servercontrols`. The panel
shows connected players, world time and weather. The host can set day or night,
clear weather, disconnect a guest, or save and stop the server. A disconnected
guest can rejoin. To start the server again after stopping it, run the launcher.

The server stores its log beside its config. One player in an Overworld bed
can skip the night while the others stay awake.

## Use voice channels

The host and anyone using voice need the [native Mineclonia build](#native-java-style-windows-client).
Friends on standard Luanti can still play. To host with voice, point the
server launcher at the native build and use your usual world path.

```powershell
.\tools\Start-FriendsServer.ps1 -LuantiExe '.\local\java-client\bin\luanti.exe' -World '.\local\friends-world'
```

To play with voice, open the same build using the client launch command below.

1. Join the multiplayer world and open **Esc → Voice Chat**.
2. Select **Lobby**, **Building** or **Exploring**. Each channel holds up to
   eight players. The panel lists the people in your current channel.
3. **MIC ON** appears when your microphone is open. It opens as soon as your
   join succeeds and stays open when you return to the game. Use **Mute Mic**
   to keep listening, **Mute Voices** to turn off incoming voice, or
   **Leave Channel** to stop both. Joining another channel opens your mic again.

Voice uses the game's existing UDP port. The server routes audio to the
other members of the same channel without storing it. Voice travels without
additional encryption, so use a trusted network or an encrypted private
network such as Tailscale. To disable it, set `mcl_voice_chat = false` in
the server config and restart.

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

## Automate a recipe with the Crafter

Arrange these ingredients at a crafting table to make a **Crafter**.

```text
Iron Ingot    Iron Ingot       Iron Ingot
Iron Ingot    Crafting Table   Iron Ingot
Redstone      Dropper          Redstone
```

Place it facing you. Put ingredients in its nine slots and use the buttons
beneath empty slots to disable them. The output shows a preview. A redstone
pulse crafts once and sends the result and any returned containers through
the front face, into a container if it has room. Hoppers skip disabled slots.
A comparator gives one signal strength for each occupied or disabled slot.
Recipes that rely on Mineclonia's manual crafting callbacks, such as written
book copying, still use the crafting table.

## Apply Minecraft Java textures

Use the client JAR from your own Minecraft Java installation. This example uses
26.3. Point `-ClientJar` to the installed version you want to use.

```powershell
.\tools\Import-JavaTextures.ps1 -ClientJar "$env:APPDATA\.minecraft\versions\26.3\26.3.jar"
```

The Windows launcher requires the imported Java 26.3 pack and applies it on
every launch, including with existing configs. If you launch directly from Luanti, copy
`mineclonia-java-<version>` from `local\textures` into your Luanti `textures` folder
and select it in the **Content** tab. Each player imports the assets on their
own device. Add `-Force` to refresh an earlier pack.
The overlay includes the Java hotbar, armour slots, menu buttons, book page,
Crafter sprites and End sky. Use `-TitlePanorama 'C:\path\to\panorama.png'`
to supply a locally available title image. Otherwise the launcher uses the
bundled Mineclonia landscape if the JAR has no full-size panorama texture.
On Windows the importer also assembles the cracking animation and adapts the
Java water and lava animation strips. It keeps the previous pack as a backup.

`java-texture-library.zip` holds the complete source texture library, including
animation metadata. The manifest lists which textures the pack applies and
which mappings kept the bundled art. For example, the Fox skin still uses
its Animalia atlas and its egg can use the Java 26.3 art. [Luanti texture pack guide](https://docs.luanti.org/for-players/texture-packs/)

## Choose a graphics preset

```powershell
.\tools\Start-VibrantClient.ps1 -LuantiExe 'C:\path\to\luanti.exe' -Profile Vibrant
```

| Profile | What it shows |
| --- | --- |
| `Fast` | Shorter draw distance, flat clouds and see-through leaves |
| `Fancy` | Longer draw distance, 3D clouds and see-through leaves |
| `Basic` | Custom colour grading, nearby sun shadows, subtle bloom, moving foliage and water |
| `Vibrant` | Dynamic sun shadows, light shafts, gentle bloom and simulated sky reflections on water |

Each profile uses a separate client config in `local`. All profiles use the
imported Java 26.3 pack. To try the updated graphics preset alongside an existing config, pass
`-Config .\local\vibrant-updated.conf` on launch.

Use `-Profile Basic` to load the Luanti colour shader inspired by Sildur’s Basic.
It adds cool shadows, warmer highlights and a colour boost for muted surfaces.
Luanti handles shadows, bloom and animation. The other profiles use Luanti’s
default colour pass.

**Multiplayer → Direct Connect** opens **Join a Server**. Paste an address and port together
(`hostname:port` or `[IPv6]:port`), or enter them in separate fields. The
menu remembers the address, port and name for your next visit. If the server
rejects the connection, correct the details on the same screen. **Server
List** opens Luanti's browser, and the local playtest launcher offers **Join
Playtest**. Progress while connecting comes from Luanti.
Dimension transfers that generate terrain display their world-generation progress.

Open **Singleplayer**, select a world, and press **Play Selected World** or
double-click it. The **Game Mode** choice is saved per world. **Create New
World** accepts a name, game mode, optional seed and the Default or Superflat
world type. **Edit** opens Luanti’s advanced world management.

The launcher configures a bundled pixel font and translucent chat where the
profile has no preference. Set a custom `font_path` in the client config to
choose another font. **T**, **/** and **Esc** use Luanti’s native controls.

**Options → Video Settings → Brighter caves and water** is on by default.
On Luanti 5.18 it brightens low-light levels, including unlit caves. It also
lightens underwater fog and increases sight distance. Use the switch to
restore the original dark appearance. Your client gamma still applies and
the game uses the original block and sky light for spawning and other rules.

## Native Java-style Windows client

After a successful build, run this from the Mineclonia directory.

```powershell
.\tools\Start-VibrantClient.ps1 -LuantiExe '.\local\java-client\bin\luanti.exe' -Profile Fast -JavaUi
```

Use **T** for chat, **/** to start a command, **Esc** for the pause menu
and **F3** for the debug overlay. **F10** still opens the full console.
The launcher keeps a separate profile for this client. For the original
client, continue using its usual executable and profile.

Use the CLANG64 packages in [Luanti's Windows build guide](https://github.com/luanti-org/luanti/blob/5.18.0/doc/compiling/windows_msys2.md).
Apply the [Java UI patch](tools/luanti-java26.3.patch), followed by the
[voice chat patch](tools/luanti-mineclonia-voice.patch) and the
[LAN sharing patch](tools/luanti-mineclonia-lan.patch), to a clean copy of
Luanti 5.18.0. The build places the client and its runtime libraries in
`local/java-client`. The same executable supports dedicated hosting through
`Start-FriendsServer.ps1`.

```powershell
$source = 'C:\path\to\luanti-5.18.0'
$patch = (Resolve-Path '.\tools\luanti-java26.3.patch').Path
$voicePatch = (Resolve-Path '.\tools\luanti-mineclonia-voice.patch').Path
$lanPatch = (Resolve-Path '.\tools\luanti-mineclonia-lan.patch').Path
git -C $source apply $patch
git -C $source apply $voicePatch
git -C $source apply $lanPatch
.\tools\Build-JavaClient.ps1 -Source $source -Toolchain 'C:\msys64\clang64'
```

Pass `-CMakeExe 'C:\path\to\cmake.exe'` to use a separate CMake installation.

The native coordinate and pause features use the matching Mineclonia game
files. A friends server picks up the new coordinate data, statistics and
world-options actions when its host restarts it with the updated game.

With a new profile, **E** opens inventory, **Left Ctrl** starts sprinting and
**F5** changes perspective. Double-tapping **W** also starts sprinting. Use
**Options → Accessibility** to change the default 350 ms tap window or set it
to zero for sprint-key-only input.

Use **Options → Video Settings** from the inventory toolbar.
Turn on **Vibrant lighting** there for tinted shadows and atmospheric fog.
**Clouds** and **Extra block debris** also apply during play. Luanti's own
settings control render distance, shadow quality, keyboard bindings and local
digging particles. When connected to a friends server, movement updates take
effect after the host restarts the server with this build.

## In-game navigation

- The upper-left HUD shows Java-style **XYZ**, **Block** and **Facing**. The
  axes and height are presented in Java’s coordinate convention. Use
  `/coords` for positions suitable for Mineclonia commands, and
  **Options → HUD Settings → Coordinates** to toggle the readout.
- The top-right HUD shows a nearby terrain map.
  **V** cycles the map zooms and off in the stock 5.18 key bindings. The
  centre arrow shows your heading, and visible nearby players have markers.
  **Options → HUD Settings → Minimap** toggles the map.
- Press **M** with the launcher presets, open **Map** from either inventory,
  or type `/map` for the full-screen world view. Select a nearby player
  marker to see their name, live coordinates and distance. The shortcut
  uses Luanti's Zoom binding, which still zooms while holding a spyglass.
  Pan with either scrollbar or the direction buttons. Blank areas have no
  loaded terrain at the displayed depth.
- Open **Players** from either inventory, or use `/players`, for the online
  roster. **Commands** or `/commandbar` opens the command field. The server
  checks the same privileges as commands entered in chat.
- Hold **W** and look up or down to swim in that direction. Presets enable
  Luanti's pitch movement for swimming. Existing explicit preferences are
  kept. On another client, enable **Pitch move mode** in Luanti's settings.
