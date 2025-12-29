-- ============================================
-- RECEIVER - UPDATED WITH PROPER STARTER
-- Smart pet detection + Status checking
-- ============================================

if not getgenv().ReceiverConfig then
    getgenv().ReceiverConfig = {
        PC_SERVER_URL = "https://spinelike-lenora-unmovingly.ngrok-free.dev/request",
        WEBHOOK_URL = "",
        RARITY = "legendary",
        PET_KIND = "winter_2025_christmas_spirit",
        FARMSYNC_API_KEY = ""
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
print("  RECEIVER - PC Server Version")
print("===========================================")

repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name

-- ============== ANTI-AFK ==============
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
    print("🔄 Anti-AFK triggered")
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

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

local function get_player_data()
    return Data.get_data()[tostring(LocalPlayer)]
end

-- Send webhook (optional)
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

-- POST request to PC server
local function post_to_pc_server(potions, pets_needed)
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
        else
            warn("⚠️  PC server responded with: " .. response.StatusCode)
        end
    end)
end

local function disableAccount()
    if CONFIG.FARMSYNC_API_KEY == "" then return end
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

-- Count specific pet kind in inventory
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

local function setup_auto_accept(expected_pets)
    pcall(function()
        local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
        local dialogApp = LocalPlayer.PlayerGui:FindFirstChild("DialogApp")
        local initialPets = count_pets()
        local webhookSent = false
        
        -- Phase 1: Auto-accept trade requests
        task.spawn(function()
            while task.wait(0.3) do
                pcall(function()
                    if dialogApp and dialogApp:FindFirstChild("Dialog") and dialogApp.Dialog.Visible then
                        for _, player in pairs(Players:GetPlayers()) do
                            if player.Name ~= playerName then
                                local args = {player, true}
                                ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest"):InvokeServer(unpack(args))
                            end
                        end
                    end
                end)
            end
        end)
        
        -- Phase 2: Auto-accept negotiation (SPAM THIS!)
        task.spawn(function()
            while task.wait(0.1) do
                pcall(function()
                    if tradeGui.Visible then
                        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
                    end
                end)
            end
        end)
        
        -- Phase 3: Auto-confirm trade (SPAM THIS!)
        task.spawn(function()
            while task.wait(0.1) do
                pcall(function()
                    if tradeGui.Visible then
                        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
                    end
                end)
            end
        end)
        
        task.spawn(function()
            local was_visible = false
            local last_pet_count = initialPets
            local no_change_time = 0
            local MAX_WAIT_TIME = 5400 -- 90 minutes timeout
            local last_status_check = 0
            
            while task.wait(0.5) do
                pcall(function()
                    local current = count_pets()
                    
                    -- Check for status message from holder every 10 seconds
                    last_status_check = last_status_check + 0.5
                    if last_status_check >= 10 then
                        last_status_check = 0
                        
                        pcall(function()
                            local response = request({
                                Url = CONFIG.PC_SERVER_URL:gsub("/request", "/check_status/" .. playerName),
                                Method = "GET"
                            })
                            
                            if response.StatusCode == 200 then
                                local status_data = HttpService:JSONDecode(response.Body)
                                
                                if status_data.message == "insufficient_pets" then
                                    print("\n📨 STATUS FROM HOLDER: Insufficient pets!")
                                    print(string.format("   Received: %d/%d pets", status_data.pets_sent or 0, expected_pets))
                                    print("   Holder doesn't have enough pets")
                                    print("   ✅ Proceeding to aging phase...\n")
                                    
                                    sendWebhook(string.format("📨 %s - Holder out of pets - Received %d/%d - Moving to aging", 
                                        playerName, status_data.pets_sent or 0, expected_pets))
                                    
                                    disableAccount()
                                    webhookSent = true
                                    return
                                end
                            end
                        end)
                    end
                    
                    -- Check if received new pets
                    if current > last_pet_count then
                        -- Got pets! Reset timeout
                        last_pet_count = current
                        no_change_time = 0
                        print(string.format("📦 Received pets! Total: %d/%d", current - initialPets, expected_pets))
                    else
                        -- No new pets, increment timer
                        no_change_time = no_change_time + 0.5
                        
                        -- Check timeout
                        if no_change_time >= MAX_WAIT_TIME and not webhookSent then
                            local received = current - initialPets
                            print(string.format("⏱️ TIMEOUT: No pets received for 90 minutes"))
                            print(string.format("   Final count: %d/%d pets", received, expected_pets))
                            
                            if received > 0 then
                                sendWebhook(string.format("⏱️ %s - TIMEOUT - Received %d/%d pets (partial)", playerName, received, expected_pets))
                            else
                                sendWebhook(string.format("⏱️ %s - TIMEOUT - No pets received", playerName))
                            end
                            
                            print("🔴 Auto-disabling due to timeout...")
                            disableAccount()
                            webhookSent = true
                            return
                        end
                    end
                    
                    -- Trade window monitoring
                    if tradeGui.Visible then
                        if not was_visible then
                            was_visible = true
                            print("📋 Trade window opened!")
                        end
                    elseif was_visible then
                        was_visible = false
                        
                        current = count_pets()
                        local received = current - initialPets
                        
                        print(string.format("📦 Trade closed! Progress: %d/%d pets", received, expected_pets))
                        
                        if received >= expected_pets and not webhookSent then
                            print("✅ ALL PETS RECEIVED! (" .. received .. "/" .. expected_pets .. ")")
                            
                            sendWebhook("✅ " .. playerName .. " - COMPLETE - Received all " .. expected_pets .. " pets!")
                            print("📡 Completion webhook sent!")
                            
                            disableAccount()
                            
                            webhookSent = true
                        elseif received < expected_pets then
                            print(string.format("⏳ Waiting for more pets... (%d/%d)", received, expected_pets))
                            -- Reset timeout after each trade
                            no_change_time = 0
                        end
                    end
                end)
            end
        end)
    end)
end

print("\n🔍 Analyzing inventory...")

pcall(function()
    local potions = count_age_potions()
    
    if potions == 0 then
        print("❌ No potions found, disabling account...")
        disableAccount()
        return
    end
    
    local age_ups = RARITY_AGE_UPS[rarity_lower]
    local total_pets_needed = math.floor(potions / age_ups)
    
    if total_pets_needed == 0 then
        print("❌ Not enough potions to age any pets, disabling...")
        disableAccount()
        return
    end
    
    -- Count existing pets of this kind
    local existing_pets = count_specific_pets(CONFIG.PET_KIND)
    local pets_to_request = total_pets_needed - existing_pets
    
    print("\n📊 Calculation:")
    print("   Potions: " .. potions)
    print("   Total pets needed: " .. total_pets_needed)
    print("   Already have: " .. existing_pets)
    print("   Will request: " .. pets_to_request)
    
    -- If already have enough or more, skip to aging!
    if pets_to_request <= 0 then
        print("\n✅ Already have enough pets (" .. existing_pets .. "/" .. total_pets_needed .. ")")
        print("   Skipping holder request, proceeding to aging...")
        
        sendWebhook(string.format("✅ %s - Already has %d/%d pets - Skipping to aging", 
            playerName, existing_pets, total_pets_needed))
        
        disableAccount()
        return
    end
    
    setup_auto_accept(pets_to_request)
    post_to_pc_server(potions, pets_to_request)
    
    print("\n✅ Waiting for " .. pets_to_request .. " pets (have " .. existing_pets .. " already)")
end)

while task.wait(10) do end
