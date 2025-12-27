-- ULTRA PREMIUM HOLDER GUI
-- Created by DevEx - Maximum Premium Edition

print("===========================================")
print("  ULTRA PREMIUM Pet Distribution System")
print("  Created by DevEx")
print("  Loading Legendary GUI...")
print("===========================================")

-- Wait for game to load
repeat task.wait() until game:IsLoaded()
repeat task.wait(1) until game:IsLoaded() and game:GetService("ReplicatedStorage"):FindFirstChild("ClientModules")
task.wait(2)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local holderName = LocalPlayer.Name

-- Create ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DevExPremiumGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Main Frame with Premium Design
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 500, 0, 670)  -- Increased height for queue section
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -335)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = false
MainFrame.Parent = ScreenGui

-- Animated Rainbow Gradient Border
local BorderGradient = Instance.new("UIGradient")
BorderGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 127)),
    ColorSequenceKeypoint.new(0.25, Color3.fromRGB(127, 0, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 127, 255)),
    ColorSequenceKeypoint.new(0.75, Color3.fromRGB(0, 255, 127)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 127))
}
BorderGradient.Rotation = 0

-- Animate rainbow gradient
task.spawn(function()
    while MainFrame.Parent do
        for i = 0, 360, 1 do
            if not MainFrame.Parent then break end
            BorderGradient.Rotation = i
            task.wait(0.02)
        end
    end
end)

-- Border Frame (Rainbow outline)
local BorderFrame = Instance.new("Frame")
BorderFrame.Size = UDim2.new(1, 6, 1, 6)
BorderFrame.Position = UDim2.new(0, -3, 0, -3)
BorderFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
BorderFrame.BorderSizePixel = 0
BorderFrame.ZIndex = 0
BorderFrame.Parent = MainFrame

local BorderCorner = Instance.new("UICorner")
BorderCorner.CornerRadius = UDim.new(0, 18)
BorderCorner.Parent = BorderFrame

BorderGradient.Parent = BorderFrame

-- Outer Glow Effect
local OuterGlow = Instance.new("ImageLabel")
OuterGlow.Size = UDim2.new(1, 60, 1, 60)
OuterGlow.Position = UDim2.new(0, -30, 0, -30)
OuterGlow.BackgroundTransparency = 1
OuterGlow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
OuterGlow.ImageColor3 = Color3.fromRGB(127, 0, 255)
OuterGlow.ImageTransparency = 0.3
OuterGlow.ScaleType = Enum.ScaleType.Slice
OuterGlow.SliceCenter = Rect.new(10, 10, 118, 118)
OuterGlow.ZIndex = -1
OuterGlow.Parent = MainFrame

-- Pulsing glow animation
task.spawn(function()
    while OuterGlow.Parent do
        TweenService:Create(OuterGlow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), 
            {ImageTransparency = 0.6}):Play()
        task.wait(2)
    end
end)

-- Corner rounding for main frame
local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 15)
MainCorner.Parent = MainFrame

-- Make draggable
local dragging = false
local dragStart = nil
local startPos = nil

MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

MainFrame.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- Content Background with animated gradient
local ContentBG = Instance.new("Frame")
ContentBG.Size = UDim2.new(1, 0, 1, 0)
ContentBG.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
ContentBG.BorderSizePixel = 0
ContentBG.Parent = MainFrame

local ContentCorner = Instance.new("UICorner")
ContentCorner.CornerRadius = UDim.new(0, 15)
ContentCorner.Parent = ContentBG

local ContentGradient = Instance.new("UIGradient")
ContentGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 15, 45)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 25, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 15, 40))
}
ContentGradient.Rotation = 45
ContentGradient.Parent = ContentBG

-- Animate content gradient
task.spawn(function()
    while ContentGradient.Parent do
        for i = 0, 360, 2 do
            if not ContentGradient.Parent then break end
            ContentGradient.Rotation = i
            task.wait(0.05)
        end
    end
end)

-- Header Section
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 100)
Header.BackgroundColor3 = Color3.fromRGB(15, 10, 30)
Header.BackgroundTransparency = 0.3
Header.BorderSizePixel = 0
Header.Parent = ContentBG

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 15)
HeaderCorner.Parent = Header

-- Pet Icon (Adopt Me style dog)
local PetIcon = Instance.new("TextLabel")
PetIcon.Size = UDim2.new(0, 70, 0, 70)
PetIcon.Position = UDim2.new(0, 15, 0, 15)
PetIcon.BackgroundColor3 = Color3.fromRGB(40, 20, 80)
PetIcon.BorderSizePixel = 0
PetIcon.Text = "🐕"
PetIcon.TextSize = 40
PetIcon.Font = Enum.Font.GothamBold
PetIcon.Parent = Header

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(0, 12)
IconCorner.Parent = PetIcon

local IconGradient = Instance.new("UIGradient")
IconGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 40, 160)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 80, 200))
}
IconGradient.Rotation = 45
IconGradient.Parent = PetIcon

-- Icon float animation
task.spawn(function()
    while PetIcon.Parent do
        TweenService:Create(PetIcon, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), 
            {Position = UDim2.new(0, 15, 0, 20)}):Play()
        task.wait(2)
    end
end)

-- Icon rotation
task.spawn(function()
    while PetIcon.Parent do
        for i = -10, 10, 1 do
            if not PetIcon.Parent then break end
            PetIcon.Rotation = i
            task.wait(0.05)
        end
        for i = 10, -10, -1 do
            if not PetIcon.Parent then break end
            PetIcon.Rotation = i
            task.wait(0.05)
        end
    end
end)

-- Title with premium font
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -200, 0, 35)
Title.Position = UDim2.new(0, 95, 0, 15)
Title.BackgroundTransparency = 1
Title.Text = "Pet Distribution"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 28
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.TextStrokeTransparency = 0.5
Title.TextStrokeColor3 = Color3.fromRGB(127, 0, 255)
Title.Parent = Header

local TitleGradient = Instance.new("UIGradient")
TitleGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(200, 150, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
}
TitleGradient.Parent = Title

-- Subtitle - Holder
local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -200, 0, 20)
Subtitle.Position = UDim2.new(0, 95, 0, 48)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "⚡ Holder Account"
Subtitle.TextColor3 = Color3.fromRGB(200, 180, 255)
Subtitle.TextSize = 14
Subtitle.Font = Enum.Font.GothamBold
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

-- Created by DevEx badge
local CreatedBy = Instance.new("TextLabel")
CreatedBy.Size = UDim2.new(0, 180, 0, 25)
CreatedBy.Position = UDim2.new(0, 95, 0, 68)
CreatedBy.BackgroundColor3 = Color3.fromRGB(40, 20, 80)
CreatedBy.BorderSizePixel = 0
CreatedBy.Text = "✨ Created by DevEx"
CreatedBy.TextColor3 = Color3.fromRGB(255, 215, 0)
CreatedBy.TextSize = 12
CreatedBy.Font = Enum.Font.GothamBold
CreatedBy.Parent = Header

local CreatedCorner = Instance.new("UICorner")
CreatedCorner.CornerRadius = UDim.new(0, 6)
CreatedCorner.Parent = CreatedBy

local CreatedGradient = Instance.new("UIGradient")
CreatedGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 30, 120)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 50, 150))
}
CreatedGradient.Rotation = 90
CreatedGradient.Parent = CreatedBy

-- Spinning money icon in top right
local MoneyIcon = Instance.new("TextLabel")
MoneyIcon.Size = UDim2.new(0, 50, 0, 50)
MoneyIcon.Position = UDim2.new(1, -115, 0, 10)
MoneyIcon.BackgroundTransparency = 1
MoneyIcon.Text = "💰"
MoneyIcon.TextSize = 40
MoneyIcon.Font = Enum.Font.GothamBold
MoneyIcon.Parent = Header

task.spawn(function()
    while MoneyIcon.Parent do
        for i = 0, 360, 4 do
            if not MoneyIcon.Parent then break end
            MoneyIcon.Rotation = i
            task.wait(0.01)
        end
    end
end)

-- Close Button (Premium style)
local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 40, 0, 40)
CloseButton.Position = UDim2.new(1, -50, 0, 10)
CloseButton.BackgroundColor3 = Color3.fromRGB(200, 40, 60)
CloseButton.BorderSizePixel = 0
CloseButton.Text = "X"  -- Changed from ✕ to X
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.TextSize = 22
CloseButton.Font = Enum.Font.GothamBold
CloseButton.Parent = Header

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(1, 0)
CloseCorner.Parent = CloseButton

local CloseGradient = Instance.new("UIGradient")
CloseGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 80)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40, 60))
}
CloseGradient.Rotation = 90
CloseGradient.Parent = CloseButton

CloseButton.MouseEnter:Connect(function()
    TweenService:Create(CloseButton, TweenInfo.new(0.2), {Size = UDim2.new(0, 45, 0, 45), Rotation = 90}):Play()
end)

CloseButton.MouseLeave:Connect(function()
    TweenService:Create(CloseButton, TweenInfo.new(0.2), {Size = UDim2.new(0, 40, 0, 40), Rotation = 0}):Play()
end)

CloseButton.MouseButton1Click:Connect(function()
    TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), 
        {Size = UDim2.new(0, 0, 0, 0), Rotation = 180}):Play()
    TweenService:Create(MainFrame, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
    task.wait(0.5)
    ScreenGui:Destroy()
end)

-- Content Container (Changed from ScrollingFrame to Frame)
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -40, 1, -130)
Container.Position = UDim2.new(0, 20, 0, 110)
Container.BackgroundTransparency = 1
Container.BorderSizePixel = 0
Container.ClipsDescendants = true
Container.Parent = ContentBG

-- Pet Remote ID Section
local PetSection = Instance.new("Frame")
PetSection.Size = UDim2.new(1, 0, 0, 90)
PetSection.BackgroundTransparency = 1
PetSection.Parent = Container

local PetLabel = Instance.new("TextLabel")
PetLabel.Size = UDim2.new(1, 0, 0, 25)
PetLabel.BackgroundTransparency = 1
PetLabel.Text = "🐾 Pet Remote ID"
PetLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
PetLabel.TextSize = 16
PetLabel.Font = Enum.Font.GothamBold
PetLabel.TextXAlignment = Enum.TextXAlignment.Left
PetLabel.TextStrokeTransparency = 0.8
PetLabel.Parent = PetSection

local PetInput = Instance.new("TextBox")
PetInput.Size = UDim2.new(1, 0, 0, 45)
PetInput.Position = UDim2.new(0, 0, 0, 30)
PetInput.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
PetInput.BorderColor3 = Color3.fromRGB(100, 50, 200)
PetInput.BorderSizePixel = 3
PetInput.PlaceholderText = "Enter pet remote ID..."
PetInput.PlaceholderColor3 = Color3.fromRGB(100, 80, 150)
PetInput.Text = "moon_2025_snorgle"
PetInput.TextColor3 = Color3.fromRGB(255, 255, 255)
PetInput.TextSize = 15
PetInput.Font = Enum.Font.GothamBold
PetInput.Parent = PetSection

local PetCorner = Instance.new("UICorner")
PetCorner.CornerRadius = UDim.new(0, 10)
PetCorner.Parent = PetInput

local PetGradient = Instance.new("UIGradient")
PetGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 20, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 25, 60))
}
PetGradient.Rotation = 90
PetGradient.Parent = PetInput

PetInput.Focused:Connect(function()
    TweenService:Create(PetInput, TweenInfo.new(0.3), {
        BorderColor3 = Color3.fromRGB(180, 100, 255),
        Size = UDim2.new(1, 5, 0, 48)
    }):Play()
end)

PetInput.FocusLost:Connect(function()
    TweenService:Create(PetInput, TweenInfo.new(0.3), {
        BorderColor3 = Color3.fromRGB(100, 50, 200),
        Size = UDim2.new(1, 0, 0, 45)
    }):Play()
end)

-- Rarity Section
local RaritySection = Instance.new("Frame")
RaritySection.Size = UDim2.new(1, 0, 0, 90)
RaritySection.Position = UDim2.new(0, 0, 0, 100)
RaritySection.BackgroundTransparency = 1
RaritySection.Parent = Container

local RarityLabel = Instance.new("TextLabel")
RarityLabel.Size = UDim2.new(1, 0, 0, 25)
RarityLabel.BackgroundTransparency = 1
RarityLabel.Text = "✨ Pet Rarity"
RarityLabel.TextColor3 = Color3.fromRGB(220, 200, 255)
RarityLabel.TextSize = 16
RarityLabel.Font = Enum.Font.GothamBold
RarityLabel.TextXAlignment = Enum.TextXAlignment.Left
RarityLabel.TextStrokeTransparency = 0.8
RarityLabel.Parent = RaritySection

local RarityButton = Instance.new("TextButton")
RarityButton.Size = UDim2.new(1, 0, 0, 45)
RarityButton.Position = UDim2.new(0, 0, 0, 30)
RarityButton.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
RarityButton.BorderColor3 = Color3.fromRGB(100, 50, 200)
RarityButton.BorderSizePixel = 3
RarityButton.Text = "Uncommon ▼"
RarityButton.TextColor3 = Color3.fromRGB(255, 255, 255)
RarityButton.TextSize = 15
RarityButton.Font = Enum.Font.GothamBold
RarityButton.Parent = RaritySection

local RarityCorner = Instance.new("UICorner")
RarityCorner.CornerRadius = UDim.new(0, 10)
RarityCorner.Parent = RarityButton

local RarityGradient = Instance.new("UIGradient")
RarityGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 20, 50)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 25, 60))
}
RarityGradient.Rotation = 90
RarityGradient.Parent = RarityButton

local rarities = {"Common", "Uncommon", "Rare", "Ultra-Rare", "Legendary"}
local currentRarity = 2

RarityButton.MouseEnter:Connect(function()
    TweenService:Create(RarityButton, TweenInfo.new(0.2), {Size = UDim2.new(1, 5, 0, 48)}):Play()
end)

RarityButton.MouseLeave:Connect(function()
    TweenService:Create(RarityButton, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 45)}):Play()
end)

RarityButton.MouseButton1Click:Connect(function()
    currentRarity = currentRarity + 1
    if currentRarity > #rarities then currentRarity = 1 end
    RarityButton.Text = rarities[currentRarity] .. " ▼"
    
    -- Flash effect
    local flash = TweenService:Create(RarityGradient, TweenInfo.new(0.2), {
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 80, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 100, 255))
        }
    })
    flash:Play()
    flash.Completed:Connect(function()
        TweenService:Create(RarityGradient, TweenInfo.new(0.3), {
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 20, 50)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 25, 60))
            }
        }):Play()
    end)
end)

-- Neon Toggle Section
local NeonSection = Instance.new("Frame")
NeonSection.Size = UDim2.new(1, 0, 0, 55)
NeonSection.Position = UDim2.new(0, 0, 0, 200)
NeonSection.BackgroundTransparency = 1
NeonSection.Parent = Container

local NeonToggle = Instance.new("TextButton")
NeonToggle.Size = UDim2.new(1, 0, 0, 50)
NeonToggle.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
NeonToggle.BorderSizePixel = 0
NeonToggle.Text = "🔘 Normals Only"
NeonToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
NeonToggle.TextSize = 17
NeonToggle.Font = Enum.Font.GothamBold
NeonToggle.Parent = NeonSection

local NeonCorner = Instance.new("UICorner")
NeonCorner.CornerRadius = UDim.new(0, 12)
NeonCorner.Parent = NeonToggle

local NeonGradient = Instance.new("UIGradient")
NeonGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 40, 70)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 50, 80))
}
NeonGradient.Rotation = 90
NeonGradient.Parent = NeonToggle

local neonsOnly = false

NeonToggle.MouseEnter:Connect(function()
    TweenService:Create(NeonToggle, TweenInfo.new(0.2), {Size = UDim2.new(1, 8, 0, 53)}):Play()
end)

NeonToggle.MouseLeave:Connect(function()
    TweenService:Create(NeonToggle, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 50)}):Play()
end)

NeonToggle.MouseButton1Click:Connect(function()
    neonsOnly = not neonsOnly
    if neonsOnly then
        NeonToggle.Text = "✨ Neons Only"
        NeonGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 50, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255))
        }
    else
        NeonToggle.Text = "🔘 Normals Only"
        NeonGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 40, 70)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 50, 80))
        }
    end
    
    -- Pulse animation
    TweenService:Create(NeonToggle, TweenInfo.new(0.15), {Size = UDim2.new(1, 15, 0, 55)}):Play()
    task.wait(0.15)
    TweenService:Create(NeonToggle, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 50)}):Play()
end)

-- Start Button (MEGA PREMIUM)
local StartSection = Instance.new("Frame")
StartSection.Size = UDim2.new(1, 0, 0, 70)
StartSection.Position = UDim2.new(0, 0, 0, 265)
StartSection.BackgroundTransparency = 1
StartSection.Parent = Container

local StartButton = Instance.new("TextButton")
StartButton.Size = UDim2.new(1, 0, 0, 60)
StartButton.BackgroundColor3 = Color3.fromRGB(40, 200, 100)
StartButton.BorderSizePixel = 0
StartButton.Text = "▶ START HOLDER"
StartButton.TextColor3 = Color3.fromRGB(255, 255, 255)
StartButton.TextSize = 20
StartButton.Font = Enum.Font.GothamBold
StartButton.TextStrokeTransparency = 0.5
StartButton.Parent = StartSection

local StartCorner = Instance.new("UICorner")
StartCorner.CornerRadius = UDim.new(0, 15)
StartCorner.Parent = StartButton

local StartGradient = Instance.new("UIGradient")
StartGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 255, 120)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(40, 200, 100)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 150, 80))
}
StartGradient.Rotation = 90
StartGradient.Parent = StartButton

-- Mega glow effect
local StartGlow = Instance.new("ImageLabel")
StartGlow.Size = UDim2.new(1, 40, 1, 40)
StartGlow.Position = UDim2.new(0, -20, 0, -20)
StartGlow.BackgroundTransparency = 1
StartGlow.Image = "rbxasset://textures/ui/GuiImagePlaceholder.png"
StartGlow.ImageColor3 = Color3.fromRGB(60, 255, 120)
StartGlow.ImageTransparency = 1
StartGlow.ScaleType = Enum.ScaleType.Slice
StartGlow.SliceCenter = Rect.new(10, 10, 118, 118)
StartGlow.ZIndex = 0
StartGlow.Parent = StartButton

StartButton.MouseEnter:Connect(function()
    TweenService:Create(StartButton, TweenInfo.new(0.3), {Size = UDim2.new(1, 10, 0, 65)}):Play()
    TweenService:Create(StartGlow, TweenInfo.new(0.4), {ImageTransparency = 0.5}):Play()
    
    -- Rainbow pulse
    task.spawn(function()
        while StartGlow.ImageTransparency < 0.9 do
            for i = 0, 360, 20 do
                if StartGlow.ImageTransparency >= 0.9 then break end
                local hue = i / 360
                StartGlow.ImageColor3 = Color3.fromHSV(hue, 1, 1)
                task.wait(0.05)
            end
        end
        StartGlow.ImageColor3 = Color3.fromRGB(60, 255, 120)
    end)
end)

StartButton.MouseLeave:Connect(function()
    TweenService:Create(StartButton, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 0, 60)}):Play()
    TweenService:Create(StartGlow, TweenInfo.new(0.4), {ImageTransparency = 1}):Play()
end)

-- Status Label (Premium style)
local StatusSection = Instance.new("Frame")
StatusSection.Size = UDim2.new(1, 0, 0, 60)
StatusSection.Position = UDim2.new(0, 0, 0, 345)
StatusSection.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
StatusSection.BackgroundTransparency = 0.5
StatusSection.BorderSizePixel = 0
StatusSection.Parent = Container

local StatusCorner = Instance.new("UICorner")
StatusCorner.CornerRadius = UDim.new(0, 10)
StatusCorner.Parent = StatusSection

local StatusIcon = Instance.new("TextLabel")
StatusIcon.Size = UDim2.new(0, 40, 0, 40)
StatusIcon.Position = UDim2.new(0, 10, 0, 10)
StatusIcon.BackgroundTransparency = 1
StatusIcon.Text = "⏸️"
StatusIcon.TextSize = 28
StatusIcon.Font = Enum.Font.GothamBold
StatusIcon.Parent = StatusSection

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -60, 1, 0)
StatusLabel.Position = UDim2.new(0, 55, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Waiting to start..."
StatusLabel.TextColor3 = Color3.fromRGB(180, 160, 200)
StatusLabel.TextSize = 14
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextYAlignment = Enum.TextYAlignment.Center
StatusLabel.Parent = StatusSection

-- Queue & Progress Section
local QueueSection = Instance.new("Frame")
QueueSection.Size = UDim2.new(1, 0, 0, 120)
QueueSection.Position = UDim2.new(0, 0, 0, 415)
QueueSection.BackgroundColor3 = Color3.fromRGB(25, 20, 40)
QueueSection.BackgroundTransparency = 0.3
QueueSection.BorderSizePixel = 0
QueueSection.Visible = false  -- Hidden until started
QueueSection.Parent = Container

local QueueCorner = Instance.new("UICorner")
QueueCorner.CornerRadius = UDim.new(0, 12)
QueueCorner.Parent = QueueSection

-- Queue Title
local QueueTitle = Instance.new("TextLabel")
QueueTitle.Size = UDim2.new(1, -20, 0, 25)
QueueTitle.Position = UDim2.new(0, 10, 0, 10)
QueueTitle.BackgroundTransparency = 1
QueueTitle.Text = "📊 Queue & Progress"
QueueTitle.TextColor3 = Color3.fromRGB(220, 200, 255)
QueueTitle.TextSize = 15
QueueTitle.Font = Enum.Font.GothamBold
QueueTitle.TextXAlignment = Enum.TextXAlignment.Left
QueueTitle.Parent = QueueSection

-- Stats Container
local StatsContainer = Instance.new("Frame")
StatsContainer.Size = UDim2.new(1, -20, 0, 80)
StatsContainer.Position = UDim2.new(0, 10, 0, 35)
StatsContainer.BackgroundTransparency = 1
StatsContainer.Parent = QueueSection

-- Stat 1: Completed
local CompletedStat = Instance.new("Frame")
CompletedStat.Size = UDim2.new(0.33, -5, 1, 0)
CompletedStat.Position = UDim2.new(0, 0, 0, 0)
CompletedStat.BackgroundColor3 = Color3.fromRGB(30, 100, 60)
CompletedStat.BorderSizePixel = 0
CompletedStat.Parent = StatsContainer

local CompletedCorner = Instance.new("UICorner")
CompletedCorner.CornerRadius = UDim.new(0, 8)
CompletedCorner.Parent = CompletedStat

local CompletedGradient = Instance.new("UIGradient")
CompletedGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 150, 80)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 100, 50))
}
CompletedGradient.Rotation = 90
CompletedGradient.Parent = CompletedStat

local CompletedLabel = Instance.new("TextLabel")
CompletedLabel.Size = UDim2.new(1, 0, 0, 25)
CompletedLabel.Position = UDim2.new(0, 0, 0, 10)
CompletedLabel.BackgroundTransparency = 1
CompletedLabel.Text = "✓ Completed"
CompletedLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
CompletedLabel.TextSize = 12
CompletedLabel.Font = Enum.Font.GothamBold
CompletedLabel.Parent = CompletedStat

local CompletedValue = Instance.new("TextLabel")
CompletedValue.Size = UDim2.new(1, 0, 0, 35)
CompletedValue.Position = UDim2.new(0, 0, 0, 35)
CompletedValue.BackgroundTransparency = 1
CompletedValue.Text = "0"
CompletedValue.TextColor3 = Color3.fromRGB(255, 255, 255)
CompletedValue.TextSize = 24
CompletedValue.Font = Enum.Font.GothamBold
CompletedValue.Parent = CompletedStat

-- Stat 2: In Queue
local QueueStat = Instance.new("Frame")
QueueStat.Size = UDim2.new(0.33, -5, 1, 0)
QueueStat.Position = UDim2.new(0.33, 2.5, 0, 0)
QueueStat.BackgroundColor3 = Color3.fromRGB(80, 60, 150)
QueueStat.BorderSizePixel = 0
QueueStat.Parent = StatsContainer

local QueueStatCorner = Instance.new("UICorner")
QueueStatCorner.CornerRadius = UDim.new(0, 8)
QueueStatCorner.Parent = QueueStat

local QueueGradient = Instance.new("UIGradient")
QueueGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 80, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 60, 150))
}
QueueGradient.Rotation = 90
QueueGradient.Parent = QueueStat

local QueueStatLabel = Instance.new("TextLabel")
QueueStatLabel.Size = UDim2.new(1, 0, 0, 25)
QueueStatLabel.Position = UDim2.new(0, 0, 0, 10)
QueueStatLabel.BackgroundTransparency = 1
QueueStatLabel.Text = "⏳ In Queue"
QueueStatLabel.TextColor3 = Color3.fromRGB(200, 180, 255)
QueueStatLabel.TextSize = 12
QueueStatLabel.Font = Enum.Font.GothamBold
QueueStatLabel.Parent = QueueStat

local QueueValue = Instance.new("TextLabel")
QueueValue.Size = UDim2.new(1, 0, 0, 35)
QueueValue.Position = UDim2.new(0, 0, 0, 35)
QueueValue.BackgroundTransparency = 1
QueueValue.Text = "0"
QueueValue.TextColor3 = Color3.fromRGB(255, 255, 255)
QueueValue.TextSize = 24
QueueValue.Font = Enum.Font.GothamBold
QueueValue.Parent = QueueStat

-- Stat 3: Total Scanned
local ScannedStat = Instance.new("Frame")
ScannedStat.Size = UDim2.new(0.33, -5, 1, 0)
ScannedStat.Position = UDim2.new(0.66, 5, 0, 0)
ScannedStat.BackgroundColor3 = Color3.fromRGB(60, 80, 150)
ScannedStat.BorderSizePixel = 0
ScannedStat.Parent = StatsContainer

local ScannedCorner = Instance.new("UICorner")
ScannedCorner.CornerRadius = UDim.new(0, 8)
ScannedCorner.Parent = ScannedStat

local ScannedGradient = Instance.new("UIGradient")
ScannedGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 120, 200)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 80, 150))
}
ScannedGradient.Rotation = 90
ScannedGradient.Parent = ScannedStat

local ScannedLabel = Instance.new("TextLabel")
ScannedLabel.Size = UDim2.new(1, 0, 0, 25)
ScannedLabel.Position = UDim2.new(0, 0, 0, 10)
ScannedLabel.BackgroundTransparency = 1
ScannedLabel.Text = "👁️ Scanned"
ScannedLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
ScannedLabel.TextSize = 12
ScannedLabel.Font = Enum.Font.GothamBold
ScannedLabel.Parent = ScannedStat

local ScannedValue = Instance.new("TextLabel")
ScannedValue.Size = UDim2.new(1, 0, 0, 35)
ScannedValue.Position = UDim2.new(0, 0, 0, 35)
ScannedValue.BackgroundTransparency = 1
ScannedValue.Text = "0"
ScannedValue.TextColor3 = Color3.fromRGB(255, 255, 255)
ScannedValue.TextSize = 24
ScannedValue.Font = Enum.Font.GothamBold
ScannedValue.Parent = ScannedStat

-- Animated status dots
task.spawn(function()
    local dots = 0
    while StatusLabel.Parent do
        if StatusLabel.Text:find("%.%.%.") then
            dots = (dots + 1) % 4
            StatusLabel.Text = StatusLabel.Text:gsub("%.+$", string.rep(".", dots))
        end
        task.wait(0.5)
    end
end)

-- Particles background effect
local function createParticle()
    local particle = Instance.new("Frame")
    particle.Size = UDim2.new(0, math.random(2, 6), 0, math.random(2, 6))
    particle.Position = UDim2.new(math.random(), 0, 1.1, 0)
    particle.BackgroundColor3 = Color3.fromHSV(math.random(), 0.8, 1)
    particle.BackgroundTransparency = 0.3
    particle.BorderSizePixel = 0
    particle.ZIndex = -1
    particle.Parent = ContentBG
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = particle
    
    TweenService:Create(particle, TweenInfo.new(math.random(3, 6), Enum.EasingStyle.Linear), 
        {Position = UDim2.new(math.random(), 0, -0.1, 0), BackgroundTransparency = 1}):Play()
    
    task.delay(6, function()
        particle:Destroy()
    end)
end

-- Spawn particles
task.spawn(function()
    while ContentBG.Parent do
        createParticle()
        task.wait(0.3)
    end
end)

-- Entrance animation (EPIC)
MainFrame.Size = UDim2.new(0, 0, 0, 0)
MainFrame.Rotation = -180
MainFrame.BackgroundTransparency = 1

TweenService:Create(MainFrame, TweenInfo.new(0.8, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 500, 0, 670),  -- Updated to match new size
    Rotation = 0,
    BackgroundTransparency = 0
}):Play()

print("✅ ULTRA PREMIUM GUI Created!")

-- ============================================
-- HOLDER SCRIPT LOGIC (Same as before)
-- ============================================

local scriptStarted = false

StartButton.MouseButton1Click:Connect(function()
    if scriptStarted then return end
    scriptStarted = true
    
    -- Transform button
    StartGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 100, 100)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 80, 80))
    }
    StartButton.Text = "✓ RUNNING"
    StatusIcon.Text = "🚀"
    StatusLabel.Text = "Starting holder script..."
    StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    
    -- Get config from GUI
    local CONFIG = {
        PET_REMOTE_ID = PetInput.Text,
        RARITY = rarities[currentRarity]:lower(),
        NEONS_ONLY = neonsOnly,
        WEBHOOK_URL = ""
    }
    
    print("\n===========================================")
    print("  HOLDER STARTED")
    print("  Created by DevEx")
    print("===========================================")
    print("Pet: " .. CONFIG.PET_REMOTE_ID)
    print("Rarity: " .. CONFIG.RARITY:upper())
    print("Neon Filter: " .. (CONFIG.NEONS_ONLY and "NEONS ONLY" or "NORMALS ONLY"))
    print("===========================================")
    
    -- Dehash remotes
    StatusIcon.Text = "🔧"
    StatusLabel.Text = "Dehashing remotes..."
    
    for i, v in pairs(debug.getupvalue(require(ReplicatedStorage.ClientModules.Core.RouterClient.RouterClient).init, 7)) do
        v.Name = i
    end
    
    -- Enter game
    StatusIcon.Text = "🏠"
    StatusLabel.Text = "Entering game..."
    
    local UIManager = require(ReplicatedStorage.Fsys).load("UIManager")
    local args = {[1] = "Parents", [2] = {["source_for_logging"] = "intro_sequence"}}
    ReplicatedStorage:WaitForChild("API"):WaitForChild("TeamAPI/ChooseTeam"):InvokeServer(unpack(args))
    task.wait(1)
    UIManager.set_app_visibility("MainMenuApp", false)
    UIManager.set_app_visibility("NewsApp", false)
    task.wait(2)
    
    -- [SAME LOGIC AS HOLDER_FINAL.lua - All the trading functions]
    
    local RARITY_COSTS = {
        ["common"] = 1,
        ["uncommon"] = 2,
        ["rare"] = 2,
        ["ultra-rare"] = 4,
        ["legendary"] = 7
    }
    
    local Data = require(ReplicatedStorage.ClientModules.Core.ClientData)
    local processing = false
    local processed_accounts = {}
    
    local function get_pet_uniques(count)
        local playerData = Data.get_data()[holderName]
        if not playerData or not playerData.inventory or not playerData.inventory.pets then return {} end
        
        local foundPets = {}
        for _, pet in pairs(playerData.inventory.pets) do
            if pet.kind == CONFIG.PET_REMOTE_ID and not pet.is_egg then
                local petIsNeon = pet.properties and pet.properties.neon or false
                if CONFIG.NEONS_ONLY then
                    if petIsNeon then table.insert(foundPets, pet.unique) end
                else
                    if not petIsNeon then table.insert(foundPets, pet.unique) end
                end
                if #foundPets >= count then break end
            end
        end
        return foundPets
    end
    
    local function send_trade(username)
        local target = Players:FindFirstChild(username)
        if not target then return false end
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/SendTradeRequest"):FireServer(target)
        return true
    end
    
    local function add_items_in_trade(unique)
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(unique)
    end
    
    local function first_trade_accept()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
    end
    
    local function confirm_trade()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
    end
    
    local function auto_trade(username, pets_unique_ids)
        local tradeGui = LocalPlayer.PlayerGui:WaitForChild("TradeApp").Frame
        local trade_status = false
        local attempts = 0
        
        repeat
            if #pets_unique_ids > 0 and not tradeGui.Visible then
                trade_status = false
                send_trade(username)
                task.wait(2)
            elseif not trade_status and tradeGui.Visible then
                local counter = 0
                while #pets_unique_ids > 0 and counter < 18 do
                    add_items_in_trade(table.remove(pets_unique_ids, 1))
                    counter = counter + 1
                    task.wait(0.5)
                end
                trade_status = true
                repeat
                    task.wait(0.5)
                    pcall(first_trade_accept)
                    pcall(confirm_trade)
                until not tradeGui.Visible
                trade_status = false
                if #pets_unique_ids > 0 then task.wait(2) end
            else
                task.wait(1)
            end
            attempts = attempts + 1
            if attempts > 100 then break end
        until #pets_unique_ids == 0
        
        return #pets_unique_ids == 0
    end
    
    local function parseFile(content)
        local data = {}
        for line in content:gmatch("[^\n]+") do
            local key, value = line:match("([^=]+)=(.+)")
            if key and value then data[key] = tonumber(value) or value end
        end
        return data
    end
    
    local function process_request(filename, requestData)
        if processed_accounts[requestData.username] or processing then return end
        processing = true
        
        StatusIcon.Text = "📋"
        StatusLabel.Text = "Trading to " .. requestData.username .. "..."
        
        if not Players:FindFirstChild(requestData.username) then
            processing = false
            StatusLabel.Text = "⚠️ Player not in server"
            return
        end
        
        local potion_cost = RARITY_COSTS[string.lower(CONFIG.RARITY)]
        local pets_needed = math.floor(requestData.potions / potion_cost)
        
        if pets_needed == 0 then
            processing = false
            return
        end
        
        local pets = get_pet_uniques(pets_needed)
        if #pets == 0 then
            processing = false
            StatusIcon.Text = "❌"
            StatusLabel.Text = "No pets found!"
            return
        end
        
        if auto_trade(requestData.username, pets) then
            processed_accounts[requestData.username] = true
            delfile(filename)
            StatusIcon.Text = "✅"
            StatusLabel.Text = "Traded " .. #pets .. " pets to " .. requestData.username
        end
        
        processing = false
    end
    
    -- Scanner
    StatusIcon.Text = "🔍"
    StatusLabel.Text = "Scanning for receiver files..."
    QueueSection.Visible = true  -- Show queue section when started
    
    local totalScanned = 0
    local queueList = {}  -- Track files in queue
    
    task.spawn(function()
        while task.wait(3) do
            if processing then continue end
            
            pcall(function()
                -- Scan all players
                totalScanned = 0
                queueList = {}
                
                for _, player in pairs(Players:GetPlayers()) do
                    if player.Name == holderName then continue end
                    
                    totalScanned = totalScanned + 1
                    
                    if processed_accounts[player.Name] then continue end
                    
                    local filename = "receiver_" .. player.Name .. ".txt"
                    if isfile(filename) then
                        local content = readfile(filename)
                        local requestData = parseFile(content)
                        if requestData.username and requestData.potions and requestData.status == "pending" then
                            table.insert(queueList, player.Name)
                        end
                    end
                end
                
                -- Update stats
                ScannedValue.Text = tostring(totalScanned)
                QueueValue.Text = tostring(#queueList)
                CompletedValue.Text = tostring(#processed_accounts)
                
                -- Process first in queue
                if #queueList > 0 then
                    local nextUser = queueList[1]
                    local filename = "receiver_" .. nextUser .. ".txt"
                    local content = readfile(filename)
                    local requestData = parseFile(content)
                    
                    process_request(filename, requestData)
                    task.wait(5)
                end
            end)
            
            if not processing then
                StatusIcon.Text = "👀"
                StatusLabel.Text = "Scanning... (" .. #processed_accounts .. " completed, " .. #queueList .. " in queue)"
            end
        end
    end)
end)

print("✅ ULTRA PREMIUM GUI Ready!")
print("Created by DevEx - Maximum Premium Edition")
