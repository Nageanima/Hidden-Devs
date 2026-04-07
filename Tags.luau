if not game:IsLoaded() then
  game.Loaded:Wait()
end

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local PlayerStats = require(Shared.PlayerStats)
local Tweens = require(Shared.Tweens)

local Configuration = require(script.Configuration)

local localPlayer = Players.LocalPlayer

local tagAddedHandlers = {} :: {[string]: (newPart: BasePart) -> ()}

local function isLocalPlayerTouched(touch: BasePart)
  local character = touch:FindFirstAncestorOfClass("Model")
  if not character then
    return false
  end
  local player = Players:GetPlayerFromCharacter(character)
  return player == localPlayer
end

do
  tagAddedHandlers[Configuration.TAGS.KILL_PART] = function(newPart: BasePart)
    local damage = newPart:GetAttribute(Configuration.ATTRIBUTES.KILL_PART.DAMAGE) or 0
    
    local isTouching = false
    newPart.Touched:Connect(function(otherPart: BasePart)
      if isTouching then
        return
      end
      if not isLocalPlayerTouched(otherPart) then
        return
      end
      if PlayerStats.Stats.Settings:getKey(localPlayer, "Invincibillity") then
        return
      end
      isTouching = true
      local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid")
      if not  humanoid then
        return
      end
      while isTouching do
        humanoid.Health -= damage
        task.wait(0.5)
      end
    end)
    newPart.TouchEnded:Connect(function(otherPart: BasePart) 
      isTouching = false
    end)
  end
end

do
  tagAddedHandlers[Configuration.TAGS.OUT_OF_BOUNDS] = function(newPart: BasePart)
    newPart.Touched:Connect(function(otherPart: BasePart)
      if not isLocalPlayerTouched(otherPart) then
        return
      end
      local humanoid = localPlayer.Character:FindFirstChildOfClass("Humanoid") :: Humanoid
      if not humanoid then
        return
      end
      humanoid:ChangeState(Enum.HumanoidStateType.Dead)
    end)
  end
end

do
  tagAddedHandlers[Configuration.TAGS.ICY_PART] = function(newPart: BasePart)
    newPart.CustomPhysicalProperties = PhysicalProperties.new(
      0.7,
      0,
      0.5,
      100,
      1
    )
  end
end

do
  local MAX_FORCE = 10 ^ 10
  tagAddedHandlers[Configuration.TAGS.AIR_LIFT] = function(newPart: BasePart)
    newPart.Touched:Connect(function(otherPart: BasePart)
      if not isLocalPlayerTouched(otherPart) then
        return
      end
      local strength = newPart:GetAttribute(Configuration.ATTRIBUTES.AIR_LIFT.STRENGTH) or 0
      local character = otherPart:FindFirstAncestorOfClass("Model")
      local torso = character.PrimaryPart or otherPart
      
      if torso:FindFirstChild("ElevatorVelocity") then
        return
      end
      local velocity = Instance.new("BodyVelocity", torso)
      velocity.Name = "ElevatorVelocity"
      local upVector = newPart.CFrame.UpVector
      
      local maxForce = Vector3.new(0, math.huge, 0)
      if upVector.X ~= 0 then
        maxForce = Vector3.new(math.huge, maxForce.Y, maxForce.Z)
      elseif upVector.Z ~= 0 then
        maxForce = Vector3.new(maxForce.X, maxForce.Y, math.huge)
      end
      velocity.MaxForce = maxForce
      velocity.Velocity = upVector * strength
    end)
    
    newPart.TouchEnded:Connect(function(otherPart: BasePart) 
      if not isLocalPlayerTouched(otherPart) then
        return
      end
      local character = otherPart:FindFirstAncestorOfClass("Model")
      local torso = character.PrimaryPart or otherPart
      local velocityConstraint = torso:FindFirstChild("ElevatorVelocity")
      if velocityConstraint then 
        velocityConstraint:Destroy()
      end
    end)
  end
end


do
  tagAddedHandlers[Configuration.TAGS.FADING_PART] = function(newPart: BasePart)
    local selectionBox = newPart:WaitForChild("SelectionBox", 5) :: SelectionBox
    
    local fadingTime = newPart:GetAttribute(Configuration.ATTRIBUTES.FADING_PART.FADING_TIME) or 1
    
    local tweenInfo = TweenInfo.new(fadingTime, Enum.EasingStyle.Linear)
    
    local isFading = false
    newPart.Touched:Connect(function(otherPart: BasePart)
      if isFading then
        return
      end
      if not isLocalPlayerTouched(otherPart) then
        return
      end
      isFading = true
      Tweens.animateOnceWithYielding(newPart, tweenInfo, {
        Transparency = 1
      })
      
      newPart.CanCollide = false
      if selectionBox then
        selectionBox.Color3 = Color3.fromRGB(255, 0, 0)
      end
      
      task.wait(0.85)
      
      newPart.CanCollide = true
      if selectionBox then
        selectionBox.Color3 = Color3.fromRGB(0, 0, 0)
      end
      newPart.Transparency = 0
      
      isFading = false
    end)
  end
end

do
  tagAddedHandlers[Configuration.TAGS.CONVEYOR] = function(newPart: BasePart)
    local orientationOffset = CFrame.Angles(0, math.pi, 0)
    local lookVector = (newPart.CFrame * orientationOffset).LookVector
    
    local strength = newPart:GetAttribute(Configuration.ATTRIBUTES.CONVEYOR.SPEED) or 0
    
    newPart.Anchored = true
    newPart.AssemblyLinearVelocity = lookVector * strength
  end
end

do
  tagAddedHandlers[Configuration.TAGS.BUTTON] = function(newPart: PVInstance)
    local linkedWallObjectValue = newPart:WaitForChild("LinkedWall", 10) :: ObjectValue
    if not linkedWallObjectValue then
      error("Buttons must have object value called 'LinkedWall' to work!")
    end
    local wall = linkedWallObjectValue.Value :: BasePart
    while not wall do
      task.wait(0.25)
      wall = linkedWallObjectValue.Value
    end
    
    local standPart = newPart:WaitForChild("Stand") :: BasePart
    local buttonPart = newPart:WaitForChild("Button") :: BasePart
    
    buttonPart.Touched:Connect(function(otherPart: BasePart) 
      if not isLocalPlayerTouched(otherPart) then
        return
      end
      wall.CanCollide = false
      wall.Transparency = 1

      buttonPart.Position = standPart.Position + Vector3.new(
        0,
        0.1,
        0
      )
    end)
  end
  
  local function resetButtons()
    for _, button in ipairs(CollectionService:GetTagged(Configuration.TAGS.BUTTON)) do
      local linkedWallObjectValue = button:WaitForChild("LinkedWall") :: ObjectValue
      local standPart = button:WaitForChild("Stand") :: BasePart
      local buttonPart = button:WaitForChild("Button") :: BasePart

      local wall = linkedWallObjectValue.Value :: BasePart
      wall.CanCollide = true
      wall.Transparency = 0

      buttonPart.Position = standPart.Position + Vector3.new(
        0,
        standPart.Size.Y / 2 + buttonPart.Size.Y / 2,
        0
      )
    end  
  end
  
  localPlayer:GetPropertyChangedSignal("Character"):Connect(resetButtons)
  PlayerStats.Stats.CurrentCheckpoint:bindToChange(localPlayer, resetButtons)
end

do
  tagAddedHandlers[Configuration.TAGS.SLIDING_PART] = function(newPart: BasePart)
    newPart.Touched:Connect(function(otherPart: BasePart) 
      if not isLocalPlayerTouched(otherPart) then
        return
      end  
      local character = otherPart:FindFirstAncestorOfClass("Model")
      local humanoid = character:FindFirstChildOfClass("Humanoid")
      if not humanoid then
        return
      end
      humanoid.Sit = true
    end)
  end
end


do
  tagAddedHandlers[Configuration.TAGS.ROPE_PART] = function(newPart: PVInstance)
    local anchor = newPart:WaitForChild("Anchor")
    local platform = newPart:WaitForChild("Platform") :: BasePart
    
    local newPlatform = platform:Clone()
    
    for i = 1, 4, 1 do
      local attachmentI = newPlatform:WaitForChild(`Attachment{i}`) :: Attachment
      local ropeConstraintI = anchor:WaitForChild(`RopeConstraint{i}`) :: RopeConstraint
      
      ropeConstraintI.Attachment1 = attachmentI
    end
    
    local attachment1 = newPlatform:WaitForChild("Attachment1") :: Attachment
    
    local linearVelocity = Instance.new("LinearVelocity")
    linearVelocity.Attachment0 = attachment1
    linearVelocity.Parent = newPlatform
    
    platform:Destroy()
    newPlatform.Parent = newPart
    newPlatform.Anchored = false
  end
end

do
  local TWEEN_INFO = TweenInfo.new(1.25, Enum.EasingStyle.Sine)
  local yOffset = Vector3.yAxis * 15
  
  tagAddedHandlers[Configuration.TAGS.FALLING_PART] = function(newPart)
    local isDebounce = false
    newPart.Touched:Connect(function(otherPart: BasePart) 
      if not isLocalPlayerTouched(otherPart) then
        return
      end
      if isDebounce then
        return
      end
      isDebounce = true
      task.wait(0.05)
      Tweens.animateOnceWithYielding(newPart, TWEEN_INFO, {
        Position = newPart.Position - yOffset,
        Transparency = 1,
      })
      newPart.CanCollide = false
      task.wait(1)
      Tweens.animateOnceWithYielding(newPart, TWEEN_INFO, {
        Position = newPart.Position + yOffset,
        Transparency = 0,
      })
      newPart.CanCollide = true
      
      isDebounce = false
    end)
  end
end

for _, tag in pairs(Configuration.TAGS) do
  for _, instance in ipairs(CollectionService:GetTagged(tag)) do
    if tagAddedHandlers[tag] then
      task.spawn(tagAddedHandlers[tag], instance)
    end
  end
end

for _, tag in pairs(Configuration.TAGS) do
  if tagAddedHandlers[tag] then
    CollectionService:GetInstanceAddedSignal(tag):Connect(tagAddedHandlers[tag])
  end
end
