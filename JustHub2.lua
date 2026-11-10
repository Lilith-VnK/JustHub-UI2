local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
assert(player, "JustHub must run in a client context")

local parentGui = player:WaitForChild("PlayerGui")

local JustHub = {
    Info = {Version = "3.2.0"},
    Save = {
        UISize = {620, 440},
        TabSize = 135,
        Theme = "Darker",
        Transparency = 0.15,
        Locked = false,
    },

    ConfigData = {},
    PendingConfig = {},
    ControlRegistry = {},
    ControlAliases = {},
    AmbiguousControlAliases = {},
    Controls = {},
    Localization = {},
    CurrentLang = "en",
    UserRole = "member",
    UndoStack = {},
    RedoStack = {},
    Sounds = {ButtonClick = 0, SliderMove = 0},
    Connections = {},
    ScreenGuis = {},
    ThemeObjects = setmetatable({}, {__mode = "k"}),
    ChromaObjects = setmetatable({}, {__mode = "k"}),
    ChromaEnabled = false,
    PromoNotifyEnabled = true,
    KeySystem = {Enabled = false, Key = ""},

    _destroyed = false,
    _initializing = false,
    _historyMax = 100,
    _isApplyingConfig = false,
    _busy = false,
    _order = {},
    _models = {},
    _ids = {},
    _threads = {},
    _scopes = {},
    _capture = nil,
    _openDropdown = nil,
}

local function finite(v)
    return type(v) == "number"
        and v == v
        and v ~= math.huge
        and v ~= -math.huge
end

local function number(v, fallback)
    local n = tonumber(v)
    return finite(n) and n or fallback
end

local function copy(v, seen)
    if type(v) ~= "table" then
        return v
    end

    seen = seen or {}
    assert(not seen[v], "Cyclic values are unsupported")
    seen[v] = true

    local out = {}
    for k, item in pairs(v) do
        out[k] = copy(item, seen)
    end

    seen[v] = nil
    return out
end

local function equal(a, b)
    if type(a) ~= type(b) then
        return false
    end

    if type(a) ~= "table" then
        return a == b
    end

    for k, v in pairs(a) do
        if not equal(v, b[k]) then
            return false
        end
    end

    for k in pairs(b) do
        if a[k] == nil then
            return false
        end
    end

    return true
end

local function stringArray(v)
    assert(type(v) == "table", "Expected an array of strings")

    local count = 0
    for k, item in pairs(v) do
        assert(
            finite(k) and k >= 1 and k % 1 == 0
                and type(item) == "string",
            "Expected a dense array of strings"
        )
        count += 1
    end

    assert(count == #v, "Expected a dense array")

    local out, seen = {}, {}
    for _, item in ipairs(v) do
        if not seen[item] then
            seen[item] = true
            table.insert(out, item)
        end
    end

    return out
end

local function selection(v)
    local out = stringArray(v)
    table.sort(out)
    return out
end

local function itemsOrEmpty(v)
    if v == nil then
        return {}
    end
    return stringArray(v)
end

local function alive()
    return not JustHub._destroyed
end

local function spawnOwned(fn)
    if not alive() then
        return nil
    end

    local thread
    thread = coroutine.create(function()
        local ok, err = xpcall(fn, debug.traceback)
        JustHub._threads[thread] = nil

        if not ok and alive() then
            warn("[JustHub] " .. tostring(err))
        end
    end)

    JustHub._threads[thread] = true
    task.defer(thread)
    return thread
end

local function callback(fn, ...)
    if type(fn) ~= "function" then
        return
    end

    local args = table.pack(...)
    spawnOwned(function()
        if alive() then
            fn(table.unpack(args, 1, args.n))
        end
    end)
end

local function newScope(root)
    local scope = {
        dead = false,
        connections = {},
        cleanups = {},
    }

    JustHub._scopes[scope] = true

    function scope:connect(signal, fn)
        if self.dead or not alive() then
            return nil
        end

        local conn = signal:Connect(function(...)
            if not self.dead and alive() then
                fn(...)
            end
        end)

        self.connections[conn] = true
        return conn
    end

    function scope:cleanup(fn)
        if self.dead then
            pcall(fn)
        else
            table.insert(self.cleanups, fn)
        end
    end

    function scope:Destroy()
        if self.dead then
            return
        end
        self.dead = true

        for conn in pairs(self.connections) do
            conn:Disconnect()
        end
        table.clear(self.connections)

        for i = #self.cleanups, 1, -1 do
            local ok, err = pcall(self.cleanups[i])
            if not ok then
                warn("[JustHub] Cleanup: " .. tostring(err))
            end
        end

        table.clear(self.cleanups)
        JustHub._scopes[self] = nil
    end

    if root then
        scope:connect(root.Destroying, function()
            scope:Destroy()
        end)
    end

    return scope
end

local requiredThemeKeys = {
    "Color Hub 1", "Color Hub 2", "Color Stroke",
    "Color Theme", "Color Text", "Color Dark Text",
}

local function palette(a, b, c, d, e, f)
    return {
        ["Color Hub 1"] = Color3.fromRGB(table.unpack(a)),
        ["Color Hub 2"] = Color3.fromRGB(table.unpack(b)),
        ["Color Stroke"] = Color3.fromRGB(table.unpack(c)),
        ["Color Theme"] = Color3.fromRGB(table.unpack(d)),
        ["Color Text"] = Color3.fromRGB(table.unpack(e)),
        ["Color Dark Text"] = Color3.fromRGB(table.unpack(f)),
    }
end

JustHub.Themes = {
    Darker = palette({15,15,20},{25,25,30},{45,45,55},{100,255,150},{240,240,245},{160,160,170}),
    Dark = palette({25,25,30},{35,35,40},{60,60,70},{80,200,255},{245,245,250},{170,170,180}),
    Purple = palette({20,15,30},{30,25,40},{50,40,65},{150,100,255},{240,240,245},{170,160,190}),
    Light = palette({210,210,215},{230,230,235},{180,180,190},{0,140,255},{40,40,45},{90,90,100}),
    Neon = palette({5,5,10},{10,10,15},{0,255,255},{0,255,100},{255,255,255},{200,255,255}),
    Forest = palette({0,30,15},{0,45,25},{0,75,35},{50,205,50},{230,255,230},{170,200,170}),
    Aqua = palette({0,70,80},{0,100,110},{0,160,180},{0,230,255},{250,255,255},{200,230,240}),
    Crimson = palette({35,0,5},{60,0,10},{110,0,20},{255,50,80},{255,240,240},{220,180,180}),
    Solar = palette({230,190,0},{255,210,0},{255,150,0},{255,80,0},{30,30,30},{70,70,70}),
    Pastel = palette({210,190,220},{235,220,245},{180,160,200},{170,210,240},{70,70,70},{110,110,110}),
    Cyber = palette({5,5,20},{15,15,35},{0,220,255},{0,180,255},{250,255,255},{190,230,255}),
    Ocean = palette({0,20,40},{0,35,70},{0,80,150},{0,150,255},{230,245,255},{180,210,230}),
    Desert = palette({180,150,110},{210,170,120},{140,70,30},{220,150,30},{50,40,30},{90,80,70}),
    Galaxy = palette({10,0,30},{20,0,40},{70,0,120},{140,0,255},{245,245,255},{200,200,230}),
    Vintage = palette({120,90,60},{140,110,80},{100,70,50},{190,150,120},{70,50,40},{100,90,80}),
    Rainbow = palette({240,240,240},{255,255,255},{200,200,200},{255,100,100},{30,30,30},{90,90,90}),
    Midnight = palette({0,0,20},{5,5,30},{0,0,80},{50,50,255},{250,250,255},{190,190,220}),
}

JustHub.Icons = {
    activity = "rbxassetid://10709752035",
    check = "rbxassetid://10709790644",
    cog = "rbxassetid://10709810948",
    folder = "rbxassetid://10723387563",
    home = "rbxassetid://10723405786",
    menu = "rbxassetid://10723406085",
    search = "rbxassetid://10723406260",
    settings = "rbxassetid://10723406450",
    user = "rbxassetid://10723406670",
}

local function validTheme(t)
    if type(t) ~= "table" then
        return false
    end
    for _, key in ipairs(requiredThemeKeys) do
        if typeof(t[key]) ~= "Color3" then
            return false
        end
    end
    return true
end

local function theme()
    local selected = JustHub.Save.Theme
    if type(selected) == "table" and validTheme(selected) then
        return selected
    end
    return JustHub.Themes[selected] or JustHub.Themes.Darker
end

local surfaces = setmetatable({}, {__mode = "k"})
local tweens = setmetatable({}, {__mode = "k"})
local chromaConnection

local function cancelProperty(obj, prop)
    local map = tweens[obj]
    local record = map and map[prop]
    if record then
        record.tween:Cancel()
    end
end

local function animate(obj, goals, duration)
    if not alive() or not obj or not obj.Parent then
        return nil
    end

    local previous = {}
    for prop in pairs(goals) do
        local record = tweens[obj] and tweens[obj][prop]
        if record then
            previous[record] = true
        end
    end

    for record in pairs(previous) do
        record.tween:Cancel()
    end

    local tween = TweenService:Create(
        obj,
        TweenInfo.new(
            math.max(0, number(duration, 0.18)),
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        ),
        goals
    )

    local record = {tween = tween, goals = goals}
    tweens[obj] = tweens[obj] or {}

    for prop in pairs(goals) do
        tweens[obj][prop] = record
    end

    local conn
    conn = tween.Completed:Connect(function()
        conn:Disconnect()
        local map = tweens[obj]

        if map then
            for prop in pairs(goals) do
                if map[prop] == record then
                    map[prop] = nil
                end
            end
            if not next(map) then
                tweens[obj] = nil
            end
        end
    end)

    tween:Play()
    return tween
end

local function bindTheme(obj, prop, key)
    JustHub.ThemeObjects[obj] = JustHub.ThemeObjects[obj] or {}
    JustHub.ThemeObjects[obj][prop] = key
    obj[prop] = theme()[key]
end

local function surface(obj, offset)
    surfaces[obj] = offset or 0
    local base = JustHub.Save.Transparency
    obj.BackgroundTransparency = math.clamp(
        base + (1 - base) * (offset or 0),
        0,
        1
    )
end

local function make(class, props, parent)
    assert(alive(), "JustHub is destroyed")
    local obj = Instance.new(class)

    local ok, err = pcall(function()
        for key, value in pairs(props or {}) do
            obj[key] = value
        end
        obj.Parent = parent
    end)

    if not ok then
        obj:Destroy()
        error(err, 2)
    end

    return obj
end

local function corner(obj, radius)
    make("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, obj)
end

local function border(obj)
    local stroke = make("UIStroke", {
        Thickness = 1,
        Transparency = 0.58,
    }, obj)
    bindTheme(stroke, "Color", "Color Stroke")
    return stroke
end

local function text(parent, value, size, pos)
    local label = make("TextLabel", {
        Text = tostring(value),
        Size = size or UDim2.new(1, -20, 1, 0),
        Position = pos or UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)

    bindTheme(label, "TextColor3", "Color Text")
    return label
end

local function button(parent, value, size, pos)
    local btn = make("TextButton", {
        Text = tostring(value),
        Size = size,
        Position = pos or UDim2.new(),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        AutoButtonColor = false,
        BorderSizePixel = 0,
    }, parent)

    bindTheme(btn, "BackgroundColor3", "Color Hub 1")
    bindTheme(btn, "TextColor3", "Color Text")
    surface(btn, 0.25)
    corner(btn, 7)
    border(btn)
    return btn
end

local function textbox(parent, value, size, pos)
    local box = make("TextBox", {
        Text = tostring(value or ""),
        Size = size,
        Position = pos or UDim2.new(),
        Font = Enum.Font.Gotham,
        TextSize = 12,
        ClearTextOnFocus = false,
        BorderSizePixel = 0,
    }, parent)

    bindTheme(box, "BackgroundColor3", "Color Hub 1")
    bindTheme(box, "TextColor3", "Color Text")
    bindTheme(box, "PlaceholderColor3", "Color Dark Text")
    surface(box, 0.25)
    corner(box, 7)
    border(box)
    return box
end

local function list(parent, padding)
    return make("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, padding or 8),
    }, parent)
end

local function safeFilename(name)
    return type(name) == "string"
        and #name > 0
        and #name <= 128
        and not name:find("[%c/\\:*?\"<>|]")
        and not name:find("..", 1, true)
        and not name:match("[%. ]$")
end

function JustHub:SetFileAdapter(adapter)
    if type(adapter) ~= "table"
        or type(adapter.read) ~= "function"
        or type(adapter.write) ~= "function" then
        return false, "Adapter requires read and write functions"
    end

    self.FileAdapter = adapter
    return true
end

local function rebuildAliases()
    table.clear(JustHub.ControlAliases)
    table.clear(JustHub.AmbiguousControlAliases)

    for id, meta in pairs(JustHub.Controls) do
        local name = meta.shortName
        if type(name) == "string" and name ~= "" and name ~= id then
            if JustHub.ControlAliases[name] then
                JustHub.ControlAliases[name] = nil
                JustHub.AmbiguousControlAliases[name] = true
            elseif not JustHub.AmbiguousControlAliases[name] then
                JustHub.ControlAliases[name] = JustHub.ControlRegistry[id]
            end
        end
    end
end

local function resolve(key)
    if JustHub.ControlRegistry[key] then
        return key, JustHub.ControlRegistry[key]
    end

    local setter = JustHub.ControlAliases[key]
    if setter then
        for id, candidate in pairs(JustHub.ControlRegistry) do
            if candidate == setter then
                return id, setter
            end
        end
    end
end

function JustHub:RegisterControl(id, setter, meta)
    if not alive() or type(id) ~= "string" or id == ""
        or type(setter) ~= "function" then
        return false
    end

    if self.ControlRegistry[id] and self.ControlRegistry[id] ~= setter then
        return false, "Duplicate control ID"
    end

    if not self.ControlRegistry[id] then
        table.insert(self._order, id)
    end

    self.ControlRegistry[id] = setter
    self.Controls[id] = meta or {}
    rebuildAliases()
    return true
end

function JustHub:UnregisterControl(id)
    self.ControlRegistry[id] = nil
    self.Controls[id] = nil
    self.ConfigData[id] = nil
    self._models[id] = nil
    rebuildAliases()
end

local function controlId(section, name)
    local base = section._tabName .. "/" .. section._sectionName .. "/" .. name
    local id, suffix = base, 2

    while JustHub._ids[id] or JustHub.ControlRegistry[id] do
        id = base .. "#" .. suffix
        suffix += 1
    end

    JustHub._ids[id] = true
    return id
end

function JustHub:AddUndo(id, old, new)
    if not alive() or self._isApplyingConfig or equal(old, new) then
        return false
    end

    table.insert(self.UndoStack, {
        key = id,
        old = copy(old),
        new = copy(new),
    })

    while #self.UndoStack > self._historyMax do
        table.remove(self.UndoStack, 1)
    end

    table.clear(self.RedoStack)
    return true
end

local function model(section, scope, name, default, normalize, render, onChange)
    local id = controlId(section, name)
    local ctrl = {
        id = id,
        scope = scope,
        revision = 0,
        normalize = normalize,
        render = render,
        callback = onChange,
        editing = false,
    }

    ctrl.value = copy(normalize(copy(default)))

    function ctrl:get()
        return copy(self.value)
    end

    function ctrl:prepare(value)
        assert(alive() and not scope.dead, "Control is destroyed")
        return copy(normalize(copy(value)))
    end

    function ctrl:set(value, opts)
        opts = opts or {}
        assert(alive() and not scope.dead, "Control is destroyed")
        assert(not JustHub._busy or opts.internal, "Configuration transaction in progress")

        local new = opts.prepared and copy(value) or self:prepare(value)
        local old = copy(self.value)

        if equal(old, new) then
            render(copy(self.value))
            return false
        end

        local ok, err = pcall(render, copy(new))
        if not ok then
            pcall(render, copy(old))
            error(err, 2)
        end

        self.value = copy(new)
        self.revision += 1
        JustHub.ConfigData[id] = copy(new)

        if not opts.noHistory and not self.editing then
            JustHub:AddUndo(id, old, new)
        end

        if not opts.silent then
            local captured = copy(new)
            spawnOwned(function()
                if alive() and not scope.dead and type(onChange) == "function" then
                    onChange(copy(captured))
                end
            end)
        end

        return true
    end

    function ctrl:beginEdit()
        if not self.editing then
            self.editing = true
            self.editStart = self:get()
        end
    end

    function ctrl:endEdit()
        if not self.editing then
            return
        end

        self.editing = false
        JustHub:AddUndo(id, self.editStart, self.value)
        self.editStart = nil
    end

    local setter = function(value)
        return ctrl:set(value)
    end

    JustHub._models[id] = ctrl
    JustHub.ConfigData[id] = ctrl:get()

    assert(JustHub:RegisterControl(id, setter, {
        shortName = name,
        getValue = function() return ctrl:get() end,
        defaultValue = copy(ctrl.value),
        tab = section._tabName,
        section = section._sectionName,
    }))

    scope:cleanup(function()
        if JustHub._models[id] == ctrl then
            JustHub:UnregisterControl(id)
        end
    end)

    render(ctrl:get())

    if JustHub.PendingConfig[id] ~= nil then
        local value = JustHub.PendingConfig[id]
        local ok, err = pcall(function()
            ctrl:set(value, {noHistory = true})
        end)

        if ok then
            JustHub.PendingConfig[id] = nil
        else
            warn("[JustHub] Pending config " .. id .. ": " .. tostring(err))
        end
    end

    return ctrl
end

local function replay(from, to, field)
    if not alive() or JustHub._busy then
        return false
    end

    while #from > 0 do
        local record = from[#from]
        local ctrl = JustHub._models[record.key]
        local setter = JustHub.ControlRegistry[record.key]

        if not setter then
            table.remove(from)
        else
            local oldFlag = JustHub._isApplyingConfig
            JustHub._isApplyingConfig = true

            local ok, err = pcall(function()
                if ctrl then
                    ctrl:set(copy(record[field]), {noHistory = true})
                else
                    setter(copy(record[field]))
                end
            end)

            JustHub._isApplyingConfig = oldFlag

            if not ok then
                return false, tostring(err)
            end

            table.remove(from)
            table.insert(to, record)
            return true
        end
    end

    return false
end

function JustHub:Undo()
    return replay(self.UndoStack, self.RedoStack, "old")
end

function JustHub:Redo()
    return replay(self.RedoStack, self.UndoStack, "new")
end

function JustHub:ApplyConfig(data)
    if not alive() or type(data) ~= "table" or self._busy then
        return false, "Invalid configuration or library state"
    end

    local staged, unknown, errors = {}, {}, {}
    local canonical = {}

    for key in pairs(data) do
        if type(key) ~= "string" then
            return false, "Configuration keys must be strings"
        end
        if self.ControlRegistry[key] then
            canonical[key] = true
        end
    end

    for key, value in pairs(data) do
        local id = resolve(key)

        if not id then
            local ok, cloned = pcall(copy, value)
            if ok then
                unknown[key] = cloned
            else
                errors[key] = tostring(cloned)
            end
        elseif key == id or not canonical[id] then
            local ctrl = self._models[id]

            if not ctrl then
                errors[key] = "External control has no transactional validator"
            else
                local ok, normalized = pcall(function()
                    return ctrl:prepare(value)
                end)

                if ok then
                    staged[id] = normalized
                else
                    errors[key] = tostring(normalized)
                end
            end
        end
    end

    if next(errors) then
        return false, {errors = errors, applied = 0}
    end

    self._busy = true

    local completed, changes = {}, {}
    local ok, err = pcall(function()
        for _, id in ipairs(self._order) do
            local ctrl = self._models[id]
            local value = staged[id]

            if ctrl and value ~= nil then
                local old = ctrl:get()
                local changed = ctrl:set(value, {
                    internal = true,
                    prepared = true,
                    noHistory = true,
                    silent = true,
                })

                table.insert(completed, {ctrl = ctrl, old = old})

                if changed then
                    table.insert(changes, {
                        ctrl = ctrl,
                        value = ctrl:get(),
                    })
                end
            end
        end
    end)

    if not ok then
        for i = #completed, 1, -1 do
            local entry = completed[i]
            pcall(function()
                entry.ctrl:set(entry.old, {
                    internal = true,
                    prepared = true,
                    noHistory = true,
                    silent = true,
                })
            end)
        end

        self._busy = false
        return false, tostring(err)
    end

    self.PendingConfig = unknown
    table.clear(self.UndoStack)
    table.clear(self.RedoStack)
    self._busy = false

    for _, change in ipairs(changes) do
        local ctrl, value = change.ctrl, copy(change.value)
        spawnOwned(function()
            if alive() and not ctrl.scope.dead
                and type(ctrl.callback) == "function" then
                ctrl.callback(copy(value))
            end
        end)
    end

    local applied, pending = 0, 0
    for _ in pairs(staged) do applied += 1 end
    for _ in pairs(unknown) do pending += 1 end

    return true, {applied = applied, skipped = pending, pending = pending}
end

local function encodeValue(v, seen, depth)
    depth = depth or 0
    assert(depth <= 64, "Configuration nesting is too deep")

    if typeof(v) == "Color3" then
        assert(finite(v.R) and finite(v.G) and finite(v.B), "Invalid Color3")
        return {__type = "Color3", R = v.R, G = v.G, B = v.B}
    end

    local kind = type(v)

    if kind == "number" then
        assert(finite(v), "Non-finite number")
        return v
    elseif kind == "string" or kind == "boolean" then
        return v
    elseif kind ~= "table" then
        error("Unsupported config value: " .. typeof(v))
    end

    seen = seen or {}
    assert(not seen[v], "Cyclic configuration")
    seen[v] = true

    local out = {}
    local keyKind

    for key, item in pairs(v) do
        local currentKind = type(key)
        assert(
            currentKind == "string"
                or (finite(key) and key >= 1 and key % 1 == 0),
            "Invalid configuration key"
        )
        assert(not keyKind or keyKind == currentKind, "Mixed table keys")
        keyKind = currentKind
        out[key] = encodeValue(item, seen, depth + 1)
    end

    if keyKind == "number" then
        local count = 0
        for _ in pairs(out) do count += 1 end
        assert(count == #out, "Sparse arrays are unsupported")
    end

    seen[v] = nil
    return out
end

local function decodeValue(v, depth)
    depth = depth or 0
    assert(depth <= 64, "Configuration nesting is too deep")

    if type(v) ~= "table" then
        if type(v) == "number" then
            assert(finite(v), "Invalid number")
        end
        return v
    end

    if v.__type ~= nil then
        assert(v.__type == "Color3", "Unknown serialized type")
        for _, key in ipairs({"R", "G", "B"}) do
            assert(finite(v[key]) and v[key] >= 0 and v[key] <= 1, "Invalid Color3")
        end
        return Color3.new(v.R, v.G, v.B)
    end

    local out = {}
    for key, value in pairs(v) do
        out[key] = decodeValue(value, depth + 1)
    end
    return out
end

function JustHub:ExportConfig()
    if not alive() then
        return false, "Library is destroyed"
    end

    local snapshot = copy(self.PendingConfig)
    for id, value in pairs(self.ConfigData) do
        snapshot[id] = copy(value)
    end

    return pcall(function()
        return HttpService:JSONEncode(encodeValue(snapshot))
    end)
end

function JustHub:ImportConfig(json)
    if type(json) ~= "string" then
        return false, "Expected JSON string"
    end

    local ok, result = pcall(function()
        local decoded = HttpService:JSONDecode(json)
        assert(type(decoded) == "table", "Expected configuration object")
        return decodeValue(decoded)
    end)

    if not ok then
        return false, tostring(result)
    end

    return self:ApplyConfig(result)
end

function JustHub:SaveConfig(name)
    name = name or "JustHub_Config.json"

    if not safeFilename(name) then
        return false, "Invalid filename"
    end

    local adapter = self.FileAdapter
    if not adapter then
        return false, "SetFileAdapter is required; alternatively use ExportConfig"
    end

    local ok, json = self:ExportConfig()
    if not ok then
        return false, json
    end

    local written, result, reason = pcall(adapter.write, name, json)
    if not written then
        return false, tostring(result)
    end
    if result == false then
        return false, reason or "Write rejected"
    end
    return true
end

function JustHub:LoadConfig(name)
    name = name or "JustHub_Config.json"

    if not safeFilename(name) then
        return false, "Invalid filename"
    end

    if not self.FileAdapter then
        return false, "SetFileAdapter is required; alternatively use ImportConfig"
    end

    local ok, json = pcall(self.FileAdapter.read, name)
    if not ok then
        return false, tostring(json)
    end

    return self:ImportConfig(json)
end

function JustHub:RegisterTheme(name, definition)
    if type(name) ~= "string" or name == "" or not validTheme(definition) then
        return false, "Invalid theme"
    end

    self.Themes[name] = copy(definition)
    return true
end

function JustHub:UpdateThemeObject(obj, prop, key)
    if not alive() or not obj or not theme()[key] then
        return false
    end
    bindTheme(obj, prop, key)
    return true
end

function JustHub:UpdateTheme(value)
    if not alive() then
        return false
    end

    local definition = type(value) == "table" and value or self.Themes[value]
    if not validTheme(definition) then
        return false, "Unknown or invalid theme"
    end

    self.Save.Theme = type(value) == "table" and copy(value) or value

    for obj, properties in pairs(self.ThemeObjects) do
        if obj.Parent then
            for prop, key in pairs(properties) do
                local chroma = self.ChromaObjects[obj]
                if not (self.ChromaEnabled and chroma and chroma[prop]) then
                    cancelProperty(obj, prop)
                    obj[prop] = theme()[key]
                end
            end
        else
            self.ThemeObjects[obj] = nil
        end
    end

    return true
end

function JustHub:SetTheme(value)
    return self:UpdateTheme(value)
end

local function updateChroma()
    if chromaConnection then
        chromaConnection:Disconnect()
        chromaConnection = nil
    end

    if not alive() or not JustHub.ChromaEnabled
        or not next(JustHub.ChromaObjects) then
        return
    end

    chromaConnection = RunService.Heartbeat:Connect(function()
        local color = Color3.fromHSV((os.clock() % 5) / 5, 1, 1)

        for obj, properties in pairs(JustHub.ChromaObjects) do
            if not obj.Parent then
                JustHub.ChromaObjects[obj] = nil
            else
                for prop in pairs(properties) do
                    obj[prop] = color
                end
            end
        end

        if not next(JustHub.ChromaObjects) then
            updateChroma()
        end
    end)
end

local function registerChroma(obj, prop, key)
    JustHub.ChromaObjects[obj] = JustHub.ChromaObjects[obj] or {}
    JustHub.ChromaObjects[obj][prop] = key
    if not chromaConnection then
        updateChroma()
    end
end

function JustHub:UnregisterChroma(obj, prop)
    local properties = self.ChromaObjects[obj]
    if properties then
        if prop then
            properties[prop] = nil
            if not next(properties) then
                self.ChromaObjects[obj] = nil
            end
        else
            self.ChromaObjects[obj] = nil
        end
    end
    updateChroma()
end

function JustHub:ToggleChroma(enabled)
    if not alive() or type(enabled) ~= "boolean" then
        return false
    end

    self.ChromaEnabled = enabled
    updateChroma()

    if not enabled then
        for obj, properties in pairs(self.ChromaObjects) do
            if obj.Parent then
                for prop, key in pairs(properties) do
                    obj[prop] = theme()[key]
                end
            end
        end
    end
    return true
end

function JustHub:SetTransparency(alpha)
    alpha = tonumber(alpha)
    if not alive() or not finite(alpha) then
        return false, "Expected finite transparency"
    end

    self.Save.Transparency = math.clamp(alpha, 0, 1)

    for obj, offset in pairs(surfaces) do
        if obj.Parent then
            cancelProperty(obj, "BackgroundTransparency")
            obj.BackgroundTransparency = math.clamp(
                self.Save.Transparency + (1 - self.Save.Transparency) * offset,
                0, 1
            )
        else
            surfaces[obj] = nil
        end
    end
    return true
end

function JustHub:SetUserRole(role)
    if type(role) ~= "string" then return false end
    self.UserRole = role
    return true
end

function JustHub:CheckRole(role)
    return self.UserRole == role
end

function JustHub:SetLanguage(lang)
    if type(lang) ~= "string" then return false end
    self.CurrentLang = lang
    return true
end

function JustHub:LocalizeText(key)
    local dict = self.Localization[self.CurrentLang]
    return dict and dict[key] or key
end

function JustHub:SetKey(key)
    if type(key) ~= "string" then return false end
    self.KeySystem.Enabled = true
    self.KeySystem.Key = key
    return true
end

function JustHub:CheckKey(key)
    return not self.KeySystem.Enabled or key == self.KeySystem.Key
end

function JustHub:PlaySound(name)
    local id = self.Sounds[name]
    if not alive() or not id or id == 0 then return end

    local sound = make("Sound", {
        SoundId = "rbxassetid://" .. tostring(id),
        Volume = 1,
        PlayOnRemove = true,
    }, workspace)
    sound:Destroy()
end

local Section = {}

local function row(section, name, height)
    assert(alive() and section.Content.Parent, "Section is destroyed")
    section._count += 1

    local frame = make("Frame", {
        Name = name,
        Size = UDim2.new(1, 0, 0, height or 42),
        BorderSizePixel = 0,
        LayoutOrder = section._count,
    }, section.Content)

    bindTheme(frame, "BackgroundColor3", "Color Hub 2")
    surface(frame, 0.35)
    corner(frame, 9)
    border(frame)

    local scope = newScope(frame)
    section:_filter()
    return frame, scope
end

local function titleOf(options, fallback)
    return tostring(options.Name or fallback)
end

function Section:addMenu(name)
    local frame = row(self, tostring(name or "Menu"), 38)
    local label = text(frame, name or "Menu")
    label.Font = Enum.Font.GothamBold
    return frame
end

function Section:addLabel(options)
    options = type(options) == "string" and {Text = options} or options or {}
    local frame, scope = row(self, tostring(options.Text or options.Name or "Label"), 34)
    frame.BackgroundTransparency = 1
    surfaces[frame] = nil

    local label = text(frame, options.Text or options.Name or "Label")
    label.TextWrapped = true
    label.TextXAlignment = options.Align == "Center"
        and Enum.TextXAlignment.Center
        or options.Align == "Right"
        and Enum.TextXAlignment.Right
        or Enum.TextXAlignment.Left

    return {
        SetText = function(_, value)
            if alive() and not scope.dead then
                label.Text = tostring(value)
            end
        end,
        Frame = frame,
    }
end

function Section:addToggle(options)
    options = options or {}
    local name = titleOf(options, "Toggle")
    local frame, scope = row(self, name)
    text(frame, name, UDim2.new(0.65, -10, 1, 0))

    local btn = button(frame, "", UDim2.fromOffset(64, 26), UDim2.new(1, -74, 0.5, -13))
    local ctrl = model(self, scope, name, options.Default == true, function(v)
        assert(type(v) == "boolean", "Toggle expects boolean")
        return v
    end, function(v)
        btn.Text = v and "ON" or "OFF"
        bindTheme(btn, "BackgroundColor3", v and "Color Theme" or "Color Hub 1")

        if v then
            registerChroma(btn, "BackgroundColor3", "Color Theme")
        else
            JustHub:UnregisterChroma(btn, "BackgroundColor3")
        end
    end, options.Callback)

    scope:connect(btn.Activated, function()
        ctrl:set(not ctrl:get())
    end)

    local revision = ctrl.revision
    spawnOwned(function()
        if not scope.dead and ctrl.revision == revision
            and type(options.Callback) == "function" then
            options.Callback(ctrl:get())
        end
    end)

    return frame
end

function Section:addChromaToggle()
    return self:addToggle({
        Name = "Rainbow Chroma Mode",
        Default = JustHub.ChromaEnabled,
        Callback = function(value)
            JustHub:ToggleChroma(value)
        end,
    })
end

function Section:addSlider(options)
    options = options or {}
    local name = titleOf(options, "Slider")
    local min = number(options.Min, 0)
    local max = number(options.Max, 100)
    local step = number(options.Step or options.Float, 1)

    assert(max > min and finite(max - min), "Invalid slider range")
    assert(step > 0, "Slider step must be positive")

    local function normalize(v)
        assert(finite(v), "Slider expects finite number")
        v = math.clamp(v, min, max)
        if v >= max then return max end
        return math.clamp(min + math.floor((v - min) / step + 0.5) * step, min, max)
    end

    local frame, scope = row(self, name, 58)
    text(frame, name, UDim2.new(0.65, -10, 0, 25))
    local box = textbox(frame, "", UDim2.fromOffset(70, 22), UDim2.new(1, -80, 0, 3))
    local track = button(frame, "", UDim2.new(1, -20, 0, 14), UDim2.fromOffset(10, 35))
    local fill = make("Frame", {
        Size = UDim2.new(),
        BorderSizePixel = 0,
    }, track)
    corner(fill, 7)
    bindTheme(fill, "BackgroundColor3", "Color Theme")
    registerChroma(fill, "BackgroundColor3", "Color Theme")

    local ctrl = model(self, scope, name, number(options.Default, min), normalize, function(v)
        box.Text = string.format("%.10g", v)
        fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
    end, options.Callback)

    local active

    local function pick(input)
        local ratio = math.clamp(
            (input.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X),
            0, 1
        )
        ctrl:set(min + ratio * (max - min), {noHistory = true})
    end

    local function finish()
        if active then
            active = nil
            ctrl:endEdit()
        end
    end

    scope:connect(track.InputBegan, function(input)
        if active then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            active = input
            ctrl:beginEdit()
            pick(input)
        end
    end)

    scope:connect(UserInputService.InputChanged, function(input)
        if active and (
            input == active
            or active.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseMovement
        ) then
            pick(input)
        end
    end)

    scope:connect(UserInputService.InputEnded, function(input)
        if active and (
            input == active
            or active.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseButton1
        ) then
            finish()
        end
    end)

    scope:connect(UserInputService.WindowFocusReleased, finish)

    scope:connect(box.FocusLost, function()
        local value = tonumber(box.Text)
        if finite(value) then
            ctrl:set(value)
        else
            ctrl.render(ctrl:get())
        end
    end)

    local revision = ctrl.revision
    spawnOwned(function()
        if not scope.dead and ctrl.revision == revision
            and type(options.Callback) == "function" then
            options.Callback(ctrl:get())
        end
    end)

    return frame
end

function Section:addTextBox(options)
    options = options or {}
    local name = titleOf(options, "TextBox")
    local frame, scope = row(self, name)
    text(frame, name, UDim2.new(0.4, -10, 1, 0))

    local box = textbox(
        frame,
        "",
        UDim2.new(0.6, -20, 0, 28),
        UDim2.new(0.4, 10, 0.5, -14)
    )
    box.PlaceholderText = "Input here..."

    local ctrl = model(self, scope, name, options.Default or "", function(v)
        assert(type(v) == "string", "TextBox expects string")
        return v
    end, function(v)
        if box.Text ~= v then box.Text = v end
    end, options.Callback)

    scope:connect(box.Focused, function() ctrl:beginEdit() end)
    scope:connect(box:GetPropertyChangedSignal("Text"), function()
        if box:IsFocused() then
            ctrl:set(box.Text, {noHistory = true})
        end
    end)
    scope:connect(box.FocusLost, function()
        ctrl:set(box.Text, {noHistory = true})
        ctrl:endEdit()
    end)

    return frame
end

function Section:addScriptBox(options)
    options = options or {}
    local name = titleOf(options, "ScriptBox")
    local frame, scope = row(self, name, 112)
    text(frame, name, UDim2.new(1, -20, 0, 25))

    local box = textbox(frame, "", UDim2.new(1, -82, 0, 72), UDim2.fromOffset(10, 30))
    box.MultiLine = true
    box.TextWrapped = true
    box.Font = Enum.Font.Code
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.TextYAlignment = Enum.TextYAlignment.Top

    local run = button(frame, "Run", UDim2.fromOffset(52, 32), UDim2.new(1, -62, 0, 30))
    local ctrl = model(self, scope, name, options.Default or "", function(v)
        assert(type(v) == "string", "ScriptBox expects string")
        return v
    end, function(v)
        if box.Text ~= v then box.Text = v end
    end, nil)

    scope:connect(box.Focused, function() ctrl:beginEdit() end)
    scope:connect(box:GetPropertyChangedSignal("Text"), function()
        if box:IsFocused() then
            ctrl:set(box.Text, {noHistory = true})
        end
    end)
    scope:connect(box.FocusLost, function()
        ctrl:set(box.Text, {noHistory = true})
        ctrl:endEdit()
    end)
    scope:connect(run.Activated, function()
        ctrl:set(box.Text, {noHistory = true})
        ctrl:endEdit()
        callback(options.Callback, ctrl:get())
    end)

    return frame
end

local function dropdown(section, options, multiple)
    options = options or {}
    local name = titleOf(options, multiple and "Multi Dropdown" or "Dropdown")
    local frame, scope = row(section, name, 42)
    frame.ClipsDescendants = true

    local header = button(frame, name, UDim2.new(1, -20, 0, 30), UDim2.fromOffset(10, 6))
    local body = make("Frame", {
        Position = UDim2.fromOffset(10, 45),
        Size = UDim2.new(1, -20, 0, 165),
        BackgroundTransparency = 1,
    }, frame)

    local search = textbox(body, "", UDim2.new(1, 0, 0, 25))
    search.PlaceholderText = "Search..."

    local scrollY = multiple and 58 or 30
    local scroll = make("ScrollingFrame", {
        Position = UDim2.fromOffset(0, scrollY),
        Size = UDim2.new(1, 0, 1, -scrollY),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 3,
    }, body)
    list(scroll, 4)

    local cache = {}
    local itemScope
    local opened = false
    local ctrl

    local function close()
        opened = false
        frame.Size = UDim2.new(1, 0, 0, 42)
        if JustHub._openDropdown == close then
            JustHub._openDropdown = nil
        end
    end

    local function render(value)
        local label = multiple
            and (#value > 0 and table.concat(value, ", ") or "Select...")
            or (value ~= "" and value or "Select...")

        header.Text = name .. ": " .. label

        local selected = {}
        if multiple then
            for _, item in ipairs(value) do selected[item] = true end
        else
            selected[value] = true
        end

        local term = search.Text:lower()

        for _, item in ipairs(cache) do
            item.button.Visible = term == ""
                or item.value:lower():find(term, 1, true) ~= nil

            item.button.Text = (selected[item.value] and "✓ " or "")
                .. (item.preset and "★ " or "")
                .. item.value

            bindTheme(
                item.button,
                "TextColor3",
                selected[item.value] and "Color Theme" or "Color Text"
            )
        end
    end

    local function normalize(value)
        if multiple then return selection(value) end
        assert(type(value) == "string", "Dropdown expects string")
        return value
    end

    ctrl = model(
        section, scope, name,
        options.Default or (multiple and {} or ""),
        normalize, render, options.Callback
    )

    local function populate(values)
        values = itemsOrEmpty(values)
        local presets = itemsOrEmpty(options.Presets)

        if itemScope then itemScope:Destroy() end
        itemScope = newScope()
        table.clear(cache)

        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("GuiObject") then child:Destroy() end
        end

        local seen = {}
        local function add(value, preset)
            if seen[value] then return end
            seen[value] = true

            local btn = button(scroll, value, UDim2.new(1, -4, 0, 28))
            local entry = {value = value, preset = preset, button = btn}
            table.insert(cache, entry)

            itemScope:connect(btn.Activated, function()
                if multiple then
                    local selected = {}
                    for _, current in ipairs(ctrl:get()) do
                        selected[current] = true
                    end
                    selected[value] = not selected[value]

                    local nextValue = {}
                    for current, enabled in pairs(selected) do
                        if enabled then table.insert(nextValue, current) end
                    end
                    ctrl:set(nextValue)
                else
                    ctrl:set(value)
                    close()
                end
            end)
        end

        for _, value in ipairs(presets) do add(value, true) end
        for _, value in ipairs(values) do add(value, false) end
        render(ctrl:get())
    end

    if multiple then
        local all = button(body, "Select All", UDim2.new(0.5, -3, 0, 24), UDim2.fromOffset(0, 29))
        local clear = button(body, "Clear All", UDim2.new(0.5, -3, 0, 24), UDim2.new(0.5, 3, 0, 29))

        scope:connect(all.Activated, function()
            local values = {}
            for _, item in ipairs(cache) do
                table.insert(values, item.value)
            end
            ctrl:set(values)
        end)
        scope:connect(clear.Activated, function() ctrl:set({}) end)
    end

    scope:connect(search:GetPropertyChangedSignal("Text"), function()
        render(ctrl:get())
    end)

    scope:connect(header.Activated, function()
        if opened then
            close()
        else
            if JustHub._openDropdown then JustHub._openDropdown() end
            opened = true
            JustHub._openDropdown = close
            frame.Size = UDim2.new(1, 0, 0, 220)
            search.Text = ""
            render(ctrl:get())
        end
    end)

    scope:cleanup(function()
        close()
        if itemScope then itemScope:Destroy() end
    end)

    populate(options.Items)

    return {
        Frame = frame,
        Refresh = function(_, values)
            assert(not scope.dead, "Dropdown is destroyed")
            populate(values)
        end,
        Clear = function()
            ctrl:set(multiple and {} or "")
            close()
        end,
        GetValue = function() return ctrl:get() end,
        SetValue = function(_, value) return ctrl:set(value) end,
    }
end

function Section:addDropdown(options)
    return dropdown(self, options, false)
end

function Section:addMultiDropdown(options)
    return dropdown(self, options, true)
end

function Section:addColorPicker(options)
    options = options or {}
    local name = titleOf(options, "ColorPicker")
    local frame, scope = row(self, name, 92)
    text(frame, name, UDim2.new(1, -20, 0, 25))

    local preview = make("Frame", {
        Size = UDim2.fromOffset(35, 22),
        Position = UDim2.new(1, -45, 0, 4),
        BorderSizePixel = 0,
    }, frame)
    corner(preview, 5)

    local boxes = {}
    for index = 1, 4 do
        boxes[index] = textbox(
            frame, "",
            UDim2.new(0.25, -13, 0, 28),
            UDim2.new((index - 1) * 0.25, 10, 0, 40)
        )
    end

    local ctrl = model(
        self, scope, name,
        options.Default or Color3.new(1, 1, 1),
        function(value)
            assert(typeof(value) == "Color3", "Expected Color3")
            for _, channel in ipairs({value.R, value.G, value.B}) do
                assert(finite(channel) and channel >= 0 and channel <= 1, "Invalid color channel")
            end
            return value
        end,
        function(value)
            preview.BackgroundColor3 = value
            boxes[1].Text = tostring(math.round(value.R * 255))
            boxes[2].Text = tostring(math.round(value.G * 255))
            boxes[3].Text = tostring(math.round(value.B * 255))
            boxes[4].Text = "#" .. value:ToHex():upper()
        end,
        options.Callback
    )

    local function applyRGB()
        local channels = {}
        for i = 1, 3 do
            local value = tonumber(boxes[i].Text)
            if not finite(value) then
                ctrl.render(ctrl:get())
                return
            end
            channels[i] = math.round(math.clamp(value, 0, 255))
        end
        ctrl:set(Color3.fromRGB(table.unpack(channels)))
    end

    for i = 1, 3 do
        scope:connect(boxes[i].FocusLost, applyRGB)
    end

    scope:connect(boxes[4].FocusLost, function()
        local hex = boxes[4].Text:gsub("^#", "")
        if #hex ~= 6 or not hex:match("^%x+$") then
            ctrl.render(ctrl:get())
            return
        end
        ctrl:set(Color3.fromHex(hex))
    end)

    return frame
end

local keyBlacklist = {
    W = true, A = true, S = true, D = true,
    Space = true, Escape = true, Tab = true,
    Backspace = true, Return = true, Unknown = true,
}

local function normalizeKey(value)
    if typeof(value) == "EnumItem" and value.EnumType == Enum.KeyCode then
        value = value.Name
    end

    assert(type(value) == "string", "Expected key name")
    if value:lower() == "none" then return "None" end

    for _, key in ipairs(Enum.KeyCode:GetEnumItems()) do
        if key.Name:lower() == value:lower() then
            assert(not keyBlacklist[key.Name], "Key is reserved")
            return key.Name
        end
    end

    error("Unknown key: " .. value)
end

function Section:addBind(options)
    options = options or {}
    local name = titleOf(options, "KeyBind")
    local frame, scope = row(self, name)
    text(frame, name, UDim2.new(0.6, -10, 1, 0))

    local btn = button(frame, "", UDim2.new(0.4, -20, 0, 28), UDim2.new(0.6, 10, 0.5, -14))
    local ctrl = model(
        self, scope, name,
        options.Default or "RightShift",
        normalizeKey,
        function(value) btn.Text = value end,
        nil
    )

    local function cancelCapture()
        if JustHub._capture and JustHub._capture.owner == ctrl then
            JustHub._capture = nil
            btn.Text = ctrl:get()
        end
    end

    scope:connect(btn.Activated, function()
        if JustHub._capture then JustHub._capture.cancel() end
        JustHub._capture = {owner = ctrl, cancel = cancelCapture}
        btn.Text = "Press Key..."
    end)

    scope:connect(UserInputService.InputBegan, function(input, processed)
        local capture = JustHub._capture

        if capture then
            if capture.owner ~= ctrl then return end
            if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

            local value = input.KeyCode.Name
            cancelCapture()

            if value == "Escape" then return end
            if value == "Backspace" then
                ctrl:set("None")
                return
            end

            local ok, key = pcall(normalizeKey, value)
            if ok then ctrl:set(key) end
            return
        end

        if processed or UserInputService:GetFocusedTextBox() then return end

        if ctrl:get() ~= "None" and input.KeyCode.Name == ctrl:get() then
            callback(options.Callback)
        end
    end)

    scope:connect(UserInputService.WindowFocusReleased, cancelCapture)
    scope:cleanup(cancelCapture)
    return frame
end

function Section:addButton(options)
    options = options or {}
    local name = titleOf(options, "Button")
    local frame, scope = row(self, name)
    text(frame, name, UDim2.new(0.6, -10, 1, 0))

    local btn = button(
        frame, options.ButtonText or "Click",
        UDim2.new(0.4, -20, 0, 28),
        UDim2.new(0.6, 10, 0.5, -14)
    )

    scope:connect(btn.Activated, function()
        JustHub:PlaySound("ButtonClick")
        callback(options.Callback)
    end)

    return frame
end

function Section:addConfigManager()
    local frame, scope = row(self, "ConfigManager", 124)
    local box = textbox(frame, "DefaultConfig", UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 8))
    local save = button(frame, "Save", UDim2.new(0.5, -15, 0, 28), UDim2.fromOffset(10, 44))
    local load = button(frame, "Load", UDim2.new(0.5, -15, 0, 28), UDim2.new(0.5, 5, 0, 44))
    local delete = button(frame, "Delete", UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 80))

    local function filename()
        local name = box.Text
        if not name:lower():match("%.json$") then name ..= ".json" end
        return name
    end

    local function report(ok, info)
        JustHub:Notify({
            Title = "Config Manager",
            Message = ok and "Operation completed" or (
                type(info) == "table"
                    and "Configuration validation failed"
                    or tostring(info)
            ),
        })
    end

    scope:connect(save.Activated, function()
        report(JustHub:SaveConfig(filename()))
    end)

    scope:connect(load.Activated, function()
        report(JustHub:LoadConfig(filename()))
    end)

    scope:connect(delete.Activated, function()
        local name = filename()
        local adapter = JustHub.FileAdapter

        if not safeFilename(name) then
            report(false, "Invalid filename")
        elseif not adapter or type(adapter.delete) ~= "function" then
            report(false, "File adapter has no delete function")
        else
            local ok, result, reason = pcall(adapter.delete, name)
            report(ok and result ~= false, ok and reason or result)
        end
    end)

    return frame
end

function JustHub:CreateWindow(options)
    if not alive() then return nil, "Library is destroyed" end
    if self.Window then return nil, "Only one live window is supported" end

    options = options or {}

    if options.Theme then
        local ok, err = self:SetTheme(options.Theme)
        if not ok then return nil, err end
    end

    self.Save.Transparency = math.clamp(number(self.Save.Transparency, 0.15), 0, 1)

    local gui = make("ScreenGui", {
        Name = "JustHub",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, parentGui)

    table.insert(self.ScreenGuis, gui)
    self.ScreenGui = gui

    local scope = newScope(gui)
    local main = make("Frame", {
        Name = "MainFrame",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(620, 440),
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Active = true,
    }, gui)

    bindTheme(main, "BackgroundColor3", "Color Hub 2")
    surface(main, 0)
    corner(main, 14)
    registerChroma(border(main), "Color", "Color Stroke")

    local top = make("Frame", {
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundTransparency = 1,
        Active = true,
    }, main)

    local title = text(top, options.Name or "JustHub Window", UDim2.new(1, -170, 0, 25))
    title.Font = Enum.Font.GothamBold
    local subtitle = text(top, options.SubTitle or "", UDim2.new(1, -170, 0, 18), UDim2.fromOffset(10, 27))
    subtitle.TextSize = 10
    bindTheme(subtitle, "TextColor3", "Color Dark Text")

    local lock = button(top, "L", UDim2.fromOffset(28, 26), UDim2.new(1, -130, 0, 10))
    local minimize = button(top, "−", UDim2.fromOffset(28, 26), UDim2.new(1, -98, 0, 10))
    local maximize = button(top, "□", UDim2.fromOffset(28, 26), UDim2.new(1, -66, 0, 10))
    local hide = button(top, "×", UDim2.fromOffset(28, 26), UDim2.new(1, -34, 0, 10))

    local sidebar = make("ScrollingFrame", {
        Name = "Sidebar",
        Position = UDim2.fromOffset(10, 58),
        Size = UDim2.new(0, 135, 1, -84),
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
    }, main)
    bindTheme(sidebar, "BackgroundColor3", "Color Hub 1")
    surface(sidebar, 0.2)
    corner(sidebar, 10)
    list(sidebar, 5)

    local content = make("Frame", {
        Position = UDim2.fromOffset(155, 58),
        Size = UDim2.new(1, -165, 1, -84),
        BackgroundTransparency = 1,
    }, main)

    local search = textbox(content, "", UDim2.new(1, 0, 0, 28))
    search.PlaceholderText = "Search controls..."
    local tabs = make("Frame", {
        Position = UDim2.fromOffset(0, 36),
        Size = UDim2.new(1, 0, 1, -36),
        BackgroundTransparency = 1,
    }, content)

    local footer = text(main, "JustHub • " .. player.DisplayName, UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 1, -20))
    footer.TextSize = 10

    local grip = button(main, "⌟", UDim2.fromOffset(22, 22), UDim2.new(1, -24, 1, -24))
    grip.ZIndex = 5

    local notifications = make("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -12, 1, -12),
        Size = UDim2.new(0, 280, 1, -24),
        BackgroundTransparency = 1,
        ZIndex = 20,
    }, gui)
    local notificationLayout = list(notifications, 8)
    notificationLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
    self.NotificationContainer = notifications

    local show = button(gui, "Show UI", UDim2.fromOffset(90, 32), UDim2.new(0.5, -45, 0, 10))
    show.Visible = false

    local window = {
        ScreenGui = gui,
        MainFrame = main,
        TopBar = top,
        Sidebar = sidebar,
        ContentContainer = tabs,
        Tabs = {},
    }
    self.Window = window

    local mode = "normal"
    local restoreMode = "normal"
    local normalPosition = UDim2.fromScale(0.5, 0.5)
    local requestedWidth = math.max(220, number(self.Save.UISize[1], 620))
    local requestedHeight = math.max(180, number(self.Save.UISize[2], 440))
    local locked = self.Save.Locked == true
    local gesture
    local layout

    local function viewport()
        local camera = workspace.CurrentCamera
        local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
        return Vector2.new(math.max(1, size.X), math.max(1, size.Y))
    end

    local function finishGesture()
        gesture = nil
    end

    layout = function()
        if scope.dead then return end
        local size = viewport()
        local width = math.min(requestedWidth, math.max(1, size.X - 16))
        local height = math.min(requestedHeight, math.max(1, size.Y - 16))

        main.Visible = mode ~= "hidden"
        show.Visible = mode == "hidden"

        local panelVisible = mode ~= "minimized"
        sidebar.Visible = panelVisible
        content.Visible = panelVisible
        footer.Visible = panelVisible
        grip.Visible = mode == "normal" and not locked

        local actualWidth = width

        if mode == "maximized" then
            actualWidth = math.max(1, size.X - 16)
            main.Size = UDim2.fromOffset(actualWidth, math.max(1, size.Y - 16))
            main.Position = UDim2.fromScale(0.5, 0.5)
        elseif mode == "minimized" then
            main.Size = UDim2.fromOffset(width, 50)
            main.Position = normalPosition
        elseif mode == "normal" then
            main.Size = UDim2.fromOffset(width, height)
            main.Position = normalPosition
        end

        local sideWidth = math.clamp(
            actualWidth * 0.24,
            math.min(64, actualWidth * 0.25),
            math.max(64, number(JustHub.Save.TabSize, 135))
        )

        sidebar.Size = UDim2.new(0, sideWidth, 1, -84)
        content.Position = UDim2.fromOffset(sideWidth + 20, 58)
        content.Size = UDim2.new(1, -(sideWidth + 30), 1, -84)
        lock.Text = locked and "U" or "L"
    end

    local function setMode(nextMode)
        finishGesture()
        if JustHub._openDropdown then JustHub._openDropdown() end
        mode = nextMode
        layout()
    end

    scope:connect(minimize.Activated, function()
        setMode(mode == "minimized" and "normal" or "minimized")
    end)
    scope:connect(maximize.Activated, function()
        setMode(mode == "maximized" and "normal" or "maximized")
    end)
    scope:connect(hide.Activated, function()
        restoreMode = mode
        setMode("hidden")
    end)
    scope:connect(show.Activated, function()
        setMode(restoreMode)
    end)
    scope:connect(lock.Activated, function()
        locked = not locked
        JustHub.Save.Locked = locked
        finishGesture()
        layout()
    end)

    local function begin(input, kind)
        if gesture or locked or mode ~= "normal" then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        gesture = {
            input = input,
            kind = kind,
            start = input.Position,
            position = main.Position,
            size = main.AbsoluteSize,
        }
    end

    scope:connect(top.InputBegan, function(input)
        local point = input.Position
        if point.X >= main.AbsolutePosition.X + main.AbsoluteSize.X - 140 then return end
        begin(input, "drag")
    end)

    scope:connect(grip.InputBegan, function(input)
        begin(input, "resize")
    end)

    scope:connect(UserInputService.InputChanged, function(input)
        local current = gesture
        if not current or locked or mode ~= "normal" then return end

        if input ~= current.input and not (
            current.input.UserInputType == Enum.UserInputType.MouseButton1
            and input.UserInputType == Enum.UserInputType.MouseMovement
        ) then
            return
        end

        local delta = input.Position - current.start
        local size = viewport()

        if current.kind == "resize" then
            requestedWidth = math.clamp(current.size.X + delta.X, math.min(220, size.X), math.max(1, size.X - 16))
            requestedHeight = math.clamp(current.size.Y + delta.Y, math.min(180, size.Y), math.max(math.min(180, size.Y), size.Y - 16))
            JustHub.Save.UISize = {requestedWidth, requestedHeight}
        else
            local x = current.position.X.Scale * size.X + current.position.X.Offset + delta.X
            local y = current.position.Y.Scale * size.Y + current.position.Y.Offset + delta.Y

            x = math.clamp(x, 30, math.max(30, size.X - 30))
            y = math.clamp(y, 25, math.max(25, size.Y - 25))
            normalPosition = UDim2.fromOffset(x, y)
        end
        layout()
    end)

    scope:connect(UserInputService.InputEnded, function(input)
        if gesture and (
            input == gesture.input
            or gesture.input.UserInputType == Enum.UserInputType.MouseButton1
                and input.UserInputType == Enum.UserInputType.MouseButton1
        ) then
            finishGesture()
        end
    end)
    scope:connect(UserInputService.WindowFocusReleased, finishGesture)

    local cameraConnection
    local function bindCamera()
        if cameraConnection then
            cameraConnection:Disconnect()
            scope.connections[cameraConnection] = nil
        end

        local camera = workspace.CurrentCamera
        if camera then
            cameraConnection = scope:connect(
                camera:GetPropertyChangedSignal("ViewportSize"),
                layout
            )
        end
        layout()
    end

    scope:connect(workspace:GetPropertyChangedSignal("CurrentCamera"), bindCamera)
    bindCamera()

    local function filter()
        local term = search.Text:lower()
        for _, tab in ipairs(window.Tabs) do
            for _, section in ipairs(tab.Sections) do
                local any = false
                for _, child in ipairs(section.Content:GetChildren()) do
                    if child:IsA("GuiObject") then
                        local visible = term == ""
                            or child.Name:lower():find(term, 1, true) ~= nil
                            or section._sectionName:lower():find(term, 1, true) ~= nil
                        child.Visible = visible
                        any = any or visible
                    end
                end
                section.Frame.Visible = any or term == ""
            end
        end
    end
    scope:connect(search:GetPropertyChangedSignal("Text"), filter)

    function window:addTab(name, iconName)
        assert(alive() and not scope.dead, "Window is destroyed")
        name = tostring(name or "Tab")

        local btn = button(sidebar, name, UDim2.new(1, -4, 0, 34))
        btn.LayoutOrder = #self.Tabs + 1

        local page = make("ScrollingFrame", {
            Name = name .. "Content",
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            ScrollBarThickness = 3,
            Visible = false,
        }, tabs)
        list(page, 10)

        local tab = {
            Name = name,
            Button = btn,
            TextLabel = nil,
            Content = page,
            Sections = {},
        }
        table.insert(self.Tabs, tab)

        local function activate()
            if JustHub._openDropdown then JustHub._openDropdown() end
            for _, candidate in ipairs(window.Tabs) do
                local selected = candidate == tab
                candidate.Content.Visible = selected
                bindTheme(
                    candidate.Button,
                    "TextColor3",
                    selected and "Color Theme" or "Color Text"
                )
            end
        end

        scope:connect(btn.Activated, activate)
        if #self.Tabs == 1 then activate() end

        function tab:addSection(sectionName)
            assert(alive() and not scope.dead, "Window is destroyed")
            sectionName = tostring(sectionName or "Section")

            local frame = make("Frame", {
                Name = sectionName,
                Size = UDim2.new(1, -5, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder = #self.Sections + 1,
            }, page)

            list(frame, 4)
            local heading = text(frame, sectionName, UDim2.new(1, 0, 0, 28), UDim2.new())
            heading.LayoutOrder = 0
            heading.Font = Enum.Font.GothamBold

            local body = make("Frame", {
                Name = "SectionContent",
                Size = UDim2.new(1, 0, 0, 0),
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                LayoutOrder = 1,
            }, frame)
            list(body, 8)

            local section = setmetatable({
                Frame = frame,
                Title = heading,
                Content = body,
                _tabName = name,
                _sectionName = sectionName,
                _count = 0,
                _filter = filter,
            }, {__index = Section})

            table.insert(self.Sections, section)
            filter()
            return section
        end

        return tab
    end

    function window:SetState(state)
        if state ~= "normal" and state ~= "maximized"
            and state ~= "minimized" and state ~= "hidden" then
            return false
        end

        if state == "hidden" and mode ~= "hidden" then restoreMode = mode end
        setMode(state)
        return true
    end

    function window:GetState()
        return mode
    end

    function window:Destroy()
        JustHub:Destroy()
    end

    scope:cleanup(function()
        if alive() then JustHub:Destroy() end
    end)

    return window
end

function JustHub:ToggleUIVisibility()
    if not alive() or not self.ScreenGui or not self.ScreenGui.Parent then
        return false
    end
    self.ScreenGui.Enabled = not self.ScreenGui.Enabled
    return self.ScreenGui.Enabled
end

function JustHub:ShowLoadingScreen(duration, done)
    if not alive() then return false end
    duration = math.max(0, number(duration, 3))

    local gui = make("ScreenGui", {
        Name = "JustHubLoadingScreen",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 100,
    }, parentGui)
    table.insert(self.ScreenGuis, gui)

    local scope = newScope(gui)
    local backdrop = make("Frame", {
        Size = UDim2.fromScale(1, 1),
        BorderSizePixel = 0,
    }, gui)
    bindTheme(backdrop, "BackgroundColor3", "Color Hub 1")
    local label = text(backdrop, "JustHub Library", UDim2.fromOffset(260, 40), UDim2.new(0.5, -130, 0.5, -45))
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextSize = 22

    local bar = make("Frame", {
        Size = UDim2.fromOffset(280, 8),
        Position = UDim2.new(0.5, -140, 0.5, 12),
        BorderSizePixel = 0,
    }, backdrop)
    bindTheme(bar, "BackgroundColor3", "Color Hub 2")
    corner(bar, 4)

    local fill = make("Frame", {
        Size = UDim2.fromScale(0, 1),
        BorderSizePixel = 0,
    }, bar)
    bindTheme(fill, "BackgroundColor3", "Color Theme")
    corner(fill, 4)

    local tween = animate(fill, {Size = UDim2.fromScale(1, 1)}, duration)
    if not tween then gui:Destroy(); return false end

    scope:connect(tween.Completed, function(state)
        if state ~= Enum.PlaybackState.Completed then return end
        gui:Destroy()

        for i = #JustHub.ScreenGuis, 1, -1 do
            if JustHub.ScreenGuis[i] == gui then
                table.remove(JustHub.ScreenGuis, i)
            end
        end

        callback(done)
    end)

    return true
end

function JustHub:InitializeUI(options)
    if not alive() or self._initializing or self.Window then
        return false
    end

    self._initializing = true
    local ok = self:ShowLoadingScreen(3, function()
        self._initializing = false
        if alive() then self:CreateWindow(options) end
    end)

    if not ok then self._initializing = false end
    return ok
end

function JustHub:Notify(options)
    if not alive() or not self.NotificationContainer
        or not self.NotificationContainer.Parent then
        return nil
    end

    options = options or {}
    local duration = math.max(0, number(options.Duration, 5))

    local frame = make("Frame", {
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BorderSizePixel = 0,
        ZIndex = 20,
    }, self.NotificationContainer)
    bindTheme(frame, "BackgroundColor3", "Color Hub 2")
    surface(frame, 0.18)
    corner(frame, 9)
    border(frame)

    make("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
    }, frame)
    list(frame, 5)

    local heading = text(frame, options.Title or "", UDim2.new(1, 0, 0, 20), UDim2.new())
    heading.Font = Enum.Font.GothamBold
    heading.LayoutOrder = 1
    heading.ZIndex = 21

    local message = text(frame, options.Message or "", UDim2.new(1, 0, 0, 0), UDim2.new())
    message.AutomaticSize = Enum.AutomaticSize.Y
    message.TextWrapped = true
    message.TextTruncate = Enum.TextTruncate.None
    message.LayoutOrder = 2
    message.ZIndex = 21

    local scope = newScope(frame)
    local progress

    if options.ShowProgress == true then
        progress = make("Frame", {
            Size = UDim2.new(1, 0, 0, 3),
            BorderSizePixel = 0,
            LayoutOrder = 3,
            ZIndex = 21,
        }, frame)
        bindTheme(progress, "BackgroundColor3", "Color Theme")
        registerChroma(progress, "BackgroundColor3", "Color Theme")
    end

    spawnOwned(function()
        if scope.dead then return end
        if progress then
            animate(progress, {Size = UDim2.new(0, 0, 0, 3)}, duration)
        end
        task.wait(duration)

        if alive() and not scope.dead then
            frame:Destroy()
        end
    end)

    return frame
end

function JustHub:PromoNotify()
    if not alive() or not self.PromoNotifyEnabled or self._promoThread then
        return false
    end

    self._promoThread = spawnOwned(function()
        while alive() and JustHub.PromoNotifyEnabled
            and JustHub.ScreenGui and JustHub.ScreenGui.Parent do
            JustHub:Notify({
                Title = "JustHub UI",
                Message = "JustHub Library " .. JustHub.Info.Version,
                Duration = 3,
                ShowProgress = true,
            })
            task.wait(30)
        end
        JustHub._promoThread = nil
    end)

    return true
end

function JustHub:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    self._initializing = false

    if self._capture then
        pcall(self._capture.cancel)
        self._capture = nil
    end

    local scopes = {}
    for scope in pairs(self._scopes) do table.insert(scopes, scope) end
    for _, scope in ipairs(scopes) do scope:Destroy() end

    for _, conn in ipairs(self.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(self.Connections)

    if chromaConnection then
        chromaConnection:Disconnect()
        chromaConnection = nil
    end

    local uniqueTweens = {}
    for _, map in pairs(tweens) do
        for _, record in pairs(map) do uniqueTweens[record.tween] = true end
    end
    for tween in pairs(uniqueTweens) do
        pcall(function() tween:Cancel() end)
    end
    table.clear(tweens)

    local current = coroutine.running()
    for thread in pairs(self._threads) do
        if thread ~= current then pcall(task.cancel, thread) end
    end
    table.clear(self._threads)

    for _, gui in ipairs(self.ScreenGuis) do
        pcall(function() gui:Destroy() end)
    end

    for _, tableValue in ipairs({
        self.ScreenGuis,
        self.ThemeObjects,
        self.ChromaObjects,
        self.ControlRegistry,
        self.ControlAliases,
        self.AmbiguousControlAliases,
        self.Controls,
        self.ConfigData,
        self.PendingConfig,
        self.UndoStack,
        self.RedoStack,
        self._models,
        self._ids,
        self._order,
        surfaces,
    }) do
        table.clear(tableValue)
    end

    self.Window = nil
    self.ScreenGui = nil
    self.NotificationContainer = nil
    self._promoThread = nil
    self._openDropdown = nil
end

return JustHub
