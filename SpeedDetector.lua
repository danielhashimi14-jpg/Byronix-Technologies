--[[
	BYRONIX — Speed Detector
	Detects players moving faster than their WalkSpeed allows.
]]

local Config = require(game.ReplicatedStorage.Superion.Config)
local Shared = require(game.ReplicatedStorage.Superion.Shared)
local Logger = require(script.Parent.Logger)
local Punisher = require(script.Parent.Punisher)
local PlayerData = require(script.Parent.PlayerData)

local SpeedDetector = {}

function SpeedDetector.Check(player)
	if not Config.SPEED_ENABLED then return end

	local data = PlayerData.Get(player)
	if not data or not data.isMonitored then return end

	local character = player.Character
	if not character then return end

	local humanoid, hrp = Shared.GetCharacterComponents(character)
	if not humanoid or not hrp then return end
	if humanoid.Health <= 0 then return end
	if humanoid:GetState() == Enum.HumanoidStateType.Freefall then return end
	if humanoid:GetState() == Enum.HumanoidStateType.Jumping then return end

	local now = tick()
	local dt = now - data.lastCheckTime
	if dt < 0.1 then return end -- too soon

	local currentPosition = hrp.Position

	if data.lastPosition then
		local distance = Shared.HorizontalDistance(data.lastPosition, currentPosition)
		local speed = distance / dt
		local maxSpeed = humanoid.WalkSpeed * Config.SPEED_THRESHOLD

		-- Add a small buffer for physics variance
		maxSpeed += 4

		if speed > maxSpeed then
			local code = Config.CODES.SPEED
			Logger.Log(player, "Speed", string.format(
				"Moving at %.1f studs/s (max: %.1f)", speed, maxSpeed
			), code)
			PlayerData.AddViolation(player, "Speed")
			Punisher.Punish(player, "Speed", code)
		end
	end

	data.lastPosition = currentPosition
end

return SpeedDetector
