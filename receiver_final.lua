-- ============================================
-- RECEIVER SCRIPT - FINAL VERSION
-- Simple rarity-based calculation + Webhook
-- ============================================

getgenv().ReceiverConfig = {
    WEBHOOK_URL = "https://discord.com/api/webhooks/1454419132371042358/U45TbmAIksgoEDwC8fXrhlMe0w6lEVQ2KRjOCL2OeI_eiy4ZZA6Lfi7J280unr5vgXo1",
    RARITY = "legendary"  -- Set: legendary, ultra_rare, rare, uncommon, common
}

local CONFIG = getgenv().ReceiverConfig

local RARITY_AGE_UPS = {
    legendary = 7,
    ultra_rare = 4,
    rare = 2,
    uncommon = 2,
    common = 1
}

print("===========================================")
print("  RECEIVER - Final Version")
print("===========================================")

-- Wait for game
print("Waiting for game to load...")
repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:IsLoaded() and game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name

print("Game loaded!")

-- Dehash
print("Dehashing remotes...")
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end
print("Remotes dehashed!")

-- Enter game
print("Entering the game...")
local UIManager = require(ReplicatedStorage.Fsys).load("UIManager")
ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/ChooseTeam"):InvokeServer("Parents", {["source_for_logging"] = "intro_sequence"})
task.wait(1)
UIManager.set_app_visibility("MainMenuApp", false)
UIManager.set_app_visibility("NewsApp", false)
task.wait(2)
print("Entered game!")

-- Get player data
local function get_player_data()
    return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[tostring(LocalPlayer)]
end

-- Send webhook
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

-- Count age potions
local function count_age_potions()
    local success, result = pcall(function()
        local data = get_player_data()
        if not data or not data.inventory or not data.inventory.food then return 0 end
        
        local count = 0
        for _, item in pairs(data.inventory.food) do
            if item.kind == "pet_age_potion" then
                count = count + 1
            end
        end
        return count
    end)
    
    return success and result or 0
end

-- Count pets
local function count_pets()
    local success, count = pcall(function()
        local data = get_player_data()
        if not data or not data.inventory or not data.inventory.pets then return 0 end
        local total = 0
        for _ in pairs(data.inventory.pets) do total = total + 1 end
        return total
    end)
    return success and count or 0
end

-- Create request file
local function create_request_file(potions, pets_needed)
    pcall(function()
        local content = "username=" .. playerName .. "\n"
        content = content .. "potions=" .. potions .. "\n"
        content = content .. "total_pets=" .. pets_needed .. "\n"
        content = content .. "rarity=" .. CONFIG.RARITY .. "\n"
        content = content .. "timestamp=" .. os.time() .. "\n"
        content = content .. "status=pending\n"
        
        writefile("receiver_" .. playerName .. ".txt", content)
        writefile("new_request_flag.txt", tostring(os.time()))
        
        print("Request file created: receiver_" .. playerName .. ".txt")
        print("  Potions: " .. potions)
        print("  Pets needed: " .. pets_needed)
    end)
end

-- Auto-accept
local function setup_auto_accept(expected_pets)
    print("Setting up auto-accept...")
    
    pcall(function()
        local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
        local dialogApp = LocalPlayer.PlayerGui:FindFirstChild("DialogApp")
        
        local initialPets = count_pets()
        local webhookSent = false
        
        -- Phase 1: Accept popup
        task.spawn(function()
            while task.wait(0.3) do
                pcall(function()
                    if dialogApp and dialogApp:FindFirstChild("Dialog") and dialogApp.Dialog.Visible then
                        for _, player in pairs(Players:GetPlayers()) do
                            if player.Name ~= playerName then
                                ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest"):InvokeServer(player, true)
                            end
                        end
                    end
                end)
            end
        end)
        
        -- Phase 2: Accept negotiation
        task.spawn(function()
            while task.wait(0.5) do
                pcall(function()
                    if tradeGui.Visible then
                        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
                    end
                end)
            end
        end)
        
        -- Phase 3: Confirm
        task.spawn(function()
            while task.wait(0.5) do
                pcall(function()
                    if tradeGui.Visible then
                        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
                    end
                end)
            end
        end)
        
        -- Monitor completion
        task.spawn(function()
            local was_visible = false
            while task.wait(0.5) do
                pcall(function()
                    if tradeGui.Visible then
                        if not was_visible then
                            print("📋 Trade window opened!")
                            was_visible = true
                        end
                    elseif was_visible then
                        was_visible = false
                        
                        local current = count_pets()
                        local received = current - initialPets
                        
                        print("📦 Trade complete! Pets: " .. initialPets .. " → " .. current .. " (+" .. received .. "/" .. expected_pets .. ")")
                        
                        if received >= expected_pets and not webhookSent then
                            print("✅ ALL PETS RECEIVED! (" .. received .. "/" .. expected_pets .. ")")
                            
                            if isfile("receiver_" .. playerName .. ".txt") then
                                delfile("receiver_" .. playerName .. ".txt")
                                print("🗑️ Request file deleted")
                            end
                            
                            sendWebhook("✅ " .. playerName .. " - COMPLETE")
                            print("📡 Completion webhook sent!")
                            webhookSent = true
                        elseif received < expected_pets then
                            print("⏳ Waiting for more pets... (" .. received .. "/" .. expected_pets .. ")")
                        end
                    end
                end)
            end
        end)
        
        print("✅ Auto-accept enabled! Expected: " .. expected_pets .. " pets")
    end)
end

-- Main
pcall(function()
    print("\nCounting age potions...")
    local potions = count_age_potions()
    print("Age Potions Found: " .. potions)

    if potions == 0 then
        warn("No age potions found!")
        return
    end
    
    local age_ups = RARITY_AGE_UPS[CONFIG.RARITY] or 1
    local pets_needed = math.floor(potions / age_ups)
    
    if pets_needed == 0 then
        warn("Not enough potions!")
        return
    end
    
    print("\n📊 Calculation:")
    print("   Rarity: " .. CONFIG.RARITY)
    print("   Potions: " .. potions)
    print("   Pets needed: " .. pets_needed)
    
    setup_auto_accept(pets_needed)
    create_request_file(potions, pets_needed)
    
    print("\n✅ SUCCESS! Waiting for " .. pets_needed .. " pets")
end)

print("\n========================================")
print("RECEIVER ACTIVE")
print("========================================")

while task.wait(10) do end
