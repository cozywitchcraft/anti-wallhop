# anti-wallhop

Patches [wallhopping](https://devforum.roblox.com/t/flicking-camera-allows-climbing-wall-intersections/298135) from the humanoid controller

![Character wallhopping with the anti-wallhop turned off vs. on](assets/RobloxPlayerBeta_cKoAtUvkUp.gif)
![Side view of a character wallhopping between two walls with the anti-wallhop turned off vs. on](assets/RobloxPlayerBeta_MpmGKuwfBv.gif)

Wallhopping occurs because the humanoid state machine runs before the physics simulation every frame. When the player has instant control of the character's rotation (e.g. in first person or mouse lock), its root part can clip into the level geometry. This allows the humanoid to detect floors *inside walls* before the simulation can force the root part out.

This module works by replacing the built-in landing transition with a custom one running post-simulation, patching wallhopping with minimal effect on the humanoid's physics.

For reference, this change affects the humanoid so little that trussflicking, which is almost functionally identical to wallhopping, is preserved.

![Character successfully trussflicking with the anti-wallhop turned on](assets/RobloxPlayerBeta_HLxxviqXdZ.gif)

For those worried about an in-engine wallhop patch in the future, this module can also serve as a wallhop reimplementation by moving the landing floor detection from post-simulation to pre-animation. I haven't implemented this option for practicality's sake.

I'll write an article further detailing how and why this was made and link it here when finished.

You can test the latest version of the anti-wallhop [here](https://www.roblox.com/games/17884774403/Anti-Wallhop-Testing). The source code for the testing place can also be found at [cozywitchcraft/anti-wallhop-testing](https://github.com/cozywitchcraft/anti-wallhop-testing).

## Features

* Emulates humanoid floor detection
* Patches wallhopping
* Visualizes floor detection raycasts
* Supports R6 and R15 rigs

## Usage

In a LocalScript in StarterCharacterScripts:

```luau
-- StarterCharacterScripts/AntiWallhopLoader
local AntiWallhop = require(path.to.AntiWallhop)

local antiWallhop = AntiWallhop.new(script.Parent)
antiWallhop:enable()
```

Or for those concerned about memory management, try the following in a LocalScript in StarterPlayerScripts:

```luau
-- StarterPlayerScripts/AntiWallhopLoader
local Players = game:GetService("Players")

local AntiWallhop = require(path.to.AntiWallhop)

local localPlayer = Players.LocalPlayer

local antiWallhop

local function onCharacterAdded(character: Model)
	antiWallhop = AntiWallhop.new(character)
	antiWallhop:enable()
end

localPlayer.CharacterAdded:Connect(onCharacterAdded)

localPlayer.CharacterRemoving:Connect(function()
	if antiWallhop then
		antiWallhop = antiWallhop:destroy()
	end
end)

if localPlayer.Character then
	onCharacterAdded(localPlayer.Character)
end
```

## Installation

### Using wally

Add `cozywitchcraft/anti-wallhop` to `wally.toml` as a dependency.

```toml
AntiWallhop = "cozywitchcraft/anti-wallhop@0.1.1"
```

### From the Creator Marketplace

Alternatively, you can get the model [here](https://create.roblox.com/store/asset/18196739150/).

### From GitHub

* [Releases](https://github.com/cozywitchcraft/anti-wallhop/releases)
* [Source](https://raw.githubusercontent.com/cozywitchcraft/anti-wallhop/main/lib/init.luau)

## API

### Functions

#### new

`AntiWallhop.new(character: Model) -> AntiWallhop`

Initializes the anti-wallhop as disabled.

#### enable

`AntiWallhop:enable() -> ()`

Enables the anti-wallhop.

#### disable

`AntiWallhop:disable() -> ()`

Disables the anti-wallhop.

#### enableDebug

`AntiWallhop:enableDebug() -> ()`

Enables debug visuals. Each raycast is visualized with a line colored red or green depending on the result.

![Transparent character jumping with debug visuals enabled](assets/RobloxPlayerBeta_6ncHDsmHU7.gif)

#### disableDebug

`AntiWallhop:disableDebug() -> ()`

Disables debug visuals and cleans up debug instances.

#### destroy

`AntiWallhop:destroy() -> ()`

Cleans up connections and debug instances because [character destruction must be handled by the end user](https://devforum.roblox.com/t/new-player-and-character-destroy-behavior/2711317/79).

## License
[MIT](LICENSE)
