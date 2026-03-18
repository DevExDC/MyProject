--[[
    SUCCESS Auto-Trade Script v8.0
    Integrated with Harvest Auto-Trade Tool

    SETUP (via getgenv().Config BEFORE running):
    getgenv().Config = {
        usernames            = {"HolderName1", "HolderName2"},
        pets_to_trade        = {"Gumball Caterpillar", "Dog"},  -- use display name OR kind
        NEON_ONLY            = false,   -- only trade neons
        MEGA_ONLY            = false,   -- only trade megas
        FULL_GROWN_ONLY      = false,   -- only trade age 6
        Webhook              = "",
        FARMSYNC_API_KEY     = "your_api_key_here",
        COMPLETION_FOLDER_ID = "your_folder_id_here"
    }
]]

repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService       = game:GetService("HttpService")
local LocalPlayer       = Players.LocalPlayer
local playerName        = LocalPlayer.Name

-- ============== ANTI-AFK ==============
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ============== CONFIG ==============
getgenv().Config = getgenv().Config or {
    usernames            = {},
    pets_to_trade        = {},
    NEON_ONLY            = false,
    MEGA_ONLY            = false,
    FULL_GROWN_ONLY      = false,
    Webhook              = "",
    FARMSYNC_API_KEY     = "",
    COMPLETION_FOLDER_ID = ""
}
local config = getgenv().Config

-- ============== DATA ==============
local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- ============== DEHASH ==============
pcall(function()
    for i, v in pairs(debug.getupvalue(
        require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7
    )) do
        v.Name = i
    end
end)
print("Dehashed remotes")

-- ============== PRINT HEADER ==============
print("===========================================")
print("  SUCCESS Auto-Trade v8.0")
print("  Player: " .. playerName)
print("===========================================")
print("Pets    : " .. #config.pets_to_trade .. " type(s)")
print("Holders : " .. table.concat(config.usernames, ", "))
print("Neon    : " .. tostring(config.NEON_ONLY))
print("Mega    : " .. tostring(config.MEGA_ONLY))
print("FG Only : " .. tostring(config.FULL_GROWN_ONLY))
print("API Key : " .. (config.FARMSYNC_API_KEY ~= "" and "Set" or "NOT SET"))
print("Folder  : " .. (config.COMPLETION_FOLDER_ID ~= "" and config.COMPLETION_FOLDER_ID:sub(1,16).."..." or "NOT SET"))
print("===========================================")

-- ============== RESOLVE ITEM (name or kind → kind) ==============
local function resolveItem(input)
    local db = require(ReplicatedStorage
        :WaitForChild("ClientDB")
        :WaitForChild("Inventory")
        :WaitForChild("KindDB"))
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

    if nameMatch then
        return nameMatch.kind, nameMatch
    end

    return nil, nil
end

-- ============== RESOLVE ALL PET NAMES UPFRONT ==============
print("\nResolving pet names...")
local resolvedKinds = {}
for _, petName in ipairs(config.pets_to_trade) do
    local kind, data = resolveItem(petName)
    if kind then
        table.insert(resolvedKinds, kind)
        print("  " .. petName .. " -> " .. kind)
    else
        warn("  Could not resolve: " .. petName)
    end
end

if #resolvedKinds == 0 then
    warn("No pets resolved! Check your pets_to_trade names.")
end

-- ============== GET PET UNIQUE IDs ==============
local function getPetUniqueIds()
    local ids = {}
    local counts = {}

    pcall(function()
        local pd = Data.get_data()[playerName]
        if not pd or not pd.inventory or not pd.inventory.pets then
            warn("No inventory/pets found!")
            return
        end

        for _, pet in pairs(pd.inventory.pets) do
            for _, kind in ipairs(resolvedKinds) do
                if pet.kind == kind then
                    local props   = pet.properties or {}
                    local is_neon = props.neon or false
                    local is_mega = props.mega_neon or false
                    local age     = props.age or 0

                    local ok = true

                    if config.FULL_GROWN_ONLY and age ~= 6 then ok = false end

                    if ok then
                        if config.MEGA_ONLY then
                            if not is_mega then ok = false end
                        elseif config.NEON_ONLY then
                            if is_mega or not is_neon then ok = false end
                        else
                            if is_neon or is_mega then ok = false end
                        end
                    end

                    if ok then
                        table.insert(ids, pet.unique)
                        counts[kind] = (counts[kind] or 0) + 1
                    end
                    break
                end
            end
        end
    end)

    print(string.format("Pets found: %d", #ids))
    for k, v in pairs(counts) do
        print("  " .. k .. ": " .. v)
    end

    return ids
end

-- ============== TRADE API ==============
local function findPlayer(username)
    local search = username:lower()
    for _, p in pairs(Players:GetPlayers()) do
        if p.Name:lower() == search then return p end
    end
    return nil
end

local function sendTrade(username)
    local target = findPlayer(username)
    if not target then return false end
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/SendTradeRequest"):FireServer(target)
    return true
end

local function addItemToTrade(unique)
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(unique)
end

local function acceptTrade()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
end

local function confirmTrade()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
end

-- ============== WEBHOOK ==============
local function sendWebhook(msg)
    if config.Webhook == "" then return end
    pcall(function()
        request({
            Url     = config.Webhook,
            Method  = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body    = HttpService:JSONEncode({content = msg})
        })
    end)
end

-- ============== COMPLETE ACCOUNT (disable + mark done + move folder) ==============
local function completeAccount()
    if config.FARMSYNC_API_KEY == "" then
        print("No API key — skipping auto-complete")
        return
    end

    local api = config.FARMSYNC_API_KEY
    local base = "https://api.farmsync.cloud/api"

    -- Disable
    print("Disabling account...")
    pcall(function()
        request({
            Url     = base .. "/self/accounts/" .. playerName,
            Method  = "PUT",
            Headers = {
                ["Authorization"] = "Bearer " .. api,
                ["Content-Type"]  = "application/json"
            },
            Body = HttpService:JSONEncode({enabled = false})
        })
    end)

    task.wait(2)

    -- Mark done + move to folder
    if config.COMPLETION_FOLDER_ID ~= "" then
        print("Moving to completion folder...")
        pcall(function()
            local resp = request({
                Url     = base .. "/self/accounts/mark-done",
                Method  = "POST",
                Headers = {
                    ["Authorization"] = "Bearer " .. api,
                    ["Content-Type"]  = "application/json"
                },
                Body = HttpService:JSONEncode({
                    usernames        = {playerName},
                    target_folder_id = config.COMPLETION_FOLDER_ID,
                    source_folder_id = ""
                })
            })
            print("mark-done: " .. tostring(resp.StatusCode) .. " | " .. tostring(resp.Body))
        end)
    end

    print("Account complete!")
end

-- ============== FIND HOLDER ==============
-- Waits until at least one holder joins the server
local function waitForHolder()
    while true do
        for _, name in ipairs(config.usernames) do
            if findPlayer(name) then
                print("Holder found: " .. name)
                return name
            end
        end
        print("Waiting for holder... (" .. table.concat(config.usernames, ", ") .. ")")
        task.wait(5)
    end
end

-- ============== SINGLE TRADE ==============
local function doTrade(holder, petIds)
    local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame

    -- Send trade request, retry until GUI opens
    local timeout = 0
    sendTrade(holder)
    print("Trade request sent to " .. holder)

    while not tradeGui.Visible do
        task.wait(0.5)
        timeout = timeout + 0.5

        if not findPlayer(holder) then
            warn(holder .. " disconnected — waiting for them to rejoin...")
            sendWebhook("⚠️ " .. playerName .. " — Holder " .. holder .. " disconnected, waiting...")
            -- Wait until holder rejoins
            while not findPlayer(holder) do
                task.wait(5)
                print("Still waiting for " .. holder .. "...")
            end
            print(holder .. " rejoined! Resending trade request...")
            sendWebhook("✅ " .. playerName .. " — Holder " .. holder .. " rejoined, resuming trades!")
            task.wait(2)
            sendTrade(holder)
            timeout = 0
        elseif timeout >= 10 then
            print("Retrying trade request to " .. holder .. "...")
            sendTrade(holder)
            timeout = 0
        end
    end

    print("Trade window opened!")
    task.wait(1)

    -- Add up to 18 items
    local added = 0
    for _, uid in ipairs(petIds) do
        if added >= 18 then break end
        addItemToTrade(uid)
        added = added + 1
        task.wait(0.3)
    end
    print(string.format("Added %d items", added))

    task.wait(2)

    -- Spam accept + confirm until trade closes
    local running = true
    task.spawn(function()
        while running do
            pcall(acceptTrade)
            task.wait(0.5)
        end
    end)
    task.wait(1)
    task.spawn(function()
        while running do
            pcall(confirmTrade)
            task.wait(0.5)
        end
    end)

    -- Wait for trade to close
    local wait_timeout = 0
    while tradeGui.Visible and wait_timeout < 30 do
        task.wait(0.5)
        wait_timeout = wait_timeout + 0.5
    end

    running = false
    task.wait(1)

    return true
end

-- ============== MAIN ==============
print("\nWaiting for holder to join...")
local holder = waitForHolder()

-- Get all pet IDs
local allIds = getPetUniqueIds()

if #allIds == 0 then
    warn("No pets to trade!")
    sendWebhook("❌ " .. playerName .. " — No pets to trade")
    completeAccount()
    return
end

print(string.format("\nStarting trades — %d pets to %s", #allIds, holder))
local initCount = #allIds
local totalTraded = 0

while #allIds > 0 do
    -- If holder left between trades, wait for rejoin
    if not findPlayer(holder) then
        warn(holder .. " left between trades — waiting for rejoin...")
        sendWebhook("⚠️ " .. playerName .. " — Holder left between trades, waiting...")
        while not findPlayer(holder) do
            task.wait(5)
            print("Waiting for " .. holder .. " to rejoin...")
        end
        print(holder .. " rejoined! Continuing...")
        sendWebhook("✅ " .. playerName .. " — Holder rejoined, continuing trades!")
        task.wait(2)
    end

    -- Take next batch of 18
    local batch = {}
    for i = 1, math.min(18, #allIds) do
        table.insert(batch, allIds[i])
    end

    local countBefore = #allIds
    local ok = doTrade(holder, batch)

    if ok then
        -- Refresh list and check how many were actually traded
        task.wait(1)
        local newIds = getPetUniqueIds()
        local traded = countBefore - #newIds
        totalTraded = totalTraded + traded
        allIds = newIds
        print(string.format("Traded %d | Total: %d/%d | Remaining: %d",
            traded, totalTraded, initCount, #allIds))
        task.wait(2)
    else
        task.wait(5)
    end
end

-- Summary
print("\n==========================================")
print("  Trading Complete!")
print(string.format("  Traded: %d / %d pets to %s", totalTraded, initCount, holder))
print("==========================================")

sendWebhook(string.format("✅ %s — Done! Traded %d/%d pets to %s",
    playerName, totalTraded, initCount, holder))

task.wait(2)
completeAccount()

print("\nSCRIPT COMPLETE")
