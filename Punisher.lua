--[[
    BYRONIX — Punisher Module
	Handles all punishment actions based on configuration.
]]

local Config = require(game.ReplicatedStorage.Superion.Config)
local Logger = require(script.Parent.Logger)

local Punisher = {}

--- Apply punishment to a player for a detection
function Punisher.Punish(player, detectionType, code)
	if Config.DRY_RUN then
		Logger.Log(player, "Punisher", "DRY RUN: Would punish for " .. detectionType, code)
		return
	end

	local violations = Logger.GetTotalViolations(player.Name)
	if violations < Config.MAX_VIOLATIONS then
		-- Not enough violations yet, just warn
		Punisher.Warn(player, code)
		return
	end

	local punishment = Config.PUNISHMENT

	if punishment == "Kick" then
		Punisher.Kick(player, code)
	elseif punishment == "Kill" then
		Punisher.Kill(player, code)
	elseif punishment == "Warn" then
		Punisher.Warn(player, code)
	elseif punishment == "Log" then
		Logger.Log(player, "Punisher", "Logged only: " .. detectionType, code)
	end
end

--- Kick the player from the game
function Punisher.Kick(player, code)
	local message = string.format(Config.KICK_MESSAGE, code or "???")
	Logger.Log(player, "Punisher", "KICKING player: " .. message, code)
	player:Kick(message)
end 

--- Kill the player's character
function Punisher.Kill(player, code)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			Logger.Log(player, "Punisher", "KILLING character (Code: " .. (code or "???") .. ")", code)
			humanoid.Health = 0
		end
	end
end

--- Send a warning to the player
function Punisher.Warn(player, code)
	Logger.Log(player, "Punisher", "WARNING player (Code: " .. (code or "???") .. ")", code)
	-- Send warning via remote to client for display
	local eventsFolder = game.ReplicatedStorage:FindFirstChild("Superion")
		and game.ReplicatedStorage.Superion:FindFirstChild("Events")
	if eventsFolder then
		local serverCommand = eventsFolder:FindFirstChild("ServerCommand")
		if serverCommand then
			serverCommand:FireClient(player, "Warn", Config.WARN_MESSAGE)
		end
	end
end

return Punisher
