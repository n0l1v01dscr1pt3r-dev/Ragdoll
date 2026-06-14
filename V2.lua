-- ============================================================
--  RAGDOLL SCRIPT v3 -- TRUE PHYSICS
--  R6 / R15 | Delta Executor | Adaptive UI
--  + Realistic mass per body part (torso heaviest, hands lightest)
--  + Angular damping (simulates joint friction / tissue resistance)
--  + Hinge-like knees and elbows (tight twist limits)
--  + Momentum preservation on ragdoll entry
--  + Real limb collisions (no clipping)
-- ============================================================

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local CoreGui          = game:GetService("CoreGui")

local LP   = Players.LocalPlayer
local Char = LP.Character or LP.CharacterAdded:Wait()
local Hum  = Char:WaitForChild("Humanoid")

-- ============================================================
--  PHYSICS CONFIG
-- ============================================================

local DENSITY = {
    Head          = 1.2,
    UpperTorso    = 2.8,
    LowerTorso    = 1.8,
    LeftUpperArm  = 0.80,
    RightUpperArm = 0.80,
    LeftLowerArm  = 0.60,
    RightLowerArm = 0.60,
    LeftHand      = 0.25,
    RightHand     = 0.25,
    LeftUpperLeg  = 1.70,
    RightUpperLeg = 1.70,
    LeftLowerLeg  = 0.85,
    RightLowerLeg = 0.85,
    LeftFoot      = 0.45,
    RightFoot     = 0.45,
    Torso         = 3.80,
    ["Left Arm"]  = 0.75,
    ["Right Arm"] = 0.75,
    ["Left Leg"]  = 1.40,
    ["Right Leg"] = 1.40,
}

local JOINT_CONFIG = {
    Neck          = { angle = 35, twist = true,  twistRange = 45 },
    Waist         = { angle = 18, twist = false },
    LeftShoulder  = { angle = 90, twist = false },
    RightShoulder = { angle = 90, twist = false },
    LeftElbow     = { angle = 75, twist = true,  twistRange = 8  },
    RightElbow    = { angle = 75, twist = true,  twistRange = 8  },
    LeftWrist     = { angle = 35, twist = false },
    RightWrist    = { angle = 35, twist = false },
    LeftHip       = { angle = 85, twist = false },
    RightHip      = { angle = 85, twist = false },
    LeftKnee      = { angle = 75, twist = true,  twistRange = 8  },
    RightKnee     = { angle = 75, twist = true,  twistRange = 8  },
    LeftAnkle     = { angle = 28, twist = false },
    RightAnkle    = { angle = 28, twist = false },
    ["Left Shoulder"]  = { angle = 85, twist = false },
    ["Right Shoulder"] = { angle = 85, twist = false },
    ["Left Hip"]       = { angle = 82, twist = false },
    ["Right Hip"]      = { angle = 82, twist = false },
}

local DEFAULT_CFG  = { angle = 45, twist = false }
local ANGULAR_DAMP = 0.95

-- ============================================================
--  STATE
-- ============================================================

local Active      = false
local MotorSave   = {}
local Created     = {}
local CollideSave = {}
local PropSave    = {}
local dampConn    = nil

local SKIP_MOTOR  = { RootJoint = true, Root = true }

-- ============================================================
--  RAGDOLL
-- ============================================================

local function Ragdoll()
    if Active then return end
    Active = true
    MotorSave, Created, CollideSave, PropSave = {}, {}, {}, {}

    local hrp = Char:FindFirstChild("HumanoidRootPart")
    local vel = hrp and hrp.AssemblyLinearVelocity or Vector3.zero

    Hum:ChangeState(Enum.HumanoidStateType.Physics)

    for _, p in ipairs(Char:GetDescendants()) do
        if p:IsA("BasePart") then CollideSave[p] = p.CanCollide end
    end

    pcall(function()
        for _, p in ipairs(Char:GetDescendants()) do
            if p:IsA("BasePart") then p:SetNetworkOwner(LP) end
        end
    end)

    for _, p in ipairs(Char:GetDescendants()) do
        if p:IsA("BasePart") and DENSITY[p.Name] then
            PropSave[p] = { original = p.CustomPhysicalProperties }
            p.CustomPhysicalProperties = PhysicalProperties.new(
                DENSITY[p.Name], 0.30, 0.00, 0.10, 0.00
            )
        end
    end

    for _, obj in ipairs(Char:GetDescendants()) do
        if obj:IsA("Motor6D")
        and obj.Part0 ~= nil
        and obj.Part1 ~= nil
        and not SKIP_MOTOR[obj.Name]
        then
            table.insert(MotorSave, { motor = obj, was = obj.Enabled })

            local a0 = Instance.new("Attachment")
            a0.CFrame = obj.C0
            a0.Parent = obj.Part0

            local a1 = Instance.new("Attachment")
            a1.CFrame = obj.C1
            a1.Parent = obj.Part1

            local cfg = JOINT_CONFIG[obj.Name] or DEFAULT_CFG

            local bsc = Instance.new("BallSocketConstraint")
            bsc.Attachment0        = a0
            bsc.Attachment1        = a1
            bsc.LimitsEnabled      = true
            bsc.UpperAngle         = cfg.angle
            bsc.TwistLimitsEnabled = cfg.twist
            if cfg.twist then
                local r = cfg.twistRange or 45
                bsc.TwistUpperAngle = r
                bsc.TwistLowerAngle = -r
            end
            bsc.Restitution = 0
            bsc.Parent      = obj.Part0

            obj.Enabled = false

            table.insert(Created, a0)
            table.insert(Created, a1)
            table.insert(Created, bsc)
        end
    end

    for _, p in ipairs(Char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.CanCollide = (p.Name ~= "HumanoidRootPart")
        end
    end

    task.defer(function()
        if not Active then return end
        for _, p in ipairs(Char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                p.AssemblyLinearVelocity = vel
            end
        end
    end)

    dampConn = RunService.Heartbeat:Connect(function()
        if not Active then return end
        for _, p in ipairs(Char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                local av = p.AssemblyAngularVelocity
                if av.Magnitude > 0.02 then
                    p.AssemblyAngularVelocity = av * ANGULAR_DAMP
                end
            end
        end
    end)
end

-- ============================================================
--  UNRAGDOLL
-- ============================================================

local function Unragdoll()
    if not Active then return end
    Active = false

    if dampConn then dampConn:Disconnect() dampConn = nil end

    for _, d in ipairs(MotorSave) do
        if d.motor and d.motor.Parent then d.motor.Enabled = d.was end
    end
    MotorSave = {}

    for _, obj in ipairs(Created) do
        if obj and obj.Parent then obj:Destroy() end
    end
    Created = {}

    for part, state in pairs(CollideSave) do
        if part and part.Parent then part.CanCollide = state end
    end
    CollideSave = {}

    for part, data in pairs(PropSave) do
        if part and part.Parent then
            part.CustomPhysicalProperties = data.original
        end
    end
    PropSave = {}

    task.delay(0.08, function()
        if not Active then
            Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end)
end

local function Toggle()
    if Active then Unragdoll() else Ragdoll() end
end

LP.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    Char = newChar
    Hum  = newChar:WaitForChild("Humanoid")
    Active = false
    if dampConn then dampConn:Disconnect() dampConn = nil end
    MotorSave, Created, CollideSave, PropSave = {}, {}, {}, {}
end)

-- ============================================================
--  UI
-- ============================================================

pcall(function() CoreGui:FindFirstChild("RagdollGui"):Destroy() end)
pcall(function() LP.PlayerGui:FindFirstChild("RagdollGui"):Destroy() end)

local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local BTN_SIZE = isMobile and 54 or 44

local Gui = Instance.new("ScreenGui")
Gui.Name           = "RagdollGui"
Gui.ResetOnSpawn   = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder   = 999

local parentOk = pcall(function() Gui.Parent = CoreGui end)
if not parentOk then Gui.Parent = LP:WaitForChild("PlayerGui") end

local defaultPos = isMobile
    and UDim2.new(0, 12, 1, -120)
    or  UDim2.new(0, 58, 1, -52)

local Root = Instance.new("Frame")
Root.Name                   = "Root"
Root.Size                   = UDim2.new(0, BTN_SIZE, 0, BTN_SIZE)
Root.Position               = defaultPos
Root.BackgroundTransparency = 1
Root.Parent                 = Gui

local Btn = Instance.new("TextButton")
Btn.Size             = UDim2.new(1, 0, 1, 0)
Btn.BackgroundColor3 = Color3.fromRGB(28, 28, 30)
Btn.BorderSizePixel  = 0
Btn.Text             = ""
Btn.AutoButtonColor  = false
Btn.ClipsDescendants = false
Btn.ZIndex           = 2
Btn.Parent           = Root

do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 12)
    c.Parent = Btn
    local s = Instance.new("UIStroke")
    s.Color     = Color3.fromRGB(78, 78, 86)
    s.Thickness = 1.2
    s.Parent    = Btn
end

local Icon = Instance.new("TextLabel")
Icon.Size                   = UDim2.new(1, 0, 1, 0)
Icon.BackgroundTransparency = 1
Icon.Text                   = "RG"
Icon.TextScaled             = true
Icon.Font                   = Enum.Font.GothamBold
Icon.TextColor3             = Color3.fromRGB(255, 255, 255)
Icon.ZIndex                 = 3
Icon.Parent                 = Btn

local TipFrame = Instance.new("Frame")
TipFrame.Size             = UDim2.new(0, 96, 0, 26)
TipFrame.Position         = isMobile
    and UDim2.new(0, 0, 0, -32)
    or  UDim2.new(1, 6, 0.5, -13)
TipFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 20)
TipFrame.BorderSizePixel  = 0
TipFrame.Visible          = false
TipFrame.ZIndex           = 5
TipFrame.Parent           = Btn

do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = TipFrame
    local s = Instance.new("UIStroke")
    s.Color     = Color3.fromRGB(60, 60, 68)
    s.Thickness = 1
    s.Parent    = TipFrame
end

local TipTxt = Instance.new("TextLabel")
TipTxt.Size                   = UDim2.new(1, -8, 1, 0)
TipTxt.Position               = UDim2.new(0, 4, 0, 0)
TipTxt.BackgroundTransparency = 1
TipTxt.Text                   = "Ragdoll [R]"
TipTxt.TextColor3             = Color3.fromRGB(210, 210, 218)
TipTxt.TextScaled             = true
TipTxt.Font                   = Enum.Font.GothamBold
TipTxt.TextXAlignment         = Enum.TextXAlignment.Left
TipTxt.ZIndex                 = 6
TipTxt.Parent                 = TipFrame

local C_IDLE   = Color3.fromRGB(28,  28,  30)
local C_HOVER  = Color3.fromRGB(50,  50,  56)
local C_ACTIVE = Color3.fromRGB(150, 22,  22)

local colorTween = nil
local isHovered  = false

local function RefreshColor()
    local target
    if Active then
        target = C_ACTIVE
    elseif isHovered then
        target = C_HOVER
    else
        target = C_IDLE
    end
    if colorTween then colorTween:Cancel() end
    colorTween = TweenService:Create(Btn, TweenInfo.new(0.12), { BackgroundColor3 = target })
    colorTween:Play()
end

local function SetVisual()
    TipTxt.Text = Active and "Stand Up [R]" or "Ragdoll [R]"
    RefreshColor()
end

if not isMobile then
    Btn.MouseEnter:Connect(function()
        isHovered = true
        TipFrame.Visible = true
        RefreshColor()
    end)
    Btn.MouseLeave:Connect(function()
        isHovered = false
        TipFrame.Visible = false
        RefreshColor()
    end)
end

do
    local dragging  = false
    local didDrag   = false
    local dragStart = nil
    local startPos2 = nil
    local THRESHOLD = 8

    local function ClampToScreen()
        local vp = workspace.CurrentCamera.ViewportSize
        local ox = math.clamp(Root.Position.X.Offset, 0, vp.X - BTN_SIZE)
        local oy = math.clamp(Root.Position.Y.Offset, 0, vp.Y - BTN_SIZE)
        Root.Position = UDim2.new(Root.Position.X.Scale, ox, Root.Position.Y.Scale, oy)
    end

    Btn.InputBegan:Connect(function(inp)
        local t = inp.UserInputType
        if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
        dragging  = true
        didDrag   = false
        dragStart = inp.Position
        startPos2 = Root.Position
    end)

    UserInputService.InputChanged:Connect(function(inp)
        if not dragging then return end
        local t = inp.UserInputType
        if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
        local d = inp.Position - dragStart
        if math.abs(d.X) > THRESHOLD or math.abs(d.Y) > THRESHOLD then
            didDrag = true
            Root.Position = UDim2.new(
                startPos2.X.Scale, startPos2.X.Offset + d.X,
                startPos2.Y.Scale, startPos2.Y.Offset + d.Y
            )
            ClampToScreen()
        end
    end)

    UserInputService.InputEnded:Connect(function(inp)
        local t = inp.UserInputType
        if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
        if not dragging then return end
        if not didDrag then
            Toggle()
            SetVisual()
            if isMobile then
                TipFrame.Visible = true
                task.delay(1.5, function() TipFrame.Visible = false end)
            end
        end
        dragging = false
        didDrag  = false
    end)
end

UserInputService.InputBegan:Connect(function(inp, gpe)
    if gpe then return end
    if UserInputService:GetFocusedTextBox() then return end
    if inp.KeyCode == Enum.KeyCode.R then
        Toggle()
        SetVisual()
    end
end)

LP.CharacterAdded:Connect(function()
    task.wait(0.1)
    Active = false
    SetVisual()
end)

task.delay(2.5, function()
    pcall(function()
        local rg = CoreGui:FindFirstChild("RobloxGui")
        if not rg then return end
        local chatBtn = rg:FindFirstChild("ChatButton", true)
        if chatBtn and chatBtn:IsA("GuiObject") and chatBtn.Visible then
            local abs = chatBtn.AbsolutePosition
            local sz  = chatBtn.AbsoluteSize
            Root.Position = UDim2.new(0, abs.X + sz.X + 6, 0, abs.Y)
        end
    end)
end)

print("SPAMTY")
