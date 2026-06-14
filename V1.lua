-- ============================================================
--  RAGDOLL SCRIPT v3.2 — FULLY STABLE
--  R6 + R15 | Better compatibility & physics
-- ============================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Hum = Char:WaitForChild("Humanoid")

local Active = false
local MotorSave = {}
local Created = {}
local CollideSave = {}

local SKIP_MOTOR = {
    RootJoint = true, Root = true, ["Root Hip"] = true,
    ["HumanoidRootPart"] = true
}

-- Balanced joint limits for good floppy feel
local JOINT_ANGLES = {
    -- R15
    Neck = 42, Waist = 28,
    LeftShoulder = 105, RightShoulder = 105,
    LeftElbow = 80, RightElbow = 80,
    LeftWrist = 50, RightWrist = 50,
    LeftHip = 92, RightHip = 92,
    LeftKnee = 88, RightKnee = 88,
    LeftAnkle = 38, RightAnkle = 38,

    -- R6
    ["Left Shoulder"] = 100, ["Right Shoulder"] = 100,
    ["Left Hip"] = 92, ["Right Hip"] = 92,
    ["Left Knee"] = 88, ["Right Knee"] = 88,
    ["Left Ankle"] = 38, ["Right Ankle"] = 38,
}

local function GetAngle(name)
    return JOINT_ANGLES[name] or 55
end

local function Ragdoll()
    if Active then return end
    Active = true
    MotorSave, Created, CollideSave = {}, {}, {}

    local hrp = Char:FindFirstChild("HumanoidRootPart")
    local initialVel = hrp and hrp.AssemblyLinearVelocity or Vector3.zero

    pcall(function()
        Hum.PlatformStand = true
        Hum:ChangeState(Enum.HumanoidStateType.Physics)
    end)

    -- Save collision states
    for _, p in ipairs(Char:GetDescendants()) do
        if p:IsA("BasePart") then
            CollideSave[p] = p.CanCollide
        end
    end

    -- Network ownership
    pcall(function()
        for _, p in ipairs(Char:GetDescendants()) do
            if p:IsA("BasePart") and p \~= hrp then
                p:SetNetworkOwner(LP)
            end
        end
    end)

    -- Convert Motor6D to BallSocketConstraint
    for _, obj in ipairs(Char:GetDescendants()) do
        if obj:IsA("Motor6D") and obj.Part0 and obj.Part1 and not SKIP_MOTOR[obj.Name] then
            table.insert(MotorSave, {motor = obj, wasEnabled = obj.Enabled})

            local a0 = Instance.new("Attachment")
            a0.CFrame = obj.C0
            a0.Parent = obj.Part0

            local a1 = Instance.new("Attachment")
            a1.CFrame = obj.C1
            a1.Parent = obj.Part1

            local bsc = Instance.new("BallSocketConstraint")
            bsc.Attachment0 = a0
            bsc.Attachment1 = a1
            bsc.LimitsEnabled = true
            bsc.UpperAngle = GetAngle(obj.Name)
            bsc.Restitution = 0.25
            bsc.Damping = 0.6
            bsc.MaxFrictionTorque = 1.2

            if string.find(obj.Name:lower(), "neck") then
                bsc.TwistLimitsEnabled = true
                bsc.TwistUpperAngle = 55
                bsc.TwistLowerAngle = -55
            end

            bsc.Parent = obj.Part0
            obj.Enabled = false

            table.insert(Created, a0)
            table.insert(Created, a1)
            table.insert(Created, bsc)
        end
    end

    -- Enable limb collisions
    for _, p in ipairs(Char:GetDescendants()) do
        if p:IsA("BasePart") and p.Name \~= "HumanoidRootPart" then
            p.CanCollide = true
        end
    end

    -- Initial flail
    task.defer(function()
        if not Active then return end
        for _, p in ipairs(Char:GetDescendants()) do
            if p:IsA("BasePart") and p \~= hrp then
                p.AssemblyLinearVelocity = initialVel + Vector3.new(math.random(-8,8), math.random(4,14), math.random(-8,8))
            end
        end
    end)
end

local function Unragdoll()
    if not Active then return end
    Active = false

    pcall(function() Hum.PlatformStand = false end)

    -- Restore motors
    for _, d in ipairs(MotorSave) do
        pcall(function()
            if d.motor and d.motor.Parent then
                d.motor.Enabled = d.wasEnabled
            end
        end)
    end

    -- Destroy constraints
    for _, obj in ipairs(Created) do
        pcall(function() if obj and obj.Parent then obj:Destroy() end end)
    end

    -- Restore collisions
    for part, state in pairs(CollideSave) do
        pcall(function()
            if part and part.Parent then
                part.CanCollide = state
            end
        end)
    end

    task.delay(0.15, function()
        if Hum and not Active then
            pcall(function() Hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        end
    end)

    MotorSave = {}
    Created = {}
    CollideSave = {}
end

local function Toggle()
    if Active then Unragdoll() else Ragdoll() end
end

-- Respawn handling
LP.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    Char = newChar
    Hum = newChar:WaitForChild("Humanoid", 5)
    Active = false
end)

-- ============================================================
--  UI
-- ============================================================

pcall(function() CoreGui:FindFirstChild("RagdollGui"):Destroy() end)
pcall(function() LP.PlayerGui:FindFirstChild("RagdollGui"):Destroy() end)

local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local BTN_SIZE = isMobile and 58 or 48

local Gui = Instance.new("ScreenGui")
Gui.Name = "RagdollGui"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 999
Gui.Parent = CoreGui:FindFirstChild("RobloxGui") or LP.PlayerGui

local Root = Instance.new("Frame")
Root.Size = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
Root.Position = isMobile and UDim2.new(0, 16, 1, -140) or UDim2.new(0, 65, 1, -60)
Root.BackgroundTransparency = 1
Root.Parent = Gui

local Btn = Instance.new("TextButton")
Btn.Size = UDim2.new(1, 0, 1, 0)
Btn.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
Btn.Text = ""
Btn.AutoButtonColor = false
Btn.ClipsDescendants = true
Btn.Parent = Root

Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 14)

local stroke = Instance.new("UIStroke", Btn)
stroke.Color = Color3.fromRGB(80, 80, 90)
stroke.Thickness = 1.4

local Icon = Instance.new("TextLabel", Btn)
Icon.Size = UDim2.new(1, 0, 1, 0)
Icon.BackgroundTransparency = 1
Icon.Text = "🦴"
Icon.TextScaled = true
Icon.Font = Enum.Font.GothamBold
Icon.TextColor3 = Color3.fromRGB(255, 255, 255)

-- Tooltip
local TipFrame = Instance.new("Frame")
TipFrame.Size = UDim2.new(0, 110, 0, 28)
TipFrame.Position = isMobile and UDim2.new(0, 0, 0, -38) or UDim2.new(1, 8, 0.5, -14)
TipFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
TipFrame.Visible = false
TipFrame.Parent = Btn

Instance.new("UICorner", TipFrame).CornerRadius = UDim.new(0, 8)

local TipTxt = Instance.new("TextLabel", TipFrame)
TipTxt.Size = UDim2.new(1, -12, 1, 0)
TipTxt.Position = UDim2.new(0, 6, 0, 0)
TipTxt.BackgroundTransparency = 1
TipTxt.Text = "Ragdoll [R]"
TipTxt.TextColor3 = Color3.fromRGB(220, 220, 230)
TipTxt.TextScaled = true
TipTxt.Font = Enum.Font.GothamSemibold
TipTxt.TextXAlignment = Enum.TextXAlignment.Left

-- Colors
local C_IDLE   = Color3.fromRGB(28, 28, 30)
local C_HOVER  = Color3.fromRGB(55, 55, 62)
local C_ACTIVE = Color3.fromRGB(170, 30, 30)

local currentTween = nil
local isHovered = false

local function RefreshColor()
    local target = Active and C_ACTIVE or (isHovered and C_HOVER or C_IDLE)
    if currentTween then currentTween:Cancel() end
    currentTween = TweenService:Create(Btn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = target})
    currentTween:Play()
end

local function UpdateUI()
    TipTxt.Text = Active and "Stand Up [R]" or "Ragdoll [R]"
    RefreshColor()
end

if not isMobile then
    Btn.MouseEnter:Connect(function() isHovered = true; TipFrame.Visible = true; RefreshColor() end)
    Btn.MouseLeave:Connect(function() isHovered = false; TipFrame.Visible = false; RefreshColor() end)
end

-- Drag + Click
do
    local dragging, didDrag = false, false
    local dragStart, startPos = nil, nil
    local THRESHOLD = 8

    local function ClampPosition()
        local vp = workspace.CurrentCamera.ViewportSize
        local x = math.clamp(Root.Position.X.Offset, 0, vp.X - BTN_SIZE)
        local y = math.clamp(Root.Position.Y.Offset, 0, vp.Y - BTN_SIZE)
        Root.Position = UDim2.new(0, x, 0, y)
    end

    Btn.InputBegan:Connect(function(inp)
        if not (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then return end
        dragging = true
        didDrag = false
        dragStart = inp.Position
        startPos = Root.Position
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        if not (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then return end
        local delta = inp.Position - dragStart
        if math.abs(delta.X) > THRESHOLD or math.abs(delta.Y) > THRESHOLD then
            didDrag = true
            Root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            ClampPosition()
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        if not dragging then return end
        if not (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then return end
        if not didDrag then
            Toggle()
            UpdateUI()
            if isMobile then
                TipFrame.Visible = true
                task.delay(1.4, function() if TipFrame then TipFrame.Visible = false end end)
            end
        end
        dragging = false
        didDrag = false
    end)
end

-- Keybind
UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe or UserInputService:GetFocusedTextBox() then return end
    if inp.KeyCode == Enum.KeyCode.R then
        Toggle()
        UpdateUI()
    end
end)

-- Respawn UI reset
LP.CharacterAdded:Connect(function()
    task.wait(0.2)
    Active = false
    UpdateUI()
end)

-- Auto position near chat
task.delay(2.8, function()
    pcall(function()
        local chatBtn = CoreGui:FindFirstChild("RobloxGui", true):FindFirstChild("ChatButton", true)
        if chatBtn and chatBtn:IsA("GuiObject") and chatBtn.Visible then
            local pos = chatBtn.AbsolutePosition
            local sz = chatBtn.AbsoluteSize
            Root.Position = UDim2.new(0, pos.X + sz.X + 8, 0, pos.Y)
        end
    end)
end)

print("spamton")
