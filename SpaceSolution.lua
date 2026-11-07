if not game:IsLoaded() then

    game.Loaded:Wait()

end

if not syn or not protectgui then

    getgenv().protectgui = function() end

end

local SilentAimSettings = {

    Enabled = false,

    ClassName = "Universal Silent Aim - Averiias, Stefanuk12, xaxa",

    ToggleKey = "RightAlt",

    TeamCheck = false,

    VisibleCheck = false,

    MagicBullet = false,

    TargetPart = "HumanoidRootPart",

    SilentAimMethod = "Raycast",

    FOVRadius = 130,

    FOVVisible = false,

    ShowSilentAimTarget = false,

    MouseHitPrediction = false,

    MouseHitPredictionAmount = 0.165,

    HitChance = 100

}

-- variables

getgenv().SilentAimSettings = SilentAimSettings

local MainFileName = "spacesolution"

local Toggles, Options = {}, {}

local SelectedFile, FileToSave = "", ""

local Camera = workspace.CurrentCamera

local Players = game:GetService("Players")

local RunService = game:GetService("RunService")

local GuiService = game:GetService("GuiService")

local UserInputService = game:GetService("UserInputService")

local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local SpaceFriends = {}
local function isSpaceFriend(player)
    return player ~= nil and SpaceFriends[player.UserId] == true
end


local Mouse = LocalPlayer:GetMouse()

-- A central lifecycle manager. The Unload button shuts down all features,
-- disconnects non-UI events, restores modified character properties, and
-- removes every Drawing/GUI created by this script.
local SpaceRuntime = {Active = true, Connections = {}, Cleanups = {}}
function SpaceRuntime:Connect(signal, callback)
    local conn = signal:Connect(callback)
    self.Connections[#self.Connections + 1] = conn
    return conn
end
function SpaceRuntime:AddCleanup(callback)
    self.Cleanups[#self.Cleanups + 1] = callback
end
function SpaceRuntime:Unload()
    if not self.Active then return end
    self.Active = false
    SilentAimSettings.Enabled = false
    SilentAimSettings.MagicBullet = false
    SilentAimSettings.FOVVisible = false
    -- Stop execution first; then restore state and remove resources.
    for _, connection in ipairs(self.Connections) do
        pcall(function() connection:Disconnect() end)
    end
    table.clear(self.Connections)
    for index = #self.Cleanups, 1, -1 do
        pcall(self.Cleanups[index])
    end
    table.clear(self.Cleanups)
    if self.ClosePopup then pcall(self.ClosePopup) end
    if self.FOVDrawing then
        pcall(function()
            self.FOVDrawing.Visible = false
            self.FOVDrawing:Remove()
        end)
        self.FOVDrawing = nil
    end
    if self.WatermarkUI then
        pcall(function() self.WatermarkUI:Destroy() end)
        self.WatermarkUI = nil
    end
    if self.MainUI then
        pcall(function() self.MainUI:Destroy() end)
        self.MainUI = nil
    end
    if type(getgenv) == "function" then
        pcall(function()
            if getgenv().SpaceSolutionRuntime == self then
                getgenv().SpaceSolutionRuntime = nil
            end
            if getgenv().SilentAimSettings == SilentAimSettings then
                getgenv().SilentAimSettings = nil
            end
        end)
    end
end
-- When this same revised script is re-executed, unload its previous instance.
if type(getgenv) == "function" then
    pcall(function()
        local previous = getgenv().SpaceSolutionRuntime
        if previous and previous ~= SpaceRuntime and type(previous.Unload) == "function" then
            previous:Unload()
        end
        getgenv().SpaceSolutionRuntime = SpaceRuntime
    end)
end

local GetChildren = game.GetChildren

local GetPlayers = Players.GetPlayers

local WorldToScreen = Camera.WorldToScreenPoint

local WorldToViewportPoint = Camera.WorldToViewportPoint

local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget

local FindFirstChild = game.FindFirstChild

local RenderStepped = RunService.RenderStepped

local GuiInset = GuiService.GetGuiInset

local GetMouseLocation = UserInputService.GetMouseLocation

local resume = coroutine.resume

local create = coroutine.create

local ValidTargetParts = {"Head", "HumanoidRootPart"}

local PredictionAmount = 0.165

local fov_circle = Drawing.new("Circle")

fov_circle.Thickness = 1

fov_circle.NumSides = 100

fov_circle.Radius = 180

fov_circle.Filled = false

fov_circle.Visible = false

fov_circle.ZIndex = 999

fov_circle.Transparency = 1

fov_circle.Color = Color3.fromRGB(255, 255, 255)
SpaceRuntime.FOVDrawing = fov_circle

local ExpectedArguments = {

    FindPartOnRayWithIgnoreList = {

        ArgCountRequired = 3,

        Args = {

            "Instance", "Ray", "table", "boolean", "boolean"

        }

    },

    FindPartOnRayWithWhitelist = {

        ArgCountRequired = 3,

        Args = {

            "Instance", "Ray", "table", "boolean"

        }

    },

    FindPartOnRay = {

        ArgCountRequired = 2,

        Args = {

            "Instance", "Ray", "Instance", "boolean", "boolean"

        }

    },

    Raycast = {

        ArgCountRequired = 3,

        Args = {

            "Instance", "Vector3", "Vector3", "RaycastParams"

        }

    }

}

local AimChanceRandom = Random.new()
function CalculateChance(Percentage)
    local percentage = math.clamp(tonumber(Percentage) or 0, 0, 100)
    if percentage >= 100 then return true end
    if percentage <= 0 then return false end
    return AimChanceRandom:NextNumber(0, 100) < percentage
end

-- file handling

do

    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(MainFileName) then

        makefolder(MainFileName);

    end

    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(string.format("%s/%s", MainFileName, tostring(game.PlaceId))) then

        makefolder(string.format("%s/%s", MainFileName, tostring(game.PlaceId)))

    end

end

-- Config system: refresh file list, save all ESP/aim settings and colors.
local ConfigFolder = string.format("%s/%s", MainFileName, tostring(game.PlaceId))

local function GetFiles()
    local names = {}
    if type(listfiles) ~= "function" then return names end
    local ok, files = pcall(listfiles, ConfigFolder)
    if not ok or type(files) ~= "table" then return names end
    for _, path in ipairs(files) do
        local name = tostring(path):match("([^/\\\\]+)%.json$")
            or tostring(path):match("([^/\\\\]+)%.lua$")
        if name and not table.find(names, name) then
            table.insert(names, name)
        end
    end
    table.sort(names)
    return names
end

local function SafeName(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    if name == "" or not name:match("^[%w_%- ]+$") then return nil end
    return name
end

local function ConfigPath(name, extension)
    return ConfigFolder .. "/" .. name .. "." .. extension
end

local function EncodeValue(value)
    if typeof(value) == "Color3" then
        return {__type = "Color3", r = value.R, g = value.G, b = value.B}
    elseif typeof(value) == "EnumItem" then
        return {__type = "EnumItem", name = value.Name}
    elseif type(value) == "number" or type(value) == "boolean" or type(value) == "string" then
        return value
    end
    return nil
end

local function DecodeValue(value)
    if type(value) == "table" and value.__type == "Color3" then
        return Color3.new(value.r, value.g, value.b)
    elseif type(value) == "table" and value.__type == "EnumItem" then
        return value.name
    end
    return value
end

local ExcludedConfigOptions = {
    CreateConfigTextBox = true,
    SaveConfigurationDropdown = true,
    LoadConfigurationDropdown = true,
}

local function UpdateFile(fileName)
    local name = SafeName(fileName)
    if not name or type(writefile) ~= "function" then return false end
    local data = {version = 2, aim = SilentAimSettings, toggles = {}, options = {}}
    for key, control in pairs(Toggles) do
        data.toggles[key] = EncodeValue(control.Value)
    end
    for key, control in pairs(Options) do
        if not ExcludedConfigOptions[key] then
            data.options[key] = EncodeValue(control.Value)
        end
    end
    local ok = pcall(function()
        writefile(ConfigPath(name, "json"), HttpService:JSONEncode(data))
    end)
    return ok
end

local function LoadFile(fileName)
    local name = SafeName(fileName)
    if not name or type(readfile) ~= "function" then return false end
    local ok, data = pcall(function()
        local jsonPath = ConfigPath(name, "json")
        local path = (type(isfile) == "function" and isfile(jsonPath))
            and jsonPath or ConfigPath(name, "lua")
        return HttpService:JSONDecode(readfile(path))
    end)
    if not ok or type(data) ~= "table" then return false end

    local aim = data.aim or data -- backwards-compatible old configurations
    for key, value in pairs(aim) do
        SilentAimSettings[key] = value
    end
    for key, value in pairs(data.options or {}) do
        if Options[key] and not ExcludedConfigOptions[key] then
            pcall(function() Options[key]:SetValue(DecodeValue(value)) end)
        end
    end
    for key, value in pairs(data.toggles or {}) do
        if Toggles[key] then
            pcall(function() Toggles[key]:SetValue(DecodeValue(value)) end)
        end
    end
    return true
end

local function getPositionOnScreen(Vector)

    local Vec3, OnScreen = WorldToScreen(Camera, Vector)

    return Vector2.new(Vec3.X, Vec3.Y), OnScreen

end

local function ValidateArguments(Args, RayMethod)

    local Matches = 0

    if #Args < RayMethod.ArgCountRequired then

        return false

    end

    for Pos, Argument in next, Args do

        if typeof(Argument) == RayMethod.Args[Pos] then

            Matches = Matches + 1

        end

    end

    return Matches >= RayMethod.ArgCountRequired

end

local function getDirection(Origin, Position)

    return (Position - Origin).Unit * 1000

end

local function getMousePosition()

    return GetMouseLocation(UserInputService)

end

local function IsPlayerVisible(Player)

    local PlayerCharacter = Player.Character

    local LocalPlayerCharacter = LocalPlayer.Character

    if not (PlayerCharacter and LocalPlayerCharacter) then return end

    local PlayerRoot = FindFirstChild(PlayerCharacter, Options.TargetPart.Value) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")

    if not PlayerRoot then return end

    local CastPoints, IgnoreList = {PlayerRoot.Position}, {LocalPlayerCharacter, PlayerCharacter}

    local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)

    return ((ObscuringObjects == 0 and true) or (ObscuringObjects > 0 and false))

end

local function getClosestPlayer()

    if not Options.TargetPart.Value then return end

    local Closest

    local DistanceToMouse
    local mousePosition = getMousePosition()

    for _, Player in next, GetPlayers(Players) do

        if Player == LocalPlayer or isSpaceFriend(Player) then continue end

        if Toggles.TeamCheck.Value and Player.Team == LocalPlayer.Team then continue end

        local Character = Player.Character

        if not Character then continue end

        -- Magic Bullet ignores client-side occlusion when selecting a target.
        if Toggles.VisibleCheck.Value and not SilentAimSettings.MagicBullet
            and not IsPlayerVisible(Player) then continue end

        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")

        local Humanoid = FindFirstChild(Character, "Humanoid")

        if not HumanoidRootPart or not Humanoid or Humanoid and Humanoid.Health <= 0 then continue end

        local ScreenPosition, OnScreen = getPositionOnScreen(HumanoidRootPart.Position)

        if not OnScreen then continue end

        local Distance = (mousePosition - ScreenPosition).Magnitude

        if Distance <= (DistanceToMouse or Options.Radius.Value or 2000) then

            Closest = ((Options.TargetPart.Value == "Random" and Character[ValidTargetParts[math.random(1, #ValidTargetParts)]]) or Character[Options.TargetPart.Value])

            DistanceToMouse = Distance

        end

    end

    return Closest

end

-- SpaceSolution: custom interface matching dark screenshot.
-- The original Silent Aim / ESP / config logic is kept below this adapter.
local ACCENT = Color3.fromRGB(140, 151, 201)
-- Dynamic theme / rainbow state (kept separate from gameplay logic).
local ThemeState = {GUIColor = ACCENT, GUIRainbow = false, WatermarkRainbow = false,
    WatermarkColor = ACCENT, ESPRainbow = false, RainbowSpeed = 0.12}
local function rainbowColor(now)
    return Color3.fromHSV((now * ThemeState.RainbowSpeed) % 1, 1, 1)
end
local function espColor(optionName)
    if ThemeState.ESPRainbow then return rainbowColor(os.clock()) end
    local option = Options[optionName]
    return option and option.Value or Color3.new(1, 1, 1)
end
local BG = Color3.fromRGB(17, 16, 22)
local BAR = Color3.fromRGB(20, 19, 25)
local PANEL = Color3.fromRGB(22, 21, 28)
local INPUT = Color3.fromRGB(30, 29, 38)
local MUTED = Color3.fromRGB(134, 131, 145)
local WHITE = Color3.fromRGB(239, 237, 245)
local function uiCreate(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end
local function uiRound(inst, px)
    uiCreate("UICorner", {CornerRadius = UDim.new(0, px or 8)}, inst)
end
local function uiText(parent, text, size, color, bold)
    return uiCreate("TextLabel", {
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium,
        TextColor3 = color or WHITE, Text = text or "", TextSize = size or 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)
end
local function uiButton(parent, text, color)
    local b = uiCreate("TextButton", {
        Text = text or "", Font = Enum.Font.GothamSemibold, TextSize = 13,
        TextColor3 = WHITE, BorderSizePixel = 0,
        AutoButtonColor = false, BackgroundColor3 = color or INPUT
    }, parent)
    uiRound(b, 8)
    -- Lightweight hover outline: no layout reflow or background-color conflicts.
    local edge = uiCreate("UIStroke", {
        Color = ACCENT, Thickness = 1, Transparency = 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, b)
    edge:SetAttribute("SpaceAccent", true)
    b.MouseEnter:Connect(function()
        game:GetService("TweenService"):Create(edge,
            TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            {Transparency = 0.58}):Play()
    end)
    b.MouseLeave:Connect(function()
        game:GetService("TweenService"):Create(edge,
            TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            {Transparency = 1}):Play()
    end)
    return b
end

local guiParent = nil
if type(gethui) == "function" then
    pcall(function() guiParent = gethui() end)
end
if not guiParent then
    pcall(function() guiParent = game:GetService("CoreGui") end)
end
if not guiParent then guiParent = LocalPlayer:WaitForChild("PlayerGui") end
pcall(function()
    local oldGui = guiParent:FindFirstChild("SpaceSolutionNewUI")
    if oldGui then oldGui:Destroy() end
end)
local ui = uiCreate("ScreenGui", {
    Name = "SpaceSolutionNewUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 5000
}, guiParent)
if type(protectgui) == "function" then pcall(protectgui, ui) end
SpaceRuntime.MainUI = ui
ui.Destroying:Connect(function() SpaceRuntime:Unload() end)

local frame = uiCreate("CanvasGroup", {
    Size = UDim2.fromOffset(862, 524),
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    BackgroundColor3 = BG, BorderSizePixel = 0, Active = true,
    GroupTransparency = 1 -- start hidden until the intro starts
}, ui)
-- Subtle fade/slide/size tweens for opening and closing the menu.
-- Revisions prevent stale close callbacks from hiding a newly reopened menu.
local TweenService = game:GetService("TweenService")
local menuTween, scaleTween
local animationRevision = 0
local menuOpen = true
local openTweenInfo = TweenInfo.new(0.36, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local closeTweenInfo = TweenInfo.new(0.26, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local function animateMenu(shouldOpen, instant)
    animationRevision = animationRevision + 1
    local revision = animationRevision
    menuOpen = shouldOpen
    frame:SetAttribute("SpaceSolutionIntroInterrupted", true)
    if menuTween then menuTween:Cancel() end
    if scaleTween then scaleTween:Cancel() end
    if shouldOpen then
        ui.Enabled = true
        frame.Visible = true
        local introViewport = frame:FindFirstChild("SpaceSolutionIntroViewport")
        local introBody = introViewport and introViewport:FindFirstChild("SpaceSolutionIntroBody")
        if introBody then
            introBody.Position = UDim2.fromOffset(0, 0)
            introBody.GroupTransparency = 0
        end
        if instant or frame.GroupTransparency >= 0.99 then
            frame.GroupTransparency = 1
            frame.Position = UDim2.new(0.5, 0, 0.5, 12)
            frame.Size = UDim2.fromOffset(852, 516)
        end
        menuTween = TweenService:Create(frame, openTweenInfo, {
            GroupTransparency = 0,
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(862, 524),
        })
        menuTween:Play()
    else
        menuTween = TweenService:Create(frame, closeTweenInfo, {
            GroupTransparency = 1,
            Position = UDim2.new(0.5, 0, 0.5, 9),
            Size = UDim2.fromOffset(854, 518),
        })
        menuTween:Play()
        task.delay(closeTweenInfo.Time + 0.015, function()
            if revision == animationRevision and not menuOpen and ui.Parent then
                ui.Enabled = false
            end
        end)
    end
end
uiRound(frame, 13)
local guiOutline = uiCreate("UIStroke", {Color = ACCENT, Thickness = 1}, frame)
guiOutline:SetAttribute("SpaceAccent", true)
local uiScale = uiCreate("UIScale", {Scale = 1}, frame)
local function resizeMenu()
    local currentCamera = workspace.CurrentCamera
    if currentCamera then
        local v = currentCamera.ViewportSize
        uiScale.Scale = math.clamp(math.min(v.X / 890, v.Y / 555, 1), 0.55, 1)
    end
end
resizeMenu()
SpaceRuntime:Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), resizeMenu)
-- Update UIScale only when the viewport actually changes (not every frame).
do
    local lastViewport = Vector2.new(-1, -1)
    SpaceRuntime:Connect(RunService.RenderStepped, function()
        if not ui.Enabled then return end
        local currentCamera = workspace.CurrentCamera
        if currentCamera and currentCamera.ViewportSize ~= lastViewport then
            lastViewport = currentCamera.ViewportSize
            resizeMenu()
        end
    end)
end

local header = uiCreate("Frame", {
    Size = UDim2.new(1, 0, 0, 57), BackgroundColor3 = BAR,
    BorderSizePixel = 0
}, frame)
uiRound(header, 13)
local headerMask = uiCreate("Frame", {
    Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12),
    BackgroundColor3 = BAR, BorderSizePixel = 0
}, header)
-- Embedded SpaceSolution logo (no external download needed).
local spaceLogoPNG = [[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]]
local function decodeSpaceLogo(source)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local lookup = {}
    for i = 1, #alphabet do lookup[alphabet:sub(i, i)] = i - 1 end
    local result, accumulator, bits = {}, 0, 0
    for i = 1, #source do
        local value = lookup[source:sub(i, i)]
        if source:sub(i, i) == "=" then break end
        if value then
            accumulator = accumulator * 64 + value
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                result[#result + 1] = string.char(math.floor(accumulator / (2 ^ bits)) % 256)
                accumulator = accumulator % (2 ^ bits)
            end
        end
    end
    return table.concat(result)
end
local logoImage = uiCreate("ImageLabel", {
    Name = "SpaceSolutionLogo", Position = UDim2.fromOffset(13, 6),
    Size = UDim2.fromOffset(43, 43), BackgroundTransparency = 1,
    ScaleType = Enum.ScaleType.Fit, Image = ""
}, header)
local logoAssetFunction = (type(getcustomasset) == "function" and getcustomasset)
    or (type(getsynasset) == "function" and getsynasset)
if logoAssetFunction and type(writefile) == "function" then
    pcall(function()
        local path = "SpaceSolution_Logo_v1.png"
        writefile(path, decodeSpaceLogo(spaceLogoPNG))
        logoImage.Image = logoAssetFunction(path)
    end)
end
spaceLogoPNG = nil
local product = uiText(header, "SpaceSolution", 16, WHITE, true)
product.Position = UDim2.fromOffset(61, 8)
product.Size = UDim2.fromOffset(200, 40)
local subtitle = uiText(header, "", 9, MUTED)
subtitle.Position = UDim2.fromOffset(62, 38)
subtitle.Size = UDim2.fromOffset(180, 14)
-- Clean header: no redundant SilentAim / TriggerBot / Aimbot labels.
local headerTop = {}

-- Loading intro from the reference video: first the logo/header appears,
-- then the actual navigation and controls slide upwards from below.
-- The viewport masks the moving content and stays behind the fixed header.
uiCreate("CanvasGroup", {
    Name = "SpaceSolutionIntroBody",
    Position = UDim2.fromOffset(0, 448),
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    GroupTransparency = 1,
}, uiCreate("Frame", {
    Name = "SpaceSolutionIntroViewport",
    Position = UDim2.fromOffset(0, 57),
    Size = UDim2.new(1, 0, 1, -57),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, frame))
local side = uiCreate("Frame", {
    Size = UDim2.new(0, 191, 1, -15), Position = UDim2.fromOffset(7, 8),
    BackgroundTransparency = 1
}, frame.SpaceSolutionIntroViewport.SpaceSolutionIntroBody)
local body = uiCreate("Frame", {
    Size = UDim2.new(1, -215, 1, -15), Position = UDim2.fromOffset(208, 8),
    BackgroundTransparency = 1
}, frame.SpaceSolutionIntroViewport.SpaceSolutionIntroBody)
local screens = {}
local links = {}
local linkLabels = {}
-- Sidebar icons bundled directly in this Lua file.
local sidebarIconPNGs = {
    ["Misc"] = [[iVBORw0KGgoAAAANSUhEUgAAACgAAAApCAYAAABHomvIAAAB1UlEQVR42u3YT4tOcRjG8c9jJqNRRkSMBVGkRFKzmGIjylDY2IuNbLwL5QVYWFhKNt7ASFYkkg02NpqS0ZhJmMYYl82Phvx5/hzneRbPVb/O5v6d8z3n3Pd13+c0kuhlrdDj6gP2AbutwQ73r8cB7MUIZjGFu3hbCWGSdtfWJFeSTOVnLSS5luRgB+f+sdrduCnJ9fxdk0mOdQrY7is+irP/iDmM13iImTqLZCNONxk7gbG6q3g7xpuMXYfddQOuxVAL8UN1A77DdJOx83hTN+BT3G8y9jke1A24gFuYayL2Jp51y6gvJZn9gwcuJrlc/LIrRv19nUpyO8ncMrAnSS4kGa6ikzQqmqhHS7rM40NJg0rU6PWRv51WN4wjpUPswGYMYAlfy3EOr/C4rBd1Fcn+kvzv07wmk5ypo0jGkjxKe5pJcvF/Au5Mci+daSrJ8VYBmzXqkzjUYb5vwfkyDVXaSUZwrqKinMCJqgHHsasiwJXYg1VVAm6o2NpGW7G3bnx2DlX9ipcqBlwohl5ZJ7mDq9hXcugzVpcLDaKxrIv87sZXlE6ziJe4gU9V9+IBbMMafCyACiykAC4Ha/xSHF/KdD3dyuNu9P8P9gH7gH3APmBv6xsjtdJpLaw9SQAAAABJRU5ErkJggg==]],
    ["Walka"] = [[iVBORw0KGgoAAAANSUhEUgAAABQAAAAVCAYAAABG1c6oAAAB4klEQVR4nI2UO2hUURCGv10NWaKLNiIbQiwMWBgEC4OIggQCYmeQiI2SRixtBEGClYW9CIIEEkhhYyeCoIWVWpjGQhFE8AESxUeIJPj4LO6sjMvduztw4My9//wzZ141lT5kAmgBj4GPlUi11xlV76vf1ctqswpfq4hwP3AcOAwci28/gQXgHvAI+NRPhNvUWfWF1TKvHui0LyO70oMoyzP1UDfCunpGXUsGN9UZ9XXod8Lhm4S5rbbKCFvq0wSci4hRT6hX1YPqgDqlLifsdBnh0QSYV4ftUsk40+qvwN9QB1XqUZsx4Hyq1ZeO2g0Du4GBXE/gW9yngSlgAHVcfV6S8Hl1e+R2KfI2E9GdUldLbE7Xgd/Aj5I+3IgoAGrAJuBP6ENdenejXd1J9UHytKDuTfnaY9EeW0PfoV5M+DX1gtrcHF4fAiPAZHha5f+ZfdkRyQrwDlgHGmG/CKzWE+h9uu8CtiS9HifLSJABfKadtvSsUfVJesac2oh/Z9VrFqM2GCl6lbCzlvRh23A9Aa+rJ9W3KbeX1A8Js6Tu7EbY6Eh2L7mr7sscZRPQtJjp5R5kt9SJTvuq0RpXz8WT2vLVYskescui7WdjD1psmRWLXhuqwldt7CxjQDP6sWyq/slfutHhaaNLGNgAAAAASUVORK5CYII=]],
    ["Visuals"] = [[iVBORw0KGgoAAAANSUhEUgAAAB0AAAAeCAYAAADQBxWhAAAB4klEQVR42u2WPWsVURCGn9Vg0KtiuKAEhPiBiIhY+NUEES1sLESChQhCCIiIP8HCWjBYhBR2ARG0C5hKIlgE0djEzhDEQqIEYuEXIvjYHOF6mb17NiERIS8sLLMz83J2Zt4zhcpqYx3/AGukK4qumv49wDZgM9ANfAW+AIvpPQ9qztOtnlZvqwv+jc/qqNqfmSuL9KQ6bh4m1OPq+uWQXla/Wx+D6sayvEUHcRgC7gX2N8Ak8AHYDZwBdgZ+V4Cx3JoW6rmSE9xUt6Qa96c/cV4dLvEfyP29B9T5IMGtFp+G+izZ59QhdSSIWVAPVpE21btB8Cd1X4vfkaCBBtSfQexIe32jTo0wrvaofclnIvC5oT4P7D/Uw608XZli8Q3YDzwqaRqADckvsjc6yeBbYCYI3ANs70C4CHxM3dyOGeB9FelwEHgM2ApcLSG9k060K/g2AryrGpmm+jCozaS6Q72oPlFnU20vpDq/DmLG0nhlKdIh9VWQZE69pB5Nc3pKvZ66ux1Tam9dGSwj/iPy8yUjojqt7l2q9l5zaRjslLfqEn8BPKh5594Hni73Pm2mOk5XnG4qyWFvVc6ixgraAM4CJ4A+YBPwC5gFHgMvc7eHoubeWwCu9mLmf7sNrpGuKH4DXbLYA++4VvEAAAAASUVORK5CYII=]],
    ["List"] = [[iVBORw0KGgoAAAANSUhEUgAAABUAAAAUCAYAAABiS3YzAAACOUlEQVR4nH3Uy4uOYRgG8N98M2MYx+QQTRQJ2SihFKmxoJSdsrUTOyws5FBiN9nZYSF/gCIhFkLKMafkbBAxDuPw6WNui+d5zeudb1z1Lu7ree/rfu7T0xIR/oNOfMd0LMYL3EF75puibRh+IVagH0+wERtwDQdysGm4gktDvCOi/E2IiM0RcS8ifkfE/ojoiX9xIiL2RsSXiHgZEZuy31+dsuDEiNhVcv6YAzyPodgZEQ9K9vaIGFNo1fKFW7EOu0tJnMckzGhSnkm4XrJ3Y3VhFKJLsb3ieAszh6n5Anwr2Z3YjC4GG/VZKvobBB7iNGZhPCbiZ/73dz57nv2WoI4bWVxbTmU5evPXwO0coCun2ZGzas2idTzGAL7mYA3MRa+IWBkR3yqNuBAR63N3h8PeiLhc4a5GxMKaNMidlZqNw9iiRsOgHVMr3DxMrmFkE4dWtPxHsBCtV7gGGjV8wtvKYS/6pIY1QwMf8a7Cv0BfG+5iD9bkg184h0c4jFX4ITWoJjXnPi5Ka/wjc3Wcwv1avtEFvMopjZNGqR1P8UGq+ViMlkrTL5VtCkZJ0/EYl9Eo5rQPc9Cd7W68luZzfZP065jg34X5ivcMbtRbHKs4Lje0EQV6Mb/Cncg6f0XhKLaW7O4cub+J6CMpswL7cLwwyqIDOIQtUuod0ooeqQiexGRpRgewAweVHu2WGPryt2OZwZ2+jW1Yi5voycG6cBZnqgLNRAt0SB1/j9lYhGfS6zUiB+9r5vgHX5tdhF3e0gYAAAAASUVORK5CYII=]],
    ["Ustawienia"] = [[iVBORw0KGgoAAAANSUhEUgAAACIAAAAaCAYAAADSbo4CAAABEUlEQVR42u3Wv0oDQRDH8U9iCP7BwlZS2FuIiPgOvoYP4MtYWlhYW9j4FKlsBEVEQRBBIVEECTc2GxAhObk7wir5wcAVc3vf252Z37YiQg5qy0TZgHR+kbOCLfRS/jI+0/M9LvFUmyQipsVqRBxGxDAm6zQiNkvWKY1WSbHu4BzrJf9zgRPcoUBgCSM84wWvdXZkP+rrISKOI2J72rfKamTUQB32cIAhrvBRpWuKBhtjD4s5tG83RSWQ9qzm1qxBurlM1nYuIH/f9Ir/uCMLdWqk0yDIO96qggySYTWhm7ReJZBrHDUA8YizST6D0msArGEXG+mcxzY/NsXx8bV+GnvKHeAW/W/vVQKZz5E5SBb6AneBF7Zsz+lLAAAAAElFTkSuQmCC]]
}
local sidebarIconAssets = {}
if logoAssetFunction and type(writefile) == "function" then
    for name, encoded in pairs(sidebarIconPNGs) do
        pcall(function()
            local file = "SpaceSolution_Nav_" .. name .. ".png"
            writefile(file, decodeSpaceLogo(encoded))
            sidebarIconAssets[name] = logoAssetFunction(file)
        end)
    end
end
sidebarIconPNGs = nil

local navDefs = {
    {"Walka", "+"}, {"Visuals", "O"},
    {"Misc", "*"}, {"List", "@"}, {"Ustawienia", "#"}
}
local selectedPage = "Walka"
local pageTween, pageOutTween = nil, nil
local pageAnimationRevision = 0
local pageTweenInfo = TweenInfo.new(0.30, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local function showPage(name)
    if not screens[name] or name == selectedPage then return end
    pageAnimationRevision = pageAnimationRevision + 1
    local revision = pageAnimationRevision
    local previousPage = screens[selectedPage]
    local activePage = screens[name]
    if pageTween then pageTween:Cancel() end
    if pageOutTween then pageOutTween:Cancel() end
    for key, page in pairs(screens) do
        if page ~= previousPage and page ~= activePage then
            page.Visible = false
            page.GroupTransparency = 0
            page.Position = UDim2.fromOffset(0, 0)
        end
    end
    selectedPage = name
    -- Show combat-only header subtabs exclusively on the Combat page.
    -- Keep these lookups inside showPage to avoid adding top-level Luau locals.
    for _, tabName in ipairs({"Silent", "Trigger", "Hitbox"}) do
        local button = header:FindFirstChild("CombatTab" .. tabName)
        if button then
            button.Visible = (name == "Walka")
        end
    end
    if previousPage and previousPage ~= activePage then
        previousPage.Visible = true
        previousPage.ZIndex = 1
        pageOutTween = TweenService:Create(previousPage,
            TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                GroupTransparency = 1,
                Position = UDim2.fromOffset(0, -6),
            })
        pageOutTween:Play()
        task.delay(0.17, function()
            if revision ~= pageAnimationRevision then return end
            previousPage.Visible = false
            previousPage.GroupTransparency = 0
            previousPage.Position = UDim2.fromOffset(0, 0)
        end)
    end
    activePage.Visible = true
    activePage.ZIndex = 2
    activePage.GroupTransparency = 1
    activePage.Position = UDim2.fromOffset(0, 11)
    pageTween = TweenService:Create(activePage, pageTweenInfo, {
        GroupTransparency = 0,
        Position = UDim2.fromOffset(0, 0),
    })
    pageTween:Play()
    for key, b in pairs(links) do
        local chosen = key == name
        TweenService:Create(b, TweenInfo.new(0.19, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
            BackgroundColor3 = chosen and INPUT or BAR,
        }):Play()
        if linkLabels[key] then
            for _, lbl in ipairs(linkLabels[key]) do
                TweenService:Create(lbl, TweenInfo.new(0.19, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                    TextColor3 = chosen and WHITE or MUTED,
                }):Play()
            end
        end
        local sidebarIcon = b:FindFirstChild("SidebarIcon")
        if sidebarIcon then
            sidebarIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
        end
    end
end
headerTop.showAim = function() showPage("Walka") end

local function createPage(name, leftRatio)
    local page = uiCreate("CanvasGroup", {
        Name = name, Size = UDim2.fromScale(1,1), BackgroundTransparency = 1,
        Visible = name == selectedPage
    }, body)
    local columns = {}
    leftRatio = leftRatio or 0.5
    for i = 1,2 do
        local width = i == 1 and leftRatio or (1-leftRatio)
        local x = i == 1 and 0 or leftRatio
        local scroll = uiCreate("ScrollingFrame", {
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, ScrollBarImageColor3 = ACCENT,
            Position = UDim2.new(x, i==1 and 0 or 6, 0, 0),
            Size = UDim2.new(width, -8, 1, 0),
            CanvasSize = UDim2.fromOffset(0,0),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollingDirection = Enum.ScrollingDirection.Y,
        }, page)
        uiCreate("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,11)
        }, scroll)
        columns[i] = scroll
    end
    screens[name] = page
    return {frame = page, columns = columns}
end
local pages = {
    Walka = createPage("Walka"),
    Visuals = createPage("Visuals", 0.52),
    Misc = createPage("Misc"),
    List = createPage("List"),
    ["Ustawienia"] = createPage("Ustawienia"),
}
-- Combat header subtabs: Silent | Trigger | Hitbox.
-- Each subtab owns its own scroll panels; no gameplay state is reset on switching.
do
    local combat = {active = "Silent", views = {}, buttons = {}, tween = nil}
    local combatParent = pages.Walka.frame

    -- Keep the original Combat columns and their controls for Silent Aim.
    local silentFrame = uiCreate("CanvasGroup", {
        Name = "CombatSilent", Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 1, Visible = true
    }, combatParent)
    for _, scrollingColumn in ipairs(pages.Walka.columns) do
        scrollingColumn.Parent = silentFrame
    end
    combat.views.Silent = {frame = silentFrame, columns = pages.Walka.columns}

    local function createCombatSubtab(name)
        local subFrame = uiCreate("CanvasGroup", {
            Name = "Combat" .. name,
            Size = UDim2.fromScale(1, 1),
            Position = UDim2.fromOffset(0, 0),
            BackgroundTransparency = 1, Visible = false,
        }, combatParent)
        local columns = {}
        for index = 1, 2 do
            local column = uiCreate("ScrollingFrame", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ScrollBarThickness = 2,
                ScrollBarImageColor3 = ACCENT,
                Position = UDim2.new((index - 1) * 0.5, index == 1 and 0 or 6, 0, 0),
                Size = UDim2.new(0.5, -8, 1, 0),
                CanvasSize = UDim2.fromOffset(0, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                ScrollingDirection = Enum.ScrollingDirection.Y,
            }, subFrame)
            uiCreate("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                SortOrder = Enum.SortOrder.LayoutOrder,
                Padding = UDim.new(0, 11),
            }, column)
            columns[index] = column
        end
        return {frame = subFrame, columns = columns}
    end

    combat.views.Trigger = createCombatSubtab("Trigger")
    combat.views.Hitbox = createCombatSubtab("Hitbox")

    local function switchCombatTab(name, instant)
        local view = combat.views[name]
        if not view then return end
        if name == combat.active and not instant then
            if selectedPage ~= "Walka" then showPage("Walka") end
            return
        end
        combat.revision = (combat.revision or 0) + 1
        local revision = combat.revision
        local previous = combat.views[combat.active]
        if combat.tween then combat.tween:Cancel() end
        if combat.exitTween then combat.exitTween:Cancel() end
        combat.active = name
        for viewName, entry in pairs(combat.views) do
            if entry ~= view and entry ~= previous then
                entry.frame.Visible = false
                entry.frame.GroupTransparency = 0
                entry.frame.Position = UDim2.fromOffset(0, 0)
            end
        end
        if previous and previous ~= view and not instant then
            previous.frame.Visible = true
            previous.frame.ZIndex = 1
            combat.exitTween = TweenService:Create(previous.frame,
                TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                    GroupTransparency = 1,
                    Position = UDim2.fromOffset(0, -5),
                })
            combat.exitTween:Play()
            task.delay(0.16, function()
                if combat.revision ~= revision then return end
                previous.frame.Visible = false
                previous.frame.GroupTransparency = 0
                previous.frame.Position = UDim2.fromOffset(0, 0)
            end)
        elseif previous and previous ~= view then
            previous.frame.Visible = false
        end
        view.frame.Visible = true
        view.frame.ZIndex = 2
        view.frame.GroupTransparency = instant and 0 or 1
        view.frame.Position = UDim2.fromOffset(0, instant and 0 or 10)
        for viewName, button in pairs(combat.buttons) do
            local chosen = viewName == name
            if instant then
                button.BackgroundColor3 = chosen and INPUT or BAR
                button.TextColor3 = chosen and WHITE or MUTED
            else
                TweenService:Create(button,
                    TweenInfo.new(0.20, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                        BackgroundColor3 = chosen and INPUT or BAR,
                        TextColor3 = chosen and WHITE or MUTED,
                    }):Play()
            end
            button.Font = chosen and Enum.Font.GothamBold or Enum.Font.GothamMedium
        end
        if not instant then
            combat.tween = TweenService:Create(view.frame,
                TweenInfo.new(0.29, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    GroupTransparency = 0,
                    Position = UDim2.fromOffset(0, 0),
                })
            combat.tween:Play()
        end
        if selectedPage ~= "Walka" then showPage("Walka") end
    end

    for index, name in ipairs({"Silent", "Trigger", "Hitbox"}) do
        local tabButton = uiButton(header, name, BAR)
        tabButton.Name = "CombatTab" .. name
        tabButton.Size = UDim2.fromOffset(108, 34)
        tabButton.Position = UDim2.fromOffset(474 + (index - 1) * 115, 11)
        tabButton.TextSize = 12
        combat.buttons[name] = tabButton
        tabButton.MouseButton1Click:Connect(function()
            switchCombatTab(name, false)
        end)
    end

    headerTop.combatColumns = {
        Silent = combat.views.Silent.columns,
        Trigger = combat.views.Trigger.columns,
        Hitbox = combat.views.Hitbox.columns,
    }
    headerTop.showCombatSubtab = switchCombatTab
    switchCombatTab("Silent", true)
end
for i, item in ipairs(navDefs) do
    local key = item[1]
    local b = uiButton(side, "", key == selectedPage and INPUT or BAR)
    b.Size = UDim2.new(1, 0, 0, 46)
    b.Position = UDim2.fromOffset(0, (i-1)*54)
    local iconText = uiText(b, "", 22,
        key == selectedPage and WHITE or MUTED)
    iconText.Size = UDim2.fromOffset(36, 40)
    iconText.Position = UDim2.fromOffset(12, 3)
    iconText.TextXAlignment = Enum.TextXAlignment.Center
    local iconImage = uiCreate("ImageLabel", {
        Name = "SidebarIcon", BackgroundTransparency = 1,
        Size = UDim2.fromOffset(29, 29),
        Position = UDim2.fromOffset(16, 8),
        ScaleType = Enum.ScaleType.Fit,
        Image = sidebarIconAssets[key] or "",
        ImageColor3 = Color3.fromRGB(255, 255, 255)
    }, b)
    local navLabel = ({Walka = "Combat", Ustawienia = "Settings"})[key] or key
    local txt = uiText(b, navLabel, 12, key == selectedPage and WHITE or MUTED, true)
    txt.Size = UDim2.new(1, -66, 1,0)
    txt.Position = UDim2.fromOffset(59,0)
    links[key] = b
    linkLabels[key] = {iconText, txt}
    b.MouseButton1Click:Connect(function()
        showPage(key)
    end)
end

-- Floating popup layer for real dropdowns and editable RGB color selection.
local popup = nil
local popupGui = nil
local function closePopup()
    if popupGui then
        popupGui:Destroy()
        popupGui = nil
    end
    popup = nil
end
SpaceRuntime.ClosePopup = closePopup
local function makePopup(source, width, height)
    closePopup()
    -- Dedicated layer prevents the menu and scrolling panels from covering
    -- the palette or intercepting its clicks.
    popupGui = uiCreate("ScreenGui", {
        Name = "SpaceSolutionColorPopup",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 6000,
        ZIndexBehavior = Enum.ZIndexBehavior.Global
    }, guiParent)
    local blocker = uiCreate("TextButton", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 1
    }, popupGui)
    blocker.MouseButton1Click:Connect(closePopup)
    local p = uiCreate("Frame", {
        BackgroundColor3 = Color3.fromRGB(30,28,38),
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(width, height),
        ZIndex = 100,
        Active = true
    }, popupGui)
    uiRound(p, 8)
    uiCreate("UIStroke", {
        Color = Color3.fromRGB(67,63,84), Thickness = 1
    }, p)
    local from = source.AbsolutePosition
    local bottom = from.Y + source.AbsoluteSize.Y + 5
    local screenSize = workspace.CurrentCamera.ViewportSize
    if bottom + height > screenSize.Y - 10 then
        bottom = from.Y - height - 5
    end
    p.Position = UDim2.fromOffset(
        math.clamp(from.X, 5, math.max(5, screenSize.X-width-5)),
        math.max(5, bottom)
    )
    popup = p
    return p
end

local function makePanel(name, col)
    local panel = uiCreate("Frame", {
        BackgroundColor3 = PANEL, BorderSizePixel = 0,
        Size = UDim2.new(1,-5,0,50), AutomaticSize=Enum.AutomaticSize.Y
    }, col)
    uiRound(panel, 10)
    local headerLabel = uiText(panel, name, 12, MUTED, true)
    headerLabel.Position = UDim2.fromOffset(13, 9)
    headerLabel.Size = UDim2.new(1,-26,0,21)
    local content = uiCreate("Frame", {
        BackgroundTransparency = 1, BorderSizePixel=0,
        Position = UDim2.fromOffset(11,34), Size = UDim2.new(1,-22,0,0),
        AutomaticSize = Enum.AutomaticSize.Y
    }, panel)
    uiCreate("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0,4), SortOrder = Enum.SortOrder.LayoutOrder
    }, content)
    uiCreate("UIPadding", {PaddingBottom = UDim.new(0,12)}, content)
    local bottom = uiCreate("UIPadding", {PaddingBottom = UDim.new(0,12)}, panel)
    return content
end

local function controlRecord(registry, key, init)
    local rec = {Value = init}
    registry[key] = rec
    function rec:OnChanged(fn)
        self.onChanged = fn
        return self
    end
    function rec:SetValue(value)
        self.Value = value
        if self.draw then self.draw(value) end
        if self.onChanged then self.onChanged() end
    end
    return rec
end
local function controlLabel(content, s, height, muted)
    local txt = uiText(content, s, 11, muted and MUTED or WHITE)
    txt.Size = UDim2.new(1,0,0,height or 24)
    return txt
end
local function addColorControl(content, key, config, parentRow)
    local row = parentRow or uiCreate("Frame", {
        Size = UDim2.new(1,0,0,30), BackgroundTransparency=1
    }, content)
    if not parentRow then
        local t = uiText(row, config.Title or key, 11, MUTED)
        t.Size=UDim2.new(1,-52,1,0)
    end
    local swatch = uiButton(row,"",config.Default or Color3.new(1,1,1))
    swatch.Size=UDim2.fromOffset(25,20)
    swatch.Position=UDim2.new(1, parentRow and -65 or -31, 0.5,-10)
    uiRound(swatch,4)
    local opt=controlRecord(Options,key,config.Default or Color3.new(1,1,1))
    opt.draw=function(v) swatch.BackgroundColor3=v end
    swatch.MouseButton1Click:Connect(function()
        local popupFrame = makePopup(swatch, 222, 178)
        local title=uiText(popupFrame, config.Title or "Pick color", 12, WHITE, true)
        title.Position=UDim2.fromOffset(12,4)
        title.Size=UDim2.new(1,-24,0,25)
        local colors={
            Color3.fromRGB(255,255,255),Color3.fromRGB(8,8,8),
            Color3.fromRGB(230,70,80),Color3.fromRGB(255,150,45),
            Color3.fromRGB(250,223,80),Color3.fromRGB(61,229,119),
            Color3.fromRGB(0,255,180),Color3.fromRGB(82,180,255),
            Color3.fromRGB(87,111,241),Color3.fromRGB(170,107,252),
            Color3.fromRGB(255,83,180),Color3.fromRGB(0,195,206)
        }
        local fields = {}
        for i, value in ipairs(colors) do
            local b=uiButton(popupFrame, "", value)
            b.Size=UDim2.fromOffset(28,24)
            b.Position=UDim2.fromOffset(13+((i-1)%6)*34,36+math.floor((i-1)/6)*30)
            b.ZIndex=102
            b.MouseButton1Click:Connect(function()
                opt:SetValue(value)
                for j, field in ipairs(fields or {}) do
                    if field then
                        local channel = j == 1 and value.R or j == 2 and value.G or value.B
                        field.Text = tostring(math.floor(channel * 255 + 0.5))
                    end
                end
            end)
        end
        for i,info in ipairs({{"R", "R"},{"G","G"},{"B","B"}}) do
            local txt=uiText(popupFrame,info[1],11,MUTED)
            txt.Position=UDim2.fromOffset(15+(i-1)*69,100)
            txt.Size=UDim2.fromOffset(15,23)
            txt.ZIndex=102
            local value = i==1 and opt.Value.R or i==2 and opt.Value.G or opt.Value.B
            local field=uiCreate("TextBox", {
                Size=UDim2.fromOffset(43,23),Position=UDim2.fromOffset(32+(i-1)*69,100),
                BackgroundColor3=INPUT,TextColor3=WHITE,TextSize=12,
                Font=Enum.Font.GothamMedium,Text=tostring(math.floor(value*255+0.5)),
                ClearTextOnFocus=false,ZIndex=102
            },popupFrame)
            uiRound(field,4)
            fields[i]=field
        end
        local apply=uiButton(popupFrame,"Apply RGB", ACCENT)
        apply.Position=UDim2.fromOffset(12,135)
        apply.Size=UDim2.fromOffset(198,29)
        apply.ZIndex=102
        apply.MouseButton1Click:Connect(function()
            local r=tonumber(fields[1].Text)
            local g=tonumber(fields[2].Text)
            local b=tonumber(fields[3].Text)
            if r and g and b then
                opt:SetValue(Color3.fromRGB(math.clamp(r,0,255),math.clamp(g,0,255),math.clamp(b,0,255)))
            end
            closePopup()
        end)
    end)
    return opt
end

local function buildControls(content)
    local controls = {Container = content}
    function controls:Resize() end
    function controls:AddToggle(id, info)
        local row=uiCreate("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,29)},content)
        local square=uiButton(row, "", INPUT)
        square.Size=UDim2.fromOffset(20,20)
        square.Position=UDim2.fromOffset(2,5)
        square.TextSize=12
        local txt=uiText(row, info.Text or id,11,MUTED)
        txt.Position=UDim2.fromOffset(31,0)
        txt.Size=UDim2.new(1,-46,1,0)
        local rec=controlRecord(Toggles,id,info.Default or false)
        local firstDraw = true
        rec.draw=function(v)
            local squareColor = v and Color3.fromRGB(255,255,255) or Color3.fromRGB(100,100,110)
            local labelColor = v and WHITE or MUTED
            if firstDraw then
                square.BackgroundColor3 = squareColor
                txt.TextColor3 = labelColor
                firstDraw = false
            else
                TweenService:Create(square,
                    TweenInfo.new(0.17, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                    {BackgroundColor3 = squareColor}):Play()
                TweenService:Create(txt,
                    TweenInfo.new(0.17, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                    {TextColor3 = labelColor}):Play()
            end
            square.TextColor3 = Color3.fromRGB(20,20,24)
            square.Text = ""
        end
        rec.draw(rec.Value)
        square.MouseButton1Click:Connect(function() rec:SetValue(not rec.Value) end)
        function rec:AddColorPicker(key,config)
            return addColorControl(content,key,config,row)
        end
        function rec:AddKeyPicker(key,config)
            return controls:_keyPicker(key,config)
        end
        return rec
    end
    function controls:AddLabel(value)
        local row=controlLabel(content,value,25,true)
        local ctrl={}
        function ctrl:AddColorPicker(id,config)
            return addColorControl(content,id,config,row)
        end
        function ctrl:AddKeyPicker(id,config)
            return controls:_keyPicker(id,config)
        end
        return ctrl
    end
    function controls:_keyPicker(id, config)
        local row=uiCreate("Frame",{Size=UDim2.new(1,0,0,35),BackgroundTransparency=1},content)
        local desc=uiText(row,config.Text or id,11,MUTED)
        desc.Size=UDim2.new(.48,0,1,0)
        local b=uiButton(row,config.Default or "RightAlt",INPUT)
        b.Position=UDim2.new(1,-128,0,2)
        b.Size=UDim2.fromOffset(126,30)
        local rec=controlRecord(Options,id,config.Default or "RightAlt")
        rec.draw=function(v) b.Text=tostring(v) end
        b.MouseButton1Click:Connect(function()
            closePopup()
            headerTop.capturingBind = true
            b.Text="Press a key..."
            local listener
            listener=SpaceRuntime:Connect(UserInputService.InputBegan, function(inp)
                if inp.UserInputType==Enum.UserInputType.Keyboard
                    or inp.UserInputType==Enum.UserInputType.MouseButton1
                    or inp.UserInputType==Enum.UserInputType.MouseButton2
                    or inp.UserInputType==Enum.UserInputType.MouseButton3 then
                    listener:Disconnect()
                    local key = inp.UserInputType==Enum.UserInputType.Keyboard
                        and inp.KeyCode.Name or inp.UserInputType.Name
                    rec:SetValue(key)
                    task.defer(function() headerTop.capturingBind = false end)
                end
            end)
        end)
        return rec
    end
    function controls:AddKeyPicker(id,info)
        return self:_keyPicker(id,info)
    end
    function controls:AddColorPicker(id,info)
        return addColorControl(content,id,info)
    end
    function controls:AddDropdown(id,info)
        local row=uiCreate("Frame",{Size=UDim2.new(1,0,0,51),BackgroundTransparency=1},content)
        local desc=uiText(row,info.Text or id,11,MUTED)
        desc.Size=UDim2.new(1,-8,0,21)
        local b=uiButton(row,"",INPUT)
        b.Size=UDim2.new(1,-4,0,27)
        b.Position=UDim2.fromOffset(2,22)
        b.TextXAlignment=Enum.TextXAlignment.Left
        local rec=controlRecord(Options,id,info.Default or (info.Values and info.Values[1]))
        rec.values=info.Values or {}
        rec.draw=function(v) b.Text="  "..tostring(v or "--") end
        function rec:SetValues(values)
            self.values=values or {}
            if self.Value and not table.find(self.values,self.Value) then self:SetValue(nil) end
        end
        rec.draw(rec.Value)
        b.MouseButton1Click:Connect(function()
            if #rec.values==0 then return end
            local height=math.min(7,#rec.values)*28+10
            local p=makePopup(b,math.max(170,b.AbsoluteSize.X),height)
            local scroll=uiCreate("ScrollingFrame",{
                BackgroundTransparency=1, BorderSizePixel=0,
                Size=UDim2.new(1,-6,1,-7),Position=UDim2.fromOffset(3,3),
                CanvasSize=UDim2.fromOffset(0,#rec.values*28),ScrollBarThickness=3,
                ScrollBarImageColor3=ACCENT,ZIndex=101
            },p)
            for i,val in ipairs(rec.values) do
                local o=uiButton(scroll,tostring(val),INPUT)
                o.Position=UDim2.fromOffset(3,(i-1)*28)
                o.Size=UDim2.new(1,-9,0,26)
                o.ZIndex=102
                o.MouseButton1Click:Connect(function()
                    rec:SetValue(val)
                    closePopup()
                end)
            end
        end)
        return rec
    end
    function controls:AddSlider(id,info)
        local row=uiCreate("Frame",{Size=UDim2.new(1,0,0,57),BackgroundTransparency=1},content)
        local desc=uiText(row,info.Text or id,11,MUTED)
        desc.Size=UDim2.new(1,-91,0,22)
        local number=uiText(row,"",11,MUTED)
        number.Position=UDim2.new(1,-88,0,0)
        number.Size=UDim2.fromOffset(86,22)
        number.TextXAlignment=Enum.TextXAlignment.Right
        local track=uiCreate("Frame",{
            Size=UDim2.new(1,-20,0,7),Position=UDim2.fromOffset(10,37),
            BackgroundColor3=INPUT,BorderSizePixel=0
        },row)
        uiRound(track,7)
        local fill=uiCreate("Frame",{
            Size=UDim2.fromScale(0,1),BackgroundColor3=Color3.fromRGB(205,207,225),BorderSizePixel=0
        },track)
        uiRound(fill,7)
        local knob=uiCreate("Frame",{
            Size=UDim2.fromOffset(15,15),AnchorPoint=Vector2.new(.5,.5),
            Position=UDim2.fromScale(0,.5),BackgroundColor3=WHITE,BorderSizePixel=0
        },track)
        uiRound(knob,15)
        local minv,maxv=info.Min or 0,info.Max or 100
        local precision=10^(info.Rounding or 0)
        local dragging = false
        local firstDraw = true
        local rec=controlRecord(Options,id,info.Default or minv)
        rec.draw=function(v)
            local alpha=math.clamp((v-minv)/math.max(.0001,maxv-minv),0,1)
            local targetSize = UDim2.fromScale(alpha, 1)
            local targetPosition = UDim2.fromScale(alpha, 0.5)
            if dragging or firstDraw then
                fill.Size = targetSize
                knob.Position = targetPosition
                firstDraw = false
            else
                -- Configuration/preset changes are eased; dragging remains direct and responsive.
                TweenService:Create(fill,
                    TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                    {Size = targetSize}):Play()
                TweenService:Create(knob,
                    TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
                    {Position = targetPosition}):Play()
            end
            number.Text=tostring(v)
        end
        rec.draw(rec.Value)
        local function move(x)
            local alpha=math.clamp((x-track.AbsolutePosition.X)/math.max(1,track.AbsoluteSize.X),0,1)
            rec:SetValue(math.floor((minv+alpha*(maxv-minv))*precision+.5)/precision)
        end
        local function beginSlide(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then
                dragging=true
                move(inp.Position.X)
            end
        end
        row.InputBegan:Connect(beginSlide)
        track.InputBegan:Connect(beginSlide)
        knob.InputBegan:Connect(beginSlide)
        SpaceRuntime:Connect(UserInputService.InputChanged, function(inp)
            if dragging and inp.UserInputType==Enum.UserInputType.MouseMovement then
                move(inp.Position.X)
            end
        end)
        SpaceRuntime:Connect(UserInputService.InputEnded, function(inp)
            if inp.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
        end)
        return rec
    end
    function controls:AddInput(id,info)
        local row=uiCreate("Frame",{Size=UDim2.new(1,0,0,58),BackgroundTransparency=1},content)
        local desc=uiText(row,info.Text or id,11,MUTED)
        desc.Size=UDim2.new(1,-4,0,22)
        local box=uiCreate("TextBox",{
            Size=UDim2.new(1,-4,0,30),Position=UDim2.fromOffset(2,25),
            BackgroundColor3=INPUT,BorderSizePixel=0,TextColor3=WHITE,
            PlaceholderColor3=MUTED,PlaceholderText=info.Placeholder or "",
            Text=info.Default or "",Font=Enum.Font.GothamMedium,TextSize=13,
            ClearTextOnFocus=false,TextXAlignment=Enum.TextXAlignment.Left
        },row)
        uiRound(box,7)
        local pad=uiCreate("UIPadding",{PaddingLeft=UDim.new(0,8)},box)
        local rec=controlRecord(Options,id,info.Default or "")
        rec.draw=function(v) if box.Text~=v then box.Text=v end end
        box:GetPropertyChangedSignal("Text"):Connect(function()
            if rec.Value~=box.Text then rec:SetValue(box.Text) end
        end)
        return rec
    end
    function controls:AddButton(text,callback)
        local b=uiButton(content,text,INPUT)
        b.Size=UDim2.new(1,-2,0,35)
        b.MouseButton1Click:Connect(callback)
        return b
    end
    return controls
end

-- Misc movement tools: Speed and Noclip (Fly fully removed).
-- Isolated function scope prevents exceeding Luau's local-register limit.
;(function()
    local state = {
        Noclip = false, Speed = false, SpeedMultiplier = 2,
        NoclipOriginal = {},
        SpeedHumanoid = nil, NormalWalkSpeed = nil,
        Unloaded = false,
    }

    local function disableSpeed()
        if state.SpeedHumanoid and state.SpeedHumanoid.Parent
            and state.NormalWalkSpeed then
            pcall(function()
                state.SpeedHumanoid.WalkSpeed = state.NormalWalkSpeed
            end)
        end
        state.SpeedHumanoid = nil
        state.NormalWalkSpeed = nil
    end

    local function restoreCollision()
        for part, canCollide in pairs(state.NoclipOriginal) do
            if part and part.Parent then
                pcall(function() part.CanCollide = canCollide end)
            end
        end
        table.clear(state.NoclipOriginal)
    end

    -- UI layout matches the current SpaceSolution style and config registry.
    local noclip = buildControls(makePanel("Noclip", pages.Misc.columns[1]))
    noclip:AddToggle("MiscNoclip", {
        Text = "Noclip Enabled", Default = false
    }):OnChanged(function()
        state.Noclip = Toggles.MiscNoclip.Value
        if not state.Noclip then restoreCollision() end
    end)

    local speed = buildControls(makePanel("Speed", pages.Misc.columns[1]))
    speed:AddToggle("MiscSpeed", {
        Text = "Speed Enabled", Default = false
    }):OnChanged(function()
        state.Speed = Toggles.MiscSpeed.Value
        if not state.Speed then disableSpeed() end
    end)
    speed:AddSlider("MiscSpeedMultiplier", {
        Text = "Speed Multiplier", Min = 1, Max = 10,
        Default = 2, Rounding = 1
    }):OnChanged(function()
        state.SpeedMultiplier = math.clamp(
            tonumber(Options.MiscSpeedMultiplier.Value) or 2, 1, 10)
    end)

    -- Same WalkSpeed multiplier and movement boost as the source script.
    local speedConnection = SpaceRuntime:Connect(RunService.Stepped, function()
        if state.Unloaded then return end
        if not state.Speed then
            if state.SpeedHumanoid then disableSpeed() end
            return
        end
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if not humanoid or humanoid.Health <= 0 then
            if state.SpeedHumanoid then disableSpeed() end
            return
        end
        if state.SpeedHumanoid ~= humanoid then
            disableSpeed()
            state.SpeedHumanoid = humanoid
            state.NormalWalkSpeed = humanoid.WalkSpeed
        end
        local desiredSpeed = (state.NormalWalkSpeed or 16) * state.SpeedMultiplier
        if humanoid.WalkSpeed ~= desiredSpeed then
            humanoid.WalkSpeed = desiredSpeed
        end
        if root and humanoid.MoveDirection.Magnitude > 0 then
            local boost = (state.SpeedMultiplier - 1) * 0.28
            if boost > 0 then
                root.CFrame += humanoid.MoveDirection * boost
            end
        end
    end)

    -- Restore each body's original CanCollide value after Noclip is disabled.
    local noclipParts, noclipCharacter, noclipRefresh = {}, nil, 0
    local noclipNextUpdate = 0
    local noclipConnection = SpaceRuntime:Connect(RunService.Stepped, function()
        if state.Unloaded or not state.Noclip then return end
        local now = os.clock()
        if now < noclipNextUpdate then return end
        noclipNextUpdate = now + (1 / 30)
        local character = LocalPlayer.Character
        if not character then return end
        if character ~= noclipCharacter or now >= noclipRefresh then
            noclipCharacter = character
            noclipRefresh = now + 1
            table.clear(noclipParts)
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    noclipParts[#noclipParts + 1] = part
                end
            end
        end
        for _, part in ipairs(noclipParts) do
            if part.Parent then
                if state.NoclipOriginal[part] == nil then
                    state.NoclipOriginal[part] = part.CanCollide
                end
                if part.CanCollide then part.CanCollide = false end
            end
        end
    end)

    local characterConnection = SpaceRuntime:Connect(LocalPlayer.CharacterAdded, function()
        disableSpeed()
        restoreCollision()
    end)

    SpaceRuntime:AddCleanup(function()
        state.Unloaded = true
        speedConnection:Disconnect()
        noclipConnection:Disconnect()
        characterConnection:Disconnect()
        disableSpeed()
        restoreCollision()
    end)
end)()

-- Settings page: Globals on the left, ConfigManager on the right.
local menuKey = Enum.KeyCode.Delete
local panicKey = nil
local globalsContent = makePanel("Globals", pages["Ustawienia"].columns[1])
local globalsControls = buildControls(globalsContent)
-- Appearance controls are stored as normal options for the existing config manager.
-- One switch controls both GUI and watermark rainbow colors.
globalsControls:AddToggle("GejMode", {Text = "Gej Mode", Default = false})
-- Speed of the shared GUI + watermark rainbow; saved with other settings.
globalsControls:AddSlider("GejModeRainbowSpeed", {Text = "Rainbow Speed", Min = 0.02, Max = 1.0, Default = 0.12, Rounding = 2})
globalsControls:AddToggle("WaterMark", {Text = "WaterMark", Default = false})
-- Separate ScreenGui keeps the watermark visible while the menu is hidden.
local oldWatermarkGui = guiParent:FindFirstChild("SpaceSolutionWatermark")
if oldWatermarkGui then oldWatermarkGui:Destroy() end
local watermarkGui = uiCreate("ScreenGui", {
    Name = "SpaceSolutionWatermark", ResetOnSpawn = false,
    IgnoreGuiInset = true, DisplayOrder = 5001
}, guiParent)
SpaceRuntime.WatermarkUI = watermarkGui
local watermarkBar = uiCreate("Frame", {
    Name = "WatermarkBar", Position = UDim2.new(1, -292, 0, 12),
    Size = UDim2.fromOffset(280, 32), BackgroundColor3 = Color3.fromRGB(24, 24, 30),
    BorderSizePixel = 0, Visible = false
}, watermarkGui)
uiRound(watermarkBar, 5)
uiCreate("UIStroke", {Color = Color3.fromRGB(105, 105, 116), Thickness = 1}, watermarkBar)
local watermark = uiText(watermarkBar,
    "SpaceSolution | User - " .. LocalPlayer.Name, 14, Color3.fromRGB(255, 255, 255), true)
watermark.Position = UDim2.fromOffset(12, 0)
watermark.Size = UDim2.new(1, -24, 1, -2)
local watermarkLine = uiCreate("Frame", {
    Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0
}, watermarkBar)
Toggles.WaterMark:OnChanged(function()
    watermarkBar.Visible = Toggles.WaterMark.Value
end)
-- Custom username shown after "User -"; the SpaceSolution title stays fixed.
-- Watermark User and Watermark Position are saved by ConfigManager.
-- Keep this in a separate scope to avoid Luau's 200-local-register limit.
do
    local positionTween = nil
    local textService = game:GetService("TextService")

    local function getWatermarkPosition()
        local width = watermarkBar.Size.X.Offset
        local choice = Options.WatermarkPosition and Options.WatermarkPosition.Value or "Right"
        if choice == "Left" then
            return UDim2.new(0, 12, 0, 12)
        elseif choice == "Center" then
            return UDim2.new(0.5, -width / 2, 0, 12)
        end
        return UDim2.new(1, -width - 12, 0, 12)
    end

    local function updateWatermarkUser()
        local userName = Options.WatermarkUser and Options.WatermarkUser.Value or LocalPlayer.Name
        userName = tostring(userName):gsub("[%c]", " "):match("^%s*(.-)%s*$")
        if userName == "" then userName = LocalPlayer.Name end

        watermark.Text = "SpaceSolution | User - " .. userName
        watermark.TextTruncate = Enum.TextTruncate.AtEnd
        local textWidth = textService:GetTextSize(
            watermark.Text, 14, Enum.Font.GothamBold, Vector2.new(2000, 32)
        ).X
        local camera = workspace.CurrentCamera
        local screenWidth = camera and camera.ViewportSize.X or 800
        local maxWidth = math.max(120, math.min(600, screenWidth - 24))
        local width = math.clamp(math.ceil(textWidth + 28), math.min(200, maxWidth), maxWidth)
        watermarkBar.Size = UDim2.fromOffset(width, 32)

        if positionTween then positionTween:Cancel() end
        watermarkBar.Position = getWatermarkPosition()
    end

    globalsControls:AddInput("WatermarkUser", {
        Text = "Watermark User",
        Placeholder = "Enter the username to display",
        Default = LocalPlayer.Name,
    }):OnChanged(updateWatermarkUser)

    globalsControls:AddDropdown("WatermarkPosition", {
        Text = "Watermark Position",
        Values = {"Left", "Center", "Right"},
        Default = "Right",
    }):OnChanged(function()
        if positionTween then positionTween:Cancel() end
        positionTween = TweenService:Create(watermarkBar,
            TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
            {Position = getWatermarkPosition()})
        positionTween:Play()
    end)

    updateWatermarkUser()
end
-- Reconnect to the current server (or rejoin the same place if needed).
globalsControls:AddButton("Reconnect", function()
    local TeleportService = game:GetService("TeleportService")
    local placeId = game.PlaceId
    local serverId = game.JobId
    local success = false

    if type(serverId) == "string" and serverId ~= "" then
        success = pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, serverId, LocalPlayer)
        end)
    end

    if not success then
        local fallbackSuccess, err = pcall(function()
            TeleportService:Teleport(placeId, LocalPlayer)
        end)
        if not fallbackSuccess then
            warn("SpaceSolution Reconnect failed: " .. tostring(err))
        end
    end
end)
globalsControls:AddKeyPicker("MenuKey", {Text = "Menu Key", Default = "Delete"}):OnChanged(function()
    local key = Enum.KeyCode[Options.MenuKey.Value]
    if key then menuKey = key end
end)
globalsControls:AddKeyPicker("PanicKey", {Text = "Panic Key", Default = "None"}):OnChanged(function()
    panicKey = Enum.KeyCode[Options.PanicKey.Value]
end)
globalsControls:AddButton("Hide Menu", function()
    closePopup()
    animateMenu(false) -- Press the configured Menu Key to reopen.
end)
globalsControls:AddButton("Unload Script (ALL OFF)", function()
    SpaceRuntime:Unload()
end)
local unifiedConfigContent = nil
local Library = {}
function Library:CreateWindow(_)
    local window = {}
    function window:AddTab(name)
        local mapped = name=="General" and "Walka" or name=="ESP" and "Visuals" or "Ustawienia"
        local tab = {}
        function tab:_box(title, column)
            local target=mapped
            -- Route Combat panels to the correct header subtab.
            local col=pages[target].columns[column]
            if name == "General" and headerTop.combatColumns then
                if title == "Trigger Bot" then
                    col = headerTop.combatColumns.Trigger[1]
                elseif title == "Hitbox Expander" then
                    col = headerTop.combatColumns.Hitbox[1]
                elseif title == "Hitbox Preview" then
                    col = headerTop.combatColumns.Hitbox[2]
                else
                    col = headerTop.combatColumns.Silent[column]
                end
            end
            local displayName = title
            if name=="General" and title=="Main" then displayName="Silent Aim" end
            if name=="General" and title=="Visuals" then displayName="FOV Settings" end
            if name=="ESP" and title=="ESP Features" then displayName="ESP Visuals" end
            if mapped == "Ustawienia" then
                if not unifiedConfigContent then
                    unifiedConfigContent = makePanel("ConfigManager", pages["Ustawienia"].columns[2])
                end
                local section = uiText(unifiedConfigContent, title, 12, WHITE, true)
                section.Size = UDim2.new(1, -4, 0, 29)
                section.TextXAlignment = Enum.TextXAlignment.Left
                return {AddTab=function(_,_) return buildControls(unifiedConfigContent) end}
            end
            local content=makePanel(displayName,col)
            return {AddTab=function(_,_) return buildControls(content) end}
        end
        function tab:AddLeftTabbox(title) return self:_box(title,1) end
        function tab:AddRightTabbox(title) return self:_box(title,2) end
        return tab
    end
    return window
end

-- Friend list shared by combat targeting, hitboxes and ESP.
-- UserId keys stay stable even if a player changes their display name.
-- Side page "List": show real connected players, with no additional gameplay hooks.
local listContent=makePanel("Players / Friends",pages.List.columns[1])
controlLabel(listContent,"Add Friend chroni przed celowaniem. Friend ESP jest osobne.",40,true)
local listItems={}
local FriendESPEnabled={}
local FriendHighlights={}
-- Dedicated color picker; saved automatically with other Options in CFG.
local friendAppearance=makePanel("Friend ESP Settings",pages.List.columns[2])
addColorControl(friendAppearance,"FriendESPColor",{
    Title="Friend ESP Color", Default=Color3.fromRGB(80,255,150)
})


local function clearFriendHighlight(userId)
    local highlight=FriendHighlights[userId]
    if highlight then pcall(function() highlight:Destroy() end) end
    FriendHighlights[userId]=nil
end

local renderList
renderList=function()
    if not SpaceRuntime.Active then return end
    for _,item in ipairs(listItems) do item:Destroy() end
    table.clear(listItems)
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local friend=isSpaceFriend(plr)
            local row=uiCreate("Frame",{
                BackgroundTransparency=1, Size=UDim2.new(1,-4,0,64)
            },listContent)
            local label=uiText(row,plr.DisplayName.." (@"..plr.Name..")",10,WHITE)
            label.Size=UDim2.new(1,-112,0,30)
            local button=uiButton(row,friend and "Remove Friend" or "Add Friend",
                friend and Color3.fromRGB(45,90,70) or INPUT)
            button.Size=UDim2.fromOffset(105,26)
            button.Position=UDim2.new(1,-108,0,3)
            button.TextSize=10
            button.MouseButton1Click:Connect(function()
                if isSpaceFriend(plr) then
                    SpaceFriends[plr.UserId]=nil
                    FriendESPEnabled[plr.UserId]=nil
                    clearFriendHighlight(plr.UserId)
                else
                    SpaceFriends[plr.UserId]=true
                end
                renderList()
            end)
            if friend then
                local espOn=FriendESPEnabled[plr.UserId] == true
                local esp=uiButton(row,espOn and "Friend ESP: ON" or "Friend ESP: OFF",
                    espOn and Color3.fromRGB(45,90,70) or INPUT)
                esp.Size=UDim2.new(1,0,0,25)
                esp.Position=UDim2.new(0,0,0,35)
                esp.TextSize=10
                esp.MouseButton1Click:Connect(function()
                    FriendESPEnabled[plr.UserId]=not FriendESPEnabled[plr.UserId]
                    if not FriendESPEnabled[plr.UserId] then clearFriendHighlight(plr.UserId) end
                    renderList()
                end)
            end
            listItems[#listItems+1]=row
        end
    end
end
renderList()
SpaceRuntime:Connect(Players.PlayerAdded,renderList)
SpaceRuntime:Connect(Players.PlayerRemoving,function(player)
    clearFriendHighlight(player.UserId)
    task.defer(renderList)
end)

-- Friend ESP is intentionally independent of normal ESP and its exclusion list.
do
    local elapsed=0
    SpaceRuntime:Connect(RunService.Heartbeat,function(dt)
        elapsed=elapsed+dt
        if elapsed<0.1 then return end
        elapsed=0
        for _,player in ipairs(Players:GetPlayers()) do
            if player~=LocalPlayer then
                local id=player.UserId
                local character=player.Character
                local active=isSpaceFriend(player) and FriendESPEnabled[id] and character
                if not active then
                    clearFriendHighlight(id)
                else
                    local highlight=FriendHighlights[id]
                    if not highlight or highlight.Parent~=character then
                        clearFriendHighlight(id)
                        highlight=Instance.new("Highlight")
                        highlight.Name="SpaceSolutionFriendESP"
                        highlight.Adornee=character
                        highlight.FillTransparency=0.7
                        highlight.OutlineTransparency=0
                        highlight.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
                        highlight.Parent=character
                        FriendHighlights[id]=highlight
                    end
                    -- Friend ESP color is independent from Rainbow ESP.
                    local color=(Options.FriendESPColor and Options.FriendESPColor.Value)
                        or Color3.fromRGB(80,255,150)
                    if highlight.FillColor~=color then highlight.FillColor=color end
                    if highlight.OutlineColor~=color then highlight.OutlineColor=color end
                end
            end
        end
    end)
    SpaceRuntime:AddCleanup(function()
        for id in pairs(FriendHighlights) do clearFriendHighlight(id) end
    end)
end

-- Drag by top bar, toggle menu with Delete (configurable).
local drag,grab,orig=false,nil,nil
header.InputBegan:Connect(function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=true;grab=inp.Position;orig=frame.Position
    end
end)
SpaceRuntime:Connect(UserInputService.InputChanged, function(inp)
    if drag and inp.UserInputType==Enum.UserInputType.MouseMovement then
        local d=inp.Position-grab
        frame.Position=UDim2.new(orig.X.Scale,orig.X.Offset+d.X/uiScale.Scale,
            orig.Y.Scale,orig.Y.Offset+d.Y/uiScale.Scale)
    end
end)
SpaceRuntime:Connect(UserInputService.InputEnded, function(inp)
    if inp.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end
end)
-- Global menu hotkey: works even while the ScreenGui is hidden.
SpaceRuntime:Connect(UserInputService.InputBegan, function(inp, processed)
    if UserInputService:GetFocusedTextBox() then return end
    if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if inp.KeyCode == menuKey then
        closePopup()
        animateMenu(not menuOpen)
    elseif panicKey and inp.KeyCode == panicKey then
        closePopup()
        animateMenu(false)
    end
end)


local Window = Library:CreateWindow({Title = 'Space solution', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2})

local GeneralTab = Window:AddTab("General")

local ESPTab = Window:AddTab("ESP")
local ConfigTab = Window:AddTab("Config")

local ESPBox = ESPTab:AddLeftTabbox("ESP Features")

local ESPControls = ESPBox:AddTab("Visuals")

ESPControls:AddToggle("SkeletonEnabled", {Text = "Skeleton ESP", Default = false}):AddColorPicker("SkeletonColor", {Default = Color3.fromRGB(255,255,255), Title = "Skeleton Color"})

ESPControls:AddSlider("SkeletonThickness", {Text = "Skeleton Thickness", Default = 2.5, Min = 0.5, Max = 10, Rounding = 1})

ESPControls:AddToggle("ESPRainbow", {Text = "Rainbow ESP (All Colors)", Default = false})

-- Self ESP: highlight your own character (independent from other players' ESP).
ESPControls:AddToggle("SelfESPEnabled", {Text = "Self ESP", Default = false})
    :AddColorPicker("SelfESPColor", {Default = Color3.fromRGB(255,255,255), Title = "Self ESP Color"})
ESPControls:AddToggle("SelfESPThroughWalls", {Text = "Self ESP Through Walls", Default = false})

-- China Hat (local character, screen-space 3D projection)
ESPControls:AddToggle("ChinaHatEnabled", {Text = "China Hat", Default = false})
    :AddColorPicker("ChinaHatColor", {Default = Color3.fromRGB(255, 255, 255), Title = "China Hat Color"})
ESPControls:AddSlider("ChinaHatSize", {Text = "China Hat Size", Default = 1, Min = 0.5, Max = 2, Rounding = 2})
ESPControls:AddToggle("ChinaHatRainbow", {Text = "China Hat Rainbow", Default = false})



ESPControls:AddSlider("ESPUpdateRate", {Text = "ESP Update Rate (Hz)", Default = 60, Min = 15, Max = 180, Rounding = 0})

ESPControls:AddToggle("HeadDotEnabled", {Text = "Head Dot", Default = false}):AddColorPicker("HeadDotColor", {Default = Color3.fromRGB(255,255,255), Title = "Head Dot Color"})

ESPControls:AddSlider("HeadDotSize", {Text = "Head Dot Size (pixels)", Default = 3, Min = 1, Max = 10, Rounding = 0})

-- Screen-space radius: shared by every Head Dot (near/far players and ESP Preview).
-- No camera-distance multiplier or preview-only scaling.
local function getHeadDotRadiusPixels()
    local size = Options.HeadDotSize and tonumber(Options.HeadDotSize.Value) or 3
    return math.clamp(math.floor(size + 0.5), 1, 10)
end


ESPControls:AddToggle("BoxESPEnabled", {Text = "Box ESP", Default = false}):AddColorPicker("BoxESPColor", {Default = Color3.fromRGB(0,255,180), Title = "Box Color"})

ESPControls:AddToggle("BoxCornered", {Text = "Cornered Box", Default = false})

ESPControls:AddSlider("BoxThickness", {Text = "Box Thickness", Default = 1, Min = 1, Max = 10, Rounding = 1})

ESPControls:AddToggle("ChamsESPEnabled", {Text = "Chams ESP", Default = false})

ESPControls:AddLabel("Chams Visible Color"):AddColorPicker("ChamsVisibleColor", {Default = Color3.fromRGB(0,255,100), Title = "Visible Color"})

ESPControls:AddLabel("Chams Invisible Color"):AddColorPicker("ChamsInvisibleColor", {Default = Color3.fromRGB(255,80,80), Title = "Invisible Color"})

ESPControls:AddToggle("TracerESPEnabled", {Text = "Tracer ESP", Default = false}):AddColorPicker("TracerESPColor", {Default = Color3.fromRGB(255,255,255), Title = "Tracer Color"})

ESPControls:AddSlider("TracerThickness", {Text = "Tracers Thickness", Default = 1, Min = 1, Max = 10, Rounding = 1})

ESPControls:AddToggle("NameESPEnabled", {Text = "Name ESP", Default = false}):AddColorPicker("NameESPColor", {Default = Color3.fromRGB(255,255,255), Title = "Name Color"})

ESPControls:AddDropdown("ESPNameType", {Text = "Name Type", Default = "Display Name", Values = {"Display Name", "Username"}, AllowNull = false})

-- Fixed Distance ESP calibration (no slider): 110m -> approximately 177.5m.
-- ESP Preview uses the same fixed distance scale.
ESPControls:AddToggle("DistanceESPEnabled", {Text = "Distance ESP", Default = false}):AddColorPicker("DistanceESPColor", {Default = Color3.fromRGB(255,255,255), Title = "Distance Color"})

ESPControls:AddDropdown("ESPDistancePosition", {
    Text = "Distance Position",
    Default = "Top",
    Values = {"Top", "Bottom", "Right", "Left"},
    AllowNull = false
})

-- Independent text-size sliders for actual in-game ESP labels.
ESPControls:AddSlider("NameESPTextSize", {
    Text = "Name ESP Text Size (in game)", Default = 15,
    Min = 12, Max = 22, Rounding = 0
})

ESPControls:AddSlider("DistanceESPTextSize", {
    Text = "Distance ESP Text Size (in game)", Default = 15,
    Min = 12, Max = 22, Rounding = 0
})

ESPControls:AddToggle("ESPTeamCheck", {Text = "Team Check", Default = false})

ESPControls:AddSlider("ESPMaxDistance", {Text = "Max Distance (studs)", Default = 1000, Min = 50, Max = 5000, Rounding = 0})

-- ESP PREVIEW: a lightweight in-menu dummy, not another ESP overlay.
-- Uses real Roblox GUI Frames inside Linoria's right-hand tabbox.
local ESPPreviewBox = ESPTab:AddRightTabbox("ESP Preview")
local ESPPreviewTab = ESPPreviewBox:AddTab("Preview")

ESPPreviewTab:AddLabel("ESP Preview - live settings")
ESPPreviewTab:AddDropdown("ESPPreviewChamsState", {
    Text = "Chams Preview",
    Values = {"Visible", "Invisible"},
    Default = "Visible",
    AllowNull = false
})

local previewHost = Instance.new("Frame")
previewHost.Name = "ESPPreviewHost"
previewHost.Size = UDim2.new(1, -6, 0, 286)
previewHost.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
previewHost.BorderColor3 = Color3.fromRGB(55, 57, 63)
previewHost.ZIndex = 4
previewHost.ClipsDescendants = true
previewHost.Parent = ESPPreviewTab.Container

local previewCanvas = Instance.new("Frame")
previewCanvas.Name = "PreviewCanvas"
previewCanvas.Size = UDim2.fromOffset(204, 230)
previewCanvas.Position = UDim2.new(0.5, 0, 0, 6)
previewCanvas.AnchorPoint = Vector2.new(0.5, 0)
previewCanvas.BackgroundTransparency = 1
previewCanvas.ZIndex = 5
previewCanvas.Parent = previewHost

local function previewFrame(parent, name, x, y, width, height, color, z)
    local part = Instance.new("Frame")
    part.Name = name
    part.BorderSizePixel = 0
    part.Position = UDim2.fromOffset(x, y)
    part.Size = UDim2.fromOffset(width, height)
    part.BackgroundColor3 = color
    part.ZIndex = z or 6
    part.Parent = parent
    return part
end

local function roundPreview(part, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = part
end

local function previewSegment(parent, name, x1, y1, x2, y2, width, color, z)
    -- Roblox rotates Frames around their CENTER. Center the segment exactly
    -- between both endpoints to prevent detached limbs and misplaced box corners.
    local dx, dy = x2 - x1, y2 - y1
    local midX, midY = (x1 + x2) / 2, (y1 + y2) / 2
    local line = previewFrame(parent, name, midX, midY,
        math.sqrt(dx * dx + dy * dy), width, color, z)
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.Rotation = math.deg(math.atan2(dy, dx))
    return line
end

-- Classic Roblox avatar from the user's transparent PNG, embedded as Base64.
-- No network request, separate image link or Roblox asset upload needed.
local previewAvatarPNG = [[
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
H10VygC3KAAAAABJRU5ErkJggg==
]]
local function decodeAvatarBase64(source)
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local lookup = {}
    for i = 1, #alphabet do lookup[alphabet:sub(i, i)] = i - 1 end
    local result, count, accumulator, bits = {}, 0, 0, 0
    for i = 1, #source do
        local ch = source:sub(i, i)
        if ch == "=" then break end
        local value = lookup[ch]
        if value then
            accumulator = accumulator * 64 + value
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                count = count + 1
                result[count] = string.char(math.floor(accumulator / (2 ^ bits)) % 256)
                accumulator = accumulator % (2 ^ bits)
            end
        end
    end
    return table.concat(result)
end

local avatarAsset = nil
local customAsset = type(getcustomasset) == "function" and getcustomasset
    or (type(getsynasset) == "function" and getsynasset)
if customAsset and type(writefile) == "function" then
    local ok, assetOrError = pcall(function()
        local path = "SpaceSolution_RobloxAvatar_Preview_v1.png"
        -- Always write the bundled PNG, so the script is fully self-contained.
        writefile(path, decodeAvatarBase64(previewAvatarPNG))
        return customAsset(path)
    end)
    if ok and type(assetOrError) == "string" then
        avatarAsset = assetOrError
    end
end
previewAvatarPNG = nil -- release embedded image string after setup

local previewAvatar = Instance.new("ImageLabel")
previewAvatar.Name = "ClassicRobloxAvatar"
previewAvatar.Position = UDim2.fromOffset(28, 23)
previewAvatar.Size = UDim2.fromOffset(148, 188)
previewAvatar.BackgroundTransparency = 1
previewAvatar.Image = avatarAsset or ""
previewAvatar.ScaleType = Enum.ScaleType.Fit
previewAvatar.Visible = avatarAsset ~= nil
previewAvatar.ZIndex = 6
previewAvatar.Parent = previewCanvas

local previewChamsTint = Instance.new("ImageLabel")
previewChamsTint.Name = "AvatarChamsTint"
previewChamsTint.Position = previewAvatar.Position
previewChamsTint.Size = previewAvatar.Size
previewChamsTint.BackgroundTransparency = 1
previewChamsTint.Image = avatarAsset or ""
previewChamsTint.ImageTransparency = 1
previewChamsTint.ScaleType = Enum.ScaleType.Fit
previewChamsTint.ZIndex = 7
previewChamsTint.Parent = previewCanvas

-- Fallback Roblox block avatar if the executor cannot load local PNG assets.
-- These Frames are hidden when the original PNG is successfully loaded.
local fallbackParts = {}
local function fallbackPart(name, x, y, w, h, color, radius)
    local part = previewFrame(previewCanvas, name, x, y, w, h, color, 6)
    part.Visible = avatarAsset == nil
    if radius and radius > 0 then roundPreview(part, radius) end
    local outline = Instance.new("UIStroke")
    outline.Name = "FallbackChamsStroke"
    outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    outline.Thickness = 1
    outline.Enabled = false
    outline.Parent = part
    fallbackParts[#fallbackParts + 1] = {frame = part, baseColor = color}
    return part
end
fallbackPart("Head", 83, 24, 38, 40, Color3.fromRGB(245, 211, 49), 10)
fallbackPart("LeftArm", 32, 68, 33, 71, Color3.fromRGB(216, 183, 46), 3)
fallbackPart("RightArm", 139, 68, 33, 71, Color3.fromRGB(216, 183, 46), 3)
fallbackPart("Torso", 66, 67, 72, 72, Color3.fromRGB(11, 72, 110), 2)
fallbackPart("LeftLeg", 72, 139, 29, 72, Color3.fromRGB(92, 112, 30), 2)
fallbackPart("RightLeg", 103, 139, 29, 72, Color3.fromRGB(92, 112, 30), 2)

local fallbackEyes = {}
for _, x in ipairs({95, 108}) do
    local eye = previewFrame(previewCanvas, "Eye", x, 37, 3, 6, Color3.new(0, 0, 0), 7)
    roundPreview(eye, 2)
    eye.Visible = avatarAsset == nil
    fallbackEyes[#fallbackEyes + 1] = eye
end

-- Anchor points follow the R6 block avatar proportions (no line on the head).
local previewBonePairs = {
    {102, 66, 102, 103}, {102, 103, 102, 138},
    {102, 76, 65, 76}, {65, 76, 48, 107}, {48, 107, 48, 137},
    {102, 76, 139, 76}, {139, 76, 156, 107}, {156, 107, 156, 137},
    {102, 138, 86, 140}, {86, 140, 86, 175}, {86, 175, 86, 207},
    {102, 138, 118, 140}, {118, 140, 118, 175}, {118, 175, 118, 207}
}
local previewBones = {}
for i, p in ipairs(previewBonePairs) do
    previewBones[i] = previewSegment(previewCanvas, "Bone" .. i,
        p[1], p[2], p[3], p[4], 1, Color3.new(1, 1, 1), 9)
end

local bx, by, bw, bh = 26, 20, 152, 194
local previewBox = previewFrame(previewCanvas, "FullBox", bx, by, bw, bh,
    Color3.fromRGB(0, 255, 180), 10)
previewBox.BackgroundTransparency = 1
local previewBoxStroke = Instance.new("UIStroke")
previewBoxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
previewBoxStroke.Thickness = 1
previewBoxStroke.Parent = previewBox

local cw, ch = 29, 36
local previewCornerPairs = {
    {bx, by, bx + cw, by}, {bx, by, bx, by + ch},
    {bx + bw, by, bx + bw - cw, by}, {bx + bw, by, bx + bw, by + ch},
    {bx, by + bh, bx + cw, by + bh}, {bx, by + bh, bx, by + bh - ch},
    {bx + bw, by + bh, bx + bw - cw, by + bh},
    {bx + bw, by + bh, bx + bw, by + bh - ch}
}
local previewCorners = {}
for i, p in ipairs(previewCornerPairs) do
    previewCorners[i] = previewSegment(previewCanvas, "Corner" .. i,
        p[1], p[2], p[3], p[4], 1, Color3.fromRGB(0, 255, 180), 10)
end

local previewTracer = previewSegment(previewCanvas, "Tracer", 10, 225, 102, 139,
    1, Color3.new(1, 1, 1), 8)

local previewHeadDotCenterX = 102
local previewHeadDotCenterY = 40
local previewHeadDot = previewFrame(previewCanvas, "HeadDot", previewHeadDotCenterX - 3, previewHeadDotCenterY - 3, 6, 6,
    Color3.new(1, 1, 1), 11)
previewHeadDot.BackgroundTransparency = 1
local previewDotCorner = Instance.new("UICorner")
previewDotCorner.CornerRadius = UDim.new(1, 0)
previewDotCorner.Parent = previewHeadDot
local previewDotStroke = Instance.new("UIStroke")
previewDotStroke.Thickness = 1
previewDotStroke.Parent = previewHeadDot

local previewName = Instance.new("TextLabel")
previewName.Name = "PreviewName"
previewName.Size = UDim2.fromOffset(190, 26)
previewName.Position = UDim2.fromOffset(7, 2)
previewName.BackgroundTransparency = 1
previewName.Text = "Player"
previewName.TextColor3 = Color3.new(1, 1, 1)
previewName.TextSize = 14
previewName.Font = Enum.Font.Arial
previewName.TextStrokeColor3 = Color3.new(0, 0, 0)
previewName.TextStrokeTransparency = 1
previewName.ZIndex = 12
previewName.Parent = previewCanvas

-- Preview for the independent Distance ESP toggle.
-- Scoped to avoid adding top-level locals (Luau 200-register limit).
do
    local distanceLabel = previewName:Clone()
    distanceLabel.Name = "PreviewDistance"
    distanceLabel.Text = "180.8m" -- default preview at 400 studs, with calibration
    distanceLabel.Size = UDim2.fromOffset(60, 26)
    distanceLabel.Position = UDim2.fromOffset(72, 18)
    distanceLabel.TextXAlignment = Enum.TextXAlignment.Center
    distanceLabel.Visible = false
    distanceLabel.Parent = previewCanvas
end

local previewCaption = Instance.new("TextLabel")
previewCaption.Name = "PreviewCaption"
previewCaption.Position = UDim2.new(0, 6, 1, -41)
previewCaption.Size = UDim2.new(1, -12, 0, 34)
previewCaption.BackgroundTransparency = 1
previewCaption.Text = "ESP Preview - Live Settings"
previewCaption.TextColor3 = Color3.fromRGB(168, 172, 185)
previewCaption.Font = Enum.Font.GothamMedium
previewCaption.TextSize = 12
previewCaption.TextWrapped = true
previewCaption.ZIndex = 6
previewCaption.Parent = previewHost

ESPPreviewTab:Resize()

local function pToggle(key)
    return Toggles[key] and Toggles[key].Value == true
end
local function pOption(key, fallback)
    return Options[key] and Options[key].Value or fallback
end
local function refreshESPPreview()
    local skeletonVisible = pToggle("SkeletonEnabled")
    local skeletonColor = pOption("SkeletonColor", Color3.new(1, 1, 1))
    local skeletonThickness = pOption("SkeletonThickness", 2.5)
    for _, line in ipairs(previewBones) do
        line.Visible = skeletonVisible
        line.BackgroundColor3 = skeletonColor
        line.Size = UDim2.fromOffset(line.Size.X.Offset, skeletonThickness)
    end

    local boxEnabled = pToggle("BoxESPEnabled")
    local cornered = pToggle("BoxCornered")
    local boxColor = pOption("BoxESPColor", Color3.fromRGB(0, 255, 180))
    local thickness = pOption("BoxThickness", 1)
    previewBox.Visible = boxEnabled and not cornered
    previewBoxStroke.Color = boxColor
    previewBoxStroke.Thickness = thickness
    for _, line in ipairs(previewCorners) do
        line.Visible = boxEnabled and cornered
        line.BackgroundColor3 = boxColor
        line.Size = UDim2.fromOffset(line.Size.X.Offset, thickness)
    end

    previewHeadDot.Visible = pToggle("HeadDotEnabled")
    local dotRadius = getHeadDotRadiusPixels()
    previewHeadDot.Size = UDim2.fromOffset(dotRadius * 2, dotRadius * 2)
    previewHeadDot.Position = UDim2.fromOffset(previewHeadDotCenterX - dotRadius, previewHeadDotCenterY - dotRadius)
    previewDotStroke.Color = pOption("HeadDotColor", Color3.new(1, 1, 1))

    previewTracer.Visible = pToggle("TracerESPEnabled")
    previewTracer.BackgroundColor3 = pOption("TracerESPColor", Color3.new(1, 1, 1))
    previewTracer.Size = UDim2.fromOffset(previewTracer.Size.X.Offset, pOption("TracerThickness", 1))

    previewName.Visible = pToggle("NameESPEnabled")
    previewName.Text = pOption("ESPNameType", "Display Name") == "Username" and "Player_123" or "DisplayName"
    previewName.TextColor3 = pOption("NameESPColor", Color3.new(1, 1, 1))
    previewName.TextSize = pOption("NameESPTextSize", 15)

    local previewDistance = previewCanvas:FindFirstChild("PreviewDistance")
    if previewDistance then
        previewDistance.Visible = pToggle("DistanceESPEnabled")
        -- Same distance multiplier as the in-game ESP; dummy is 400 studs away.
        previewDistance.Text = string.format("%.1fm",
            400 * 0.28 * 1.614)
        previewDistance.TextColor3 = pOption("DistanceESPColor", Color3.new(1, 1, 1))
        previewDistance.TextSize = pOption("DistanceESPTextSize", 15)
        local distancePosition = pOption("ESPDistancePosition", "Top")
        if distancePosition == "Bottom" then
            previewDistance.Position = UDim2.fromOffset(72, 218)
        elseif distancePosition == "Left" then
            previewDistance.Position = UDim2.fromOffset(-40, 109)
        elseif distancePosition == "Right" then
            previewDistance.Position = UDim2.fromOffset(186, 109)
        else
            previewDistance.Position = UDim2.fromOffset(
                72, previewName.Visible and (2 + previewName.TextSize + 4) or 2
            )
        end
    end

    local chams = pToggle("ChamsESPEnabled")
    local state = pOption("ESPPreviewChamsState", "Visible")
    local chamsColor = state == "Invisible"
        and pOption("ChamsInvisibleColor", Color3.fromRGB(255, 80, 80))
        or pOption("ChamsVisibleColor", Color3.fromRGB(0, 255, 100))
    -- Overlay the original avatar silhouette with translucent chams color.
    previewChamsTint.Visible = avatarAsset ~= nil and chams
    previewChamsTint.ImageColor3 = chamsColor
    previewChamsTint.ImageTransparency = 0.45
    for _, entry in ipairs(fallbackParts) do
        local part = entry.frame
        part.BackgroundColor3 = chams and entry.baseColor:Lerp(chamsColor, 0.40) or entry.baseColor
        local outline = part:FindFirstChild("FallbackChamsStroke")
        if outline then
            outline.Enabled = chams
            outline.Color = chamsColor
        end
    end
    previewCaption.Text = chams
        and ("Chams: " .. state .. " | ESP Preview")
        or "ESP Preview - Live Settings"
end

refreshESPPreview()
local previewUpdateTime = 0
SpaceRuntime:Connect(RunService.Heartbeat, function(dt)
    previewUpdateTime = previewUpdateTime + dt
    if previewUpdateTime < 0.1 then return end
    previewUpdateTime = 0
    if not previewHost.Parent or selectedPage ~= "Visuals" then return end
    refreshESPPreview()
end)

-- Theme animation is throttled to 20 Hz and does not change ESP update rates.
do
    local themeElapsed = 0
    local themeLastColor = nil
    local accentStrokes, scrollFrames = {}, {}
    for _, item in ipairs(ui:GetDescendants()) do
        if item:IsA("UIStroke") and item:GetAttribute("SpaceAccent") then
            accentStrokes[#accentStrokes + 1] = item
        elseif item:IsA("ScrollingFrame") then
            scrollFrames[#scrollFrames + 1] = item
        end
    end
    SpaceRuntime:Connect(RunService.Heartbeat, function(dt)
        if not SpaceRuntime.Active then return end
        themeElapsed = themeElapsed + dt
        if themeElapsed < 0.05 then return end
        themeElapsed = 0
        ThemeState.RainbowSpeed = math.clamp(tonumber(Options.GejModeRainbowSpeed and Options.GejModeRainbowSpeed.Value) or 0.12, 0.02, 1.0)
        ThemeState.ESPRainbow = Toggles.ESPRainbow.Value
        local gejMode = Toggles.GejMode.Value == true
        ThemeState.GUIRainbow = gejMode
        ThemeState.WatermarkRainbow = false
        local sharedColor = gejMode and rainbowColor(os.clock()) or ACCENT
        local guiColor = sharedColor
        local markColor = Color3.fromRGB(255, 255, 255)
        if watermarkLine.BackgroundColor3 ~= markColor then watermarkLine.BackgroundColor3 = markColor end
        if watermark.TextColor3 ~= markColor then watermark.TextColor3 = markColor end
        if guiColor ~= themeLastColor then
            themeLastColor = guiColor
            -- Accent strokes and scroll bars, including controls added later.
            for _, item in ipairs(accentStrokes) do
                if item.Parent then item.Color = guiColor end
            end
            for _, item in ipairs(scrollFrames) do
                if item.Parent then item.ScrollBarImageColor3 = guiColor end
            end
        end
    end)
end

-- Skeleton ESP based on the supplied source: cached BasePart-to-BasePart connections.
-- R6 and R15 parts are resolved once per character, not searched every frame.
local function buildSkeletonConnections(character)
    local head = character:FindFirstChild("Head")
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    local lowerTorso = character:FindFirstChild("LowerTorso")
    local leftArm = character:FindFirstChild("Left Arm") or character:FindFirstChild("LeftUpperArm")
    local rightArm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightUpperArm")
    local leftLeg = character:FindFirstChild("Left Leg") or character:FindFirstChild("LeftUpperLeg")
    local rightLeg = character:FindFirstChild("Right Leg") or character:FindFirstChild("RightUpperLeg")
    local leftHand = character:FindFirstChild("LeftHand") or character:FindFirstChild("LeftLowerArm")
    local rightHand = character:FindFirstChild("RightHand") or character:FindFirstChild("RightLowerArm")
    local leftFoot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("LeftLowerLeg")
    local rightFoot = character:FindFirstChild("RightFoot") or character:FindFirstChild("RightLowerLeg")

    local connections = {}
    local function connect(part1, part2)
        if part1 and part2 then
            connections[#connections + 1] = {part1, part2}
        end
    end

    connect(head, torso)
    connect(torso, lowerTorso)
    connect(torso, leftArm)
    connect(torso, rightArm)
    connect(leftArm, leftHand)
    connect(rightArm, rightHand)
    connect(lowerTorso or torso, leftLeg)
    connect(lowerTorso or torso, rightLeg)
    connect(leftLeg, leftFoot)
    connect(rightLeg, rightFoot)
    return connections
end

local ESPObjects = {}

local function newLine()

    local obj = Drawing.new("Line")

    obj.Visible = false

    obj.Thickness = 1

    obj.Transparency = 1

    return obj

end

local function createESP(player)

    if player == LocalPlayer or ESPObjects[player] then return end

    local obj = {
        Bones = {},
        SkeletonConnections = {},
        SkeletonCharacter = nil,
        SkeletonRefreshAt = 0,
    }

    for i = 1, 10 do obj.Bones[i] = newLine() end

    obj.Box = Drawing.new("Square")

    obj.Box.Visible = false

    obj.Box.Filled = false

    obj.Box.Thickness = 1

    obj.Box.Transparency = 1

    obj.Corners = {}

    for i = 1, 8 do obj.Corners[i] = newLine() end

    obj.HeadDot = Drawing.new("Circle")

    obj.HeadDot.Visible = false

    obj.HeadDot.Filled = false

    obj.HeadDot.Thickness = 1

    obj.HeadDot.NumSides = 64

    obj.HeadDot.Transparency = 1

    obj.HeadDot.Radius = 3

    obj.Tracer = newLine()

    -- Background drawing objects retained for compatibility, but disabled
    -- to keep the in-game Arial ESP labels clean and borderless.
    obj.NameBG = Drawing.new("Square")
    obj.NameBG.Visible = false
    obj.NameBG.Filled = true
    obj.NameBG.Color = Color3.fromRGB(9, 11, 16)
    obj.NameBG.Transparency = 0.58
    obj.NameBG.Thickness = 0

    obj.DistanceBG = Drawing.new("Square")
    obj.DistanceBG.Visible = false
    obj.DistanceBG.Filled = true
    obj.DistanceBG.Color = Color3.fromRGB(9, 11, 16)
    obj.DistanceBG.Transparency = 0.58
    obj.DistanceBG.Thickness = 0

    obj.Name = Drawing.new("Text")

    obj.Name.Visible = false

    obj.Name.Center = true

    obj.Name.Outline = false

    obj.Name.Size = 15
    obj.Name.Font = 0 -- Drawing UI font: Arial-style text in the actual game ESP.

    obj.Name.Transparency = 1

    obj.Distance = Drawing.new("Text")
    obj.Distance.Visible = false
    obj.Distance.Center = true
    obj.Distance.Outline = false
    obj.Distance.Size = 15
    obj.Distance.Font = 0 -- Drawing UI font: Arial-style text in the actual game ESP.
    obj.Distance.Transparency = 1

    ESPObjects[player] = obj

end

local function hideESP(obj)

    for _, line in ipairs(obj.Bones) do line.Visible = false end

    obj.Box.Visible = false

    for _, line in ipairs(obj.Corners) do line.Visible = false end

    obj.Tracer.Visible = false

    obj.HeadDot.Visible = false

    obj.Name.Visible = false
    obj.NameBG.Visible = false

    obj.Distance.Visible = false
    obj.DistanceBG.Visible = false

    if obj.Highlight then obj.Highlight.Enabled = false end

end

local function removeESP(player)

    local obj = ESPObjects[player]

    if not obj then return end

    for _, line in ipairs(obj.Bones) do line:Remove() end

    obj.Box:Remove()

    for _, line in ipairs(obj.Corners) do line:Remove() end

    obj.Tracer:Remove()

    obj.HeadDot:Remove()

    obj.Name:Remove()
    obj.NameBG:Remove()

    obj.Distance:Remove()
    obj.DistanceBG:Remove()

    if obj.Highlight then obj.Highlight:Destroy() end

    ESPObjects[player] = nil

end

SpaceRuntime:AddCleanup(function()
    for player in pairs(ESPObjects) do
        pcall(removeESP, player)
    end
end)

local function updateESP(player, obj)
    if isSpaceFriend(player) then
        hideESP(obj)
        return
    end

    local character = player.Character

    local humanoid = character and character:FindFirstChildOfClass("Humanoid")

    local root = character and character:FindFirstChild("HumanoidRootPart")

    local camera = workspace.CurrentCamera

    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

    if not camera or not humanoid or humanoid.Health <= 0 or not root or not myRoot

        or (Toggles.ESPTeamCheck.Value and player.Team ~= nil and player.Team == LocalPlayer.Team)

        or (root.Position - myRoot.Position).Magnitude > Options.ESPMaxDistance.Value then

        hideESP(obj)

        return

    end

    -- Fast off-screen rejection before 3D bounding boxes and bone projection.
    local rootScreen, rootOnScreen = camera:WorldToViewportPoint(root.Position)
    if rootScreen.Z <= 0 or not rootOnScreen then
        hideESP(obj)
        return
    end

    if Toggles.SkeletonEnabled.Value then
        -- Rebuild connections on respawn; retry briefly when streamed parts are missing.
        local now = os.clock()
        if obj.SkeletonCharacter ~= character or now >= obj.SkeletonRefreshAt then
            obj.SkeletonCharacter = character
            obj.SkeletonConnections = buildSkeletonConnections(character)
            local expectedCount = character:FindFirstChild("Torso") and 5 or 10
            obj.SkeletonRefreshAt = now + (#obj.SkeletonConnections < expectedCount and 1.5 or 10)
        end

        -- The supplied source fades skeleton lines with distance (500 studs).
        local distance = (root.Position - myRoot.Position).Magnitude
        local transparency = math.clamp(1 - distance / 500, 0.3, 1)
        local thickness = Options.SkeletonThickness.Value
        local color = espColor("SkeletonColor")

        for i, line in ipairs(obj.Bones) do
            local connection = obj.SkeletonConnections[i]
            line.Visible = false
            if connection then
                local part1, part2 = connection[1], connection[2]
                if part1.Parent == character and part2.Parent == character then
                    local pos1, onScreen1 = camera:WorldToViewportPoint(part1.Position)
                    local pos2, onScreen2 = camera:WorldToViewportPoint(part2.Position)
                    if onScreen1 and onScreen2 and pos1.Z > 0 and pos2.Z > 0 then
                        line.From = Vector2.new(pos1.X, pos1.Y)
                        line.To = Vector2.new(pos2.X, pos2.Y)
                        line.Color = color
                        line.Thickness = thickness
                        line.Transparency = transparency
                        line.Visible = true
                    end
                end
            end
        end
    else
        for _, line in ipairs(obj.Bones) do line.Visible = false end
    end

-- Head Dot uses identical pixel radius for all players, regardless of camera distance.

    obj.HeadDot.Visible = false

    if Toggles.HeadDotEnabled.Value then

        local head = character:FindFirstChild("Head")

        if head then

            local point, onScreen = camera:WorldToViewportPoint(head.Position)

            if onScreen and point.Z > 0 then

                obj.HeadDot.Position = Vector2.new(point.X, point.Y)

                obj.HeadDot.Color = espColor("HeadDotColor")

                obj.HeadDot.Radius = getHeadDotRadiusPixels()

                obj.HeadDot.Thickness = 1

                obj.HeadDot.Filled = false

                obj.HeadDot.Visible = true

            end

        end

    end

    obj.Box.Visible = false

    for _, line in ipairs(obj.Corners) do line.Visible = false end

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local count = 0

    if Toggles.BoxESPEnabled.Value or Toggles.DistanceESPEnabled.Value
        or Toggles.NameESPEnabled.Value then

-- Bounding box from the character's actual 3D extents.

        local cf, size = character:GetBoundingBox()

        for x = -1, 1, 2 do

            for y = -1, 1, 2 do

                for z = -1, 1, 2 do

                    local point = cf:PointToWorldSpace(Vector3.new(x * size.X/2, y * size.Y/2, z * size.Z/2))

                    local projected = camera:WorldToViewportPoint(point)

                    if projected.Z > 0 then

                        minX = math.min(minX, projected.X)

                        minY = math.min(minY, projected.Y)

                        maxX = math.max(maxX, projected.X)

                        maxY = math.max(maxY, projected.Y)

                        count = count + 1

                    end

                end

            end

        end

        if count == 8 and Toggles.BoxESPEnabled.Value then

            local width, height = maxX - minX, maxY - minY

            local color = espColor("BoxESPColor")

            local thickness = Options.BoxThickness.Value

            if Toggles.BoxCornered.Value then

                local cornerW = width * 0.25

                local cornerH = height * 0.25

                local segments = {

                    {minX, minY, minX + cornerW, minY},

                    {minX, minY, minX, minY + cornerH},

                    {maxX, minY, maxX - cornerW, minY},

                    {maxX, minY, maxX, minY + cornerH},

                    {minX, maxY, minX + cornerW, maxY},

                    {minX, maxY, minX, maxY - cornerH},

                    {maxX, maxY, maxX - cornerW, maxY},

                    {maxX, maxY, maxX, maxY - cornerH}

                }

                for i, segment in ipairs(segments) do

                    local line = obj.Corners[i]

                    line.From = Vector2.new(segment[1], segment[2])

                    line.To = Vector2.new(segment[3], segment[4])

                    line.Color = color

                    line.Thickness = thickness

                    line.Visible = true

                end

            else

                obj.Box.Position = Vector2.new(minX, minY)

                obj.Box.Size = Vector2.new(width, height)

                obj.Box.Color = color

                obj.Box.Thickness = thickness

                obj.Box.Visible = true

            end

        end

    end

    local pos, onScreen = camera:WorldToViewportPoint(root.Position)

    obj.Tracer.Visible = Toggles.TracerESPEnabled.Value and onScreen

    if obj.Tracer.Visible then

        obj.Tracer.From = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)

        obj.Tracer.To = Vector2.new(pos.X, pos.Y)

        obj.Tracer.Color = espColor("TracerESPColor")

        obj.Tracer.Thickness = Options.TracerThickness.Value

    end

    -- In-game ESP text: position using projected character bounds (not the
    -- dummy preview), and keep the name and distance on separate lines.
    obj.Name.Visible = false
    obj.Distance.Visible = false
    obj.NameBG.Visible = false
    obj.DistanceBG.Visible = false
    obj._espDistance = (root.Position - myRoot.Position).Magnitude

    local nameLabelSize = Options.NameESPTextSize and Options.NameESPTextSize.Value or 15
    local distanceLabelSize = Options.DistanceESPTextSize and Options.DistanceESPTextSize.Value or 15
    obj.Name.Size = nameLabelSize
    obj.Distance.Size = distanceLabelSize

    local centreX, centreY
    if count == 8 and onScreen and pos.Z > 0 then
        centreX = (minX + maxX) * 0.5
        centreY = (minY + maxY) * 0.5
    elseif onScreen and pos.Z > 0 then
        centreX, centreY = pos.X, pos.Y
        minX, maxX = pos.X - 22, pos.X + 22
        minY, maxY = pos.Y - 48, pos.Y + 48
    end

    local placement = Options.ESPDistancePosition
        and Options.ESPDistancePosition.Value or "Top"
    local distanceOnTop = Toggles.DistanceESPEnabled.Value and placement == "Top"

    if centreX then
        if Toggles.NameESPEnabled.Value then
            local displayName = Options.ESPNameType.Value == "Username"
                and player.Name or player.DisplayName
            -- Extremely long usernames obscure nearby players. Keep the full
            -- value in the game; shorten only the rendered label.
            if #displayName > 24 then
                displayName = string.sub(displayName, 1, 21) .. "..."
            end
            obj.Name.Text = displayName
            obj.Name.Position = Vector2.new(
                centreX, minY - (distanceOnTop
                    and (nameLabelSize + distanceLabelSize + 12)
                    or (nameLabelSize + 8))
            )
            obj.Name.Color = espColor("NameESPColor")
            obj.Name.Visible = true
        end

        if Toggles.DistanceESPEnabled.Value then
            -- Shared calibrated scale with ESP Preview (one decimal like kill feed).
            obj.Distance.Text = string.format("%.1fm",
                obj._espDistance * 0.28 * 1.614)
            obj.Distance.Color = espColor("DistanceESPColor")
            if placement == "Bottom" then
                obj.Distance.Position = Vector2.new(centreX, maxY + 7)
            elseif placement == "Left" then
                -- Exact text width is applied later by the screen-space layout.
                obj.Distance.Position = Vector2.new(minX - 14, centreY - distanceLabelSize * 0.5)
            elseif placement == "Right" then
                obj.Distance.Position = Vector2.new(maxX + 14, centreY - distanceLabelSize * 0.5)
            else
                obj.Distance.Position = Vector2.new(centreX, minY - distanceLabelSize - 5)
            end
            obj.Distance.Visible = true
        end
    end

-- A camera-to-target ray determines whether geometry blocks the character.-- Ignore the local character and the target itself.

    local function isCharacterVisible()
        local now = os.clock()
        if obj.VisibilityCharacter == character and obj.VisibilityUntil
            and now < obj.VisibilityUntil then
            return obj.CachedVisible
        end
        local origin = camera.CFrame.Position

        local direction = root.Position - origin

        if direction.Magnitude < 0.001 then return true end

        local params = RaycastParams.new()

        params.FilterType = Enum.RaycastFilterType.Exclude

        local ignored = {character}

        if LocalPlayer.Character then

            table.insert(ignored, LocalPlayer.Character)

        end

        params.FilterDescendantsInstances = ignored

        params.IgnoreWater = true

        local hit = workspace:Raycast(origin, direction, params)

        obj.VisibilityCharacter = character
        obj.VisibilityUntil = now + 0.10
        obj.CachedVisible = hit == nil
        return obj.CachedVisible

    end

    if Toggles.ChamsESPEnabled.Value then

        if not obj.Highlight then

            obj.Highlight = Instance.new("Highlight")

            obj.Highlight.Name = "SpaceSolutionESPHighlight"

            obj.Highlight.FillTransparency = 0.55

            obj.Highlight.OutlineTransparency = 0

            obj.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop

        end

        obj.Highlight.Adornee = character

        obj.Highlight.Parent = character

        local chamsColor = isCharacterVisible()

            and espColor("ChamsVisibleColor")

            or espColor("ChamsInvisibleColor")

        obj.Highlight.FillColor = chamsColor

        obj.Highlight.OutlineColor = chamsColor

        obj.Highlight.Enabled = true

    elseif obj.Highlight then

        obj.Highlight.Enabled = false

    end

end

-- Self ESP uses a single Highlight and follows respawns.
do
    local selfHighlight
    local function updateSelfESP()
        local character = LocalPlayer.Character
        local enabled = Toggles.SelfESPEnabled and Toggles.SelfESPEnabled.Value
        if not enabled or not character then
            if selfHighlight then
                selfHighlight:Destroy()
                selfHighlight = nil
            end
            return
        end
        if not selfHighlight or selfHighlight.Parent ~= character then
            if selfHighlight then selfHighlight:Destroy() end
            selfHighlight = Instance.new("Highlight")
            selfHighlight.Name = "SpaceSolutionSelfESP"
            selfHighlight.Adornee = character
            selfHighlight.Parent = character
            selfHighlight.FillTransparency = 0.75
            selfHighlight.OutlineTransparency = 0
        end
        local color = (ThemeState.ESPRainbow and rainbowColor(os.clock()))
            or (Options.SelfESPColor and Options.SelfESPColor.Value)
            or Color3.new(1, 1, 1)
        if selfHighlight.FillColor ~= color then selfHighlight.FillColor = color end
        if selfHighlight.OutlineColor ~= color then selfHighlight.OutlineColor = color end
        local mode = Toggles.SelfESPThroughWalls and Toggles.SelfESPThroughWalls.Value
            and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
        if selfHighlight.DepthMode ~= mode then selfHighlight.DepthMode = mode end
    end
    SpaceRuntime:Connect(LocalPlayer.CharacterAdded, function()
        if selfHighlight then selfHighlight:Destroy(); selfHighlight = nil end
        task.defer(updateSelfESP)
    end)
    local elapsed = 0
    SpaceRuntime:Connect(RunService.Heartbeat, function(dt)
        elapsed = elapsed + dt
        if elapsed < 0.05 then return end
        elapsed = 0
        updateSelfESP()
    end)
    SpaceRuntime:AddCleanup(function()
        if selfHighlight then selfHighlight:Destroy(); selfHighlight = nil end
    end)
    updateSelfESP()
end

-- China Hat is a cosmetic cone above your own head. No teleport or gameplay changes.
do
    local segments = 24
    local brimLines, tipLines = {}, {}
    for i = 1, segments do
        local brim = Drawing.new("Line")
        brim.Thickness = 1.5
        brim.Visible = false
        local side = Drawing.new("Line")
        side.Thickness = 1.5
        side.Visible = false
        brimLines[i], tipLines[i] = brim, side
    end
    local function hideHat()
        for i = 1, segments do
            brimLines[i].Visible = false
            tipLines[i].Visible = false
        end
    end
    SpaceRuntime:AddCleanup(function()
        for i = 1, segments do
            pcall(function() brimLines[i]:Remove() end)
            pcall(function() tipLines[i]:Remove() end)
        end
    end)
    SpaceRuntime:Connect(RunService.RenderStepped, function()
        if not (Toggles.ChinaHatEnabled and Toggles.ChinaHatEnabled.Value) then
            hideHat()
            return
        end
        local character = LocalPlayer.Character
        local head = character and character:FindFirstChild("Head")
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local camera = workspace.CurrentCamera
        if not head or not camera or not humanoid or humanoid.Health <= 0 then
            hideHat()
            return
        end
        local scale = (Options.ChinaHatSize and Options.ChinaHatSize.Value) or 1
        local base = head.Position + Vector3.new(0, head.Size.Y * 0.55 + 0.2 * scale, 0)
        local apex = base + Vector3.new(0, 0.85 * scale, 0)
        local radius = 1.15 * scale
        local color = (Toggles.ChinaHatRainbow and Toggles.ChinaHatRainbow.Value)
            and Color3.fromHSV((os.clock() * 0.15) % 1, 1, 1)
            or ((Options.ChinaHatColor and Options.ChinaHatColor.Value) or Color3.new(1, 1, 1))
        local tip, tipVisible = camera:WorldToViewportPoint(apex)
        for i = 1, segments do
            local a = (i - 1) * math.pi * 2 / segments
            local b = i * math.pi * 2 / segments
            local p1, v1 = camera:WorldToViewportPoint(base + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius))
            local p2, v2 = camera:WorldToViewportPoint(base + Vector3.new(math.cos(b) * radius, 0, math.sin(b) * radius))
            local visible = v1 and v2 and tipVisible and p1.Z > 0 and p2.Z > 0 and tip.Z > 0
            local brim, side = brimLines[i], tipLines[i]
            brim.Visible = visible
            side.Visible = visible
            if visible then
                brim.From, brim.To = Vector2.new(p1.X, p1.Y), Vector2.new(p2.X, p2.Y)
                side.From, side.To = Vector2.new(p1.X, p1.Y), Vector2.new(tip.X, tip.Y)
                brim.Color, side.Color = color, color
            end
        end
    end)
end

for _, player in ipairs(Players:GetPlayers()) do createESP(player) end

SpaceRuntime:Connect(Players.PlayerAdded, createESP)

SpaceRuntime:Connect(Players.PlayerRemoving, removeESP)

-- Resolve on-screen collisions between the REAL Drawing labels every frame.
-- Scoped to avoid adding to the main chunk's 200-local-register limit.
do
    local function getLabelSize(label)
        local ok, bounds = pcall(function() return label.TextBounds end)
        if ok and bounds and bounds.X and bounds.X > 0 then
            return bounds.X, math.max(label.Size + 3, bounds.Y)
        end
        return math.max(24, #tostring(label.Text) * label.Size * 0.55), label.Size + 3
    end

    local function overlaps(a, b)
        return a.x < b.x + b.w + 4 and a.x + a.w + 4 > b.x
            and a.y < b.y + b.h + 4 and a.y + a.h + 4 > b.y
    end

    -- Adjustable ESP budget (15–180 Hz); at low FPS naturally updates per frame.
    -- Allows the user to trade render smoothness for CPU/GPU load.
    local espElapsed = 0
    local espHidden = false
    SpaceRuntime:Connect(RunService.RenderStepped, function(dt)
        local enabled = Toggles.SkeletonEnabled.Value or Toggles.HeadDotEnabled.Value
            or Toggles.BoxESPEnabled.Value or Toggles.TracerESPEnabled.Value
            or Toggles.NameESPEnabled.Value or Toggles.DistanceESPEnabled.Value
            or Toggles.ChamsESPEnabled.Value
        if not enabled then
            if not espHidden then
                for _, obj in pairs(ESPObjects) do hideESP(obj) end
                espHidden = true
            end
            return
        end
        espHidden = false
        espElapsed = espElapsed + dt
        local rate = math.clamp(tonumber(Options.ESPUpdateRate.Value) or 60, 15, 180)
        if espElapsed < 1 / rate then return end
        espElapsed = 0
        for player, obj in pairs(ESPObjects) do
            updateESP(player, obj)
        end

        -- Skip label sorting and overlap checks if both text ESPs are off.
        if not Toggles.NameESPEnabled.Value and not Toggles.DistanceESPEnabled.Value then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local viewport = camera.ViewportSize
        local labels = {}

        for player, obj in pairs(ESPObjects) do
            if obj.Name.Visible then
                labels[#labels + 1] = {
                    label = obj.Name, bg = obj.NameBG,
                    depth = obj._espDistance or math.huge,
                    id = player.UserId, order = 1
                }
            end
            if obj.Distance.Visible then
                labels[#labels + 1] = {
                    label = obj.Distance, bg = obj.DistanceBG,
                    depth = obj._espDistance or math.huge,
                    id = player.UserId, order = 2,
                    side = Options.ESPDistancePosition
                        and Options.ESPDistancePosition.Value or "Top",
                }
            end
        end

        -- Closest players get the clearest placement. Stable IDs prevent
        -- labels from randomly swapping order as pairs() iterates.
        table.sort(labels, function(a, b)
            if math.abs(a.depth - b.depth) > 0.1 then
                return a.depth < b.depth
            end
            if a.id ~= b.id then return a.id < b.id end
            return a.order < b.order
        end)

        local occupied = {}
        for _, entry in ipairs(labels) do
            local label = entry.label
            local width, height = getLabelSize(label)
            local desired = label.Position
            local x = desired.X
            local y = desired.Y
            if entry.side == "Left" then
                x = x - width * 0.5
            elseif entry.side == "Right" then
                x = x + width * 0.5
            end

            x = math.clamp(x, width * 0.5 + 6,
                math.max(width * 0.5 + 6, viewport.X - width * 0.5 - 6))
            y = math.clamp(y, 5, math.max(5, viewport.Y - height - 5))

            local chosen = nil
            -- Try the natural position, then nearby vertical lanes to keep
            -- overlapping usernames and distance labels readable.
            for attempt = 0, 14 do
                local shift = 0
                if attempt > 0 then
                    local lane = math.ceil(attempt / 2)
                    shift = (attempt % 2 == 1 and -1 or 1) * lane * (height + 6)
                end
                local candidateY = y + shift
                if candidateY >= 5 and candidateY + height < viewport.Y - 5 then
                    local rect = {x = x - width * 0.5, y = candidateY,
                        w = width, h = height}
                    local free = true
                    for _, other in ipairs(occupied) do
                        if overlaps(rect, other) then
                            free = false
                            break
                        end
                    end
                    if free then
                        chosen = rect
                        break
                    end
                end
            end

            if chosen then
                label.Position = Vector2.new(chosen.x + width * 0.5, chosen.y)
                entry.bg.Position = Vector2.new(chosen.x - 5, chosen.y - 2)
                entry.bg.Size = Vector2.new(width + 10, height + 4)
                entry.bg.Visible = false -- No dark background behind in-game ESP text.
                occupied[#occupied + 1] = chosen
            else
                -- When too many players are stacked together, hide the
                -- unplaceable label instead of drawing unreadable text piles.
                label.Visible = false
                entry.bg.Visible = false
            end
        end
    end)
end

-- Aim modes: the Enabled checkbox mirrors the real active state.

-- In Hold, it lights up on key down and turns off on key up.

local aimKeyHeld = false

local toggleAimEnabled = SilentAimSettings.Enabled == true

local syncingAimEnabled = false

local function getAimMode()

    return Options.AimMode and Options.AimMode.Value or "Toggle"

end

local function matchesAimKey(input)

    local picker = Options.AimKeyPicker

    local selected = picker and picker.Value or SilentAimSettings.ToggleKey

    if typeof(selected) == "EnumItem" then

        return input.KeyCode == selected or input.UserInputType == selected

    end

    selected = tostring(selected)

    if selected == "MB1" then

        return input.UserInputType == Enum.UserInputType.MouseButton1

    elseif selected == "MB2" then

        return input.UserInputType == Enum.UserInputType.MouseButton2

    end

    return input.KeyCode.Name == selected or input.UserInputType.Name == selected

end

local function isAimActive()
    if not SpaceRuntime.Active then return false end

    local mode = getAimMode()

    if mode == "Hold" then

        return aimKeyHeld

    elseif mode == "Always" then

        return true

    end

    return toggleAimEnabled

end

local function syncAimEnabled()

    local enabled = isAimActive()

    SilentAimSettings.Enabled = enabled

    if Toggles.aim_Enabled and Toggles.aim_Enabled.Value ~= enabled then

        syncingAimEnabled = true

        Toggles.aim_Enabled:SetValue(enabled)

        syncingAimEnabled = false

    end

end

SpaceRuntime:Connect(UserInputService.InputBegan, function(input, gameProcessed)

    if UserInputService:GetFocusedTextBox() then return end

    if not matchesAimKey(input) then return end

    local mode = getAimMode()

    if mode == "Hold" then

        -- GameProcessed can be true in some games: still allow Hold.

        aimKeyHeld = true

        syncAimEnabled()

    elseif mode == "Toggle" and not gameProcessed then

        toggleAimEnabled = not toggleAimEnabled

        syncAimEnabled()

    end

end)

SpaceRuntime:Connect(UserInputService.InputEnded, function(input)

    if not matchesAimKey(input) then return end

    aimKeyHeld = false

    if getAimMode() == "Hold" then

        syncAimEnabled()

    end

end)

;(function()
    local MainBOX = GeneralTab:AddLeftTabbox("Main") do

    local Main = MainBOX:AddTab("Main")

    -- Toggle: click Enabled or press Aim Key to switch.

    -- Hold: Enabled lights up only while Aim Key is pressed.

    -- Always: Enabled is always lit while this mode is selected.

    Main:AddToggle("aim_Enabled", {

        Text = "Enabled",

        Default = toggleAimEnabled

    }):OnChanged(function()

        if syncingAimEnabled then return end

        if getAimMode() == "Toggle" then

            toggleAimEnabled = Toggles.aim_Enabled.Value

        end

        syncAimEnabled()

    end)

    Main:AddDropdown("AimMode", {

        Text = "Aim Mode",

        Values = {"Toggle", "Hold", "Always"},

        Default = "Toggle",

        AllowNull = false

    }):OnChanged(function()

        aimKeyHeld = false

        syncAimEnabled()

    end)

    Main:AddKeyPicker("AimKeyPicker", {

        Default = SilentAimSettings.ToggleKey,

        Mode = "Toggle",

        Text = "Aim Key",

        NoUI = false,

        SyncToggleState = false

    })

    Options.AimKeyPicker:OnChanged(function()

        local selected = Options.AimKeyPicker.Value

        SilentAimSettings.ToggleKey = typeof(selected) == "EnumItem" and selected.Name or tostring(selected)

        aimKeyHeld = false

        syncAimEnabled()

    end)

    syncAimEnabled()

    Main:AddToggle("TeamCheck", {Text = "Team Check", Default = SilentAimSettings.TeamCheck}):OnChanged(function()

        SilentAimSettings.TeamCheck = Toggles.TeamCheck.Value

    end)

    Main:AddToggle("VisibleCheck", {Text = "Visible Check", Default = SilentAimSettings.VisibleCheck}):OnChanged(function()

        SilentAimSettings.VisibleCheck = Toggles.VisibleCheck.Value

    end)

    -- For client-side ray-based weapons, cast against the selected character
    -- instead of the map geometry. Server-validated weapons can still reject hits.
    Main:AddToggle("MagicBullet", {
        Text = "Magic Bullet", Default = SilentAimSettings.MagicBullet
    }):OnChanged(function()
        SilentAimSettings.MagicBullet = Toggles.MagicBullet.Value
    end)

    Main:AddDropdown("TargetPart", {AllowNull = true, Text = "Target Part", Default = SilentAimSettings.TargetPart, Values = {"Head", "HumanoidRootPart", "Random"}}):OnChanged(function()

        SilentAimSettings.TargetPart = Options.TargetPart.Value

    end)

    Main:AddDropdown("Method", {AllowNull = true, Text = "Silent Aim Method", Default = SilentAimSettings.SilentAimMethod, Values = {

        "Raycast","FindPartOnRay",

        "FindPartOnRayWithWhitelist",

        "FindPartOnRayWithIgnoreList",

        "Mouse.Hit/Target"

    }}):OnChanged(function()

        SilentAimSettings.SilentAimMethod = Options.Method.Value

    end)

    Main:AddSlider('HitChance', {

        Text = 'Hit chance',

        Default = 100,

        Min = 0,

        Max = 100,

        Rounding = 1,

        Compact = false,

    })

    Options.HitChance:OnChanged(function()

        SilentAimSettings.HitChance = Options.HitChance.Value

    end)

end

end)() -- Silent Aim controls in their own function scope

;(function()
-- Trigger Bot with independent keybind and Toggle / Hold / Always modes.
local TriggerBotSettings = {
    Enabled = false,
    TeamCheck = false,
    VisibleCheck = false,
    Delay = 0.12,
    ToggleKey = "T",
    TargetHead = false,
    TargetBody = false,
}
local triggerLastShot = 0
local triggerKeyHeld = false
local triggerToggled = false
local triggerSyncing = false

local function triggerMode()
    return Options.TriggerMode and Options.TriggerMode.Value or "Toggle"
end

local function matchesTriggerKey(input)
    local selected = Options.TriggerKeyPicker and Options.TriggerKeyPicker.Value or TriggerBotSettings.ToggleKey
    if typeof(selected) == "EnumItem" then
        return input.KeyCode == selected or input.UserInputType == selected
    end
    selected = tostring(selected)
    if selected == "MB1" then return input.UserInputType == Enum.UserInputType.MouseButton1 end
    if selected == "MB2" then return input.UserInputType == Enum.UserInputType.MouseButton2 end
    return input.KeyCode.Name == selected or input.UserInputType.Name == selected
end

local function syncTriggerEnabled()
    local mode = triggerMode()
    local enabled = (mode == "Always") or (mode == "Hold" and triggerKeyHeld)
        or (mode == "Toggle" and triggerToggled)
    TriggerBotSettings.Enabled = enabled
    if Toggles.TriggerEnabled and Toggles.TriggerEnabled.Value ~= enabled then
        triggerSyncing = true
        Toggles.TriggerEnabled:SetValue(enabled)
        triggerSyncing = false
    end
end

-- A filtered camera ray finds players under the crosshair even when a wall
-- is in front of them. Visible Check independently decides whether walls block.
local triggerTargetRayParams = RaycastParams.new()
triggerTargetRayParams.FilterType = Enum.RaycastFilterType.Include
triggerTargetRayParams.IgnoreWater = true

local triggerVisibilityRayParams = RaycastParams.new()
triggerVisibilityRayParams.FilterType = Enum.RaycastFilterType.Exclude
triggerVisibilityRayParams.IgnoreWater = true

local function triggerTargetValid()
    if not TriggerBotSettings.TargetHead and not TriggerBotSettings.TargetBody then
        return false
    end

    local currentCamera = workspace.CurrentCamera
    if not currentCamera then return false end

    local targetParts = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not isSpaceFriend(player)
            and (not TriggerBotSettings.TeamCheck or player.Team == nil
                or player.Team ~= LocalPlayer.Team) then
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                for _, part in ipairs(character:GetChildren()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        if (part.Name == "Head" and TriggerBotSettings.TargetHead)
                            or (part.Name ~= "Head" and TriggerBotSettings.TargetBody) then
                            table.insert(targetParts, part)
                        end
                    end
                end
            end
        end
    end

    if #targetParts == 0 then return false end

    -- ScreenPointToRay uses the same inset-adjusted mouse coordinates as Mouse.X/Y.
    local aimRay = currentCamera:ScreenPointToRay(Mouse.X, Mouse.Y)
    triggerTargetRayParams.FilterDescendantsInstances = targetParts
    local hit = workspace:Raycast(aimRay.Origin, aimRay.Direction * 10000, triggerTargetRayParams)
    if not hit then return false end

    if TriggerBotSettings.VisibleCheck then
        local targetCharacter = hit.Instance:FindFirstAncestorOfClass("Model")
        local ignored = {}
        if LocalPlayer.Character then
            table.insert(ignored, LocalPlayer.Character)
        end
        if targetCharacter then
            table.insert(ignored, targetCharacter)
        end
        triggerVisibilityRayParams.FilterDescendantsInstances = ignored
        -- Any object between the camera and target prevents the shot.
        local obstacle = workspace:Raycast(
            aimRay.Origin,
            hit.Position - aimRay.Origin,
            triggerVisibilityRayParams
        )
        if obstacle then return false end
    end

    return true
end

local TriggerBOX = GeneralTab:AddRightTabbox("Trigger Bot") do
    local Trigger = TriggerBOX:AddTab("Trigger Bot")
    Trigger:AddToggle("TriggerEnabled", {
        Text = "Trigger Bot Enabled", Default = false
    }):OnChanged(function()
        if triggerSyncing then return end
        local enabled = Toggles.TriggerEnabled.Value
        if triggerMode() == "Toggle" then
            triggerToggled = enabled
        elseif triggerMode() == "Hold" then
            triggerKeyHeld = enabled
        end
        syncTriggerEnabled()
    end)
    Trigger:AddDropdown("TriggerMode", {
        Text = "Trigger Mode", Values = {"Toggle", "Hold", "Always"},
        Default = "Toggle", AllowNull = false
    }):OnChanged(function()
        triggerKeyHeld = false
        syncTriggerEnabled()
    end)
    Trigger:AddKeyPicker("TriggerKeyPicker", {
        Text = "Trigger Key", Default = TriggerBotSettings.ToggleKey,
        Mode = "Toggle", NoUI = false, SyncToggleState = false
    }):OnChanged(function()
        local selected = Options.TriggerKeyPicker.Value
        TriggerBotSettings.ToggleKey = typeof(selected) == "EnumItem" and selected.Name or tostring(selected)
        triggerKeyHeld = false
        syncTriggerEnabled()
    end)
    Trigger:AddToggle("TriggerTeamCheck", {
        Text = "Trigger Team Check", Default = false
    }):OnChanged(function()
        TriggerBotSettings.TeamCheck = Toggles.TriggerTeamCheck.Value
    end)
    Trigger:AddToggle("TriggerVisibleCheck", {
        Text = "Visible Check", Default = false
    }):OnChanged(function()
        TriggerBotSettings.VisibleCheck = Toggles.TriggerVisibleCheck.Value
    end)
    Trigger:AddToggle("TriggerTargetHead", {
        Text = "Target Head", Default = false
    }):OnChanged(function()
        TriggerBotSettings.TargetHead = Toggles.TriggerTargetHead.Value
    end)
    Trigger:AddToggle("TriggerTargetBody", {
        Text = "Target Body", Default = false
    }):OnChanged(function()
        TriggerBotSettings.TargetBody = Toggles.TriggerTargetBody.Value
    end)
    Trigger:AddSlider("TriggerDelay", {
        Text = "Trigger Delay (seconds)", Min = 0.05, Max = 1,
        Default = 0.12, Rounding = 2
    }):OnChanged(function()
        TriggerBotSettings.Delay = Options.TriggerDelay.Value
    end)
    syncTriggerEnabled()
end

SpaceRuntime:Connect(UserInputService.InputBegan, function(input, processed)
    if processed or UserInputService:GetFocusedTextBox() then return end
    if not matchesTriggerKey(input) then return end
    if triggerMode() == "Toggle" then
        triggerToggled = not triggerToggled
    elseif triggerMode() == "Hold" then
        triggerKeyHeld = true
    end
    syncTriggerEnabled()
end)
SpaceRuntime:Connect(UserInputService.InputEnded, function(input)
    if triggerMode() == "Hold" and matchesTriggerKey(input) then
        triggerKeyHeld = false
        syncTriggerEnabled()
    end
end)

do
local lastTriggerCheck = 0
SpaceRuntime:Connect(RunService.RenderStepped, function()
    if not TriggerBotSettings.Enabled then return end
    local now = os.clock()
    if now - lastTriggerCheck < 1 / 30 then return end
    lastTriggerCheck = now
    if now - triggerLastShot < TriggerBotSettings.Delay then return end
    if not triggerTargetValid() then return end
    if type(mouse1click) == "function" then
        triggerLastShot = now
        if headerTop.SoundShot then headerTop.SoundShot() end
        mouse1click()
    elseif type(mouse1press) == "function" and type(mouse1release) == "function" then
        triggerLastShot = now
        if headerTop.SoundShot then headerTop.SoundShot() end
        mouse1press()
        task.defer(mouse1release)
    end
end)
end

end)() -- Trigger Bot isolated to keep main-chunk register usage low

-- SpaceSolution client-side Hit / Long Kill Sounds.
-- The game-specific weapon's server acknowledgement is unavailable in a universal script.
-- Attribute feedback to recent local shots and/or a Humanoid's "creator" tag.
;(function()
    local soundService = game:GetService("SoundService")
    local soundObjects = {}
    local watched = {}
    local playerConnections = {}
    local connections = {}
    local markedShots = {}
    local assetCache = {} -- Resolve custom audio files once, not on every hit.
    local shotWindow = 5.0 -- allow delayed long-range kills to be correlated
    local longKillThreshold = 110 -- meters as shown by calibrated Distance ESP
    local hitSoundMaxDistance = 99 -- Hit Sound only up to and including 99m
    local distanceScale = 0.28 * 1.614 -- must match Distance ESP / ESP Preview

    -- Store shot distance, rather than relying on the victim's position after death.
    local function displayedDistance(player)
        local localCharacter = LocalPlayer.Character
        local victimCharacter = player and player.Character
        local ownRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
        local victimRoot = victimCharacter and victimCharacter:FindFirstChild("HumanoidRootPart")
        if not (ownRoot and victimRoot) then return nil end
        return (ownRoot.Position - victimRoot.Position).Magnitude * distanceScale
    end

    -- Kill sound files belong in this folder in the executor's workspace.
    -- Creates the folder once; does not overwrite the user's audio files.
    local killSoundFolder = MainFileName .. "/KillSounds"
    local noKillFiles = "(No audio files found)"

    local function ensureKillSoundFolder()
        if type(makefolder) ~= "function" then return end
        if type(isfolder) == "function" then
            local ok, exists = pcall(isfolder, killSoundFolder)
            if ok and exists then return end
        end
        pcall(makefolder, killSoundFolder)
    end

    local function listKillSoundFiles()
        ensureKillSoundFolder()
        local choices = {}
        if type(listfiles) == "function" then
            local ok, paths = pcall(listfiles, killSoundFolder)
            if ok and type(paths) == "table" then
                for _, path in ipairs(paths) do
                    local filename = tostring(path):gsub("\\", "/"):match("([^/]+)$")
                    local lower = filename and filename:lower() or ""
                    if (lower:match("%.mp3$") or lower:match("%.wav$")
                        or lower:match("%.ogg$") or lower:match("%.vsnd_c$"))
                        and not table.find(choices, filename) then
                        table.insert(choices, filename)
                    end
                end
            end
        end
        table.sort(choices, function(a, b) return a:lower() < b:lower() end)
        if #choices == 0 then choices[1] = noKillFiles end
        return choices
    end

    ensureKillSoundFolder()

    -- Resolve audio with diagnostics rather than silently doing nothing.
    -- A valid Roblox asset ID needs permission to be played in the current game.
    local soundStatusLabel
    local soundStatusRevision = 0
    local function soundStatus(message, good)
        if not SpaceRuntime.Active then return end
        soundStatusRevision = soundStatusRevision + 1
        local revision = soundStatusRevision
        if soundStatusLabel and soundStatusLabel.Parent then
            soundStatusLabel.Text = tostring(message)
            soundStatusLabel.TextColor3 = good and Color3.fromRGB(130, 224, 161)
                or Color3.fromRGB(248, 134, 139)
            soundStatusLabel.Visible = true
            task.delay(8, function()
                if soundStatusLabel and soundStatusLabel.Parent
                    and revision == soundStatusRevision then
                    soundStatusLabel.Visible = false
                end
            end)
        end
        if not good then warn("SpaceSolution Sounds: " .. tostring(message)) end
    end

    local function fileExists(path)
        if type(isfile) ~= "function" then return false end
        local ok, yes = pcall(isfile, path)
        return ok and yes == true
    end

    local function actualFilePath(value)
        -- User can type just "sound.mp3" instead of the whole workspace path.
        local normalized = value:gsub("\\", "/"):gsub("^%s+", ""):gsub("%s+$", "")
        local candidates = {normalized}
        if not normalized:find("/", 1, true) then
            candidates[#candidates + 1] = killSoundFolder .. "/" .. normalized
        elseif normalized:sub(1, 11):lower() == "killsounds/" then
            candidates[#candidates + 1] = MainFileName .. "/" .. normalized
        end
        for _, candidate in ipairs(candidates) do
            if fileExists(candidate) then return candidate end
        end
        return candidates[#candidates]
    end

    local function soundId(kind)
        -- Hit and Long Kill sounds come exclusively from spacesolution/KillSounds/.
        local picker = Options[kind .. "SoundFile"]
        local filename = picker and picker.Value
        if type(filename) ~= "string" or filename == noKillFiles
            or filename:find("/", 1, true) or filename:find("\\", 1, true)
            or not (filename:lower():match("%.mp3$")
                or filename:lower():match("%.wav$")
                or filename:lower():match("%.ogg$")
                or filename:lower():match("%.vsnd_c$")) then
            return nil, "Brak pliku. Wrzuc audio do spacesolution/KillSounds i kliknij Rescan."
        end
        local value = killSoundFolder .. "/" .. filename

        -- Roblox Sound cannot directly decode the Source 2 VSND_C container.
        -- A converted .mp3/.ogg/.wav with the same stem is supported.
        local filePath = actualFilePath(value)
        local originalPath = filePath
        if value:lower():match("%.vsnd_c$") then
            local base = filePath:sub(1, -8)
            local exported
            for _, ext in ipairs({"mp3", "wav", "ogg"}) do
                local candidate = base .. "." .. ext
                if fileExists(candidate) then exported = candidate; break end
            end
            if exported then
                filePath = exported
            else
                -- Some VSND_C files contain a directly embedded OGG/MP3/WAV stream.
                -- Extraction is best-effort; other encodings need external export.
                if type(readfile) == "function" and type(writefile) == "function"
                    and fileExists(filePath) then
                    local ok, data = pcall(readfile, filePath)
                    if ok and type(data) == "string" and #data <= 16 * 1024 * 1024 then
                        local ogg = data:find("OggS", 17, true)
                        local mp3 = data:find("ID3", 17, true)
                        local wav = data:find("RIFF", 17, true)
                        if wav and data:sub(wav + 8, wav + 11) ~= "WAVE" then wav = nil end
                        local offset, ext
                        if ogg then offset, ext = ogg, "ogg"
                        elseif mp3 then offset, ext = mp3, "mp3"
                        elseif wav then offset, ext = wav, "wav" end
                        if offset then
                            local hash = 5381
                            for i = 1, #filePath do
                                hash = (hash * 33 + filePath:byte(i)) % 2147483647
                            end
                            local extracted = string.format("%s/vsndc_audio_%d.%s", MainFileName, hash, ext)
                            if pcall(writefile, extracted, data:sub(offset)) then
                                filePath = extracted
                            end
                        end
                    end
                end
                if filePath == originalPath then
                    return nil, "VSND_C nie jest odtwarzany bezposrednio. Wyeksportuj WAV/MP3/OGG."
                end
            end
        elseif not (value:lower():match("%.mp3$") or value:lower():match("%.ogg$")
            or value:lower():match("%.wav$")) then
            return nil, "Plik musi miec format MP3, WAV lub OGG."
        end

        -- Some executors can load a local asset but do not expose isfile().
        -- Only reject missing files when the check itself is available.
        if type(isfile) == "function" and not fileExists(filePath) then
            return nil, "Nie znaleziono pliku: " .. filePath
        end
        -- Failed paths are deliberately NOT cached: a newly added audio file can be
        -- tested immediately without restarting the script or clearing a negative cache.
        if assetCache[filePath] then return assetCache[filePath] end
        local assetFunction = type(getcustomasset) == "function" and getcustomasset
            or type(getsynasset) == "function" and getsynasset
        if type(assetFunction) ~= "function" then
            return nil, "Executor nie obsluguje getcustomasset/getsynasset dla lokalnych plikow."
        end
        local ok, asset = pcall(assetFunction, filePath)
        if ok and type(asset) == "string" and asset ~= "" then
            assetCache[filePath] = asset
            return asset
        end
        return nil, "Nie udalo sie zaladowac pliku: " .. filePath
    end

    local function play(kind, force)
        if not SpaceRuntime.Active then return false end
        local enabled = Toggles[kind .. "SoundsEnabled"]
        if not force and (not enabled or not enabled.Value) then return false end
        local id, err = soundId(kind)
        if not id then
            if force then soundStatus(err or "Nie mozna zaladowac dzwieku.", false) end
            return false
        end
        local sound = soundObjects[kind]
        if not sound then
            sound = Instance.new("Sound")
            sound.Name = "SpaceSolution" .. kind .. "Sound"
            sound.Parent = soundService
            soundObjects[kind] = sound
        end
        local success, playError = pcall(function()
            if sound.SoundId ~= id then sound.SoundId = id end
            sound.Volume = math.clamp(tonumber(Options[kind .. "SoundVolume"]
                and Options[kind .. "SoundVolume"].Value) or 0.8, 0, 2)
            sound.PlaybackSpeed = math.clamp(tonumber(Options[kind .. "SoundPitch"]
                and Options[kind .. "SoundPitch"].Value) or 1, 0.5, 2)
            sound:Stop()
            sound.TimePosition = 0
            sound:Play()
        end)
        if not success then
            if force then soundStatus("Blad odtwarzania: " .. tostring(playError), false) end
            return false
        end
        if force then
            soundStatus("Test " .. kind .. ": odtwarzanie wyslane do Roblox.", true)
            local requestedId = id
            task.delay(4, function()
                if not SpaceRuntime.Active or soundObjects[kind] ~= sound
                    or sound.SoundId ~= requestedId then return end
                if not sound.IsLoaded then
                    soundStatus("Roblox nie zaladowal pliku. Sprawdz format audio (MP3/WAV/OGG).", false)
                end
            end)
        end
        return true
    end

    -- Folder only: no Custom Sound IDs, presets or manual paths.
    -- One shared directory for Hit (<=99m) and Long Kill (>=110m).
    local feedback = buildControls(makePanel("Hit & Long Kill Sounds", pages.Misc.columns[2]))
    local initialFiles = listKillSoundFiles()
    local firstFile = initialFiles[1]

    feedback:AddToggle("HitSoundsEnabled", {Text = "Hit Sounds (do 99m)", Default = false})
    feedback:AddDropdown("HitSoundFile", {
        Text = "Hit Sound File", Values = initialFiles,
        Default = firstFile, AllowNull = false
    })
    feedback:AddSlider("HitSoundVolume", {
        Text = "Hit Volume", Min = 0, Max = 2, Default = 0.8, Rounding = 2
    })
    feedback:AddSlider("HitSoundPitch", {
        Text = "Hit Pitch", Min = 0.5, Max = 2, Default = 1, Rounding = 2
    })
    feedback:AddButton("Test Hit Sound", function() play("Hit", true) end)

    feedback:AddToggle("LongKillSoundsEnabled", {Text = "Long Kill Sounds (110m+)", Default = false})
    feedback:AddDropdown("LongKillSoundFile", {
        Text = "Long Kill Sound File", Values = initialFiles,
        Default = firstFile, AllowNull = false
    })
    feedback:AddSlider("LongKillSoundVolume", {
        Text = "Long Kill Volume", Min = 0, Max = 2, Default = 1, Rounding = 2
    })
    feedback:AddSlider("LongKillSoundPitch", {
        Text = "Long Kill Pitch", Min = 0.5, Max = 2, Default = 1, Rounding = 2
    })
    feedback:AddButton("Test Long Kill Sound", function() play("LongKill", true) end)

    -- Feedback appears only after using Test, never as permanent help text.
    soundStatusLabel = uiText(feedback.Container, "", 10, MUTED)
    soundStatusLabel.Name = "SoundTestStatus"
    soundStatusLabel.TextWrapped = true
    soundStatusLabel.Size = UDim2.new(1, -4, 0, 37)
    soundStatusLabel.Visible = false

    feedback:AddButton("Rescan Sound Files", function()
        table.clear(assetCache)
        local files = listKillSoundFiles()
        for _, kind in ipairs({"Hit", "LongKill"}) do
            local picker = Options[kind .. "SoundFile"]
            if picker then
                local previous = picker.Value
                picker:SetValues(files)
                if not previous or not table.find(files, previous) then
                    picker:SetValue(files[1])
                end
            end
        end
    end)

    local function getTargetPlayer(part)
        if not part then return nil end
        local character = part:FindFirstAncestorOfClass("Model")
        local player = character and Players:GetPlayerFromCharacter(character)
        if player and player ~= LocalPlayer then return player end
        return nil
    end

    local function markShot()
        if not SpaceRuntime.Active then return end
        if not ((Toggles.HitSoundsEnabled and Toggles.HitSoundsEnabled.Value)
            or (Toggles.LongKillSoundsEnabled and Toggles.LongKillSoundsEnabled.Value)) then return end
        local selected = nil
        -- If Silent Aim is active, the intended target may be different from Mouse.Target.
        if isAimActive() then
            local ok, target = pcall(getClosestPlayer)
            if ok then selected = getTargetPlayer(target) end
        end
        if not selected then
            local ok, target = pcall(function() return Mouse.Target end)
            if ok then selected = getTargetPlayer(target) end
        end
        -- Long-range shots often have no Mouse.Target (the ray hits terrain or
        -- misses the tiny character). Use a small crosshair cone as a fallback.
        if not selected then
            local camera = workspace.CurrentCamera
            if camera then
                local cursor = UserInputService:GetMouseLocation()
                local bestPixels = 75
                for _, candidate in ipairs(Players:GetPlayers()) do
                    if candidate ~= LocalPlayer then
                        local character = candidate.Character
                        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                        local root = character and character:FindFirstChild("HumanoidRootPart")
                        if humanoid and humanoid.Health > 0 and root then
                            local point, onScreen = camera:WorldToViewportPoint(root.Position)
                            if onScreen then
                                local pixels = (Vector2.new(point.X, point.Y) - cursor).Magnitude
                                if pixels < bestPixels then
                                    bestPixels = pixels
                                    selected = candidate
                                end
                            end
                        end
                    end
                end
            end
        end
        if selected then
            markedShots[selected] = {at = os.clock(), distance = displayedDistance(selected)}
        end
    end
    headerTop.SoundShot = markShot

    table.insert(connections, SpaceRuntime:Connect(UserInputService.InputBegan, function(input, processed)
        if processed or UserInputService:GetFocusedTextBox() then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then markShot() end
    end))

    local function unbind(player)
        local rec = watched[player]
        if rec then
            for _, connection in ipairs(rec.connections) do connection:Disconnect() end
            watched[player] = nil
        end
        markedShots[player] = nil
    end

    local function creatorMatches(humanoid)
        local tag = humanoid:FindFirstChild("creator") or humanoid:FindFirstChild("Creator")
        return tag and tag:IsA("ObjectValue") and tag.Value == LocalPlayer
    end

    local function bindCharacter(player, character)
        if not SpaceRuntime.Active or not ui.Parent then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
            or character:WaitForChild("Humanoid", 4)
        if not humanoid or player.Character ~= character or not SpaceRuntime.Active or not ui.Parent then return end
        unbind(player)
        local rec = {humanoid = humanoid, lastHealth = humanoid.Health,
            creditedTime = -100, creditedDistance = nil, lastHitSound = -100,
            killPlayed = false, connections = {}}
        watched[player] = rec

        local function recentShot()
            local shot = markedShots[player]
            return shot and os.clock() - shot.at <= shotWindow and shot or nil
        end
        local function credited()
            return creatorMatches(humanoid) or recentShot() ~= nil
        end
        local function onDeath()
            if rec.killPlayed or watched[player] ~= rec then return end
            if credited() or os.clock() - rec.creditedTime <= 2.5 then
                rec.killPlayed = true
                local shot = recentShot()
                local meters = (shot and shot.distance)
                    or rec.creditedDistance or displayedDistance(player)
                local longEnabled = Toggles.LongKillSoundsEnabled
                    and Toggles.LongKillSoundsEnabled.Value
                -- Kill Sounds controls were removed. Close-range kills use
                -- the Hit Sound, if enabled; distant kills use Long Kill Sound.
                if meters and longEnabled and meters >= longKillThreshold then
                    play("LongKill", false)
                elseif meters and meters <= hitSoundMaxDistance then
                    play("Hit", false)
                end
            end
        end
        table.insert(rec.connections, SpaceRuntime:Connect(humanoid.HealthChanged, function(health)
            if watched[player] ~= rec then return end
            local old = rec.lastHealth
            rec.lastHealth = health
            if old <= health then return end
            if credited() then
                rec.creditedTime = os.clock()
                local shot = recentShot()
                rec.creditedDistance = (shot and shot.distance) or displayedDistance(player)
                if health <= 0 then
                    onDeath()
                elseif rec.creditedDistance and rec.creditedDistance <= hitSoundMaxDistance
                    and os.clock() - rec.lastHitSound >= 0.08 then
                    rec.lastHitSound = os.clock()
                    play("Hit", false)
                end
            end
        end))
        table.insert(rec.connections, SpaceRuntime:Connect(humanoid.Died, onDeath))
    end

    local function watchPlayer(player)
        if not SpaceRuntime.Active or player == LocalPlayer then return end
        local conns = {}
        playerConnections[player] = conns
        table.insert(conns, SpaceRuntime:Connect(player.CharacterAdded, function(char)
            task.spawn(bindCharacter, player, char)
        end))
        table.insert(conns, SpaceRuntime:Connect(player.CharacterRemoving, function()
            unbind(player)
        end))
        if player.Character then task.spawn(bindCharacter, player, player.Character) end
    end
    for _, player in ipairs(Players:GetPlayers()) do watchPlayer(player) end
    table.insert(connections, SpaceRuntime:Connect(Players.PlayerAdded, watchPlayer))
    table.insert(connections, SpaceRuntime:Connect(Players.PlayerRemoving, function(player)
        unbind(player)
        local conns = playerConnections[player]
        if conns then
            for _, connection in ipairs(conns) do connection:Disconnect() end
            playerConnections[player] = nil
        end
    end))

    SpaceRuntime:AddCleanup(function()
        headerTop.SoundShot = nil
        for _, connection in ipairs(connections) do connection:Disconnect() end
        for player in pairs(watched) do unbind(player) end
        for player, conns in pairs(playerConnections) do
            for _, connection in ipairs(conns) do connection:Disconnect() end
            playerConnections[player] = nil
        end
        for _, sound in pairs(soundObjects) do sound:Destroy() end
    end)
end)()

-- Hitbox Expander adapted from the supplied Specter script.
-- Kept inside a function scope to avoid Luau's top-level register limit.
-- The leading semicolon separates this IIFE from the preceding Connect(...) call.
;(function()
    local hitboxConfig = {
        Enabled = false,
        Invisible = false,
        Size = 5
    }
    local originalHeads = {}

    local function saveHead(head)
        local original = originalHeads[head]
        if original then return original end
        original = {
            Size = head.Size,
            Transparency = head.Transparency,
            Material = head.Material,
            Color = head.Color,
            CanCollide = head.CanCollide,
            Children = {}
        }
        originalHeads[head] = original
        return original
    end

    local function saveChild(original, child)
        if original.Children[child] then return original.Children[child] end
        local state
        if child:IsA("Decal") or child:IsA("Texture") then
            state = {Kind = "Transparency", Value = child.Transparency}
        elseif child:IsA("SpecialMesh") then
            state = {Kind = "Scale", Value = child.Scale}
        elseif child:IsA("BillboardGui") or child:IsA("SurfaceGui") then
            state = {Kind = "Enabled", Value = child.Enabled}
        end
        if state then original.Children[child] = state end
        return state
    end

    local function restoreHead(head, original)
        if not head or not head.Parent then return end
        pcall(function()
            head.Size = original.Size
            head.Transparency = original.Transparency
            head.Material = original.Material
            head.Color = original.Color
            head.CanCollide = original.CanCollide
        end)
        for child, originalState in pairs(original.Children) do
            if child.Parent then
                pcall(function()
                    child[originalState.Kind] = originalState.Value
                end)
            end
        end
    end

    local function restoreAll()
        for head, original in pairs(originalHeads) do
            restoreHead(head, original)
            originalHeads[head] = nil
        end
    end

    local function applyToHead(head)
        local original = saveHead(head)
        local size = hitboxConfig.Size
        pcall(function()
            head.Size = Vector3.new(size, size, size)
            head.CanCollide = false
            if hitboxConfig.Invisible then
                head.Transparency = 1
                head.Material = Enum.Material.Plastic
            else
                head.Transparency = 0.65
                head.Material = Enum.Material.ForceField
                head.Color = Color3.fromRGB(255, 50, 50)
            end
        end)

        -- Hide decals/meshes along with the head; restore their original
        -- values when "Invisible Hitbox" or the expander is switched off.
        for _, child in ipairs(head:GetChildren()) do
            local originalChild = saveChild(original, child)
            if originalChild then
                pcall(function()
                    if originalChild.Kind == "Transparency" then
                        child.Transparency = hitboxConfig.Invisible and 1 or originalChild.Value
                    elseif originalChild.Kind == "Scale" then
                        child.Scale = hitboxConfig.Invisible
                            and Vector3.new(0, 0, 0) or originalChild.Value
                    elseif originalChild.Kind == "Enabled" then
                        child.Enabled = not hitboxConfig.Invisible and originalChild.Value
                    end
                end)
            end
        end
    end

    local function updateHitboxes()
        if not hitboxConfig.Enabled then return end
        local activeHeads = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and not isSpaceFriend(player) and player.Character then
                local character = player.Character
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                local head = character:FindFirstChild("Head")
                if humanoid and humanoid.Health > 0 and head and head:IsA("BasePart") then
                    activeHeads[head] = true
                    applyToHead(head)
                end
            end
        end
        -- Also handle respawns, dead characters and players leaving the server.
        for head, original in pairs(originalHeads) do
            if not activeHeads[head] then
                restoreHead(head, original)
                originalHeads[head] = nil
            end
        end
    end

    -- Live 3D preview inside Combat > Hitbox (the right column).
    -- The mannequin exists only in a ViewportFrame; it never edits game characters.
    local hitboxPreviewBox = GeneralTab:AddRightTabbox("Hitbox Preview")
    local hitboxPreviewTab = hitboxPreviewBox:AddTab("Preview")
    local hitboxPreviewHost = uiCreate("Frame", {
        Name = "HitboxPreviewHost", Size = UDim2.new(1, -2, 0, 299),
        BackgroundColor3 = Color3.fromRGB(16, 17, 23),
        BorderSizePixel = 0, ClipsDescendants = true
    }, hitboxPreviewTab.Container)
    uiRound(hitboxPreviewHost, 9)

    local hitboxPreviewViewport = uiCreate("ViewportFrame", {
        Name = "HitboxViewport", Position = UDim2.fromOffset(7, 7),
        Size = UDim2.new(1, -14, 0, 237),
        BackgroundColor3 = Color3.fromRGB(21, 22, 30),
        BorderSizePixel = 0,
        Ambient = Color3.fromRGB(172, 172, 183),
        LightColor = Color3.fromRGB(255, 245, 241),
        LightDirection = Vector3.new(-1, -1, -0.6)
    }, hitboxPreviewHost)
    uiRound(hitboxPreviewViewport, 7)
    local hitboxPreviewWorld = Instance.new("WorldModel")
    hitboxPreviewWorld.Parent = hitboxPreviewViewport
    local hitboxPreviewCamera = Instance.new("Camera")
    hitboxPreviewCamera.FieldOfView = 43
    hitboxPreviewCamera.CFrame = CFrame.lookAt(
        Vector3.new(9, 7, -18), Vector3.new(0, 3.55, 0))
    hitboxPreviewCamera.Parent = hitboxPreviewViewport
    hitboxPreviewViewport.CurrentCamera = hitboxPreviewCamera

    local hitboxPreviewRig = Instance.new("Model")
    hitboxPreviewRig.Name = "PreviewOnlyDummy"
    hitboxPreviewRig.Parent = hitboxPreviewWorld
    local function previewPart(name, size, position, color)
        local part = Instance.new("Part")
        part.Name = name
        part.Anchored = true
        part.CanCollide = false
        part.CastShadow = false
        part.Material = Enum.Material.SmoothPlastic
        part.Color = color
        part.Size = size
        part.Position = position
        part.Parent = hitboxPreviewRig
        return part
    end
    local skin = Color3.fromRGB(250, 211, 70)
    previewPart("LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.51, 1.25, 0), Color3.fromRGB(66, 176, 91))
    previewPart("RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.51, 1.25, 0), Color3.fromRGB(66, 176, 91))
    previewPart("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3.27, 0), Color3.fromRGB(59, 136, 237))
    previewPart("LeftArm", Vector3.new(1, 2, 1), Vector3.new(-1.54, 3.27, 0), skin)
    previewPart("RightArm", Vector3.new(1, 2, 1), Vector3.new(1.54, 3.27, 0), skin)
    local normalHead = previewPart("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.8, 0), skin)
    local face = Instance.new("Decal")
    face.Name = "Face"
    face.Texture = "rbxasset://textures/face.png"
    face.Face = Enum.NormalId.Front
    face.Parent = normalHead

    local expandedHead = Instance.new("Part")
    expandedHead.Name = "ExpandedHeadPreview"
    expandedHead.Anchored = true
    expandedHead.CanCollide = false
    expandedHead.CastShadow = false
    expandedHead.Material = Enum.Material.ForceField
    expandedHead.Color = Color3.fromRGB(255, 75, 87)
    expandedHead.Position = normalHead.Position
    expandedHead.Parent = hitboxPreviewRig

    -- Wire edges remain faintly visible in the preview while Invisible Hitbox
    -- is enabled, so users can still see the size of the hidden volume.
    local hitboxPreviewEdges = {}
    for axis = 1, 3 do
        for _, a in ipairs({-1, 1}) do
            for _, b in ipairs({-1, 1}) do
                local edge = Instance.new("Part")
                edge.Name = "HitboxGuideEdge"
                edge.Anchored = true
                edge.CanCollide = false
                edge.CastShadow = false
                edge.Material = Enum.Material.Neon
                edge.Color = Color3.fromRGB(250, 105, 115)
                edge.Parent = hitboxPreviewRig
                table.insert(hitboxPreviewEdges, {part = edge, axis = axis, a = a, b = b})
            end
        end
    end

    local hitboxPreviewInfo = uiText(hitboxPreviewHost, "Hitbox disabled", 11, WHITE, true)
    hitboxPreviewInfo.Position = UDim2.fromOffset(10, 249)
    hitboxPreviewInfo.Size = UDim2.new(1, -20, 0, 19)
    hitboxPreviewInfo.TextXAlignment = Enum.TextXAlignment.Center
    local hitboxPreviewHint = uiText(hitboxPreviewHost,
        "Preview only - does not affect the game", 10, MUTED)
    hitboxPreviewHint.Position = UDim2.fromOffset(8, 269)
    hitboxPreviewHint.Size = UDim2.new(1, -16, 0, 19)
    hitboxPreviewHint.TextXAlignment = Enum.TextXAlignment.Center

    local function refreshHitboxPreview()
        if not hitboxPreviewHost.Parent then return end
        local size = math.clamp(tonumber(hitboxConfig.Size) or 5, 1, 6.35)
        local half = size * 0.5
        expandedHead.Size = Vector3.new(size, size, size)
        expandedHead.Transparency = not hitboxConfig.Enabled and 1
            or (hitboxConfig.Invisible and 1 or 0.76)
        for _, edge in ipairs(hitboxPreviewEdges) do
            local part = edge.part
            local a, b = edge.a * half, edge.b * half
            if edge.axis == 1 then
                part.Size = Vector3.new(size, 0.047, 0.047)
                part.Position = normalHead.Position + Vector3.new(0, a, b)
            elseif edge.axis == 2 then
                part.Size = Vector3.new(0.047, size, 0.047)
                part.Position = normalHead.Position + Vector3.new(a, 0, b)
            else
                part.Size = Vector3.new(0.047, 0.047, size)
                part.Position = normalHead.Position + Vector3.new(a, b, 0)
            end
            part.Transparency = not hitboxConfig.Enabled and 1
                or (hitboxConfig.Invisible and 0.66 or 0.13)
        end
        if not hitboxConfig.Enabled then
            hitboxPreviewInfo.Text = string.format("OFF  |  Size %.2f", size)
        elseif hitboxConfig.Invisible then
            hitboxPreviewInfo.Text = string.format("INVISIBLE  |  Size %.2f", size)
        else
            hitboxPreviewInfo.Text = string.format("VISIBLE  |  Size %.2f", size)
        end
    end
    refreshHitboxPreview()

    local hitboxBox = GeneralTab:AddRightTabbox("Hitbox Expander")
    local hitboxControls = hitboxBox:AddTab("Hitbox Expander")
    hitboxControls:AddToggle("HitboxExpanderEnabled", {
        Text = "Hitbox Expander", Default = false
    }):OnChanged(function()
        hitboxConfig.Enabled = Toggles.HitboxExpanderEnabled.Value
        if hitboxConfig.Enabled then
            updateHitboxes()
        else
            restoreAll()
        end
        refreshHitboxPreview()
    end)
    hitboxControls:AddToggle("HitboxExpanderInvisible", {
        Text = "Invisible Hitbox", Default = false
    }):OnChanged(function()
        hitboxConfig.Invisible = Toggles.HitboxExpanderInvisible.Value
        updateHitboxes()
        refreshHitboxPreview()
    end)
    hitboxControls:AddSlider("HitboxExpanderSize", {
        Text = "Head Size", Min = 1, Max = 6.35, Default = 5, Rounding = 2
    }):OnChanged(function()
        hitboxConfig.Size = math.clamp(tonumber(Options.HitboxExpanderSize.Value) or 5, 1, 6.35)
        updateHitboxes()
        refreshHitboxPreview()
    end)

    local elapsed = 0
    local heartbeatConnection
    heartbeatConnection = SpaceRuntime:Connect(RunService.Heartbeat, function(deltaTime)
        elapsed = elapsed + deltaTime
        if elapsed < 0.15 then return end
        elapsed = 0
        if not ui.Parent then
            restoreAll()
            heartbeatConnection:Disconnect()
            return
        end
        updateHitboxes()
    end)
    SpaceRuntime:AddCleanup(function()
        heartbeatConnection:Disconnect()
        restoreAll()
    end)
end)()

;(function()
-- Prediction / FOV controls and ConfigManager UI are constructed in a separate scope.
-- Prediction on the right side of General.
local PredictionBOX = GeneralTab:AddRightTabbox("Prediction") do
    local PredictionTab = PredictionBOX:AddTab("Prediction")

    PredictionTab:AddToggle("Prediction", {Text = "Mouse.Hit/Target Prediction"}):OnChanged(function()
        SilentAimSettings.MouseHitPrediction = Toggles.Prediction.Value
    end)

    PredictionTab:AddSlider("Amount", {Text = "Prediction Amount", Min = 0.165, Max = 1, Default = 0.165, Rounding = 3}):OnChanged(function()
        PredictionAmount = Options.Amount.Value
        SilentAimSettings.MouseHitPredictionAmount = Options.Amount.Value
    end)
end

-- FOV visuals in General (left side).
local VisualizeESPBOX = GeneralTab:AddLeftTabbox("Visuals") do
    local Visualize = VisualizeESPBOX:AddTab("Visuals")

    Visualize:AddToggle("Visible", {Text = "Show FOV Circle"}):AddColorPicker("Color", {Default = Color3.fromRGB(255, 255, 255)}):OnChanged(function()
        fov_circle.Visible = Toggles.Visible.Value
        SilentAimSettings.FOVVisible = Toggles.Visible.Value
    end)

    Visualize:AddSlider("Radius", {Text = "FOV Circle Radius", Min = 0, Max = 360, Default = 130, Rounding = 0}):OnChanged(function()
        fov_circle.Radius = Options.Radius.Value
        SilentAimSettings.FOVRadius = Options.Radius.Value
    end)
end

local function RefreshConfigDropdowns()
    local names = GetFiles()
    if Options.SaveConfigurationDropdown then
        Options.SaveConfigurationDropdown:SetValues(names)
    end
    if Options.LoadConfigurationDropdown then
        Options.LoadConfigurationDropdown:SetValues(names)
    end
end

local CreateConfigurationBOX = ConfigTab:AddLeftTabbox("Create Configuration") do
    local Main = CreateConfigurationBOX:AddTab("Create Configuration")
    Main:AddInput("CreateConfigTextBox", {
        Default = "", Numeric = false, Finished = false,
        Text = "Configuration Name", Placeholder = "File name"
    })
    Main:AddButton("Create Configuration File", function()
        if UpdateFile(Options.CreateConfigTextBox.Value) then
            RefreshConfigDropdowns()
        end
    end)
end

local SaveConfigurationBOX = ConfigTab:AddLeftTabbox("Save Configuration") do
    local Main = SaveConfigurationBOX:AddTab("Save Configuration")
    Main:AddDropdown("SaveConfigurationDropdown", {
        AllowNull = true, Values = GetFiles(), Text = "Choose Configuration to Save"
    })
    Main:AddButton("Save Configuration", function()
        if Options.SaveConfigurationDropdown.Value then
            UpdateFile(Options.SaveConfigurationDropdown.Value)
            RefreshConfigDropdowns()
        end
    end)
end

local LoadConfigurationBOX = ConfigTab:AddRightTabbox("Load Configuration") do
    local Main = LoadConfigurationBOX:AddTab("Load Configuration")
    Main:AddDropdown("LoadConfigurationDropdown", {
        AllowNull = true, Values = GetFiles(), Text = "Choose Configuration to Load"
    })
    Main:AddButton("Load Configuration", function()
        local selected = Options.LoadConfigurationDropdown.Value
        if selected and table.find(GetFiles(), selected) and LoadFile(selected) then
            -- Apply values for old-format configs (new configs restore every control).
            if type(isfile) == "function" and not isfile(ConfigPath(selected, "json")) then
                Toggles.TeamCheck:SetValue(SilentAimSettings.TeamCheck)
                Toggles.VisibleCheck:SetValue(SilentAimSettings.VisibleCheck)
                Toggles.MagicBullet:SetValue(SilentAimSettings.MagicBullet == true)
                Options.TargetPart:SetValue(SilentAimSettings.TargetPart)
                Options.Method:SetValue(SilentAimSettings.SilentAimMethod)
                Toggles.Visible:SetValue(SilentAimSettings.FOVVisible)
                Options.Radius:SetValue(SilentAimSettings.FOVRadius)
                Toggles.Prediction:SetValue(SilentAimSettings.MouseHitPrediction)
                Options.Amount:SetValue(SilentAimSettings.MouseHitPredictionAmount)
                Options.HitChance:SetValue(SilentAimSettings.HitChance)
            end
        end
    end)
    Main:AddButton("Refresh Config List", RefreshConfigDropdowns)
end

end)() -- End of scoped Prediction / FOV / ConfigManager controls

resume(create(function()

    SpaceRuntime:Connect(RenderStepped, function()

        local shouldShow = Toggles.Visible and Toggles.Visible.Value == true
        if fov_circle.Visible ~= shouldShow then
            fov_circle.Visible = shouldShow
        end
        if not shouldShow then return end
        local wantedColor = Options.Color.Value
        if fov_circle.Color ~= wantedColor then
            fov_circle.Color = wantedColor
        end
        local mousePosition = getMousePosition()
        if fov_circle.Position ~= mousePosition then
            fov_circle.Position = mousePosition
        end

    end)

end))

-- Install hooks in their own function scope: Luau allows at most
-- 200 local registers in any single function. This also prevents the
-- oldIndex local at the bottom from exhausting the main chunk's locals.
do
    (function()
        local oldNamecall

        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    if not SpaceRuntime.Active then return oldNamecall(...) end

    local Method = getnamecallmethod()

    local Arguments = {...}

    local self = Arguments[1]

    local chance = CalculateChance(SilentAimSettings.HitChance)

    if isAimActive() and self == workspace and not checkcaller() and chance == true then

        if Method == "FindPartOnRayWithIgnoreList" and Options.Method.Value == Method then

            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithIgnoreList) then

                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()

                if HitPart then

                    local Origin = A_Ray.Origin

                    local Direction = getDirection(Origin, HitPart.Position)

                    Arguments[2] = Ray.new(Origin, Direction)

                    if SilentAimSettings.MagicBullet then
                        -- Whitelist bypasses intervening world parts client-side.
                        return workspace:FindPartOnRayWithWhitelist(
                            Arguments[2], {HitPart.Parent}, true
                        )
                    end
                    return oldNamecall(unpack(Arguments))

                end

            end

        elseif Method == "FindPartOnRayWithWhitelist" and Options.Method.Value == Method then

            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithWhitelist) then

                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()

                if HitPart then

                    local Origin = A_Ray.Origin

                    local Direction = getDirection(Origin, HitPart.Position)

                    Arguments[2] = Ray.new(Origin, Direction)
                    if SilentAimSettings.MagicBullet then
                        Arguments[3] = {HitPart.Parent}
                    end
                    return oldNamecall(unpack(Arguments))

                end

            end

        elseif (Method == "FindPartOnRay" or Method == "findPartOnRay") and Options.Method.Value:lower() == Method:lower() then

            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRay) then

                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()

                if HitPart then

                    local Origin = A_Ray.Origin

                    local Direction = getDirection(Origin, HitPart.Position)

                    Arguments[2] = Ray.new(Origin, Direction)
                    if SilentAimSettings.MagicBullet then
                        return workspace:FindPartOnRayWithWhitelist(
                            Arguments[2], {HitPart.Parent}, true
                        )
                    end
                    return oldNamecall(unpack(Arguments))

                end

            end

        elseif Method == "Raycast" and Options.Method.Value == Method then

            if ValidateArguments(Arguments, ExpectedArguments.Raycast) then

                local A_Origin = Arguments[2]

                local HitPart = getClosestPlayer()

                if HitPart then

                    Arguments[3] = getDirection(A_Origin, HitPart.Position)
                    if SilentAimSettings.MagicBullet then
                        local previousParams = Arguments[4]
                        local magicParams = RaycastParams.new()
                        magicParams.FilterType = Enum.RaycastFilterType.Include
                        magicParams.FilterDescendantsInstances = {HitPart.Parent}
                        magicParams.IgnoreWater = true
                        if typeof(previousParams) == "RaycastParams" then
                            magicParams.CollisionGroup = previousParams.CollisionGroup
                            magicParams.RespectCanCollide = previousParams.RespectCanCollide
                        end
                        Arguments[4] = magicParams
                    end
                    return oldNamecall(unpack(Arguments))

                end

            end

        end

    end

    return oldNamecall(...)

end))

local oldIndex = nil

oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, Index)
    if not SpaceRuntime.Active then return oldIndex(self, Index) end

    if self == Mouse and not checkcaller() and isAimActive() and Options.Method.Value == "Mouse.Hit/Target" and getClosestPlayer() then

        local HitPart = getClosestPlayer()

        if Index == "Target" or Index == "target" then

            return HitPart

        elseif Index == "Hit" or Index == "hit" then

            return ((Toggles.Prediction.Value and (HitPart.CFrame + (HitPart.Velocity * PredictionAmount))) or (not Toggles.Prediction.Value and HitPart.CFrame))

        elseif Index == "X" or Index == "x" then

            return oldIndex(self, Index)

        elseif Index == "Y" or Index == "y" then

            return oldIndex(self, Index)

        elseif Index == "UnitRay" then

            return Ray.new(self.Origin, (self.Hit - self.Origin).Unit)

        end

    end

    return oldIndex(self, Index)

end))
    end)()
end

-- Startup intro: softly reveal the header, then gently bring up its content.
-- Reopening the menu uses animateMenu instead of replaying the intro.
;(function()
    local introViewport = frame:FindFirstChild("SpaceSolutionIntroViewport")
    local introBody = introViewport and introViewport:FindFirstChild("SpaceSolutionIntroBody")
    if introBody then
        frame:SetAttribute("SpaceSolutionIntroInterrupted", false)
        ui.Enabled = true
        frame.Visible = true
        frame.Size = UDim2.fromOffset(862, 524)
        frame.Position = UDim2.fromScale(0.5, 0.5)
        frame.GroupTransparency = 1
        introBody.Position = UDim2.fromOffset(0, 96)
        introBody.GroupTransparency = 1
        TweenService:Create(frame,
            TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
            {GroupTransparency = 0}
        ):Play()
        task.delay(0.44, function()
            if not ui.Parent or not menuOpen
                or frame:GetAttribute("SpaceSolutionIntroInterrupted") then return end
            TweenService:Create(introBody,
                TweenInfo.new(0.68, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
                {Position = UDim2.fromOffset(0, 0), GroupTransparency = 0}
            ):Play()
        end)
    else
        animateMenu(true, true)
    end
end)()
