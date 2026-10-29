local EmoteChanger = {}

local emoteRegistry = {}
local originalEmoteContents = {}

function EmoteChanger.scan()
    emoteRegistry = {}
    local found = false

    local roots = {
        game:GetService("ReplicatedStorage"):FindFirstChild("Items")
            and game:GetService("ReplicatedStorage").Items:FindFirstChild("ItemPacks"),
        game:GetService("ReplicatedStorage"):FindFirstChild("Items")
            and game:GetService("ReplicatedStorage").Items:FindFirstChild("BaseItems"),
    }

    local function collectModules(parent, pathPrefix)
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("ModuleScript") then
                local key = child.Name
                if emoteRegistry[key] then
                    local i = 2
                    while emoteRegistry[key .. " (" .. i .. ")"] do
                        i = i + 1
                    end
                    key = key .. " (" .. i .. ")"
                end
                emoteRegistry[key] = {
                    module = child,
                    path = pathPrefix .. "." .. child.Name,
                    realName = child.Name,
                }
                found = true
            elseif child:IsA("Folder") then
                collectModules(child, pathPrefix .. "." .. child.Name)
            end
        end
    end

    local function walk(parent, pathPrefix, depth)
        if depth > 15 then return end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Folder") then
                if child.Name == "Emotes" then
                    collectModules(child, pathPrefix .. "." .. child.Name)
                else
                    walk(child, pathPrefix .. "." .. child.Name, depth + 1)
                end
            end
        end
    end

    for _, root in ipairs(roots) do
        if root then
            pcall(function()
                walk(root, "ReplicatedStorage.Items." .. root.Name, 0)
            end)
        end
    end

    local names = {}
    for name, _ in pairs(emoteRegistry) do
        table.insert(names, name)
    end
    table.sort(names)

    return names, found
end

local function saveOriginalEmote(name)
    if originalEmoteContents[name] then return end
    local entry = emoteRegistry[name]
    if not entry then return end

    local saved = {
        children = {},
        name = nil,
        desc = nil,
        creator = nil,
        speedMult = nil,
        sound = nil,
    }

    for _, child in ipairs(entry.module:GetChildren()) do
        saved.children[child.Name] = child:Clone()
    end

    local ok, data = pcall(require, entry.module)
    if ok and type(data) == "table" then
        if data.AppearanceInfo then
            saved.name = data.AppearanceInfo.Name
            saved.desc = data.AppearanceInfo.Desc
            saved.creator = data.AppearanceInfo.Creator
        end
        if data.EmoteInfo then
            saved.speedMult = data.EmoteInfo.SpeedMult
            saved.sound = data.EmoteInfo.Sound
        end
    end

    originalEmoteContents[name] = saved
end

function EmoteChanger.replace(targetName, donorName)
    local targetEntry = emoteRegistry[targetName]
    local donorEntry = emoteRegistry[donorName]
    if not targetEntry or not donorEntry then
        return false, "Emote not found in registry"
    end

    saveOriginalEmote(targetName)

    local donorChildren = donorEntry.module:GetChildren()
    if #donorChildren == 0 then
        return false, "Donor has no children"
    end

    local removedCount = 0
    for _, child in ipairs(targetEntry.module:GetChildren()) do
        child:Destroy()
        removedCount = removedCount + 1
    end

    local addedCount = 0
    for _, child in ipairs(donorChildren) do
        local clone = child:Clone()
        clone.Parent = targetEntry.module
        addedCount = addedCount + 1
    end

    local okTarget, targetData = pcall(require, targetEntry.module)
    local okDonor, donorData = pcall(require, donorEntry.module)

    if okTarget and okDonor and type(targetData) == "table" and type(donorData) == "table" then
        if donorData.AppearanceInfo then
            targetData.AppearanceInfo = targetData.AppearanceInfo or {}
            targetData.AppearanceInfo.Name = donorData.AppearanceInfo.Name
            targetData.AppearanceInfo.Desc = donorData.AppearanceInfo.Desc
            targetData.AppearanceInfo.Creator = donorData.AppearanceInfo.Creator
        end

        if donorData.EmoteInfo then
            targetData.EmoteInfo = targetData.EmoteInfo or {}
            targetData.EmoteInfo.SpeedMult = donorData.EmoteInfo.SpeedMult
            targetData.EmoteInfo.Sound = donorData.EmoteInfo.Sound
        end
    end

    return true, string.format(
        "Removed %d, added %d objects from '%s' to '%s' (Name, Desc, Creator, SpeedMult, Sound)",
        removedCount, addedCount, donorName, targetName
    )
end

function EmoteChanger.restore(targetName)
    local saved = originalEmoteContents[targetName]
    if not saved then
        return false, "Original not saved (replace was not performed)"
    end
    local entry = emoteRegistry[targetName]
    if not entry then
        return false, "Module not found"
    end

    for _, child in ipairs(entry.module:GetChildren()) do
        child:Destroy()
    end

    local restored = 0
    for _, clone in pairs(saved.children or {}) do
        local newClone = clone:Clone()
        newClone.Parent = entry.module
        restored = restored + 1
    end

    local ok, data = pcall(require, entry.module)
    if ok and type(data) == "table" then
        if saved.name ~= nil or saved.desc ~= nil or saved.creator ~= nil then
            data.AppearanceInfo = data.AppearanceInfo or {}
            if saved.name ~= nil then data.AppearanceInfo.Name = saved.name end
            if saved.desc ~= nil then data.AppearanceInfo.Desc = saved.desc end
            if saved.creator ~= nil then data.AppearanceInfo.Creator = saved.creator end
        end
        if saved.speedMult ~= nil or saved.sound ~= nil then
            data.EmoteInfo = data.EmoteInfo or {}
            if saved.speedMult ~= nil then data.EmoteInfo.SpeedMult = saved.speedMult end
            if saved.sound ~= nil then data.EmoteInfo.Sound = saved.sound end
        end
    end

    return true, string.format("Restored %d objects + properties for '%s'", restored, targetName)
end

return EmoteChanger
