local MarketplaceService = game:GetService("MarketplaceService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Assets = ReplicatedStorage.Assets
local Remotes = ReplicatedStorage.Remotes
local Server = ServerStorage.Server
local Shared = ReplicatedStorage.Shared

local Donates = require(Shared.Lists.Donates)
local GameRules = require(Shared.Lists.GameRules)
local pcalls = require(Shared.pcalls)
local PlayerStats = require(Shared.PlayerStats)
local Profiles = require(Server.Profiles)
local Tweens = require(Shared.Tweens)

local NUKE_TOPIC = "NUKE_LAUCHED"

do
  local nukeRemoteEvent = Remotes.NukeRemoteEvent

  local alarmSound = Assets.Sound.AlarmSound
  local explosionSound = Assets.Sound.ExplosionSound
  local nukeSound = Assets.Sound.NukeSound

  local nukePart = script.Nuke
  local explosionPart = script.ExplosionPart
  
  local SPAWN_POSITION = GameRules.NUKE_SPAWN_POSITION

  local NUKE_TWEEN_INFO = TweenInfo.new(
    8, 
    Enum.EasingStyle.Linear
  )
  local EXPLOSION_TWEEN_INFO = TweenInfo.new(
    explosionSound.TimeLength, 
    Enum.EasingStyle.Linear
  )
  
  function launchNuke(playerName: string, isGlobal: boolean)
    local isEnded = false
    local message = ""
    if isGlobal then
      message = `{playerName} has launched a GLOBAL a nuke!`
    else
      message = `{playerName} has launched a nuke!`
    end
    nukeRemoteEvent:FireAllClients("NUKE_MESSAGE", message)

    local alarmSound = alarmSound:Clone()
    alarmSound.Parent = Workspace.Runtime
    alarmSound.Looped = true
    alarmSound:Play()

    task.wait(8)

    local newNukePart = nukePart:Clone()

    local nukeSound = nukeSound:Clone()
    nukeSound.Parent = newNukePart
    nukeSound.Looped = true
    nukeSound:Play()

    newNukePart.Position = SPAWN_POSITION + Vector3.new(0, newNukePart.Size.Y * 5, 0)
    newNukePart.Anchored = true
    newNukePart.Parent = Workspace.Runtime

    Tweens.animateOnceWithYielding(newNukePart, NUKE_TWEEN_INFO, {
      Position = SPAWN_POSITION + Vector3.new(0, newNukePart.Size.Y / 2 + 7, 0)
    })
    newNukePart:Destroy()

    nukeRemoteEvent:FireAllClients("SHAKE_CAMERA")

    local explosionPart = explosionPart:Clone()
    explosionPart.Anchored = true
    explosionPart.CanCollide = false
    explosionPart.Size = Vector3.new(0, 0, 0)
    explosionPart.Position = SPAWN_POSITION
    explosionPart.Parent = Workspace.Runtime

    local explosionSound = explosionSound:Clone()
    explosionSound.Parent = explosionPart
    explosionSound:Play()

    local oldRespawnTime = Players.RespawnTime
    Players.RespawnTime = explosionSound.TimeLength

    Tweens.animateOnce(explosionPart, EXPLOSION_TWEEN_INFO, {
      Size = Vector3.new(2048, 2048, 2048)
    })

    local threads = {}

    for _, player in ipairs(Players:GetPlayers()) do
      local character = player.Character
      if not character then
        continue
      end
      local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
      if not humanoid then
        continue
      end

      local distance = 
        (
          character:GetPivot().Position 
          - explosionPart.Position
        ).Magnitude
      
      local thread = task.spawn(function()
        while not isEnded do
          if 
            explosionPart.Size.X / 2 
            >= distance - 30 
          then
            break
          end
          task.wait(0.2)
        end
        nukeRemoteEvent:FireClient(
          player, 
          "LIGHTING_EFFECT"
        )

        task.wait(1)
        humanoid.Health = 0
      end)
      table.insert(threads, thread)
    end

    explosionSound.Ended:Wait()

    Players.RespawnTime = oldRespawnTime
    alarmSound:Stop()
    alarmSound:Destroy()

    explosionSound:Stop()
    explosionPart:Destroy()

    isEnded = true
    task.wait(5)
  end
end
