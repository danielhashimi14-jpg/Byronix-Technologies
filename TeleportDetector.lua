--[[
	BYRONIX — Teleport Detector
	Detects sudden large position changes (teleportation).
]]

local Config = require(game.ReplicatedStorage.Superion.Config)
local Shared = require(game.ReplicatedStorage.Superion.Shared)
local Logger = require(script.Parent.Logger)
local Punisher = require(script.Parent.Punisher)
local PlayerData = require(script.Parent.PlayerData)

local TeleportDetector = {}

function TeleportDetector.Check(player)
	if not Config.TELEPORT_ENABLED then return end

	local data = PlayerData.Get(player)
	if not data or not data.isMonitored then return end
	if not data.lastPosition then return end

	local character = player.Character
	if not character then return end

	local humanoid, hrp = Shared.GetCharacterComponents(character)
	if not humanoid or not hrp then return end
	if humanoid.Health <= 0 then return end

	local distance = Shared.Distance(data.lastPosition, hrp.Position)

	if distance > Config.TELEPORT_MAX_DISTANCE then
		-- Check if the player is in a vehicle or on a fast-moving platform
		local seat = character:FindFirstChildOfClass("Seat")
			or character:FindFirstChildOfClass("VehicleSeat")
		if seat then return end

		local code = Config.CODES.TELEPORT
		Logger.Log(player, "Teleport", string.format(
			"Moved %.1f studs in one tick (max: %d)",
			distance, Config.TELEPORT_MAX_DISTANCE
		), code)
		PlayerData.AddViolation(player, "Teleport")
		Punisher.Punish(player, "Teleport", code)
	end
end

return TeleportDetector
