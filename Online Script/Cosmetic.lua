local Cosmetic = {}

local cosmeticRegistry = {}
local originalCosmeticContents = {}

function Cosmetic.scan()
    cosmeticRegistry = {}
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
                if cosmeticRegistry[key] then
                    local i = 2
                    while cosmeticRegistry[key .. " (" .. i .. ")"] do
                        i = i + 1
                    end
                    key = key .. " (" .. i .. ")"
                end
                cosmeticRegistry[key] = {
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
                if child.Name == "Cosmetics" then
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
    for name, _ in pairs(cosmeticRegistry) do
        table.insert(names, name)
    end
    table.sort(names)

    return names, found
end

local function saveOriginalCosmetic(name)
    if originalCosmeticContents[name] then return end
    local entry = cosmeticRegistry[name]
    if not entry then return end

    local saved = {}
    for _, child in ipairs(entry.module:GetChildren()) do
        saved[child.Name] = child:Clone()
    end
    originalCosmeticContents[name] = saved
end

function Cosmetic.replace(targetName, donorName)
    local targetEntry = cosmeticRegistry[targetName]
    local donorEntry = cosmeticRegistry[donorName]
    if not targetEntry or not donorEntry then
        return false, "Cosmetic not found in registry"
    end

    saveOriginalCosmetic(targetName)

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

    return true, string.format(
        "Removed %d, added %d objects from '%s' to '%s'",
        removedCount, addedCount, donorName, targetName
    )
end

function Cosmetic.restore(targetName)
    local saved = originalCosmeticContents[targetName]
    if not saved then
        return false, "Original not saved (replace was not performed)"
    end
    local entry = cosmeticRegistry[targetName]
    if not entry then
        return false, "Module not found"
    end

    for _, child in ipairs(entry.module:GetChildren()) do
        child:Destroy()
    end

    local restored = 0
    for _, clone in pairs(saved) do
        local newClone = clone:Clone()
        newClone.Parent = entry.module
        restored = restored + 1
    end

    return true, string.format("Restored %d objects for '%s'", restored, targetName)
end

return Cosmetic
