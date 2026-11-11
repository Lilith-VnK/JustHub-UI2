local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local StarterGui       = game:GetService("StarterGui")
local localPlayer = Players.LocalPlayer
if not localPlayer then
    error("JustHub must be initialized from a client context", 2)
end
local targetParent = localPlayer:WaitForChild("PlayerGui")
do
    local coreGuiOk, coreGui = pcall(function()
        return game:GetService("CoreGui")
    end)
    if coreGuiOk and coreGui then
        local probe = Instance.new("ScreenGui")
        local canUseCoreGui = pcall(function()
            probe.Parent = coreGui
        end)
        pcall(function() probe:Destroy() end)
        if canUseCoreGui then
            targetParent = coreGui
        end
    end
end
for _, child in ipairs(targetParent:GetChildren()) do
    if child.Name == "JustHub" or child.Name == "JustHubLoadingScreen" or child.Name == "JustHubShowUI" then
        pcall(function() child:Destroy() end)
    end
end

local function shallowClone(t)
    if type(t) ~= "table" then return {} end
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

local JustHub = {}

JustHub.Themes = {
    Darker   = {["Color Hub 1"] = Color3.fromRGB(15, 15, 20),   ["Color Hub 2"] = Color3.fromRGB(25, 25, 30),   ["Color Stroke"] = Color3.fromRGB(45, 45, 55),   ["Color Theme"] = Color3.fromRGB(100, 255, 150), ["Color Text"] = Color3.fromRGB(240, 240, 245), ["Color Dark Text"] = Color3.fromRGB(160, 160, 170)},
    Dark     = {["Color Hub 1"] = Color3.fromRGB(25, 25, 30),   ["Color Hub 2"] = Color3.fromRGB(35, 35, 40),   ["Color Stroke"] = Color3.fromRGB(60, 60, 70),   ["Color Theme"] = Color3.fromRGB(80, 200, 255),  ["Color Text"] = Color3.fromRGB(245, 245, 250), ["Color Dark Text"] = Color3.fromRGB(170, 170, 180)},
    Purple   = {["Color Hub 1"] = Color3.fromRGB(20, 15, 30),   ["Color Hub 2"] = Color3.fromRGB(30, 25, 40),   ["Color Stroke"] = Color3.fromRGB(50, 40, 65),   ["Color Theme"] = Color3.fromRGB(150, 100, 255), ["Color Text"] = Color3.fromRGB(240, 240, 245), ["Color Dark Text"] = Color3.fromRGB(170, 160, 190)},
    Light    = {["Color Hub 1"] = Color3.fromRGB(210, 210, 215),["Color Hub 2"] = Color3.fromRGB(230, 230, 235),["Color Stroke"] = Color3.fromRGB(180, 180, 190),["Color Theme"] = Color3.fromRGB(0, 140, 255),   ["Color Text"] = Color3.fromRGB(40, 40, 45),    ["Color Dark Text"] = Color3.fromRGB(90, 90, 100)},
    Neon     = {["Color Hub 1"] = Color3.fromRGB(5, 5, 10),     ["Color Hub 2"] = Color3.fromRGB(10, 10, 15),   ["Color Stroke"] = Color3.fromRGB(0, 255, 255),  ["Color Theme"] = Color3.fromRGB(0, 255, 100),   ["Color Text"] = Color3.fromRGB(255, 255, 255), ["Color Dark Text"] = Color3.fromRGB(200, 255, 255)},
    Forest   = {["Color Hub 1"] = Color3.fromRGB(0, 30, 15),    ["Color Hub 2"] = Color3.fromRGB(0, 45, 25),    ["Color Stroke"] = Color3.fromRGB(0, 75, 35),    ["Color Theme"] = Color3.fromRGB(50, 205, 50),   ["Color Text"] = Color3.fromRGB(230, 255, 230), ["Color Dark Text"] = Color3.fromRGB(170, 200, 170)},
    Aqua     = {["Color Hub 1"] = Color3.fromRGB(0, 70, 80),    ["Color Hub 2"] = Color3.fromRGB(0, 100, 110),  ["Color Stroke"] = Color3.fromRGB(0, 160, 180),  ["Color Theme"] = Color3.fromRGB(0, 230, 255),   ["Color Text"] = Color3.fromRGB(250, 255, 255), ["Color Dark Text"] = Color3.fromRGB(200, 230, 240)},
    Crimson  = {["Color Hub 1"] = Color3.fromRGB(35, 0, 5),     ["Color Hub 2"] = Color3.fromRGB(60, 0, 10),    ["Color Stroke"] = Color3.fromRGB(110, 0, 20),   ["Color Theme"] = Color3.fromRGB(255, 50, 80),   ["Color Text"] = Color3.fromRGB(255, 240, 240), ["Color Dark Text"] = Color3.fromRGB(220, 180, 180)},
    Solar    = {["Color Hub 1"] = Color3.fromRGB(230, 190, 0),  ["Color Hub 2"] = Color3.fromRGB(255, 210, 0),  ["Color Stroke"] = Color3.fromRGB(255, 150, 0),  ["Color Theme"] = Color3.fromRGB(255, 80, 0),    ["Color Text"] = Color3.fromRGB(30, 30, 30),    ["Color Dark Text"] = Color3.fromRGB(70, 70, 70)},
    Pastel   = {["Color Hub 1"] = Color3.fromRGB(210, 190, 220),["Color Hub 2"] = Color3.fromRGB(235, 220, 245),["Color Stroke"] = Color3.fromRGB(180, 160, 200),["Color Theme"] = Color3.fromRGB(170, 210, 240), ["Color Text"] = Color3.fromRGB(70, 70, 70),    ["Color Dark Text"] = Color3.fromRGB(110, 110, 110)},
    Cyber    = {["Color Hub 1"] = Color3.fromRGB(5, 5, 20),     ["Color Hub 2"] = Color3.fromRGB(15, 15, 35),   ["Color Stroke"] = Color3.fromRGB(0, 220, 255),  ["Color Theme"] = Color3.fromRGB(0, 180, 255),   ["Color Text"] = Color3.fromRGB(250, 255, 255), ["Color Dark Text"] = Color3.fromRGB(190, 230, 255)},
    Ocean    = {["Color Hub 1"] = Color3.fromRGB(0, 20, 40),    ["Color Hub 2"] = Color3.fromRGB(0, 35, 70),    ["Color Stroke"] = Color3.fromRGB(0, 80, 150),   ["Color Theme"] = Color3.fromRGB(0, 150, 255),   ["Color Text"] = Color3.fromRGB(230, 245, 255), ["Color Dark Text"] = Color3.fromRGB(180, 210, 230)},
    Desert   = {["Color Hub 1"] = Color3.fromRGB(180, 150, 110),["Color Hub 2"] = Color3.fromRGB(210, 170, 120),["Color Stroke"] = Color3.fromRGB(140, 70, 30),  ["Color Theme"] = Color3.fromRGB(220, 150, 30),  ["Color Text"] = Color3.fromRGB(50, 40, 30),    ["Color Dark Text"] = Color3.fromRGB(90, 80, 70)},
    Galaxy   = {["Color Hub 1"] = Color3.fromRGB(10, 0, 30),    ["Color Hub 2"] = Color3.fromRGB(20, 0, 40),    ["Color Stroke"] = Color3.fromRGB(70, 0, 120),   ["Color Theme"] = Color3.fromRGB(140, 0, 255),   ["Color Text"] = Color3.fromRGB(245, 245, 255), ["Color Dark Text"] = Color3.fromRGB(200, 200, 230)},
    Vintage  = {["Color Hub 1"] = Color3.fromRGB(120, 90, 60),  ["Color Hub 2"] = Color3.fromRGB(140, 110, 80), ["Color Stroke"] = Color3.fromRGB(100, 70, 50),  ["Color Theme"] = Color3.fromRGB(190, 150, 120), ["Color Text"] = Color3.fromRGB(70, 50, 40),    ["Color Dark Text"] = Color3.fromRGB(100, 90, 80)},
    Rainbow  = {["Color Hub 1"] = Color3.fromRGB(240, 240, 240),["Color Hub 2"] = Color3.fromRGB(255, 255, 255),["Color Stroke"] = Color3.fromRGB(200, 200, 200),["Color Theme"] = Color3.fromRGB(255, 100, 100), ["Color Text"] = Color3.fromRGB(30, 30, 30),    ["Color Dark Text"] = Color3.fromRGB(90, 90, 90)},
    Midnight = {["Color Hub 1"] = Color3.fromRGB(0, 0, 20),     ["Color Hub 2"] = Color3.fromRGB(5, 5, 30),     ["Color Stroke"] = Color3.fromRGB(0, 0, 80),     ["Color Theme"] = Color3.fromRGB(50, 50, 255),   ["Color Text"] = Color3.fromRGB(250, 250, 255), ["Color Dark Text"] = Color3.fromRGB(190, 190, 220)}
}

JustHub.Info = {Version = "3.1.2"}
JustHub.Save = {UISize = {620, 440}, TabSize = 135, Theme = "Darker", Transparency = 0.1, Locked = false}
JustHub.ConfigData = {}
JustHub.ControlRegistry = {}
JustHub.ControlAliases = {}
JustHub.AmbiguousControlAliases = {}
JustHub.Controls = {}
JustHub.Localization = {}
JustHub.CurrentLang = "en"
JustHub.UserRole = "member"
JustHub.UndoStack = {}
JustHub.RedoStack = {}
JustHub.Sounds = {ButtonClick = 0, SliderMove = 0}
JustHub.Connections = {}
JustHub.ScreenGuis = {}
JustHub.ThemeObjects = setmetatable({}, {__mode = "k"})
JustHub.ChromaEnabled = false
JustHub.ChromaObjects = setmetatable({}, {__mode = "k"})
JustHub.KeySystem = {Enabled = false, Key = ""}
JustHub.PromoNotifyEnabled = true
JustHub._isApplyingConfig = false
JustHub._destroyed = false
JustHub._initializing = false
JustHub._historyMax = 100
JustHub._promoThread = nil
JustHub._notificationThreads = {}

JustHub.Icons = (function()
    local iconData = {
        {"activity", 10709752035}, {"check", 10709790644}, {"cog", 10709810948},
        {"folder", 10723387563}, {"home", 10723405786}, {"menu", 10723406085},
        {"search", 10723406260}, {"settings", 10723406450}, {"user", 10723406670}
    }
    local icons = {}
    for _, pair in ipairs(iconData) do icons[pair[1]] = "rbxassetid://" .. tostring(pair[2]) end
    return icons
end)()

JustHub.DesignTokens = {
    Colors = {
        SurfacePrimary = "Color Hub 1",
        SurfaceElevated = "Color Hub 2",
        Border = "Color Stroke",
        Accent = "Color Theme",
        TextPrimary = "Color Text",
        TextSecondary = "Color Dark Text",
    },
    Transparency = {},
    Geometry = {
        WindowRadius = 14, SidebarRadius = 12, TabRadius = 8,
        SectionRadius = 10, ControlRadius = 9, InputRadius = 7,
        PopupRadius = 10, ButtonRadius = 7,
    },
    Spacing = {XS = 4, SM = 8, MD = 12, LG = 16, XL = 20},
    Animation = {
        General = 0.18, Hover = 0.14, Press = 0.10,
        TabTransition = 0.24, PopupTransition = 0.24,
        ToggleTransition = 0.22, NotificationTransition = 0.30,
    },
    Opacity = {Border = 0.58, MutedIcon = 0.22},
}

local activeTweens = setmetatable({}, {__mode = "k"})
local chromaRenderConn = nil
local surfaceRegistry = setmetatable({}, {__mode = "k"})

local function refreshTransparencyTokens()
    local base = math.clamp(
        tonumber(JustHub.Save.Transparency) or 0.03,
        0,
        0.85
    )

    local function derive(offset)
        return math.clamp(base + offset, 0, 0.85)
    end

    local t = JustHub.DesignTokens.Transparency

    t.MainWindow   = base
    t.Sidebar      = derive(0.005)
    t.Content      = derive(0.005)
    t.TabActive    = derive(0.005)
    t.TabHover     = derive(0.010)
    t.TabInactive  = derive(0.020)
    t.Section      = derive(0.005)
    t.Control      = derive(0.010)
    t.Input        = derive(0.005)
    t.Popup        = base
    t.Notification = base
    t.Button       = derive(0.010)
end
JustHub.Save.Transparency = 0.03
refreshTransparencyTokens()

local function surfaceTransparency(kind)
    local values = JustHub.DesignTokens.Transparency
    return values[kind] or values.Control or 0.4
end

local function registerSurface(obj, kind)
    if not obj or not kind then return obj end
    local ok = pcall(function()
        if obj:IsA("GuiObject") then
            surfaceRegistry[obj] = {Kind = kind}
            obj.BackgroundTransparency = surfaceTransparency(kind)
        end
    end)
    if not ok then surfaceRegistry[obj] = nil end
    return obj
end

local function hasAncestorName(parent, targetName)
    local current = parent
    while current do
        if current.Name == targetName then return true end
        current = current.Parent
    end
    return false
end

local function classifySurface(className, props, parent)
    local name = props and props.Name or ""
    if name == "MainFrame" then return "MainWindow" end
    if name == "Sidebar" then return "Sidebar" end
    if name == "ContentContainer" then return "Content" end
    if name == "SearchFrame" then return "Input" end
    if className == "Frame" and parent and string.find(parent.Name, "Dropdown", 1, true) then return "Popup" end
    if hasAncestorName(parent, "NotificationContainer") and className == "Frame" and parent and parent.Name == "NotificationContainer" then
        return "Notification"
    end
    if parent and parent.Name == "Sidebar" and className == "TextButton" then return "TabInactive" end
    if className == "Frame" and parent and parent.Name == "SectionContent"
        and props and props.BackgroundTransparency ~= 1 then return "Control" end
    if className == "Frame" and parent and parent:IsA("ScrollingFrame")
        and string.sub(parent.Name, -7) == "Content" then return "Section" end
    if className == "TextBox" and (hasAncestorName(parent, "SectionContent") or hasAncestorName(parent, "Body")) then
        return "Input"
    end
    if className == "TextButton" and props and type(props.Text) == "string" and props.Text ~= ""
        and props.BackgroundTransparency ~= 1 and hasAncestorName(parent, "SectionContent") then return "Button" end
    if props and type(props.BackgroundTransparency) == "number" and props.BackgroundTransparency < 1
        and hasAncestorName(parent, "SectionContent") then return "Control" end
    return nil
end

local function setSurfaceKind(obj, kind)
    if obj and kind then surfaceRegistry[obj] = {Kind = kind} end
    return obj
end

local function isAlive() return not JustHub._destroyed end

local function addConnection(conn)
    if not conn then return nil end
    if not isAlive() then pcall(function() conn:Disconnect() end) return nil end
    table.insert(JustHub.Connections, conn)
    return conn
end

local function removeConnection(conn)
    if not conn then return end
    for i = #JustHub.Connections, 1, -1 do
        if JustHub.Connections[i] == conn then
            table.remove(JustHub.Connections, i)
            break
        end
    end
end

local function trackScreenGui(sg)
    if not sg then return nil end
    if not isAlive() then
        pcall(function() sg:Destroy() end)
        return nil
    end
    table.insert(JustHub.ScreenGuis, sg)
    return sg
end

local function createInstance(className, props, parent)
    if className == "UICorner" and parent and surfaceRegistry[parent] then
        local radiusByKind = {
            MainWindow = JustHub.DesignTokens.Geometry.WindowRadius,
            Sidebar = JustHub.DesignTokens.Geometry.SidebarRadius,
            Content = 12,
            TabActive = JustHub.DesignTokens.Geometry.TabRadius,
            TabInactive = JustHub.DesignTokens.Geometry.TabRadius,
            Section = JustHub.DesignTokens.Geometry.SectionRadius,
            Control = JustHub.DesignTokens.Geometry.ControlRadius,
            Input = JustHub.DesignTokens.Geometry.InputRadius,
            Popup = JustHub.DesignTokens.Geometry.PopupRadius,
            Notification = JustHub.DesignTokens.Geometry.ControlRadius,
            Button = JustHub.DesignTokens.Geometry.ButtonRadius,
        }
        local radius = radiusByKind[surfaceRegistry[parent].Kind]
        local isPill = props and props.CornerRadius and props.CornerRadius.Scale >= 1
        if radius and not isPill then
            props = shallowClone(props)
            props.CornerRadius = UDim.new(0, radius)
        end
    end
    local obj = Instance.new(className)
    if props then for k, v in pairs(props) do obj[k] = v end end
    if className == "TextButton" then
        if not props or props.Active == nil then obj.Active = true end
        if not props or props.Selectable == nil then obj.Selectable = true end
    elseif className == "TextBox" then
        if not props or props.Active == nil then obj.Active = true end
        if not props or props.Selectable == nil then obj.Selectable = true end
        if not props or props.TextEditable == nil then obj.TextEditable = true end
    end
    if parent then obj.Parent = parent end
    local surfaceKind = classifySurface(className, props, parent)
    if surfaceKind then registerSurface(obj, surfaceKind) end
    return obj
end

local function connectOnce(signal, callback)
    local connection
    connection = signal:Connect(function(...)
        if connection then
            connection:Disconnect()
            connection = nil
        end
        callback(...)
    end)
    return connection
end

local function tweenProperty(guiObject, goal, time, easingStyle, easingDirection)
    if not guiObject or not guiObject.Parent then return nil end
    if activeTweens[guiObject] then activeTweens[guiObject]:Cancel() end
    local ti = TweenInfo.new(time or JustHub.DesignTokens.Animation.General, easingStyle or Enum.EasingStyle.Quad, easingDirection or Enum.EasingDirection.Out)
    local tween = TweenService:Create(guiObject, ti, goal)
    activeTweens[guiObject] = tween
    connectOnce(tween.Completed, function()
        if activeTweens[guiObject] == tween then activeTweens[guiObject] = nil end
    end)
    tween:Play()
    return tween
end

local requiredThemeKeys = {
    "Color Hub 1", "Color Hub 2", "Color Stroke",
    "Color Theme", "Color Text", "Color Dark Text"
}

local function isValidTheme(theme)
    if type(theme) ~= "table" then return false end
    for _, key in ipairs(requiredThemeKeys) do
        if typeof(theme[key]) ~= "Color3" then return false end
    end
    return true
end

local function getCurrentTheme(themeName)
    local theme = type(themeName) == "table"
        and themeName
        or JustHub.Themes[themeName or JustHub.Save.Theme]
    if isValidTheme(theme) then return theme end
    return JustHub.Themes["Darker"]
end

local function applyTheme(obj, prop, themeKey)
    if not JustHub.ThemeObjects[obj] then JustHub.ThemeObjects[obj] = {} end
    JustHub.ThemeObjects[obj][prop] = {ThemeKey = themeKey}
    local currentTheme = getCurrentTheme(JustHub.Save.Theme)
    if currentTheme[themeKey] then obj[prop] = currentTheme[themeKey] end
end

function JustHub:UpdateThemeObject(obj, prop, newThemeKey)
    if self.ThemeObjects[obj] and self.ThemeObjects[obj][prop] then
        self.ThemeObjects[obj][prop].ThemeKey = newThemeKey
    end
end

local function addBorder(obj, themeKey, thickness)
    local stroke = createInstance("UIStroke", {Thickness = thickness, Transparency = JustHub.DesignTokens.Opacity.Border}, obj)
    applyTheme(stroke, "Color", themeKey)
    return stroke
end

local function updateChromaConn()
    if JustHub.ChromaEnabled and next(JustHub.ChromaObjects) and isAlive() then
        if not chromaRenderConn then
            chromaRenderConn = RunService.Heartbeat:Connect(function()
                if not isAlive() then return end
                local color = Color3.fromHSV((tick() % 5) / 5, 1, 1)
                for obj, props in pairs(JustHub.ChromaObjects) do
                    for prop, _ in pairs(props) do
                        obj[prop] = color
                    end
                end
            end)
        end
    elseif chromaRenderConn then
        chromaRenderConn:Disconnect()
        chromaRenderConn = nil
    end
end

local function registerChroma(obj, property, themeKey)
    if not JustHub.ChromaObjects[obj] then JustHub.ChromaObjects[obj] = {} end
    JustHub.ChromaObjects[obj][property] = themeKey or true
    updateChromaConn()
end

function JustHub:UnregisterChroma(obj, property)
    if self.ChromaObjects[obj] then
        if property then
            self.ChromaObjects[obj][property] = nil
            if not next(self.ChromaObjects[obj]) then self.ChromaObjects[obj] = nil end
        else
            self.ChromaObjects[obj] = nil
        end
    end
    updateChromaConn()
end

function JustHub:ToggleChroma(state)
    self.ChromaEnabled = state
    updateChromaConn()
    if not state then
        local theme = getCurrentTheme(self.Save.Theme)
        for obj, props in pairs(self.ChromaObjects) do
            for prop, themeKey in pairs(props) do
                if type(themeKey) == "string" and theme[themeKey] then
                    obj[prop] = theme[themeKey]
                end
            end
        end
    end
end

local function makeControlId(tab, section, name)
    local baseId = tostring(tab or "") .. "/" .. tostring(section or "") .. "/" .. tostring(name or "_")
    local controlId = baseId
    local suffix = 2
    while JustHub.ControlRegistry[controlId] or JustHub.ConfigData[controlId] do
        controlId = baseId .. "#" .. tostring(suffix)
        suffix = suffix + 1
    end
    return controlId
end

local function normalizeStringArray(value)
    local normalized = {}
    if type(value) == "table" then
        for _, item in ipairs(value) do
            if type(item) == "string" then table.insert(normalized, item) end
        end
    end
    return normalized
end

local function createControl(opts)
    local ctrl = {
        id          = opts.id,
        shortName   = opts.shortName,
        default     = opts.default,
        callback    = opts.callback or function() end,
        updateVisuals = opts.updateVisuals or function() end,
        validate     = opts.validate,
        _value      = opts.default,
        _editStart  = nil,
    }
    local function fireCallback(val)
        local ok, err = pcall(ctrl.callback, val)
        if not ok then warn("[JustHub] Callback error for '" .. tostring(ctrl.id) .. "': " .. tostring(err)) end
    end
    local function setValueCore(newVal, applyOpts)
        applyOpts = applyOpts or {}
        if ctrl.validate then
            local valid, reason = ctrl.validate(newVal)
            if not valid then error(reason or ("Invalid value for control " .. tostring(ctrl.id)), 0) end
        end
        local oldVal = ctrl._value
        ctrl._value = newVal
        JustHub.ConfigData[ctrl.id] = newVal
        if not applyOpts.skipVisual then
            local visualOk, visualErr = pcall(ctrl.updateVisuals, newVal)
            if not visualOk then
                ctrl._value = oldVal
                JustHub.ConfigData[ctrl.id] = oldVal
                pcall(ctrl.updateVisuals, oldVal)
                error(visualErr, 0)
            end
        end
        if not applyOpts.skipCallback then
            task.spawn(fireCallback, newVal)
        end
        if not applyOpts.skipHistory and not JustHub._isApplyingConfig and oldVal ~= newVal then
            JustHub:AddUndo(ctrl.id, oldVal, newVal)
        end
    end
    function ctrl.setValue(v) setValueCore(v) end
    function ctrl.setValueLive(v) setValueCore(v, {skipHistory = true}) end
    function ctrl.getValue() return ctrl._value end
    function ctrl.beginEdit() ctrl._editStart = ctrl._value end
    function ctrl.endEdit()
        if ctrl._editStart ~= nil and ctrl._editStart ~= ctrl._value and not JustHub._isApplyingConfig then
            JustHub:AddUndo(ctrl.id, ctrl._editStart, ctrl._value)
        end
        ctrl._editStart = nil
    end
    JustHub.ConfigData[ctrl.id] = ctrl._value
    return ctrl
end

function JustHub:RegisterControl(id, setter, meta)
    meta = meta or {}
    if type(id) ~= "string" or id == "" or type(setter) ~= "function" then
        warn("[JustHub] Invalid control registration")
        return false
    end
    local existing = self.ControlRegistry[id]
    if existing and existing ~= setter then
        warn("[JustHub] Control ID collision: " .. tostring(id))
        return false
    end
    self.ControlRegistry[id] = setter
    self.Controls[id] = meta
    local shortName = meta.shortName
    if type(shortName) == "string" and shortName ~= "" and shortName ~= id
        and not self.AmbiguousControlAliases[shortName] then
        local existingAlias = self.ControlAliases[shortName]
        if existingAlias and existingAlias ~= setter then
            self.ControlAliases[shortName] = nil
            self.AmbiguousControlAliases[shortName] = true
            if not self.ControlRegistry[shortName] then
                self.Controls[shortName] = nil
            end
            warn("[JustHub] Ambiguous short control name; use the full control ID: " .. shortName)
        else
            self.ControlAliases[shortName] = setter
            if not self.ControlRegistry[shortName] then
                self.Controls[shortName] = meta
            end
        end
    end
    return true
end

function JustHub:SetUserRole(roleName) self.UserRole = roleName end
function JustHub:CheckRole(requiredRole) return self.UserRole == requiredRole end

function JustHub:AddUndo(controlKey, oldValue, newValue)
    if self._isApplyingConfig then return end
    if oldValue == newValue then return end
    local last = self.UndoStack[#self.UndoStack]
    if last and last.key == controlKey and last.new == oldValue then
        last.new = newValue
    else
        table.insert(self.UndoStack, {key = controlKey, old = oldValue, new = newValue})
        if #self.UndoStack > self._historyMax then table.remove(self.UndoStack, 1) end
    end
    table.clear(self.RedoStack)
end

function JustHub:Undo()
    local last = self.UndoStack[#self.UndoStack]
    if not last then return false end
    local setter = self.ControlRegistry[last.key]
    if not setter then return false end
    local wasApplyingConfig = self._isApplyingConfig
    self._isApplyingConfig = true
    local ok, err = pcall(setter, last.old)
    self._isApplyingConfig = wasApplyingConfig
    if not ok then
        warn("[JustHub] Undo failed for '" .. tostring(last.key) .. "': " .. tostring(err))
        return false
    end
    self.UndoStack[#self.UndoStack] = nil
    table.insert(self.RedoStack, last)
    return true
end

function JustHub:Redo()
    local last = self.RedoStack[#self.RedoStack]
    if not last then return false end
    local setter = self.ControlRegistry[last.key]
    if not setter then return false end
    local wasApplyingConfig = self._isApplyingConfig
    self._isApplyingConfig = true
    local ok, err = pcall(setter, last.new)
    self._isApplyingConfig = wasApplyingConfig
    if not ok then
        warn("[JustHub] Redo failed for '" .. tostring(last.key) .. "': " .. tostring(err))
        return false
    end
    self.RedoStack[#self.RedoStack] = nil
    table.insert(self.UndoStack, last)
    return true
end

function JustHub:ApplyConfig(configData)
    if type(configData) ~= "table" then return false, "Invalid config table" end
    local wasApplyingConfig = self._isApplyingConfig
    self._isApplyingConfig = true
    local applied, skipped = 0, 0
    local canonicalPresent = {}
    for key, val in pairs(configData) do
        local setter = self.ControlRegistry[key]
        if setter then
            canonicalPresent[setter] = true
            local ok, err = pcall(setter, val)
            if ok then applied = applied + 1
            else
                skipped = skipped + 1
                warn("[JustHub] Failed to apply '" .. tostring(key) .. "': " .. tostring(err))
            end
        end
    end
    for key, val in pairs(configData) do
        if not self.ControlRegistry[key] then
            local setter = self.ControlAliases[key]
            if setter and not canonicalPresent[setter] then
                local ok, err = pcall(setter, val)
                if ok then applied = applied + 1
                else
                    skipped = skipped + 1
                    warn("[JustHub] Failed to apply legacy key '" .. tostring(key) .. "': " .. tostring(err))
                end
            elseif not setter then
                skipped = skipped + 1
            end
        end
    end
    self._isApplyingConfig = wasApplyingConfig
    return true, {applied = applied, skipped = skipped}
end

function JustHub:RegisterTheme(name, definition)
    if type(name) ~= "string" or name == "" or not isValidTheme(definition) then
        warn("[JustHub] Invalid theme. Expected a name and all six Color3 theme fields.")
        return false
    end
    self.Themes[name] = definition
    return true
end

function JustHub:PlaySound(name)
    if self.Sounds[name] and self.Sounds[name] ~= 0 then
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://" .. tostring(self.Sounds[name])
        s.Volume = 1; s.PlayOnRemove = true; s.Parent = workspace; s:Destroy()
    end
end

function JustHub:SetLanguage(lang) self.CurrentLang = lang end
function JustHub:LocalizeText(textKey) return (self.Localization[self.CurrentLang] and self.Localization[self.CurrentLang][textKey]) or textKey end

local function createDropdownScaffolding(parent, title, defaultText)
    local frame = createInstance("Frame", {
        Name = title .. "Dropdown", Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 0.15,
        ClipsDescendants = false, BorderSizePixel = 0, ZIndex = 1
    }, parent)
    applyTheme(frame, "BackgroundColor3", "Color Hub 2")
    local bgFrame = createInstance("Frame", {Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2}, frame)
    applyTheme(bgFrame, "BackgroundColor3", "Color Hub 2")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, bgFrame)
    addBorder(bgFrame, "Color Stroke", 1)
    local headerBtn = createInstance("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 3}, bgFrame)
    local label = createInstance("TextLabel", {
        Text = title, Size = UDim2.new(0.5, -10, 1, 0), Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3
    }, headerBtn)
    applyTheme(label, "TextColor3", "Color Text")
    local selectedLabel = createInstance("TextLabel", {
        Text = defaultText, Size = UDim2.new(0.5, -25, 1, 0), Position = UDim2.new(0.5, 0, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3
    }, headerBtn)
    applyTheme(selectedLabel, "TextColor3", "Color Dark Text")
    local arrow = createInstance("TextLabel", {
        Text = "▼", Size = UDim2.new(0, 15, 1, 0), Position = UDim2.new(1, -20, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3
    }, headerBtn)
    applyTheme(arrow, "TextColor3", "Color Dark Text")
    local body = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 0, 42),
        BackgroundTransparency = 0, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 10
    }, frame)
    applyTheme(body, "BackgroundColor3", "Color Hub 2")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, body)
    addBorder(body, "Color Stroke", 1)
    return {Frame = frame, Header = headerBtn, SelectedLabel = selectedLabel, Arrow = arrow, Body = body}
end

local SectionMethods = {}

function SectionMethods:addMenu(name)
    local menuName = (name ~= nil) and tostring(name) or "Menu"
    local frame = createInstance("Frame", {
        Name = menuName, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 0.15,
        BorderSizePixel = 0, ClipsDescendants = true
    }, self.Content)
    applyTheme(frame, "BackgroundColor3", "Color Hub 2")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 10)}, frame)
    addBorder(frame, "Color Stroke", 1)
    local gradient = createInstance("UIGradient", {Rotation = 90}, frame)
    local function updateGradient()
        local ct = getCurrentTheme(JustHub.Save.Theme)
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, ct["Color Hub 2"]),
            ColorSequenceKeypoint.new(1, ct["Color Hub 1"])
        })
    end
    updateGradient()
    if not JustHub.ThemeObjects[gradient] then JustHub.ThemeObjects[gradient] = {} end
    JustHub.ThemeObjects[gradient]["Color"] = {ThemeKey = "GradientSpecial", CustomFunc = updateGradient}
    local label = createInstance("TextLabel", {
        Name = "MenuLabel", Text = menuName, Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2
    }, frame)
    applyTheme(label, "TextColor3", "Color Text")
    return frame
end

function SectionMethods:addChromaToggle()
    return self:addToggle({
        Name = "Rainbow Chroma Mode",
        Default = JustHub.ChromaEnabled,
        Callback = function(state) JustHub:ToggleChroma(state) end
    })
end

function SectionMethods:addToggle(options)
    options = options or {}
    local title     = options.Name or "Toggle"
    local default   = options.Default == true
    local callback  = options.Callback or function() end
    local controlId = makeControlId(self._tabName, self._sectionName, title)
    local frame = createInstance("Frame", {
        Name = title .. "Toggle", Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 0.08, BorderSizePixel = 0
    }, self.Content)
    applyTheme(frame, "BackgroundColor3", "Color Hub 2")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, frame)
    addBorder(frame, "Color Stroke", 1)
    local label = createInstance("TextLabel", {
        Size = UDim2.new(0.7, -8, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Text = title,
        Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2
    }, frame)
    applyTheme(label, "TextColor3", "Color Text")
    local switchBg = createInstance("Frame", {
        Size = UDim2.new(0, 44, 0, 22), Position = UDim2.new(1, -54, 0.5, -11), BorderSizePixel = 0, ZIndex = 2
    }, frame)
    applyTheme(switchBg, "BackgroundColor3", default and "Color Theme" or "Color Hub 1")
    registerSurface(switchBg, "Button")
    createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, switchBg)
    addBorder(switchBg, "Color Stroke", 1)
    local circle = createInstance("Frame", {
        Size = UDim2.new(0, 18, 0, 18), BorderSizePixel = 0, ZIndex = 3,
        Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    }, switchBg)
    applyTheme(circle, "BackgroundColor3", "Color Text")
    createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, circle)
    if default then registerChroma(switchBg, "BackgroundColor3", "Color Theme") end
    local hitButton = createInstance("TextButton", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 5}, frame)
    local function updateVisuals(isActive)
        tweenProperty(circle, {Position = isActive and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}, JustHub.DesignTokens.Animation.ToggleTransition)
        local ct = getCurrentTheme(JustHub.Save.Theme)
        if isActive then
            tweenProperty(switchBg, {BackgroundColor3 = ct["Color Theme"]}, JustHub.DesignTokens.Animation.ToggleTransition)
            registerChroma(switchBg, "BackgroundColor3", "Color Theme")
            JustHub:UpdateThemeObject(switchBg, "BackgroundColor3", "Color Theme")
        else
            tweenProperty(switchBg, {BackgroundColor3 = ct["Color Hub 1"]}, JustHub.DesignTokens.Animation.ToggleTransition)
            JustHub:UnregisterChroma(switchBg, "BackgroundColor3")
            JustHub:UpdateThemeObject(switchBg, "BackgroundColor3", "Color Hub 1")
        end
    end
    local ctrl = createControl({
        id = controlId, shortName = title, default = default,
        callback = callback, updateVisuals = updateVisuals,
        validate = function(v) return type(v) == "boolean", "Toggle value must be boolean" end
    })
    addConnection(hitButton.Activated:Connect(function() ctrl.setValue(not ctrl.getValue()) end))
    JustHub:RegisterControl(controlId, function(v) ctrl.setValue(v) end, {getValue = ctrl.getValue, shortName = title, defaultValue = default, tab = self._tabName, section = self._sectionName})
    task.defer(function() if isAlive() then pcall(callback, default) end end)
    return frame
end

function SectionMethods:addSlider(options)
    options = options or {}
    local title    = options.Name or "Slider"
    local minVal   = tonumber(options.Min) or 0
    local maxVal   = tonumber(options.Max) or 100
    local step     = tonumber(options.Step or options.Float) or 1
    local default  = tonumber(options.Default) or minVal
    local callback = options.Callback or function() end
    if maxVal <= minVal then maxVal = minVal + 1 end
    if step <= 0 then step = 1 end
    default = math.clamp(default, minVal, maxVal)
    local controlId = makeControlId(self._tabName, self._sectionName, title)
    local function decimalPlaces(value)
        local formatted = string.format("%.10f", value):gsub("0+$", ""):gsub("%.$", "")
        local dot = formatted:find("%.")
        return dot and (#formatted - dot) or 0
    end
    local precision = math.max(decimalPlaces(minVal), decimalPlaces(maxVal), decimalPlaces(step))
    local function formatVal(v)
        if precision == 0 then return tostring(math.floor(v + 0.5)) end
        return string.format("%." .. precision .. "f", v)
    end
    local function snapVal(exact)
        exact = math.clamp(exact, minVal, maxVal)
        if exact >= maxVal then return tonumber(string.format("%." .. precision .. "f", maxVal)) end
        local increments = math.floor(((exact - minVal) / step) + 0.5)
        local value = math.clamp(minVal + increments * step, minVal, maxVal)
        return tonumber(string.format("%." .. precision .. "f", value))
    end
    default = snapVal(default)
    local frame = createInstance("Frame", {
        Name = title .. "Slider", Size = UDim2.new(1, 0, 0, 48),
        BackgroundTransparency = 0.08, BorderSizePixel = 0
    }, self.Content)
    applyTheme(frame, "BackgroundColor3", "Color Hub 2")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, frame)
    addBorder(frame, "Color Stroke", 1)
    local label = createInstance("TextLabel", {
        Text = title, Size = UDim2.new(0.5, -10, 0, 20), Position = UDim2.new(0, 10, 0, 4),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left
    }, frame)
    applyTheme(label, "TextColor3", "Color Text")
    local valBox = createInstance("TextBox", {
        Size = UDim2.new(0, 48, 0, 20), Position = UDim2.new(1, -58, 0, 4), Text = formatVal(default),
        Font = Enum.Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false, TextWrapped = true
    }, frame)
    applyTheme(valBox, "BackgroundColor3", "Color Hub 1")
    applyTheme(valBox, "TextColor3", "Color Text")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, valBox)
    addBorder(valBox, "Color Stroke", 1)
    local trackArea = createInstance("TextButton", {
        Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0, 10, 0, 24),
        BackgroundTransparency = 1, Text = "", ZIndex = 5
    }, frame)
    local track = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5)
    }, trackArea)
    applyTheme(track, "BackgroundColor3", "Color Hub 1")
    registerSurface(track, "Button")
    createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, track)
    local ratio = math.clamp((default - minVal) / (maxVal - minVal), 0, 1)
    local fill = createInstance("Frame", {Size = UDim2.new(ratio, 0, 1, 0)}, track)
    applyTheme(fill, "BackgroundColor3", "Color Theme")
    createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)
    registerChroma(fill, "BackgroundColor3", "Color Theme")
    local handle = createInstance("Frame", {
        Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(1, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5)
    }, fill)
    applyTheme(handle, "BackgroundColor3", "Color Text")
    createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, handle)
    local function updateVisuals(val)
        valBox.Text = formatVal(val)
        local r = math.clamp((val - minVal) / (maxVal - minVal), 0, 1)
        tweenProperty(fill, {Size = UDim2.new(r, 0, 1, 0)}, 0.1)
    end
    local ctrl = createControl({
        id = controlId, shortName = title, default = default, callback = callback, updateVisuals = updateVisuals,
        validate = function(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
            and v >= minVal and v <= maxVal, "Slider value must be a finite number within its range" end
    })
    local function pickFromInput(input)
        local x = math.clamp((input.Position.X - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        return snapVal(minVal + x * (maxVal - minVal))
    end
    local activeDragInput = nil
    addConnection(trackArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            activeDragInput = input
            ctrl.beginEdit()
            tweenProperty(handle, {Size = UDim2.new(0, 20, 0, 20)}, 0.15)
            ctrl.setValueLive(pickFromInput(input))
            local dragConn, endConn, focusLostConn
            local function endDrag()
                tweenProperty(handle, {Size = UDim2.new(0, 16, 0, 16)}, 0.15)
                ctrl.endEdit()
                if dragConn then dragConn:Disconnect(); removeConnection(dragConn); dragConn = nil end
                if endConn then endConn:Disconnect(); removeConnection(endConn); endConn = nil end
                if focusLostConn then focusLostConn:Disconnect(); removeConnection(focusLostConn); focusLostConn = nil end
                activeDragInput = nil
            end
            dragConn = addConnection(UserInputService.InputChanged:Connect(function(input2)
                if not isAlive() or not activeDragInput then return end
                local isMatchingMouse = activeDragInput.UserInputType == Enum.UserInputType.MouseButton1
                    and input2.UserInputType == Enum.UserInputType.MouseMovement
                local isMatchingTouch = activeDragInput.UserInputType == Enum.UserInputType.Touch
                    and input2 == activeDragInput
                if isMatchingMouse or isMatchingTouch then
                    ctrl.setValueLive(pickFromInput(input2))
                end
            end))
            endConn = addConnection(UserInputService.InputEnded:Connect(function(input3)
                local isMatchingMouse = activeDragInput
                    and activeDragInput.UserInputType == Enum.UserInputType.MouseButton1
                    and input3.UserInputType == Enum.UserInputType.MouseButton1
                if activeDragInput and (input3 == activeDragInput or isMatchingMouse) then
                    endDrag()
                end
            end))
            focusLostConn = addConnection(UserInputService.WindowFocusReleased:Connect(function()
                endDrag()
            end))
        end
    end))
    addConnection(valBox.FocusLost:Connect(function()
        local num = tonumber(valBox.Text)
        if num then ctrl.setValue(snapVal(num)) else valBox.Text = formatVal(ctrl.getValue()) end
    end))
    JustHub:RegisterControl(controlId, function(v) ctrl.setValue(v) end, {getValue = ctrl.getValue, shortName = title, defaultValue = default, tab = self._tabName, section = self._sectionName})
    task.defer(function() if isAlive() then pcall(callback, default) end end)
    return frame
end

function SectionMethods:addLabel(options)
    options = type(options) == "string" and {Text = options} or options or {}
    local txt = tostring(options.Text or options.Name or "Label")
    local align = options.Align or "Left"
    local frame = createInstance("Frame", {Name = txt, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1}, self.Content)
    local labelObj = createInstance("TextLabel", {
        Name = "LabelText", Text = txt, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium, TextSize = 13, TextWrapped = true,
        TextXAlignment = (align == "Center" and Enum.TextXAlignment.Center)
                     or (align == "Right" and Enum.TextXAlignment.Right)
                     or Enum.TextXAlignment.Left
    }, frame)
    applyTheme(labelObj, "TextColor3", "Color Text")
    if align == "Left" then
        createInstance("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10)}, labelObj)
    end
    return {SetText = function(self, newText) labelObj.Text = newText end}
end

function SectionMethods:addTextBox(options)
    options = options or {}
    local title    = options.Name or "TextBox"
    local default  = type(options.Default) == "string" and options.Default or ""
    local callback = options.Callback or function() end
    local controlId = makeControlId(self._tabName, self._sectionName, title)
    local frame = createInstance("Frame", {
        Name = title .. "TextBox", Size = UDim2.new(1, 0, 0, 44),
        BackgroundTransparency = 0.08, BorderSizePixel = 0, Active = false
    }, self.Content)
    applyTheme(frame, "BackgroundColor3", "Color Hub 2")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, frame)
    addBorder(frame, "Color Stroke", 1)
    local label = createInstance("TextLabel", {
        Text = title, Size = UDim2.new(0.4, -10, 1, 0), Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left
    }, frame)
    applyTheme(label, "TextColor3", "Color Text")
    local inputBox = createInstance("TextBox", {
        Name = "Input",
        Text = default,
        Size = UDim2.new(0.6, -14, 0, 32),
        Position = UDim2.new(0.4, 7, 0.5, -16),
        Font = Enum.Font.Gotham, TextSize = 13,
        ClearTextOnFocus = false, TextEditable = true,
        Active = true, Selectable = true, ZIndex = 5,
        PlaceholderText = "Input here...", TextWrapped = false,
        TextXAlignment = Enum.TextXAlignment.Left
    }, frame)
    applyTheme(inputBox, "BackgroundColor3", "Color Hub 1")
    applyTheme(inputBox, "TextColor3", "Color Text")
    applyTheme(inputBox, "PlaceholderColor3", "Color Dark Text")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, inputBox)
    createInstance("UIPadding", {
        PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 7)
    }, inputBox)
    addBorder(inputBox, "Color Stroke", 1)
    addConnection(inputBox.Focused:Connect(function() tweenProperty(inputBox, {BackgroundColor3 = getCurrentTheme(JustHub.Save.Theme)["Color Hub 2"]}, 0.2) end))
    addConnection(inputBox.FocusLost:Connect(function() tweenProperty(inputBox, {BackgroundColor3 = getCurrentTheme(JustHub.Save.Theme)["Color Hub 1"]}, 0.2) end))
    local ctrl = createControl({
        id = controlId, shortName = title, default = default, callback = callback,
        updateVisuals = function(v) if inputBox.Text ~= v then inputBox.Text = v end end,
        validate = function(v) return type(v) == "string", "TextBox value must be a string" end
    })
    addConnection(inputBox.FocusLost:Connect(function() ctrl.setValue(inputBox.Text) end))
    JustHub:RegisterControl(controlId, function(v) ctrl.setValue(v) end, {getValue = ctrl.getValue, shortName = title, defaultValue = default, tab = self._tabName, section = self._sectionName})
    return frame
end

function SectionMethods:addDropdown(options)
    options = options or {}
    local title    = options.Name or "Dropdown"
    local default  = type(options.Default) == "string" and options.Default or ""
    local presets  = normalizeStringArray(options.Presets)
    local callback = options.Callback or function() end
    local controlId = makeControlId(self._tabName, self._sectionName, title)
    local scaffold = createDropdownScaffolding(self.Content, title, default ~= "" and default or "Select...")
    local frame, headerBtn, selectedLabel, arrow, body = scaffold.Frame, scaffold.Header, scaffold.SelectedLabel, scaffold.Arrow, scaffold.Body
    local searchBox = createInstance("TextBox", {
        Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, 5),
        Font = Enum.Font.Gotham, TextSize = 12, PlaceholderText = "Search...",
        ClearTextOnFocus = false, ZIndex = 12
    }, body)
    applyTheme(searchBox, "BackgroundColor3", "Color Hub 1")
    applyTheme(searchBox, "TextColor3", "Color Text")
    applyTheme(searchBox, "PlaceholderColor3", "Color Dark Text")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, searchBox)
    addBorder(searchBox, "Color Stroke", 1)
    local scroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -36), Position = UDim2.new(0, 10, 0, 36),
        BackgroundTransparency = 1, ScrollBarThickness = 2, BorderSizePixel = 0,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 11
    }, body)
    applyTheme(scroll, "ScrollBarImageColor3", "Color Stroke")
    createInstance("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, scroll)
    local isOpen = false
    local itemCache, itemConnections = {}, {}
    local ctrl
    local function closeDropdown()
        isOpen = false; frame.ZIndex = 1
        tweenProperty(frame, {Size = UDim2.new(1, 0, 0, 42)}, JustHub.DesignTokens.Animation.PopupTransition)
        tweenProperty(body, {Size = UDim2.new(1, 0, 0, 0)}, JustHub.DesignTokens.Animation.PopupTransition)
        tweenProperty(arrow, {Rotation = 0}, JustHub.DesignTokens.Animation.PopupTransition)
        searchBox.Text = ""
    end
    local function clearItems()
        for _, conn in ipairs(itemConnections) do pcall(function() conn:Disconnect() end) end
        table.clear(itemConnections)
        for _, btn in ipairs(scroll:GetChildren()) do
            if btn:IsA("TextButton") then btn:Destroy() end
        end
        table.clear(itemCache)
    end
    local function createItem(data)
        local btn = createInstance("TextButton", {
            Name = data.Name, Size = UDim2.new(1, 0, 0, 32),
            Text = "  " .. data.Name, Font = Enum.Font.Gotham, TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, ZIndex = 12
        }, scroll)
        applyTheme(btn, "BackgroundColor3", "Color Hub 1")
        applyTheme(btn, "TextColor3", data.IsPreset and "Color Theme" or "Color Text")
        createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, btn)
        if data.IsPreset then registerChroma(btn, "TextColor3", "Color Theme") end
        table.insert(itemConnections, btn.MouseEnter:Connect(function() tweenProperty(btn, {BackgroundColor3 = getCurrentTheme(JustHub.Save.Theme)["Color Stroke"]}, 0.15) end))
        table.insert(itemConnections, btn.MouseLeave:Connect(function() tweenProperty(btn, {BackgroundColor3 = getCurrentTheme(JustHub.Save.Theme)["Color Hub 1"]}, 0.15) end))
        table.insert(itemConnections, btn.Activated:Connect(function()
            selectedLabel.Text = data.Name
            ctrl.setValue(data.Value)
            closeDropdown()
        end))
        table.insert(itemCache, {Name = data.Name, Value = data.Value, Button = btn, IsPreset = data.IsPreset})
    end
    local function populateCache(newList)
        clearItems()
        for _, p in ipairs(presets) do createItem({Name = "★ " .. p, Value = p, IsPreset = true}) end
        for _, i in ipairs(normalizeStringArray(newList)) do createItem({Name = i, Value = i, IsPreset = false}) end
    end
    local function renderItems(filterText)
        local lower = filterText and filterText:lower() or ""
        for _, item in ipairs(itemCache) do item.Button.Visible = (lower == "" or string.find(item.Name:lower(), lower, 1, true) ~= nil) end
    end
    local function getDisplayName(value)
        for _, item in ipairs(itemCache) do
            if item.Value == value then return item.Name end
        end
        return tostring(value)
    end
    ctrl = createControl({
        id = controlId, shortName = title, default = default, callback = callback,
        updateVisuals = function(v)
            if v ~= nil and v ~= "" then selectedLabel.Text = getDisplayName(v) end
        end,
        validate = function(v) return type(v) == "string", "Dropdown value must be a string" end
    })
    populateCache(options.Items or {})
    if default ~= "" then selectedLabel.Text = getDisplayName(default) end
    addConnection(searchBox:GetPropertyChangedSignal("Text"):Connect(function() renderItems(searchBox.Text) end))
    addConnection(headerBtn.Activated:Connect(function()
        isOpen = not isOpen
        if isOpen then
            frame.ZIndex = 50
            tweenProperty(frame, {Size = UDim2.new(1, 0, 0, 192)}, JustHub.DesignTokens.Animation.PopupTransition)
            tweenProperty(body, {Size = UDim2.new(1, 0, 0, 150)}, JustHub.DesignTokens.Animation.PopupTransition)
            tweenProperty(arrow, {Rotation = 180}, JustHub.DesignTokens.Animation.PopupTransition)
            searchBox.Text = ""
            renderItems()
        else closeDropdown() end
    end))
    JustHub:RegisterControl(controlId, function(v) ctrl.setValue(v) end, {getValue = ctrl.getValue, shortName = title, defaultValue = default, tab = self._tabName, section = self._sectionName})
    return {Refresh = function(self, newList) populateCache(newList); renderItems(searchBox.Text) end, Clear = function(self) clearItems(); selectedLabel.Text = "Select..."; ctrl.setValue(""); closeDropdown() end, GetValue = function() return ctrl.getValue() end}
end

function SectionMethods:addMultiDropdown(options)
    options = options or {}
    local title    = options.Name or "Multi Dropdown"
    local default  = normalizeStringArray(options.Default)
    local presets  = normalizeStringArray(options.Presets)
    local callback = options.Callback or function() end
    local controlId = makeControlId(self._tabName, self._sectionName, title)
    local defaultLabel = #default > 0 and table.concat(default, ", ") or "Select..."
    local scaffold = createDropdownScaffolding(self.Content, title, defaultLabel)
    local frame, headerBtn, selectedLabel, arrow, body = scaffold.Frame, scaffold.Header, scaffold.SelectedLabel, scaffold.Arrow, scaffold.Body
    local controlBar = createInstance("Frame", {
        Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0, 10, 0, 5), BackgroundTransparency = 1, ZIndex = 12
    }, body)
    createInstance("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}, controlBar)
    local selectAllBtn = createInstance("TextButton", {Text = "Select All", Size = UDim2.new(0, 70, 1, 0), Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, ZIndex = 12}, controlBar)
    applyTheme(selectAllBtn, "BackgroundColor3", "Color Theme"); applyTheme(selectAllBtn, "TextColor3", "Color Text")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, selectAllBtn)
    registerChroma(selectAllBtn, "BackgroundColor3", "Color Theme")
    local clearAllBtn = createInstance("TextButton", {Text = "Clear All", Size = UDim2.new(0, 70, 1, 0), Font = Enum.Font.GothamBold, TextSize = 11, AutoButtonColor = false, ZIndex = 12}, controlBar)
    applyTheme(clearAllBtn, "BackgroundColor3", "Color Hub 1"); applyTheme(clearAllBtn, "TextColor3", "Color Text")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, clearAllBtn); addBorder(clearAllBtn, "Color Stroke", 1)
    local searchBox = createInstance("TextBox", {
        Size = UDim2.new(1, -148, 1, 0), Font = Enum.Font.Gotham, TextSize = 12, PlaceholderText = "Search...", ClearTextOnFocus = false, ZIndex = 12
    }, controlBar)
    applyTheme(searchBox, "BackgroundColor3", "Color Hub 1"); applyTheme(searchBox, "TextColor3", "Color Text"); applyTheme(searchBox, "PlaceholderColor3", "Color Dark Text")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, searchBox); addBorder(searchBox, "Color Stroke", 1)
    local scroll = createInstance("ScrollingFrame", {
        Size = UDim2.new(1, -20, 1, -34), Position = UDim2.new(0, 10, 0, 34), BackgroundTransparency = 1, ScrollBarThickness = 2, BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), ZIndex = 11
    }, body)
    applyTheme(scroll, "ScrollBarImageColor3", "Color Stroke")
    createInstance("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, scroll)
    local isOpen = false
    local activeItems = {}
    for _, v in ipairs(default) do activeItems[v] = true end
    local itemCache, itemConnections = {}, {}
    local suppressCallback = false
    local ctrl
    local function computeSelection()
        local sel = {}
        for k, v in pairs(activeItems) do if v then table.insert(sel, k) end end
        table.sort(sel); return sel
    end
    local function closeDropdown()
        isOpen = false; frame.ZIndex = 1
        tweenProperty(frame, {Size = UDim2.new(1, 0, 0, 42)}, JustHub.DesignTokens.Animation.PopupTransition)
        tweenProperty(body, {Size = UDim2.new(1, 0, 0, 0)}, JustHub.DesignTokens.Animation.PopupTransition)
        tweenProperty(arrow, {Rotation = 0}, JustHub.DesignTokens.Animation.PopupTransition)
        searchBox.Text = ""
    end
    local function clearItems()
        for _, conn in ipairs(itemConnections) do pcall(function() conn:Disconnect() end) end
        table.clear(itemConnections)
        for _, btn in ipairs(scroll:GetChildren()) do if btn:IsA("TextButton") then btn:Destroy() end end
        table.clear(itemCache)
    end
    local function renderItems(filterText)
        local lower = filterText and filterText:lower() or ""
        local t = getCurrentTheme(JustHub.Save.Theme)
        for _, item in ipairs(itemCache) do
            local match = (lower == "" or string.find(item.Name:lower(), lower, 1, true) ~= nil)
            item.Button.Visible = match
            if match then
                local isActive = activeItems[item.RawName]
                item.Check.BackgroundColor3 = isActive and t["Color Theme"] or t["Color Hub 2"]
                if isActive then
                    registerChroma(item.Check, "BackgroundColor3", "Color Theme")
                    JustHub:UpdateThemeObject(item.Check, "BackgroundColor3", "Color Theme")
                else
                    JustHub:UnregisterChroma(item.Check, "BackgroundColor3")
                    JustHub:UpdateThemeObject(item.Check, "BackgroundColor3", "Color Hub 2")
                end
            end
        end
    end
    local function createItem(data)
        local btn = createInstance("TextButton", {Name = data.Name, Size = UDim2.new(1, 0, 0, 32), Text = "      " .. data.Name, Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, AutoButtonColor = false, ZIndex = 12}, scroll)
        applyTheme(btn, "BackgroundColor3", "Color Hub 1"); applyTheme(btn, "TextColor3", data.IsPreset and "Color Theme" or "Color Text")
        createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, btn)
        if data.IsPreset then registerChroma(btn, "TextColor3", "Color Theme") end
        local check = createInstance("Frame", {Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 6, 0.5, -8), BorderSizePixel = 0, ZIndex = 12}, btn)
        createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, check); addBorder(check, "Color Stroke", 1)
        table.insert(itemConnections, btn.MouseEnter:Connect(function() tweenProperty(btn, {BackgroundColor3 = getCurrentTheme(JustHub.Save.Theme)["Color Stroke"]}, 0.15) end))
        table.insert(itemConnections, btn.MouseLeave:Connect(function() tweenProperty(btn, {BackgroundColor3 = getCurrentTheme(JustHub.Save.Theme)["Color Hub 1"]}, 0.15) end))
        table.insert(itemConnections, btn.Activated:Connect(function()
            activeItems[data.RawName] = not activeItems[data.RawName]
            local sel = computeSelection()
            selectedLabel.Text = #sel > 0 and table.concat(sel, ", ") or "Select..."
            renderItems(searchBox.Text)
            ctrl.setValue(sel)
        end))
        table.insert(itemCache, {Name = data.Name, RawName = data.RawName, Button = btn, Check = check, IsPreset = data.IsPreset})
    end
    local function populateCache(newList)
        clearItems()
        for _, p in ipairs(presets) do createItem({Name = "★ " .. p, RawName = p, IsPreset = true}) end
        for _, i in ipairs(normalizeStringArray(newList)) do createItem({Name = i, RawName = i, IsPreset = false}) end
    end
    ctrl = createControl({
        id = controlId, shortName = title, default = default, callback = callback,
        updateVisuals = function(v)
            if suppressCallback then return end
            table.clear(activeItems)
            for _, item in ipairs(v) do activeItems[item] = true end
            local sel = computeSelection()
            selectedLabel.Text = #sel > 0 and table.concat(sel, ", ") or "Select..."
            renderItems(searchBox.Text)
        end,
        validate = function(v)
            if type(v) ~= "table" then return false, "MultiDropdown value must be an array" end
            local count, maxIndex = 0, 0
            for key, item in pairs(v) do
                if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or type(item) ~= "string" then
                    return false, "MultiDropdown values must be an array of strings"
                end
                count = count + 1
                if key > maxIndex then maxIndex = key end
            end
            return count == maxIndex and count == #v, "MultiDropdown values must be a dense array"
        end
    })
    populateCache(options.Items or {})
    addConnection(searchBox:GetPropertyChangedSignal("Text"):Connect(function() renderItems(searchBox.Text) end))
    addConnection(selectAllBtn.Activated:Connect(function()
        suppressCallback = true
        for _, item in ipairs(itemCache) do activeItems[item.RawName] = true end
        suppressCallback = false
        local sel = computeSelection()
        selectedLabel.Text = #sel > 0 and table.concat(sel, ", ") or "Select..."
        renderItems(searchBox.Text)
        ctrl.setValue(sel)
    end))
    addConnection(clearAllBtn.Activated:Connect(function()
        suppressCallback = true
        table.clear(activeItems)
        suppressCallback = false
        selectedLabel.Text = "Select..."
        renderItems(searchBox.Text)
        ctrl.setValue({})
    end))
    addConnection(headerBtn.Activated:Connect(function()
        isOpen = not isOpen
        if isOpen then
            frame.ZIndex = 50
            tweenProperty(frame, {Size = UDim2.new(1, 0, 0, 192)}, JustHub.DesignTokens.Animation.PopupTransition)
            tweenProperty(body, {Size = UDim2.new(1, 0, 0, 150)}, JustHub.DesignTokens.Animation.PopupTransition)
            tweenProperty(arrow, {Rotation = 180}, JustHub.DesignTokens.Animation.PopupTransition)
            searchBox.Text = ""; renderItems()
        else closeDropdown() end
    end))
    JustHub:RegisterControl(controlId, function(v) ctrl.setValue(v) end, {getValue = ctrl.getValue, shortName = title, defaultValue = default, tab = self._tabName, section = self._sectionName})
    return {Refresh = function(self, newList) populateCache(newList); renderItems(searchBox.Text) end, GetValue = function() return ctrl.getValue() end}
end

function SectionMethods:addColorPicker(options)
    options = options or {}
    local title    = options.Name or "ColorPicker"
    local default  = typeof(options.Default) == "Color3" and options.Default or Color3.fromRGB(255, 255, 255)
    local callback = options.Callback or function() end
    local controlId = makeControlId(self._tabName, self._sectionName, title)
    local frame = createInstance("Frame", {Name = title .. "ColorPicker", Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 0.08, BorderSizePixel = 0}, self.Content)
    applyTheme(frame, "BackgroundColor3", "Color Hub 2")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, frame); addBorder(frame, "Color Stroke", 1)
    local label = createInstance("TextLabel", {Text = title, Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0, 10, 0, 2), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left}, frame)
    applyTheme(label, "TextColor3", "Color Text")
    local preview = createInstance("Frame", {Size = UDim2.new(0, 44, 0, 22), Position = UDim2.new(1, -54, 0, 4), BackgroundColor3 = default, BorderSizePixel = 0}, frame)
    createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, preview); addBorder(preview, "Color Stroke", 1)
    local presetColors = {Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 255, 0), Color3.fromRGB(0, 0, 255), Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255), Color3.fromRGB(0, 255, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 0, 0)}
    local presetFrame = createInstance("Frame", {Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0, 10, 0, 30), BackgroundTransparency = 1}, frame)
    createInstance("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}, presetFrame)
    local inputFrame = createInstance("Frame", {Size = UDim2.new(1, -20, 0, 24), Position = UDim2.new(0, 10, 0, 58), BackgroundTransparency = 1}, frame)
    createInstance("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4)}, inputFrame)
    local rBox = createInstance("TextBox", {Text = tostring(math.floor(default.R * 255)), Size = UDim2.new(0, 40, 1, 0), TextColor3 = Color3.fromRGB(255, 100, 100), Font = Enum.Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false}, inputFrame)
    local gBox = createInstance("TextBox", {Text = tostring(math.floor(default.G * 255)), Size = UDim2.new(0, 40, 1, 0), TextColor3 = Color3.fromRGB(100, 255, 100), Font = Enum.Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false}, inputFrame)
    local bBox = createInstance("TextBox", {Text = tostring(math.floor(default.B * 255)), Size = UDim2.new(0, 40, 1, 0), TextColor3 = Color3.fromRGB(100, 150, 255), Font = Enum.Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false}, inputFrame)
    local hexBox = createInstance("TextBox", {Text = "#" .. default:ToHex():upper(), Size = UDim2.new(0, 60, 1, 0), Font = Enum.Font.GothamMedium, TextSize = 12, ClearTextOnFocus = false}, inputFrame)
    applyTheme(hexBox, "TextColor3", "Color Text")
    for _, box in ipairs({rBox, gBox, bBox, hexBox}) do
        applyTheme(box, "BackgroundColor3", "Color Hub 1")
        createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, box); addBorder(box, "Color Stroke", 1)
    end
    local function syncBoxes(c3)
        preview.BackgroundColor3 = c3
        rBox.Text = tostring(math.floor(c3.R * 255 + 0.5))
        gBox.Text = tostring(math.floor(c3.G * 255 + 0.5))
        bBox.Text = tostring(math.floor(c3.B * 255 + 0.5))
        hexBox.Text = "#" .. c3:ToHex():upper()
    end
    local ctrl = createControl({
        id = controlId, shortName = title, default = default, callback = callback,
        updateVisuals = function(v) syncBoxes(v) end,
        validate = function(v) return typeof(v) == "Color3", "ColorPicker value must be Color3" end
    })
    for _, c in ipairs(presetColors) do
        local btn = createInstance("TextButton", {Size = UDim2.new(0, 24, 0, 24), BackgroundColor3 = c, Text = "", AutoButtonColor = false, BorderSizePixel = 0}, presetFrame)
        createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, btn)
        addConnection(btn.Activated:Connect(function() ctrl.setValue(c) end))
    end
    local function updateColorRGB()
        local rr = math.clamp(tonumber(rBox.Text) or 0, 0, 255); local gg = math.clamp(tonumber(gBox.Text) or 0, 0, 255); local bb = math.clamp(tonumber(bBox.Text) or 0, 0, 255)
        local c3 = Color3.fromRGB(rr, gg, bb)
        if c3 ~= ctrl.getValue() then ctrl.setValue(c3) else syncBoxes(c3) end
    end
    local function updateColorHex()
        local hx = hexBox.Text:gsub("#", "")
        local ok, c3 = pcall(function() return Color3.fromHex(hx) end)
        if ok and c3 then
            if c3 ~= ctrl.getValue() then ctrl.setValue(c3) else syncBoxes(c3) end
        else
            hexBox.Text = "#" .. ctrl.getValue():ToHex():upper()
        end
    end
    addConnection(rBox.FocusLost:Connect(updateColorRGB)); addConnection(gBox.FocusLost:Connect(updateColorRGB)); addConnection(bBox.FocusLost:Connect(updateColorRGB)); addConnection(hexBox.FocusLost:Connect(updateColorHex))
    JustHub:RegisterControl(controlId, function(v) ctrl.setValue(v) end, {getValue = ctrl.getValue, shortName = title, defaultValue = default, tab = self._tabName, section = self._sectionName})
    return frame
end

function SectionMethods:addScriptBox(options)
    options = options or {}
    local title    = options.Name or "ScriptBox"
    local default  = type(options.Default) == "string" and options.Default or ""
    local callback = options.Callback or function() end
    local controlId = makeControlId(self._tabName, self._sectionName, title)
    local frame = createInstance("Frame", {Name = title .. "ScriptBox", Size = UDim2.new(1, 0, 0, 96), BackgroundTransparency = 0.08, BorderSizePixel = 0}, self.Content)
    applyTheme(frame, "BackgroundColor3", "Color Hub 2"); createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, frame); addBorder(frame, "Color Stroke", 1)
    local label = createInstance("TextLabel", {Text = title, Size = UDim2.new(1, -10, 0, 20), Position = UDim2.new(0, 10, 0, 4), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left}, frame)
    applyTheme(label, "TextColor3", "Color Text")
    local inputBox = createInstance("TextBox", {Text = default, Size = UDim2.new(1, -80, 0, 56), Position = UDim2.new(0, 10, 0, 30), Font = Enum.Font.Code, TextSize = 13, ClearTextOnFocus = false, MultiLine = true, TextWrapped = true, PlaceholderText = "Paste script here...", TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top}, frame)
    applyTheme(inputBox, "BackgroundColor3", "Color Hub 1"); applyTheme(inputBox, "TextColor3", "Color Text"); createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, inputBox); addBorder(inputBox, "Color Stroke", 1)
    local runBtn = createInstance("TextButton", {Text = "Run", Size = UDim2.new(0, 50, 0, 34), Position = UDim2.new(1, -60, 0, 40), TextColor3 = Color3.fromRGB(20, 20, 20), Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = false}, frame)
    applyTheme(runBtn, "BackgroundColor3", "Color Theme"); createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, runBtn); registerChroma(runBtn, "BackgroundColor3", "Color Theme")
    addConnection(runBtn.MouseEnter:Connect(function()
        tweenProperty(runBtn, {BackgroundTransparency = math.max(0, surfaceTransparency("Button") - 0.12)}, JustHub.DesignTokens.Animation.Hover)
    end))
    addConnection(runBtn.MouseLeave:Connect(function()
        tweenProperty(runBtn, {BackgroundTransparency = surfaceTransparency("Button")}, JustHub.DesignTokens.Animation.Hover)
    end))
    addConnection(runBtn.Activated:Connect(function()
        task.spawn(function()
            local ok, err = pcall(callback, inputBox.Text)
            if not ok then warn("[JustHub] ScriptBox run error: " .. tostring(err)) end
        end)
    end))
    local ctrl = createControl({
        id = controlId, shortName = title, default = default, callback = function() end,
        updateVisuals = function(v) if inputBox.Text ~= v then inputBox.Text = v end end,
        validate = function(v) return type(v) == "string", "ScriptBox value must be a string" end
    })
    JustHub:RegisterControl(controlId, function(v) ctrl.setValue(v) end, {getValue = ctrl.getValue, shortName = title, defaultValue = default, tab = self._tabName, section = self._sectionName})
    return frame
end

function SectionMethods:addBind(options)
    options = options or {}
    local title    = options.Name or "KeyBind"
    local default  = options.Default or "RightShift"
    if typeof(default) == "EnumItem" and default.EnumType == Enum.KeyCode then
        default = default.Name
    elseif type(default) ~= "string" then
        default = "RightShift"
    end
    local callback = options.Callback or function() end
    local controlId = makeControlId(self._tabName, self._sectionName, title)
    local blacklist = {
        [Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
        [Enum.KeyCode.Space] = true, [Enum.KeyCode.Escape] = true, [Enum.KeyCode.Tab] = true,
        [Enum.KeyCode.Backspace] = true, [Enum.KeyCode.Return] = true, [Enum.KeyCode.Unknown] = true
    }
    local frame = createInstance("Frame", {Name = title .. "BindControl", Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 0.08, BorderSizePixel = 0}, self.Content)
    applyTheme(frame, "BackgroundColor3", "Color Hub 2"); createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, frame); addBorder(frame, "Color Stroke", 1)
    local label = createInstance("TextLabel", {Text = title, Size = UDim2.new(0.6, -10, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left}, frame)
    applyTheme(label, "TextColor3", "Color Text")
    local inputBox = createInstance("TextBox", {Text = default, Size = UDim2.new(0.4, -20, 0, 30), Position = UDim2.new(0.6, 10, 0.5, -15), Font = Enum.Font.GothamBold, TextSize = 12, ClearTextOnFocus = false}, frame)
    applyTheme(inputBox, "BackgroundColor3", "Color Hub 1"); applyTheme(inputBox, "TextColor3", "Color Text"); createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, inputBox); addBorder(inputBox, "Color Stroke", 1)
    local triggerConn = nil
    local waitConn, focusLostConn = nil, nil
    local ctrl
    local function disconnectTrigger()
        if triggerConn then
            triggerConn:Disconnect()
            removeConnection(triggerConn)
            triggerConn = nil
        end
    end
    local function applyKeyName(keyName)
        disconnectTrigger()
        local keyEnum = type(keyName) == "string" and Enum.KeyCode[keyName] or nil
        if not keyEnum or blacklist[keyEnum] then
            inputBox.Text = "None"
            if ctrl.getValue() ~= "None" then ctrl.setValue("None") end
            return "None"
        end
        triggerConn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == keyEnum then
                task.spawn(function()
                    local ok, err = pcall(callback)
                    if not ok then warn("[JustHub] Bind callback error [" .. controlId .. "]: " .. tostring(err)) end
                end)
            end
        end)
        addConnection(triggerConn)
        inputBox.Text = keyEnum.Name
        if ctrl.getValue() ~= keyEnum.Name then ctrl.setValue(keyEnum.Name) end
        return keyEnum.Name
    end
    ctrl = createControl({
        id = controlId, shortName = title, default = default, callback = function() end, updateVisuals = function() end,
        validate = function(v) return type(v) == "string", "Keybind value must be a key name string" end
    })
    local wasApplyingConfig = JustHub._isApplyingConfig
    JustHub._isApplyingConfig = true
    local matched = false
    for _, kEnum in pairs(Enum.KeyCode:GetEnumItems()) do
        if kEnum.Name:lower() == default:lower() then applyKeyName(kEnum.Name); matched = true; break end
    end
    if not matched then applyKeyName(default) end
    JustHub._isApplyingConfig = wasApplyingConfig
    addConnection(inputBox.Focused:Connect(function()
        inputBox.Text = "Press Key..."
        if waitConn then waitConn:Disconnect(); removeConnection(waitConn) end
        if focusLostConn then focusLostConn:Disconnect(); removeConnection(focusLostConn) end
        waitConn = addConnection(UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Keyboard then
                if waitConn then waitConn:Disconnect(); removeConnection(waitConn); waitConn = nil end
                if focusLostConn then focusLostConn:Disconnect(); removeConnection(focusLostConn); focusLostConn = nil end
                local keyName = input.KeyCode.Name
                inputBox:ReleaseFocus()
                if blacklist[input.KeyCode] then
                    inputBox.Text = ctrl.getValue()
                else
                    ctrl.setValue(keyName)
                    applyKeyName(keyName)
                end
            end
        end))
        focusLostConn = addConnection(inputBox.FocusLost:Connect(function()
            if waitConn then waitConn:Disconnect(); removeConnection(waitConn); waitConn = nil end
            if focusLostConn then focusLostConn:Disconnect(); removeConnection(focusLostConn); focusLostConn = nil end
            inputBox.Text = ctrl.getValue()
        end))
    end))
    JustHub:RegisterControl(controlId, function(v) applyKeyName(v) end, {getValue = ctrl.getValue, shortName = title, defaultValue = default, tab = self._tabName, section = self._sectionName})
    return frame
end

function SectionMethods:addButton(options)
    options = options or {}
    local title    = options.Name or "Button"
    local btnText  = options.ButtonText or "Click"
    local callback = options.Callback or function() end
    local frame = createInstance("Frame", {Name = title .. "ButtonControl", Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 0.08, BorderSizePixel = 0}, self.Content)
    applyTheme(frame, "BackgroundColor3", "Color Hub 2"); createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, frame); addBorder(frame, "Color Stroke", 1)
    local label = createInstance("TextLabel", {Text = title, Size = UDim2.new(0.6, -10, 1, 0), Position = UDim2.new(0, 10, 0, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left}, frame)
    applyTheme(label, "TextColor3", "Color Text")
    local btn = createInstance("TextButton", {Text = btnText, Size = UDim2.new(0.4, -20, 0, 30), Position = UDim2.new(0.6, 10, 0.5, -15), Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = false}, frame)
    applyTheme(btn, "BackgroundColor3", "Color Hub 1"); applyTheme(btn, "TextColor3", "Color Text"); createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, btn); addBorder(btn, "Color Stroke", 1)
    local baseSize, basePos = UDim2.new(0.4, -20, 0, 30), UDim2.new(0.6, 10, 0.5, -15)
    local downSize, downPos = UDim2.new(0.4, -24, 0, 26), UDim2.new(0.6, 12, 0.5, -13)
    addConnection(btn.MouseEnter:Connect(function() tweenProperty(btn, {BackgroundColor3 = getCurrentTheme(JustHub.Save.Theme)["Color Stroke"]}, 0.15) end))
    addConnection(btn.MouseLeave:Connect(function() tweenProperty(btn, {BackgroundColor3 = getCurrentTheme(JustHub.Save.Theme)["Color Hub 1"]}, 0.15); tweenProperty(btn, {Size = baseSize, Position = basePos}, 0.1) end))
    addConnection(btn.MouseButton1Down:Connect(function() tweenProperty(btn, {Size = downSize, Position = downPos}, 0.1) end))
    addConnection(btn.Activated:Connect(function()
        tweenProperty(btn, {Size = baseSize, Position = basePos}, 0.1)
        task.spawn(function()
            local ok, err = pcall(callback)
            if not ok then warn("[JustHub] Button callback error [" .. title .. "]: " .. tostring(err)) end
        end)
    end))
    return frame
end

function SectionMethods:addConfigManager()
    local frame = createInstance("Frame", {Name = "ConfigManager", Size = UDim2.new(1, 0, 0, 105), BackgroundTransparency = 0.08, BorderSizePixel = 0}, self.Content)
    applyTheme(frame, "BackgroundColor3", "Color Hub 2"); createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, frame); addBorder(frame, "Color Stroke", 1)
    local inputBox = createInstance("TextBox", {Text = "DefaultConfig", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 10), Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false, PlaceholderText = "Config Name..."}, frame)
    applyTheme(inputBox, "BackgroundColor3", "Color Hub 1"); applyTheme(inputBox, "TextColor3", "Color Text"); createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, inputBox); addBorder(inputBox, "Color Stroke", 1)
    local saveBtn = createInstance("TextButton", {Text = "Save Profile", Size = UDim2.new(0.48, 0, 0, 30), Position = UDim2.new(0, 10, 0, 48), TextColor3 = Color3.fromRGB(20, 20, 20), Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false}, frame)
    applyTheme(saveBtn, "BackgroundColor3", "Color Theme"); createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, saveBtn); registerChroma(saveBtn, "BackgroundColor3", "Color Theme")
    local loadBtn = createInstance("TextButton", {Text = "Load Profile", Size = UDim2.new(0.48, 0, 0, 30), Position = UDim2.new(0.52, -10, 0, 48), Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false}, frame)
    applyTheme(loadBtn, "BackgroundColor3", "Color Hub 1"); applyTheme(loadBtn, "TextColor3", "Color Text"); createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, loadBtn); addBorder(loadBtn, "Color Stroke", 1)
    local deleteBtn = createInstance("TextButton", {Text = "Delete Profile", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.new(0, 10, 0, 82), Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false}, frame)
    applyTheme(deleteBtn, "BackgroundColor3", "Color Stroke"); applyTheme(deleteBtn, "TextColor3", "Color Dark Text"); createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, deleteBtn)
    addConnection(saveBtn.MouseEnter:Connect(function()
        tweenProperty(saveBtn, {BackgroundTransparency = math.max(0, surfaceTransparency("Button") - 0.12)}, JustHub.DesignTokens.Animation.Hover)
    end))
    addConnection(saveBtn.MouseLeave:Connect(function()
        tweenProperty(saveBtn, {BackgroundTransparency = surfaceTransparency("Button")}, JustHub.DesignTokens.Animation.Hover)
    end))
    addConnection(loadBtn.MouseEnter:Connect(function() tweenProperty(loadBtn, {BackgroundColor3 = getCurrentTheme(JustHub.Save.Theme)["Color Stroke"]}, 0.15) end))
    addConnection(loadBtn.MouseLeave:Connect(function() tweenProperty(loadBtn, {BackgroundColor3 = getCurrentTheme(JustHub.Save.Theme)["Color Hub 1"]}, 0.15) end))
    addConnection(deleteBtn.MouseEnter:Connect(function() tweenProperty(deleteBtn, {BackgroundColor3 = Color3.fromRGB(200, 60, 60), TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.15) end))
    addConnection(deleteBtn.MouseLeave:Connect(function() tweenProperty(deleteBtn, {BackgroundColor3 = getCurrentTheme(JustHub.Save.Theme)["Color Stroke"], TextColor3 = getCurrentTheme(JustHub.Save.Theme)["Color Dark Text"]}, 0.15) end))
    addConnection(saveBtn.Activated:Connect(function()
        if inputBox.Text == "" then return end
        local ok, err = JustHub:SaveConfig(inputBox.Text .. ".json")
        if not ok then JustHub:Notify({Title = "Save Config", Message = "Failed: " .. tostring(err), Duration = 4}) end
    end))
    addConnection(loadBtn.Activated:Connect(function()
        if inputBox.Text == "" then return end
        local ok, err = JustHub:LoadConfig(inputBox.Text .. ".json")
        if not ok then JustHub:Notify({Title = "Load Config", Message = "Failed: " .. tostring(err), Duration = 4}) end
    end))
    addConnection(deleteBtn.Activated:Connect(function()
        if inputBox.Text == "" then return end
        local fn = inputBox.Text .. ".json"
        if not isSafeConfigFileName(fn) then JustHub:Notify({Title = "Config Manager", Message = "Invalid filename", Duration = 4}); return end
        if not delfile then JustHub:Notify({Title = "Config Manager", Message = "delfile not supported by executor", Duration = 4}); return end
        local ok, err = pcall(delfile, fn)
        if ok then JustHub:Notify({Title = "Config Manager", Message = "Deleted: " .. fn, Duration = 3})
        else JustHub:Notify({Title = "Config Manager", Message = "Failed: " .. tostring(err), Duration = 4}) end
    end))
    return frame
end

function JustHub:CreateWindow(options)
    if not isAlive() then return nil end
    options = options or {}
    local winName   = options.Name or "JustHub Window"
    local themeName = options.Theme or "Darker"
    local subTitle  = options.SubTitle or "SubTitle"
    local player    = Players.LocalPlayer
    local screenGui = trackScreenGui(createInstance("ScreenGui", {Name = "JustHub", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Global}, targetParent))
    self.ScreenGui = screenGui; JustHub.Save.Theme = themeName
    local initialCamera = workspace.CurrentCamera
    local initialViewport = initialCamera and initialCamera.ViewportSize or Vector2.new(1280, 720)
    local initialWidth = math.max(220, math.min(JustHub.Save.UISize[1], initialViewport.X - 24))
    local initialHeight = math.max(200, math.min(JustHub.Save.UISize[2], initialViewport.Y - 24))
    local mainFrame = createInstance("Frame", {
        Name = "MainFrame", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, initialWidth, 0, initialHeight),
        BackgroundTransparency = JustHub.Save.Transparency, BorderSizePixel = 0, ClipsDescendants = true, Active = true, ZIndex = 1
    }, screenGui)
    applyTheme(mainFrame, "BackgroundColor3", "Color Hub 2"); createInstance("UICorner", {CornerRadius = UDim.new(0, JustHub.DesignTokens.Geometry.WindowRadius)}, mainFrame)
    local mainBorder = addBorder(mainFrame, "Color Stroke", 1); registerChroma(mainBorder, "Color", "Color Stroke")
    local topBar = createInstance("Frame", {Name = "TopBar", Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2}, mainFrame)
    local titleLabel = createInstance("TextLabel", {Name = "TitleLabel", Text = winName, Size = UDim2.new(0.62, 0, 0, 22), Position = UDim2.new(0, 20, 0, 4), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2}, topBar)
    applyTheme(titleLabel, "TextColor3", "Color Text")
    local subtitleLabel = createInstance("TextLabel", {Name = "SubtitleLabel", Text = subTitle, Size = UDim2.new(0.62, 0, 0, 15), Position = UDim2.new(0, 20, 0, 27), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2}, topBar)
    applyTheme(subtitleLabel, "TextColor3", "Color Dark Text")
    local btnContainer = createInstance("Frame", {Name = "ButtonContainer", Size = UDim2.new(0, 100, 1, 0), Position = UDim2.new(1, -15, 0, 0), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, ZIndex = 2}, topBar)
    createInstance("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, btnContainer)
    local function createWinBtn(name, themeKey, order, text)
        local btn = createInstance("TextButton", {Name = name, Text = text or "", Size = UDim2.new(0, 14, 0, 14), LayoutOrder = order, AutoButtonColor = false, BorderSizePixel = 0, TextSize = 10, ZIndex = 2}, btnContainer)
        applyTheme(btn, "BackgroundColor3", themeKey)
        registerSurface(btn, "Button")
        createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, btn)
        addConnection(btn.MouseEnter:Connect(function()
            tweenProperty(btn, {BackgroundTransparency = math.max(0, surfaceTransparency("Button") - 0.12)}, JustHub.DesignTokens.Animation.Hover)
        end))
        addConnection(btn.MouseLeave:Connect(function()
            tweenProperty(btn, {BackgroundTransparency = surfaceTransparency("Button")}, JustHub.DesignTokens.Animation.Hover)
        end))
        return btn
    end
    local hideBtn = createWinBtn("HideBtn", "Color Dark Text", 1)
    local maxBtn  = createWinBtn("MaxBtn", "Color Theme", 2)
    local closeBtn = createWinBtn("CloseBtn", "Color Stroke", 3)
    local lockBtn = createWinBtn("LockBtn", "Color Dark Text", 4, "🔒")
    applyTheme(lockBtn, "TextColor3", "Color Text")
    local headerSep = createInstance("Frame", {Size = UDim2.new(1, -40, 0, 1), Position = UDim2.new(0, 20, 0, 52), BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 2}, mainFrame)
    applyTheme(headerSep, "BackgroundColor3", "Color Stroke")
    local profileFrame = createInstance("Frame", {Name = "ProfileFrame", Size = UDim2.new(0, JustHub.Save.TabSize, 0, 46), Position = UDim2.new(0, 20, 0, 62), BackgroundTransparency = 1, ZIndex = 2}, mainFrame)
    local avatarImg = createInstance("ImageLabel", {Size = UDim2.new(0, 36, 0, 36), Position = UDim2.new(0, 0, 0.5, -18), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2}, profileFrame)
    applyTheme(avatarImg, "BackgroundColor3", "Color Hub 1"); createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, avatarImg)
    pcall(function() avatarImg.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100) end)
    local profileName = createInstance("TextLabel", {Text = player.DisplayName, Size = UDim2.new(1, -46, 1, 0), Position = UDim2.new(0, 46, 0, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2}, profileFrame)
    applyTheme(profileName, "TextColor3", "Color Text")
    local sidebar = createInstance("Frame", {Name = "Sidebar", Size = UDim2.new(0, JustHub.Save.TabSize, 1, -142), Position = UDim2.new(0, 20, 0, 118), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2}, mainFrame)
    applyTheme(sidebar, "BackgroundColor3", "Color Hub 1")
    registerSurface(sidebar, "Sidebar")
    createInstance("UICorner", {CornerRadius = UDim.new(0, JustHub.DesignTokens.Geometry.SidebarRadius)}, sidebar)
    addBorder(sidebar, "Color Stroke", 1)
    createInstance("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6)}, sidebar)
    local contentContainer = createInstance("Frame", {Name = "ContentContainer", Size = UDim2.new(1, -(JustHub.Save.TabSize + 50), 1, -82), Position = UDim2.new(0, JustHub.Save.TabSize + 30, 0, 62), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2}, mainFrame)
    applyTheme(contentContainer, "BackgroundColor3", "Color Hub 1")
    registerSurface(contentContainer, "Content")
    createInstance("UICorner", {CornerRadius = UDim.new(0, 12)}, contentContainer)
    addBorder(contentContainer, "Color Stroke", 1)
    local searchFrame = createInstance("Frame", {Name = "SearchFrame", Size = UDim2.new(1, 0, 0, 32), Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 0.08, BorderSizePixel = 0, ZIndex = 2}, contentContainer)
    applyTheme(searchFrame, "BackgroundColor3", "Color Hub 2"); createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, searchFrame); addBorder(searchFrame, "Color Stroke", 1)
    local searchIcon = createInstance("ImageLabel", {Name = "SearchIcon", Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 11, 0.5, -7), BackgroundTransparency = 1, Image = JustHub.Icons.search, ImageTransparency = 0.15, ZIndex = 3}, searchFrame)
    applyTheme(searchIcon, "ImageColor3", "Color Dark Text")
    local searchBox = createInstance("TextBox", {Size = UDim2.new(1, -42, 1, 0), Position = UDim2.new(0, 34, 0, 0), Font = Enum.Font.Gotham, TextSize = 12, PlaceholderText = "Search controls...", ClearTextOnFocus = false, BackgroundTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3}, searchFrame)
    applyTheme(searchBox, "TextColor3", "Color Text"); applyTheme(searchBox, "PlaceholderColor3", "Color Dark Text")
    local tabsContainer = createInstance("Frame", {Name = "TabsContainer", Size = UDim2.new(1, 0, 1, -40), Position = UDim2.new(0, 0, 0, 38), BackgroundTransparency = 1, ZIndex = 2}, contentContainer)
    local footer = createInstance("Frame", {Name = "Footer", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -20), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2}, mainFrame)
    local watermark = createInstance("TextLabel", {Name = "Watermark", Text = "JustHub  •  " .. player.DisplayName, Size = UDim2.new(0, 220, 1, 0), Position = UDim2.new(0, 20, 0, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 10, TextTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2}, footer)
    applyTheme(watermark, "TextColor3", "Color Dark Text")
    local fpsLabel = createInstance("TextLabel", {Name = "FPSLabel", Text = "FPS: --", Size = UDim2.new(0, 100, 1, 0), Position = UDim2.new(1, -20, 0, 0), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 2}, footer)
    applyTheme(fpsLabel, "TextColor3", "Color Dark Text")
    local lastTime, frameCount = os.clock(), 0
    addConnection(RunService.RenderStepped:Connect(function()
        if not isAlive() then return end
        frameCount = frameCount + 1; local currentTime = os.clock()
        if currentTime - lastTime >= 1 then
            if fpsLabel and fpsLabel.Parent then fpsLabel.Text = "FPS: " .. frameCount end
            frameCount = 0; lastTime = currentTime
        end
    end))
    tweenProperty(mainFrame, {Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.6, Enum.EasingStyle.Exponential)
    local windowState = "normal"
    local savedNormalSize = mainFrame.Size
    local requestedNormalSize = UDim2.new(0, JustHub.Save.UISize[1], 0, JustHub.Save.UISize[2])
    local savedNormalPos  = UDim2.new(0.5, 0, 0.5, 0)
    local isLocked = JustHub.Save.Locked
    local function setPanelsVisible(visible)
        sidebar.Visible = visible; contentContainer.Visible = visible; footer.Visible = visible
        headerSep.Visible = visible; profileFrame.Visible = visible; watermark.Visible = visible
    end
    local function setWindowState(newState)
        if newState == windowState then return end
        local prevState = windowState
        if prevState == "normal" and newState ~= "normal" then savedNormalSize = mainFrame.Size; savedNormalPos = mainFrame.Position end
        windowState = newState
        if newState == "minimized" then
            local minimizedWidth = savedNormalSize.X.Offset
            if minimizedWidth <= 0 then
                minimizedWidth = math.max(mainFrame.AbsoluteSize.X, JustHub.Save.UISize[1])
            end
            tweenProperty(mainFrame, {Size = UDim2.new(0, minimizedWidth, 0, 45)}, 0.4, Enum.EasingStyle.Exponential)
            task.delay(0.15, function() if isAlive() and windowState == "minimized" then setPanelsVisible(false) end end)
        elseif newState == "maximized" then
            setPanelsVisible(true)
            tweenProperty(mainFrame, {Size = UDim2.new(1, -40, 1, -40), Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.4, Enum.EasingStyle.Exponential)
        elseif newState == "normal" then
            setPanelsVisible(true)
            tweenProperty(mainFrame, {Size = savedNormalSize, Position = savedNormalPos}, 0.4, Enum.EasingStyle.Exponential)
        end
    end
    addConnection(hideBtn.Activated:Connect(function() setWindowState(windowState == "minimized" and "normal" or "minimized") end))
    addConnection(maxBtn.Activated:Connect(function() setWindowState(windowState == "maximized" and "normal" or "maximized") end))
    addConnection(closeBtn.Activated:Connect(function()
        if windowState == "hidden" then return end
        local prevState = windowState; windowState = "hidden"
        local t = tweenProperty(mainFrame, {Position = UDim2.new(0.5, 0, -0.5, 0), BackgroundTransparency = 1}, 0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.In)
        connectOnce(t.Completed, function()
            if not isAlive() then return end
            mainFrame.Visible = false
            local showUI = trackScreenGui(createInstance("ScreenGui", {Name = "JustHubShowUI", ResetOnSpawn = false}, targetParent))
            local showBtn = createInstance("TextButton", {Name = "ShowUIButton", Size = UDim2.new(0, 44, 0, 44), Position = UDim2.new(0.5, -22, 0, 10), Text = "UI", Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = false}, showUI)
            applyTheme(showBtn, "BackgroundColor3", "Color Hub 2"); applyTheme(showBtn, "TextColor3", "Color Text")
            registerSurface(showBtn, "Button")
            createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, showBtn); addBorder(showBtn, "Color Stroke", 1)
            addConnection(showBtn.Activated:Connect(function()
                if not isAlive() then return end
                mainFrame.Visible = true; windowState = prevState or "normal"
                tweenProperty(mainFrame, {Position = savedNormalPos, BackgroundTransparency = surfaceTransparency("MainWindow"), Size = savedNormalSize}, 0.5, Enum.EasingStyle.Exponential)
                pcall(function() showUI:Destroy() end)
                for i = #JustHub.ScreenGuis, 1, -1 do if JustHub.ScreenGuis[i] == showUI then table.remove(JustHub.ScreenGuis, i) end end
            end))
        end)
    end))
    addConnection(lockBtn.Activated:Connect(function()
        isLocked = not isLocked; JustHub.Save.Locked = isLocked
        lockBtn.Text = isLocked and "🔐" or "🔒"
        JustHub:UpdateThemeObject(lockBtn, "BackgroundColor3", isLocked and "Color Theme" or "Color Dark Text")
        lockBtn.BackgroundColor3 = getCurrentTheme(JustHub.Save.Theme)[isLocked and "Color Theme" or "Color Dark Text"]
    end))
    local resizeGrip = createInstance("TextButton", {Name = "ResizeGrip", Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -24, 1, -24), BackgroundTransparency = 1, Text = "⌟", Font = Enum.Font.Gotham, TextSize = 16, ZIndex = 50}, mainFrame)
    applyTheme(resizeGrip, "TextColor3", "Color Dark Text")
    local isDragging, isResizing = false, false
    local activeWindowInput = nil
    local dragStart, dragStartPos, dragStartSize
    addConnection(topBar.InputBegan:Connect(function(input)
        if isLocked or windowState == "maximized" then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true; activeWindowInput = input; dragStart = input.Position; dragStartPos = mainFrame.Position
        end
    end))
    addConnection(resizeGrip.InputBegan:Connect(function(input)
        if isLocked or windowState ~= "normal" then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isResizing = true; activeWindowInput = input; dragStart = input.Position; dragStartSize = mainFrame.Size
        end
    end))
    addConnection(UserInputService.InputChanged:Connect(function(input)
        if not isAlive() or not activeWindowInput then return end
        local isMatchingMouse = activeWindowInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        local isMatchingTouch = activeWindowInput.UserInputType == Enum.UserInputType.Touch
            and input == activeWindowInput
        if not (isMatchingMouse or isMatchingTouch) then return end
        if isDragging then
            local delta = input.Position - dragStart
            local newPos = UDim2.new(dragStartPos.X.Scale, dragStartPos.X.Offset + delta.X, dragStartPos.Y.Scale, dragStartPos.Y.Offset + delta.Y)
            mainFrame.Position = newPos
            if windowState == "normal" then savedNormalPos = newPos end
        elseif isResizing then
            local delta = input.Position - dragStart
            local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(JustHub.Save.UISize[1], JustHub.Save.UISize[2])
            local minW = math.min(JustHub.Save.UISize[1] * 0.7, math.max(220, viewport.X - 24))
            local minH = math.min(JustHub.Save.UISize[2] * 0.7, math.max(200, viewport.Y - 24))
            local maxW, maxH = math.max(220, viewport.X - 24), math.max(200, viewport.Y - 24)
            local newW = math.clamp(dragStartSize.X.Offset + delta.X, minW, maxW)
            local newH = math.clamp(dragStartSize.Y.Offset + delta.Y, minH, maxH)
            local newSize = UDim2.new(0, newW, 0, newH)
            mainFrame.Size = newSize; savedNormalSize = newSize; requestedNormalSize = newSize
        end
    end))
    addConnection(UserInputService.InputEnded:Connect(function(input)
        local isMatchingMouse = activeWindowInput
            and activeWindowInput.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseButton1
        if activeWindowInput and (input == activeWindowInput or isMatchingMouse) then
            isDragging, isResizing = false, false
            activeWindowInput = nil
        end
    end))
    addConnection(UserInputService.WindowFocusReleased:Connect(function()
        isDragging, isResizing = false, false
        activeWindowInput = nil
    end))
    local notiContainer = createInstance("Frame", {Name = "NotificationContainer", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -20), Size = UDim2.new(0, 280, 1, -40), BackgroundTransparency = 1, ZIndex = 100}, screenGui)
    createInstance("UIListLayout", {Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder}, notiContainer)
    self.NotificationContainer = notiContainer
    local windowObj = {ScreenGui = screenGui, MainFrame = mainFrame, TopBar = topBar, Sidebar = sidebar, ContentContainer = tabsContainer, Tabs = {}}
    self.Window = windowObj
    local viewportConnection
    local function applyResponsiveLayout()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
        local desiredW = math.max(220, requestedNormalSize.X.Offset)
        local desiredH = math.max(200, requestedNormalSize.Y.Offset)
        local fittedW = math.max(220, math.min(desiredW, math.max(220, viewport.X - 24)))
        local fittedH = math.max(200, math.min(desiredH, math.max(200, viewport.Y - 24)))
        savedNormalSize = UDim2.new(0, fittedW, 0, fittedH)
        if windowState == "normal" then mainFrame.Size = savedNormalSize end
        local compact = fittedW < 540 or viewport.Y < 500
        local sideWidth = compact and math.clamp(math.floor(fittedW * 0.25), 64, 96)
            or math.min(JustHub.Save.TabSize, math.floor(fittedW * 0.28))
        titleLabel.Size = UDim2.new(compact and 0.44 or 0.62, 0, 0, 22)
        subtitleLabel.Size = UDim2.new(compact and 0.44 or 0.62, 0, 0, 15)
        titleLabel.TextSize = compact and 14 or 16
        subtitleLabel.TextSize = compact and 10 or 11
        titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        subtitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
        btnContainer.Size = UDim2.new(0, compact and 84 or 100, 1, 0)
        sidebar.Size = UDim2.new(0, sideWidth, 1, -142)
        profileFrame.Size = UDim2.new(0, sideWidth, 0, 46)
        profileName.Visible = not compact
        contentContainer.Position = UDim2.new(0, sideWidth + 30, 0, 62)
        contentContainer.Size = UDim2.new(1, -(sideWidth + 50), 1, -82)
        for _, tab in ipairs(windowObj.Tabs) do
            tab.Button.Size = UDim2.new(1, 0, 0, compact and 34 or 36)
            if tab.Icon then
                tab.Icon.Visible = not compact
                tab.Icon.Position = UDim2.new(0, 15, 0.5, -9)
            end
            if tab.TextLabel then
                local textX = (not compact and tab.Icon) and 40 or 16
                tab.TextLabel.Position = UDim2.new(0, textX, 0, 0)
                tab.TextLabel.Size = UDim2.new(1, -(textX + 8), 1, 0)
                tab.TextLabel.TextSize = compact and 11 or 13
            end
        end
    end
    local function bindViewportCamera()
        if viewportConnection then
            removeConnection(viewportConnection)
            pcall(function() viewportConnection:Disconnect() end)
            viewportConnection = nil
        end
        local camera = workspace.CurrentCamera
        if camera then
            viewportConnection = addConnection(camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout))
        end
        applyResponsiveLayout()
    end
    addConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewportCamera))
    bindViewportCamera()
    addConnection(searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local term = searchBox.Text:lower()
        for _, tab in ipairs(windowObj.Tabs) do
            for _, sec in ipairs(tab.Sections) do
                local anyVisible = false
                for _, child in ipairs(sec.Content:GetChildren()) do
                    if child:IsA("Frame") then
                        local show = (term == "" or string.find(child.Name:lower(), term, 1, true) ~= nil)
                        child.Visible = show
                        if show then anyVisible = true end
                    end
                end
                sec.Frame.Visible = (anyVisible or term == "")
            end
        end
    end))
    function windowObj:addTab(tabName, iconName)
        tabName = tabName or "Tab"
        local btn = createInstance("TextButton", {
            Name = tabName .. "Button", Text = "", Size = UDim2.new(1, 0, 0, 40),
            BackgroundTransparency = 1, AutoButtonColor = false,
            Active = true, Selectable = true, ZIndex = 5
        }, sidebar)
        applyTheme(btn, "BackgroundColor3", "Color Hub 1")
        registerSurface(btn, "TabInactive")
        createInstance("UICorner", {CornerRadius = UDim.new(0, JustHub.DesignTokens.Geometry.TabRadius)}, btn)
        local indicator = createInstance("Frame", {
            Name = "ActiveIndicator", Size = UDim2.new(0, 3, 0, 16), Position = UDim2.new(0, 6, 0.5, -8),
            BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4
        }, btn)
        applyTheme(indicator, "BackgroundColor3", "Color Theme")
        createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, indicator)
        local tabIcon
        if iconName and JustHub.Icons[iconName] then
            tabIcon = createInstance("ImageLabel", {Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(0, 15, 0.5, -9), BackgroundTransparency = 1, Image = JustHub.Icons[iconName], ZIndex = 2}, btn)
            applyTheme(tabIcon, "ImageColor3", "Color Dark Text")
        end
        local textX = tabIcon and 40 or 16
        local tabText = createInstance("TextLabel", {Text = tabName, Size = UDim2.new(1, -(textX + 8), 1, 0), Position = UDim2.new(0, textX, 0, 0), BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 2}, btn)
        applyTheme(tabText, "TextColor3", "Color Dark Text")
        local tabContent = createInstance("ScrollingFrame", {Name = tabName .. "Content", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, ScrollBarThickness = 2, BorderSizePixel = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), Visible = false, ZIndex = 2}, tabsContainer)
        applyTheme(tabContent, "ScrollBarImageColor3", "Color Stroke"); createInstance("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center}, tabContent)
        local tabObj = {Name = tabName, Button = btn, Content = tabContent, Sections = {}, Indicator = indicator, Icon = tabIcon, TextLabel = tabText}
        table.insert(windowObj.Tabs, tabObj)
        local function updateTabs()
            local theme = getCurrentTheme(JustHub.Save.Theme)
            for _, t in ipairs(windowObj.Tabs) do
                local active = (t == tabObj)
                t.Content.Visible = active
                setSurfaceKind(t.Button, active and "TabActive" or "TabInactive")
                tweenProperty(t.Button, {BackgroundTransparency = surfaceTransparency(active and "TabActive" or "TabInactive")}, JustHub.DesignTokens.Animation.TabTransition)
                if t.Indicator then tweenProperty(t.Indicator, {BackgroundTransparency = active and 0 or 1}, JustHub.DesignTokens.Animation.TabTransition) end
                local textObj = t.Button:FindFirstChildOfClass("TextLabel")
                local imgObj = t.Button:FindFirstChildOfClass("ImageLabel")
                if textObj then
                    local textKey = active and "Color Text" or "Color Dark Text"
                    JustHub:UpdateThemeObject(textObj, "TextColor3", textKey)
                    tweenProperty(textObj, {TextColor3 = theme[textKey]}, JustHub.DesignTokens.Animation.TabTransition)
                end
                if imgObj then
                    local iconKey = active and "Color Text" or "Color Dark Text"
                    JustHub:UpdateThemeObject(imgObj, "ImageColor3", iconKey)
                    tweenProperty(imgObj, {ImageColor3 = theme[iconKey]}, JustHub.DesignTokens.Animation.TabTransition)
                end
            end
        end
        addConnection(btn.MouseEnter:Connect(function()
            if tabObj.Content.Visible then return end
            tweenProperty(btn, {BackgroundTransparency = surfaceTransparency("TabHover")}, JustHub.DesignTokens.Animation.Hover)
        end))
        addConnection(btn.MouseLeave:Connect(function()
            if tabObj.Content.Visible then return end
            tweenProperty(btn, {BackgroundTransparency = surfaceTransparency("TabInactive")}, JustHub.DesignTokens.Animation.Hover)
        end))
        addConnection(btn.Activated:Connect(updateTabs))
        if #windowObj.Tabs == 1 then updateTabs() end
        if applyResponsiveLayout then applyResponsiveLayout() end
        function tabObj:addSection(sectionName)
            sectionName = sectionName or "Section"

            local secFrame = createInstance("Frame", {
                Name = sectionName,
                Size = UDim2.new(1, -4, 0, 48),
                BackgroundTransparency = 0.22,
                ClipsDescendants = false,
                LayoutOrder = #tabObj.Sections + 1,
                ZIndex = 2
            }, tabContent)
            applyTheme(secFrame, "BackgroundColor3", "Color Hub 1")
            createInstance("UICorner", {
                CornerRadius = UDim.new(0, JustHub.DesignTokens.Geometry.SectionRadius)
            }, secFrame)
            addBorder(secFrame, "Color Stroke", 1)

            local secTitle = createInstance("TextLabel", {
                Name = "SectionTitle",
                Text = "  " .. sectionName,
                Size = UDim2.new(1, 0, 0, 36),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamSemibold,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2
            }, secFrame)
            applyTheme(secTitle, "TextColor3", "Color Text")

            local secContent = createInstance("Frame", {
                Name = "SectionContent",
                Size = UDim2.new(1, 0, 0, 12),
                Position = UDim2.new(0, 0, 0, 36),
                BackgroundTransparency = 1,
                ZIndex = 2
            }, secFrame)

            local sectionLayout = createInstance("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
                HorizontalAlignment = Enum.HorizontalAlignment.Center
            }, secContent)

            createInstance("UIPadding", {
                PaddingBottom = UDim.new(0, 10),
                PaddingTop = UDim.new(0, 2),
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10)
            }, secContent)

            local function updateSectionSize()
                if not secFrame.Parent or not secContent.Parent then
                    return
                end

                local contentHeight = math.max(12, sectionLayout.AbsoluteContentSize.Y + 12)
                secContent.Size = UDim2.new(1, 0, 0, contentHeight)
                secFrame.Size = UDim2.new(1, -4, 0, 36 + contentHeight)
            end

            addConnection(sectionLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateSectionSize))

            local secObj = {
                Frame = secFrame,
                Title = secTitle,
                Content = secContent,
                _tabName = tabName,
                _sectionName = sectionName
            }

            table.insert(tabObj.Sections, secObj)
            setmetatable(secObj, {__index = SectionMethods})

            updateSectionSize()

            return secObj
        end
        return tabObj
    end
    return windowObj
end

function JustHub:ShowLoadingScreen(duration, callback)
    duration = duration or 5
    callback = callback or function() end
    if not isAlive() then return end
    local loadGui = trackScreenGui(createInstance("ScreenGui", {Name = "JustHubLoadingScreen", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Global}, targetParent))
    local bgOverlay = createInstance("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 100}, loadGui)
    applyTheme(bgOverlay, "BackgroundColor3", "Color Hub 2")
    local titleLabel = createInstance("TextLabel", {Text = "JustHub Library", Font = Enum.Font.GothamBold, TextSize = 24, BackgroundTransparency = 1, Size = UDim2.new(0, 200, 0, 50), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -50), ZIndex = 101}, loadGui)
    applyTheme(titleLabel, "TextColor3", "Color Text")
    local barContainer = createInstance("Frame", {Size = UDim2.new(0, 300, 0, 10), Position = UDim2.new(0.5, 0, 0.5, 20), AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 101}, loadGui)
    applyTheme(barContainer, "BackgroundColor3", "Color Hub 1"); createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, barContainer); addBorder(barContainer, "Color Stroke", 1)
    local barFill = createInstance("Frame", {Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, ZIndex = 102}, barContainer)
    applyTheme(barFill, "BackgroundColor3", "Color Theme"); createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, barFill)
    local tween = tweenProperty(barFill, {Size = UDim2.new(1, 0, 1, 0)}, duration)
    local titleTween = TweenService:Create(titleLabel, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {TextTransparency = 0.5})
    activeTweens[titleLabel] = titleTween
    titleTween:Play()
    if tween then
        connectOnce(tween.Completed, function()
            if not isAlive() then return end
            titleTween:Cancel()
            if activeTweens[titleLabel] == titleTween then activeTweens[titleLabel] = nil end
            task.wait(0.3)
            local fade = tweenProperty(bgOverlay, {BackgroundTransparency = 1}, 0.5)
            tweenProperty(titleLabel, {TextTransparency = 1}, 0.5)
            tweenProperty(barContainer, {BackgroundTransparency = 1}, 0.5)
            tweenProperty(barFill, {BackgroundTransparency = 1}, 0.5)
            if fade then
                connectOnce(fade.Completed, function()
                    if loadGui then pcall(function() loadGui:Destroy() end) end
                    for i = #JustHub.ScreenGuis, 1, -1 do if JustHub.ScreenGuis[i] == loadGui then table.remove(JustHub.ScreenGuis, i) end end
                    if isAlive() then local ok, err = pcall(callback); if not ok then warn("[JustHub] Loading screen error: " .. tostring(err)) end end
                end)
            end
        end)
    end
end

function JustHub:InitializeUI(options)
    if not isAlive() or self._initializing or self.Window then return false end
    self._initializing = true
    self:ShowLoadingScreen(3, function()
        self._initializing = false
        if not isAlive() then return end
        self.Window = self:CreateWindow(options)
    end)
    return true
end

local function serializeConfig(data)
    local serialized = {}
    for k, v in pairs(data) do
        if typeof(v) == "Color3" then serialized[k] = {__type = "Color3", R = v.R, G = v.G, B = v.B}
        elseif type(v) == "table" then serialized[k] = serializeConfig(v)
        else serialized[k] = v end
    end
    return serialized
end

local function deserializeConfig(data)
    local deserialized = {}
    for k, v in pairs(data) do
        if type(v) == "table" and v.__type == "Color3" then deserialized[k] = Color3.new(v.R, v.G, v.B)
        elseif type(v) == "table" then deserialized[k] = deserializeConfig(v)
        else deserialized[k] = v end
    end
    return deserialized
end

local function isSafeConfigFileName(fileName)
    return type(fileName) == "string"
        and fileName ~= ""
        and fileName ~= "."
        and fileName ~= ".."
        and #fileName <= 128
        and not fileName:find("/", 1, true)
        and not fileName:find("\\", 1, true)
        and not fileName:find(":", 1, true)
        and not fileName:find("..", 1, true)
        and not fileName:find("\0", 1, true)
end

function JustHub:SaveConfig(fileName)
    fileName = fileName or "JustHub_Config.json"
    if not isSafeConfigFileName(fileName) then
        warn("[JustHub] SaveConfig: Invalid filename '" .. tostring(fileName) .. "'")
        return false, "Invalid filename"
    end
    local success, err = pcall(function()
        if writefile then
            local json = HttpService:JSONEncode(serializeConfig(JustHub.ConfigData))
            writefile(fileName, json)
            StarterGui:SetCore("SendNotification", {Title = "Save Config", Text = "Success save at " .. fileName, Duration = 5})
        else
            warn("Saving config not supported.")
        end
    end)
    if not success then warn("Save error: " .. err) end
    return success
end

function JustHub:LoadConfig(fileName)
    fileName = fileName or "JustHub_Config.json"
    if not isSafeConfigFileName(fileName) then
        warn("[JustHub] LoadConfig: Invalid filename '" .. tostring(fileName) .. "'")
        return false, "Invalid filename"
    end
    local config = {}
    local success, err = pcall(function()
        if readfile then
            local data = readfile(fileName)
            config = deserializeConfig(HttpService:JSONDecode(data))
            JustHub.ConfigData = config
            JustHub:ApplyConfig(config)
            StarterGui:SetCore("SendNotification", {Title = "Load Config", Text = "Success load from " .. fileName, Duration = 5})
        else
            warn("Loading config not supported.")
        end
    end)
    if not success then warn("Load error: " .. err) end
    return config
end

function JustHub:UpdateTheme(newTheme)
    self.Save.Theme = newTheme
    local themeData = getCurrentTheme(newTheme)
    for obj, props in pairs(self.ThemeObjects) do
        for prop, data in pairs(props) do
            local skip = false
            if self.ChromaEnabled and self.ChromaObjects[obj] and self.ChromaObjects[obj][prop] then
                skip = true
            end
            if not skip then
                if data.CustomFunc then data.CustomFunc()
                elseif themeData[data.ThemeKey] then obj[prop] = themeData[data.ThemeKey] end
            end
        end
    end
end

function JustHub:SetTheme(newTheme) self:UpdateTheme(newTheme) end

function JustHub:ToggleUIVisibility()
    if self.ScreenGui and self.ScreenGui.Parent then self.ScreenGui.Enabled = not self.ScreenGui.Enabled end
end

function JustHub:SetTransparency(alpha)
    alpha = math.clamp(tonumber(alpha) or 0.15, 0, 1)
    self.Save.Transparency = alpha
    refreshTransparencyTokens()
    for obj, record in pairs(surfaceRegistry) do
        if obj and obj.Parent and record then
            if activeTweens[obj] then
                pcall(function() activeTweens[obj]:Cancel() end)
                activeTweens[obj] = nil
            end
            pcall(function() obj.BackgroundTransparency = surfaceTransparency(record.Kind) end)
        else
            surfaceRegistry[obj] = nil
        end
    end
    return true
end

function JustHub:SetKey(key) self.KeySystem.Enabled = true; self.KeySystem.Key = key end
function JustHub:CheckKey(inputKey)
    if not self.KeySystem.Enabled then return true end
    return inputKey == self.KeySystem.Key
end

function JustHub:Notify(options)
    options = options or {}
    local title = tostring(options.Title or "")
    local message = tostring(options.Message or "")
    local duration = math.max(0, tonumber(options.Duration) or 5)
    local showProgress = options.ShowProgress == true
    if not self.NotificationContainer or not isAlive() then return end
    local notifFrame = createInstance("Frame", {Name = "NotificationSurface", Size = UDim2.new(0, 300, 0, 0), BackgroundTransparency = 0.15, ClipsDescendants = true}, self.NotificationContainer)
    applyTheme(notifFrame, "BackgroundColor3", "Color Hub 2"); createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, notifFrame); addBorder(notifFrame, "Color Stroke", 1)
    local titleLabel = createInstance("TextLabel", {Text = title, Size = UDim2.new(1, -20, 0, 20), Position = UDim2.new(0, 10, 0, 10), BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left}, notifFrame)
    applyTheme(titleLabel, "TextColor3", "Color Text")
    local msgLabel = createInstance("TextLabel", {Text = message, Size = UDim2.new(1, -20, 0, 0), Position = UDim2.new(0, 10, 0, 35), BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.Y}, notifFrame)
    applyTheme(msgLabel, "TextColor3", "Color Dark Text")
    local progressFrame
    if showProgress then
        progressFrame = createInstance("Frame", {Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 1, -4), BorderSizePixel = 0}, notifFrame)
        applyTheme(progressFrame, "BackgroundColor3", "Color Theme"); registerChroma(progressFrame, "BackgroundColor3", "Color Theme")
    end
    local notificationThread
    notificationThread = task.defer(function()
        local function finish()
            self._notificationThreads[notificationThread] = nil
        end
        if not isAlive() or not notifFrame.Parent then finish(); return end
        task.wait()
        if not isAlive() or not notifFrame.Parent then finish(); return end
        local calculated = 10 + titleLabel.Size.Y.Offset + (msgLabel.TextBounds.Y > 0 and msgLabel.TextBounds.Y or 18) + 15
        if showProgress then calculated = calculated + 4 end
        tweenProperty(notifFrame, {Size = UDim2.new(0, 300, 0, calculated)}, 0.4, Enum.EasingStyle.Exponential)
        task.wait(0.5)
        if not isAlive() or not notifFrame.Parent then finish(); return end
        if showProgress and progressFrame then tweenProperty(progressFrame, {Size = UDim2.new(0, 0, 0, 4)}, duration, Enum.EasingStyle.Linear) end
        task.wait(duration)
        if not isAlive() or not notifFrame.Parent then finish(); return end
        local outTween = tweenProperty(notifFrame, {BackgroundTransparency = 1, Size = UDim2.new(0, 300, 0, 0)}, JustHub.DesignTokens.Animation.NotificationTransition, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        if outTween then connectOnce(outTween.Completed, function() if notifFrame then pcall(function() notifFrame:Destroy() end) end end) end
        finish()
    end)
    self._notificationThreads[notificationThread] = true
end

function JustHub:PromoNotify(interval)
    if not self.PromoNotifyEnabled then return end
    if self._promoThread then return end
    interval = math.max(10, tonumber(interval) or 30)
    self._promoThread = task.spawn(function()
        while isAlive() and self.ScreenGui and self.ScreenGui.Parent do
            self:Notify({Title = "JustHub UI", Message = "Thanks for using JustHub Library " .. self.Info.Version, Duration = 3, ShowProgress = true})
            task.wait(interval)
        end
        self._promoThread = nil
    end)
end

function JustHub:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self._initializing = false
    for _, conn in ipairs(self.Connections) do pcall(function() conn:Disconnect() end) end
    table.clear(self.Connections)
    for _, tween in pairs(activeTweens) do
        pcall(function() tween:Cancel() end)
    end
    table.clear(activeTweens)
    if self._promoThread then
        pcall(task.cancel, self._promoThread)
    end
    for thread in pairs(self._notificationThreads) do
        pcall(task.cancel, thread)
    end
    table.clear(self._notificationThreads)
    if chromaRenderConn then pcall(function() chromaRenderConn:Disconnect() end); chromaRenderConn = nil end
    for _, sg in ipairs(self.ScreenGuis) do pcall(function() sg:Destroy() end) end
    table.clear(self.ScreenGuis)
    table.clear(self.ThemeObjects)
    table.clear(surfaceRegistry)
    table.clear(self.ChromaObjects)
    table.clear(self.ControlRegistry)
    table.clear(self.ControlAliases)
    table.clear(self.AmbiguousControlAliases)
    table.clear(self.Controls)
    table.clear(self.UndoStack)
    table.clear(self.RedoStack)
    if self.ScreenGui then pcall(function() self.ScreenGui:Destroy() end); self.ScreenGui = nil end
    self.NotificationContainer = nil; self.Window = nil; self._promoThread = nil
end

return JustHub
