--[[
    Multi-Target Auto Trade System (SUCCESS SCRIPT)
    FINAL VERSION v2.0.0
    - Fixed neon detection (v.properties.neon)
    - Added auto-disable when complete
    - Integrated with Progress UI
]]

-- Services
repeat wait() until game:IsLoaded()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name

-- Modules
local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- Configuration (loaded from main script)
getgenv().Config = getgenv().Config or {
    usernames = {},
    How_many_Pets = {},
    pets_to_trade = {},
    Neon = false,
    Webhook = "",
    FARMSYNC_API_KEY = "" -- For auto-disable
}

local config = getgenv().Config

-- Variables
local currentTargetIndex = 1
local pets_unique_ids = {}
local trade_status = false
local completedTrades = {}

print("===========================================")
print("  Multi-Target Auto Trade System v2.0.0")
print("===========================================")

-- Load Progress UI
local UILoaded = pcall(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/DevExDC/MyProject/refs/heads/main/progress_ui_universal.lua"))()
end)

if UILoaded then
    print("✅ Progress UI loaded")
    wait(1)
else
    warn("⚠️ Progress UI failed to load, continuing without UI")
end

-- Dehash function
local function dehash()
    local function rename(remotename, hashedremote)
        hashedremote.Name = remotename
    end
    local success, err = pcall(function()
        table.foreach(
            getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7),
            rename
        )
    end)
    if success then
        print("✅ Dehashed remotes successfully")
    else
        warn("❌ Dehash failed:", err)
    end
end
dehash()

-- Disable account
local function disableAccount()
    if config.FARMSYNC_API_KEY == "" then 
        print("⚠️ No API key, skipping auto-disable")
        return 
    end
    
    pcall(function()
        request({
            Url = "https://api.farmsync.cloud/api/self/accounts/" .. playerName,
            Method = "PUT",
            Headers = {
                ["Authorization"] = "Bearer " .. config.FARMSYNC_API_KEY,
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode({enabled = false})
        })
        
        print("🔴 Account disabled!")
    end)
end

-- Webhook function
local function sendWebhook(username, petCount, status, extraInfo)
    if not config.Webhook or config.Webhook == "" then return end
    
    local statusEmoji = status == "Success" and "✅" or (status:match("Failed") and "❌" or "⚠️")
    local statusColor = status == "Success" and 5763719 or (status:match("Failed") and 15548997 or 16705372)
    
    local description = string.format(
        "**Target Username:** `%s`\n**Pets Traded:** `%d`\n**Pet Type:** `%s`\n**Neon Only:** `%s`\n**Status:** %s `%s`",
        username,
        petCount,
        config.pets_to_trade[1] or "Unknown",
        config.Neon and "Yes ✨" or "No",
        statusEmoji,
        status
    )
    
    if extraInfo then
        description = description .. "\n**Details:** " .. extraInfo
    end
    
    local embed = {
        ["content"] = nil,
        ["embeds"] = {{
            ["title"] = "🤝 Auto Trade System",
            ["description"] = description,
            ["color"] = statusColor,
            ["fields"] = {
                {
                    ["name"] = "📊 Executor",
                    ["value"] = string.format("`%s`", playerName),
                    ["inline"] = true
                },
                {
                    ["name"] = "⏰ Time",
                    ["value"] = string.format("<t:%d:R>", os.time()),
                    ["inline"] = true
                }
            },
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S"),
            ["footer"] = {
                ["text"] = "Auto Trade System • v2.0.0"
            }
        }}
    }
    
    local success, err = pcall(function()
        local response = request({
            Url = config.Webhook,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(embed)
        })
    end)
    
    if not success then
        warn("Webhook error:", err)
    end
end

-- Trade API functions
local function first_trade_accept()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
end

local function confirm_trade()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
end

local function send_trade(username)
    local target = Players:FindFirstChild(username)
    if not target then
        warn(string.format("Player %s not found in server!", username))
        return false
    end
    
    local args = {[1] = target}
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/SendTradeRequest"):FireServer(unpack(args))
    return true
end

local function add_items_in_trade(unique)
    local args = {[1] = unique}
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(unpack(args))
end

-- Get pet unique IDs based on config (FIXED NEON DETECTION)
local function get_pet_uniques(maxPets)
    local foundPets = {}
    local playerData = Data.get_data()[playerName]
    
    if not playerData or not playerData.inventory or not playerData.inventory.pets then
        warn("No pet data found in inventory")
        return foundPets
    end
    
    print("\n🔍 Searching for pets...")
    print("Target pets: " .. table.concat(config.pets_to_trade, ", "))
    print("Neon only: " .. tostring(config.Neon))
    print("Max needed: " .. maxPets)
    print("---")
    
    for i, v in pairs(playerData.inventory.pets) do
        for _, petKind in pairs(config.pets_to_trade) do
            if v.kind == petKind then
                local is_neon = v.properties and v.properties.neon
                
                if config.Neon == true then
                    if is_neon then
                        table.insert(foundPets, v.unique)
                        print(string.format("✅ Found NEON %s (Unique: %s)", v.kind, v.unique))
                    else
                        print(string.format("⏭️ Skipped NORMAL %s (not neon)", v.kind))
                    end
                elseif config.Neon == false then
                    if not is_neon then
                        table.insert(foundPets, v.unique)
                        print(string.format("✅ Found NORMAL %s (Unique: %s)", v.kind, v.unique))
                    else
                        print(string.format("⏭️ Skipped NEON %s (neon not wanted)", v.kind))
                    end
                end
                
                if #foundPets >= maxPets then
                    print("---")
                    print(string.format("📊 Total found: %d pets (reached max)", #foundPets))
                    return foundPets
                end
            end
        end
    end
    
    print("---")
    print(string.format("📊 Total found: %d pets matching criteria", #foundPets))
    return foundPets
end

-- Main auto trade function
local function autotrade(username, petCount)
    local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
    
    if #pets_unique_ids > 0 and not tradeGui.Visible then
        trade_status = false
        local success = send_trade(username)
        if not success then
            return false
        end
        print(string.format("📤 Trade request sent to %s", username))
        task.wait(2)
    
    elseif not trade_status and tradeGui.Visible then
        local counter = 0
        local maxSlots = math.min(#pets_unique_ids, 18)
        
        print(string.format("Adding %d pets to trade...", maxSlots))
        
        while #pets_unique_ids > 0 and counter < maxSlots do
            local petUnique = table.remove(pets_unique_ids, 1)
            add_items_in_trade(petUnique)
            counter = counter + 1
            task.wait(0.5)
        end
        
        print(string.format("✅ Added %d pets | Remaining: %d", counter, #pets_unique_ids))
        trade_status = true
        task.wait(1)
    
    elseif trade_status and tradeGui.Visible then
        task.wait(1)
        first_trade_accept()
        print("✅ Trade accepted")
        task.wait(1.5)
        confirm_trade()
        print("✅ Trade confirmed")
        
        local timeout = 0
        repeat
            task.wait(0.5)
            timeout = timeout + 0.5
        until not tradeGui.Visible or timeout > 10
        
        if timeout > 10 then
            warn("Trade timeout - moving to next")
            return false
        end
        
        task.wait(2)
        trade_status = false
    end
    
    return true
end

-- Main execution loop
local totalPetsTraded = 0

if getgenv().ProgressUI then
    getgenv().ProgressUI.SetTitle("🤝 Auto Trade Progress")
    getgenv().ProgressUI.SetStatus("🔄 Initializing...")
end

print(string.format("\n📋 Configuration Loaded:"))
print(string.format("   • Targets: %d", #config.usernames))
print(string.format("   • Pet Type: %s", table.concat(config.pets_to_trade, ", ")))
print(string.format("   • Neon Only: %s", config.Neon and "Yes ✨" or "No"))
print(string.format("   • Webhook: %s\n", config.Webhook ~= "" and "Enabled" or "Disabled"))

for index, username in ipairs(config.usernames) do
    local targetPetCount = tonumber(config.How_many_Pets[index]) or 0
    
    if targetPetCount <= 0 then
        warn(string.format("⚠️ Skipping %s: Invalid pet count", username))
        continue
    end
    
    print(string.format("\n┌────────────────────────────────────┐"))
    print(string.format("│ 📊 Target [%d/%d]: %s", index, #config.usernames, username))
    print(string.format("│ 📦 Required Pets: %d", targetPetCount))
    print(string.format("└────────────────────────────────────┘\n"))
    
    if getgenv().ProgressUI then
        getgenv().ProgressUI.UpdateTarget(username)
        getgenv().ProgressUI.UpdateProgress(index - 1, #config.usernames, totalPetsTraded)
    end
    
    if not Players:FindFirstChild(username) then
        warn(string.format("❌ %s is not in the server!", username))
        sendWebhook(username, 0, "Failed - Not In Server")
        continue
    end
    
    pets_unique_ids = get_pet_uniques(targetPetCount)
    
    if #pets_unique_ids == 0 then
        warn(string.format("❌ No pets found for %s!", username))
        local reason = config.Neon and "No NEON pets found matching criteria" or "No NORMAL pets found matching criteria"
        sendWebhook(username, 0, "Failed - No Pets Found", reason)
        continue
    end
    
    print(string.format("✅ Found %d pets to trade", #pets_unique_ids))
    
    local totalTraded = #pets_unique_ids
    local tradesNeeded = math.ceil(#pets_unique_ids / 18)
    
    print(string.format("🔄 Executing %d trade(s)...\n", tradesNeeded))
    
    for tradeNum = 1, tradesNeeded do
        print(string.format("Trade %d/%d:", tradeNum, tradesNeeded))
        
        local attempts = 0
        local maxAttempts = 50
        
        repeat
            local success = autotrade(username, targetPetCount)
            if not success and attempts > 10 then
                warn("Trade failed after multiple attempts")
                break
            end
            task.wait(1)
            attempts = attempts + 1
        until #pets_unique_ids == 0 or not Players:FindFirstChild(username) or attempts >= maxAttempts
        
        if not Players:FindFirstChild(username) then
            warn(string.format("⚠️ %s left the game!", username))
            sendWebhook(username, totalTraded - #pets_unique_ids, "Incomplete - Player Left")
            break
        end
        
        if attempts >= maxAttempts then
            warn("Max attempts reached")
            sendWebhook(username, totalTraded - #pets_unique_ids, "Failed - Max Attempts")
            break
        end
        
        task.wait(3)
    end
    
    if #pets_unique_ids == 0 then
        print(string.format("\n✅ Successfully traded %d pets with %s", totalTraded, username))
        sendWebhook(username, totalTraded, "Success")
        table.insert(completedTrades, username)
        totalPetsTraded = totalPetsTraded + totalTraded
        
        if getgenv().ProgressUI then
            getgenv().ProgressUI.UpdateProgress(index, #config.usernames, totalPetsTraded)
        end
    end
    
    task.wait(5)
end

print("\n┌────────────────────────────────────┐")
print("│ 🎉 All Trades Completed!           │")
print(string.format("│ ✅ Success: %d/%d targets", #completedTrades, #config.usernames))
print(string.format("│ ✅ Total Pets Traded: %d", totalPetsTraded))
print("└────────────────────────────────────┘\n")

if getgenv().ProgressUI then
    getgenv().ProgressUI.Complete()
end

if config.Webhook ~= "" then
    sendWebhook("All Trades", totalPetsTraded, string.format("Completed %d/%d trades", #completedTrades, #config.usernames))
end

-- Auto-disable account when complete
print("\n🔴 Disabling account...")
disableAccount()

print("\n========================================")
print("✅ SCRIPT COMPLETE & ACCOUNT DISABLED")
print("========================================")
