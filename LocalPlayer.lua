local Import = loadstring(game:HttpGet("https://raw.githubusercontent.com/newmorta/Roblox-Helpers/main/Import.lua"))()

local Services = Import("Services")

local LocalPlayer = {}

function LocalPlayer.Get()
	return Services.Players.LocalPlayer
end

function LocalPlayer.GetCharacter()
	local player = Services.GetLocalPlayer()
	return player.Character or player.CharacterAdded:Wait()
end

function LocalPlayer.GetHumanoid()
	local character = Services.GetLocalCharacter()
	return character:WaitForChild("Humanoid")
end

return LocalPlayer
