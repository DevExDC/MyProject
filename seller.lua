--[[
    WARD TERMINAL - SELLER DISPATCH SCRIPT
    Runs on the account sitting in the private server.
    Reports who's in the server, polls the backend for orders
    created from the dashboard, and executes them automatically.

    CONFIG (set BEFORE running):
    getgenv().DispatchConfig = {
        BACKEND_URL      = "http://localhost:3000",  -- your PC's backend
        API_KEY          = "my-secret-key-123",       -- must match SCRIPT_API_KEY on the server
        REPORT_INTERVAL  = 5,   -- seconds between player-list updates
        POLL_INTERVAL    = 3,   -- seconds between order checks
        TRADE_TIMEOUT    = 90,  -- seconds to wait for target to accept before giving up
        WEBHOOK_URL      = "", -- optional, leave "" to disable
    }
]]

repeat wait() until game:IsLoaded()

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local RS          = game:GetService("ReplicatedStorage")
local request     = (syn and syn.request) or (http and http.request) or http_request

if not request then
    error("❌ No HTTP request function available in this executor!")
end

-- ============================================
-- CONFIG
-- ============================================

local CONFIG = getgenv().DispatchConfig
if not CONFIG then
    error("❌ No config! Set getgenv().DispatchConfig before running.")
end

local BACKEND_URL     = (CONFIG.BACKEND_URL or "http://localhost:3000"):gsub("/$", "")
local API_KEY         = CONFIG.API_KEY or ""
local REPORT_INTERVAL = CONFIG.REPORT_INTERVAL or 5
local POLL_INTERVAL   = CONFIG.POLL_INTERVAL or 3
local TRADE_TIMEOUT   = CONFIG.TRADE_TIMEOUT or 90
local WEBHOOK_URL     = CONFIG.WEBHOOK_URL or ""

if API_KEY == "" then
    error("❌ API_KEY is required - must match SCRIPT_API_KEY on your backend!")
end

repeat task.wait(1) until RS:FindFirstChild("ClientModules")
task.wait(2)

local LocalPlayer = Players.LocalPlayer
local playerName  = LocalPlayer.Name

-- Server identity: JobId uniquely identifies this private server instance,
-- so the dashboard automatically shows the right server with zero manual setup.
local SERVER_ID = game.JobId ~= "" and game.JobId or ("studio-" .. tostring(os.time()))

-- Anti-AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
print("✅ Anti-AFK enabled")

-- ============================================
-- DEHASH REMOTES
-- ============================================

local function dehash()
    local router = require(RS.ClientModules.Core.RouterClient.RouterClient)
    if type(router.init) ~= "function" then
        print("Router.init is not a function")
        return
    end
    local targetTable = nil
    for i = 1, 20 do
        local upv = debug.getupvalue(router.init, i)
        if type(upv) == "table" then
            local valid = true
            local count = 0
            for k, v in pairs(upv) do
                count = count + 1
                if typeof(v) ~= "Instance" then
                    valid = false
                    break
                end
            end
            if valid and count > 0 then
                targetTable = upv
                print("Found remotes table at index:", i)
                break
            end
        end
    end
    if not targetTable then
        print("🔴 Remotes table not found")
        return
    end
    for name, remote in pairs(targetTable) do
        pcall(function()
            remote.Name = name
        end)
    end
    print("✅ Dehash done")
end

dehash()
task.wait(1)

local Data = require(RS.ClientModules.Core.ClientData)

-- ============================================
-- LOGGING / WEBHOOK
-- ============================================

local function log(msg)
    print(string.format("[Dispatch] %s", msg))
end

local function sendWebhook(msg)
    if WEBHOOK_URL == "" then return end
    pcall(function()
        request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode({
                content = string.format("Ward Terminal | %s : %s", playerName, msg),
                username = "Ward Terminal"
            })
        })
    end)
end

-- ============================================
-- BACKEND HTTP HELPERS
-- ============================================

local function backendGet(path)
    local ok, response = pcall(function()
        return request({
            Url = BACKEND_URL .. path,
            Method = "GET",
            Headers = { ["X-API-Key"] = API_KEY }
        })
    end)

    if not ok or not response then return nil, "request failed" end
    if response.StatusCode ~= 200 then return nil, "HTTP " .. tostring(response.StatusCode) end

    local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body)
    if not decodeOk then return nil, "bad json" end

    return decoded, nil
end

local function backendPost(path, bodyTable)
    local ok, response = pcall(function()
        return request({
            Url = BACKEND_URL .. path,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["X-API-Key"] = API_KEY
            },
            Body = HttpService:JSONEncode(bodyTable)
        })
    end)

    if not ok or not response then return nil, "request failed" end
    if response.StatusCode < 200 or response.StatusCode >= 300 then
        return nil, "HTTP " .. tostring(response.StatusCode)
    end

    local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body)
    if not decodeOk then return nil, "bad json" end

    return decoded, nil
end

-- ============================================
-- REPORT PLAYERS IN SERVER (excludes self)
-- ============================================

local function reportPlayers()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(list, {
                username = p.Name,
                displayName = p.DisplayName,
                userId = p.UserId
            })
        end
    end

    local _, err = backendPost("/api/script/players/update", {
        server_id = SERVER_ID,
        seller_username = playerName,
        players = list
    })

    if err then
        log("⚠️ Failed to report players: " .. err)
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
    return nil, nil
end

-- ============================================
-- INVENTORY CATEGORIES + KIND->NAME LOOKUP
-- ============================================

local INVENTORY_CATEGORIES = { "pets", "vehicles", "toys", "food", "gifts", "eggs" }

-- Build kind -> {name, category} once from KindDB so we can label counts nicely
local kindInfo = {}

local function buildKindInfo()
    local ok, db = pcall(function()
        return require(RS:WaitForChild("ClientDB"):WaitForChild("Inventory"):WaitForChild("KindDB"))
    end)
    if not ok then
        log("⚠️ Could not load KindDB for inventory labeling")
        return
    end
    for _, v in pairs(db) do
        if v.kind then
            kindInfo[v.kind] = { name = v.name or v.kind, category = v.category or "pets" }
        end
    end
end

buildKindInfo()

-- ============================================
-- BUILD + REPORT CURRENT INVENTORY (counts per kind)
-- ============================================

local function reportInventory()
    local playerData = Data.get_data()[playerName]
    if not playerData or not playerData.inventory then return end

    local counts = {} -- kind -> count

    for _, category in ipairs(INVENTORY_CATEGORIES) do
        local inv = playerData.inventory[category]
        if inv then
            for _, item in pairs(inv) do
                if item.kind then
                    counts[item.kind] = (counts[item.kind] or 0) + 1
                end
            end
        end
    end

    local items = {}
    for kind, count in pairs(counts) do
        local info = kindInfo[kind] or { name = kind, category = "pets" }
        table.insert(items, {
            category = info.category,
            kind = kind,
            name = info.name,
            count = count
        })
    end

    local _, err = backendPost("/api/script/inventory/update", {
        server_id = SERVER_ID,
        seller_username = playerName,
        items = items
    })

    if err then
        log("⚠️ Failed to report inventory: " .. err)
    end
end

-- ============================================
-- GET MATCHING ITEM UNIQUES FOR AN ORDER
-- ============================================

local function getOrderItems(kind, category, amount, tradeAll)
    local items = {}
    local playerData = Data.get_data()[playerName]
    if not playerData or not playerData.inventory then return items end

    local inv = playerData.inventory[category]
    if not inv then return items end

    for _, item in pairs(inv) do
        if item.kind == kind then
            table.insert(items, item.unique)
            if not tradeAll and amount and #items >= amount then
                break
            end
        end
    end

    return items
end

-- ============================================
-- TRADE FUNCTIONS (same remotes as Harvest Sender)
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
-- EXECUTE ONE ORDER (blocking, one order at a time)
-- ============================================

local function executeOrder(order)
    log(string.format("▶️ Executing order #%s -> %s", tostring(order.id), order.target_username))

    -- 1. Target must still be in the server
    local targetPlayer = Players:FindFirstChild(order.target_username)
    if not targetPlayer then
        return false, "Target left the server before trade could start"
    end

    -- 2. Resolve the item name into kind + category
    local petName = order.pet_name
    if not petName then
        return false, "Order has no item specified"
    end

    local kind, data = resolveItem(petName)
    if not kind then
        return false, "Could not resolve item: " .. tostring(petName)
    end

    local category = (order.category and order.category ~= "") and order.category or (data.category or "pets")

    -- 3. Gather matching item uniques
    local tradeAll = (order.trade_all == 1 or order.trade_all == true)
    local amount = order.amount

    local queue = getOrderItems(kind, category, amount, tradeAll)

    if #queue == 0 then
        return false, string.format("No %s found in inventory (category: %s)", petName, category)
    end

    log(string.format("📦 Found %d x %s to send", #queue, petName))

    local totalToSend = #queue
    local sentTotal = 0
    local roundsNeeded = math.ceil(totalToSend / 18) -- Adopt Me trade slot limit

    for round = 1, roundsNeeded do
        -- Send / wait for trade window
        local waited = 0
        local tradeOpen = false

        send_trade(order.target_username)
        log(string.format("📤 Trade request sent (round %d/%d)", round, roundsNeeded))

        while waited < TRADE_TIMEOUT do
            if tradeGuiVisible() then
                tradeOpen = true
                break
            end
            task.wait(1)
            waited = waited + 1
        end

        if not tradeOpen then
            return false, string.format("Target did not accept trade window (round %d) within %ds", round, TRADE_TIMEOUT)
        end

        -- Add items for this round (up to 18)
        local addedThisRound = 0
        while #queue > 0 and addedThisRound < 18 do
            local unique = table.remove(queue, 1)
            add_items_in_trade(unique)
            addedThisRound = addedThisRound + 1
            sentTotal = sentTotal + 1
            task.wait(0.5)
        end

        log(string.format("➕ Added %d items this round", addedThisRound))

        -- Accept + confirm loop until trade window closes
        local closeWaited = 0
        repeat
            task.wait(1)
            first_trade_accept()
            task.wait(1)
            confirm_trade()
            closeWaited = closeWaited + 2
        until not tradeGuiVisible() or closeWaited > TRADE_TIMEOUT

        if tradeGuiVisible() then
            return false, string.format("Trade window did not close after confirming (round %d)", round)
        end

        log(string.format("✅ Round %d/%d complete (%d/%d sent)", round, roundsNeeded, sentTotal, totalToSend))
        task.wait(2)
    end

    local resultMsg = tradeAll
        and string.format("Sent all %d x %s", sentTotal, petName)
        or string.format("Sent %d x %s", sentTotal, petName)

    return true, resultMsg
end

-- ============================================
-- ORDER POLL LOOP
-- ============================================

local function pollAndExecute()
    local data, err = backendGet(string.format(
        "/api/script/orders/next?server_id=%s&seller_username=%s",
        HttpService:UrlEncode(SERVER_ID),
        HttpService:UrlEncode(playerName)
    ))

    if err then
        log("⚠️ Order poll failed: " .. err)
        return
    end

    if not data or not data.order then
        return -- nothing pending
    end

    local order = data.order
    sendWebhook(string.format("Order #%s claimed - dispatching %s to %s",
        tostring(order.id), tostring(order.pet_name), tostring(order.target_username)))

    local okCall, r1, r2 = pcall(executeOrder, order)

    if okCall then
        if r1 then
            log("✅ Order #" .. tostring(order.id) .. " completed: " .. tostring(r2))
            backendPost("/api/script/orders/" .. tostring(order.id) .. "/report", {
                status = "completed",
                result_message = r2
            })
            sendWebhook(string.format("✅ Order #%s completed - %s", tostring(order.id), tostring(r2)))
        else
            log("❌ Order #" .. tostring(order.id) .. " failed: " .. tostring(r2))
            backendPost("/api/script/orders/" .. tostring(order.id) .. "/report", {
                status = "failed",
                result_message = r2
            })
            sendWebhook(string.format("❌ Order #%s failed - %s", tostring(order.id), tostring(r2)))
        end
    else
        log("❌ Order #" .. tostring(order.id) .. " crashed: " .. tostring(r1))
        backendPost("/api/script/orders/" .. tostring(order.id) .. "/report", {
            status = "failed",
            result_message = "Script error: " .. tostring(r1)
        })
        sendWebhook(string.format("❌ Order #%s crashed - %s", tostring(order.id), tostring(r1)))
    end
end

-- ============================================
-- HEADER
-- ============================================

log("================================")
log("WARD TERMINAL - SELLER DISPATCH")
log("Account   : " .. playerName)
log("Server ID : " .. SERVER_ID)
log("Backend   : " .. BACKEND_URL)
log("================================")

sendWebhook("Dispatch script online. Server ID: " .. SERVER_ID)

-- ============================================
-- MAIN LOOPS
-- ============================================

-- Report players on its own timer
spawn(function()
    while true do
        pcall(reportPlayers)
        pcall(reportInventory)
        task.wait(REPORT_INTERVAL)
    end
end)

-- Poll for orders on its own timer (sequential - one order at a time)
while true do
    pcall(pollAndExecute)
    task.wait(POLL_INTERVAL)
end
