--[[
    SUCCESS Auto-Trade Script - PETS + PET WEARS + GIFTS
    v7.0.0 - Integrated with Harvest Auto-Trade Tool
    
    HOW IT WORKS WITH THE PYTHON TOOL:
    - Python tool sets this config on the account and enables it
    - Script runs, finds holder, trades all items
    - When done, script calls disableAccount() → tool detects disabled → marks done + moves to folder
    - Tool then pulls next account from queue automatically
    
    SETUP (via getgenv().Config BEFORE running):
    getgenv().Config = {
        usernames = {"HolderName1", "HolderName2"},   -- holder account(s) in server
        pets_to_trade = {"Pet Kind Name"},             -- pet kinds to trade
        Webhook = "",                                  -- discord webhook (optional)
        FARMSYNC_API_KEY = "your_api_key_here"        -- REQUIRED for auto-disable signal
    }
]]

repeat task.wait() until game:IsLoaded()

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService      = game:GetService("HttpService")
local LocalPlayer      = Players.LocalPlayer
local playerName       = LocalPlayer.Name

-- ============== ANTI-AFK ==============
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ============== CONFIG ==============
getgenv().Config = getgenv().Config or {
    usernames            = {},
    pets_to_trade        = {},
    Webhook              = "",
    FARMSYNC_API_KEY     = ""
}

local config = getgenv().Config

-- ============== DATA ==============
local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- ============== STATE ==============
local pets_unique_ids      = {}
local trade_status         = false

-- ============== PRINT HEADER ==============
print("===========================================")
print("  SUCCESS Auto-Trade v7.0 (Tool Integrated)")
print("  Player: " .. playerName)
print("===========================================")
print("Pets    : " .. tostring(#config.pets_to_trade) .. " type(s)")
print("Holders : " .. table.concat(config.usernames, ", "))
print("API Key : " .. (config.FARMSYNC_API_KEY ~= "" and "Set" or "NOT SET"))
print("===========================================")

-- ============== DEHASH ==============
local function dehash()
    local function rename(remotename, hashedremote)
        hashedremote.Name = remotename
    end
    pcall(function()
        table.foreach(
            getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7),
            rename
        )
    end)
    print("✅ Dehashed remotes")
end
dehash()

-- ============== WEBHOOK ==============
local function sendWebhook(message)
    if config.Webhook == "" then return end
    pcall(function()
        request({
            Url     = config.Webhook,
            Method  = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body    = HttpService:JSONEncode({["content"] = message})
        })
    end)
end

-- ============== DISABLE ACCOUNT (signals tool that trading is done) ==============
local function disableAccount()
    if config.FARMSYNC_API_KEY == "" then
        print("⚠️ No API key set — tool won't detect completion automatically")
        return
    end
    print("🔴 Signaling tool: trading complete (disabling account)...")
    pcall(function()
        request({
            Url    = "https://api.farmsync.cloud/api/self/accounts/" .. playerName,
            Method = "PUT",
            Headers = {
                ["Authorization"] = "Bearer " .. config.FARMSYNC_API_KEY,
                ["Content-Type"]  = "application/json"
            },
            Body = HttpService:JSONEncode({enabled = false})
        })
        print("✅ Disabled! Tool will now mark done and move to completion folder.")
    end)
end

-- ============== TRADE API HELPERS ==============
local function send_trade(username)
    local target = Players:FindFirstChild(username)
    if not target then
        warn("Player " .. username .. " not found!")
        return false
    end
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/SendTradeRequest"):FireServer(target)
    return true
end

local function add_item_to_trade(unique_id)
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(unique_id)
end

local function first_trade_accept()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
end

local function confirm_trade()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
end

-- ============== AUTO-ACCEPT SYSTEMS ==============
local function setup_auto_accept()
    task.spawn(function()
        local dialogApp = LocalPlayer.PlayerGui:FindFirstChild("DialogApp")
        while task.wait(0.3) do
            pcall(function()
                if dialogApp and dialogApp:FindFirstChild("Dialog") and dialogApp.Dialog.Visible then
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Name ~= playerName then
                            ReplicatedStorage:WaitForChild("API")
                                :WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest")
                                :InvokeServer(player, true)
                        end
                    end
                end
            end)
        end
    end)
end

local function setup_auto_negotiate()
    task.spawn(function()
        while task.wait(0.5) do
            pcall(function()
                local tradeGui = LocalPlayer.PlayerGui:FindFirstChild("TradeApp")
                if tradeGui and tradeGui.Frame.Visible then
                    first_trade_accept()
                end
            end)
        end
    end)
end

local function setup_auto_confirm()
    task.spawn(function()
        while task.wait(0.5) do
            pcall(function()
                local tradeGui = LocalPlayer.PlayerGui:FindFirstChild("TradeApp")
                if tradeGui and tradeGui.Frame.Visible then
                    confirm_trade()
                end
            end)
        end
    end)
end

-- ============== INVENTORY READERS ==============

local function get_all_pets()
    local all_pets  = {}
    local counts    = {}
    local total_inv = 0
    for _, kind in ipairs(config.pets_to_trade) do counts[kind] = 0 end
    pcall(function()
        local pd = Data.get_data()[playerName]
        if not pd or not pd.inventory or not pd.inventory.pets then return end
        for _, pet in pairs(pd.inventory.pets) do
            total_inv = total_inv + 1
            for _, kind in ipairs(config.pets_to_trade) do
                if pet.kind == kind then
                    table.insert(all_pets, pet.unique)
                    counts[kind] = counts[kind] + 1
                    break
                end
            end
        end
    end)
    print(string.format("🐾 Pets  — Inventory: %d | Matching: %d", total_inv, #all_pets))
    for kind, cnt in pairs(counts) do
        if cnt > 0 then print("   • " .. kind .. ": " .. cnt) end
    end
    return all_pets, total_inv
end

-- Count helpers (post-trade verification)
local function count_pets()
    local c = 0
    pcall(function()
        local pd = Data.get_data()[playerName]
        if not pd or not pd.inventory or not pd.inventory.pets then return end
        for _, pet in pairs(pd.inventory.pets) do
            for _, kind in ipairs(config.pets_to_trade) do
                if pet.kind == kind then c = c + 1; break end
            end
        end
    end)
    return c
end

-- ============== SINGLE TRADE ATTEMPT ==============
local function autotrade(username)
    if trade_status then return false end
    if #pets_unique_ids == 0 then
        return true  -- nothing left, we're done
    end

    local success_flag = false

    pcall(function()
        trade_status = true

        local holder = Players:FindFirstChild(username)
        if not holder then
            warn("❌ " .. username .. " is not in the server!")
            trade_status = false
            return
        end

        local pets_before = count_pets()
        print(string.format("📦 Before — Pets: %d", pets_before))

        local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame

        if not send_trade(username) then
            print("❌ Failed to send trade request")
            trade_status = false
            return
        end

        print("📤 Trade request sent to " .. username)
        task.wait(3)

        -- Wait for trade window
        local timeout = 0
        while not tradeGui.Visible and timeout < 20 do
            if not Players:FindFirstChild(username) then
                warn("❌ " .. username .. " left while waiting!")
                trade_status = false
                return
            end
            task.wait(0.5)
            timeout = timeout + 0.5
        end

        if timeout >= 20 then
            warn("⚠️ Trade window didn't open after 20s")
            trade_status = false
            return
        end

        task.wait(1)

        -- Add pets (max 18)
        local added = 0
        for _, uid in ipairs(pets_unique_ids) do
            if added >= 18 then break end
            add_item_to_trade(uid); added = added + 1; task.wait(0.3)
        end

        print(string.format("✅ Added %d item(s) to trade", added))
        task.wait(2)

        -- Wait countdown + accept
        print("Waiting 6s countdown...")
        task.wait(6)
        print("Accepting...")
        first_trade_accept()
        task.wait(1)
        confirm_trade()

        -- Wait for trade to close
        timeout = 0
        while tradeGui.Visible and timeout < 30 do
            task.wait(0.5); timeout = timeout + 0.5
        end
        task.wait(2)

        -- Verify
        local pets_after  = count_pets()
        local pets_traded = pets_before - pets_after

        print(string.format("✅ Traded — Pets: %d", pets_traded))

        if pets_traded > 0 then
            for i = 1, pets_traded do table.remove(pets_unique_ids, 1) end
            print(string.format("📋 Remaining — Pets: %d", #pets_unique_ids))
            success_flag = true
        else
            warn("⚠️ No items traded — refreshing list...")
            pets_unique_ids, _ = get_all_pets()
        end

        trade_status = false
    end)

    return success_flag
end

-- ============== FIND HOLDER ==============
local function find_holder()
    for _, name in ipairs(config.usernames) do
        if Players:FindFirstChild(name) then
            print("✅ Holder found: " .. name)
            return name
        else
            print("⚠️  " .. name .. " not in game")
        end
    end
    return nil
end

-- ============== MAIN ==============

-- Start auto-systems
setup_auto_accept()
setup_auto_negotiate()
setup_auto_confirm()
print("✅ Auto-accept/confirm systems running\n")

-- Find holder
print("🔍 Looking for holder...")
local holder = find_holder()

if not holder then
    local tried = table.concat(config.usernames, ", ")
    warn("❌ No holders in server! Tried: " .. tried)
    sendWebhook("❌ " .. playerName .. " — No holders in server (" .. tried .. ")")
    disableAccount()
    return
end

-- Get all items
pets_unique_ids, _ = get_all_pets()

local total_items = #pets_unique_ids

if total_items == 0 then
    warn("❌ No items to trade! Disabling...")
    sendWebhook("❌ " .. playerName .. " — Nothing to trade, disabling")
    disableAccount()
    return
end

print(string.format("\n✅ Total pets to trade: %d", total_items))

local init_pets = #pets_unique_ids

-- Trade loop
local attempts     = 0
local max_attempts = math.ceil(total_items / 18) + 10
local consec_fails = 0
local max_fails    = 3

while #pets_unique_ids > 0 and attempts < max_attempts do

    attempts = attempts + 1
    print("\n=== Trade Attempt " .. attempts .. " ===")

    if not Players:FindFirstChild(holder) then
        warn("❌ " .. holder .. " left the game!")
        sendWebhook("❌ " .. playerName .. " — Holder left mid-session")
        break
    end

    local ok = autotrade(holder)

    if not ok then
        consec_fails = consec_fails + 1
        if consec_fails >= max_fails then
            warn("⚠️ " .. max_fails .. " consecutive failures — waiting 10s...")
            task.wait(10)
            consec_fails = 0
        else
            task.wait(5)
        end
    else
        consec_fails = 0
        task.wait(3)
    end
end

-- Summary
local pets_done = init_pets - #pets_unique_ids

print("\n+----------------------------------------+")
print("|  Trading Session Complete!             |")
print("|  Holder : " .. holder)
print(string.format("|  Pets   : %d / %d traded", pets_done, init_pets))
print("+----------------------------------------+")

sendWebhook(string.format(
    "✅ **%s** — Trading done\nPets: %d / %d → **%s**",
    playerName, pets_done, init_pets, holder))

-- Disable to signal the Python tool
print("\n🔴 All done — signaling tool to mark complete...")
task.wait(2)
disableAccount()

print("\n========================================")
print("✅ SCRIPT COMPLETE — Tool will handle the rest")
print("========================================")
