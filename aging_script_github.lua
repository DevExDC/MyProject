-- ============================================
-- SMART AGING SCRIPT V2 - MULTI-PET SUPPORT
-- + FarmSync Auto-Disable
-- + AccountOps Auto-Disable
-- Pet resolved by name (resolveItem)
-- Supports multiple pet names with fallback
-- Friend's entry logic + UI disable
-- Kicks game when done
-- ============================================

if not getgenv().AgingConfig then
    getgenv().AgingConfig = {
        -- 🐾 Use PET_NAMES for multiple pets (tries in order)
        PET_NAMES = {
            "Christmas Spirit",
            -- "Lunar Dragon",
            -- "Capybara",
        },
        
        -- OR use PET_NAME for single pet (old way)
        -- PET_NAME = "Christmas Spirit",
        
        WEBHOOK_URL = "",

        -- FarmSync (optional, leave "" to skip)
        FARMSYNC_API_KEY = "",
        FARMSYNC_AUTO_DISABLE = false,  -- true = auto-disable when done

        -- AccountOps (optional, leave "" to skip)
        ACCOUNTOPS_API_KEY = "",
        ACCOUNTOPS_AUTO_DISABLE = false,  -- true = auto-disable when done
    }
end

local CONFIG = getgenv().AgingConfig

-- Default settings
if CONFIG.PET_DELAY == nil then CONFIG.PET_DELAY = 5 end
if CONFIG.DEBUG_LOGGING == nil then CONFIG.DEBUG_LOGGING = true end

-- Hardcoded aging settings
local MAX_AGE_RETRIES = 5
local AGE_VERIFY_WAIT = 3

-- ============================================
-- SERVICES (Early init)
-- ============================================
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local request = (syn and syn.request) or (http and http.request) or http_request

-- ============================================
-- FARMSYNC DISABLE FUNCTION
-- ============================================
local function disable_farmsync_account()
    if not CONFIG.FARMSYNC_AUTO_DISABLE then
        print("ℹ️ FarmSync auto-disable is OFF")
        return
    end

    if not CONFIG.FARMSYNC_API_KEY or CONFIG.FARMSYNC_API_KEY == "" then
        print("⚠️ FarmSync API key not set, skipping disable")
        return
    end

    if not request then
        print("❌ HTTP request function not available")
        return
    end

    print("\n🔴 Disabling FarmSync account...")

    local success, response = pcall(function()
        return request({
            Url = "https://api.farmsync.cloud/api/self/accounts/" .. LocalPlayer.Name,
            Method = "PUT",
            Headers = {
                ["Authorization"] = "Bearer " .. CONFIG.FARMSYNC_API_KEY,
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({ enabled = false })
        })
    end)

    if success and response and response.StatusCode and response.StatusCode >= 200 and response.StatusCode < 300 then
        print("✅ FarmSync account disabled! (Status: " .. response.StatusCode .. ")")
        if CONFIG.WEBHOOK_URL and CONFIG.WEBHOOK_URL ~= "" then
            pcall(function()
                request({
                    Url = CONFIG.WEBHOOK_URL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({
                        content = string.format("✅ %s - FarmSync account disabled (Status %d)", LocalPlayer.Name, response.StatusCode)
                    })
                })
            end)
        end
    else
        local err = response and response.StatusCode or "unknown error"
        print("❌ Failed to disable FarmSync: " .. tostring(err))
        if CONFIG.WEBHOOK_URL and CONFIG.WEBHOOK_URL ~= "" then
            pcall(function()
                request({
                    Url = CONFIG.WEBHOOK_URL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({
                        content = string.format("❌ %s - Failed to disable FarmSync (%s)", LocalPlayer.Name, tostring(err))
                    })
                })
            end)
        end
    end
end

-- ============================================
-- ACCOUNTOPS DISABLE FUNCTION
-- ============================================
local function disable_accountops_account()
    if not CONFIG.ACCOUNTOPS_AUTO_DISABLE then
        print("ℹ️ AccountOps auto-disable is OFF")
        return
    end

    if not CONFIG.ACCOUNTOPS_API_KEY or CONFIG.ACCOUNTOPS_API_KEY == "" then
        print("⚠️ AccountOps API key not set, skipping disable")
        return
    end

    if not request then
        print("❌ HTTP request function not available")
        return
    end

    print("\n🔴 Disabling AccountOps account...")

    local success, response = pcall(function()
        return request({
            Url = "https://accountops.org/api/accounts/enable",
            Method = "PUT",
            Headers = {
                ["Content-Type"] = "application/json",
                ["X-Api-Key"]    = CONFIG.ACCOUNTOPS_API_KEY
            },
            Body = HttpService:JSONEncode({
                usernames = { LocalPlayer.Name },
                enabled   = false
            })
        })
    end)

    if success and response and response.StatusCode and response.StatusCode >= 200 and response.StatusCode < 300 then
        print("✅ AccountOps account disabled! (Status: " .. response.StatusCode .. ")")
        if CONFIG.WEBHOOK_URL and CONFIG.WEBHOOK_URL ~= "" then
            pcall(function()
                request({
                    Url = CONFIG.WEBHOOK_URL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({
                        content = string.format("✅ %s - AccountOps account disabled (Status %d)", LocalPlayer.Name, response.StatusCode)
                    })
                })
            end)
        end
    else
        local err = response and response.StatusCode or "unknown error"
        print("❌ Failed to disable AccountOps: " .. tostring(err))
        if CONFIG.WEBHOOK_URL and CONFIG.WEBHOOK_URL ~= "" then
            pcall(function()
                request({
                    Url = CONFIG.WEBHOOK_URL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = HttpService:JSONEncode({
                        content = string.format("❌ %s - Failed to disable AccountOps (%s)", LocalPlayer.Name, tostring(err))
                    })
                })
            end)
        end
    end
end

-- ============================================
-- MASTER DISABLE (calls both if configured)
-- ============================================
local function disable_all_accounts()
    disable_farmsync_account()
    disable_accountops_account()
end

-- ============================================
-- MULTI-PET NAME RESOLVER
-- ============================================
local function findAndSelectPet()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local playerName = LocalPlayer.Name
    
    local function resolveItem(input)
        local db = require(ReplicatedStorage
            :WaitForChild("ClientDB")
            :WaitForChild("Inventory")
            :WaitForChild("KindDB"))
        local search = input:lower()
        local nameMatch = nil

        for _, v in pairs(db) do
            if v.kind and v.kind:lower() == search then
                return v.kind, v, "kind"
            end
            if not nameMatch and v.name and v.name:lower() == search then
                nameMatch = v
            end
        end

        if nameMatch then
            return nameMatch.kind, nameMatch, "name"
        end

        return nil
    end
    
    local function countPets(petKind)
        local count = 0
        pcall(function()
            local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)
            local playerData = Data.get_data()[playerName]
            if playerData and playerData.inventory and playerData.inventory.pets then
                for _, pet in pairs(playerData.inventory.pets) do
                    if pet.kind == petKind then
                        count = count + 1
                    end
                end
            end
        end)
        return count
    end
    
    if CONFIG.PET_NAMES and #CONFIG.PET_NAMES > 0 then
        print("🔍 Multi-Pet Mode: Searching for available pets...")
        print("=" .. string.rep("=", 50))
        
        for i, petName in ipairs(CONFIG.PET_NAMES) do
            print(string.format("\n[%d/%d] Checking: %s", i, #CONFIG.PET_NAMES, petName))
            
            local resolved_kind, resolved_data = resolveItem(petName)
            
            if resolved_kind then
                print("  ✅ Found in database!")
                
                local count = countPets(resolved_kind)
                print(string.format("  📊 You have %d of these", count))
                
                if count > 0 then
                    print(string.format("  🎯 SELECTED: %s", petName))
                    print("=" .. string.rep("=", 50))
                    CONFIG.PET_NAME = petName
                    return true
                else
                    print("  ⚠️ You don't have any, trying next...")
                end
            else
                print("  ❌ Not found in database, trying next...")
            end
        end
        
        print("\n❌ ERROR: None of the pet types found in your inventory!")
        print("\nPets searched:")
        for i, name in ipairs(CONFIG.PET_NAMES) do
            print(string.format("  %d. %s", i, name))
        end
        
        disable_all_accounts()
        
        print("\n❌ Exiting script - No pets available")
        
        if CONFIG.AUTO_KICK ~= false then
            task.wait(3)
            game.Players.LocalPlayer:Kick("❌ No pets available from the list!")
        end
        
        return false
        
    elseif CONFIG.PET_NAME and CONFIG.PET_NAME ~= "" then
        print("🐾 Single-Pet Mode: " .. CONFIG.PET_NAME)
        return true
    else
        error("❌ No PET_NAME or PET_NAMES configured!")
    end
end

local pet_selection_success = findAndSelectPet()

if not pet_selection_success then
    print("✅ Script terminated gracefully")
    return
end

if not CONFIG.PET_NAME or CONFIG.PET_NAME == "" then
    error("❌ No pet selected!")
end

-- ============================================
-- WAIT FOR GAME READY
-- ============================================
repeat task.wait(1) until game:IsLoaded()
    and game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
    and game:GetService("ReplicatedStorage").ClientModules:FindFirstChild("Core")
    and game:GetService("ReplicatedStorage").ClientModules.Core:FindFirstChild("UIManager")
    and game:GetService("ReplicatedStorage").ClientModules.Core:FindFirstChild("UIManager").Apps:FindFirstChild("TransitionsApp")
    and game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("TransitionsApp")
    and game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("TransitionsApp"):FindFirstChild("Whiteout")

repeat task.wait(1) until game:GetService("Players").LocalPlayer.PlayerGui
    and game:GetService("Players").LocalPlayer.PlayerGui.AssetLoadUI
    and (game:GetService("Players").LocalPlayer.PlayerGui.AssetLoadUI.Enabled == false)

task.wait(1)
print("[1] Check Done")

-- ============================================
-- SERVICES
-- ============================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local playerName = LocalPlayer.Name

-- ============================================
-- RESOLVE ITEM FUNCTION
-- ============================================
local function resolveItem(input)
    local db = require(ReplicatedStorage
        :WaitForChild("ClientDB")
        :WaitForChild("Inventory")
        :WaitForChild("KindDB"))
    local search = input:lower()
    local nameMatch = nil

    for _, v in pairs(db) do
        if v.kind and v.kind:lower() == search then
            print(
                "✨ Found with KIND",
                "| Name:", v.name or "unknown",
                "| Kind:", v.kind or "unknown",
                "| Rarity:", v.rarity or "N/A",
                "| Category:", v.category or "unknown"
            )
            return v.kind, v, "kind"
        end
        if not nameMatch and v.name and v.name:lower() == search then
            nameMatch = v
        end
    end

    if nameMatch then
        print(
            "🐾 Found with NAME",
            "| Name:", nameMatch.name or "unknown",
            "| Kind:", nameMatch.kind or "unknown",
            "| Rarity:", nameMatch.rarity or "N/A",
            "| Category:", nameMatch.category or "unknown"
        )
        return nameMatch.kind, nameMatch, "name"
    end

    warn("❌ Item not found:", input)
    return nil
end

-- ============================================
-- RESOLVE PET FROM NAME → KIND + RARITY
-- ============================================
print("🔍 Resolving pet: " .. CONFIG.PET_NAME .. "...")
local resolved_kind, resolved_data = resolveItem(CONFIG.PET_NAME)

if not resolved_kind then
    error("❌ Could not resolve pet: " .. CONFIG.PET_NAME .. " — double check the name!")
end

CONFIG.PET_KIND = resolved_kind
CONFIG.RARITY = (resolved_data.rarity or ""):lower():gsub("%s+", "_")

print("✅ Resolved → Kind: " .. CONFIG.PET_KIND .. " | Rarity: " .. CONFIG.RARITY)

-- ============================================
-- RARITY → POTIONS NEEDED PER PET
-- ============================================
local RARITY_AGE_UPS = {
    legendary   = 7,
    ultra_rare  = 4,
    rare        = 2,
    uncommon    = 2,
    common      = 1
}

local potions_per_pet = RARITY_AGE_UPS[CONFIG.RARITY]
if not potions_per_pet then
    error("❌ Invalid rarity resolved: " .. tostring(CONFIG.RARITY))
end

-- ============================================
-- ANTI-AFK
-- ============================================
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
print("✅ Anti-AFK enabled")

-- ============================================
-- REMOTE DEHASH
-- ============================================
print("🔧 Dehashing remotes...")
local RouterClient = require(ReplicatedStorage.ClientModules.Core:WaitForChild("RouterClient"):WaitForChild("RouterClient"))

local function dehash()
    local fn = RouterClient.init
    for i = 1, 30 do
        local ok, val = pcall(debug.getupvalue, fn, i)
        if ok and type(val) == "table" then
            local hasRemotes = false
            for _, v in pairs(val) do
                if typeof(v) == "Instance" and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
                    hasRemotes = true
                    break
                end
            end
            if hasRemotes then
                for name, remote in pairs(val) do
                    pcall(function() remote.Name = name end)
                end
                print("[Dehash] ✅ Success at upvalue index " .. i)
                return true
            end
        end
    end
    warn("[Dehash] ⚠️ Failed — no remote table found in upvalues")
    return false
end

dehash()
print("✅ Remotes dehashed!")

-- ============================================
-- DISABLE USELESS UI
-- ============================================
LocalPlayer.PlayerGui.DialogApp.Enabled = false

-- ============================================
-- ENTER THE GAME
-- ============================================
local UIManager = require(ReplicatedStorage.Fsys).load("UIManager")

local function enter_the_game()
    print("📍 Choosing team...")
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/ChooseTeam"):InvokeServer("Parents", {
        source_for_logging = "intro_sequence"
    })
    task.wait(1)

    UIManager.set_app_visibility("MainMenuApp", false)
    UIManager.set_app_visibility("NewsApp", false)
    UIManager.set_app_visibility("DialogApp", false)

    task.wait(3)

    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("DailyLoginAPI/ClaimDailyReward"):InvokeServer()
        UIManager.set_app_visibility("DailyLoginApp", false)
    end)

    print("✅ Entered the game!")
end

enter_the_game()

repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
print("✅ Character loaded!")

-- ============================================
-- UNSUBSCRIBE FROM HOUSE
-- ============================================
print("⏳ Waiting 15s before unsubscribing from house...")
task.wait(15)
pcall(function()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/UnsubscribeFromHouse"):InvokeServer(LocalPlayer, true)
end)
task.wait(5)

-- ============================================
-- HEADER
-- ============================================
print("===========================================")
print("  SMART AGING SYSTEM V2")
print("  + Multi-pet support with fallback")
print("  + Pet resolved by name")
print("  + FarmSync auto-disable")
print("  + AccountOps auto-disable")
print("  + Kicks game when done")
print("===========================================")
print("Pet Name:     " .. CONFIG.PET_NAME)
print("Pet Kind:     " .. CONFIG.PET_KIND)
print("Rarity:       " .. CONFIG.RARITY)
print("Potions/pet:  " .. potions_per_pet)
print("FarmSync:     " .. (CONFIG.FARMSYNC_AUTO_DISABLE and "Auto-disable ON" or "OFF"))
print("AccountOps:   " .. (CONFIG.ACCOUNTOPS_AUTO_DISABLE and "Auto-disable ON" or "OFF"))
print("===========================================")
print("✅ Ready to start!")

-- ============================================
-- DATA + WEBHOOK
-- ============================================
local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

local function sendWebhook(message, is_debug)
    if not CONFIG.WEBHOOK_URL or CONFIG.WEBHOOK_URL == "" then return end
    if not request then return end
    if is_debug and not CONFIG.DEBUG_LOGGING then return end
    
    pcall(function()
        request({
            Url = CONFIG.WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({["content"] = message})
        })
    end)
end

local function logDebug(message)
    print(message)
    sendWebhook(string.format("🔍 %s - %s", playerName, message), true)
end

local function logEvent(message)
    print(message)
    sendWebhook(string.format("📋 %s - %s", playerName, message), false)
end

local function logError(message)
    warn(message)
    sendWebhook(string.format("❌ %s - %s", playerName, message), false)
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

-- ============== COUNT SPECIFIC PETS ==============
local function count_specific_pets()
    local count = 0
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for _, pet in pairs(playerData.inventory.pets) do
                if pet.kind == CONFIG.PET_KIND then
                    count = count + 1
                end
            end
        end
    end)
    return count
end

-- ============== COUNT AGE POTIONS ==============
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

-- ============== GET POTION UNIQUES ==============
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

-- ============== ANALYZE PET INVENTORY ==============
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
                local is_mega = pet.properties and pet.properties.mega_neon or false
                local age = pet.properties and pet.properties.age or 0

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

-- ============== GET FULL GROWN NORMALS ==============
local function get_full_grown_normals()
    local pets = {}
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for _, pet in pairs(playerData.inventory.pets) do
                if pet.kind == CONFIG.PET_KIND then
                    local is_neon = pet.properties and pet.properties.neon
                    local is_mega = pet.properties and pet.properties.mega_neon
                    local age = pet.properties and pet.properties.age or 0
                    if not is_neon and not is_mega and age == 6 then
                        table.insert(pets, pet.unique)
                    end
                end
            end
        end
    end)
    return pets
end

-- ============== GET FULL GROWN NEONS ==============
local function get_full_grown_neons()
    local neons = {}
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for _, pet in pairs(playerData.inventory.pets) do
                if pet.kind == CONFIG.PET_KIND then
                    local is_neon = pet.properties and pet.properties.neon
                    local is_mega = pet.properties and pet.properties.mega_neon
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

-- ============================================
-- EQUIP PET
-- ============================================
local function equip_pet(pet_unique)
    logDebug(string.format("🔧 Equipping pet: %s", pet_unique))

    local success = false
    for attempt = 1, 3 do
        success = pcall(function()
            ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(pet_unique, {
                use_sound_delay = true,
                equip_as_last = false
            })
        end)

        if success then
            logEvent(string.format("✅ Equip call sent on attempt %d", attempt))
            task.wait(2)
            return true
        else
            logError(string.format("⚠️ Equip call failed on attempt %d, retrying...", attempt))
            task.wait(1)
        end
    end

    logError("❌ Equip call failed after 3 attempts! Proceeding anyway...")
    return false
end

-- ============== FEED POTIONS ==============
local function feed_potions_fast(pet_unique, working_potion_unique, sub_potions_array)
    logDebug(string.format("Starting feed process - Pet: %s, Main potion: %s, Sub potions: %d", 
        pet_unique, working_potion_unique, #sub_potions_array))
    
    local function equip_potion(potion_unique)
        logDebug("Equipping potion: " .. potion_unique)
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(tostring(potion_unique), {
            use_sound_delay = false,
            equip_as_last = false
        })
        task.wait(1)
        logDebug("Potion equipped")
    end

    local function create_objects(p_unique, pot_unique, sub_potions)
        logDebug("Creating pet object for feeding")
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject"):InvokeServer(
            "__Enum_PetObjectCreatorType_2",
            {
                additional_consume_uniques = sub_potions,
                pet_unique = p_unique,
                unique_id = pot_unique
            }
        )
        logDebug("Pet object created")
    end

    local function fast_consume(p_unique)
        logDebug("Starting fast consume")
        local timeout = 0
        local potion_object = nil
        
        while not potion_object and timeout < 10 do
            local petObjects = workspace:FindFirstChild("PetObjects")
            if petObjects then
                potion_object = petObjects:FindFirstChild("AgePotion")
            end
            
            if not potion_object then
                task.wait(0.5)
                timeout = timeout + 0.5
                if timeout % 2 == 0 then
                    logDebug(string.format("Waiting for AgePotion object... (%ds)", timeout))
                end
            end
        end
        
        if potion_object then
            logDebug("AgePotion object found, consuming...")
            ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/ConsumeFoodObject"):FireServer(potion_object, p_unique)
            logDebug("Consume sent")
            return true
        else
            logError("AgePotion object not found after 10s timeout!")
            return false
        end
    end

    print("   ❤️ Equip Potion")
    equip_potion(working_potion_unique)

    print("   ⚙️ Feed")
    create_objects(pet_unique, working_potion_unique, sub_potions_array)
    task.wait(2)

    print("   🚀 Fast Consume")
    local consume_success = fast_consume(pet_unique)
    if not consume_success then
        logError("Fast consume failed, trying again...")
        task.wait(1)
        consume_success = fast_consume(pet_unique)
        if consume_success then
            logEvent("Fast consume succeeded on retry")
        else
            logError("Fast consume failed on both attempts!")
        end
    else
        logDebug("Fast consume successful")
    end
    task.wait(2)
    
    logDebug("Feed process complete")
end

-- ============== AGE UP WITH VERIFICATION ==============
local function age_up_pet_verified(pet_unique, potion_uniques, expected_final_age)
    logEvent(string.format("Starting age verification - Pet: %s, Potions: %d, Target age: %d", 
        pet_unique, #potion_uniques, expected_final_age))
    
    local initial_age = get_pet_age(pet_unique)

    if not initial_age then
        logError("Cannot get pet age!")
        return false
    end

    print(string.format("   📊 Age: %d → %d", initial_age, expected_final_age))

    for attempt = 1, MAX_AGE_RETRIES do
        if attempt > 1 then
            print(string.format("   🔄 Retry %d/%d", attempt, MAX_AGE_RETRIES))
            logEvent(string.format("Retry attempt %d/%d", attempt, MAX_AGE_RETRIES))
        end

        print("   🔧 Equipping pet...")
        equip_pet(pet_unique)
        print("   ✅ Equip sent — proceeding to feed potions")
        task.wait(1)

        local main_potion = potion_uniques[1]
        local sub_potions = {}
        for i = 2, #potion_uniques do
            table.insert(sub_potions, potion_uniques[i])
        end

        print(string.format("   🍼 Feeding %d potions", #potion_uniques))
        feed_potions_fast(pet_unique, main_potion, sub_potions)

        print("   ⏳ Verifying age...")
        task.wait(AGE_VERIFY_WAIT)

        local current_age = get_pet_age(pet_unique)

        if not current_age then
            print("   ⚠️ Can't verify age, assuming success")
            logEvent("Cannot verify age, assuming success")
            return true
        end

        if current_age >= expected_final_age then
            print(string.format("   ✅ SUCCESS! %d → %d", initial_age, current_age))
            logEvent(string.format("Age up SUCCESS! %d → %d", initial_age, current_age))
            return true
        else
            print(string.format("   ⚠️ Still age %d (expected %d)", current_age, expected_final_age))
            logEvent(string.format("Age up incomplete - Still age %d (expected %d)", current_age, expected_final_age))
            if attempt < MAX_AGE_RETRIES then
                task.wait(2)
            end
        end
    end

    print("   ❌ FAILED after retries")
    logError(string.format("Age up FAILED after %d retries", MAX_AGE_RETRIES))
    return false
end

-- ============== CREATE NEON / MEGA ==============
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

-- ============================================
-- MAIN AGING LOOP
-- ============================================
local function run_aging()
    print("\n🔍 Checking inventory...")

    local total_pets = count_specific_pets()
    if total_pets == 0 then
        print("\n❌ NO PETS OF TYPE: " .. CONFIG.PET_KIND)
        sendWebhook(string.format("❌ %s - No %s pets found, kicking.", playerName, CONFIG.PET_KIND))
        disable_all_accounts()
        task.wait(3)
        LocalPlayer:Kick("No pets found — done!")
        return
    end
    print(string.format("✅ Found %d pets of kind: %s", total_pets, CONFIG.PET_KIND))

    local total_potions = count_age_potions()
    if total_potions == 0 then
        print("\n❌ NO AGE POTIONS")
        sendWebhook(string.format("❌ %s - No potions, kicking.", playerName))
        disable_all_accounts()
        task.wait(3)
        LocalPlayer:Kick("No potions — done!")
        return
    end
    print(string.format("✅ Found %d age potions", total_potions))

    local total_aged   = 0
    local total_failed = 0
    local total_neons  = 0
    local total_megas  = 0

    sendWebhook(string.format("🔄 %s - Starting: %d %s pets, %d potions",
        playerName, total_pets, CONFIG.PET_KIND, total_potions))

    local cycle = 0
    local last_cycle_time = os.time()
    local max_cycle_time = 180

    -- Watchdog
    spawn(function()
        while true do
            task.wait(30)
            local time_in_cycle = os.time() - last_cycle_time
            if time_in_cycle > max_cycle_time then
                local msg = string.format("WATCHDOG ALERT: Cycle taking too long (%ds / %ds max)", time_in_cycle, max_cycle_time)
                print("\n⚠️ " .. msg)
                logError(msg)
                logEvent("Attempting recovery - unequipping all")
                pcall(function()
                    ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/UnequipAll"):FireServer()
                end)
                task.wait(2)
                last_cycle_time = os.time()
                logEvent("Recovery attempted, timer reset")
            end
        end
    end)

    while true do
        cycle = cycle + 1
        last_cycle_time = os.time()
        print(string.format("\n========== CYCLE %d ==========", cycle))
        logEvent(string.format("Starting Cycle %d", cycle))

        local analysis = analyze_pet_inventory()
        local potions  = count_age_potions()

        print(string.format("📊 %s:", CONFIG.PET_KIND))
        print(string.format("   Potions:            %d", potions))
        print(string.format("   Normal (not fg):    %d", #analysis.normal_pets))
        print(string.format("   Normal (fg / age6): %d", analysis.full_grown_normal))
        print(string.format("   Neon   (not fg):    %d", #analysis.neon_pets))
        print(string.format("   Neon   (fg / age6): %d", analysis.full_grown_neons))

        local did_something = false
        local aged_this_cycle = false

        if #analysis.normal_pets > 0 and potions >= potions_per_pet then
            print("\n🐾 AGING: normal pet...")
            logEvent(string.format("AGING normal pet (age %d)", analysis.normal_pets[1].age))
            local pet = analysis.normal_pets[1]
            local potion_batch = get_age_potion_uniques(potions_per_pet)

            if #potion_batch >= potions_per_pet then
                print(string.format("   age %d → 6", pet.age))
                local success = age_up_pet_verified(pet.unique, potion_batch, 6)
                if success then
                    total_aged = total_aged + 1
                    logEvent("Normal pet aged successfully")
                else
                    total_failed = total_failed + 1
                    logError("Normal pet aging FAILED")
                end
                aged_this_cycle = true
                did_something   = true
            end

        elseif #analysis.neon_pets > 0 and potions >= potions_per_pet then
            print("\n💎 AGING: neon pet...")
            logEvent(string.format("AGING neon pet (age %d)", analysis.neon_pets[1].age))
            local pet = analysis.neon_pets[1]
            local potion_batch = get_age_potion_uniques(potions_per_pet)

            if #potion_batch >= potions_per_pet then
                print(string.format("   age %d → 6", pet.age))
                local success = age_up_pet_verified(pet.unique, potion_batch, 6)
                if success then
                    total_aged = total_aged + 1
                    logEvent("Neon pet aged successfully")
                else
                    total_failed = total_failed + 1
                    logError("Neon pet aging FAILED")
                end
                aged_this_cycle = true
                did_something   = true
            end

        elseif potions > 0 and potions < potions_per_pet then
            analysis = analyze_pet_inventory()

            local target = nil
            local label  = ""

            if #analysis.normal_pets > 0 then
                target = analysis.normal_pets[1]
                label  = "normal"
            elseif #analysis.neon_pets > 0 then
                target = analysis.neon_pets[1]
                label  = "neon"
            end

            if target and target.age < 6 then
                local potion_batch = get_age_potion_uniques(potions)
                if #potion_batch > 0 then
                    print(string.format("\n🔄 LEFTOVER: %d potions on %s (age %d)", #potion_batch, label, target.age))
                    local success = age_up_pet_verified(target.unique, potion_batch, target.age + #potion_batch)
                    if success then total_aged = total_aged + 1
                    else            total_failed = total_failed + 1 end
                    aged_this_cycle = true
                    did_something   = true
                end
            end
        end

        if aged_this_cycle then
            print(string.format("⏳ Waiting %ds before next pet...", CONFIG.PET_DELAY))
            task.wait(CONFIG.PET_DELAY)
        end

        analysis = analyze_pet_inventory()

        if analysis.full_grown_normal >= 4 then
            print("\n🌟 FUSE: 4 full-grown normals → neon")
            local full_grown = get_full_grown_normals()
            if #full_grown >= 4 then
                if create_neon(full_grown) then
                    print("   ✅ Neon created!")
                    total_neons = total_neons + 1
                    did_something = true
                    task.wait(2)
                end
            end
        end

        analysis = analyze_pet_inventory()

        if analysis.full_grown_neons >= 4 then
            print("\n🔥 FUSE: 4 full-grown neons → mega")
            local full_grown_neons = get_full_grown_neons()
            if #full_grown_neons >= 4 then
                if create_neon(full_grown_neons) then
                    print("   ✅ Mega created!")
                    total_megas = total_megas + 1
                    did_something = true
                    task.wait(2)
                end
            end
        end

        if not did_something then
            local final_potions  = count_age_potions()
            local final_analysis = analyze_pet_inventory()

            local all_age_6 = (#final_analysis.normal_pets == 0)
                and (#final_analysis.neon_pets == 0)
                and (final_analysis.full_grown_normal + final_analysis.full_grown_neons > 0)

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

    local final_potions = count_age_potions()

    print("\n" .. ("="):rep(50))
    print("✅ COMPLETE!")
    print(("="):rep(50))
    print(string.format("   Aged:              %d", total_aged))
    print(string.format("   Failed:            %d", total_failed))
    print(string.format("   Neons made:        %d", total_neons))
    print(string.format("   Megas made:        %d", total_megas))
    print(string.format("   Remaining potions: %d", final_potions))
    print(("="):rep(50))

    sendWebhook(string.format("✅ %s - COMPLETE\nAged: %d | Failed: %d | Neons: %d | Megas: %d\nRemaining potions: %d",
        playerName, total_aged, total_failed, total_neons, total_megas, final_potions))

    disable_all_accounts()

    print("\n🔴 Aging done — kicking in 5s...")
    task.wait(5)
    LocalPlayer:Kick("Aging complete!")
end

-- ============================================
-- RUN
-- ============================================
run_aging()
