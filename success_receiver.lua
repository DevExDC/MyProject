--[[
    HARVEST SENDER v3
    Auto-trades all specified pets to main account then disables itself
    Based on autoTradeALL.lua
    
    CONFIG (set BEFORE running):
    getgenv().Config = {
        farmsync_api_key = "your_key_here",
        username         = "YourMainAccount",
        pet_names        = {"Corgi", "Robot", "Swordfish"},  -- auto-detects category
        neon_only        = false,  -- true = trade neon pets only (excludes megas)
        mega_only        = false,  -- true = trade mega neon pets only
        full_grown_only  = false,  -- true = age 6 pets only
        webhook          = "",     -- optional, leave "" to disable
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
local NEON_ONLY        = CONFIG.neon_only         or false
local MEGA_ONLY        = CONFIG.mega_only         or false
local FULL_GROWN_ONLY  = CONFIG.full_grown_only   or false

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

local Data         = require(RS.ClientModules.Core.ClientData)
local TweenService = game:GetService("TweenService")
local CoreGui      = game:GetService("CoreGui")

-- ============================================
-- PATRICK-THEMED UI
-- ============================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "HarvestUI"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
local _ok = pcall(function() ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
if not _ok then ScreenGui.Parent = CoreGui end

-- Full-screen backdrop
local Backdrop = Instance.new("Frame")
Backdrop.Size                   = UDim2.new(1, 0, 1, 0)
Backdrop.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
Backdrop.BackgroundTransparency = 0.5
Backdrop.BorderSizePixel        = 0
Backdrop.ZIndex                 = 1
Backdrop.Parent                 = ScreenGui

-- Main card
local Card = Instance.new("Frame")
Card.Size             = UDim2.new(0, 480, 0, 430)
Card.Position         = UDim2.new(0.5, -240, 0.5, -215)
Card.BackgroundColor3 = Color3.fromRGB(252, 228, 236)
Card.BorderSizePixel  = 0
Card.ZIndex           = 2
Card.Parent           = ScreenGui
Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 24)
local CardStroke = Instance.new("UIStroke")
CardStroke.Color = Color3.fromRGB(244, 143, 177); CardStroke.Thickness = 3; CardStroke.Parent = Card

-- Sailor blue header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 52); Header.BackgroundColor3 = Color3.fromRGB(21, 101, 192)
Header.BorderSizePixel = 0; Header.ZIndex = 3; Header.Parent = Card
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 24)
local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 24); HeaderFix.Position = UDim2.new(0, 0, 1, -24)
HeaderFix.BackgroundColor3 = Color3.fromRGB(21, 101, 192); HeaderFix.BorderSizePixel = 0
HeaderFix.ZIndex = 3; HeaderFix.Parent = Header

-- Hat icon
local HatCircle = Instance.new("Frame")
HatCircle.Size = UDim2.new(0, 32, 0, 32); HatCircle.Position = UDim2.new(0, 12, 0, 10)
HatCircle.BackgroundColor3 = Color3.fromRGB(13, 71, 161); HatCircle.BorderSizePixel = 0
HatCircle.ZIndex = 4; HatCircle.Parent = Header
Instance.new("UICorner", HatCircle).CornerRadius = UDim.new(1, 0)
local HatStroke = Instance.new("UIStroke")
HatStroke.Color = Color3.fromRGB(144, 202, 249); HatStroke.Thickness = 2; HatStroke.Parent = HatCircle
local HatBrim = Instance.new("Frame")
HatBrim.Size = UDim2.new(0, 18, 0, 10); HatBrim.Position = UDim2.new(0.5, -9, 0.5, -2)
HatBrim.BackgroundColor3 = Color3.fromRGB(144, 202, 249); HatBrim.BorderSizePixel = 0
HatBrim.ZIndex = 5; HatBrim.Parent = HatCircle
Instance.new("UICorner", HatBrim).CornerRadius = UDim.new(0, 3)

-- Title
local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.Size = UDim2.new(1, -120, 1, 0); HeaderTitle.Position = UDim2.new(0, 54, 0, 0)
HeaderTitle.BackgroundTransparency = 1; HeaderTitle.Text = "Harvest Sender v3"
HeaderTitle.TextColor3 = Color3.fromRGB(227, 242, 253); HeaderTitle.TextSize = 17
HeaderTitle.Font = Enum.Font.GothamBold; HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.ZIndex = 4; HeaderTitle.Parent = Header

-- Traffic dots
for i, col in ipairs({Color3.fromRGB(239,154,154), Color3.fromRGB(255,245,157), Color3.fromRGB(165,214,167)}) do
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0,10,0,10); dot.Position = UDim2.new(1,-14-(i-1)*16,0.5,-5)
    dot.BackgroundColor3 = col; dot.BorderSizePixel = 0; dot.ZIndex = 4; dot.Parent = Header
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
end

-- Stat box helper
local function makeStatBox(label, xOffset)
    local box = Instance.new("Frame")
    box.Size = UDim2.new(0,140,0,72); box.Position = UDim2.new(0,xOffset,0,68)
    box.BackgroundColor3 = Color3.fromRGB(255,255,255); box.BorderSizePixel = 0
    box.ZIndex = 3; box.Parent = Card
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 16)
    local bs = Instance.new("UIStroke"); bs.Color = Color3.fromRGB(244,143,177); bs.Thickness = 2; bs.Parent = box
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,0,0,22); lbl.Position = UDim2.new(0,0,0,8)
    lbl.BackgroundTransparency = 1; lbl.Text = label
    lbl.TextColor3 = Color3.fromRGB(173,20,87); lbl.TextSize = 11
    lbl.Font = Enum.Font.GothamBold; lbl.ZIndex = 4; lbl.Parent = box
    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(1,0,0,36); val.Position = UDim2.new(0,0,0,28)
    val.BackgroundTransparency = 1; val.Text = "0"
    val.TextColor3 = Color3.fromRGB(136,14,79); val.TextSize = 28
    val.Font = Enum.Font.GothamBold; val.ZIndex = 4; val.Parent = box
    return val
end

local TradedVal    = makeStatBox("TRADED",    20)
local RemainingVal = makeStatBox("REMAINING", 320)

-- Bubble dots between stat boxes
for i, sz in ipairs({12, 8, 6}) do
    local b = Instance.new("Frame")
    b.Size = UDim2.new(0,sz,0,sz); b.Position = UDim2.new(0.5,-sz/2,0,68+36-sz/2+(i-1)*12)
    b.BackgroundColor3 = i==1 and Color3.fromRGB(240,98,146) or i==2 and Color3.fromRGB(244,143,177) or Color3.fromRGB(252,228,236)
    b.BorderSizePixel = i==3 and 1 or 0; b.ZIndex = 3; b.Parent = Card
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    if i==3 then local bs2=Instance.new("UIStroke"); bs2.Color=Color3.fromRGB(244,143,177); bs2.Thickness=1; bs2.Parent=b end
end

-- Status label
local UI_Status = Instance.new("TextLabel")
UI_Status.Size = UDim2.new(1,-40,0,22); UI_Status.Position = UDim2.new(0,20,0,152)
UI_Status.BackgroundTransparency = 1; UI_Status.Text = "Status: Starting..."
UI_Status.TextColor3 = Color3.fromRGB(136,14,79); UI_Status.TextSize = 13
UI_Status.Font = Enum.Font.GothamBold; UI_Status.TextXAlignment = Enum.TextXAlignment.Left
UI_Status.ZIndex = 3; UI_Status.Parent = Card

-- Lollipop bar BG
local BarBG = Instance.new("Frame")
BarBG.Size = UDim2.new(1,-40,0,22); BarBG.Position = UDim2.new(0,20,0,178)
BarBG.BackgroundColor3 = Color3.fromRGB(255,255,255); BarBG.BorderSizePixel = 0
BarBG.ZIndex = 3; BarBG.Parent = Card
Instance.new("UICorner", BarBG).CornerRadius = UDim.new(1, 0)
local BarStroke = Instance.new("UIStroke"); BarStroke.Color = Color3.fromRGB(244,143,177); BarStroke.Thickness=2; BarStroke.Parent=BarBG

-- Lollipop bar fill
local BarFill = Instance.new("Frame")
BarFill.Size = UDim2.new(0,0,1,0); BarFill.BackgroundColor3 = Color3.fromRGB(233,30,140)
BarFill.BorderSizePixel = 0; BarFill.ZIndex = 4; BarFill.Parent = BarBG
Instance.new("UICorner", BarFill).CornerRadius = UDim.new(1, 0)
local CandyDot = Instance.new("Frame")
CandyDot.Size = UDim2.new(0,10,0,10); CandyDot.AnchorPoint = Vector2.new(1,0.5)
CandyDot.Position = UDim2.new(1,-4,0.5,0); CandyDot.BackgroundColor3 = Color3.fromRGB(255,255,255)
CandyDot.BackgroundTransparency = 0.3; CandyDot.BorderSizePixel = 0; CandyDot.ZIndex = 5; CandyDot.Parent = BarFill
Instance.new("UICorner", CandyDot).CornerRadius = UDim.new(1, 0)

-- Pct label
local PctMid = Instance.new("TextLabel")
PctMid.Size = UDim2.new(1,-40,0,16); PctMid.Position = UDim2.new(0,20,0,202)
PctMid.BackgroundTransparency = 1; PctMid.Text = "0%"
PctMid.TextColor3 = Color3.fromRGB(136,14,79); PctMid.TextSize = 11
PctMid.Font = Enum.Font.GothamBold; PctMid.TextXAlignment = Enum.TextXAlignment.Center
PctMid.ZIndex = 3; PctMid.Parent = Card

-- Detail label
local UI_Detail = Instance.new("TextLabel")
UI_Detail.Size = UDim2.new(1,-40,0,20); UI_Detail.Position = UDim2.new(0,20,0,224)
UI_Detail.BackgroundTransparency = 1; UI_Detail.Text = ""
UI_Detail.TextColor3 = Color3.fromRGB(106,28,32); UI_Detail.TextSize = 12
UI_Detail.Font = Enum.Font.Gotham; UI_Detail.TextXAlignment = Enum.TextXAlignment.Left
UI_Detail.ZIndex = 3; UI_Detail.Parent = Card

-- Trade info row
local TradeRow = Instance.new("Frame")
TradeRow.Size = UDim2.new(1,-40,0,64); TradeRow.Position = UDim2.new(0,20,0,252)
TradeRow.BackgroundColor3 = Color3.fromRGB(255,255,255); TradeRow.BorderSizePixel = 0
TradeRow.ZIndex = 3; TradeRow.Parent = Card
Instance.new("UICorner", TradeRow).CornerRadius = UDim.new(0, 14)
local TRS = Instance.new("UIStroke"); TRS.Color = Color3.fromRGB(244,143,177); TRS.Thickness=2; TRS.Parent=TradeRow

-- Lollipop art
local Stick = Instance.new("Frame")
Stick.Size = UDim2.new(0,2,0,18); Stick.Position = UDim2.new(0,29,0,40)
Stick.BackgroundColor3 = Color3.fromRGB(229,57,53); Stick.BorderSizePixel=0; Stick.ZIndex=4; Stick.Parent=TradeRow
local Candy = Instance.new("Frame")
Candy.Size = UDim2.new(0,24,0,24); Candy.Position = UDim2.new(0,18,0,16)
Candy.BackgroundColor3 = Color3.fromRGB(229,57,53); Candy.BorderSizePixel=0; Candy.ZIndex=4; Candy.Parent=TradeRow
Instance.new("UICorner", Candy).CornerRadius = UDim.new(1,0)
local CS2 = Instance.new("UIStroke"); CS2.Color=Color3.fromRGB(183,28,28); CS2.Thickness=2; CS2.Parent=Candy
local CandyInner = Instance.new("Frame")
CandyInner.Size=UDim2.new(0,10,0,10); CandyInner.Position=UDim2.new(0.5,-5,0.5,-5)
CandyInner.BackgroundColor3=Color3.fromRGB(255,160,160); CandyInner.BorderSizePixel=0
CandyInner.ZIndex=5; CandyInner.Parent=Candy
Instance.new("UICorner",CandyInner).CornerRadius=UDim.new(1,0)

-- Trade # label
local UI_TradeNum = Instance.new("TextLabel")
UI_TradeNum.Size=UDim2.new(0,200,0,28); UI_TradeNum.Position=UDim2.new(0,54,0,8)
UI_TradeNum.BackgroundTransparency=1; UI_TradeNum.Text="Trade #0"
UI_TradeNum.TextColor3=Color3.fromRGB(173,20,87); UI_TradeNum.TextSize=13
UI_TradeNum.Font=Enum.Font.GothamBold; UI_TradeNum.TextXAlignment=Enum.TextXAlignment.Left
UI_TradeNum.ZIndex=4; UI_TradeNum.Parent=TradeRow

-- Filter mode
local UI_Mode = Instance.new("TextLabel")
UI_Mode.Size=UDim2.new(0,200,0,20); UI_Mode.Position=UDim2.new(0,54,0,36)
UI_Mode.BackgroundTransparency=1; UI_Mode.Text=filterMode
UI_Mode.TextColor3=Color3.fromRGB(194,24,91); UI_Mode.TextSize=11
UI_Mode.Font=Enum.Font.Gotham; UI_Mode.TextXAlignment=Enum.TextXAlignment.Left
UI_Mode.ZIndex=4; UI_Mode.Parent=TradeRow

-- Trades done
local TradeDoneTitle = Instance.new("TextLabel")
TradeDoneTitle.Size=UDim2.new(0,80,0,20); TradeDoneTitle.Position=UDim2.new(1,-90,0,8)
TradeDoneTitle.BackgroundTransparency=1; TradeDoneTitle.Text="Trades done"
TradeDoneTitle.TextColor3=Color3.fromRGB(173,20,87); TradeDoneTitle.TextSize=11
TradeDoneTitle.Font=Enum.Font.Gotham; TradeDoneTitle.ZIndex=4; TradeDoneTitle.Parent=TradeRow
local UI_TradeCount = Instance.new("TextLabel")
UI_TradeCount.Size=UDim2.new(0,80,0,30); UI_TradeCount.Position=UDim2.new(1,-90,0,26)
UI_TradeCount.BackgroundTransparency=1; UI_TradeCount.Text="0"
UI_TradeCount.TextColor3=Color3.fromRGB(136,14,79); UI_TradeCount.TextSize=24
UI_TradeCount.Font=Enum.Font.GothamBold; UI_TradeCount.ZIndex=4; UI_TradeCount.Parent=TradeRow

-- Filter pills
local pillData = {}
if MEGA_ONLY       then table.insert(pillData, {"MEGA ONLY",   Color3.fromRGB(21,101,192), Color3.fromRGB(227,242,253)}) end
if NEON_ONLY       then table.insert(pillData, {"NEON ONLY",   Color3.fromRGB(21,101,192), Color3.fromRGB(227,242,253)}) end
if FULL_GROWN_ONLY then table.insert(pillData, {"FULL GROWN",  Color3.fromRGB(173,20,87),  Color3.fromRGB(252,228,236)}) end
table.insert(pillData, {"AUTO DISABLE", Color3.fromRGB(46,125,50), Color3.fromRGB(232,245,233)})
local pillX = 20
for _, p in ipairs(pillData) do
    local pill = Instance.new("TextLabel")
    pill.Size = UDim2.new(0,#p[1]*7+20,0,22); pill.Position = UDim2.new(0,pillX,0,332)
    pill.BackgroundColor3=p[2]; pill.Text=p[1]; pill.TextColor3=p[3]
    pill.TextSize=11; pill.Font=Enum.Font.GothamBold; pill.ZIndex=3; pill.Parent=Card
    Instance.new("UICorner",pill).CornerRadius=UDim.new(1,0)
    pillX = pillX + #p[1]*7+28
end

-- Pets + account info
local UI_Pets = Instance.new("TextLabel")
UI_Pets.Size=UDim2.new(1,-40,0,20); UI_Pets.Position=UDim2.new(0,20,0,364)
UI_Pets.BackgroundTransparency=1; UI_Pets.Text="Pets: " .. table.concat(PET_NAMES, ", ")
UI_Pets.TextColor3=Color3.fromRGB(173,20,87); UI_Pets.TextSize=11
UI_Pets.Font=Enum.Font.Gotham; UI_Pets.TextXAlignment=Enum.TextXAlignment.Left
UI_Pets.ZIndex=3; UI_Pets.Parent=Card

local UI_Account = Instance.new("TextLabel")
UI_Account.Size=UDim2.new(1,-40,0,20); UI_Account.Position=UDim2.new(0,20,0,384)
UI_Account.BackgroundTransparency=1; UI_Account.Text="Account: " .. playerName .. "  ->  " .. USERNAME
UI_Account.TextColor3=Color3.fromRGB(173,20,87); UI_Account.TextSize=11
UI_Account.Font=Enum.Font.Gotham; UI_Account.TextXAlignment=Enum.TextXAlignment.Left
UI_Account.ZIndex=3; UI_Account.Parent=Card

-- updateUI
local function updateUI(status, traded, remaining, detail, tradeNum)
    if UI_Status   then UI_Status.Text   = "Status: " .. tostring(status) end
    if UI_Detail   then UI_Detail.Text   = tostring(detail or "")          end
    if UI_TradeNum and tradeNum then UI_TradeNum.Text  = "Trade #" .. tostring(tradeNum) end
    if UI_TradeCount and tradeNum then UI_TradeCount.Text = tostring(tradeNum) end
    if traded ~= nil and remaining ~= nil then
        TradedVal.Text    = tostring(traded)
        RemainingVal.Text = tostring(remaining)
        local total = traded + remaining
        local pct   = total > 0 and math.clamp(traded / total, 0, 1) or 0
        PctMid.Text = math.floor(pct * 100) .. "%"
        TweenService:Create(BarFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(pct, 0, 1, 0)
        }):Play()
    end
end

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
-- PET FILTER HELPER
-- ============================================

local function petPassesFilter(item)
    local is_neon = item.properties and item.properties.neon
    local is_mega = item.properties and item.properties.mega_neon
    local pet_age = item.properties and item.properties.age or 0

    if FULL_GROWN_ONLY and pet_age ~= 6 then return false end

    if MEGA_ONLY and NEON_ONLY then
        -- both true = accept neon AND mega
        return is_neon == true or is_mega == true
    elseif MEGA_ONLY then
        return is_mega == true
    elseif NEON_ONLY then
        return is_neon == true and not is_mega
    else
        return not is_neon and not is_mega
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
local filterMode = MEGA_ONLY and "MEGA ONLY" or (NEON_ONLY and "NEON ONLY" or "NORMAL (non-neon)")
if FULL_GROWN_ONLY then filterMode = filterMode .. " + FULL GROWN" end
log("Filter   : " .. filterMode)
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
            if item.kind == pet.kind and petPassesFilter(item) then
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
updateUI("Waiting for " .. USERNAME, 0, #items_unique_ids, "Player not in server yet", 0)
while not Players:FindFirstChild(USERNAME) do
    task.wait(5)
end
log("Found '" .. USERNAME .. "'!")
sendWebhook("Harvest Sender started | Pets: " .. table.concat(PET_NAMES, ", "))
updateUI("Player found!", 0, #items_unique_ids, "Starting trades...", 0)

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
        updateUI("Sending trade request...", tradeCount * 18, #items_unique_ids, "Waiting for " .. USERNAME .. " to accept", tradeCount)

    elseif not trade_status and tradeGuiVisible() then
        local counter = 0
        while #items_unique_ids > 0 and counter < 18 do
            local unique = table.remove(items_unique_ids, 1)
            add_items_in_trade(unique)
            log("Added item to trade")
            counter = counter + 1
            updateUI("Adding pets...", tradeCount * 18 + counter, #items_unique_ids, string.format("Slot %d / %d", counter, math.min(18, counter + #items_unique_ids)), tradeCount)
            task.wait(0.5)
        end
        log("Items left in queue: " .. #items_unique_ids)
        trade_status = true
        updateUI("Accepting trade...", tradeCount * 18 + counter, #items_unique_ids, "Confirming...", tradeCount)

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
        updateUI("Trade complete!", tradeCount * 18, #items_unique_ids, "Trade #" .. tradeCount .. " done!", tradeCount)

    else
        log("Waiting...")
        updateUI("Waiting...", tradeCount * 18, #items_unique_ids, "Standing by...", tradeCount)
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
updateUI("All done! Disabling account...", tradeCount * 18, 0, tradeCount .. " trades completed!", tradeCount)

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
