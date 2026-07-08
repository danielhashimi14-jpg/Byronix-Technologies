--[[
	BYRONIX — Property Detector
	Detects unauthorized changes to WalkSpeed, JumpPower,
	and other critical character properties.
]]

local Config = require(game.ReplicatedStorage.Superion.Config)
local Shared = require(game.ReplicatedStorage.Superion.Shared)
local Logger = require(script.Parent.Logger)
local Punisher = require(script.Parent.Punisher)
local PlayerData = require(script.Parent.PlayerData)

local PropertyDetector = {}

function PropertyDetector.Check(player)
	if not Config.PROPERTY_ENABLED then return end

	local data = PlayerData.Get(player)
	if not data or not data.isMonitored then return end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- WalkSpeed check
	local ws = humanoid.WalkSpeed
	if ws < Config.WALKSPEED_MIN or ws > Config.WALKSPEED_MAX then
		local code = Config.CODES.PROPERTY
		Logger.Log(player, "Property", string.format(
			"WalkSpeed out of range: %.1f (allowed: %d-%d)",
			ws, Config.WALKSPEED_MIN, Config.WALKSPEED_MAX
		), code)
		-- Reset to safe value
		humanoid.WalkSpeed = math.clamp(ws, Config.WALKSPEED_MIN, Config.WALKSPEED_MAX)
		PlayerData.AddViolation(player, "Property")
		Punisher.Punish(player, "Property", code)
	end

	-- JumpPower check
	local jp = humanoid.JumpPower
	if jp < Config.JUMPPOWER_MIN or jp > Config.JUMPPOWER_MAX then
		local code = Config.CODES.PROPERTY
		Logger.Log(player, "Property", string.format(
			"JumpPower out of range: %.1f (allowed: %d-%d)",
			jp, Config.JUMPPOWER_MIN, Config.JUMPPOWER_MAX
		), code)
		humanoid.JumpPower = math.clamp(jp, Config.JUMPPOWER_MIN, Config.JUMPPOWER_MAX)
		PlayerData.AddViolation(player, "Property")
		Punisher.Punish(player, "Property", code)
	end

	-- Check for suspicious attributes on HumanoidRootPart
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		-- Check for BodyMovers that shouldn't be there (fly hacks)
		for _, child in hrp:GetChildren() do
			if child:IsA("BodyVelocity") or child:IsA("BodyForce") or child:IsA("RocketPropulsion") then
				local code = Config.CODES.PROPERTY
				Logger.Log(player, "Property", string.format(
					"Suspicious BodyMover on HumanoidRootPart: %s (%s)",
					child.Name, child.ClassName
				), code)
				child:Destroy()
				PlayerData.AddViolation(player, "Property")
				Punisher.Punish(player, "Property", code)
			end
		end
	end
end

return PropertyDetector
