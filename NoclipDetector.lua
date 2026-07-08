--[[
	BYRONIX — Noclip Detector
	Detects players moving through solid parts.
]]

local Config = require(game.ReplicatedStorage.Superion.Config)
local Shared = require(game.ReplicatedStorage.Superion.Shared)
local Logger = require(script.Parent.Logger)
local Punisher = require(script.Parent.Punisher)
local PlayerData = require(script.Parent.PlayerData)

local NoclipDetector = {}

local RAY_PARAMS = RaycastParams.new()
RAY_PARAMS.FilterType = Enum.RaycastFilterType.Exclude

function NoclipDetector.Check(player)
	if not Config.NOCLIP_ENABLED then return end

	local data = PlayerData.Get(player)
	if not data or not data.isMonitored then return end

	local character = player.Character
	if not character then return end

	local humanoid, hrp = Shared.GetCharacterComponents(character)
	if not humanoid or not hrp then return end
	if humanoid.Health <= 0 then return end

	-- Skip if in a seat or swimming
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Seated
		or state == Enum.HumanoidStateType.Swimming then
		data.noclipCounter = 0
		return
	end

	-- Cast rays in the movement direction to check for walls
	local velocity = hrp.AssemblyLinearVelocity
	local moveDir = velocity.Magnitude > 1 and velocity.Unit or hrp.CFrame.LookVector

	RAY_PARAMS.FilterDescendantsInstances = {character}

	-- Cast ray in movement direction
	local rayResult = workspace:Raycast(
		hrp.Position,
		moveDir * 3,
		RAY_PARAMS
	)

	if rayResult and rayResult.Instance and rayResult.Instance.CanCollide then
		-- Player is inside or very close to a solid part
		data.noclipCounter += 1

		if data.noclipCounter >= Config.NOCLIP_FRAMES then
			local code = Config.CODES.NOCLIP
			Logger.Log(player, "Noclip", string.format(
				"Inside solid part for %d frames: %s",
				data.noclipCounter, rayResult.Instance:GetFullName()
			), code)
			PlayerData.AddViolation(player, "Noclip")
			Punisher.Punish(player, "Noclip", code)
		end
	else
		data.noclipCounter = math.max(0, data.noclipCounter - 1)
	end
end

return NoclipDetector
