-- ============================================
-- RECEIVER - SMART AUTO-COMPLETE (FIXED)
-- Keeps original trade logic + smart completion
-- ============================================

if not getgenv().ReceiverConfig then
    getgenv().ReceiverConfig = {
        PC_SERVER_URL = "https://spinelike-lenora-unmovingly.ngrok-free.dev/request",
        WEBHOOK_URL = "",
        RARITY = "legendary",
        PET_KIND = "winter_2025_christmas_spirit",
        FARMSYNC_API_KEY = "",
        NO_TRADE_TIMEOUT = 300,        -- Auto-complete if no trades for 5 min
        STATUS_CHECK_INTERVAL = 10     -- Check server status every 10s
    }
end

local CONFIG = getgenv().ReceiverConfig

if CONFIG.PC_SERVER_URL == "" or CONFIG.PC_SERVER_URL:match("YOUR_PC_IP") then
    error("❌ Set PC_SERVER_URL!")
end

if not CONFIG.RARITY or CONFIG.RARITY == "" then
    error("❌ Set RARITY!")
end

if not CONFIG.PET_KIND or CONFIG.PET_KIND == "" then
    error("❌ Set PET_KIND!")
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
print("  RECEIVER - SMART AUTO-COMPLETE v2.0")
print("  + Auto-complete detection")
print("  + No-trade timeout")
print("===========================================")
print("No-Trade Timeout: " .. CONFIG.NO_TRADE_TIMEOUT .. "s")
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

print("⚠️ NOT spawning - waiting for trades without spawn!")

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

local function get_player_data()
    return Data.get_data()[tostring(LocalPlayer)]
end

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

local function post_to_pc_server(potions, pets_needed)
    local success = false
    pcall(function()
        local data = {
            username = playerName,
            potions = potions,
            pets_needed = pets_needed,
            rarity = CONFIG.RARITY
        }
        
        print("\n📡 Sending request to PC server...")
        print("  URL: " .. CONFIG.PC_SERVER_URL)
        print("  Username: " .. playerName)
        print("  Pets needed: " .. pets_needed)
        
        local response = request({
            Url = CONFIG.PC_SERVER_URL,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
        
        if response.StatusCode == 200 then
            print("✅ Request sent to PC successfully!")
            success = true
        else
            warn("⚠️  PC server responded with: " .. response.StatusCode)
        end
    end)
    return success
end

local function disableAccount()
    if CONFIG.FARMSYNC_API_KEY == "" then 
        print("⚠️ No API key, skipping auto-disable")
        return false
    end
    
    local success = false
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
        success = true
    end)
    return success
end

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

local function count_specific_pets(pet_kind)
    local success, count = pcall(function()
        local data = get_player_data()
        if not data or not data.inventory or not data.inventory.pets then return 0 end
        local total = 0
        for _, pet in pairs(data.inventory.pets) do
            if pet.kind == pet_kind then
                total = total + 1
            end
        end
        return total
    end)
    return success and count or 0
end

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

-- ============== ORIGINAL AUTO-ACCEPT (NO CHANGES) ==============

local function setup_auto_accept(expected_pets)
    pcall(function()
        local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
        local dialogApp = LocalPlayer.PlayerGui:WaitForChild("DialogApp")
        local initialPets = count_pets()
        local webhookSent = false
        
        print("\n✅ Auto-accept system ready (no spawn mode)")
        
        -- Phase 1: Auto-accept EVERY trade request (ORIGINAL - NO FLAGS)
        task.spawn(function()
            print("✅ Phase 1: Continuous dialog acceptor started")
            while task.wait(0.3) do
                pcall(function()
                    -- NO EARLY RETURN - Accept all trades continuously
                    local dialogVisible = dialogApp and dialogApp:FindFirstChild("Dialog") and dialogApp.Dialog.Visible
                    
                    if dialogVisible then
                        print("\n📨 Trade request detected!")
                        
                        -- Accept from ALL players
                        for _, player in pairs(Players:GetPlayers()) do
                            if player ~= LocalPlayer then
                                local success = pcall(function()
                                    local args = {player, true}
                                    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest"):InvokeServer(unpack(args))
                                end)
                                if success then
                                    print("   ✅ Accepted from: " .. player.Name)
                                end
                                task.wait(0.2)
                            end
                        end
                    end
                end)
            end
        end)
        
        -- Phase 2: Auto-accept negotiation (ORIGINAL)
        task.spawn(function()
            while task.wait(0.1) do
                pcall(function()
                    if tradeGui.Visible then
                        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
                    end
                end)
            end
        end)
        
        -- Phase 3: Auto-confirm trade (ORIGINAL)
        task.spawn(function()
            while task.wait(0.1) do
                pcall(function()
                    if tradeGui.Visible then
                        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
                    end
                end)
            end
        end)
        
        -- ============== ENHANCED MONITOR WITH SMART COMPLETION ==============
        task.spawn(function()
            local was_visible = false
            local last_pet_count = initialPets
            local last_trade_time = tick()
            local last_status_check = 0
            local start_time = tick()
            
            while task.wait(0.5) do
                pcall(function()
                    local current = count_pets()
                    local received = current - initialPets
                    local time_since_last_trade = tick() - last_trade_time
                    local elapsed_minutes = math.floor((tick() - start_time) / 60)
                    
                    -- Check for new pets
                    if current > last_pet_count then
                        last_pet_count = current
                        last_trade_time = tick()
                        print(string.format("📦 Trade received! Progress: %d/%d", received, expected_pets))
                    end
                    
                    -- ============================================
                    -- CHECK 1: Got all pets!
                    -- ============================================
                    if received >= expected_pets and not webhookSent then
                        print("\n" .. ("="):rep(50))
                        print("✅ SUCCESS! All pets received!")
                        print(("="):rep(50))
                        print(string.format("   Received: %d/%d pets", received, expected_pets))
                        print(string.format("   Time: %dm", elapsed_minutes))
                        print(("="):rep(50))
                        
                        sendWebhook(string.format("✅ %s - COMPLETE - %d pets in %dm!", 
                            playerName, received, elapsed_minutes))
                        
                        disableAccount()
                        webhookSent = true
                        return
                    end
                    
                    -- ============================================
                    -- CHECK 2: Check server status
                    -- ============================================
                    last_status_check = last_status_check + 0.5
                    if last_status_check >= CONFIG.STATUS_CHECK_INTERVAL then
                        last_status_check = 0
                        
                        pcall(function()
                            local response = request({
                                Url = CONFIG.PC_SERVER_URL:gsub("/request", "/check_status/" .. playerName),
                                Method = "GET"
                            })
                            
                            if response.StatusCode == 200 then
                                local status_data = HttpService:JSONDecode(response.Body)
                                
                                if status_data.message == "insufficient_pets" and not webhookSent then
                                    print("\n" .. ("="):rep(50))
                                    print("📨 SERVER: Holder ran out of pets!")
                                    print(("="):rep(50))
                                    print(string.format("   Holder sent: %d pets", status_data.pets_sent or 0))
                                    print(string.format("   Expected: %d pets", expected_pets))
                                    print(string.format("   Received: %d pets", received))
                                    print(("="):rep(50))
                                    
                                    sendWebhook(string.format("📨 %s - Holder out of pets - Got %d/%d", 
                                        playerName, received, expected_pets))
                                    
                                    disableAccount()
                                    webhookSent = true
                                    return
                                end
                            end
                        end)
                    end
                    
                    -- ============================================
                    -- CHECK 3: No trades for too long (ONLY if received > 0)
                    -- ============================================
                    if time_since_last_trade > CONFIG.NO_TRADE_TIMEOUT and received > 0 and not webhookSent then
                        print("\n" .. ("="):rep(50))
                        print("⚠️ AUTO-COMPLETE: No trades timeout!")
                        print(("="):rep(50))
                        print(string.format("   Last trade: %.0fs ago", time_since_last_trade))
                        print(string.format("   Timeout: %ds", CONFIG.NO_TRADE_TIMEOUT))
                        print(string.format("   Received: %d/%d pets", received, expected_pets))
                        print(("="):rep(50))
                        print("💡 Holder likely ran out of pets!")
                        
                        sendWebhook(string.format("⚠️ %s - Auto-complete (no trades %ds) - Got %d/%d", 
                            playerName, math.floor(time_since_last_trade), received, expected_pets))
                        
                        disableAccount()
                        webhookSent = true
                        return
                    end
                    
                    -- Trade window monitoring
                    if tradeGui.Visible then
                        if not was_visible then
                            was_visible = true
                            print("📋 Trade window opened")
                        end
                    elseif was_visible then
                        was_visible = false
                        print(string.format("📦 Trade closed! Progress: %d/%d", received, expected_pets))
                    end
                    
                    -- Status update every 30 seconds
                    if math.floor(tick() - start_time) % 30 == 0 and math.floor(tick() - start_time) > 0 then
                        print(string.format("\n📊 [%dm] Status: %d/%d pets | Last trade: %.0fs ago", 
                            elapsed_minutes, received, expected_pets, time_since_last_trade))
                    end
                end)
            end
        end)
    end)
end

-- ============== MAIN EXECUTION ==============

print("\n🔍 Analyzing inventory (without spawning)...")

pcall(function()
    local potions = count_age_potions()
    
    if potions == 0 then
        print("❌ No potions")
        disableAccount()
        return
    end
    
    local age_ups = RARITY_AGE_UPS[rarity_lower]
    local total_pets_needed = math.floor(potions / age_ups)
    
    if total_pets_needed == 0 then
        print("❌ Not enough potions")
        disableAccount()
        return
    end
    
    local existing_pets = count_specific_pets(CONFIG.PET_KIND)
    local pets_to_request = total_pets_needed - existing_pets
    
    print("\n📊 Calculation:")
    print("   Potions: " .. potions)
    print("   Total needed: " .. total_pets_needed)
    print("   Already have: " .. existing_pets)
    print("   Will request: " .. pets_to_request)
    
    if pets_to_request <= 0 then
        print("\n✅ Already have enough pets!")
        sendWebhook(string.format("✅ %s - Already has %d/%d pets", playerName, existing_pets, total_pets_needed))
        disableAccount()
        return
    end
    
    -- Setup auto-accept with smart completion
    setup_auto_accept(pets_to_request)
    
    -- Send request to PC server
    local server_success = post_to_pc_server(potions, pets_to_request)
    
    if server_success then
        print("\n✅ Waiting for " .. pets_to_request .. " pets")
        print("💡 Smart completion enabled:")
        print("   • Will complete when all pets received")
        print("   • Will auto-complete if holder runs out")
        print("   • Will auto-complete after " .. CONFIG.NO_TRADE_TIMEOUT .. "s no trades")
    else
        print("\n⚠️ Failed to contact PC server, but continuing...")
    end
end)

-- Keep script running
while task.wait(10) do end
