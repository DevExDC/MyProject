-- ============================================
-- ADOPT ME PET AGING SCRIPT
-- Auto-ages pets, makes neons, and makes megas
-- Uses ALL available potions automatically
-- ============================================

-- Check if already running
if getgenv().AgingScript then
    warn("⚠️ Aging script already running!")
    return
end

getgenv().AgingScript = {
    Running = true,
    Version = "2.0"
}

-- ============================================
-- CONFIGURATION VIA GETGENV
-- ============================================
if not getgenv().AgingConfig then
    getgenv().AgingConfig = {
        PET_KIND = "moon_2025_snorgle",
        RARITY = "uncommon",
        WEBHOOK_URL = ""
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
repeat task.wait(1) until game:IsLoaded() and game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules") and game:GetService("ReplicatedStorage").ClientModules:FindFirstChild("Core") and game:GetService("ReplicatedStorage").ClientModules.Core:FindFirstChild("UIManager") and game:GetService("ReplicatedStorage").ClientModules.Core:FindFirstChild("UIManager").Apps:FindFirstChild("TransitionsApp") and game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("TransitionsApp") and game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("TransitionsApp"):FindFirstChild("Whiteout")
repeat task.wait(1) until game.Players and game.Players.LocalPlayer and game:GetService("Players").LocalPlayer.PlayerGui and game:GetService("Players").LocalPlayer.PlayerGui.AssetLoadUI and (game:GetService("Players").LocalPlayer.PlayerGui.AssetLoadUI.Enabled == false)

task.wait(1.5)

print("✅ Game loaded!")

-- Load Progress UI
local UILoaded = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/DevExDC/MyProject/refs/heads/main/progress_ui_universal.lua"))()
end)

if UILoaded then
    print("✅ Progress UI loaded")
    task.wait(1)
    
    -- Set UI for Aging mode
    if getgenv().ProgressUI then
        getgenv().ProgressUI.SetTitle("🐾 Auto Aging Progress")
        getgenv().ProgressUI.SetStatus("⏳ Initializing game...")
    end
else
    warn("⚠️ Progress UI failed to load, continuing without UI")
end

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

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

-- Choose Parents team
local function enter_the_game()
    local args = {
        [1] = "Parents",
        [2] = {
            ["source_for_logging"] = "intro_sequence",
        },
    }
    
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/ChooseTeam"):InvokeServer(unpack(args))
    task.wait(1)
    
    -- Hide UI elements
    UIManager.set_app_visibility("MainMenuApp", false)
    UIManager.set_app_visibility("NewsApp", false)
    UIManager.set_app_visibility("DialogApp", false)
    UIManager.set_app_visibility("MinigameRewardsApp", false)
    
    task.wait(3)
    
    -- Claim daily reward
    ReplicatedStorage:WaitForChild("API"):WaitForChild("DailyLoginAPI/ClaimDailyReward"):InvokeServer()
    UIManager.set_app_visibility("DailyLoginApp", false)
end

pcall(enter_the_game)

print("✅ Entered the game!")

-- Update UI
if getgenv().ProgressUI then
    getgenv().ProgressUI.SetStatus("⏳ Waiting 30 seconds...")
end

-- ============================================
-- 30 SECOND DELAY BEFORE STARTING
-- ============================================
print("\n⏳ Waiting 30 seconds before starting aging process...")
task.wait(30)
print("✅ Starting aging process now!")

-- ============================================
-- REST OF THE SCRIPT
-- ============================================

-- Rarity potion mapping
local RARITY_POTIONS = {
    ["common"] = 1,
    ["uncommon"] = 2,
    ["rare"] = 2,
    ["ultra-rare"] = 4,
    ["legendary"] = 7
}

-- ============================================
-- SMART WEBHOOK LOGGING SYSTEM (Anti-Spam)
-- ============================================

local WebhookManager = {
    queue = {},
    last_send = 0,
    send_delay = 5, -- Batch messages every 5 seconds
    max_batch = 10, -- Max 10 messages per batch
}

-- Add message to queue
function WebhookManager:add(title, message, isError)
    table.insert(self.queue, {
        title = title,
        message = message,
        isError = isError,
        timestamp = os.time()
    })
end

-- Send batched messages
function WebhookManager:send_batch()
    if #self.queue == 0 then return end
    if CONFIG.WEBHOOK_URL == "" then 
        self.queue = {}
        return 
    end
    
    -- Group messages by type
    local batched = {
        success = {},
        error = {},
        info = {}
    }
    
    for _, msg in ipairs(self.queue) do
        if msg.isError then
            table.insert(batched.error, msg)
        elseif msg.title:find("✅") then
            table.insert(batched.success, msg)
        else
            table.insert(batched.info, msg)
        end
    end
    
    -- Build combined message
    local combined_description = ""
    
    -- Add success messages
    if #batched.success > 0 then
        combined_description = combined_description .. "**✅ SUCCESS (" .. #batched.success .. ")**\n"
        for i, msg in ipairs(batched.success) do
            if i <= 3 then -- Show max 3 detailed
                combined_description = combined_description .. "• " .. msg.title .. "\n"
            end
        end
        if #batched.success > 3 then
            combined_description = combined_description .. "• ... and " .. (#batched.success - 3) .. " more\n"
        end
        combined_description = combined_description .. "\n"
    end
    
    -- Add info messages
    if #batched.info > 0 then
        combined_description = combined_description .. "**ℹ️ INFO (" .. #batched.info .. ")**\n"
        for i, msg in ipairs(batched.info) do
            if i <= 2 then
                combined_description = combined_description .. "• " .. msg.title .. "\n"
            end
        end
        if #batched.info > 2 then
            combined_description = combined_description .. "• ... and " .. (#batched.info - 2) .. " more\n"
        end
        combined_description = combined_description .. "\n"
    end
    
    -- Add error messages (always show all)
    if #batched.error > 0 then
        combined_description = combined_description .. "**❌ ERRORS (" .. #batched.error .. ")**\n"
        for _, msg in ipairs(batched.error) do
            combined_description = combined_description .. "• " .. msg.title .. ": " .. msg.message .. "\n"
        end
    end
    
    -- Send combined webhook
    local data = {
        ["embeds"] = {{
            ["title"] = "🤖 Batch Update - " .. LocalPlayer.Name,
            ["description"] = combined_description,
            ["color"] = #batched.error > 0 and 16711680 or 65280,
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S"),
            ["footer"] = {
                ["text"] = "Account: " .. LocalPlayer.Name .. " | Total Messages: " .. #self.queue
            }
        }}
    }
    
    pcall(function()
        request({
            Url = CONFIG.WEBHOOK_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(data)
        })
    end)
    
    -- Clear queue
    self.queue = {}
    self.last_send = os.time()
end

-- Auto-send loop
task.spawn(function()
    while task.wait(WebhookManager.send_delay) do
        if #WebhookManager.queue > 0 then
            WebhookManager:send_batch()
        end
    end
end)

-- Send critical messages immediately
function WebhookManager:send_now(title, message, isError)
    if CONFIG.WEBHOOK_URL == "" then return end
    
    local data = {
        ["embeds"] = {{
            ["title"] = "🚨 " .. title .. " - " .. LocalPlayer.Name,
            ["description"] = "```lua\n" .. message .. "\n```",
            ["color"] = isError and 16711680 or 65280,
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S"),
            ["footer"] = {
                ["text"] = "Account: " .. LocalPlayer.Name
            }
        }}
    }
    
    pcall(function()
        request({
            Url = CONFIG.WEBHOOK_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- Function to send to Discord (now uses batching)
local function sendToWebhook(title, message, isError, immediate)
    if immediate then
        -- Send critical messages immediately (start, complete, critical errors)
        WebhookManager:send_now(title, message, isError)
    else
        -- Add to batch queue
        WebhookManager:add(title, message, isError)
    end
end

-- ============================================
-- UTILITY FUNCTIONS
-- ============================================

-- Get player data
local function get_player_data()
    local success, result = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[tostring(LocalPlayer)]
    end)
    
    if not success then
        sendToWebhook("❌ Get Player Data Error", tostring(result), true)
        return nil
    end
    
    return result
end

-- Get ALL normal pets (not neon, not full grown)
local function get_all_normal_pets(pet_kind)
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then error("No player data") end
        
        local normal_pets = {}
        for _, pet in pairs(data.inventory.pets) do
            local age = pet.properties and pet.properties.age or 0
            local is_neon = pet.properties and pet.properties.neon
            local is_full_grown = age >= 6
            
            -- Only normal (non-neon) pets that are not full grown
            if pet.kind == pet_kind and not pet.is_egg and not is_neon and not is_full_grown then
                table.insert(normal_pets, pet.unique)
                print("Found normal pet: " .. pet.kind .. " (Age: " .. age .. ", Unique: " .. pet.unique .. ")")
            end
        end
        
        print("Total normal (non-neon, not full-grown) pets found: " .. #normal_pets)
        return normal_pets
    end)
    
    if not success then
        sendToWebhook("❌ Get Normal Pets Error", tostring(result), true)
        return {}
    end
    
    return result
end

-- Get ALL neon pets (not full grown)
local function get_all_neon_pets(pet_kind)
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then error("No player data") end
        
        local neon_pets = {}
        for _, pet in pairs(data.inventory.pets) do
            local age = pet.properties and pet.properties.age or 0
            local is_neon = pet.properties and pet.properties.neon
            local is_full_grown = age >= 6
            
            -- Only neon pets that are not full grown
            if pet.kind == pet_kind and is_neon and not is_full_grown then
                table.insert(neon_pets, pet.unique)
                print("Found neon pet: " .. pet.kind .. " (Age: " .. age .. ", Unique: " .. pet.unique .. ")")
            end
        end
        
        print("Total neon (not full-grown) pets found: " .. #neon_pets)
        return neon_pets
    end)
    
    if not success then
        sendToWebhook("❌ Get Neon Pets Error", tostring(result), true)
        return {}
    end
    
    return result
end

-- Get full grown normal pets (for neon making)
local function get_full_grown_normal_pets(pet_kind)
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then error("No player data") end
        
        local full_grown_pets = {}
        for _, pet in pairs(data.inventory.pets) do
            local age = pet.properties and pet.properties.age or 0
            local is_neon = pet.properties and pet.properties.neon
            
            -- Only normal (non-neon) full grown pets (age 6)
            if pet.kind == pet_kind and not is_neon and age >= 6 then
                table.insert(full_grown_pets, pet.unique)
                print("Found full grown normal pet: " .. pet.kind .. " (Unique: " .. pet.unique .. ")")
            end
        end
        
        print("Total full grown normal pets: " .. #full_grown_pets)
        return full_grown_pets
    end)
    
    if not success then
        sendToWebhook("❌ Get Full Grown Pets Error", tostring(result), true)
        return {}
    end
    
    return result
end

-- Get luminous neon pets (for mega making)
local function get_luminous_neon_pets(pet_kind)
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then error("No player data") end
        
        local luminous_neons = {}
        for _, pet in pairs(data.inventory.pets) do
            local age = pet.properties and pet.properties.age or 0
            local is_neon = pet.properties and pet.properties.neon
            local is_mega = pet.properties and pet.properties.mega
            
            -- Only luminous neons (age 6, neon but not mega)
            if pet.kind == pet_kind and is_neon and not is_mega and age >= 6 then
                table.insert(luminous_neons, pet.unique)
                print("Found luminous neon pet: " .. pet.kind .. " (Unique: " .. pet.unique .. ")")
            end
        end
        
        print("Total luminous neon pets: " .. #luminous_neons)
        return luminous_neons
    end)
    
    if not success then
        sendToWebhook("❌ Get Luminous Neons Error", tostring(result), true)
        return {}
    end
    
    return result
end

-- Find age potions
local function find_age_potions(count)
    local success, result = pcall(function()
        local data = get_player_data()
        if not data then error("No player data") end
        
        local potions = {}
        
        for _, item in pairs(data.inventory.food) do
            if item.kind == "pet_age_potion" then
                table.insert(potions, item.unique)
                
                if #potions >= count then
                    break
                end
            end
        end
        
        return potions
    end)
    
    if not success then
        sendToWebhook("❌ Find Age Potions Error", tostring(result), true)
        return {}
    end
    
    return result
end

-- Get ALL age potions
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
    
    if not success then
        sendToWebhook("❌ Get Potions Error", tostring(result), true)
        return {}
    end
    
    return result
end

-- Equip pet
local function equip_pet(pet_unique)
    local success, result = pcall(function()
        local args = {
            pet_unique,
            {
                use_sound_delay = true,
                equip_as_last = false
            }
        }
        
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(unpack(args))
        return true
    end)
    
    if not success then
        sendToWebhook("❌ Equip Pet Error", "Pet: " .. tostring(pet_unique) .. "\nError: " .. tostring(result), true)
        return false
    end
    
    return true
end

-- Feed pet with ALL potions at once
local function feed_pet_all_potions(pet_unique, potion_count, potions)
    local success, result = pcall(function()
        if #potions < potion_count then
            error("Not enough potions! Need: " .. potion_count .. ", Have: " .. #potions)
        end
        
        -- Take first potion
        local first_potion = table.remove(potions, 1)
        
        -- Take remaining potions for additional_consume_uniques
        local additional = {}
        local remaining_count = potion_count - 1
        
        local add_index = 1
        while add_index <= remaining_count do
            table.insert(additional, table.remove(potions, 1))
            add_index = add_index + 1
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
        return true
    end)
    
    if not success then
        local errorMsg = "❌ FEED PET ERROR - COPY THIS!\n\n"
        errorMsg = errorMsg .. "Error: " .. tostring(result) .. "\n"
        errorMsg = errorMsg .. "Pet Unique: " .. tostring(pet_unique) .. "\n"
        errorMsg = errorMsg .. "Potion Count: " .. tostring(potion_count)
        
        sendToWebhook("❌ Feed Pet Failed", errorMsg, true)
        return false
    end
    
    return true
end

-- Complete aging process for one pet (Feed all at once)
local function age_pet_fully(pet_unique, potion_count, potions)
    print("🔧 Aging pet: " .. pet_unique .. " with " .. potion_count .. " potions")
    
    -- Equip the pet first
    if not equip_pet(pet_unique) then
        return false
    end
    
    task.wait(0.5)
    
    -- Feed ALL potions at once
    if not feed_pet_all_potions(pet_unique, potion_count, potions) then
        return false
    end
    
    print("✅ Fed " .. potion_count .. " potions, waiting for drinking animation...")
    task.wait(9) -- Wait 9 seconds for drinking animation
    
    return true
end

-- Make neon from 4 pets
local function make_neon(four_pet_uniques)
    local success, result = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/DoNeonFusion"):InvokeServer(four_pet_uniques)
        return true
    end)
    
    if not success then
        local errorMsg = "❌ NEON FUSION ERROR - COPY THIS!\n\n"
        errorMsg = errorMsg .. "Error: " .. tostring(result)
        
        sendToWebhook("❌ Neon Fusion Failed", errorMsg, true)
        return false
    end
    
    return true
end

-- Make mega from 4 luminous neons (uses same remote as neon)
local function make_mega(four_luminous_neons)
    local success, result = pcall(function()
        -- Same remote as neon making, but with 4 luminous neons
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/DoNeonFusion"):InvokeServer(four_luminous_neons)
        return true
    end)
    
    if not success then
        local errorMsg = "❌ MEGA FUSION ERROR - COPY THIS!\n\n"
        errorMsg = errorMsg .. "Error: " .. tostring(result)
        
        sendToWebhook("❌ Mega Fusion Failed", errorMsg, true)
        return false
    end
    
    return true
end

-- Main aging process with smart logic
local function start_aging_process()
    print("\n========================================")
    print("🚀 STARTING SMART PET AGING PROCESS")
    print("========================================")
    print("Pet Kind: " .. CONFIG.PET_KIND)
    print("Rarity: " .. CONFIG.RARITY:upper())
    print("Strategy: Use ALL potions available")
    print("========================================\n")
    
    local rarity_lower = string.lower(CONFIG.RARITY)
    local potionCost = RARITY_POTIONS[rarity_lower]
    
    if not potionCost then
        local errorMsg = "Unknown rarity: " .. CONFIG.RARITY .. "\nValid: common, uncommon, rare, ultra-rare, legendary"
        sendToWebhook("❌ Invalid Rarity", errorMsg, true)
        error(errorMsg)
    end
    
    sendToWebhook("🚀 Starting Smart Aging", 
        "Pet: " .. CONFIG.PET_KIND .. "\n" ..
        "Rarity: " .. CONFIG.RARITY .. "\n" ..
        "Potions per Pet: " .. potionCost .. "\n" ..
        "Strategy: Use all available potions", false, true) -- IMMEDIATE
    
    local total_potions = get_age_potions()
    local original_potion_count = #total_potions
    
    print("\n📊 Initial Status:")
    print("Total age potions available: " .. #total_potions)
    
    if #total_potions == 0 then
        local errorMsg = "No age potions found!"
        sendToWebhook("❌ Error", errorMsg, true)
        error(errorMsg)
    end
    
    -- ============================================
    -- PHASE 1: AGE NORMAL PETS & MAKE NEONS
    -- ============================================
    print("\n🔧 PHASE 1: AGING NORMAL PETS")
    print("========================================")
    
    -- Update UI
    if getgenv().ProgressUI then
        getgenv().ProgressUI.SetStatus("🔧 Phase 1: Aging normal pets...")
        getgenv().ProgressUI.UpdateStats("🧪 Potions: " .. #total_potions, "📊 Phase: 1/3")
    end
    
    local normal_pets = get_all_normal_pets(CONFIG.PET_KIND)
    
    if #normal_pets == 0 then
        print("⚠️ No normal pets found to age")
    else
        print("Found " .. #normal_pets .. " normal pets to age")
        
        -- Age normal pets until we run out of potions or pets
        local aged_count = 0
        
        for i, pet_unique in ipairs(normal_pets) do
            if #total_potions < potionCost then
                print("\n⚠️ Not enough potions left for next pet (need " .. potionCost .. ", have " .. #total_potions .. ")")
                break
            end
            
            print("\n[" .. i .. "/" .. #normal_pets .. "] Aging normal pet...")
            
            -- Update UI per pet
            if getgenv().ProgressUI then
                getgenv().ProgressUI.UpdateProgress(i, #normal_pets, aged_count)
                getgenv().ProgressUI.UpdateStats("🧪 Potions: " .. #total_potions, "🐾 Aged: " .. aged_count)
            end
            
            if age_pet_fully(pet_unique, potionCost, total_potions) then
                aged_count = aged_count + 1
                print("✅ Normal pet " .. i .. " aged successfully")
                sendToWebhook("✅ Normal Pet Aged", "Pet " .. i .. " aged | Potions left: " .. #total_potions, false)
            else
                warn("❌ Failed to age normal pet " .. i)
            end
            
            task.wait(1)
        end
        
        print("\n✅ Aged " .. aged_count .. " normal pets")
        sendToWebhook("✅ Normal Pets Phase Complete", "Aged: " .. aged_count .. " normal pets\nPotions remaining: " .. #total_potions, false)
    end
    
    -- Wait for pets to become full grown
    print("\n⏳ Waiting 10 seconds for pets to reach full grown...")
    task.wait(10)
    
    -- Make neons from full grown normal pets
    print("\n🌟 MAKING NEONS FROM FULL GROWN NORMAL PETS")
    print("========================================")
    
    -- Update UI
    if getgenv().ProgressUI then
        getgenv().ProgressUI.SetStatus("🌟 Making neons...")
    end
    
    local full_grown_normal = get_full_grown_normal_pets(CONFIG.PET_KIND)
    local neons_made = 0
    
    if #full_grown_normal < 4 then
        print("⚠️ Not enough full grown normal pets to make neon (have " .. #full_grown_normal .. ", need 4)")
        if #full_grown_normal > 0 then
            print("⚠️ " .. #full_grown_normal .. " full grown normal pet(s) will remain (cannot make neon)")
        end
    else
        local neonCount = math.floor(#full_grown_normal / 4)
        print("Can make " .. neonCount .. " neon(s) from " .. #full_grown_normal .. " full grown normal pets")
        
        for i = 1, neonCount do
            local start_idx = (i - 1) * 4 + 1
            local fourPets = {
                full_grown_normal[start_idx],
                full_grown_normal[start_idx + 1],
                full_grown_normal[start_idx + 2],
                full_grown_normal[start_idx + 3]
            }
            
            print("\n[" .. i .. "/" .. neonCount .. "] Making neon from 4 full grown normal pets...")
            
            if make_neon(fourPets) then
                neons_made = neons_made + 1
                print("✅ Neon " .. i .. " created!")
                sendToWebhook("✅ Neon Created", "Neon " .. i .. "/" .. neonCount .. " created from normal pets", false)
                task.wait(3)
            else
                warn("❌ Failed to make neon " .. i)
            end
        end
        
        -- Check for leftover full grown normal pets
        local leftover = #full_grown_normal % 4
        if leftover > 0 then
            print("\n⚠️ " .. leftover .. " full grown normal pet(s) left over (cannot make neon)")
        end
    end
    
    print("\n✅ Neon making complete! Made " .. neons_made .. " neons")
    sendToWebhook("✅ Neon Making Complete", "Neons made: " .. neons_made .. "\nPotions remaining: " .. #total_potions, false)
    
    -- ============================================
    -- PHASE 2: AGE NEON PETS (if potions remain)
    -- ============================================
    if #total_potions >= potionCost then
        print("\n🌟 PHASE 2: AGING NEON PETS")
        print("========================================")
        print("Potions remaining: " .. #total_potions)
        
        -- Update UI
        if getgenv().ProgressUI then
            getgenv().ProgressUI.SetStatus("🌟 Phase 2: Aging neon pets...")
            getgenv().ProgressUI.UpdateStats("🌟 Neons: " .. neons_made, "📊 Phase: 2/3")
        end
        
        task.wait(2)
        
        local neon_pets = get_all_neon_pets(CONFIG.PET_KIND)
        
        if #neon_pets == 0 then
            print("⚠️ No neon pets found to age")
        else
            print("Found " .. #neon_pets .. " neon pets to age")
            
            local neon_aged_count = 0
            
            for i, neon_unique in ipairs(neon_pets) do
                if #total_potions < potionCost then
                    print("\n⚠️ Not enough potions left for next neon (need " .. potionCost .. ", have " .. #total_potions .. ")")
                    break
                end
                
                print("\n[" .. i .. "/" .. #neon_pets .. "] Aging neon pet...")
                
                -- Update UI
                if getgenv().ProgressUI then
                    getgenv().ProgressUI.UpdateProgress(i, #neon_pets, neon_aged_count)
                    getgenv().ProgressUI.UpdateStats("🧪 Potions: " .. #total_potions, "🌟 Neons Aged: " .. neon_aged_count)
                end
                
                if age_pet_fully(neon_unique, potionCost, total_potions) then
                    neon_aged_count = neon_aged_count + 1
                    print("✅ Neon pet " .. i .. " aged successfully")
                    sendToWebhook("✅ Neon Pet Aged", "Neon " .. i .. " aged | Potions left: " .. #total_potions, false)
                else
                    warn("❌ Failed to age neon pet " .. i)
                end
                
                task.wait(1)
            end
            
            print("\n✅ Aged " .. neon_aged_count .. " neon pets")
            sendToWebhook("✅ Neon Pets Phase Complete", "Aged: " .. neon_aged_count .. " neon pets\nPotions remaining: " .. #total_potions, false)
        end
    else
        print("\n⚠️ No potions left to age neon pets")
    end
    
    -- ============================================
    -- PHASE 3: MAKE MEGA NEONS (from luminous neons)
    -- ============================================
    print("\n💎 PHASE 3: MAKING MEGA NEONS")
    print("========================================")
    
    -- Update UI
    if getgenv().ProgressUI then
        getgenv().ProgressUI.SetStatus("💎 Phase 3: Making mega neons...")
        getgenv().ProgressUI.UpdateStats("🌟 Neons: " .. neons_made, "📊 Phase: 3/3")
    end
    
    -- Wait for neon pets to become luminous
    print("⏳ Waiting 10 seconds for neon pets to reach luminous...")
    task.wait(10)
    
    local luminous_neons = get_luminous_neon_pets(CONFIG.PET_KIND)
    local megas_made = 0
    
    if #luminous_neons < 4 then
        print("⚠️ Not enough luminous neons to make mega (have " .. #luminous_neons .. ", need 4)")
        if #luminous_neons > 0 then
            print("⚠️ " .. #luminous_neons .. " luminous neon(s) will remain (cannot make mega)")
        end
    else
        local megaCount = math.floor(#luminous_neons / 4)
        print("Can make " .. megaCount .. " mega(s) from " .. #luminous_neons .. " luminous neons")
        
        for i = 1, megaCount do
            local start_idx = (i - 1) * 4 + 1
            local fourLuminous = {
                luminous_neons[start_idx],
                luminous_neons[start_idx + 1],
                luminous_neons[start_idx + 2],
                luminous_neons[start_idx + 3]
            }
            
            print("\n[" .. i .. "/" .. megaCount .. "] Making mega from 4 luminous neons...")
            
            local megaMsg = "Mega " .. i .. "/" .. megaCount .. "\nLuminous Neons:\n"
            for j, neonUnique in ipairs(fourLuminous) do
                megaMsg = megaMsg .. "  Neon " .. j .. ": " .. neonUnique .. "\n"
            end
            
            sendToWebhook("🔄 Making Mega #" .. i, megaMsg, false)
            
            if make_mega(fourLuminous) then
                megas_made = megas_made + 1
                print("✅ Mega " .. i .. " created!")
                sendToWebhook("✅ Mega Created!", "Successfully created mega " .. i .. "/" .. megaCount, false)
                task.wait(3)
            else
                warn("❌ Failed to make mega " .. i)
                sendToWebhook("❌ Mega Failed", "Failed to create mega " .. i .. "/" .. megaCount, true)
            end
        end
        
        -- Check for leftover luminous neons
        local leftover = #luminous_neons % 4
        if leftover > 0 then
            print("\n⚠️ " .. leftover .. " luminous neon(s) left over (cannot make mega)")
        end
    end
    
    print("\n✅ Mega making complete! Made " .. megas_made .. " megas")
    sendToWebhook("💎 Mega Making Complete", "Megas made: " .. megas_made, false)
    
    -- ============================================
    -- FINAL SUMMARY
    -- ============================================
    print("\n========================================")
    print("✅ AGING PROCESS COMPLETE")
    print("========================================")
    
    local potions_used = original_potion_count - #total_potions
    
    local finalMsg = "🎉 COMPLETE! 🎉\n\n"
    finalMsg = finalMsg .. "Pet Kind: " .. CONFIG.PET_KIND .. "\n"
    finalMsg = finalMsg .. "Rarity: " .. CONFIG.RARITY:upper() .. "\n"
    finalMsg = finalMsg .. "Potions Used: " .. potions_used .. "/" .. original_potion_count .. "\n"
    finalMsg = finalMsg .. "Potions Remaining: " .. #total_potions .. "\n"
    finalMsg = finalMsg .. "Neons Made: " .. neons_made .. "\n"
    finalMsg = finalMsg .. "Megas Made: " .. megas_made
    
    print("\n📊 Final Stats:")
    print("Potions used: " .. potions_used .. "/" .. original_potion_count)
    print("Potions remaining: " .. #total_potions)
    print("Neons made: " .. neons_made)
    print("Megas made: " .. megas_made)
    
    sendToWebhook("🎉 Process Complete!", finalMsg, false, true) -- IMMEDIATE
    
    -- Complete UI
    if getgenv().ProgressUI then
        getgenv().ProgressUI.Complete()
    end
end

-- ============================================
-- START THE AGING PROCESS
-- ============================================
print("🔧 Starting aging process...")
start_aging_process()

print("\n========================================")
print("✅ SCRIPT COMPLETE")
print("========================================")

getgenv().AgingScript.Running = false
