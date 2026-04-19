--!strict
--[[
    This script handles part tags (CollectionService) for 
    special behavior and provides tags that when applied 
    would provide interactable pieces of some common obby elements
--]]

-- =========================== TWEENING UTILITIES ===========================
local TweenService = game:GetService("TweenService")

local function createTween(
	object: Instance, 
	tweenInfo: TweenInfo,
	props: {[string]: any} 
)
	return TweenService:Create(
		object, 
		tweenInfo, 
		props
	)
end

local function createSinglePlayTween(
	object: Instance, 
	tweenInfo: TweenInfo,
	props: {[string]: any}
)
	local tween = createTween(object, tweenInfo, props)
	tween.Completed:Once(function() tween:Destroy() end)
	return tween
end

local function animateOnce(
	object: Instance, 
	tweenInfo: TweenInfo,
	props: {[string]: any}
)
	local tween = createSinglePlayTween(
		object, 
		tweenInfo, 
		props
	)
	tween:Play()
	return tween
end

local function animateOnceWithYielding(
	object: Instance, 
	tweenInfo: TweenInfo,
	props: {[string]: any}
)
	local tween = createSinglePlayTween(object, tweenInfo, props)
	tween:Play()
	tween.Completed:Wait()
end

-- =========================== CONFIGURATION ===========================
-- Contains tag names and attribute keys
-- So user can change names if needed 
-- (just change symbols in the "")
local TAGS = {
	KILL_PART = "KILL_PART",
	ICY_PART = "ICY_PART",
	AIR_LIFT = "AIR_LIFT",
	FADING_PART = "FADING_PART",
	CONVEYOR = "CONVEYOR",
	BUTTON = "BUTTON",
	SLIDING_PART = "SLIDING_PART",
	ROPE_PART = "ROPE_PART",
	FALLING_PART = "FALLING_PART",
	OUT_OF_BOUNDS = "OUT_OF_BOUNDS",
}
-- This demonstrates which attributes will be used by some tags
local ATTRIBUTES = {
	KILL_PART = { DAMAGE = "DAMAGE" --[[Number]] },
	AIR_LIFT = { STRENGTH = "STRENGTH" --[[Number]] },
	FADING_PART = { FADING_TIME = "FADING_TIME" --[[Number]] },
	CONVEYOR = { SPEED = "SPEED" --[[Number]] },
}
-- You can configure default values and they will apply to game
local DEFAULT_VALUES = {
	KILL_PART = {DAMAGE = 10},
	AIR_LIFT = {STRENGTH = 0},
	FADING_PART = {
		FADING_TIME = 1,
		PAUSE_BEFORE_FADE_IN = 0.85,
		SELECTION_BOX_FADED_COLOR = Color3.fromRGB(255, 0, 0),
		SELECTION_BOX_DEFAULT_COLOR = Color3.fromRGB(0, 0, 0),
	},
	CONVEYOR = {
		SPEED = 0,
		DIRECTION_OFFSET = CFrame.Angles(
			0, 
			math.pi, 
			0
		),	-- We use 180 degrees because our mesh is rotated by default
	},
	ICY_PART = {
		PROPERTIES = PhysicalProperties.new(
			0.7,  -- Density
			0,  -- Friction
			0.5, -- Elasticity
			100, -- Friction Weight
			1 -- Elasticity Weight
		)
	},
	SLIDING_PART = {
		SLIDE_TIME = 2,	
	},
	FALLING_PART = {
		FALLING_TWEEN_INFO = TweenInfo.new(
			1.25,
			Enum.EasingStyle.Sine
		),	
		FALL_OFFSET = Vector3.new(
			0, 
			-15,
			0
		),
		TIME_BEFORE_RETURN = 1,
	},
}

-- =========================== MAIN LOGIC ===========================
if not game:IsLoaded() then 
	game.Loaded:Wait() 
end

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer

-- Dictionary of tag handlers
-- Each handler is called when a new tagged instance appears
local tagAddedHandlers = {} :: {[string]: (Instance) -> ()}

-- Checks if the touched part belongs 
-- to the local player's character
local function isLocalPlayerTouched(touchPart)
	local character = touchPart:FindFirstAncestorOfClass("Model")
	if not character then 
		return false 
	end
	local player = Players:GetPlayerFromCharacter(character)
	return player == localPlayer
end

-- Handlers separated by do...end block 
-- so variables and functions would not mixed

-- Also tag-parts behvior will not be explained 
-- (I mean why they had this behovior)
-- Because their behvoir was suitable for our games only
-- (Some of tag-parts may be diffrent from "default" obbies)

do -- ================ KILL_PART HANDLER ================
	-- Deals periodic damage while touching, 
	-- unless the player has invincibility
	
	local function doDamageLoop(damage: number)
		local character = localPlayer.Character
		if not character then
			return false
		end
		local humanoid = 
			character:FindFirstChildOfClass("Humanoid")

		if not humanoid then 
			return false 
		end
		if 
			localPlayer:GetAttribute("Invincibility") 
			== true 
		then 
			return false 
		end

		humanoid.Health = math.max(
			0, 
			humanoid.Health - damage
		)
		task.wait(0.5)
		return true
	end

	tagAddedHandlers[TAGS.KILL_PART] = function(newPart: Instance)
		if not newPart:IsA("BasePart") then
			return
		end

		local damage = newPart:GetAttribute(
			ATTRIBUTES.KILL_PART.DAMAGE
		) or DEFAULT_VALUES.KILL_PART.DAMAGE

		local active = false          -- flag indicating player is inside the kill zone
		local connectionTouch = nil   -- stored for cleanup
		local connectionLeave = nil

		connectionTouch = newPart.Touched:Connect(function(otherPart)
			if not isLocalPlayerTouched(otherPart) then 
				return 
			end
			if active then 
				return 
			end
			active = true

			while active do
				-- We want to check if we need to continue this loop
				-- We do not want if character are dead or missing
				local isShouldContinue = doDamageLoop(damage)
				if not isShouldContinue then
					break
				end
			end
		end)

		connectionLeave = newPart.TouchEnded:Connect(function(otherPart)
			if not isLocalPlayerTouched(otherPart) then 
				return 
			end
			active = false
		end)

		-- Cleanup if ever needed
		-- Made for so other scripts may delete killparts
		-- And do not cause memory leaks
		newPart.Destroying:Once(function()
			connectionTouch:Disconnect()
			connectionLeave:Disconnect()
		end)
	end
end

do  -- ============= OUT_OF_BOUNDS HANDLER =============
	-- Instantly kills the player on touch
	tagAddedHandlers[TAGS.OUT_OF_BOUNDS] = function(
		newPart: Instance
	)
		if not newPart:IsA("BasePart") then
			return
		end

		newPart.Touched:Connect(function(otherPart)
			if not isLocalPlayerTouched(otherPart) then 
				return 
			end
			local character = localPlayer.Character
			if not character then
				return
			end
			local humanoid = 
				character:FindFirstChildOfClass("Humanoid")

			--Note: We can use ChangeState because
			--player always has network ownership
			--over his character and humanoid
			--so if we change state here it will replicate to server
			if humanoid then
				humanoid:ChangeState(
					Enum.HumanoidStateType.Dead
				)
			end
		end)
	end
end

do  -- ================ ICY_PART HANDLER ================
	-- Make the part slippery
	tagAddedHandlers[TAGS.ICY_PART] = function(newPart: Instance)
		if not newPart:IsA("BasePart") then
			return
		end
		newPart.CustomPhysicalProperties = 
			DEFAULT_VALUES.ICY_PART.PROPERTIES
	end
end

do  -- ================= AIR_LIFT HANDLER =================
	-- Makes player float (upwards) inside part
	local function applyLift(
		from: BasePart, 
		touchPart: BasePart, 
		strength: number
	)
		local character = 
			touchPart:FindFirstAncestorOfClass("Model")
		if not character then 
			return 
		end
		local primary = 
			character.PrimaryPart 
			or character:FindFirstChildOfClass("BasePart")

		if not primary then 
			return 
		end
		if primary:FindFirstChild("AirLiftVelocity") then 
			return 
		end

		local attachment = 
			primary:FindFirstChild("VelocityAttachment") :: Attachment?
		
		if not attachment or not attachment:IsA("Attachment") then
			attachment = Instance.new("Attachment")
			attachment.Name = "VelocityAttachment"
			attachment.Parent = primary
		end

		local constraint = Instance.new("LinearVelocity")
		constraint.Name = "AirLiftVelocity"
		constraint.Attachment0 = attachment

		constraint.MaxForce = 1e10
		constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		constraint.VectorVelocity = from.CFrame.UpVector * strength

		constraint.Parent = primary
	end

	local function removeLift(touchPart: BasePart)
		local character = 
			touchPart:FindFirstAncestorOfClass("Model")
		if not character then 
			return 
		end
		local primary = 
			character.PrimaryPart 
			or character:FindFirstChildOfClass("BasePart")
		if primary then
			local constraint = 
				primary:FindFirstChild("AirLiftVelocity")

			if constraint and constraint:IsA("BodyVelocity") then 
				constraint:Destroy() 
			end
		end
	end

	tagAddedHandlers[TAGS.AIR_LIFT] = function(newPart: Instance)
		if not newPart:IsA("BasePart") then
			return
		end
		local strength = newPart:GetAttribute(
			ATTRIBUTES.AIR_LIFT.STRENGTH
		) or DEFAULT_VALUES.AIR_LIFT.STRENGTH
		
		if strength <= 0 then
			warn(
				`Air lift part's [{newPart}] strength should be greater than zero!`
			)
			return
		end

		newPart.Touched:Connect(function(otherPart)
			if not isLocalPlayerTouched(otherPart) then 
				return 
			end
			applyLift(newPart, otherPart, strength)
		end)
		newPart.TouchEnded:Connect(function(otherPart)
			if not isLocalPlayerTouched(otherPart) then 
				return 
			end
			removeLift(otherPart)
		end)
	end
end

do  -- =============== FADING_PART HANDLER ===============
	-- On touch: 
	-- -> fades oyt (transparency + no collision)
	-- -> waits
	-- -> then reappears
	tagAddedHandlers[TAGS.FADING_PART] = function(newPart: Instance)
		if not newPart:IsA("BasePart") then
			return
		end
		local fadingTime = newPart:GetAttribute(
			ATTRIBUTES.FADING_PART.FADING_TIME
		) or DEFAULT_VALUES.FADING_PART.FADING_TIME

		local tweenInfo = TweenInfo.new(
			fadingTime, 
			Enum.EasingStyle.Linear
		)
		local selectionBox = 
			newPart:FindFirstChild("SelectionBox") -- optional visual feedback
		
		-- Chech for case when there is instance named "SelectionBox" 
		-- but it is not actually needed instance type
		-- So we need to warn developer to fix this
		if 
			selectionBox 
			and not selectionBox:IsA("SelectionBox") 
		then
			warn(
				`There's no SelectionBox for Fading Part [{newPart}]`
			)
			return
		end

		local debounce = false
		newPart.Touched:Connect(function(otherPart)
			if not isLocalPlayerTouched(otherPart) then 
				return 
			end
			if debounce then 
				return 
			end
			debounce = true

			-- Fade out
			animateOnceWithYielding(
				newPart, 
				tweenInfo, 
				{ Transparency = 1 }
			)
			newPart.CanCollide = false
			if selectionBox then 
				selectionBox.Color3 = 
					DEFAULT_VALUES.FADING_PART.SELECTION_BOX_FADED_COLOR 
			end
			task.wait(
				DEFAULT_VALUES.FADING_PART.PAUSE_BEFORE_FADE_IN
			)  -- pause while invisible
			
			-- Fade in
			newPart.CanCollide = true
			newPart.Transparency = 0
			if selectionBox then 
				selectionBox.Color3 = 
					DEFAULT_VALUES.FADING_PART.SELECTION_BOX_DEFAULT_COLOR
			end

			debounce = false
		end)
	end
end

do  -- ================== CONVEYOR HANDLER ==================
	-- Moves player standing on it at a given speed
	tagAddedHandlers[TAGS.CONVEYOR] = function(newPart: Instance)
		if not newPart:IsA("BasePart") then
			return
		end
		local speed = newPart:GetAttribute(
			ATTRIBUTES.CONVEYOR.SPEED
		) or DEFAULT_VALUES.CONVEYOR.SPEED
		
		if speed <= 0 then
			warn(
				`Conveyor part's [{newPart}] speed should be greater than zero!`
			)
			return
		end

		-- Multiply by an offset rotation
		-- to produce desired movement direction
		local direction = 
			(newPart.CFrame * DEFAULT_VALUES.CONVEYOR.DIRECTION_OFFSET).LookVector

		newPart.Anchored = true
		-- Old trick when anchored part with velocity
		-- Will share their velocity to other parts that touched
		newPart.AssemblyLinearVelocity = direction * speed
	end
end

do  -- ==================== BUTTON HANDLER ====================
	--[[
		Button that opens a wall
		When pressed, the wall becomes transparent and not collidable
		Can be tricky to set up
		So we need to notify developer about problems
	]]
	tagAddedHandlers[TAGS.BUTTON] = function(
		buttonModel: Instance
	)
		local linkedWallValue = buttonModel:FindFirstChild(
			"LinkedWall"
		)
		if 
			not linkedWallValue 
			or not linkedWallValue:IsA("ObjectValue") 
		then
			warn(`Button missing LinkedWall ObjectValue: [{buttonModel}]`)
			return
		end
		local wall = linkedWallValue.Value
		if not wall or not wall:IsA("BasePart") then
			warn(
				`"LinkedWall" ObjectValue [{linkedWallValue}] does not point to a valid part`
			)
			return
		end

		local standPart = buttonModel:FindFirstChild("Stand")
		local buttonPart = buttonModel:FindFirstChild("Button")

		if not standPart or not standPart:IsA("BasePart") then
			warn(
				`There's no "Stand" part for button [{buttonModel}]`
			)
			return
		end
		if not buttonPart or not buttonPart:IsA("BasePart") then
			warn(
				`There's no "Button" part for button [{buttonModel}]`
			)
			return
		end

		-- Storing original button position for reset
		local originalButtonPos = buttonPart.Position

		buttonPart.Touched:Connect(function(otherPart)
			if not isLocalPlayerTouched(otherPart) then 
				return 
			end
			buttonModel:SetAttribute("Pressed", true)

			wall.CanCollide = false
			wall.Transparency = 1
			-- This for "press" effect
			buttonPart.Position = 
				standPart.Position + Vector3.new(0, 0.1, 0)
		end)

		local function resetButton()
			if not wall then 
				return 
			end
			wall.CanCollide = true
			wall.Transparency = 0
			if buttonPart then
				buttonPart.Position = originalButtonPos
			end
			buttonModel:SetAttribute("Pressed", false)
		end

		localPlayer:GetPropertyChangedSignal("Character"):Connect(resetButton)
		-- Monitor attribute "CurrentCheckpoint" 
		-- And resetting button when checkpoint changed
		-- (It was added while our team meeting)
		localPlayer:GetAttributeChangedSignal(
			"CurrentCheckpoint"
		):Connect(resetButton)
	end
end

do	-- ================ SLIDING_PART HANDLER ================
	-- Forces players to sit down when touching 
	-- Created mostly for slides
	tagAddedHandlers[TAGS.SLIDING_PART] = function(
		newPart: Instance
	)
		if not newPart:IsA("BasePart") then
			return
		end

		newPart.Touched:Connect(function(otherPart)
			if not isLocalPlayerTouched(otherPart) then 
				return 
			end
			local character = 
				otherPart:FindFirstAncestorOfClass("Model")
			if not character then
				return
			end
			local humanoid = 
				character:FindFirstChildOfClass("Humanoid")

			if not humanoid then 
				return 
			end
			humanoid.Sit = true
			task.wait(
				DEFAULT_VALUES.SLIDING_PART.SLIDE_TIME
			)
			if humanoid.Parent then  -- check that humanoid still exists
				humanoid.Sit = false
			end
		end)
	end
end

do 	-- ================== ROPE_PART HANDLER ==================
	--[[
		Rebuilds a platform attached to an anchor by ropes
		Because ropes created on client they will be smooth enough
		(when on server they would be laggy 
		because of constant network ownership transfer)
		
		Also can be tricky for set up
		So we want to notify developer correctly
	]]
	tagAddedHandlers[TAGS.ROPE_PART] = function(model: Instance)
		local anchor = model:FindFirstChild("Anchor")
		local platform = model:FindFirstChild("Platform")
		if not anchor or not anchor:IsA("BasePart") then
			warn(
				`There's no "Anchor" part for rope platform [{model}]`
			)
			return
		end
		if not platform or not platform:IsA("BasePart") then
			warn(
				`There's no "Platform" part for rope platform [{model}]`
			)
			return
		end

		local newPlatform = platform:Clone()
		newPlatform.Parent = model

		-- We need to Attach all RopeConstraints 
		-- from anchor to the new platform
		for i = 1, 4 do
			local attachmentName = "Attachment" .. i
			local ropeName = "RopeConstraint" .. i
			local attachment = 
				newPlatform:FindFirstChild(attachmentName)

			if 
				not attachment 
				or not attachment:IsA("Attachment")
			then
				warn(
					`There's no Attachment for #{i} rope in [{newPlatform}]`
				)
				newPlatform:Destroy()
				return
			end

			local rope = anchor:FindFirstChild(ropeName)
			if not rope or not rope:IsA("RopeConstraint") then
				warn(
					`There's no RopeConstraint for #{i} rope in [{newPlatform}]`
				)
				newPlatform:Destroy()
				return
			end
			rope.Attachment1 = attachment
		end

		-- Adds LinearVelocity for stabillity (optional)
		local attachment1 = 
			newPlatform:FindFirstChild("Attachment1")

		if attachment1 and attachment1:IsA("Attachment") then
			local constraint = Instance.new("LinearVelocity")
			constraint.Attachment0 = attachment1
			constraint.MaxForce = 10000
			constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
			constraint.VectorVelocity = Vector3.new(0, 5, 0)  -- lifts upward
			constraint.Parent = newPlatform
		end
		
		platform:Destroy() -- dont forget to destroy original part
		newPlatform.Anchored = false
	end
end

do	-- ================= FALLING_PART HANDLER =================
	-- When touched part "falls" down
	-- then returns to its original position
	tagAddedHandlers[TAGS.FALLING_PART] = function(
		newPart: Instance
	)
		if not newPart:IsA("BasePart") then
			return
		end
		local originalPos = newPart.Position
		local debounce = false

		newPart.Touched:Connect(function(otherPart)
			if not isLocalPlayerTouched(otherPart) then 
				return 
			end
			if debounce then 
				return 
			end
			debounce = true
			task.wait(0.05)

			animateOnceWithYielding(
				newPart, 
				DEFAULT_VALUES.FALLING_PART.FALLING_TWEEN_INFO, 
				{
					Position = originalPos + DEFAULT_VALUES.FALLING_PART.FALL_OFFSET,
					Transparency = 1,
				}
			)
			newPart.CanCollide = false
			task.wait(
				DEFAULT_VALUES.FALLING_PART.TIME_BEFORE_RETURN
			)

			animateOnceWithYielding(
				newPart, 
				DEFAULT_VALUES.FALLING_PART.FALLING_TWEEN_INFO, 
				{
					Position = originalPos,
					Transparency = 0,
				}
			)
			newPart.CanCollide = true

			debounce = false
		end)
	end
end

-- ==================== INITIALIZATION ====================
-- Process already existing tagged instances
-- If they loaded before this script initialized
for tagName, handler in pairs(tagAddedHandlers) do
	for _, instance in ipairs(CollectionService:GetTagged(tagName)) do
		task.spawn(handler, instance)
	end
end

--[[
	Subscribing to future tagged instances
    So if some instances loaded after script has initilized
    they would be processed
    (also because of this we can add tags during runtime, 
    which adds some interesting interactions)
]]
for tagName, handler in pairs(tagAddedHandlers) do
	CollectionService:GetInstanceAddedSignal(tagName):Connect(
		handler
	)
end