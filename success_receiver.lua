--[[
    HARVEST SENDER v3
    Auto-trades all specified pets to main account then disables itself
    Based on autoTradeALL.lua
    
    CONFIG (set BEFORE running):
    getgenv().Config = {
        farmsync_api_key = "your_key_here",
        username         = "YourMainAccount",
        pet_names        = {"Corgi", "Robot", "Swordfish"},  -- auto-detects category
        webhook          = "",  -- optional, leave "" to disable
    }
]]

repeat wait() until game:IsLoaded()

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local request     = (syn and syn.request) or (http and http.request) or http_request

-- ============================================
-- CONFIG
-- ============================================

local CONFIG = getgenv().Config
if not CONFIG then
    error("No config! Set getgenv().Config before running.")
end

local FARMSYNC_API_KEY = CONFIG.farmsync_api_key or ""
local USERNAME         = CONFIG.username          or ""
local PET_NAMES        = CONFIG.pet_names         or (CONFIG.pet_name and {CONFIG.pet_name}) or {}
local WEBHOOK_URL      = CONFIG.webhook           or ""

if USERNAME == "" then error("No username set in config!") end
if #PET_NAMES == 0 then error("No pet_names set in config!") end

-- ============================================
-- SETUP
-- ============================================

repeat task.wait(1) until RS:FindFirstChild("ClientModules")
task.wait(2)

local LocalPlayer = Players.LocalPlayer
local playerName  = LocalPlayer.Name

-- Anti-AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ============================================
-- DEHASH REMOTES (fixed: scans all upvalues)
-- ============================================

local function dehash()
    local router = require(RS.ClientModules.Core.RouterClient.RouterClient)
    local fn = router.init

    for i = 1, 30 do
        local ok, val = pcall(debug.getupvalue, fn, i)
        if ok and type(val) == "table" then
            local hasRemotes = false
            for _, v in pairs(val) do
                if typeof(v) == "Instance" and (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) then
                    hasRemotes = true
                    break
                end
            end
            if hasRemotes then
                for name, remote in pairs(val) do
                    pcall(function() remote.Name = name end)
                end
                print("[Dehash] Success at upvalue index " .. i)
                return
            end
        end
    end

    warn("[Dehash] Failed — no remote table found in upvalues")
end

dehash()
task.wait(1)

local Data = require(RS.ClientModules.Core.ClientData)

-- ============================================
-- UTILITIES
-- ============================================

local function log(msg)
    print(string.format("[%s] %s", playerName, msg))
end

local function sendWebhook(msg)
    if WEBHOOK_URL == "" then return end
    pcall(function()
        request({
            Url     = WEBHOOK_URL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({
                content  = string.format("FarmSync | %s : %s", playerName, msg),
                username = "Harvest Sender"
            })
        })
    end)
end

local function disableAccount()
    if FARMSYNC_API_KEY == "" then
        log("No API key - skipping auto-disable")
        return
    end
    local success, response = pcall(function()
        return request({
            Url     = "https://api.farmsync.cloud/api/self/accounts/" .. playerName,
            Method  = "PUT",
            Headers = {
                ["Authorization"] = "Bearer " .. FARMSYNC_API_KEY,
                ["Content-Type"]  = "application/json"
            },
            Body = HttpService:JSONEncode({ enabled = false })
        })
    end)
    if success and response and response.StatusCode and response.StatusCode >= 200 and response.StatusCode < 300 then
        log("Account disabled via FarmSync!")
        sendWebhook("Account disabled successfully.")
    else
        local err = response and response.StatusCode or "unknown"
        warn("Failed to disable account: " .. tostring(err))
        sendWebhook("Failed to disable account (" .. tostring(err) .. ")")
    end
end

-- ============================================
-- ITEM RESOLVER (auto-detects category from KindDB)
-- ============================================

local function resolveItem(input)
    local db = require(RS:WaitForChild("ClientDB"):WaitForChild("Inventory"):WaitForChild("KindDB"))
    local search = input:lower()
    local nameMatch = nil

    for _, v in pairs(db) do
        if v.kind and v.kind:lower() == search then
            return v.kind, v
        end
        if not nameMatch and v.name and v.name:lower() == search then
            nameMatch = v
        end
    end

    if nameMatch then return nameMatch.kind, nameMatch end
    warn("Item not found: " .. input)
    return nil, nil
end

-- ============================================
-- RESOLVE ALL PET NAMES UPFRONT
-- ============================================

log("================================")
log("HARVEST SENDER v3")
log("Account  : " .. playerName)
log("Main acc : " .. USERNAME)
log("Pets     : " .. table.concat(PET_NAMES, ", "))
log("================================")

local resolvedPets = {}  -- { kind, category }

for _, petName in ipairs(PET_NAMES) do
    log("Resolving: " .. petName)
    local kind, data = resolveItem(petName)
    if kind and data then
        local cat = data.category or "pets"
        table.insert(resolvedPets, { name = petName, kind = kind, category = cat })
        log(string.format("  OK: %s -> kind=%s category=%s", petName, kind, cat))
    else
        log("  FAILED: Could not resolve " .. petName .. " - skipping!")
        sendWebhook("Could not resolve pet: " .. petName)
    end
end

if #resolvedPets == 0 then
    warn("No pets could be resolved!")
    disableAccount()
    return
end

-- ============================================
-- GET ALL ITEM UNIQUE IDs (across all pet names)
-- ============================================

local items_unique_ids = {}

local function refreshItems()
    items_unique_ids = {}
    local playerData = Data.get_data()[playerName]
    if not playerData or not playerData.inventory then
        warn("No player data found!")
        return
    end
    for _, pet in ipairs(resolvedPets) do
        local inv = playerData.inventory[pet.category]
        if not inv then continue end
        for _, item in pairs(inv) do
            if item.kind == pet.kind then
                table.insert(items_unique_ids, item.unique)
            end
        end
    end
    log("Items in inventory: " .. #items_unique_ids)
end

-- ============================================
-- TRADE FUNCTIONS
-- ============================================

local function send_trade(username)
    local args = { [1] = Players:WaitForChild(username) }
    RS:WaitForChild("API"):WaitForChild("TradeAPI/SendTradeRequest"):FireServer(unpack(args))
end

local function add_items_in_trade(unique)
    RS:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(unique)
end

local function first_trade_accept()
    RS:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
end

local function confirm_trade()
    RS:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
end

local function tradeGuiVisible()
    local gui = LocalPlayer.PlayerGui:FindFirstChild("TradeApp")
    return gui and gui.Frame and gui.Frame.Visible
end

-- ============================================
-- WAIT FOR TARGET PLAYER
-- ============================================

log("Waiting for '" .. USERNAME .. "' in server...")
while not Players:FindFirstChild(USERNAME) do
    task.wait(5)
end
log("Found '" .. USERNAME .. "'!")
sendWebhook("Harvest Sender started | Pets: " .. table.concat(PET_NAMES, ", "))

-- ============================================
-- MAIN TRADE LOOP
-- ============================================

local trade_status = false
local tradeCount   = 0

refreshItems()

local function autotrade()
    if #items_unique_ids > 0 and not tradeGuiVisible() then
        trade_status = false
        send_trade(USERNAME)
        log("Trade request sent to " .. USERNAME)
        sendWebhook("Trade request sent to " .. USERNAME)

    elseif not trade_status and tradeGuiVisible() then
        local counter = 0
        while #items_unique_ids > 0 and counter < 18 do
            local unique = table.remove(items_unique_ids, 1)
            add_items_in_trade(unique)
            log("Added item to trade")
            counter = counter + 1
            task.wait(0.5)
        end
        log("Items left in queue: " .. #items_unique_ids)
        trade_status = true

    elseif trade_status and tradeGuiVisible() then
        repeat
            task.wait(1)
            first_trade_accept()
            log("Accepted!")
            task.wait(1)
            confirm_trade()
            log("Confirmed!")
        until not tradeGuiVisible()

        tradeCount = tradeCount + 1
        log("Trade #" .. tradeCount .. " completed!")
        sendWebhook("Trade #" .. tradeCount .. " completed!")

    else
        log("Waiting...")
    end
end

repeat
    autotrade()
    refreshItems()
    task.wait(1)
until #items_unique_ids == 0

-- ============================================
-- DONE
-- ============================================

log("================================")
log("ALL DONE! " .. tradeCount .. " trades completed.")
log("Disabling account via FarmSync...")
log("================================")

sendWebhook("All trades done! " .. tradeCount .. " trades completed. Disabling account now.")

disableAccount()

-- Safety loop to keep accepting any leftover trades
while true do
    task.wait(1)
    pcall(function()
        first_trade_accept()
        confirm_trade()
    end)
    task.wait(5)
end
