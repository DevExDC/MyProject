-- ============================================
-- RECEIVER SCRIPT - Pet Distribution System
-- Created by DevEx
-- GitHub Ready Version
-- ============================================

-- ============================================
-- CONFIGURATION (Edit this section)
-- ============================================
getgenv().ReceiverConfig = getgenv().ReceiverConfig or {
    -- Holder Account Settings
    HOLDER_USERNAME = "YourHolderAccountName",  -- The account that will send you pets
    
    -- Optional Webhook (leave empty "" if you don't want logging)
    WEBHOOK_URL = ""
}

-- ============================================
-- SCRIPT START
-- ============================================
print("===========================================")
print("  RECEIVER - Pet Distribution System")
print("  Created by DevEx")
print("===========================================")

local CONFIG = getgenv().ReceiverConfig

-- Wait for game to load
repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:IsLoaded() and game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local receiverName = LocalPlayer.Name

print("Receiver: " .. receiverName)
print("Waiting for holder: " .. CONFIG.HOLDER_USERNAME)
print("===========================================")

-- Dehash remotes
print("Dehashing remotes...")
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end
print("Remotes dehashed!")

-- Enter game
print("Entering the game...")
local UIManager = require(ReplicatedStorage.Fsys).load("UIManager")
local args = {[1] = "Parents", [2] = {["source_for_logging"] = "intro_sequence"}}
ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/ChooseTeam"):InvokeServer(unpack(args))
task.wait(1)
UIManager.set_app_visibility("MainMenuApp", false)
UIManager.set_app_visibility("NewsApp", false)
task.wait(2)
print("Entered game!")

-- Webhook function
local function sendWebhook(title, description, error_mode)
    if CONFIG.WEBHOOK_URL == "" then return end
    
    local success, err = pcall(function()
        local embed = {
            ["embeds"] = {{
                ["title"] = title,
                ["description"] = description,
                ["color"] = error_mode and 16711680 or 65280,
                ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S")
            }}
        }
        
        request({
            Url = CONFIG.WEBHOOK_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(embed)
        })
    end)
end

-- Count age potions
local function count_age_potions()
    local success, count = pcall(function()
        local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = Data.get_data()[receiverName]
        
        if not playerData or not playerData.inventory or not playerData.inventory.food then
            return 0
        end
        
        local total = 0
        for _, food in pairs(playerData.inventory.food) do
            if food.kind == "age_up_potion" then
                total = total + (food.quantity or 0)
            end
        end
        
        return total
    end)
    
    return success and count or 0
end

-- Create request file
local function create_request_file()
    local potions = count_age_potions()
    
    if potions == 0 then
        warn("No age potions found! Cannot create request.")
        return false
    end
    
    local filename = "receiver_" .. receiverName .. ".txt"
    local content = "username=" .. receiverName .. "\npotions=" .. potions .. "\nstatus=pending\ntimestamp=" .. os.time()
    
    local success = pcall(function()
        writefile(filename, content)
    end)
    
    if success then
        print("✅ Request file created: " .. filename)
        print("   Potions: " .. potions)
        sendWebhook("📋 Request Created", "Requesting pets for " .. potions .. " age potions", false)
        return true
    else
        warn("Failed to create request file!")
        return false
    end
end

-- Setup auto-accept for trades
local function setup_auto_accept()
    local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
    
    local function accept_trade(player)
        if player.Name ~= CONFIG.HOLDER_USERNAME then
            print("❌ Trade from " .. player.Name .. " - Not the holder, ignoring")
            return
        end
        
        print("✅ Trade request from holder: " .. player.Name)
        sendWebhook("📨 Trade Received", "Accepting trade from " .. player.Name, false)
        
        -- Phase 1: Accept trade request popup (spam 5x over 1 second)
        print("Phase 1: Accepting trade request...")
        for i = 1, 5 do
            pcall(function()
                ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest"):FireServer(player, true)
            end)
            task.wait(0.2)
        end
        
        -- Wait for trade window to open
        task.wait(2)
        
        -- Phase 2: Accept negotiation (green checkmark) - spam 10x over 5 seconds
        print("Phase 2: Accepting negotiation...")
        for i = 1, 10 do
            pcall(function()
                ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
            end)
            task.wait(0.5)
        end
        
        -- Phase 3: Confirm trade - spam 10x over 5 seconds
        print("Phase 3: Confirming trade...")
        for i = 1, 10 do
            pcall(function()
                ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
            end)
            task.wait(0.5)
        end
        
        print("✅ Trade accepted and confirmed!")
    end
    
    -- Listen for trade requests
    local TradeAPI = ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/SendTradeRequest")
    
    for _, connection in pairs(getconnections(TradeAPI.OnClientEvent)) do
        connection:Disable()
    end
    
    TradeAPI.OnClientEvent:Connect(function(player)
        accept_trade(player)
    end)
    
    print("✅ Auto-accept system active for: " .. CONFIG.HOLDER_USERNAME)
end

-- Main execution
local function main()
    -- Wait for holder to join
    print("⏳ Waiting for holder to join server...")
    
    local holder = nil
    local attempts = 0
    
    while not holder and attempts < 60 do
        holder = Players:FindFirstChild(CONFIG.HOLDER_USERNAME)
        if not holder then
            task.wait(1)
            attempts = attempts + 1
        end
    end
    
    if not holder then
        warn("❌ Holder not found after 60 seconds!")
        sendWebhook("❌ Error", "Holder " .. CONFIG.HOLDER_USERNAME .. " not in server", true)
        return
    end
    
    print("✅ Holder found: " .. holder.Name)
    
    -- Setup auto-accept
    setup_auto_accept()
    
    -- Create request file
    if not create_request_file() then
        warn("Failed to create request file!")
        return
    end
    
    -- Monitor trade completion
    local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
    local initialPotions = count_age_potions()
    
    print("📊 Monitoring trades...")
    print("   Initial potions: " .. initialPotions)
    
    -- Wait for all trades to complete
    local lastCheck = os.time()
    local tradesComplete = false
    
    while not tradesComplete do
        task.wait(3)
        
        -- Check if we received pets (potions should decrease)
        local currentPotions = count_age_potions()
        
        if currentPotions < initialPotions then
            print("📦 Received pets! Potions: " .. initialPotions .. " → " .. currentPotions)
            
            -- If no more potions, we're done
            if currentPotions == 0 then
                tradesComplete = true
                print("✅ All trades complete!")
                sendWebhook("✅ Complete", "Received all pets! Used " .. initialPotions .. " potions", false)
                
                -- Delete request file
                local filename = "receiver_" .. receiverName .. ".txt"
                pcall(function()
                    delfile(filename)
                    print("🗑️ Request file deleted")
                end)
            else
                initialPotions = currentPotions
            end
        end
        
        -- Timeout after 5 minutes of no activity
        if os.time() - lastCheck > 300 then
            print("⏱️ Timeout - No activity for 5 minutes")
            break
        end
    end
    
    print("===========================================")
    print("  RECEIVER FINISHED")
    print("===========================================")
end

-- Error handling wrapper
local success, error_msg = pcall(main)

if not success then
    warn("❌ ERROR: " .. tostring(error_msg))
    sendWebhook("❌ Script Error", "```\n" .. tostring(error_msg) .. "\n```", true)
end
