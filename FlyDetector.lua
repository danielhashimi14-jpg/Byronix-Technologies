--[[
	SUPERION — Fly Detector
	Detects players floating in the air beyond the grace period.
]]

local Config = require(game.ReplicatedStorage.Superion.Config)
local Shared = require(game.ReplicatedStorage.Superion.Shared)
local Logger = require(script.Parent.Logger)
local Punisher = require(script.Parent.Punisher)
local PlayerData = require(script.Parent.PlayerData)

local FlyDetector = {}

local RAY_PARAMS = RaycastParams.new()
RAY_PARAMS.FilterType = Enum.RaycastFilterType.Exclude

function FlyDetector.Check(player)
	if not Config.FLY_ENABLED then return end

	local data = PlayerData.Get(player)
	if not data or not data.isMonitored then return end

	local character = player.Character
	if not character then return end

	local humanoid, hrp = Shared.GetCharacterComponents(character)
	if not humanoid or not hrp then return end
	if humanoid.Health <= 0 then return end

	-- Skip if swimming or climbing
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Swimming
		or state == Enum.HumanoidStateType.Climbing
		or state == Enum.HumanoidStateType.Seated then
		data.airborneTime = 0
		return
	end

	-- Raycast downward to check for ground
	RAY_PARAMS.FilterDescendantsInstances = {character}
	local rayResult = workspace:Raycast(
		hrp.Position,
		Vector3.new(0, -Config.FLY_MIN_HEIGHT, 0),
		RAY_PARAMS
	)

	local isOnGround = rayResult ~= nil
		or state == Enum.HumanoidStateType.Landed
		or state == Enum.HumanoidStateType.Running
		or state == Enum.HumanoidStateType.RunningNoPhysics

	if isOnGround then
		data.airborneTime = 0
	else
		data.airborneTime += Config.LOOP_INTERVAL
	end

	if data.airborneTime >= Config.FLY_GRACE_PERIOD and not isOnGround then
		local code = Config.CODES.FLY
		Logger.Log(player, "Fly", string.format(
			"Airborne for %.1fs without ground contact",
			data.airborneTime
		), code)
		PlayerData.AddViolation(player, "Fly")
		Punisher.Punish(player, "Fly", code)
	end
end

return FlyDetector
