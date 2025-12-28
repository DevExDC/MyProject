-- ============================================
-- SMART AGING SCRIPT
-- Ages pets, creates neons automatically, disables when done
-- ============================================

if not getgenv().AgingConfig then
    getgenv().AgingConfig = {
        PET_KIND = "winter_2025_christmas_spirit",
        RARITY = "legendary",
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

-- Count age potions
local function count_age_potions()
    local count = 0
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.currency then
            count = playerData.inventory.currency.ageup_pet or 0
        end
    end)
    return count
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

-- Get pets that need aging (normal pets first, then neons)
local function get_pets_to_age(include_neons)
    local pets = {}
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for _, pet in pairs(playerData.inventory.pets) do
                if pet.kind == CONFIG.PET_KIND then
                    local is_neon = pet.properties and pet.properties.neon
                    local age = pet.properties and pet.properties.age or 0
                    
                    -- Skip full grown pets
                    if age >= 6 then
                        continue
                    end
                    
                    -- If include_neons is true, get everything
                    -- If false, only get normal pets
                    if include_neons or not is_neon then
                        table.insert(pets, {
                            unique = pet.unique,
                            age = age,
                            is_neon = is_neon
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

-- Age up pet
local function age_up_pet(pet_unique)
    pcall(function()
        local potions_needed = RARITY_AGE_UPS[rarity_lower]
        
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem"):InvokeServer(
            "food",
            "ageup_pet",
            {
                ["pets"] = {pet_unique},
                ["additional_consume_uniques"] = potions_needed - 1
            }
        )
    end)
end

-- Create neon
local function create_neon(pet_uniques)
    if #pet_uniques < 4 then
        return false
    end
    
    local success = false
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem"):InvokeServer(
            "pets",
            "neon_pet_combine",
            {
                ["pets"] = {pet_uniques[1], pet_uniques[2], pet_uniques[3], pet_uniques[4]}
            }
        )
        success = true
    end)
    return success
end

-- Get full grown pets
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

-- Main execution
print("\n🔍 Analyzing inventory...")

local potions = count_age_potions()
local potions_per_pet = RARITY_AGE_UPS[rarity_lower]

print(string.format("\n📊 Current Status:"))
print(string.format("   Potions: %d", potions))
print(string.format("   Potions per pet: %d", potions_per_pet))

if potions < potions_per_pet then
    print("\n❌ Not enough potions to age any pets!")
    print("   Disabling account...")
    disableAccount()
    return
end

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
    print(string.format("   Aging normal pet %d/%d (age: %d)", i, to_age_normal, pet.age))
    age_up_pet(pet.unique)
    aged_count = aged_count + 1
    task.wait(0.5)
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
        print(string.format("   Aging %s pet %d/%d (age: %d)", pet_type, i, to_age_extra, pet.age))
        age_up_pet(pet.unique)
        aged_count = aged_count + 1
        task.wait(0.5)
    end
    
    print(string.format("✅ Used remaining potions on %d pets", to_age_extra))
else
    print(string.format("   Only %d potions left (need %d to age)", remaining_potions, potions_per_pet))
    print("   ✅ Not enough to age any more pets")
end

-- Final status
local final_potions = count_age_potions()

print("\n" .. ("="):rep(50))
print("✅ AGING COMPLETE!")
print(("="):rep(50))
print(string.format("   Total pets aged: %d", aged_count))
print(string.format("   Neons created: %d", neons_created))
print(string.format("   Potions used: %d", potions - final_potions))
print(string.format("   Potions remaining: %d", final_potions))
print(("="):rep(50))

print("\n🔴 Disabling account...")
disableAccount()

print("\n========================================")
print("✅ SCRIPT COMPLETE & ACCOUNT DISABLED")
print("========================================")
