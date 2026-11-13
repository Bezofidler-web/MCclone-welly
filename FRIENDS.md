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
your computer's LAN address and port `30000`. The server does not configure
remote access. By default its world and log are in `local`. To use an existing
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

## Apply Minecraft Java textures

Use the client JAR from your own Minecraft Java installation. This example uses
1.21.4. Point `-ClientJar` to the installed version you want to use.

```powershell
.\tools\Import-JavaTextures.ps1 -ClientJar "$env:APPDATA\.minecraft\versions\1.21.4\1.21.4.jar"
```

Copy the resulting `mineclonia-java-<version>` folder from `local\textures` to
your Luanti `textures` folder, then select it in the **Content** tab. Each player
does this on their own device. The manifest inside the pack lists imported and
skipped mappings. The fox model uses its bundled Animalia atlas. Its Java spawn
egg can be imported with 26.3. Other missing or unsupported textures use the
game's bundled art. [Luanti texture pack guide](https://docs.luanti.org/for-players/texture-packs/)
