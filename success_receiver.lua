--[[
    ULTIMATE PET TRADER V3
    - No amount required — trades ALL available matching pets
    - Fixed dehash (auto-scans upvalues)
    - Full-screen overlay progress UI (0.5 transparency)
    - MEGA_ONLY / NEON_ONLY support

    CONFIG EXAMPLE:
    getgenv().TradeConfig = {
        USERNAME        = "MainAccount",
        PET_NAME        = "Corgi",        -- or PET_NAMES = {"Corgi","Robot"}
        NEON_ONLY       = false,
        MEGA_ONLY       = false,
        FULL_GROWN_ONLY = false,
        NORMAL_MODE     = false,
        AUTO_KICK       = false,
    }
]]

local CONFIG = getgenv().TradeConfig
if not CONFIG then
    error("❌ ERROR: No configuration found!\n\nPlease set getgenv().TradeConfig BEFORE loading the script.")
end

-- ============================================
-- SETUP
-- ============================================

repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui           = game:GetService("CoreGui")
local LocalPlayer       = Players.LocalPlayer
local playerName        = LocalPlayer.Name

-- Anti-AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- ============================================
-- DEHASH (auto-scans upvalues 1-30)
-- ============================================
local function dehash()
    local router = require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient)
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
    warn("[Dehash] Failed — remotes may still be hashed, continuing anyway...")
end
dehash()

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- Default config flags
if CONFIG.AUTO_KICK       == nil then CONFIG.AUTO_KICK       = false end
if CONFIG.NORMAL_MODE     == nil then CONFIG.NORMAL_MODE     = false end
if CONFIG.FULL_GROWN_ONLY == nil then CONFIG.FULL_GROWN_ONLY = false end
if CONFIG.NEON_ONLY       == nil then CONFIG.NEON_ONLY       = false end
if CONFIG.MEGA_ONLY       == nil then CONFIG.MEGA_ONLY       = false end

-- ============================================
-- FULL-SCREEN OVERLAY UI
-- ============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "TradeProgressUI"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset  = true

local ok = pcall(function() ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
if not ok then ScreenGui.Parent = CoreGui end

-- Full-screen backdrop
local Backdrop = Instance.new("Frame")
Backdrop.Size                   = UDim2.new(1, 0, 1, 0)
Backdrop.Position               = UDim2.new(0, 0, 0, 0)
Backdrop.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
Backdrop.BackgroundTransparency = 0.5
Backdrop.BorderSizePixel        = 0
Backdrop.ZIndex                 = 1
Backdrop.Parent                 = ScreenGui

-- Centered card
local Card = Instance.new("Frame")
Card.Size             = UDim2.new(0, 520, 0, 320)
Card.Position         = UDim2.new(0.5, -260, 0.5, -160)
Card.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Card.BorderSizePixel  = 0
Card.ZIndex           = 2
Card.Parent           = ScreenGui
Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 16)

-- Accent bar
local AccentBar = Instance.new("Frame")
AccentBar.Size             = UDim2.new(1, 0, 0, 5)
AccentBar.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
AccentBar.BorderSizePixel  = 0
AccentBar.ZIndex           = 3
AccentBar.Parent           = Card
Instance.new("UICorner", AccentBar).CornerRadius = UDim.new(0, 16)

-- Title
local Title = Instance.new("TextLabel")
Title.Size               = UDim2.new(1, -40, 0, 44)
Title.Position           = UDim2.new(0, 20, 0, 18)
Title.BackgroundTransparency = 1
Title.Text               = "🚀  ULTIMATE PET TRADER  V3"
Title.TextColor3         = Color3.fromRGB(255, 255, 255)
Title.TextSize           = 22
Title.Font               = Enum.Font.GothamBold
Title.TextXAlignment     = Enum.TextXAlignment.Left
Title.ZIndex             = 3
Title.Parent             = Card

-- Divider
local Divider = Instance.new("Frame")
Divider.Size             = UDim2.new(1, -40, 0, 1)
Divider.Position         = UDim2.new(0, 20, 0, 68)
Divider.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
Divider.BorderSizePixel  = 0
Divider.ZIndex           = 3
Divider.Parent           = Card

-- Mode badge
local ModeBadge = Instance.new("TextLabel")
ModeBadge.Size                   = UDim2.new(0, 200, 0, 26)
ModeBadge.Position               = UDim2.new(0, 20, 0, 82)
ModeBadge.BackgroundColor3       = Color3.fromRGB(99, 102, 241)
ModeBadge.BackgroundTransparency = 0.6
ModeBadge.Text                   = "● INITIALIZING"
ModeBadge.TextColor3             = Color3.fromRGB(200, 200, 255)
ModeBadge.TextSize               = 12
ModeBadge.Font                   = Enum.Font.GothamBold
ModeBadge.ZIndex                 = 3
ModeBadge.Parent                 = Card
Instance.new("UICorner", ModeBadge).CornerRadius = UDim.new(0, 6)
Instance.new("UIPadding", ModeBadge).PaddingLeft = UDim.new(0, 8)

-- Status
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size               = UDim2.new(1, -40, 0, 36)
StatusLabel.Position           = UDim2.new(0, 20, 0, 118)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text               = "Status: Starting up..."
StatusLabel.TextColor3         = Color3.fromRGB(230, 230, 230)
StatusLabel.TextSize           = 16
StatusLabel.Font               = Enum.Font.Gotham
StatusLabel.TextXAlignment     = Enum.TextXAlignment.Left
StatusLabel.ZIndex             = 3
StatusLabel.Parent             = Card

-- Progress bar BG
local BarBG = Instance.new("Frame")
BarBG.Size             = UDim2.new(1, -40, 0, 18)
BarBG.Position         = UDim2.new(0, 20, 0, 164)
BarBG.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
BarBG.BorderSizePixel  = 0
BarBG.ZIndex           = 3
BarBG.Parent           = Card
Instance.new("UICorner", BarBG).CornerRadius = UDim.new(0, 9)

-- Progress bar fill
local BarFill = Instance.new("Frame")
BarFill.Size             = UDim2.new(0, 0, 1, 0)
BarFill.BackgroundColor3 = Color3.fromRGB(99, 102, 241)
BarFill.BorderSizePixel  = 0
BarFill.ZIndex           = 4
BarFill.Parent           = BarBG
Instance.new("UICorner", BarFill).CornerRadius = UDim.new(0, 9)

-- Progress text
local ProgressLabel = Instance.new("TextLabel")
ProgressLabel.Size               = UDim2.new(1, -40, 0, 28)
ProgressLabel.Position           = UDim2.new(0, 20, 0, 188)
ProgressLabel.BackgroundTransparency = 1
ProgressLabel.Text               = "Traded: 0  |  Remaining: 0"
ProgressLabel.TextColor3         = Color3.fromRGB(180, 180, 200)
ProgressLabel.TextSize           = 14
ProgressLabel.Font               = Enum.Font.GothamBold
ProgressLabel.TextXAlignment     = Enum.TextXAlignment.Left
ProgressLabel.ZIndex             = 3
ProgressLabel.Parent             = Card

-- Detail
local DetailLabel = Instance.new("TextLabel")
DetailLabel.Size               = UDim2.new(1, -40, 0, 26)
DetailLabel.Position           = UDim2.new(0, 20, 0, 222)
DetailLabel.BackgroundTransparency = 1
DetailLabel.Text               = ""
DetailLabel.TextColor3         = Color3.fromRGB(130, 130, 160)
DetailLabel.TextSize           = 13
DetailLabel.Font               = Enum.Font.Gotham
DetailLabel.TextXAlignment     = Enum.TextXAlignment.Left
DetailLabel.ZIndex             = 3
DetailLabel.Parent             = Card

-- Trade count
local TradeCountLabel = Instance.new("TextLabel")
TradeCountLabel.Size               = UDim2.new(1, -40, 0, 26)
TradeCountLabel.Position           = UDim2.new(0, 20, 0, 252)
TradeCountLabel.BackgroundTransparency = 1
TradeCountLabel.Text               = "Trades completed: 0"
TradeCountLabel.TextColor3         = Color3.fromRGB(130, 130, 160)
TradeCountLabel.TextSize           = 13
TradeCountLabel.Font               = Enum.Font.Gotham
TradeCountLabel.TextXAlignment     = Enum.TextXAlignment.Left
TradeCountLabel.ZIndex             = 3
TradeCountLabel.Parent             = Card

-- Filter tags
local FilterRow = Instance.new("TextLabel")
FilterRow.Size               = UDim2.new(1, -40, 0, 24)
FilterRow.Position           = UDim2.new(0, 20, 0, 284)
FilterRow.BackgroundTransparency = 1
local filterTags = {}
if CONFIG.MEGA_ONLY       then table.insert(filterTags, "🟣 MEGA ONLY")       end
if CONFIG.NEON_ONLY       then table.insert(filterTags, "🔵 NEON ONLY")       end
if CONFIG.FULL_GROWN_ONLY then table.insert(filterTags, "🌿 FULL GROWN ONLY") end
if CONFIG.NORMAL_MODE     then table.insert(filterTags, "🐢 NORMAL MODE")     end
FilterRow.Text               = #filterTags > 0 and table.concat(filterTags, "  ·  ") or "No extra filters"
FilterRow.TextColor3         = Color3.fromRGB(100, 100, 130)
FilterRow.TextSize           = 12
FilterRow.Font               = Enum.Font.Gotham
FilterRow.TextXAlignment     = Enum.TextXAlignment.Left
FilterRow.ZIndex             = 3
FilterRow.Parent             = Card

local function updateUI(status, traded, remaining, detail, tradeNum, badge)
    if StatusLabel    then StatusLabel.Text = "Status: " .. tostring(status) end
    if DetailLabel    then DetailLabel.Text = tostring(detail or "")         end
    if TradeCountLabel and tradeNum then
        TradeCountLabel.Text = "Trades completed: " .. tostring(tradeNum)
    end
    if badge and ModeBadge then
        ModeBadge.Text = "● " .. tostring(badge):upper()
    end
    if ProgressLabel and traded ~= nil and remaining ~= nil then
        ProgressLabel.Text = string.format("Traded: %d  |  Remaining: %d", traded, remaining)
    end
    if BarFill and traded ~= nil and remaining ~= nil then
        local total = traded + remaining
        local pct   = total > 0 and math.clamp(traded / total, 0, 1) or 0
        BarFill:TweenSize(UDim2.new(pct, 0, 1, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
    end
end

-- ============================================
-- UTILITIES
-- ============================================
local function findPlayer(username)
    local search = username:lower()
    for _, player in pairs(Players:GetPlayers()) do
        if player.Name:lower() == search then return player end
    end
    return nil
end

local function resolveItem(input)
    local db = require(ReplicatedStorage:WaitForChild("ClientDB"):WaitForChild("Inventory"):WaitForChild("KindDB"))
    local search = input:lower()
    local nameMatch = nil
    for _, v in pairs(db) do
        if v.kind and v.kind:lower() == search then return v.kind, v end
        if not nameMatch and v.name and v.name:lower() == search then nameMatch = v end
    end
    if nameMatch then return nameMatch.kind, nameMatch end
    return nil
end

-- ============================================
-- PET FILTER HELPER
-- ============================================
local function petPassesFilter(pet, petConfig)
    local is_neon = pet.properties and pet.properties.neon
    local is_mega = pet.properties and pet.properties.mega_neon
    local pet_age = pet.properties and pet.properties.age or 0

    if CONFIG.FULL_GROWN_ONLY and pet_age ~= 6 then return false end

    local neonOnly = petConfig.NEON_ONLY or CONFIG.NEON_ONLY
    local megaOnly = petConfig.MEGA_ONLY or CONFIG.MEGA_ONLY

    if megaOnly then
        return is_mega == true
    elseif neonOnly then
        return is_neon == true and not is_mega
    else
        return not is_neon and not is_mega
    end
end

-- ============================================
-- BUILD PETS LIST
-- ============================================
local petsList        = {}
local MIXED_MODE      = false
local MULTI_USER_MODE = false

if CONFIG.PET_NAMES then
    MIXED_MODE = true
    for _, petName in ipairs(CONFIG.PET_NAMES) do
        table.insert(petsList, {
            PET_NAME  = petName,
            NEON_ONLY = CONFIG.NEON_ONLY or false,
            MEGA_ONLY = CONFIG.MEGA_ONLY or false,
        })
    end
elseif CONFIG.PETS then
    MIXED_MODE = true
    for _, petConfig in ipairs(CONFIG.PETS) do
        table.insert(petsList, {
            PET_NAME  = petConfig.PET_NAME,
            NEON_ONLY = petConfig.NEON_ONLY or CONFIG.NEON_ONLY or false,
            MEGA_ONLY = petConfig.MEGA_ONLY or CONFIG.MEGA_ONLY or false,
        })
    end
elseif CONFIG.PET_NAME then
    table.insert(petsList, {
        PET_NAME  = CONFIG.PET_NAME,
        NEON_ONLY = CONFIG.NEON_ONLY or false,
        MEGA_ONLY = CONFIG.MEGA_ONLY or false,
    })
else
    error("❌ No pet configuration found! Use PET_NAME, PET_NAMES, or PETS")
end

if CONFIG.USERNAMES and #CONFIG.USERNAMES > 0 then
    MULTI_USER_MODE = true
else
    CONFIG.USERNAMES = { CONFIG.USERNAME }
end

-- ============================================
-- RESOLVE ALL PET NAMES
-- ============================================
updateUI("Resolving pet names...", 0, 0, "", 0, "resolving")

for _, petConfig in ipairs(petsList) do
    local resolved_kind = resolveItem(petConfig.PET_NAME)
    if not resolved_kind then
        error("❌ Could not resolve pet: " .. petConfig.PET_NAME)
    end
    petConfig.PET_KIND = resolved_kind
    print(string.format("[Resolve] %s -> %s", petConfig.PET_NAME, resolved_kind))
end

-- ============================================
-- PET COLLECTION FUNCTIONS
-- ============================================
local function get_all_pets_of_type(petConfig, limit)
    local pets = {}
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then return end
        for _, pet in pairs(playerData.inventory.pets) do
            if pet.kind == petConfig.PET_KIND and petPassesFilter(pet, petConfig) then
                table.insert(pets, pet.unique)
                if limit and #pets >= limit then break end
            end
        end
    end)
    return pets
end

local function count_pets(petConfig)
    return #get_all_pets_of_type(petConfig, nil)
end

local function get_mixed_batch(batch_size)
    local pets = {}
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then return end
        for _, pet in pairs(playerData.inventory.pets) do
            if #pets >= batch_size then break end
            for _, petConfig in ipairs(petsList) do
                if pet.kind == petConfig.PET_KIND and petPassesFilter(pet, petConfig) then
                    table.insert(pets, { unique = pet.unique, kind = petConfig.PET_KIND, name = petConfig.PET_NAME })
                    break
                end
            end
        end
    end)
    return pets
end

local function count_mixed_remaining()
    local total = 0
    for _, petConfig in ipairs(petsList) do
        total = total + count_pets(petConfig)
    end
    return total
end

-- ============================================
-- TRADE FUNCTIONS
-- ============================================
local function send_trade(username)
    local target = findPlayer(username)
    if not target then return false end
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/SendTradeRequest"):FireServer(target)
    return true
end

local function add_pet(unique)
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(unique)
end

local function accept_trade()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
end

local function confirm_trade()
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
end

local function waitForTradeClose(tradeGui)
    if CONFIG.NORMAL_MODE then
        accept_trade() task.wait(20) confirm_trade()
        repeat task.wait(0.5) until not tradeGui.Visible
    else
        local spamA, spamC = true, true
        task.spawn(function() while spamA do pcall(accept_trade)  task.wait(0.5) end end)
        task.wait(1)
        task.spawn(function() while spamC do pcall(confirm_trade) task.wait(0.5) end end)
        repeat task.wait(0.5) until not tradeGui.Visible
        spamA = false spamC = false
    end
end

local function waitForTradeGui(username, traded, remaining, tradeNum, badge)
    while not send_trade(username) do
        updateUI("Waiting for player...", traded, remaining, username .. " not in server", tradeNum, badge)
        task.wait(5)
    end
    task.wait(2)
    local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
    local timeout  = 0
    while not tradeGui.Visible do
        task.wait(0.5) timeout = timeout + 0.5
        if timeout >= 10 then send_trade(username) timeout = 0 end
    end
    return tradeGui
end

-- ============================================
-- SINGLE PET MODE
-- ============================================
local function trade_single_pet_to_user(username)
    local petConfig = petsList[1]
    local badge     = petConfig.MEGA_ONLY and "MEGA" or (petConfig.NEON_ONLY and "NEON" or "NORMAL")
    local BATCH     = 18
    local traded    = 0
    local tradeNum  = 0

    while not findPlayer(username) do
        local remaining = count_pets(petConfig)
        updateUI("Waiting for player...", traded, remaining, username .. " not in server", tradeNum, badge)
        task.wait(5)
    end

    while true do
        local remaining = count_pets(petConfig)
        if remaining == 0 then
            updateUI("✅ Complete!", traded, 0, "No more pets to trade!", tradeNum, badge)
            break
        end

        local pets = get_all_pets_of_type(petConfig, BATCH)
        updateUI("Trading to " .. username, traded, remaining, "Sending trade request...", tradeNum, badge)

        local tradeGui = waitForTradeGui(username, traded, remaining, tradeNum, badge)

        local add_delay = CONFIG.NORMAL_MODE and 3.0 or 0.2
        for i, petUnique in ipairs(pets) do
            add_pet(petUnique)
            updateUI("Adding pets", traded, remaining, string.format("Slot %d / %d", i, #pets), tradeNum, badge)
            task.wait(add_delay)
        end

        updateUI("Confirming trade...", traded, remaining, "Waiting for countdown...", tradeNum, badge)
        task.wait(6)
        waitForTradeClose(tradeGui)

        task.wait(1)
        local newRemaining = count_pets(petConfig)
        local justTraded   = remaining - newRemaining
        if justTraded > 0 then
            traded   = traded + justTraded
            tradeNum = tradeNum + 1
        end

        updateUI("Trading to " .. username, traded, newRemaining, "Trade #" .. tradeNum .. " done!", tradeNum, badge)
        task.wait(2)
    end

    return true
end

-- ============================================
-- MIXED PETS MODE
-- ============================================
local function trade_mixed_pets_to_user(username)
    local BATCH    = 18
    local traded   = 0
    local tradeNum = 0

    while not findPlayer(username) do
        local remaining = count_mixed_remaining()
        updateUI("Waiting for player...", traded, remaining, username .. " not in server", tradeNum, "MIXED")
        task.wait(5)
    end

    while true do
        local remaining = count_mixed_remaining()
        if remaining == 0 then
            updateUI("✅ Complete!", traded, 0, "All pets traded!", tradeNum, "MIXED")
            break
        end

        local pets = get_mixed_batch(BATCH)
        if #pets == 0 then
            updateUI("✅ Complete!", traded, 0, "All pets traded!", tradeNum, "MIXED")
            break
        end

        updateUI("Trading to " .. username, traded, remaining, "Sending trade request...", tradeNum, "MIXED")

        local tradeGui = waitForTradeGui(username, traded, remaining, tradeNum, "MIXED")

        local add_delay = CONFIG.NORMAL_MODE and 3.0 or 0.2
        for i, pet in ipairs(pets) do
            add_pet(pet.unique)
            updateUI("Adding " .. pet.name, traded, remaining, string.format("Slot %d / %d", i, #pets), tradeNum, "MIXED")
            task.wait(add_delay)
        end

        task.wait(6)
        waitForTradeClose(tradeGui)

        traded   = traded + #pets
        tradeNum = tradeNum + 1
        task.wait(2)
    end

    return true
end

-- ============================================
-- MAIN
-- ============================================
local function run_trader()
    local successful = 0
    local failed     = 0

    for i, username in ipairs(CONFIG.USERNAMES) do
        local success
        if MIXED_MODE then
            success = trade_mixed_pets_to_user(username)
        else
            success = trade_single_pet_to_user(username)
        end

        if success then successful = successful + 1 else failed = failed + 1 end
        if i < #CONFIG.USERNAMES then task.wait(3) end
    end

    updateUI(
        "🎉 ALL DONE!",
        successful, 0,
        string.format("✅ %d succeeded · ❌ %d failed", successful, failed),
        nil, "done"
    )

    if CONFIG.AUTO_KICK then
        task.wait(3)
        LocalPlayer:Kick("✅ Trading complete!")
    end
end

run_trader()
