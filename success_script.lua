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
    Webhook              = "",
    FARMSYNC_API_KEY     = "",   -- required for auto-disable signal to tool
    COMPLETION_FOLDER_ID = ""    -- folder to move account when done trading
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
                    -- Trade ALL versions (normal, neon, mega)
                    table.insert(ids, pet.unique)
                    counts[kind] = (counts[kind] or 0) + 1
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
    local args = { [1] = target }
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/SendTradeRequest"):FireServer(unpack(args))
    return true
end

local function addItemToTrade(unique)
    local args = { [1] = unique }
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(unpack(args))
end

local function acceptTrade()
    game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
end

local function confirmTrade()
    game:GetService("ReplicatedStorage"):WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
end

-- ============== WEBHOOK ==============
local function sendWebhook(msg)
    if not config.Webhook or config.Webhook == "" then return end
    pcall(function()
        local hs = game:GetService("HttpService")
        request({
            Url     = config.Webhook,
            Method  = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body    = hs:JSONEncode({content = msg})
        })
    end)
end

-- ============== COMPLETE ACCOUNT ==============
-- Step 1: Move to completion folder via mark-done API
-- Step 2: Disable so the tool detects it and pulls next account
local function completeAccount()
    local api            = config.FARMSYNC_API_KEY or ""
    local completeFolder = config.COMPLETION_FOLDER_ID or ""
    local hs             = game:GetService("HttpService")

    if api == "" then
        print("No API key set — skipping completion")
        return
    end

    -- Step 1: Move to completion folder
    if completeFolder ~= "" then
        print("Step 1: Moving to completion folder...")
        pcall(function()
            local resp = request({
                Url     = "https://api.farmsync.cloud/api/self/accounts/mark-done",
                Method  = "POST",
                Headers = {
                    ["Authorization"] = "Bearer " .. api,
                    ["Content-Type"]  = "application/json"
                },
                Body = hs:JSONEncode({
                    usernames        = {playerName},
                    target_folder_id = completeFolder
                })
            })
            print("  mark-done: " .. tostring(resp.StatusCode) .. " | " .. tostring(resp.Body))
        end)
        task.wait(2)
    end

    -- Step 2: Disable to signal the tool
    print("Step 2: Disabling account...")
    pcall(function()
        local resp = request({
            Url     = "https://api.farmsync.cloud/api/self/accounts/" .. playerName,
            Method  = "PUT",
            Headers = {
                ["Authorization"] = "Bearer " .. api,
                ["Content-Type"]  = "application/json"
            },
            Body = hs:JSONEncode({enabled = false})
        })
        print("  disabled: " .. tostring(resp.StatusCode))
    end)

    print("Done!")
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
