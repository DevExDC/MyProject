-- ============================================
-- ADOPT ME PET AGING SCRIPT - FARMSYNC EDITION
-- Auto-ages pets with smart potion usage
-- Auto-disables account when complete
-- ============================================

-- Check if already running
if getgenv().AgingScript then
    warn("⚠️ Aging script already running!")
    return
end

getgenv().AgingScript = {
    Running = true,
    Version = "3.0"
}

-- ============================================
-- CONFIGURATION VIA GETGENV
-- ============================================
if not getgenv().AgingConfig then
    getgenv().AgingConfig = {
        PET_KIND = "moon_2025_snorgle",
        RARITY = "uncommon",
        WEBHOOK_URL = "",
        FARMSYNC_API_KEY = ""
    }
end

local CONFIG = getgenv().AgingConfig

-- Validate configuration
if CONFIG.PET_KIND == "" then
    error("❌ Please set AgingConfig.PET_KIND")
end

if CONFIG.RARITY == "" then
    error("❌ Please set AgingConfig.RARITY")
end

-- ============================================
-- WAIT FOR GAME TO LOAD
-- ============================================
print("⏳ Waiting for game to load...")

repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:IsLoaded() and game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

print("✅ Game loaded!")

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name

-- ============================================
-- DEHASH REMOTES
-- ============================================
print("🔧 Dehashing remotes...")

for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end

print("✅ Remotes dehashed!")

-- ============================================
-- ENTER THE GAME
-- ============================================
print("🏠 Entering the game...")

local UIManager = require(ReplicatedStorage.Fsys).load("UIManager")

local function enter_the_game()
    local args = {
        [1] = "Parents",
        [2] = {
            ["source_for_logging"] = "intro_sequence",
        },
    }
    
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/ChooseTeam"):InvokeServer(unpack(args))
    task.wait(1)
    
    UIManager.set_app_visibility("MainMenuApp", false)
    UIManager.set_app_visibility("NewsApp", false)
    UIManager.set_app_visibility("DialogApp", false)
    UIManager.set_app_visibility("MinigameRewardsApp", false)
    
    task.wait(3)
    
    ReplicatedStorage:WaitForChild("API"):WaitForChild("DailyLoginAPI/ClaimDailyReward"):InvokeServer()
    UIManager.set_app_visibility("DailyLoginApp", false)
end

pcall(enter_the_game)

print("✅ Entered the game!")

-- Wait 30 seconds before starting
print("\n⏳ Waiting 30 seconds before starting...")
task.wait(30)
print("✅ Starting aging process now!")

-- ============================================
-- RARITY POTION MAPPING
-- ============================================
local RARITY_POTIONS = {
    ["common"] = 1,
    ["uncommon"] = 2,
    ["rare"] = 2,
    ["ultra_rare"] = 4,
    ["legendary"] = 7
}

-- ============================================
-- WEBHOOK FUNCTION
-- ============================================
local function sendWebhook(message)
    if CONFIG.WEBHOOK_URL == "" then return end
    
    pcall(function()
        request({
            Url = CONFIG.WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({["content"] = message})
        })
    end)
end

-- ============================================
-- FARMSYNC AUTO-DISABLE FUNCTION
-- ============================================
local function disableAccount()
    if CONFIG.FARMSYNC_API_KEY == "" then 
        print("⚠️ No FarmSync API key, skipping auto-disable")
        return 
    end
    
    pcall(function()
        request({
            Url = "https://api.farmsync.cloud/api/self/accounts/" .. playerName,
            Method = "PUT",
            Headers = {
                ["Authorization"] = "Bearer " .. CONFIG.FARMSYNC_API_KEY,
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({
                enabled = false
            })
        })
        
        print("🔴 Account auto-disabled via FarmSync!")
    end)
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

local function get_player_data()
    local success, result = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[tostring(LocalPlayer)]
    end)
    
    return success and result or nil
end

local function count_pets_needing_aging()
    local success, count = pcall(function()
        local data = get_player_data()
        if not data or not data.inventory or not data.inventory.pets then return 0 end
        
        local total = 0
        for _, pet in pairs(data.inventory.pets) do
            if pet.kind == CONFIG.PET_KIND then
                local age = pet.properties and pet.properties.age or 0
                if age < 6 then
                    total = total + 1
                end
            end
        end
        
        return total
    end)
    
    return success and count or 0
end

local function get_all_normal_pets(pet_kind)
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then error("No player data") end
        
        local normal_pets = {}
        for _, pet in pairs(data.inventory.pets) do
            local age = pet.properties and pet.properties.age or 0
            local is_neon = pet.properties and pet.properties.neon
            
            if pet.kind == pet_kind and not pet.is_egg and not is_neon and age < 6 then
                table.insert(normal_pets, pet.unique)
            end
        end
        
        return normal_pets
    end)
    
    return success and result or {}
end

local function get_age_potions()
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then error("No player data") end
        
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

local function equip_pet(pet_unique)
    local success = pcall(function()
        local args = {
            pet_unique,
            {
                use_sound_delay = true,
                equip_as_last = false
            }
        }
        
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(unpack(args))
    end)
    
    return success
end

local function feed_pet_all_potions(pet_unique, potion_count, potions)
    local success = pcall(function()
        if #potions < potion_count then
            error("Not enough potions!")
        end
        
        local first_potion = table.remove(potions, 1)
        local additional = {}
        
        for i = 1, potion_count - 1 do
            table.insert(additional, table.remove(potions, 1))
        end
        
        local args = {
            "__Enum_PetObjectCreatorType_2",
            {
                pet_unique = pet_unique,
                unique_id = first_potion,
                additional_consume_uniques = additional
            }
        }
        
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject"):InvokeServer(unpack(args))
    end)
    
    return success
end

local function age_pet_fully(pet_unique, potion_count, potions)
    if not equip_pet(pet_unique) then
        return false
    end
    
    task.wait(0.5)
    
    if not feed_pet_all_potions(pet_unique, potion_count, potions) then
        return false
    end
    
    task.wait(9)
    return true
end

-- ============================================
-- MAIN AGING PROCESS
-- ============================================
local function start_aging_process()
    print("\n========================================")
    print("🚀 STARTING PET AGING PROCESS")
    print("========================================")
    print("Pet Kind: " .. CONFIG.PET_KIND)
    print("Rarity: " .. CONFIG.RARITY:upper())
    print("========================================\n")
    
    local rarity_lower = string.lower(CONFIG.RARITY)
    local potionCost = RARITY_POTIONS[rarity_lower]
    
    if not potionCost then
        error("Unknown rarity: " .. CONFIG.RARITY)
    end
    
    local total_potions = get_age_potions()
    local original_potion_count = #total_potions
    
    print("📊 Total age potions: " .. #total_potions)
    
    if #total_potions == 0 then
        error("No age potions found!")
    end
    
    local normal_pets = get_all_normal_pets(CONFIG.PET_KIND)
    local aged_count = 0
    
    print("🐾 Pets to age: " .. #normal_pets)
    
    if #normal_pets > 0 then
        for i, pet_unique in ipairs(normal_pets) do
            if #total_potions < potionCost then 
                print("⚠️ Out of potions!")
                break 
            end
            
            print("🔧 Aging pet " .. i .. "/" .. #normal_pets)
            
            if age_pet_fully(pet_unique, potionCost, total_potions) then
                aged_count = aged_count + 1
                print("✅ Pet " .. i .. " aged! Potions left: " .. #total_potions)
            else
                print("❌ Failed to age pet " .. i)
            end
            
            task.wait(1)
        end
    end
    
    local potions_used = original_potion_count - #total_potions
    
    print("\n========================================")
    print("🎉 AGING COMPLETE!")
    print("Pets Aged: " .. aged_count)
    print("Potions Used: " .. potions_used .. "/" .. original_potion_count)
    print("========================================")
end

-- ============================================
-- START PROCESS
-- ============================================
print("🔧 Starting aging process...")
start_aging_process()

-- ============================================
-- MONITOR FOR COMPLETION
-- ============================================
print("\n📊 Monitoring for completion...")

local webhookSent = false

for i = 1, 60 do
    task.wait(5)
    
    local remaining = count_pets_needing_aging()
    
    if remaining == 0 and not webhookSent then
        print("\n✅ ALL PETS FULL GROWN!")
        
        -- Send webhook
        sendWebhook("✅ " .. playerName .. " - COMPLETE")
        print("📡 Completion webhook sent!")
        
        -- Auto-disable account
        disableAccount()
        
        webhookSent = true
        break
    elseif i % 6 == 0 then
        print("📊 Still aging... " .. remaining .. " pets remaining")
    end
end

if not webhookSent then
    print("\n⏱️ Timeout reached, sending completion...")
    sendWebhook("✅ " .. playerName .. " - COMPLETE")
    disableAccount()
end

print("\n========================================")
print("✅ SCRIPT COMPLETE")
print("========================================")

getgenv().AgingScript.Running = false
