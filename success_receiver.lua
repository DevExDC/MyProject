--[[
    SUCCESS RECEIVER - Accepts All Trades
    Run this on 1 VPS account to receive all pets after aging
    No spawning needed - can trade without being in world
]]

getgenv().Config = getgenv().Config or {
    FARMSYNC_API_KEY = "0f22da569a1e7da354c3c628813bb2652dc81fbbb82b45c139f9aedf0cc5a9c6",
    Webhook = "YOUR_DISCORD_WEBHOOK",
    CheckInterval = 2,  -- Check for trades every 2 seconds
    AcceptDelay = 1     -- Wait 1s before accepting
}

local config = getgenv().Config

-- ============== UTILITIES ==============

local function sendWebhook(content)
    if not config.Webhook or config.Webhook == "" or config.Webhook == "YOUR_DISCORD_WEBHOOK" then
        return
    end
    
    pcall(function()
        local data = {
            ["content"] = content,
            ["username"] = "Success Receiver"
        }
        
        local http = game:GetService("HttpService")
        local final = http:JSONEncode(data)
        
        http:PostAsync(config.Webhook, final, Enum.HttpContentType.ApplicationJson)
    end)
end

local function disableAccount()
    pcall(function()
        local url = string.format(
            "https://api.farmsync.cloud/api/self/accounts/%s",
            game.Players.LocalPlayer.Name
        )
        
        local http = game:GetService("HttpService")
        local headers = {
            ["Authorization"] = "Bearer " .. config.FARMSYNC_API_KEY,
            ["Content-Type"] = "application/json"
        }
        
        local data = http:JSONEncode({enabled = false})
        
        local success, response = pcall(function()
            return game:HttpPost(url, data, true, headers)
        end)
        
        if success then
            print("✅ Account disabled via FarmSync API")
            sendWebhook(string.format("🔴 %s - Account Disabled", game.Players.LocalPlayer.Name))
        end
    end)
end

-- ============== ANTI-AFK ==============

local VirtualUser = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ============== TRADE SYSTEM ==============

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local API = require(ReplicatedStorage:WaitForChild("API"))
local TradeAPI = API:Get("TradeAPI")

local playerName = game.Players.LocalPlayer.Name
local tradesAccepted = 0
local petsReceived = 0

print("🎯 SUCCESS RECEIVER STARTED")
print(string.format("👤 Account: %s", playerName))
sendWebhook(string.format("🎯 %s - Success Receiver Online", playerName))

-- Track last trade to avoid duplicates
local lastTradePartner = nil
local lastTradeTime = 0

-- ============== MAIN LOOP ==============

while true do
    pcall(function()
        -- Check for active trade
        local activeTradeData = TradeAPI:GetActiveTradeData()
        
        if activeTradeData then
            local partner = activeTradeData.player_name
            local currentTime = tick()
            
            -- Avoid accepting same trade multiple times
            if partner ~= lastTradePartner or (currentTime - lastTradeTime) > 10 then
                lastTradePartner = partner
                lastTradeTime = currentTime
                
                print(string.format("📥 Trade from: %s", partner))
                
                -- Wait for trade to be ready
                wait(config.AcceptDelay)
                
                -- Count pets being offered
                local offeredPets = 0
                if activeTradeData.other_offer and activeTradeData.other_offer.pets then
                    offeredPets = #activeTradeData.other_offer.pets
                end
                
                print(string.format("📦 Pets offered: %d", offeredPets))
                
                -- Accept the trade
                local success, err = pcall(function()
                    -- Click accept button
                    TradeAPI:AcceptTrade()
                    wait(0.5)
                    
                    -- Confirm trade
                    TradeAPI:ConfirmTrade()
                end)
                
                if success then
                    tradesAccepted = tradesAccepted + 1
                    petsReceived = petsReceived + offeredPets
                    
                    print(string.format("✅ Trade accepted! Total: %d trades, %d pets", tradesAccepted, petsReceived))
                    
                    sendWebhook(string.format(
                        "✅ %s - Trade Accepted\n📦 From: %s\n🐾 Pets: %d\n📊 Total: %d trades, %d pets",
                        playerName, partner, offeredPets, tradesAccepted, petsReceived
                    ))
                else
                    warn("❌ Failed to accept trade:", err)
                end
                
                wait(2)  -- Cooldown after trade
            end
        end
    end)
    
    wait(config.CheckInterval)
end
