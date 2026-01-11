-- ============================================
-- SMART AGING SCRIPT - FIXED LOGIC
-- Only works with specified pet kind!
-- Disables when no more work to do!
-- ============================================

if not getgenv().AgingConfig then
    getgenv().AgingConfig = {
        PET_KIND = "winter_2025_christmas_spirit",
        RARITY = "legendary",
        WEBHOOK_URL = "",
        FARMSYNC_API_KEY = "",
        MAX_AGE_RETRIES = 5,
        AGE_VERIFY_WAIT = 3
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
print("  SMART AGING SYSTEM - FIXED LOGIC")
print("  + Only works with specified pet")
print("  + Disables when done")
print("===========================================")
print("Pet Kind: " .. CONFIG.PET_KIND)
print("Rarity: " .. CONFIG.RARITY)
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

-- Dehash
print("🔧 Dehashing remotes...")
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end
print("✅ Remotes dehashed!")

-- Starter
local UIManager = require(ReplicatedStorage.Fsys).load("UIManager")

local function enter_the_game()
    print("📍 Phase 1: Accepting terms...")
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("MainMenuAPI/AcceptTermsOfServiceAndPrivacyPolicy"):FireServer()
    end)
    task.wait(1)
    
    print("📍 Phase 2: Choosing team...")
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/ChooseTeam"):InvokeServer("Parents", {
            source_for_logging = "intro_sequence",
            dont_enter_location = true
        })
    end)
    task.wait(1)
    
    print("📍 Phase 3: Spawning...")
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradingServerAPI/IncrementConsecutiveSpawnCounter"):FireServer("Home")
    end)
    task.wait(2)
    
    UIManager.set_app_visibility("MainMenuApp", false)
    UIManager.set_app_visibility("NewsApp", false)
    UIManager.set_app_visibility("DialogApp", false)
    UIManager.set_app_visibility("MinigameRewardsApp", false)
    
    task.wait(2)
    
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("DailyLoginAPI/ClaimDailyReward"):InvokeServer()
        UIManager.set_app_visibility("DailyLoginApp", false)
    end)
    
    print("✅ Fully spawned!")
end

enter_the_game()

print("⏳ Waiting 30 seconds before unsubscribing...")
task.wait(30)

print("🏠 Unsubscribing from house...")
pcall(function()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/UnsubscribeFromHouse"):InvokeServer(LocalPlayer, true)
end)

task.wait(10)
print("✅ Ready to start!")

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

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

local function disableAccount()
    if CONFIG.FARMSYNC_API_KEY == "" then
        print("⚠️ No API key")
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

-- ============== GET PET AGE ==============
local function get_pet_age(pet_unique)
    local age = nil
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for _, pet in pairs(playerData.inventory.pets) do
                if pet.unique == pet_unique then
                    age = pet.properties and pet.properties.age or 0
                    break
                end
            end
        end
    end)
    return age
end

-- ============== COUNT SPECIFIC PETS ONLY ==============
local function count_specific_pets()
    local count = 0
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for _, pet in pairs(playerData.inventory.pets) do
                -- ONLY count the specific pet kind!
                if pet.kind == CONFIG.PET_KIND then
                    count = count + 1
                end
            end
        end
    end)
    return count
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
                    if #potions >= amount then break end
                end
            end
        end
    end)
    return potions
end

-- ============== ANALYZE ONLY SPECIFIED PET KIND ==============
local function analyze_pet_inventory()
    local analysis = {
        normal_pets = {},
        neon_pets = {},
        full_grown_normal = 0,
        full_grown_neons = 0
    }
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then
            return
        end
        
        for _, pet in pairs(playerData.inventory.pets) do
            -- ONLY look at the specified pet kind!
            if pet.kind == CONFIG.PET_KIND then
                local is_neon = pet.properties and pet.properties.neon or false
                local is_mega = pet.properties and pet.properties.mega or false
                local age = pet.properties and pet.properties.age or 0
                
                -- Skip mega pets
                if is_mega then continue end
                
                if is_neon then
                    if age == 6 then
                        analysis.full_grown_neons = analysis.full_grown_neons + 1
                    else
                        table.insert(analysis.neon_pets, {unique = pet.unique, age = age})
                    end
                else
                    if age == 6 then
                        analysis.full_grown_normal = analysis.full_grown_normal + 1
                    else
                        table.insert(analysis.normal_pets, {unique = pet.unique, age = age})
                    end
                end
            end
        end
    end)
    
    return analysis
end

-- Get full grown normals (ONLY specified pet)
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

-- Get full grown neons (ONLY specified pet)
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
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(pet_unique, {
            use_sound_delay = true,
            equip_as_last = false
        })
    end)
end

-- Feed potions fast
local function feed_potions_fast(pet_unique, working_potion_unique, sub_potions_array)
    local function equip_potion(potion_unique)
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(tostring(potion_unique), {
            use_sound_delay = false,
            equip_as_last = false
        })
        task.wait(1)
    end
    
    local function create_objects(pet_unique, potion_unique, sub_potions)
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject"):InvokeServer(
            "__Enum_PetObjectCreatorType_2",
            {
                additional_consume_uniques = sub_potions,
                pet_unique = pet_unique,
                unique_id = potion_unique
            }
        )
    end
    
    local function fast_consume(pet_unique)
        local potion_object = workspace:WaitForChild("PetObjects"):FindFirstChild("AgePotion")
        if potion_object then
            ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/ConsumeFoodObject"):FireServer(potion_object, pet_unique)
        end
    end
    
    print("   ❤️ Equip Potion")
    equip_potion(working_potion_unique)
    
    print("   ⚙️ Feed")
    create_objects(pet_unique, working_potion_unique, sub_potions_array)
    task.wait(1)
    
    print("   🚀 Fast Consume")
    fast_consume(pet_unique)
    task.wait(1)
end

-- Age up with verification
local function age_up_pet_verified(pet_unique, potion_uniques, expected_final_age)
    local initial_age = get_pet_age(pet_unique)
    
    if not initial_age then
        print("   ❌ Can't get pet age")
        return false
    end
    
    print(string.format("   📊 Age: %d → %d", initial_age, expected_final_age))
    
    for attempt = 1, CONFIG.MAX_AGE_RETRIES do
        if attempt > 1 then
            print(string.format("   🔄 Retry %d/%d", attempt, CONFIG.MAX_AGE_RETRIES))
        end
        
        equip_pet(pet_unique)
        print("   ✅ Equipped")
        task.wait(1)
        
        local main_potion = potion_uniques[1]
        local sub_potions = {}
        for i = 2, #potion_uniques do
            table.insert(sub_potions, potion_uniques[i])
        end
        
        print(string.format("   🍼 Feeding %d potions", #potion_uniques))
        feed_potions_fast(pet_unique, main_potion, sub_potions)
        
        print("   ⏳ Verifying...")
        task.wait(CONFIG.AGE_VERIFY_WAIT)
        
        local current_age = get_pet_age(pet_unique)
        
        if not current_age then
            print("   ⚠️ Can't verify, assuming success")
            return true
        end
        
        if current_age >= expected_final_age then
            print(string.format("   ✅ SUCCESS! %d → %d", initial_age, current_age))
            return true
        else
            print(string.format("   ⚠️ Still age %d", current_age))
            if attempt < CONFIG.MAX_AGE_RETRIES then
                task.wait(2)
            end
        end
    end
    
    print("   ❌ FAILED after retries")
    return false
end

-- Create neon
local function create_neon(pet_uniques)
    if #pet_uniques < 4 then return false end
    
    local success = false
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/DoNeonFusion"):InvokeServer({
            pet_uniques[1], pet_uniques[2], pet_uniques[3], pet_uniques[4]
        })
        success = true
    end)
    return success
end

-- ============== MAIN EXECUTION ==============

local function run_aging()
    print("\n🔍 Checking inventory...")

    -- Check if account has the specified pet
    local total_pets = count_specific_pets()

    if total_pets == 0 then
        print("\n❌ NO PETS OF TYPE: " .. CONFIG.PET_KIND)
        print("   Account has 0 of this pet kind")
        sendWebhook(string.format("❌ %s - No pets of kind: %s - Disabling", playerName, CONFIG.PET_KIND))
        disableAccount()
        return
    end

    print(string.format("✅ Found %d pets of kind: %s", total_pets, CONFIG.PET_KIND))

    -- Check if account has potions
    local total_potions = count_age_potions()

    if total_potions == 0 then
        print("\n❌ NO AGE POTIONS")
        sendWebhook(string.format("❌ %s - No potions - Disabling", playerName))
        disableAccount()
        return
    end

    print(string.format("✅ Found %d age potions", total_potions))

    local total_aged = 0
local total_failed = 0
local total_neons = 0
local total_megas = 0
local potions_per_pet = RARITY_AGE_UPS[rarity_lower]

sendWebhook(string.format("🔄 %s - Starting: %d %s pets, %d potions", 
    playerName, total_pets, CONFIG.PET_KIND, total_potions))

local cycle = 0
local MAX_CYCLES = 100

while cycle < MAX_CYCLES do
    cycle = cycle + 1
    print(string.format("\n========== CYCLE %d ==========", cycle))
    
    local analysis = analyze_pet_inventory()
    local potions = count_age_potions()
    
    print(string.format("📊 %s:", CONFIG.PET_KIND))
    print(string.format("   Potions: %d", potions))
    print(string.format("   Normal (not age 6): %d", #analysis.normal_pets))
    print(string.format("   Normal (age 6): %d", analysis.full_grown_normal))
    print(string.format("   Neon (not age 6): %d", #analysis.neon_pets))
    print(string.format("   Neon (age 6): %d", analysis.full_grown_neons))
    
    local did_something = false
    
    -- ============================================
    -- PRIORITY 1: Age normal pets
    -- ============================================
    if #analysis.normal_pets > 0 and potions >= potions_per_pet then
        print("\n📦 PRIORITY 1: Aging normal pets...")
        
        local pet = analysis.normal_pets[1]
        local potion_batch = get_age_potion_uniques(potions_per_pet)
        
        if #potion_batch >= potions_per_pet then
            print(string.format("   Aging pet (age: %d)", pet.age))
            
            local success = age_up_pet_verified(pet.unique, potion_batch, 6)
            
            if success then
                total_aged = total_aged + 1
            else
                total_failed = total_failed + 1
            end
            
            did_something = true
            task.wait(2)
            continue
        end
    end
    
    -- ============================================
    -- PRIORITY 2: Make neons from full grown normals
    -- ============================================
    if analysis.full_grown_normal >= 4 then
        print("\n🌟 PRIORITY 2: Making neon...")
        
        local full_grown = get_full_grown_normals()
        
        if #full_grown >= 4 then
            if create_neon(full_grown) then
                print("   ✅ Neon created!")
                total_neons = total_neons + 1
                did_something = true
                task.wait(2)
                continue
            end
        end
    end
    
    -- ============================================
    -- PRIORITY 3: Age neon pets
    -- ============================================
    if #analysis.neon_pets > 0 and potions >= potions_per_pet then
        print("\n💎 PRIORITY 3: Aging neon pets...")
        
        local pet = analysis.neon_pets[1]
        local potion_batch = get_age_potion_uniques(potions_per_pet)
        
        if #potion_batch >= potions_per_pet then
            print(string.format("   Aging neon (age: %d)", pet.age))
            
            local success = age_up_pet_verified(pet.unique, potion_batch, 6)
            
            if success then
                total_aged = total_aged + 1
            else
                total_failed = total_failed + 1
            end
            
            did_something = true
            task.wait(2)
            continue
        end
    end
    
    -- ============================================
    -- PRIORITY 4: Make megas from full grown neons
    -- ============================================
    if analysis.full_grown_neons >= 4 then
        print("\n🔥 PRIORITY 4: Making mega...")
        
        local full_grown_neons = get_full_grown_neons()
        
        if #full_grown_neons >= 4 then
            if create_neon(full_grown_neons) then
                print("   ✅ Mega created!")
                total_megas = total_megas + 1
                did_something = true
                task.wait(2)
                continue
            end
        end
    end
    
    -- ============================================
    -- PRIORITY 5: Use leftover potions
    -- ============================================
    potions = count_age_potions()
    if potions > 0 and potions < potions_per_pet then
        analysis = analyze_pet_inventory()
        
        -- Try to use leftovers on non-age-6 pets
        if #analysis.normal_pets > 0 then
            local pet = analysis.normal_pets[1]
            local potion_batch = get_age_potion_uniques(potions)
            
            if #potion_batch > 0 and pet.age < 6 then
                print(string.format("\n🔄 LEFTOVER: Using %d potions", #potion_batch))
                local success = age_up_pet_verified(pet.unique, potion_batch, pet.age + #potion_batch)
                
                if success then
                    total_aged = total_aged + 1
                else
                    total_failed = total_failed + 1
                end
                
                did_something = true
                task.wait(2)
                continue
            end
        elseif #analysis.neon_pets > 0 then
            local pet = analysis.neon_pets[1]
            local potion_batch = get_age_potion_uniques(potions)
            
            if #potion_batch > 0 and pet.age < 6 then
                print(string.format("\n🔄 LEFTOVER: Using %d potions on neon", #potion_batch))
                local success = age_up_pet_verified(pet.unique, potion_batch, pet.age + #potion_batch)
                
                if success then
                    total_aged = total_aged + 1
                else
                    total_failed = total_failed + 1
                end
                
                did_something = true
                task.wait(2)
                continue
            end
        end
    end
    
    -- ============================================
    -- NO MORE WORK - DISABLE!
    -- ============================================
    if not did_something then
        local final_potions = count_age_potions()
        local final_analysis = analyze_pet_inventory()
        
        -- Check if all pets are age 6
        local all_age_6 = (#final_analysis.normal_pets == 0) and 
                          (#final_analysis.neon_pets == 0) and 
                          (final_analysis.full_grown_normal + final_analysis.full_grown_neons > 0)
        
        print("\n✅ NO MORE WORK!")
        print(string.format("   Remaining potions: %d", final_potions))
        
        if all_age_6 then
            print("   All pets are age 6!")
        elseif final_potions < potions_per_pet then
            print(string.format("   Not enough potions (need %d)", potions_per_pet))
        end
        
        break
    end
end

-- Final summary
local final_potions = count_age_potions()

print("\n" .. ("="):rep(50))
print("✅ COMPLETE!")
print(("="):rep(50))
print(string.format("   Aged: %d", total_aged))
print(string.format("   Failed: %d", total_failed))
    print(string.format("   Neons: %d", total_neons))
    print(string.format("   Megas: %d", total_megas))
    print(string.format("   Remaining potions: %d", final_potions))
    print(("="):rep(50))
    
    sendWebhook(string.format("✅ %s - COMPLETE\nAged: %d | Neons: %d | Megas: %d\nRemaining potions: %d", 
        playerName, total_aged, total_neons, total_megas, final_potions))
    
    print("\n🔴 Disabling account...")
    disableAccount()
    
    print("\n========================================")
    print("✅ SCRIPT COMPLETE & ACCOUNT DISABLED")
    print("========================================")
end

-- Run the aging function
run_aging()

print("\n========================================")
print("✅ SCRIPT FINISHED")
print("========================================")
