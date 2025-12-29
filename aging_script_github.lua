-- ============================================
-- SMART AGING SCRIPT
-- Ages pets, creates neons automatically, disables when done
-- ============================================

if not getgenv().AgingConfig then
    getgenv().AgingConfig = {
        PET_KIND = "winter_2025_christmas_spirit",
        RARITY = "legendary",
        WEBHOOK_URL = "",  -- NEW: For Discord notifications
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
print("  SMART AGING SYSTEM")
print("  Ages → Neon → Ages → Success")
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

-- ============== STARTER - EXACT COPY FROM WORKING STARTER.LUA ==============
local UIManager = require(ReplicatedStorage.Fsys).load("UIManager")

local function enter_the_game()
    local function chooserole()
        local args = {
            [1] = "Parents",
            [2] = {
                ["source_for_logging"] = "intro_sequence",
            },
        }
        game:GetService("ReplicatedStorage")
            :WaitForChild("API")
            :WaitForChild("TeamAPI/ChooseTeam")
            :InvokeServer(unpack(args))
    end
    chooserole()
    task.wait(1)
    local ui_stuff = require(game:GetService("ReplicatedStorage").Fsys).load("UIManager")
    ui_stuff.set_app_visibility("MainMenuApp", false)
    ui_stuff.set_app_visibility("NewsApp", false)
    ui_stuff.set_app_visibility("DialogApp", false)
    ui_stuff.set_app_visibility("MinigameRewardsApp", false)

    task.wait(3)
    game:GetService("ReplicatedStorage")
        :WaitForChild("API")
        :WaitForChild("DailyLoginAPI/ClaimDailyReward")
        :InvokeServer()
    ui_stuff.set_app_visibility("DailyLoginApp", false)
end

print("🎮 Entering game...")
enter_the_game()
print("✅ Game entered!")

for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

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

-- Send webhook notification
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

-- Count age potions (they're items in food inventory, not currency!)
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

-- Get age potion unique IDs (needed for using them)
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

-- Count ALL pets that can be aged (including neons)
local function count_all_ageable_pets()
    local count = 0
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for _, pet in pairs(playerData.inventory.pets) do
                if pet.kind == CONFIG.PET_KIND then
                    local age = pet.properties and pet.properties.age or 0
                    -- Count any pet that's not full grown (age < 6)
                    if age < 6 then
                        count = count + 1
                    end
                end
            end
        end
    end)
    return count
end

-- Get pets that need aging (normal pets first, then neons, SKIP age 6)
local function get_pets_to_age(include_neons)
    local pets = {}
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for _, pet in pairs(playerData.inventory.pets) do
                if pet.kind == CONFIG.PET_KIND then
                    local is_neon = pet.properties and pet.properties.neon
                    local is_mega = pet.properties and pet.properties.mega
                    local age = pet.properties and pet.properties.age or 0
                    
                    -- SKIP age 6 pets (already full grown)
                    if age >= 6 then
                        continue
                    end
                    
                    -- SKIP mega pets (can't age further)
                    if is_mega then
                        continue
                    end
                    
                    -- If include_neons is true, get everything
                    -- If false, only get normal pets
                    if include_neons or not is_neon then
                        table.insert(pets, {
                            unique = pet.unique,
                            age = age,
                            is_neon = is_neon,
                            is_mega = is_mega
                        })
                    end
                end
            end
        end
    end)
    
    -- Sort: normal pets first, then neons
    table.sort(pets, function(a, b)
        if a.is_neon ~= b.is_neon then
            return not a.is_neon -- false (normal) comes before true (neon)
        end
        return a.age < b.age -- Lower age first
    end)
    
    return pets
end

-- Equip pet before aging (CORRECT REMOTE)
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

-- Age up pet using potion unique IDs (CORRECT REMOTE)
local function age_up_pet(pet_unique, potion_uniques)
    -- First equip the pet
    equip_pet(pet_unique)
    task.wait(1) -- Wait for equip
    
    pcall(function()
        -- Main potion
        local main_potion = potion_uniques[1]
        
        -- Additional potions (all except first)
        local additional = {}
        for i = 2, #potion_uniques do
            table.insert(additional, potion_uniques[i])
        end
        
        -- Feed potions using CreatePetObject (this ages the pet)
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject"):InvokeServer(
            "__Enum_PetObjectCreatorType_2",
            {
                pet_unique = pet_unique,
                unique_id = main_potion,
                additional_consume_uniques = additional
            }
        )
    end)
    
    task.wait(10) -- Wait for aging animation
end

-- Create neon (CORRECT REMOTE)
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

-- Create MEGA neon (SAME REMOTE AS NEON!)
local function create_mega(neon_uniques)
    if #neon_uniques < 4 then
        return false
    end
    
    local success = false
    pcall(function()
        -- Same remote! Just pass 4 neons instead of 4 normal pets
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/DoNeonFusion"):InvokeServer(
            {neon_uniques[1], neon_uniques[2], neon_uniques[3], neon_uniques[4]}
        )
        success = true
    end)
    return success
end

-- Get full grown pets (normal, not neon, age 6)
local function get_full_grown_pets()
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

-- Get full grown NEON pets (for mega creation)
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

-- Main execution
print("\n🔍 Analyzing inventory...")

local potions = count_age_potions()
local potions_per_pet = RARITY_AGE_UPS[rarity_lower]

print(string.format("\n📊 Current Status:"))
print(string.format("   Potions: %d", potions))
print(string.format("   Potions per pet: %d", potions_per_pet))

if potions < potions_per_pet then
    print("\n❌ Not enough potions to age any pets!")
    sendWebhook(string.format("❌ %s - Not enough potions (%d)", playerName, potions))
    print("   Disabling account...")
    disableAccount()
    return
end

sendWebhook(string.format("🔄 %s - Starting aging - Potions: %d", playerName, potions))

-- PHASE 1: Age normal pets and create neons
print("\n=== PHASE 1: Normal Pets → Neons ===")

local normal_pets = get_pets_to_age(false) -- Only normal pets
local can_age = math.floor(potions / potions_per_pet)
local to_age_normal = math.min(can_age, #normal_pets)

print(string.format("   Normal pets available: %d", #normal_pets))
print(string.format("   Will age: %d normal pets", to_age_normal))

local aged_count = 0

for i = 1, to_age_normal do
    local pet = normal_pets[i]
    
    -- Get potions needed for this pet
    local potions_needed = get_age_potion_uniques(potions_per_pet)
    
    if #potions_needed < potions_per_pet then
        print(string.format("   ⚠️ Not enough potions! Have %d, need %d", #potions_needed, potions_per_pet))
        break
    end
    
    print(string.format("   Aging normal pet %d/%d (age: %d)", i, to_age_normal, pet.age))
    age_up_pet(pet.unique, potions_needed)
    aged_count = aged_count + 1
    -- No task.wait here - it's in age_up_pet function now
end

print(string.format("✅ Aged %d normal pets", aged_count))
task.wait(2)

-- Create neons from full grown
print("\n🔍 Creating neons from full grown pets...")
task.wait(1)

local full_grown = get_full_grown_pets()
print(string.format("   Found %d full grown pets", #full_grown))

local neons_created = 0

while #full_grown >= 4 do
    print(string.format("\n🌟 Creating neon #%d...", neons_created + 1))
    
    if create_neon(full_grown) then
        print("   ✅ Neon created!")
        neons_created = neons_created + 1
        task.wait(2)
        full_grown = get_full_grown_pets()
    else
        warn("   ❌ Failed to create neon")
        break
    end
end

print(string.format("\n✅ Phase 1 complete: %d neons created", neons_created))
sendWebhook(string.format("🌟 %s - Phase 1 done - Aged: %d pets, Neons: %d", playerName, aged_count, neons_created))

-- Check for full grown neons and create MEGA
if neons_created >= 4 then
    print("\n🌟 Checking for mega neon creation...")
    task.wait(2)
    
    local full_grown_neons = get_full_grown_neons()
    print(string.format("   Found %d full grown neons", #full_grown_neons))
    
    local megas_created = 0
    
    while #full_grown_neons >= 4 do
        print(string.format("\n💎 Creating MEGA neon #%d...", megas_created + 1))
        
        if create_mega(full_grown_neons) then
            print("   ✅ MEGA neon created!")
            megas_created = megas_created + 1
            task.wait(2)
            full_grown_neons = get_full_grown_neons()
        else
            warn("   ❌ Failed to create mega neon")
            break
        end
    end
    
    if megas_created > 0 then
        print(string.format("\n🎉 Created %d MEGA neon(s)!", megas_created))
        sendWebhook(string.format("💎 %s - Created %d MEGA neon(s)!", playerName, megas_created))
    end
else
    print("\n⚠️ Not enough neons for mega (need 4 full grown neons)")
end

-- PHASE 2: Use remaining potions on ANY pet (including neons)
print("\n=== PHASE 2: Use Remaining Potions ===")

local remaining_potions = count_age_potions()
print(string.format("   Potions remaining: %d", remaining_potions))

if remaining_potions >= potions_per_pet then
    local all_pets = get_pets_to_age(true) -- Include neons now!
    local can_age_more = math.floor(remaining_potions / potions_per_pet)
    local to_age_extra = math.min(can_age_more, #all_pets)
    
    print(string.format("   Ageable pets (including neons): %d", #all_pets))
    print(string.format("   Will age: %d more pets", to_age_extra))
    
    for i = 1, to_age_extra do
        local pet = all_pets[i]
        local pet_type = pet.is_neon and "NEON" or "normal"
        
        -- Get potions for this pet
        local potions_needed = get_age_potion_uniques(potions_per_pet)
        
        if #potions_needed < potions_per_pet then
            print(string.format("   ⚠️ Ran out of potions after aging %d pets", i - 1))
            break
        end
        
        print(string.format("   Aging %s pet %d/%d (age: %d)", pet_type, i, to_age_extra, pet.age))
        age_up_pet(pet.unique, potions_needed)
        aged_count = aged_count + 1
        -- No task.wait here - it's in age_up_pet function now
    end
    
    print(string.format("✅ Used remaining potions on %d pets", to_age_extra))
    sendWebhook(string.format("⚡ %s - Phase 2 done - Used remaining potions on %d pets", playerName, to_age_extra))
else
    print(string.format("   Only %d potions left (need %d to age)", remaining_potions, potions_per_pet))
    print("   ✅ Not enough to age any more pets")
end

-- Final status
local final_potions = count_age_potions()
local final_neons = get_full_grown_neons()
local final_megas = 0

pcall(function()
    local playerData = Data.get_data()[playerName]
    if playerData and playerData.inventory and playerData.inventory.pets then
        for _, pet in pairs(playerData.inventory.pets) do
            if pet.kind == CONFIG.PET_KIND then
                local is_mega = pet.properties and pet.properties.mega
                if is_mega then
                    final_megas = final_megas + 1
                end
            end
        end
    end
end)

print("\n" .. ("="):rep(50))
print("✅ AGING COMPLETE!")
print(("="):rep(50))
print(string.format("   Total pets aged: %d", aged_count))
print(string.format("   Neons created: %d", neons_created))
print(string.format("   Megas created: %d", final_megas))
print(string.format("   Full grown neons remaining: %d", #final_neons))
print(string.format("   Potions used: %d", potions - final_potions))
print(string.format("   Potions remaining: %d", final_potions))
print(("="):rep(50))

print("\n🔴 Disabling account...")
sendWebhook(string.format("✅ %s - AGING COMPLETE - Aged: %d, Neons: %d, Megas: %d, Potions used: %d", 
    playerName, aged_count, neons_created, final_megas, potions - final_potions))
disableAccount()

print("\n========================================")
print("✅ SCRIPT COMPLETE & ACCOUNT DISABLED")
print("========================================")
