-- ============================================
-- AUTO ACCEPT TRADES
-- Accepts all incoming trade requests from anyone
-- ============================================

repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer       = Players.LocalPlayer

-- ============================================
-- ANTI-AFK
-- ============================================
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)
print("✅ Anti-AFK enabled")

-- ============================================
-- DEHASH REMOTES
-- ============================================
print("🔧 Dehashing remotes...")
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
                print("[Dehash] ✅ Success at upvalue index " .. i)
                return
            end
        end
    end
    warn("[Dehash] ⚠️ Failed — no remote table found in upvalues")
end
dehash()
print("✅ Remotes dehashed!")

-- ============================================
-- AUTO ACCEPT
-- ============================================
local tradeGui  = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
local dialogApp = LocalPlayer.PlayerGui:WaitForChild("DialogApp")

print("\n✅ Auto-accept running — waiting for trades...")
print("==========================================")

-- Phase 1: Accept incoming trade requests
task.spawn(function()
    while task.wait(0.3) do
        pcall(function()
            local dialogVisible = dialogApp
                and dialogApp:FindFirstChild("Dialog")
                and dialogApp.Dialog.Visible

            if dialogVisible then
                print("\n📨 Trade request detected!")
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local ok = pcall(function()
                            ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest"):InvokeServer(player, true)
                        end)
                        if ok then
                            print("   ✅ Accepted from: " .. player.Name)
                        end
                        task.wait(0.2)
                    end
                end
            end
        end)
    end
end)

-- Phase 2: Accept negotiation
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            if tradeGui.Visible then
                ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
            end
        end)
    end
end)

-- Phase 3: Confirm trade
task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            if tradeGui.Visible then
                ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
            end
        end)
    end
end)

-- Trade open/close logger
task.spawn(function()
    local was_visible = false
    local trade_count = 0
    while task.wait(0.5) do
        pcall(function()
            if tradeGui.Visible and not was_visible then
                was_visible = true
                print("📋 Trade window opened")
            elseif not tradeGui.Visible and was_visible then
                was_visible = false
                trade_count = trade_count + 1
                print(string.format("✅ Trade #%d completed!", trade_count))
            end
        end)
    end
end)

while task.wait(10) do end
