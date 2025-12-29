-- ============================================
-- SMART AGING SCRIPT - REBUILT
-- Proper property checking and intelligent aging
-- ============================================

if not getgenv().AgingConfig then
    getgenv().AgingConfig = {
        PET_KIND = "winter_2025_christmas_spirit",
        RARITY = "legendary",
        WEBHOOK_URL = "",
        FARMSYNC_API_KEY = ""
    }
end

local CONFIG = getgenv().AgingConfig

if CONFIG.PET_KIND == "" then
    error("❌ Set PET_KIND!")
end

if not CONFIG.RARITY or CONFIG.RARITY == "" then
    error("❌ Set RARITY!")
end

local RARITY_AGE_UPS = {
    legendary = 7,
    ultra_rare = 4,
    rare = 2,
    uncommon = 2,
    common = 1
}

local rarity_lower = string.lower(CONFIG.RARITY)
if not RARITY_AGE_UPS[rarity_lower] then
    error("❌ Invalid RARITY!")
end

print("===========================================")
print("  SMART AGING SYSTEM - REBUILT")
print("  Intelligent Pet Detection & Aging")
print("===========================================")

repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name

-- Anti-AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
print("✅ Anti-AFK enabled")

-- ============== DEHASH FIRST! ==============
print("🔧 Dehashing remotes...")
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end
print("✅ Remotes dehashed!")

-- ============== STARTER - CORRECT 3-PHASE SEQUENCE ==============
local UIManager = require(ReplicatedStorage.Fsys).load("UIManager")

local function enter_the_game()
    print("📍 Phase 1: Accepting terms...")
    -- Phase 1: Accept terms (Click "Play")
    pcall(function()
        game:GetService("ReplicatedStorage")
            :WaitForChild("API")
            :WaitForChild("MainMenuAPI/AcceptTermsOfServiceAndPrivacyPolicy")
            :FireServer()
    end)
    task.wait(1)
    
    print("📍 Phase 2: Choosing team...")
    -- Phase 2: Choose team (Click "Parents")
    pcall(function()
        local args = {
            "Parents",
            {
                source_for_logging = "intro_sequence",
                dont_enter_location = true
            }
        }
        game:GetService("ReplicatedStorage")
            :WaitForChild("API")
            :WaitForChild("TeamAPI/ChooseTeam")
            :InvokeServer(unpack(args))
    end)
    task.wait(1)
    
    print("📍 Phase 3: Spawning...")
    -- Phase 3: Actually spawn
    pcall(function()
        local args = {"Home"}
        game:GetService("ReplicatedStorage")
            :WaitForChild("API")
            :WaitForChild("TradingServerAPI/IncrementConsecutiveSpawnCounter")
            :FireServer(unpack(args))
    end)
    task.wait(2)
    
    -- Hide UI elements
    UIManager.set_app_visibility("MainMenuApp", false)
    UIManager.set_app_visibility("NewsApp", false)
    UIManager.set_app_visibility("DialogApp", false)
    UIManager.set_app_visibility("MinigameRewardsApp", false)
    
    task.wait(2)
    
    -- Claim daily reward
    pcall(function()
        game:GetService("ReplicatedStorage")
            :WaitForChild("API")
            :WaitForChild("DailyLoginAPI/ClaimDailyReward")
            :InvokeServer()
        UIManager.set_app_visibility("DailyLoginApp", false)
    end)
    
    print("✅ Fully spawned and ready!")
end

print("🎮 Entering game...")
enter_the_game()
print("✅ Game entered!")

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- Webhook
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

-- Disable account
local function disableAccount()
    if CONFIG.FARMSYNC_API_KEY == "" then
        print("⚠️ No API key, skipping auto-disable")
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
            Body = HttpService:JSONEncode({enabled = false})
        })
        print("🔴 Account disabled!")
    end)
end

-- Count age potions
local function count_age_potions()
    local count = 0
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.food then
            for _, item in pairs(playerData.inventory.food) do
                if item.kind == "pet_age_potion" then
                    count = count + 1
                end
            end
        end
    end)
    return count
end

-- Get age potion uniques
local function get_age_potion_uniques(amount)
    local potions = {}
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.food then
            for _, item in pairs(playerData.inventory.food) do
                if item.kind == "pet_age_potion" then
                    table.insert(potions, item.unique)
                    if #potions >= amount then
                        break
                    end
                end
            end
        end
    end)
    return potions
end

-- Analyze pet inventory with FULL property checking
local function analyze_pet_inventory()
    local analysis = {
        normal_pets = {},      -- Normal pets by age
        neon_pets = {},        -- Neon pets by age
        full_grown_normal = 0, -- Count of age 6 normals
        full_grown_neons = 0   -- Count of age 6 neons
    }
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then
            return
        end
        
        for _, pet in pairs(playerData.inventory.pets) do
            if pet.kind == CONFIG.PET_KIND then
                local is_neon = pet.properties and pet.properties.neon or false
                local is_mega = pet.properties and pet.properties.mega or false
                local age = pet.properties and pet.properties.age or 0
                
                -- Skip mega pets
                if is_mega then
                    continue
                end
                
                if is_neon then
                    -- Neon pet
                    if age == 6 then
                        analysis.full_grown_neons = analysis.full_grown_neons + 1
                    else
                        table.insert(analysis.neon_pets, {
                            unique = pet.unique,
                            age = age
                        })
                    end
                else
                    -- Normal pet
                    if age == 6 then
                        analysis.full_grown_normal = analysis.full_grown_normal + 1
                    else
                        table.insert(analysis.neon_pets, {
                            unique = pet.unique,
                            age = age
                        })
                    end
                end
            end
        end
    end)
    
    return analysis
end

-- Get full grown normal pets
local function get_full_grown_normals()
    local pets = {}
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for _, pet in pairs(playerData.inventory.pets) do
                if pet.kind == CONFIG.PET_KIND then
                    local is_neon = pet.properties and pet.properties.neon
                    local age = pet.properties and pet.properties.age or 0
                    if not is_neon and age == 6 then
                        table.insert(pets, pet.unique)
                    end
                end
            end
        end
    end)
    return pets
end

-- Get full grown neon pets
local function get_full_grown_neons()
    local neons = {}
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for _, pet in pairs(playerData.inventory.pets) do
                if pet.kind == CONFIG.PET_KIND then
                    local is_neon = pet.properties and pet.properties.neon
                    local is_mega = pet.properties and pet.properties.mega
                    local age = pet.properties and pet.properties.age or 0
                    if is_neon and not is_mega and age == 6 then
                        table.insert(neons, pet.unique)
                    end
                end
            end
        end
    end)
    return neons
end

-- Equip pet
local function equip_pet(pet_unique)
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(
            pet_unique,
            {
                use_sound_delay = true,
                equip_as_last = false
            }
        )
    end)
end

-- Age up pet
local function age_up_pet(pet_unique, potion_uniques)
    equip_pet(pet_unique)
    task.wait(1)
    
    pcall(function()
        local main_potion = potion_uniques[1]
        local additional = {}
        for i = 2, #potion_uniques do
            table.insert(additional, potion_uniques[i])
        end
        
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject"):InvokeServer(
            "__Enum_PetObjectCreatorType_2",
            {
                pet_unique = pet_unique,
                unique_id = main_potion,
                additional_consume_uniques = additional
            }
        )
    end)
    
    task.wait(10)
end

-- Create neon
local function create_neon(pet_uniques)
    if #pet_uniques < 4 then
        return false
    end
    
    local success = false
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/DoNeonFusion"):InvokeServer(
            {pet_uniques[1], pet_uniques[2], pet_uniques[3], pet_uniques[4]}
        )
        success = true
    end)
    return success
end

-- Main execution
print("\n🔍 Analyzing inventory...")

local total_aged = 0
local total_neons_created = 0
local total_megas_created = 0
local potions_per_pet = RARITY_AGE_UPS[rarity_lower]

sendWebhook(string.format("🔄 %s - Starting smart aging", playerName))

-- CONTINUOUS LOOP UNTIL NO MORE WORK
local cycle = 0
local MAX_CYCLES = 100  -- Safety limit

while cycle < MAX_CYCLES do
    cycle = cycle + 1
    print(string.format("\n========== CYCLE %d ==========", cycle))
    
    local analysis = analyze_pet_inventory()
    local potions = count_age_potions()
    
    print(string.format("📊 Status:"))
    print(string.format("   Potions: %d", potions))
    print(string.format("   Normal pets (not age 6): %d", #analysis.normal_pets))
    print(string.format("   Full grown normals: %d", analysis.full_grown_normal))
    print(string.format("   Neon pets (not age 6): %d", #analysis.neon_pets))
    print(string.format("   Full grown neons: %d", analysis.full_grown_neons))
    
    local did_something = false
    
    -- STEP 1: Age normal pets
    if #analysis.normal_pets > 0 and potions >= potions_per_pet then
        print("\n📦 Aging normal pets...")
        local can_age = math.floor(potions / potions_per_pet)
        local to_age = math.min(can_age, #analysis.normal_pets)
        
        for i = 1, to_age do
            local pet = analysis.normal_pets[i]
            local potion_batch = get_age_potion_uniques(potions_per_pet)
            
            if #potion_batch < potions_per_pet then
                print("⚠️ Ran out of potions")
                break
            end
            
            print(string.format("   Aging normal pet %d/%d (age: %d)", i, to_age, pet.age))
            age_up_pet(pet.unique, potion_batch)
            total_aged = total_aged + 1
        end
        
        did_something = true
        task.wait(2)
        continue -- Recheck inventory
    end
    
    -- STEP 2: Make neons from full grown normals
    if analysis.full_grown_normal >= 4 then
        print("\n🌟 Creating neons from full grown normals...")
        local full_grown = get_full_grown_normals()
        
        while #full_grown >= 4 do
            if create_neon(full_grown) then
                print("   ✅ Neon created!")
                total_neons_created = total_neons_created + 1
                task.wait(2)
                full_grown = get_full_grown_normals()
            else
                break
            end
        end
        
        did_something = true
        task.wait(2)
        continue -- Recheck inventory
    end
    
    -- STEP 3: Age neon pets
    if #analysis.neon_pets > 0 and potions >= potions_per_pet then
        print("\n💎 Aging neon pets...")
        local can_age = math.floor(potions / potions_per_pet)
        local to_age = math.min(can_age, #analysis.neon_pets)
        
        for i = 1, to_age do
            local pet = analysis.neon_pets[i]
            local potion_batch = get_age_potion_uniques(potions_per_pet)
            
            if #potion_batch < potions_per_pet then
                print("⚠️ Ran out of potions")
                break
            end
            
            print(string.format("   Aging NEON pet %d/%d (age: %d)", i, to_age, pet.age))
            age_up_pet(pet.unique, potion_batch)
            total_aged = total_aged + 1
        end
        
        did_something = true
        task.wait(2)
        continue -- Recheck inventory
    end
    
    -- STEP 4: Make megas from full grown neons
    if analysis.full_grown_neons >= 4 then
        print("\n💎 Creating MEGA from full grown neons...")
        local full_grown_neons = get_full_grown_neons()
        
        while #full_grown_neons >= 4 do
            if create_neon(full_grown_neons) then -- Same remote!
                print("   ✅ MEGA created!")
                total_megas_created = total_megas_created + 1
                task.wait(2)
                full_grown_neons = get_full_grown_neons()
            else
                break
            end
        end
        
        did_something = true
        task.wait(2)
        continue -- Recheck inventory
    end
    
    -- If nothing left to do, exit loop
    if not did_something then
        print("\n✅ No more work to do!")
        
        local remaining_potions = count_age_potions()
        if remaining_potions > 0 then
            print(string.format("⚠️ WARNING: %d potions remaining (not enough to age)", remaining_potions))
        end
        
        break
    end
end

-- Check if hit max cycles (safety)
if cycle >= MAX_CYCLES then
    print("\n⚠️ WARNING: Hit max cycles limit (" .. MAX_CYCLES .. ")")
    print("   Forcing completion to prevent infinite loop")
    sendWebhook(string.format("⚠️ %s - Hit max cycles, forced completion", playerName))
end

-- Final summary
local final_potions = count_age_potions()

print("\n" .. ("="):rep(50))
print("✅ AGING COMPLETE!")
print(("="):rep(50))
print(string.format("   Total pets aged: %d", total_aged))
print(string.format("   Neons created: %d", total_neons_created))
print(string.format("   Megas created: %d", total_megas_created))
print(string.format("   Potions remaining: %d", final_potions))
print(("="):rep(50))

sendWebhook(string.format("✅ %s - AGING COMPLETE - Aged: %d, Neons: %d, Megas: %d, Leftover: %d potions", 
    playerName, total_aged, total_neons_created, total_megas_created, final_potions))

print("\n🔴 Disabling account...")
disableAccount()

print("\n========================================")
print("✅ SCRIPT COMPLETE & ACCOUNT DISABLED")
print("========================================")
