-- ============================================
-- COMPLETE SMART AGING SCRIPT
-- 1. Ages ALL pets (normal + neon)
-- 2. Makes neons when 4 full grown
-- 3. Makes megas when 4 luminous neons
-- 4. Detects completion by AGE POTIONS = 0
-- 5. Auto-disables account when done
-- ============================================

-- Check if config exists, if not create default
if not getgenv().AgingConfig then
    getgenv().AgingConfig = {
        PET_KIND = "", -- remote id of the pet
        RARITY = "uncommon", -- legendary, ultra_rare, rare, uncommon, common
        WEBHOOK_URL = "",
        FARMSYNC_API_KEY = ""
    }
end

local CONFIG = getgenv().AgingConfig

-- Validate required fields
if not CONFIG.PET_KIND or CONFIG.PET_KIND == "" then
    error("❌ ERROR: Please set AgingConfig.PET_KIND before loading script!\n\nExample:\ngetgenv().AgingConfig = {\n    PET_KIND = \"moon_2025_snorgle\",\n    RARITY = \"uncommon\",\n    WEBHOOK_URL = \"your_webhook\",\n    FARMSYNC_API_KEY = \"your_key\"\n}\nloadstring(game:HttpGet(\"url\"))()")
end

if not CONFIG.RARITY or CONFIG.RARITY == "" then
    error("❌ ERROR: Please set AgingConfig.RARITY!")
end

-- Wait for game
print("⏳ Loading...")
repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name

print("✅ Loaded!")

-- Dehash
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end

-- Enter game
local UIManager = require(ReplicatedStorage.Fsys).load("UIManager")
ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/ChooseTeam"):InvokeServer("Parents", {["source_for_logging"] = "intro_sequence"})
task.wait(1)
UIManager.set_app_visibility("MainMenuApp", false)
UIManager.set_app_visibility("NewsApp", false)
task.wait(2)

-- Rarity potions
local RARITY_POTIONS = {
    ["common"] = 1,
    ["uncommon"] = 2,
    ["rare"] = 2,
    ["ultra_rare"] = 4,
    ["legendary"] = 7
}

-- Webhook
local function sendWebhook(msg)
    if CONFIG.WEBHOOK_URL == "" then return end
    pcall(function()
        request({
            Url = CONFIG.WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({["content"] = msg})
        })
    end)
end

-- Disable account
local function disableAccount()
    if CONFIG.FARMSYNC_API_KEY == "" then return end
    pcall(function()
        request({
            Url = "https://api.farmsync.cloud/api/self/accounts/" .. playerName,
            Method = "PUT",
            Headers = {
                ["Authorization"] = "Bearer " .. CONFIG.FARMSYNC_API_KEY,
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({enabled = false})
        })
        print("🔴 Account disabled!")
    end)
end

-- Get player data
local function get_player_data()
    local success, result = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[tostring(LocalPlayer)]
    end)
    return success and result or nil
end

-- Count age potions
local function get_age_potion_count()
    local success, count = pcall(function()
        local data = get_player_data()
        if not data or not data.inventory or not data.inventory.food then return 0 end
        
        local total = 0
        for _, item in pairs(data.inventory.food) do
            if item.kind == "pet_age_potion" then
                total = total + 1
            end
        end
        return total
    end)
    return success and count or 0
end

-- Get age potions as table
local function get_age_potions()
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then return {} end
        
        local potions = {}
        for _, item in pairs(data.inventory.food) do
            if item.kind == "pet_age_potion" then
                table.insert(potions, item.unique)
            end
        end
        return potions
    end)
    return success and result or {}
end

-- Get pets that need aging (age < 6, any type)
local function get_pets_needing_aging()
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then return {} end
        
        local pets = {}
        for _, pet in pairs(data.inventory.pets) do
            if pet.kind == CONFIG.PET_KIND then
                local age = pet.properties and pet.properties.age or 0
                
                -- Any pet under age 6 needs aging (normal or neon)
                if age < 6 then
                    table.insert(pets, pet.unique)
                end
            end
        end
        return pets
    end)
    return success and result or {}
end

-- Get full grown NORMAL pets (for making neons)
local function get_full_grown_normal()
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then return {} end
        
        local pets = {}
        for _, pet in pairs(data.inventory.pets) do
            if pet.kind == CONFIG.PET_KIND then
                local age = pet.properties and pet.properties.age or 0
                local is_neon = pet.properties and pet.properties.neon
                
                if age >= 6 and not is_neon then
                    table.insert(pets, pet.unique)
                end
            end
        end
        return pets
    end)
    return success and result or {}
end

-- Get luminous NEON pets (for making megas)
local function get_luminous_neons()
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then return {} end
        
        local neons = {}
        for _, pet in pairs(data.inventory.pets) do
            if pet.kind == CONFIG.PET_KIND then
                local age = pet.properties and pet.properties.age or 0
                local is_neon = pet.properties and pet.properties.neon
                local is_mega = pet.properties and pet.properties.mega
                
                if age >= 6 and is_neon and not is_mega then
                    table.insert(neons, pet.unique)
                end
            end
        end
        return neons
    end)
    return success and result or {}
end

-- Equip pet
local function equip_pet(unique)
    return pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(unique, {
            use_sound_delay = true,
            equip_as_last = false
        })
    end)
end

-- Feed pet all potions
local function feed_pet(pet_unique, potion_count, potions)
    if #potions < potion_count then return false end
    
    local success = pcall(function()
        local first = table.remove(potions, 1)
        local additional = {}
        
        for i = 1, potion_count - 1 do
            table.insert(additional, table.remove(potions, 1))
        end
        
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject"):InvokeServer(
            "__Enum_PetObjectCreatorType_2",
            {
                pet_unique = pet_unique,
                unique_id = first,
                additional_consume_uniques = additional
            }
        )
    end)
    
    return success
end

-- Age pet
local function age_pet(pet_unique, potion_count, potions)
    if not equip_pet(pet_unique) then return false end
    task.wait(0.5)
    if not feed_pet(pet_unique, potion_count, potions) then return false end
    task.wait(9)
    return true
end

-- Make neon
local function make_neon(four_pets)
    return pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/DoNeonFusion"):InvokeServer(four_pets)
    end)
end

-- Make mega
local function make_mega(four_neons)
    return pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/DoNeonFusion"):InvokeServer(four_neons)
    end)
end

-- ============================================
-- MAIN PROCESS
-- ============================================

print("\n========================================")
print("🚀 SMART AGING PROCESS")
print("========================================")

local rarity = string.lower(CONFIG.RARITY)
local potionCost = RARITY_POTIONS[rarity]

if not potionCost then
    error("Invalid rarity!")
end

print("Pet: " .. CONFIG.PET_KIND)
print("Rarity: " .. CONFIG.RARITY)
print("Potions per pet: " .. potionCost)

-- Wait 30 seconds
print("\n⏳ Waiting 30 seconds...")
task.wait(30)

local initial_potions = get_age_potion_count()
print("\n📊 Initial potions: " .. initial_potions)

if initial_potions == 0 then
    error("No potions!")
end

local total_potions = get_age_potions()
local aged_count = 0
local neons_made = 0
local megas_made = 0

-- LOOP: Age → Make Neons → Make Megas → Repeat
while #total_potions >= potionCost do
    
    -- PHASE 1: Age pets
    print("\n🔧 AGING PETS...")
    local pets_to_age = get_pets_needing_aging()
    
    for i, pet in ipairs(pets_to_age) do
        if #total_potions < potionCost then break end
        
        print("Aging pet " .. i .. "...")
        if age_pet(pet, potionCost, total_potions) then
            aged_count = aged_count + 1
            print("✅ Aged! Potions left: " .. #total_potions)
        end
        
        task.wait(1)
    end
    
    task.wait(5)
    
    -- PHASE 2: Make neons
    print("\n🌟 MAKING NEONS...")
    local full_grown = get_full_grown_normal()
    
    while #full_grown >= 4 do
        local four = {full_grown[1], full_grown[2], full_grown[3], full_grown[4]}
        
        if make_neon(four) then
            neons_made = neons_made + 1
            print("✅ Neon #" .. neons_made .. " made!")
            task.wait(3)
        end
        
        -- Refresh list
        full_grown = get_full_grown_normal()
    end
    
    task.wait(5)
    
    -- PHASE 3: Make megas
    print("\n💎 MAKING MEGAS...")
    local luminous = get_luminous_neons()
    
    while #luminous >= 4 do
        local four = {luminous[1], luminous[2], luminous[3], luminous[4]}
        
        if make_mega(four) then
            megas_made = megas_made + 1
            print("✅ Mega #" .. megas_made .. " made!")
            task.wait(3)
        end
        
        -- Refresh list
        luminous = get_luminous_neons()
    end
    
    -- Check potions again
    total_potions = get_age_potions()
    
    if #total_potions == 0 then
        print("\n🎉 ALL POTIONS USED!")
        break
    end
end

-- ============================================
-- COMPLETION DETECTION (BY POTIONS)
-- ============================================

print("\n========================================")
print("🔍 CHECKING COMPLETION...")
print("========================================")

local webhookSent = false

for i = 1, 60 do
    task.wait(5)
    
    local potions_left = get_age_potion_count()
    
    print("Check #" .. i .. " - Potions: " .. potions_left)
    
    if potions_left == 0 and not webhookSent then
        print("\n✅ NO POTIONS LEFT - COMPLETE!")
        
        sendWebhook("✅ " .. playerName .. " - COMPLETE - Aged: " .. aged_count .. ", Neons: " .. neons_made .. ", Megas: " .. megas_made)
        print("📡 Webhook sent!")
        
        disableAccount()
        
        webhookSent = true
        break
    end
end

if not webhookSent then
    sendWebhook("✅ " .. playerName .. " - COMPLETE")
    disableAccount()
end

print("\n========================================")
print("✅ SCRIPT COMPLETE!")
print("Pets Aged: " .. aged_count)
print("Neons Made: " .. neons_made)
print("Megas Made: " .. megas_made)
print("========================================")-- ============================================
-- COMPLETE SMART AGING SCRIPT
-- 1. Ages ALL pets (normal + neon)
-- 2. Makes neons when 4 full grown
-- 3. Makes megas when 4 luminous neons
-- 4. Detects completion by AGE POTIONS = 0
-- 5. Auto-disables account when done
-- ============================================

-- Check if config exists, if not create default
if not getgenv().AgingConfig then
    getgenv().AgingConfig = {
        PET_KIND = "", -- remote id of the pet
        RARITY = "uncommon", -- legendary, ultra_rare, rare, uncommon, common
        WEBHOOK_URL = "",
        FARMSYNC_API_KEY = ""
    }
end

local CONFIG = getgenv().AgingConfig

-- Validate required fields
if not CONFIG.PET_KIND or CONFIG.PET_KIND == "" then
    error("❌ ERROR: Please set AgingConfig.PET_KIND before loading script!\n\nExample:\ngetgenv().AgingConfig = {\n    PET_KIND = \"moon_2025_snorgle\",\n    RARITY = \"uncommon\",\n    WEBHOOK_URL = \"your_webhook\",\n    FARMSYNC_API_KEY = \"your_key\"\n}\nloadstring(game:HttpGet(\"url\"))()")
end

if not CONFIG.RARITY or CONFIG.RARITY == "" then
    error("❌ ERROR: Please set AgingConfig.RARITY!")
end

-- Wait for game
print("⏳ Loading...")
repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name

print("✅ Loaded!")

-- Dehash
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end

-- Enter game
local UIManager = require(ReplicatedStorage.Fsys).load("UIManager")
ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/ChooseTeam"):InvokeServer("Parents", {["source_for_logging"] = "intro_sequence"})
task.wait(1)
UIManager.set_app_visibility("MainMenuApp", false)
UIManager.set_app_visibility("NewsApp", false)
task.wait(2)

-- Rarity potions
local RARITY_POTIONS = {
    ["common"] = 1,
    ["uncommon"] = 2,
    ["rare"] = 2,
    ["ultra_rare"] = 4,
    ["legendary"] = 7
}

-- Webhook
local function sendWebhook(msg)
    if CONFIG.WEBHOOK_URL == "" then return end
    pcall(function()
        request({
            Url = CONFIG.WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({["content"] = msg})
        })
    end)
end

-- Disable account
local function disableAccount()
    if CONFIG.FARMSYNC_API_KEY == "" then return end
    pcall(function()
        request({
            Url = "https://api.farmsync.cloud/api/self/accounts/" .. playerName,
            Method = "PUT",
            Headers = {
                ["Authorization"] = "Bearer " .. CONFIG.FARMSYNC_API_KEY,
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({enabled = false})
        })
        print("🔴 Account disabled!")
    end)
end

-- Get player data
local function get_player_data()
    local success, result = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[tostring(LocalPlayer)]
    end)
    return success and result or nil
end

-- Count age potions
local function get_age_potion_count()
    local success, count = pcall(function()
        local data = get_player_data()
        if not data or not data.inventory or not data.inventory.food then return 0 end
        
        local total = 0
        for _, item in pairs(data.inventory.food) do
            if item.kind == "pet_age_potion" then
                total = total + 1
            end
        end
        return total
    end)
    return success and count or 0
end

-- Get age potions as table
local function get_age_potions()
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then return {} end
        
        local potions = {}
        for _, item in pairs(data.inventory.food) do
            if item.kind == "pet_age_potion" then
                table.insert(potions, item.unique)
            end
        end
        return potions
    end)
    return success and result or {}
end

-- Get pets that need aging (age < 6, any type)
local function get_pets_needing_aging()
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then return {} end
        
        local pets = {}
        for _, pet in pairs(data.inventory.pets) do
            if pet.kind == CONFIG.PET_KIND then
                local age = pet.properties and pet.properties.age or 0
                
                -- Any pet under age 6 needs aging (normal or neon)
                if age < 6 then
                    table.insert(pets, pet.unique)
                end
            end
        end
        return pets
    end)
    return success and result or {}
end

-- Get full grown NORMAL pets (for making neons)
local function get_full_grown_normal()
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then return {} end
        
        local pets = {}
        for _, pet in pairs(data.inventory.pets) do
            if pet.kind == CONFIG.PET_KIND then
                local age = pet.properties and pet.properties.age or 0
                local is_neon = pet.properties and pet.properties.neon
                
                if age >= 6 and not is_neon then
                    table.insert(pets, pet.unique)
                end
            end
        end
        return pets
    end)
    return success and result or {}
end

-- Get luminous NEON pets (for making megas)
local function get_luminous_neons()
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then return {} end
        
        local neons = {}
        for _, pet in pairs(data.inventory.pets) do
            if pet.kind == CONFIG.PET_KIND then
                local age = pet.properties and pet.properties.age or 0
                local is_neon = pet.properties and pet.properties.neon
                local is_mega = pet.properties and pet.properties.mega
                
                if age >= 6 and is_neon and not is_mega then
                    table.insert(neons, pet.unique)
                end
            end
        end
        return neons
    end)
    return success and result or {}
end

-- Equip pet
local function equip_pet(unique)
    return pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(unique, {
            use_sound_delay = true,
            equip_as_last = false
        })
    end)
end

-- Feed pet all potions
local function feed_pet(pet_unique, potion_count, potions)
    if #potions < potion_count then return false end
    
    local success = pcall(function()
        local first = table.remove(potions, 1)
        local additional = {}
        
        for i = 1, potion_count - 1 do
            table.insert(additional, table.remove(potions, 1))
        end
        
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject"):InvokeServer(
            "__Enum_PetObjectCreatorType_2",
            {
                pet_unique = pet_unique,
                unique_id = first,
                additional_consume_uniques = additional
            }
        )
    end)
    
    return success
end

-- Age pet
local function age_pet(pet_unique, potion_count, potions)
    if not equip_pet(pet_unique) then return false end
    task.wait(0.5)
    if not feed_pet(pet_unique, potion_count, potions) then return false end
    task.wait(9)
    return true
end

-- Make neon
local function make_neon(four_pets)
    return pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/DoNeonFusion"):InvokeServer(four_pets)
    end)
end

-- Make mega
local function make_mega(four_neons)
    return pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/DoNeonFusion"):InvokeServer(four_neons)
    end)
end

-- ============================================
-- MAIN PROCESS
-- ============================================

print("\n========================================")
print("🚀 SMART AGING PROCESS")
print("========================================")

local rarity = string.lower(CONFIG.RARITY)
local potionCost = RARITY_POTIONS[rarity]

if not potionCost then
    error("Invalid rarity!")
end

print("Pet: " .. CONFIG.PET_KIND)
print("Rarity: " .. CONFIG.RARITY)
print("Potions per pet: " .. potionCost)

-- Wait 30 seconds
print("\n⏳ Waiting 30 seconds...")
task.wait(30)

local initial_potions = get_age_potion_count()
print("\n📊 Initial potions: " .. initial_potions)

if initial_potions == 0 then
    error("No potions!")
end

local total_potions = get_age_potions()
local aged_count = 0
local neons_made = 0
local megas_made = 0

-- LOOP: Age → Make Neons → Make Megas → Repeat
while #total_potions >= potionCost do
    
    -- PHASE 1: Age pets
    print("\n🔧 AGING PETS...")
    local pets_to_age = get_pets_needing_aging()
    
    for i, pet in ipairs(pets_to_age) do
        if #total_potions < potionCost then break end
        
        print("Aging pet " .. i .. "...")
        if age_pet(pet, potionCost, total_potions) then
            aged_count = aged_count + 1
            print("✅ Aged! Potions left: " .. #total_potions)
        end
        
        task.wait(1)
    end
    
    task.wait(5)
    
    -- PHASE 2: Make neons
    print("\n🌟 MAKING NEONS...")
    local full_grown = get_full_grown_normal()
    
    while #full_grown >= 4 do
        local four = {full_grown[1], full_grown[2], full_grown[3], full_grown[4]}
        
        if make_neon(four) then
            neons_made = neons_made + 1
            print("✅ Neon #" .. neons_made .. " made!")
            task.wait(3)
        end
        
        -- Refresh list
        full_grown = get_full_grown_normal()
    end
    
    task.wait(5)
    
    -- PHASE 3: Make megas
    print("\n💎 MAKING MEGAS...")
    local luminous = get_luminous_neons()
    
    while #luminous >= 4 do
        local four = {luminous[1], luminous[2], luminous[3], luminous[4]}
        
        if make_mega(four) then
            megas_made = megas_made + 1
            print("✅ Mega #" .. megas_made .. " made!")
            task.wait(3)
        end
        
        -- Refresh list
        luminous = get_luminous_neons()
    end
    
    -- Check potions again
    total_potions = get_age_potions()
    
    if #total_potions == 0 then
        print("\n🎉 ALL POTIONS USED!")
        break
    end
end

-- ============================================
-- COMPLETION DETECTION (BY POTIONS)
-- ============================================

print("\n========================================")
print("🔍 CHECKING COMPLETION...")
print("========================================")

local webhookSent = false

for i = 1, 60 do
    task.wait(5)
    
    local potions_left = get_age_potion_count()
    
    print("Check #" .. i .. " - Potions: " .. potions_left)
    
    if potions_left == 0 and not webhookSent then
        print("\n✅ NO POTIONS LEFT - COMPLETE!")
        
        sendWebhook("✅ " .. playerName .. " - COMPLETE - Aged: " .. aged_count .. ", Neons: " .. neons_made .. ", Megas: " .. megas_made)
        print("📡 Webhook sent!")
        
        disableAccount()
        
        webhookSent = true
        break
    end
end

if not webhookSent then
    sendWebhook("✅ " .. playerName .. " - COMPLETE")
    disableAccount()
end

print("\n========================================")
print("✅ SCRIPT COMPLETE!")
print("Pets Aged: " .. aged_count)
print("Neons Made: " .. neons_made)
print("Megas Made: " .. megas_made)
print("========================================")
