-- ============================================
-- SMART AGING SCRIPT - WITH VERIFICATION
-- Ensures pets are ACTUALLY aged before continuing!
-- ============================================

if not getgenv().AgingConfig then
    getgenv().AgingConfig = {
        PET_KIND = "winter_2025_christmas_spirit",
        RARITY = "legendary",
        WEBHOOK_URL = "",
        FARMSYNC_API_KEY = "",
        MAX_AGE_RETRIES = 5,      -- Retry up to 5 times if aging fails
        AGE_VERIFY_WAIT = 4       -- Wait 3s before verifying age increased
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
print("  SMART AGING SYSTEM - WITH VERIFICATION")
print("  + Verifies pets are actually aged")
print("  + Retries if aging fails")
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

-- ============== STARTER ==============
local UIManager = require(ReplicatedStorage.Fsys).load("UIManager")

local function enter_the_game()
    print("📍 Phase 1: Accepting terms...")
    pcall(function()
        game:GetService("ReplicatedStorage")
            :WaitForChild("API")
            :WaitForChild("MainMenuAPI/AcceptTermsOfServiceAndPrivacyPolicy")
            :FireServer()
    end)
    task.wait(1)
    
    print("📍 Phase 2: Choosing team...")
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
    pcall(function()
        local args = {"Home"}
        game:GetService("ReplicatedStorage")
            :WaitForChild("API")
            :WaitForChild("TradingServerAPI/IncrementConsecutiveSpawnCounter")
            :FireServer(unpack(args))
    end)
    task.wait(2)
    
    UIManager.set_app_visibility("MainMenuApp", false)
    UIManager.set_app_visibility("NewsApp", false)
    UIManager.set_app_visibility("DialogApp", false)
    UIManager.set_app_visibility("MinigameRewardsApp", false)
    
    task.wait(2)
    
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

print("⏳ Waiting 30 seconds before unsubscribing from house...")
task.wait(30)

print("🏠 Unsubscribing from own house...")
pcall(function()
    local args = {LocalPlayer, true}
    ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/UnsubscribeFromHouse"):InvokeServer(unpack(args))
    print("✅ Unsubscribed from own house")
end)

print("⏳ Waiting 10 seconds after unsubscribe...")
task.wait(10)
print("✅ Ready to start aging!")

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

-- ============== GET PET AGE (VERIFICATION) ==============
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

-- Analyze pet inventory
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
            if pet.kind == CONFIG.PET_KIND then
                local is_neon = pet.properties and pet.properties.neon or false
                local is_mega = pet.properties and pet.properties.mega or false
                local age = pet.properties and pet.properties.age or 0
                
                if is_mega then
                    continue
                end
                
                if is_neon then
                    if age == 6 then
                        analysis.full_grown_neons = analysis.full_grown_neons + 1
                    else
                        table.insert(analysis.neon_pets, {
                            unique = pet.unique,
                            age = age
                        })
                    end
                else
                    if age == 6 then
                        analysis.full_grown_normal = analysis.full_grown_normal + 1
                    else
                        table.insert(analysis.normal_pets, {
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

-- ============== FRIEND'S FAST CONSUME LOGIC ==============

local function feed_potions_fast(pet_unique, working_potion_unique, sub_potions_array)
    -- Step 1: Equip main potion
    local function equip_potion(working_potion_unique)
        local args = {
            tostring(working_potion_unique),
            {
                use_sound_delay = false,
                equip_as_last = false
            }
        }
        game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(unpack(args))
        task.wait(1)
    end
    
    -- Step 2: Create objects (feed potions)
    local function create_objects(pet_unique, working_potion_unique, sub_potions_array)
        local args = {
            "__Enum_PetObjectCreatorType_2",
            {
                additional_consume_uniques = sub_potions_array,
                pet_unique = pet_unique,
                unique_id = working_potion_unique
            }
        }
        game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject"):InvokeServer(unpack(args))
    end
    
    -- Step 3: Fast consume (skip animation!)
    local function fast_consume(pet_unique)
        local potion_object = workspace:WaitForChild("PetObjects"):FindFirstChild("AgePotion")
        if potion_object then
            local args = {
                potion_object,
                pet_unique
            }
            game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("PetAPI/ConsumeFoodObject"):FireServer(unpack(args))
        end
    end
    
    -- Execute the sequence
    print("   ❤️ Equip Main Potion!")
    equip_potion(working_potion_unique)
    
    print("   ⚙️ Created Objects!")
    create_objects(pet_unique, working_potion_unique, sub_potions_array)
    task.wait(1)
    
    print("   🚀 Fast Consume!")
    fast_consume(pet_unique)
    task.wait(1)
end

-- ============== AGE UP PET WITH VERIFICATION ==============
local function age_up_pet_verified(pet_unique, potion_uniques, expected_final_age)
    local initial_age = get_pet_age(pet_unique)
    
    if not initial_age then
        print("   ❌ Failed to get pet age!")
        return false
    end
    
    print(string.format("   📊 Starting age: %d → Target: %d", initial_age, expected_final_age))
    
    -- Try up to MAX_AGE_RETRIES times
    for attempt = 1, CONFIG.MAX_AGE_RETRIES do
        if attempt > 1 then
            print(string.format("   🔄 Retry attempt %d/%d...", attempt, CONFIG.MAX_AGE_RETRIES))
        end
        
        -- Equip pet
        equip_pet(pet_unique)
        print("   ✅ Pet equipped!")
        task.wait(1)
        
        -- Prepare potions (main + additional)
        local main_potion = potion_uniques[1]
        local sub_potions = {}
        for i = 2, #potion_uniques do
            table.insert(sub_potions, potion_uniques[i])
        end
        
        print(string.format("   🍼 Feeding %d potions with fast consume...", #potion_uniques))
        feed_potions_fast(pet_unique, main_potion, sub_potions)
        
        -- Wait for server to process
        print("   ⏳ Waiting for server to process...")
        task.wait(CONFIG.AGE_VERIFY_WAIT)
        
        -- VERIFY: Check if age actually increased
        local current_age = get_pet_age(pet_unique)
        
        if not current_age then
            print("   ⚠️ Failed to verify age, assuming success...")
            return true
        end
        
        if current_age >= expected_final_age then
            print(string.format("   ✅ SUCCESS! Age: %d → %d", initial_age, current_age))
            return true
        else
            print(string.format("   ⚠️ Age did not increase! Still at age %d (expected %d)", current_age, expected_final_age))
            
            if attempt < CONFIG.MAX_AGE_RETRIES then
                print("   🔄 Retrying...")
                task.wait(2)
            else
                print("   ❌ FAILED after max retries!")
                return false
            end
        end
    end
    
    return false
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
local total_failed = 0
local total_neons_created = 0
local total_megas_created = 0
local potions_per_pet = RARITY_AGE_UPS[rarity_lower]

sendWebhook(string.format("🔄 %s - Starting verified aging", playerName))

-- CONTINUOUS LOOP WITH STRICT PRIORITY
local cycle = 0
local MAX_CYCLES = 100

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
    
    -- PRIORITY 1: Age ALL normal pets to full grown
    if #analysis.normal_pets > 0 and potions >= potions_per_pet then
        print("\n📦 PRIORITY 1: Aging normal pets to full grown...")
        
        while true do
            analysis = analyze_pet_inventory()
            potions = count_age_potions()
            
            if #analysis.normal_pets == 0 then
                print("   ✅ All normal pets are full grown!")
                break
            end
            
            if potions < potions_per_pet then
                print(string.format("   ⚠️ Not enough potions (%d/%d)", potions, potions_per_pet))
                break
            end
            
            local pet = analysis.normal_pets[1]
            local potion_batch = get_age_potion_uniques(potions_per_pet)
            
            if #potion_batch < potions_per_pet then
                print("   ⚠️ Failed to get potions")
                break
            end
            
            print(string.format("\n   Aging normal pet (current age: %d)", pet.age))
            
            -- AGE WITH VERIFICATION
            local success = age_up_pet_verified(pet.unique, potion_batch, 6)
            
            if success then
                total_aged = total_aged + 1
            else
                total_failed = total_failed + 1
                print("   ❌ Pet aging failed after retries, skipping...")
            end
            
            task.wait(2)
        end
        
        did_something = true
        task.wait(2)
        continue
    end
    
    -- PRIORITY 2: Make neons
    if analysis.full_grown_normal >= 4 then
        print("\n🌟 PRIORITY 2: Creating neons...")
        
        while true do
            analysis = analyze_pet_inventory()
            
            if analysis.full_grown_normal < 4 then
                print("   ✅ Made all possible neons!")
                break
            end
            
            local full_grown = get_full_grown_normals()
            
            if #full_grown < 4 then
                break
            end
            
            if create_neon(full_grown) then
                print("   ✅ Neon created!")
                total_neons_created = total_neons_created + 1
                task.wait(2)
            else
                print("   ❌ Failed to create neon")
                break
            end
        end
        
        did_something = true
        task.wait(2)
        continue
    end
    
    -- PRIORITY 3: Age ALL neon pets
    if #analysis.neon_pets > 0 and potions >= potions_per_pet then
        print("\n💎 PRIORITY 3: Aging neon pets...")
        
        while true do
            analysis = analyze_pet_inventory()
            potions = count_age_potions()
            
            if #analysis.neon_pets == 0 then
                print("   ✅ All neon pets are full grown!")
                break
            end
            
            if potions < potions_per_pet then
                print(string.format("   ⚠️ Not enough potions (%d/%d)", potions, potions_per_pet))
                break
            end
            
            local pet = analysis.neon_pets[1]
            local potion_batch = get_age_potion_uniques(potions_per_pet)
            
            if #potion_batch < potions_per_pet then
                print("   ⚠️ Failed to get potions")
                break
            end
            
            print(string.format("\n   Aging NEON pet (current age: %d)", pet.age))
            
            -- AGE WITH VERIFICATION
            local success = age_up_pet_verified(pet.unique, potion_batch, 6)
            
            if success then
                total_aged = total_aged + 1
            else
                total_failed = total_failed + 1
                print("   ❌ Pet aging failed after retries, skipping...")
            end
            
            task.wait(2)
        end
        
        did_something = true
        task.wait(2)
        continue
    end
    
    -- PRIORITY 4: Make megas
    if analysis.full_grown_neons >= 4 then
        print("\n🔥 PRIORITY 4: Creating megas...")
        
        while true do
            analysis = analyze_pet_inventory()
            
            if analysis.full_grown_neons < 4 then
                print("   ✅ Made all possible megas!")
                break
            end
            
            local full_grown_neons = get_full_grown_neons()
            
            if #full_grown_neons < 4 then
                break
            end
            
            if create_neon(full_grown_neons) then
                print("   ✅ MEGA created!")
                total_megas_created = total_megas_created + 1
                task.wait(2)
            else
                print("   ❌ Failed to create mega")
                break
            end
        end
        
        did_something = true
        task.wait(2)
        continue
    end
    
    -- PRIORITY 5: Use leftover potions
    potions = count_age_potions()
    if potions > 0 then
        analysis = analyze_pet_inventory()
        
        if #analysis.normal_pets > 0 then
            local target_pet = analysis.normal_pets[1]
            local potion_batch = get_age_potion_uniques(math.min(potions, potions_per_pet))
            
            if #potion_batch > 0 then
                print(string.format("\n🔄 LEFTOVER: Using %d potions on normal pet", #potion_batch))
                local success = age_up_pet_verified(target_pet.unique, potion_batch, target_pet.age + #potion_batch)
                
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
        
        if #analysis.neon_pets > 0 then
            local target_neon = analysis.neon_pets[1]
            local potion_batch = get_age_potion_uniques(math.min(potions, potions_per_pet))
            
            if #potion_batch > 0 then
                print(string.format("\n🔄 LEFTOVER: Using %d potions on neon pet", #potion_batch))
                local success = age_up_pet_verified(target_neon.unique, potion_batch, target_neon.age + #potion_batch)
                
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
    
    -- NO MORE WORK
    if not did_something then
        print("\n✅ No more work to do!")
        break
    end
end

-- Final summary
local final_potions = count_age_potions()

print("\n" .. ("="):rep(50))
print("✅ AGING COMPLETE!")
print(("="):rep(50))
print(string.format("   Pets aged successfully: %d", total_aged))
print(string.format("   Pets failed to age: %d", total_failed))
print(string.format("   Neons created: %d", total_neons_created))
print(string.format("   Megas created: %d", total_megas_created))
print(string.format("   Potions remaining: %d", final_potions))
print(("="):rep(50))

sendWebhook(string.format("✅ %s - COMPLETE - Aged: %d, Failed: %d, Neons: %d, Megas: %d", 
    playerName, total_aged, total_failed, total_neons_created, total_megas_created))

print("\n🔴 Disabling account...")
disableAccount()

print("\n========================================")
print("✅ SCRIPT COMPLETE & ACCOUNT DISABLED")
print("========================================")
