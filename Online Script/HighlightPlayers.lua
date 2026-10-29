local HighlightPlayers = {}

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local playerHighlights = {}
local highlightConnection = nil
local isEnabled = false
local Fluent = nil
local Options = nil

local CharacterService
pcall(function()
    CharacterService = require(ReplicatedStorage.Services.Asset.CharacterService)
end)

local function isPlayerDowned(player)
    if not player or player == LocalPlayer then return false end
    
    local playersFolder = workspace:FindFirstChild("Players")
    if playersFolder then
        local model = playersFolder:FindFirstChild(player.Name)
        if model then
            if model:GetAttribute("Downed") then
                return true
            end
            
            if CharacterService then
                local char = CharacterService:GetCharacterFromTag(model:GetAttribute("Tag"))
                if char and char.State then
                    return char.State.State == "Downed"
                end
            end
        end
    end
    
    return false
end

local function getPlayerModel(player)
    local playersFolder = workspace:FindFirstChild("Players")
    if playersFolder then
        return playersFolder:FindFirstChild(player.Name)
    end
    return nil
end

local function updatePlayerHighlight(player)
    if not player or player == LocalPlayer then return end
    if not isEnabled then return end
    
    local model = getPlayerModel(player)
    if not model then return end
    
    local isDowned = isPlayerDowned(player)
    
    if playerHighlights[player] then
        local highlight = playerHighlights[player]
        if highlight and highlight.Parent then
            highlight.FillColor = isDowned and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 255, 255)
            highlight.OutlineColor = isDowned and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(200, 200, 200)
            return
        else
            playerHighlights[player] = nil
        end
    end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "PlayerHighlight_" .. player.Name
    highlight.Parent = model
    highlight.FillTransparency = 0.3
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = isDowned and Color3.fromRGB(255, 255, 0) or Color3.fromRGB(255, 255, 255)
    highlight.OutlineColor = isDowned and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(200, 200, 200)
    
    playerHighlights[player] = highlight
end

local function removePlayerHighlight(player)
    if playerHighlights[player] then
        local highlight = playerHighlights[player]
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
        playerHighlights[player] = nil
    end
end

local function clearAllHighlights()
    for player, highlight in pairs(playerHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
    end
    playerHighlights = {}
end

local function updateAllHighlights()
    if not isEnabled then return end
    
    local currentPlayers = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            currentPlayers[player] = true
            updatePlayerHighlight(player)
        end
    end
    
    for player in pairs(playerHighlights) do
        if not currentPlayers[player] then
            removePlayerHighlight(player)
        end
    end
end

function HighlightPlayers.init(fluentLib, options)
    Fluent = fluentLib
    Options = options
end

function HighlightPlayers.Start()
    if isEnabled then return end
    isEnabled = true
    
    updateAllHighlights()
    
    if highlightConnection then
        highlightConnection:Disconnect()
    end
    
    highlightConnection = RunService.Heartbeat:Connect(function()
        if isEnabled then
            updateAllHighlights()
        end
    end)
    
    if Fluent then
        Fluent:Notify({ Title = "Highlight Players", Content = "Enabled", Duration = 3 })
    end
end

function HighlightPlayers.Stop()
    if not isEnabled then return end
    isEnabled = false
    
    if highlightConnection then
        highlightConnection:Disconnect()
        highlightConnection = nil
    end
    
    clearAllHighlights()
    
    if Fluent then
        Fluent:Notify({ Title = "Highlight Players", Content = "Disabled", Duration = 3 })
    end
end

function HighlightPlayers.Toggle()
    if isEnabled then
        HighlightPlayers.Stop()
    else
        HighlightPlayers.Start()
    end
    return isEnabled
end

function HighlightPlayers.IsEnabled()
    return isEnabled
end

function HighlightPlayers.Refresh()
    if isEnabled then
        updateAllHighlights()
    end
end

return HighlightPlayers
