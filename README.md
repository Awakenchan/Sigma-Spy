# Sigma-Spy
A complete Remote Spy with an incredible parser that captures Client receives and pushes with Actor support!

## Notices
- Sigma Spy will have bugs, please report any bugs by opening an [issue](https://discord.gg/aeAUA4nkhF) on Github
- If you gave a suggestion, please post it in the [discussions](https://discord.gg/aeAUA4nkhF)
- Please do not use Potassium in games with Actors as Potassium's crude implimentations break

## Loadstring
```lua
--// Sigma Spy @depso > active fork by @awakenkn
loadstring(game:HttpGet("https://raw.githubusercontent.com/Awakenchan/Sigma-Spy/refs/heads/main/Main.lua"), "Sigma Spy")()
```

## Features ⚡
- **Actors** support
- **__index** and __namecall support
- **Decompile** large scripts
- **Block** remotes from firing
- **Spoof** return values _(Return spoofs.lua)_
- **Keybinds** for toggling options
- Argument values for log titles
- Wide range of supported data types
- Logging client recieves _(e.g **OnClientEvent**)_
- Variable compression in the parser
- Remote stacking _(optional)_

## Gallery
<table>
	<tr>
		<td>
			<img src="https://github.com/user-attachments/assets/d1a1c86c-008c-49bf-ba06-f66c143fff29">
      Parser output example
		</td>
    <td width="58%">
			<img src="https://github.com/user-attachments/assets/ca620f32-1238-42d7-ac7c-41edeee6d232">
      UI preview
		</td>
	</tr>
</table>

## Required functions ⚠️
Sigma spy will prompt you if your executor does not support it.
Your executor must support these functions in order for it to function:
- create_comm_channel
- get_comm_channel
- hookmetamethod
- getrawmetatable
- setreadonly
