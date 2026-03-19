-- ============================================
-- ULTIMATE PET TRADER V3
-- Fixed config system + Progress UI
-- ============================================

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

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local playerName = LocalPlayer.Name
local CoreGui = game:GetService("CoreGui")

-- Anti-AFK
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Dehash
for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
    v.Name = i
end

local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)

-- Default settings
if CONFIG.AUTO_KICK == nil then CONFIG.AUTO_KICK = false end
if CONFIG.NORMAL_MODE == nil then CONFIG.NORMAL_MODE = false end
if CONFIG.FULL_GROWN_ONLY == nil then CONFIG.FULL_GROWN_ONLY = false end

-- ============================================
-- PROGRESS UI
-- ============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TradeProgressUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Try PlayerGui first, fallback to CoreGui
local success = pcall(function()
    ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end)
if not success then
    ScreenGui.Parent = CoreGui
end

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 400, 0, 200)
MainFrame.Position = UDim2.new(0.5, -200, 0.5, -100)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, -20, 0, 40)
Title.Position = UDim2.new(0, 10, 0, 10)
Title.BackgroundTransparency = 1
Title.Text = "🚀 ULTIMATE PET TRADER"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusLabel"
StatusLabel.Size = UDim2.new(1, -20, 0, 30)
StatusLabel.Position = UDim2.new(0, 10, 0, 60)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Initializing..."
StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
StatusLabel.TextSize = 14
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = MainFrame

local ProgressLabel = Instance.new("TextLabel")
ProgressLabel.Name = "ProgressLabel"
ProgressLabel.Size = UDim2.new(1, -20, 0, 30)
ProgressLabel.Position = UDim2.new(0, 10, 0, 100)
ProgressLabel.BackgroundTransparency = 1
ProgressLabel.Text = "Progress: 0/0"
ProgressLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
ProgressLabel.TextSize = 14
ProgressLabel.Font = Enum.Font.Gotham
ProgressLabel.TextXAlignment = Enum.TextXAlignment.Left
ProgressLabel.Parent = MainFrame

local DetailLabel = Instance.new("TextLabel")
DetailLabel.Name = "DetailLabel"
DetailLabel.Size = UDim2.new(1, -20, 0, 30)
DetailLabel.Position = UDim2.new(0, 10, 0, 140)
DetailLabel.BackgroundTransparency = 1
DetailLabel.Text = ""
DetailLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
DetailLabel.TextSize = 12
DetailLabel.Font = Enum.Font.Gotham
DetailLabel.TextXAlignment = Enum.TextXAlignment.Left
DetailLabel.Parent = MainFrame

local function updateUI(status, progress, detail)
    if StatusLabel then StatusLabel.Text = "Status: " .. status end
    if ProgressLabel and progress then ProgressLabel.Text = "Progress: " .. progress end
    if DetailLabel and detail then DetailLabel.Text = detail end
end

-- ============================================
-- CASE-INSENSITIVE PLAYER FINDER
-- ============================================
local function findPlayer(username)
    local search = username:lower()
    for _, player in pairs(Players:GetPlayers()) do
        if player.Name:lower() == search then
            return player
        end
    end
    return nil
end

-- ============================================
-- PET NAME RESOLVER (Case-insensitive)
-- ============================================
local function resolveItem(input)
    local db = require(ReplicatedStorage:WaitForChild("ClientDB"):WaitForChild("Inventory"):WaitForChild("KindDB"))
    local search = input:lower()
    local nameMatch = nil

    for _, v in pairs(db) do
        if v.kind and v.kind:lower() == search then
            return v.kind, v, "kind"
        end
        if not nameMatch and v.name and v.name:lower() == search then
            nameMatch = v
        end
    end

    if nameMatch then
        return nameMatch.kind, nameMatch, "name"
    end

    return nil
end

-- ============================================
-- DETECT MODE & BUILD PETS LIST
-- ============================================
local petsList = {}
local MIXED_MODE = false
local MULTI_USER_MODE = false

if CONFIG.PET_NAMES then
    MIXED_MODE = true
    for _, petName in ipairs(CONFIG.PET_NAMES) do
        table.insert(petsList, {
            PET_NAME = petName,
            NEON_ONLY = CONFIG.NEON_ONLY or false,
            MEGA_ONLY = CONFIG.MEGA_ONLY or false,
        })
    end
elseif CONFIG.PETS then
    MIXED_MODE = true
    for _, petConfig in ipairs(CONFIG.PETS) do
        table.insert(petsList, {
            PET_NAME = petConfig.PET_NAME,
            AMOUNT = petConfig.AMOUNT,
            NEON_ONLY = petConfig.NEON_ONLY or CONFIG.NEON_ONLY or false,
            MEGA_ONLY = petConfig.MEGA_ONLY or CONFIG.MEGA_ONLY or false,
        })
    end
elseif CONFIG.PET_NAME then
    table.insert(petsList, {
        PET_NAME = CONFIG.PET_NAME,
        AMOUNT = CONFIG.AMOUNT,
        NEON_ONLY = CONFIG.NEON_ONLY or false,
        MEGA_ONLY = CONFIG.MEGA_ONLY or false,
    })
else
    error("❌ No pet configuration found! Use PET_NAME, PET_NAMES, or PETS")
end

-- Detect multi-user mode
if CONFIG.USERNAMES and #CONFIG.USERNAMES > 0 then
    MULTI_USER_MODE = true
else
    CONFIG.USERNAMES = {CONFIG.USERNAME}
    if CONFIG.AMOUNT then
        CONFIG.AMOUNTS = {CONFIG.AMOUNT}
    end
end

-- Smart AMOUNTS handling for multi-user
if MULTI_USER_MODE and CONFIG.AMOUNTS then
    if #CONFIG.AMOUNTS == 1 and #CONFIG.USERNAMES > 1 then
        local single_amount = CONFIG.AMOUNTS[1]
        CONFIG.AMOUNTS = {}
        for i = 1, #CONFIG.USERNAMES do
            CONFIG.AMOUNTS[i] = single_amount
        end
    end
    
    if not MIXED_MODE and #CONFIG.USERNAMES ~= #CONFIG.AMOUNTS then
        error("❌ ERROR: USERNAMES and AMOUNTS must have the same number of entries!")
    end
end

-- ============================================
-- RESOLVE ALL PET NAMES
-- ============================================
updateUI("Resolving pet names...", "", "")
for i, petConfig in ipairs(petsList) do
    local resolved_kind, resolved_data = resolveItem(petConfig.PET_NAME)
    
    if not resolved_kind then
        error("❌ Could not resolve pet: " .. petConfig.PET_NAME)
    end
    
    petConfig.PET_KIND = resolved_kind
end

-- ============================================
-- PET COLLECTION FUNCTIONS
-- ============================================
local function get_single_pet_type(petConfig, count)
    local pets = {}
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then
            return
        end
        
        for _, pet in pairs(playerData.inventory.pets) do
            if pet.kind == petConfig.PET_KIND then
                local shouldInclude = true
                
                local is_neon = pet.properties and pet.properties.neon
                local is_mega = pet.properties and pet.properties.mega_neon
                local pet_age = pet.properties and pet.properties.age or 0
                
                if CONFIG.FULL_GROWN_ONLY and pet_age ~= 6 then
                    shouldInclude = false
                end
                
                if shouldInclude then
                    if petConfig.MEGA_ONLY then
                        if not is_mega then shouldInclude = false end
                    elseif petConfig.NEON_ONLY then
                        if is_mega or not is_neon then shouldInclude = false end
                    else
                        if is_neon or is_mega then shouldInclude = false end
                    end
                end
                
                if shouldInclude then
                    table.insert(pets, pet.unique)
                    if #pets >= count then break end
                end
            end
        end
    end)
    
    return pets
end

local function get_mixed_pets(batch_size, petTypeStats)
    local pets = {}
    
    pcall(function()
        local playerData = Data.get_data()[playerName]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then
            return
        end
        
        for _, pet in pairs(playerData.inventory.pets) do
            if #pets >= batch_size then break end
            
            for _, petConfig in ipairs(petsList) do
                if pet.kind == petConfig.PET_KIND then
                    local stats = petTypeStats[petConfig.PET_KIND]
                    
                    if stats.collected < stats.target then
                        local shouldInclude = true
                        
                        local is_neon = pet.properties and pet.properties.neon
                        local is_mega = pet.properties and pet.properties.mega_neon
                        local pet_age = pet.properties and pet.properties.age or 0
                        
                        if CONFIG.FULL_GROWN_ONLY and pet_age ~= 6 then
                            shouldInclude = false
                        end
                        
                        if shouldInclude then
                            if petConfig.MEGA_ONLY then
                                if not is_mega then shouldInclude = false end
                            elseif petConfig.NEON_ONLY then
                                if is_mega or not is_neon then shouldInclude = false end
                            else
                                if is_neon or is_mega then shouldInclude = false end
                            end
                        end
                        
                        if shouldInclude then
                            table.insert(pets, {
                                unique = pet.unique,
                                kind = petConfig.PET_KIND,
                                name = petConfig.PET_NAME
                            })
                            stats.collected = stats.collected + 1
                            
                            if #pets >= batch_size then break end
                        end
                    end
                    
                    break
                end
            end
        end
    end)
    
    return pets
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

-- ============================================
-- SINGLE PET MODE TRADING
-- ============================================
local function trade_single_pet_to_user(username, amount)
    updateUI("Trading to " .. username, "0/" .. amount, "Finding player...")
    
    -- Wait for player if not in server
    while not findPlayer(username) do
        updateUI("Waiting for player...", "0/" .. amount, username .. " not in server")
        task.wait(5)
    end
    
    updateUI("Trading to " .. username, "0/" .. amount, "Player found!")
    
    local BATCH_SIZE = 18
    local total_traded = 0
    local trade_number = 1
    
    local function get_current_pet_count()
        local count = 0
        pcall(function()
            local playerData = Data.get_data()[playerName]
            if playerData and playerData.inventory and playerData.inventory.pets then
                for _, pet in pairs(playerData.inventory.pets) do
                    if pet.kind == petsList[1].PET_KIND then
                        local is_neon = pet.properties and pet.properties.neon
                        local is_mega = pet.properties and pet.properties.mega_neon
                        local pet_age = pet.properties and pet.properties.age or 0
                        
                        local shouldCount = true
                        
                        if CONFIG.FULL_GROWN_ONLY and pet_age ~= 6 then
                            shouldCount = false
                        end
                        
                        if shouldCount then
                            if petsList[1].MEGA_ONLY then
                                if not is_mega then shouldCount = false end
                            elseif petsList[1].NEON_ONLY then
                                if is_mega or not is_neon then shouldCount = false end
                            else
                                if is_neon or is_mega then shouldCount = false end
                            end
                        end
                        
                        if shouldCount then count = count + 1 end
                    end
                end
            end
        end)
        return count
    end
    
    while total_traded < amount do
        local remaining = amount - total_traded
        local this_batch = math.min(remaining, BATCH_SIZE)
        
        updateUI("Trading to " .. username, total_traded .. "/" .. amount, "Trade #" .. trade_number .. " - Finding pets...")
        
        local pets_before = get_current_pet_count()
        local pets = get_single_pet_type(petsList[1], this_batch)
        
        if #pets == 0 then
            updateUI("No pets available!", total_traded .. "/" .. amount, "❌ Cannot continue")
            return false
        end
        
        updateUI("Trading to " .. username, total_traded .. "/" .. amount, "Sending trade request...")
        
        -- Send trade (infinite retry)
        while not send_trade(username) do
            updateUI("Waiting for player...", total_traded .. "/" .. amount, username .. " not in server")
            task.wait(5)
        end
        
        task.wait(2)
        
        -- Wait for GUI (infinite retry)
        local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
        local timeout = 0
        while not tradeGui.Visible do
            task.wait(0.5)
            timeout = timeout + 0.5
            
            if timeout >= 10 then
                updateUI("Retrying...", total_traded .. "/" .. amount, "Trade GUI didn't open")
                send_trade(username)
                timeout = 0
            end
        end
        
        updateUI("Trading to " .. username, total_traded .. "/" .. amount, "Adding " .. #pets .. " pets...")
        
        -- Add pets
        local add_delay = CONFIG.NORMAL_MODE and 3.0 or 0.2
        for i, petUnique in ipairs(pets) do
            add_pet(petUnique)
            updateUI("Trading to " .. username, total_traded .. "/" .. amount, "Adding pets... (" .. i .. "/" .. #pets .. ")")
            task.wait(add_delay)
        end
        
        -- Wait for countdown
        updateUI("Trading to " .. username, total_traded .. "/" .. amount, "Waiting for countdown...")
        task.wait(6)
        
        if CONFIG.NORMAL_MODE then
            updateUI("Trading to " .. username, total_traded .. "/" .. amount, "Accepting...")
            accept_trade()
            task.wait(20)
            updateUI("Trading to " .. username, total_traded .. "/" .. amount, "Confirming...")
            confirm_trade()
            repeat task.wait(0.5) until not tradeGui.Visible
        else
            updateUI("Trading to " .. username, total_traded .. "/" .. amount, "Auto-accepting...")
            local accept_spam = true
            task.spawn(function()
                while accept_spam do pcall(accept_trade) task.wait(0.5) end
            end)
            
            task.wait(1)
            
            local confirm_spam = true
            task.spawn(function()
                while confirm_spam do pcall(confirm_trade) task.wait(0.5) end
            end)
            
            repeat task.wait(0.5) until not tradeGui.Visible
            
            accept_spam = false
            confirm_spam = false
        end
        
        -- Check actual traded amount
        task.wait(1)
        local pets_after = get_current_pet_count()
        local actually_traded = pets_before - pets_after
        
        if actually_traded > 0 then
            total_traded = total_traded + actually_traded
            updateUI("Trading to " .. username, total_traded .. "/" .. amount, "✅ Trade #" .. trade_number .. " complete!")
        else
            updateUI("Trade failed", total_traded .. "/" .. amount, "⚠️ Retrying...")
        end
        
        trade_number = trade_number + 1
        task.wait(2)
    end
    
    updateUI("✅ Complete!", total_traded .. "/" .. amount, "Traded to " .. username)
    return true
end

-- ============================================
-- MIXED PETS MODE TRADING
-- ============================================
local function trade_mixed_pets_to_user(username)
    updateUI("Trading mixed pets to " .. username, "", "Finding player...")
    
    while not findPlayer(username) do
        updateUI("Waiting for player...", "", username .. " not in server")
        task.wait(5)
    end
    
    local BATCH_SIZE = 18
    local trade_number = 1
    local totalTraded = {}
    local petTypeStats = {}
    
    for _, petConfig in ipairs(petsList) do
        totalTraded[petConfig.PET_KIND] = 0
        petTypeStats[petConfig.PET_KIND] = {
            collected = 0,
            target = petConfig.AMOUNT or math.huge
        }
    end
    
    while true do
        local progress_text = ""
        for _, petConfig in ipairs(petsList) do
            progress_text = progress_text .. petConfig.PET_NAME .. ": " .. totalTraded[petConfig.PET_KIND] .. " | "
        end
        
        updateUI("Trading to " .. username, progress_text, "Trade #" .. trade_number)
        
        local pets = get_mixed_pets(BATCH_SIZE, petTypeStats)
        
        if #pets == 0 then
            updateUI("✅ Complete!", progress_text, "All pets traded!")
            break
        end
        
        -- Send trade (infinite retry)
        while not send_trade(username) do
            updateUI("Waiting for player...", progress_text, username .. " not in server")
            task.wait(5)
        end
        
        task.wait(2)
        
        -- Wait for GUI (infinite retry)
        local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
        local timeout = 0
        while not tradeGui.Visible do
            task.wait(0.5)
            timeout = timeout + 0.5
            
            if timeout >= 10 then
                updateUI("Retrying...", progress_text, "Trade GUI didn't open")
                send_trade(username)
                timeout = 0
            end
        end
        
        -- Add pets
        updateUI("Trading to " .. username, progress_text, "Adding " .. #pets .. " pets...")
        local add_delay = CONFIG.NORMAL_MODE and 3.0 or 0.2
        for _, pet in ipairs(pets) do
            add_pet(pet.unique)
            task.wait(add_delay)
        end
        
        task.wait(6)
        
        if CONFIG.NORMAL_MODE then
            accept_trade()
            task.wait(20)
            confirm_trade()
            repeat task.wait(0.5) until not tradeGui.Visible
        else
            local accept_spam = true
            task.spawn(function()
                while accept_spam do pcall(accept_trade) task.wait(0.5) end
            end)
            
            task.wait(1)
            
            local confirm_spam = true
            task.spawn(function()
                while confirm_spam do pcall(confirm_trade) task.wait(0.5) end
            end)
            
            repeat task.wait(0.5) until not tradeGui.Visible
            
            accept_spam = false
            confirm_spam = false
        end
        
        for _, pet in ipairs(pets) do
            totalTraded[pet.kind] = totalTraded[pet.kind] + 1
        end
        
        trade_number = trade_number + 1
        task.wait(2)
    end
    
    return true
end

-- ============================================
-- MAIN EXECUTION
-- ============================================
local function run_trader()
    local total_users = #CONFIG.USERNAMES
    local successful = 0
    local failed = 0
    
    for i, username in ipairs(CONFIG.USERNAMES) do
        local success
        if MIXED_MODE then
            success = trade_mixed_pets_to_user(username)
        else
            local amount = CONFIG.AMOUNTS[i]
            success = trade_single_pet_to_user(username, amount)
        end
        
        if success then
            successful = successful + 1
        else
            failed = failed + 1
        end
        
        if i < total_users then
            task.wait(3)
        end
    end
    
    updateUI("🎉 ALL COMPLETE!", successful .. " successful, " .. failed .. " failed", "")
    
    if CONFIG.AUTO_KICK then
        task.wait(3)
        LocalPlayer:Kick("✅ Trading complete!")
    end
end

run_trader()
