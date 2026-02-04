-- ============================================
-- SMART AGING SCRIPT - UPDATED
-- Pet resolved by name (resolveItem)
-- Friend's entry logic + UI disable
-- Kicks game when done
-- ============================================

if not getgenv().AgingConfig then
    getgenv().AgingConfig = {
        PET_NAME = "Christmas Spirit",  -- just put the pet name here, no need for the kind id
        WEBHOOK_URL = "",
        MAX_AGE_RETRIES = 5,
        AGE_VERIFY_WAIT = 3
    }
end

local CONFIG = getgenv().AgingConfig

if not CONFIG.PET_NAME or CONFIG.PET_NAME == "" then
    error("❌ Set PET_NAME!")
end

-- ============================================
-- WAIT FOR GAME READY (Friend's logic)
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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
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
        -- priority: kind match
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
        -- fallback: name match
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
-- normalize rarity from DB (e.g. "Ultra Rare" → "ultra_rare")
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
-- ANTI-AFK (No movement version)
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
for i, v in pairs(debug.getupvalue(RouterClient.init, 7)) do
    v.Name = i
end
print("✅ Remotes dehashed!")

-- ============================================
-- DISABLE USELESS UI (Friend's approach)
-- ============================================
LocalPlayer.PlayerGui.DialogApp.Enabled = false

-- ============================================
-- ENTER THE GAME (Friend's logic)
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

-- wait for character to fully load (friend's check)
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
print("  SMART AGING SYSTEM")
print("  + Pet resolved by name")
print("  + Kicks game when done")
print("===========================================")
print("Pet Name:     " .. CONFIG.PET_NAME)
print("Pet Kind:     " .. CONFIG.PET_KIND)
print("Rarity:       " .. CONFIG.RARITY)
print("Potions/pet:  " .. potions_per_pet)
print("===========================================")
print("✅ Ready to start!")

-- ============================================
-- DATA + WEBHOOK
-- ============================================
local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

local function sendWebhook(message)
    if not CONFIG.WEBHOOK_URL or CONFIG.WEBHOOK_URL == "" then return end
    pcall(function()
        request({
            Url = CONFIG.WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({["content"] = message})
        })
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

                -- skip megas, they're already done
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

-- ============== EQUIP PET ==============
local function equip_pet(pet_unique)
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(pet_unique, {
            use_sound_delay = true,
            equip_as_last = false
        })
    end)
end

-- ============== FEED POTIONS ==============
local function feed_potions_fast(pet_unique, working_potion_unique, sub_potions_array)
    local function equip_potion(potion_unique)
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(tostring(potion_unique), {
            use_sound_delay = false,
            equip_as_last = false
        })
        task.wait(1)
    end

    local function create_objects(p_unique, pot_unique, sub_potions)
        ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject"):InvokeServer(
            "__Enum_PetObjectCreatorType_2",
            {
                additional_consume_uniques = sub_potions,
                pet_unique = p_unique,
                unique_id = pot_unique
            }
        )
    end

    local function fast_consume(p_unique)
        local potion_object = workspace:WaitForChild("PetObjects"):FindFirstChild("AgePotion")
        if potion_object then
            ReplicatedStorage:WaitForChild("API"):WaitForChild("PetAPI/ConsumeFoodObject"):FireServer(potion_object, p_unique)
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

-- ============== AGE UP WITH VERIFICATION ==============
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
        task.wait(3)
        LocalPlayer:Kick("No pets found — done!")
        return
    end
    print(string.format("✅ Found %d pets of kind: %s", total_pets, CONFIG.PET_KIND))

    local total_potions = count_age_potions()
    if total_potions == 0 then
        print("\n❌ NO AGE POTIONS")
        sendWebhook(string.format("❌ %s - No potions, kicking.", playerName))
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
    local MAX_CYCLES = 100

    while cycle < MAX_CYCLES do
        cycle = cycle + 1
        print(string.format("\n========== CYCLE %d ==========", cycle))

        local analysis = analyze_pet_inventory()
        local potions  = count_age_potions()

        print(string.format("📊 %s:", CONFIG.PET_KIND))
        print(string.format("   Potions:            %d", potions))
        print(string.format("   Normal (not fg):    %d", #analysis.normal_pets))
        print(string.format("   Normal (fg / age6): %d", analysis.full_grown_normal))
        print(string.format("   Neon   (not fg):    %d", #analysis.neon_pets))
        print(string.format("   Neon   (fg / age6): %d", analysis.full_grown_neons))

        local did_something = false

        -- ============================================
        -- PHASE 1: AGE ONE PET
        --   → normals first, if none then neons
        --   → if not enough for a full batch, burn leftovers
        -- ============================================
        local aged_this_cycle = false

        if #analysis.normal_pets > 0 and potions >= potions_per_pet then
            -- full batch on a normal
            print("\n🐾 AGING: normal pet...")
            local pet = analysis.normal_pets[1]
            local potion_batch = get_age_potion_uniques(potions_per_pet)

            if #potion_batch >= potions_per_pet then
                print(string.format("   age %d → 6", pet.age))
                local success = age_up_pet_verified(pet.unique, potion_batch, 6)
                if success then total_aged = total_aged + 1
                else            total_failed = total_failed + 1 end
                aged_this_cycle = true
                did_something   = true
            end

        elseif #analysis.neon_pets > 0 and potions >= potions_per_pet then
            -- no normals left to age → age a neon
            print("\n💎 AGING: neon pet...")
            local pet = analysis.neon_pets[1]
            local potion_batch = get_age_potion_uniques(potions_per_pet)

            if #potion_batch >= potions_per_pet then
                print(string.format("   age %d → 6", pet.age))
                local success = age_up_pet_verified(pet.unique, potion_batch, 6)
                if success then total_aged = total_aged + 1
                else            total_failed = total_failed + 1 end
                aged_this_cycle = true
                did_something   = true
            end

        elseif potions > 0 and potions < potions_per_pet then
            -- leftover potions that can't fill a full batch → burn them
            -- re-read so we have the freshest picture
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
            task.wait(2)
        end

        -- ============================================
        -- PHASE 2: FUSE (runs every cycle after aging)
        --   → 4 full-grown normals  →  neon
        --   → 4 full-grown neons    →  mega
        -- ============================================
        -- re-read inventory so fusions see the pet we just aged
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

        -- re-read again because the neon we just made might already be age 6
        -- (newly fused neons start at age 0 so this is just safety)
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

        -- ============================================
        -- NOTHING LEFT TO DO → break out
        -- ============================================
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

    -- ============================================
    -- FINAL SUMMARY + KICK
    -- ============================================
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

    print("\n🔴 Aging done — kicking in 3s...")
    task.wait(3)
    LocalPlayer:Kick("Aging complete!")
end

-- ============================================
-- RUN
-- ============================================
run_aging()
