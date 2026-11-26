local Modules = {}
Modules.Util = (function()
local Util = {}
function Util.IsFinite(value)
return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
function Util.ClampNumber(value, minimum, maximum, fallback)
local number = tonumber(value)
if not Util.IsFinite(number) then number = fallback or minimum or 0 end
return math.clamp(number, minimum, maximum)
end
function Util.ShallowClone(source)
local copy = {}
if type(source) == "table" then
for key, value in pairs(source) do copy[key] = value end
end
return copy
end
function Util.Clone(value, seen)
if type(value) ~= "table" then return value end
seen = seen or {}
if seen[value] then return seen[value] end
local copy = {}
seen[value] = copy
for key, child in pairs(value) do
copy[Util.Clone(key, seen)] = Util.Clone(child, seen)
end
return copy
end
function Util.DeepEqual(left, right, seen)
if left == right then return true end
if type(left) ~= "table" or type(right) ~= "table" then return false end
seen = seen or {}
if seen[left] == right then return true end
seen[left] = right
for key, value in pairs(left) do
if not Util.DeepEqual(value, right[key], seen) then return false end
end
for key in pairs(right) do
if left[key] == nil then return false end
end
return true
end
function Util.NormalizeStringArray(value)
local result, seen = {}, {}
if type(value) ~= "table" then return result end
for _, item in ipairs(value) do
if type(item) == "string" and item ~= "" and not seen[item] then
seen[item] = true
table.insert(result, item)
end
end
return result
end
function Util.SafeCall(label, callback, ...)
if type(callback) ~= "function" then return false, "Callback is not a function" end
local args = table.pack(...)
local ok, result = xpcall(function()
return callback(table.unpack(args, 1, args.n))
end, debug.traceback)
if not ok then
warn("[JustHub] " .. tostring(label or "Operation") .. ": " .. tostring(result))
end
return ok, result
end
function Util.MakeId(...)
local parts = table.pack(...)
local output = table.create(parts.n)
for index = 1, parts.n do
local value = tostring(parts[index] or "")
value = value:gsub("[%c/\\]+", "_"):gsub("%s+", " ")
output[index] = value
end
return table.concat(output, "/")
end
function Util.SafeDestroy(instance)
if instance then pcall(function() instance:Destroy() end) end
end
function Util.IsDenseArray(value)
if type(value) ~= "table" then return false end
local count, maximum = 0, 0
for key in pairs(value) do
if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false end
count += 1
maximum = math.max(maximum, key)
end
return count == maximum
end
function Util.Trim(value)
local text = tostring(value or "")
text = text:gsub("^%s+", "")
text = text:gsub("%s+$", "")
return text
end
function Util.SanitizeName(value)
local text = tostring(value or "")
text = text:gsub("[^%w_%-]", "")
return text
end
return Util
end)()

Modules.ResourceManager = (function()
local ResourceManager = {}
ResourceManager.__index = ResourceManager
local Scope = {}
Scope.__index = Scope
local function disconnect(connection)
if connection then pcall(function() connection:Disconnect() end) end
end
local function safeDestroy(instance)
if instance then pcall(function() instance:Destroy() end) end
end
local function cancelTween(tween)
if tween then pcall(function() tween:Cancel() end) end
end
function Scope.new(parent, label)
local self = setmetatable({
Label = label or "Scope",
Parent = parent,
Destroyed = false,
Connections = {},
Tweens = {},
Threads = {},
Instances = {},
Cleanups = {},
Children = {},
ActiveTweens = setmetatable({}, {__mode = "k"}),
}, Scope)
if parent then
if parent.Destroyed then
self:Destroy()
else
table.insert(parent.Children, self)
end
end
return self
end
function Scope:IsAlive()
return not self.Destroyed and (not self.Parent or self.Parent:IsAlive())
end
function Scope:CreateScope(label)
return Scope.new(self, label)
end
function Scope:Connect(signal, callback)
if self.Destroyed or not signal then return nil end
local ok, connection = pcall(function() return signal:Connect(callback) end)
if not ok then
warn("[JustHub] Connection failed in " .. self.Label .. ": " .. tostring(connection))
return nil
end
table.insert(self.Connections, connection)
return connection
end
function Scope:Disconnect(connection)
if not connection then return end
disconnect(connection)
for index = #self.Connections, 1, -1 do
if self.Connections[index] == connection then
table.remove(self.Connections, index)
break
end
end
end
function Scope:TrackInstance(instance)
if not instance then return nil end
if self.Destroyed then safeDestroy(instance) return nil end
table.insert(self.Instances, instance)
return instance
end
function Scope:AddCleanup(callback)
if type(callback) ~= "function" then return nil end
if self.Destroyed then pcall(callback) return nil end
table.insert(self.Cleanups, callback)
return callback
end
function Scope:Tween(instance, tweenInfo, goals)
if self.Destroyed or not instance or type(goals) ~= "table" or typeof(tweenInfo) ~= "TweenInfo" then return nil end
local bucket = self.ActiveTweens[instance]
if not bucket then
bucket = {}
self.ActiveTweens[instance] = bucket
end
local replaced = {}
for property in pairs(goals) do
local previous = bucket[property]
if previous then replaced[previous] = true end
end
for record in pairs(replaced) do
cancelTween(record.Tween)
if record.Connection then
self:Disconnect(record.Connection)
record.Connection = nil
end
for index = #self.Tweens, 1, -1 do
if self.Tweens[index] == record.Tween then table.remove(self.Tweens, index) break end
end
for property, current in pairs(bucket) do
if current == record then bucket[property] = nil end
end
end
local ok, tween = pcall(function()
return game:GetService("TweenService"):Create(instance, tweenInfo, goals)
end)
if not ok then
warn("[JustHub] Tween creation failed in " .. self.Label .. ": " .. tostring(tween))
return nil
end
local record = {Tween = tween}
for property in pairs(goals) do bucket[property] = record end
record.Connection = self:Connect(tween.Completed, function()
local currentBucket = self.ActiveTweens[instance]
if currentBucket then
for property, current in pairs(currentBucket) do
if current == record then currentBucket[property] = nil end
end
if not next(currentBucket) then self.ActiveTweens[instance] = nil end
end
if record.Connection then
self:Disconnect(record.Connection)
record.Connection = nil
end
for index = #self.Tweens, 1, -1 do
if self.Tweens[index] == tween then table.remove(self.Tweens, index) break end
end
end)
table.insert(self.Tweens, tween)
local played, playError = pcall(function() tween:Play() end)
if not played then
cancelTween(tween)
if record.Connection then
self:Disconnect(record.Connection)
record.Connection = nil
end
for property, current in pairs(bucket) do
if current == record then bucket[property] = nil end
end
if not next(bucket) then self.ActiveTweens[instance] = nil end
for index = #self.Tweens, 1, -1 do
if self.Tweens[index] == tween then table.remove(self.Tweens, index) break end
end
warn("[JustHub] Tween playback failed in " .. self.Label .. ": " .. tostring(playError))
return nil
end
return tween
end
function Scope:Spawn(callback)
if self.Destroyed or type(callback) ~= "function" then return nil end
local token = {Finished = false}
self.Threads[token] = true
local thread = task.spawn(function()
local ok, err = xpcall(function()
callback(function() return self:IsAlive() end)
end, debug.traceback)
if not ok then
warn("[JustHub] Task failed in " .. self.Label .. ": " .. tostring(err))
end
token.Finished = true
self.Threads[token] = nil
end)
if not token.Finished then token.Thread = thread end
return thread, token
end
function Scope:Delay(seconds, callback)
if self.Destroyed or type(callback) ~= "function" then return nil end
local token = {}
self.Threads[token] = true
token.Thread = task.delay(math.max(0, tonumber(seconds) or 0), function()
self.Threads[token] = nil
if self:IsAlive() then
local ok, err = xpcall(callback, debug.traceback)
if not ok then
warn("[JustHub] Delayed task failed in " .. self.Label .. ": " .. tostring(err))
end
end
end)
return token.Thread
end
function Scope:Destroy()
if self.Destroyed then return end
self.Destroyed = true
for index = #self.Children, 1, -1 do
self.Children[index]:Destroy()
end
table.clear(self.Children)
local running = coroutine.running()
for token in pairs(self.Threads) do
if token.Thread and token.Thread ~= running then pcall(task.cancel, token.Thread) end
self.Threads[token] = nil
end
for index = #self.Connections, 1, -1 do
disconnect(self.Connections[index])
self.Connections[index] = nil
end
for index = #self.Tweens, 1, -1 do
cancelTween(self.Tweens[index])
self.Tweens[index] = nil
end
for index = #self.Cleanups, 1, -1 do
local cleanup = self.Cleanups[index]
pcall(cleanup)
self.Cleanups[index] = nil
end
for index = #self.Instances, 1, -1 do
safeDestroy(self.Instances[index])
self.Instances[index] = nil
end
table.clear(self.ActiveTweens)
if self.Parent then
for index = #self.Parent.Children, 1, -1 do
if self.Parent.Children[index] == self then
table.remove(self.Parent.Children, index)
break
end
end
end
self.Parent = nil
end
function ResourceManager.new(label)
return Scope.new(nil, label or "JustHub")
end
ResourceManager.Scope = Scope
return ResourceManager
end)()

Modules.ThemeManager = (function()
local ThemeManager = {}
ThemeManager.__index = ThemeManager
local REQUIRED_KEYS = {
"Color Hub 1", "Color Hub 2", "Color Stroke",
"Color Theme", "Color Text", "Color Dark Text",
}
local THEMES = {
Darker = { ["Color Hub 1"] = Color3.fromRGB(18, 24, 34), ["Color Hub 2"] = Color3.fromRGB(25, 33, 46), ["Color Stroke"] = Color3.fromRGB(54, 68, 86), ["Color Theme"] = Color3.fromRGB(82, 211, 165), ["Color Text"] = Color3.fromRGB(239, 245, 250), ["Color Dark Text"] = Color3.fromRGB(171, 185, 201) },
Dark = { ["Color Hub 1"] = Color3.fromRGB(25, 25, 30), ["Color Hub 2"] = Color3.fromRGB(35, 35, 40), ["Color Stroke"] = Color3.fromRGB(60, 60, 70), ["Color Theme"] = Color3.fromRGB(80, 200, 255), ["Color Text"] = Color3.fromRGB(245, 245, 250), ["Color Dark Text"] = Color3.fromRGB(170, 170, 180) },
Purple = { ["Color Hub 1"] = Color3.fromRGB(20, 15, 30), ["Color Hub 2"] = Color3.fromRGB(30, 25, 40), ["Color Stroke"] = Color3.fromRGB(50, 40, 65), ["Color Theme"] = Color3.fromRGB(150, 100, 255), ["Color Text"] = Color3.fromRGB(240, 240, 245), ["Color Dark Text"] = Color3.fromRGB(170, 160, 190) },
Light = { ["Color Hub 1"] = Color3.fromRGB(210, 210, 215), ["Color Hub 2"] = Color3.fromRGB(230, 230, 235), ["Color Stroke"] = Color3.fromRGB(180, 180, 190), ["Color Theme"] = Color3.fromRGB(0, 140, 255), ["Color Text"] = Color3.fromRGB(40, 40, 45), ["Color Dark Text"] = Color3.fromRGB(90, 90, 100) },
Neon = { ["Color Hub 1"] = Color3.fromRGB(5, 5, 10), ["Color Hub 2"] = Color3.fromRGB(10, 10, 15), ["Color Stroke"] = Color3.fromRGB(0, 255, 255), ["Color Theme"] = Color3.fromRGB(0, 255, 100), ["Color Text"] = Color3.fromRGB(255, 255, 255), ["Color Dark Text"] = Color3.fromRGB(200, 255, 255) },
Forest = { ["Color Hub 1"] = Color3.fromRGB(0, 30, 15), ["Color Hub 2"] = Color3.fromRGB(0, 45, 25), ["Color Stroke"] = Color3.fromRGB(0, 75, 35), ["Color Theme"] = Color3.fromRGB(50, 205, 50), ["Color Text"] = Color3.fromRGB(230, 255, 230), ["Color Dark Text"] = Color3.fromRGB(170, 200, 170) },
Aqua = { ["Color Hub 1"] = Color3.fromRGB(0, 70, 80), ["Color Hub 2"] = Color3.fromRGB(0, 100, 110), ["Color Stroke"] = Color3.fromRGB(0, 160, 180), ["Color Theme"] = Color3.fromRGB(0, 230, 255), ["Color Text"] = Color3.fromRGB(250, 255, 255), ["Color Dark Text"] = Color3.fromRGB(200, 230, 240) },
Crimson = { ["Color Hub 1"] = Color3.fromRGB(35, 0, 5), ["Color Hub 2"] = Color3.fromRGB(60, 0, 10), ["Color Stroke"] = Color3.fromRGB(110, 0, 20), ["Color Theme"] = Color3.fromRGB(255, 50, 80), ["Color Text"] = Color3.fromRGB(255, 240, 240), ["Color Dark Text"] = Color3.fromRGB(220, 180, 180) },
Solar = { ["Color Hub 1"] = Color3.fromRGB(230, 190, 0), ["Color Hub 2"] = Color3.fromRGB(255, 210, 0), ["Color Stroke"] = Color3.fromRGB(255, 150, 0), ["Color Theme"] = Color3.fromRGB(255, 80, 0), ["Color Text"] = Color3.fromRGB(30, 30, 30), ["Color Dark Text"] = Color3.fromRGB(70, 70, 70) },
Pastel = { ["Color Hub 1"] = Color3.fromRGB(210, 190, 220), ["Color Hub 2"] = Color3.fromRGB(235, 220, 245), ["Color Stroke"] = Color3.fromRGB(180, 160, 200), ["Color Theme"] = Color3.fromRGB(170, 210, 240), ["Color Text"] = Color3.fromRGB(70, 70, 70), ["Color Dark Text"] = Color3.fromRGB(110, 110, 110) },
Cyber = { ["Color Hub 1"] = Color3.fromRGB(5, 5, 20), ["Color Hub 2"] = Color3.fromRGB(15, 15, 35), ["Color Stroke"] = Color3.fromRGB(0, 220, 255), ["Color Theme"] = Color3.fromRGB(0, 180, 255), ["Color Text"] = Color3.fromRGB(250, 255, 255), ["Color Dark Text"] = Color3.fromRGB(190, 230, 255) },
Ocean = { ["Color Hub 1"] = Color3.fromRGB(0, 20, 40), ["Color Hub 2"] = Color3.fromRGB(0, 35, 70), ["Color Stroke"] = Color3.fromRGB(0, 80, 150), ["Color Theme"] = Color3.fromRGB(0, 150, 255), ["Color Text"] = Color3.fromRGB(230, 245, 255), ["Color Dark Text"] = Color3.fromRGB(180, 210, 230) },
Desert = { ["Color Hub 1"] = Color3.fromRGB(180, 150, 110), ["Color Hub 2"] = Color3.fromRGB(210, 170, 120), ["Color Stroke"] = Color3.fromRGB(140, 70, 30), ["Color Theme"] = Color3.fromRGB(220, 150, 30), ["Color Text"] = Color3.fromRGB(50, 40, 30), ["Color Dark Text"] = Color3.fromRGB(90, 80, 70) },
Galaxy = { ["Color Hub 1"] = Color3.fromRGB(10, 0, 30), ["Color Hub 2"] = Color3.fromRGB(20, 0, 40), ["Color Stroke"] = Color3.fromRGB(70, 0, 120), ["Color Theme"] = Color3.fromRGB(140, 0, 255), ["Color Text"] = Color3.fromRGB(245, 245, 255), ["Color Dark Text"] = Color3.fromRGB(200, 200, 230) },
Vintage = { ["Color Hub 1"] = Color3.fromRGB(120, 90, 60), ["Color Hub 2"] = Color3.fromRGB(140, 110, 80), ["Color Stroke"] = Color3.fromRGB(100, 70, 50), ["Color Theme"] = Color3.fromRGB(190, 150, 120), ["Color Text"] = Color3.fromRGB(70, 50, 40), ["Color Dark Text"] = Color3.fromRGB(100, 90, 80) },
Rainbow = { ["Color Hub 1"] = Color3.fromRGB(240, 240, 240), ["Color Hub 2"] = Color3.fromRGB(255, 255, 255), ["Color Stroke"] = Color3.fromRGB(200, 200, 200), ["Color Theme"] = Color3.fromRGB(255, 100, 100), ["Color Text"] = Color3.fromRGB(30, 30, 30), ["Color Dark Text"] = Color3.fromRGB(90, 90, 90) },
Midnight = { ["Color Hub 1"] = Color3.fromRGB(0, 0, 20), ["Color Hub 2"] = Color3.fromRGB(5, 5, 30), ["Color Stroke"] = Color3.fromRGB(0, 0, 80), ["Color Theme"] = Color3.fromRGB(50, 50, 255), ["Color Text"] = Color3.fromRGB(250, 250, 255), ["Color Dark Text"] = Color3.fromRGB(190, 190, 220) },
}
local TOKENS = {
Geometry = { WindowRadius = 14, SidebarRadius = 11, CardRadius = 10, ControlRadius = 8, InputRadius = 7, PopupRadius = 9 },
Spacing = { XS = 4, SM = 8, MD = 12, LG = 16, XL = 22 },
Animation = { General = 0.18, Hover = 0.12, Press = 0.09, Tab = 0.18, Popup = 0.18, Toggle = 0.16, Notification = 0.24 },
Typography = { Title = 18, Subtitle = 11, Section = 14, Body = 13, Small = 11 },
Dimensions = { Header = 58, Sidebar = 168, MinWidth = 320, MinHeight = 280, DropdownHeader = 44, DropdownSingle = 154, DropdownMulti = 158 },
Controls = { Toggle = 48, Slider = 68, TextBox = 50, ColorPicker = 96, ScriptBox = 128, ConfigManager = 148, Button = 48, Bind = 48, Label = 28, Menu = 36 },
}
local function validTheme(theme)
if type(theme) ~= "table" then return false end
for _, key in ipairs(REQUIRED_KEYS) do
if typeof(theme[key]) ~= "Color3" then return false end
end
return true
end
function ThemeManager.new(runService, resourceScope)
local themes = Modules.Util.Clone(THEMES)
return setmetatable({
Themes = themes,
CurrentName = "Darker",
Current = themes.Darker,
Tokens = Modules.Util.Clone(TOKENS),
Bindings = setmetatable({}, {__mode = "k"}),
Chroma = setmetatable({}, {__mode = "k"}),
ChromaEnabled = false,
RunService = runService,
ResourceScope = resourceScope,
ChromaConnection = nil,
_elapsed = 0,
}, ThemeManager)
end
function ThemeManager:IsValid(theme)
return validTheme(theme)
end
function ThemeManager:Get(key)
local value = self.Current[key]
if value == nil then value = THEMES.Darker[key] end
return value
end
function ThemeManager:Bind(instance, property, themeKey, customUpdater)
if not instance or type(property) ~= "string" then return false end
local bucket = self.Bindings[instance]
if not bucket then
bucket = {}
self.Bindings[instance] = bucket
end
bucket[property] = {Key = themeKey, Updater = customUpdater}
if customUpdater then
local ok, err = pcall(customUpdater, self.Current)
if not ok then
warn("[JustHub] Theme binding failed: " .. tostring(err))
return false
end
elseif themeKey and self.Current[themeKey] then
local ok, err = pcall(function() instance[property] = self.Current[themeKey] end)
if not ok then
warn("[JustHub] Theme binding failed: " .. tostring(err))
return false
end
end
return true
end
function ThemeManager:UpdateBinding(instance, property, themeKey)
local bucket = self.Bindings[instance]
if bucket and bucket[property] then
bucket[property].Key = themeKey
return true
end
return false
end
function ThemeManager:Unbind(instance)
if not instance then return end
self.Bindings[instance] = nil
self.Chroma[instance] = nil
end
function ThemeManager:UnbindTree(root)
if not root then return end
self:Unbind(root)
local ok, descendants = pcall(function() return root:GetDescendants() end)
if ok and type(descendants) == "table" then
for _, descendant in ipairs(descendants) do self:Unbind(descendant) end
end
self:_UpdateChromaConnection()
end
function ThemeManager:Apply(theme)
local nextTheme, nextName
if type(theme) == "string" then
nextTheme = self.Themes[theme]
nextName = theme
else
nextTheme = validTheme(theme) and table.clone(theme) or nil
nextName = "Custom"
end
if not validTheme(nextTheme) then
return false, "Unknown or invalid theme"
end
self.Current = nextTheme
self.CurrentName = nextName
for instance, properties in pairs(self.Bindings) do
local alive = true
pcall(function() alive = instance.Parent ~= nil end)
if not alive then
self.Bindings[instance] = nil
else
for property, binding in pairs(properties) do
if not (self.ChromaEnabled and self.Chroma[instance] and self.Chroma[instance][property]) then
local ok, err = pcall(function()
if binding.Updater then
binding.Updater(nextTheme)
elseif binding.Key and nextTheme[binding.Key] then
instance[property] = nextTheme[binding.Key]
end
end)
if not ok then
warn("[JustHub] Theme update failed: " .. tostring(err))
end
end
end
end
end
return true
end
function ThemeManager:Register(name, definition)
if type(name) ~= "string" or name == "" or not validTheme(definition) then
return false, "Theme requires a name and six Color3 fields"
end
self.Themes[name] = table.clone(definition)
return true
end
function ThemeManager:RegisterChroma(instance, property, themeKey)
if not instance or type(property) ~= "string" then return false end
local bucket = self.Chroma[instance]
if not bucket then
bucket = {}
self.Chroma[instance] = bucket
end
bucket[property] = themeKey or true
self:_UpdateChromaConnection()
return true
end
function ThemeManager:UnregisterChroma(instance, property)
local bucket = instance and self.Chroma[instance]
if not bucket then return end
if property then
local themeKey = bucket[property]
bucket[property] = nil
if not next(bucket) then self.Chroma[instance] = nil end
if self.ChromaEnabled and themeKey ~= nil then self:_RestoreProperty(instance, property, themeKey) end
else
self.Chroma[instance] = nil
if self.ChromaEnabled then
for chromaProperty, themeKey in pairs(bucket) do self:_RestoreProperty(instance, chromaProperty, themeKey) end
end
end
self:_UpdateChromaConnection()
end
function ThemeManager:_UpdateChromaConnection()
local shouldRun = self.ChromaEnabled and next(self.Chroma) ~= nil
if shouldRun and not self.ChromaConnection then
self.ChromaConnection = self.ResourceScope:Connect(self.RunService.Heartbeat, function(deltaTime)
self._elapsed += deltaTime
if self._elapsed < 1 / 24 then return end
self._elapsed %= 1 / 24
local color = Color3.fromHSV((os.clock() % 5) / 5, 0.82, 1)
for instance, properties in pairs(self.Chroma) do
local alive = false
pcall(function() alive = instance.Parent ~= nil end)
if not alive then
self.Chroma[instance] = nil
else
for property in pairs(properties) do
local ok = pcall(function() instance[property] = color end)
if not ok then properties[property] = nil end
end
if not next(properties) then self.Chroma[instance] = nil end
end
end
if not next(self.Chroma) then self:_UpdateChromaConnection() end
end)
elseif not shouldRun and self.ChromaConnection then
self.ResourceScope:Disconnect(self.ChromaConnection)
self.ChromaConnection = nil
end
end
function ThemeManager:_RestoreProperty(instance, property, fallbackKey)
local bucket = self.Bindings[instance]
local binding = bucket and bucket[property]
local ok, err = pcall(function()
if binding and binding.Updater then
binding.Updater(self.Current)
elseif binding and binding.Key and self.Current[binding.Key] then
instance[property] = self.Current[binding.Key]
elseif type(fallbackKey) == "string" and self.Current[fallbackKey] then
instance[property] = self.Current[fallbackKey]
end
end)
if not ok then warn("[JustHub] Theme restore failed: " .. tostring(err)) end
end
function ThemeManager:SetChroma(enabled)
self.ChromaEnabled = enabled == true
self._elapsed = 0
if not self.ChromaEnabled then
for instance, properties in pairs(self.Chroma) do
for property, themeKey in pairs(properties) do
self:_RestoreProperty(instance, property, themeKey)
end
end
end
self:_UpdateChromaConnection()
return self.ChromaEnabled
end
function ThemeManager:Destroy()
if self.ChromaConnection then
self.ResourceScope:Disconnect(self.ChromaConnection)
self.ChromaConnection = nil
end
table.clear(self.Bindings)
table.clear(self.Chroma)
end
ThemeManager.Defaults = THEMES
ThemeManager.DesignTokens = TOKENS
return ThemeManager
end)()

Modules.UiKit = (function()
return function(context)
local Instance = context.Instance
local Enum = context.Enum
local Theme = context.Theme
local Kit = {}
function Kit.make(className, properties, parent, warnLabel)
local object = Instance.new(className)
for property, value in pairs(properties or {}) do
local ok, err = pcall(function() object[property] = value end)
if not ok and warnLabel then
warn("[JustHub] " .. warnLabel .. " " .. className .. "." .. tostring(property) .. ": " .. tostring(err))
end
end
if parent then object.Parent = parent end
return object
end
function Kit.bind(object, property, key)
Theme:Bind(object, property, key)
return object
end
function Kit.corner(object, radius)
Kit.make("UICorner", {CornerRadius = UDim.new(0, radius or Theme.Tokens.Geometry.ControlRadius)}, object)
return object
end
function Kit.stroke(object, colorKey, thickness)
local border = Kit.make("UIStroke", {
ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
Color = Theme:Get(colorKey or "Color Stroke"),
Thickness = thickness or 1,
Transparency = 0,
}, object)
Kit.bind(border, "Color", colorKey or "Color Stroke")
return border
end
function Kit.text(parent, text, position, size, options)
options = options or {}
local label = Kit.make("TextLabel", {
Name = options.Name or "Text",
Text = tostring(text or ""),
Position = position or UDim2.new(),
Size = size or UDim2.new(1, 0, 1, 0),
BackgroundTransparency = 1,
BorderSizePixel = 0,
Font = options.Font or Enum.Font.Gotham,
TextSize = options.TextSize or Theme.Tokens.Typography.Body,
TextColor3 = Theme:Get(options.ColorKey or "Color Text"),
TextXAlignment = options.Align or Enum.TextXAlignment.Left,
TextYAlignment = options.YAlign or Enum.TextYAlignment.Center,
TextWrapped = options.Wrapped == true,
TextTruncate = options.Truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None,
RichText = false,
ZIndex = options.ZIndex or 3,
}, parent)
Kit.bind(label, "TextColor3", options.ColorKey or "Color Text")
return label
end
return Kit
end
end)()

Modules.StateManager = (function()
local Util = Modules.Util
local StateManager = {}
StateManager.__index = StateManager
local cloneValue = Util.Clone
function StateManager.new(options)
options = options or {}
return setmetatable({
Values = {},
Registry = {},
Aliases = {},
AmbiguousAliases = {},
Controls = {},
UndoStack = {},
RedoStack = {},
HistoryLimit = math.floor(Util.ClampNumber(options.HistoryLimit, 1, 1000, 100)),
Applying = false,
Destroyed = false,
}, StateManager)
end
function StateManager:_Warn(message)
warn("[JustHub] " .. tostring(message))
end
function StateManager:_Resolve(id)
if type(id) ~= "string" or id == "" then
return nil, nil, "Control ID must be a non-empty string"
end
if self.Registry[id] then return id, self.Registry[id] end
if self.AmbiguousAliases[id] then
return nil, nil, "Ambiguous control alias; use the full control ID"
end
local canonical = self.Aliases[id]
if canonical then return canonical, self.Registry[canonical] end
return nil, nil, "Unknown control: " .. tostring(id)
end
function StateManager:_ReleaseAlias(id)
if self.Aliases[id] then
self.Aliases[id] = nil
self.Controls[id] = nil
end
self.AmbiguousAliases[id] = nil
end
function StateManager:_RegisterAlias(id, alias)
if type(alias) ~= "string" or alias == "" or alias == id then return end
if self.Registry[alias] then return end
local ambiguous = self.AmbiguousAliases[alias]
if ambiguous then
ambiguous[id] = true
return
end
local existing = self.Aliases[alias]
if existing and existing ~= id then
self.Aliases[alias] = nil
self.Controls[alias] = nil
self.AmbiguousAliases[alias] = {[existing] = true, [id] = true}
self:_Warn("Ambiguous short control name '" .. alias .. "'; use the full ID")
return
end
self.Aliases[alias] = id
self.Controls[alias] = self.Controls[id]
end
function StateManager:Create(id, defaultValue, validator, renderer, callback, metadata)
if self.Destroyed then return nil, "State manager is destroyed" end
if type(id) ~= "string" or id == "" then
return nil, "Control ID must be a non-empty string"
end
if self.Registry[id] then
return nil, "Control ID already registered: " .. id
end
self:_ReleaseAlias(id)
metadata = type(metadata) == "table" and metadata or {}
local normalizer = metadata.normalize or metadata.Normalize
if type(normalizer) == "function" then
local ok, normalized = pcall(normalizer, defaultValue)
if ok and normalized ~= nil then defaultValue = normalized end
end
local record = {
Id = id,
Value = cloneValue(defaultValue),
Validator = validator,
Renderer = renderer,
Callback = callback,
Normalizer = type(normalizer) == "function" and normalizer or nil,
Metadata = metadata,
EditStart = nil,
Destroyed = false,
}
local handle = {Id = id}
local selfManager = self
record.Handle = handle
self.Registry[id] = record
self.Values[id] = cloneValue(defaultValue)
self.Controls[id] = record.Metadata
self:_RegisterAlias(id, record.Metadata.shortName or record.Metadata.ShortName)
function handle:Get()
return cloneValue(record.Value)
end
function handle:Set(value, applyOptions)
return selfManager:Set(id, value, applyOptions)
end
function handle:SetLive(value, applyOptions)
local options = table.clone(applyOptions or {})
options.skipHistory = true
return selfManager:Set(id, value, options)
end
function handle:BeginEdit()
if record.EditStart == nil then
record.EditStart = cloneValue(record.Value)
end
end
function handle:EndEdit(dispatchCallback)
local changed = record.EditStart ~= nil and not selfManager:_Equal(record.EditStart, record.Value)
if changed and not selfManager.Applying then
selfManager:AddUndo(id, record.EditStart, record.Value)
end
record.EditStart = nil
if changed and dispatchCallback == true and type(record.Callback) == "function" then
local callback = record.Callback
local callbackValue = cloneValue(record.Value)
task.defer(function()
if not selfManager.Destroyed and not record.Destroyed then
local ok, err = xpcall(function() callback(callbackValue) end, debug.traceback)
if not ok then selfManager:_Warn("Callback failed for '" .. id .. "': " .. tostring(err)) end
end
end)
end
end
function handle:Destroy()
selfManager:Unregister(id)
end
if type(renderer) == "function" then
local ok, err = pcall(renderer, cloneValue(defaultValue))
if not ok then
self:Unregister(id)
return nil, "Initial render failed: " .. tostring(err)
end
end
return handle
end
function StateManager:_Equal(left, right)
return Util.DeepEqual(left, right)
end
function StateManager:Set(id, value, applyOptions)
if self.Destroyed then return false, "State manager is destroyed" end
local canonical, record, resolveError = self:_Resolve(id)
if not record then return false, resolveError end
if record.Destroyed then return false, "Control is destroyed" end
applyOptions = type(applyOptions) == "table" and applyOptions or {}
if type(record.ExternalSetter) == "function" then
local ok, result, reason = pcall(record.ExternalSetter, cloneValue(value))
if not ok then return false, result end
if result == false then return false, reason or "External control rejected the value" end
return true, true
end
if type(record.Normalizer) == "function" then
local normalizeOk, normalized = pcall(record.Normalizer, value)
if normalizeOk and normalized ~= nil then value = normalized end
end
if type(record.Validator) == "function" then
local validatorOk, valid, reason = pcall(record.Validator, value)
if not validatorOk then
return false, "Validator failed: " .. tostring(valid)
end
if valid ~= true then
return false, reason or "Invalid control value"
end
end
local oldValue = cloneValue(record.Value)
local newValue = cloneValue(value)
if self:_Equal(oldValue, newValue) then return true, false end
record.Value = cloneValue(newValue)
self.Values[canonical] = cloneValue(newValue)
if type(record.Renderer) == "function" and not applyOptions.skipRender then
local ok, err = pcall(record.Renderer, cloneValue(newValue))
if not ok then
record.Value = cloneValue(oldValue)
self.Values[canonical] = cloneValue(oldValue)
pcall(record.Renderer, cloneValue(oldValue))
self:_Warn("Render failed for '" .. canonical .. "': " .. tostring(err))
return false, err
end
end
if not applyOptions.skipHistory and not self.Applying then
self:AddUndo(canonical, oldValue, newValue)
end
if not applyOptions.skipCallback and type(record.Callback) == "function" then
local callback = record.Callback
local callbackValue = cloneValue(newValue)
task.defer(function()
if not self.Destroyed and not record.Destroyed then
local ok, err = xpcall(function() callback(callbackValue) end, debug.traceback)
if not ok then
self:_Warn("Callback failed for '" .. canonical .. "': " .. tostring(err))
end
end
end)
end
return true, true
end
function StateManager:RegisterExternal(id, setter, metadata)
metadata = type(metadata) == "table" and metadata or {}
if type(id) ~= "string" or id == "" or type(setter) ~= "function" then
return false, "Invalid external control registration"
end
if self.Registry[id] then
return false, "Control ID already registered: " .. id
end
self:_ReleaseAlias(id)
local record = {Id = id, ExternalSetter = setter, Metadata = metadata, Destroyed = false}
self.Registry[id] = record
self.Controls[id] = metadata
self:_RegisterAlias(id, metadata.shortName or metadata.ShortName)
return true
end
function StateManager:Get(id)
local _, record, resolveError = self:_Resolve(id)
if not record then return nil, resolveError end
if record.ExternalSetter then
local getter = type(record.Metadata) == "table" and (record.Metadata.getValue or record.Metadata.GetValue)
if type(getter) == "function" then
local ok, value = pcall(getter)
if ok then return cloneValue(value) end
return nil, tostring(value)
end
return nil, "External control does not expose a getter"
end
return cloneValue(record.Value)
end
function StateManager:Unregister(id)
local canonical = self.Registry[id] and id or self.Aliases[id]
if not canonical then return false end
local record = self.Registry[canonical]
if record then
record.Destroyed = true
self.Registry[canonical] = nil
self.Values[canonical] = nil
self.Controls[canonical] = nil
end
for alias, target in pairs(self.Aliases) do
if target == canonical then
self.Aliases[alias] = nil
self.Controls[alias] = nil
end
end
for alias, candidates in pairs(self.AmbiguousAliases) do
if candidates[canonical] then
candidates[canonical] = nil
local remaining, count = nil, 0
for candidateId in pairs(candidates) do
if self.Registry[candidateId] then
remaining = candidateId
count += 1
end
end
if count == 0 then
self.AmbiguousAliases[alias] = nil
elseif count == 1 then
self.AmbiguousAliases[alias] = nil
self.Aliases[alias] = remaining
self.Controls[alias] = self.Controls[remaining]
end
end
end
for index = #self.UndoStack, 1, -1 do
if self.UndoStack[index].Id == canonical then table.remove(self.UndoStack, index) end
end
for index = #self.RedoStack, 1, -1 do
if self.RedoStack[index].Id == canonical then table.remove(self.RedoStack, index) end
end
return true
end
function StateManager:AddUndo(id, oldValue, newValue)
if type(id) ~= "string" then return false end
local canonical = self.Registry[id] and id or self.Aliases[id]
if not canonical then return false end
id = canonical
if self.Applying or self.Destroyed or self:_Equal(oldValue, newValue) then return false end
local last = self.UndoStack[#self.UndoStack]
if last and last.Id == id and self:_Equal(last.New, oldValue) then
last.New = cloneValue(newValue)
if self:_Equal(last.Old, last.New) then table.remove(self.UndoStack) end
else
table.insert(self.UndoStack, {Id = id, Old = cloneValue(oldValue), New = cloneValue(newValue)})
if #self.UndoStack > self.HistoryLimit then table.remove(self.UndoStack, 1) end
end
table.clear(self.RedoStack)
return true
end
function StateManager:_ApplyHistory(id, value)
local record = self.Registry[id]
if not record then return false, "Control is no longer registered" end
if record.ExternalSetter then
local ok, result, reason = pcall(record.ExternalSetter, cloneValue(value))
if not ok then return false, result end
if result == false then return false, reason or "External control rejected the value" end
return true
end
self.Applying = true
local ok, err = self:Set(id, value, {skipHistory = true})
self.Applying = false
return ok, err
end
function StateManager:Undo()
local entry = self.UndoStack[#self.UndoStack]
if not entry then return false, "Nothing to undo" end
local ok, err = self:_ApplyHistory(entry.Id, entry.Old)
if not ok then return false, err end
table.remove(self.UndoStack)
table.insert(self.RedoStack, entry)
return true
end
function StateManager:Redo()
local entry = self.RedoStack[#self.RedoStack]
if not entry then return false, "Nothing to redo" end
local ok, err = self:_ApplyHistory(entry.Id, entry.New)
if not ok then return false, err end
table.remove(self.RedoStack)
table.insert(self.UndoStack, entry)
return true
end
function StateManager:ApplyConfig(values)
if type(values) ~= "table" then
return false, "Configuration values must be a table"
end
local previous = self.Applying
self.Applying = true
local applied, skipped = 0, 0
local canonicalSet = {}
local function applyRecord(record, value)
if not record then return false end
if record.ExternalSetter then
local ok, result = pcall(record.ExternalSetter, cloneValue(value))
return ok and result ~= false
end
local ok = self:Set(record.Id, value, {skipHistory = true})
return ok == true
end
local loopOk, loopError = xpcall(function()
for key, value in pairs(values) do
local record = self.Registry[key]
if record then
canonicalSet[key] = true
if applyRecord(record, value) then applied += 1 else skipped += 1 end
end
end
for key, value in pairs(values) do
if not self.Registry[key] then
local canonical = self.Aliases[key]
local record = canonical and self.Registry[canonical]
if record and not canonicalSet[canonical] then
canonicalSet[canonical] = true
if applyRecord(record, value) then applied += 1 else skipped += 1 end
else
skipped += 1
end
end
end
end, debug.traceback)
self.Applying = previous
if not loopOk then
self:_Warn("Configuration application aborted: " .. tostring(loopError))
return false, loopError
end
table.clear(self.UndoStack)
table.clear(self.RedoStack)
return true, {Applied = applied, Skipped = skipped}
end
function StateManager:Destroy()
if self.Destroyed then return end
self.Destroyed = true
for _, record in pairs(self.Registry) do record.Destroyed = true end
table.clear(self.Registry)
table.clear(self.Values)
table.clear(self.Aliases)
table.clear(self.AmbiguousAliases)
table.clear(self.Controls)
table.clear(self.UndoStack)
table.clear(self.RedoStack)
end
return StateManager
end)()

Modules.StorageAdapter = (function()
local Util = Modules.Util
local StorageAdapter = {}
StorageAdapter.__index = StorageAdapter
local RESERVED = {
con = true, prn = true, aux = true, nul = true,
com1 = true, com2 = true, com3 = true, com4 = true, com5 = true,
com6 = true, com7 = true, com8 = true, com9 = true,
lpt1 = true, lpt2 = true, lpt3 = true, lpt4 = true, lpt5 = true,
lpt6 = true, lpt7 = true, lpt8 = true, lpt9 = true,
}
local DIRECT = {
readfile = readfile, writefile = writefile, delfile = delfile, isfile = isfile,
makefolder = makefolder, isfolder = isfolder, listfiles = listfiles,
}
local function getExecutorEnvironment()
local environment = _G
if type(getgenv) == "function" then
local ok, result = pcall(getgenv)
if ok and type(result) == "table" then return result end
end
if type(getfenv) == "function" then
local ok, result = pcall(getfenv, 0)
if ok and type(result) == "table" then environment = result end
end
return environment
end
local function lookup(environment, name)
if type(environment) ~= "table" then return nil end
local value = rawget(environment, name)
if type(value) == "function" then return value end
local ok, indexed = pcall(function() return environment[name] end)
if ok and type(indexed) == "function" then return indexed end
return nil
end
function StorageAdapter.new(options)
options = options or {}
local environment = getExecutorEnvironment()
local function resolve(name)
if type(DIRECT[name]) == "function" then return DIRECT[name] end
return lookup(environment, name) or lookup(_G, name)
end
local folder = type(options.Folder) == "string" and Util.Trim(options.Folder) or ""
folder = folder:gsub("\\", "/")
folder = folder:gsub("^/+", "")
folder = folder:gsub("/+$", "")
if folder:find("..", 1, true) or folder:find(":", 1, true) or folder:find("%c") then folder = "" end
return setmetatable({
Environment = environment,
ReadFile = resolve("readfile"),
WriteFile = resolve("writefile"),
DeleteFile = resolve("delfile"),
IsFile = resolve("isfile"),
MakeFolder = resolve("makefolder"),
IsFolder = resolve("isfolder"),
ListFiles = resolve("listfiles"),
Folder = folder,
}, StorageAdapter)
end
function StorageAdapter:Capabilities()
return {
Read = type(self.ReadFile) == "function",
Write = type(self.WriteFile) == "function",
Delete = type(self.DeleteFile) == "function",
IsFile = type(self.IsFile) == "function",
MakeFolder = type(self.MakeFolder) == "function",
IsFolder = type(self.IsFolder) == "function",
List = type(self.ListFiles) == "function",
}
end
function StorageAdapter:NormalizeName(fileName)
local name = Util.Trim(tostring(fileName or ""))
name = name:gsub("\\", "/")
if name == "" then return nil, "Filename is empty" end
if name:lower():sub(-5) ~= ".json" then name = name .. ".json" end
if #name > 128 or name:lower() == ".json" then
return nil, "Filename contains an invalid path or character"
end
if name:find("%c") or name:find("[<>\"|%?%*]") then
return nil, "Filename contains an invalid path or character"
end
if name:sub(-6, -6) == " " or name:sub(-6, -6) == "." then
return nil, "Filename cannot end with a space or a dot"
end
if name == "." or name == ".." or name:find("..", 1, true)
or name:find("/", 1, true) or name:find(":", 1, true) then
return nil, "Filename contains an invalid path or character"
end
local base = name:lower():sub(1, -6)
base = base:match("^([^%.]*)") or base
if RESERVED[base] then return nil, "Filename is reserved by the operating system" end
return self.Folder ~= "" and (self.Folder .. "/" .. name) or name
end
function StorageAdapter:_EnsureFolder()
if self.Folder == "" then return true end
if type(self.MakeFolder) ~= "function" then
return false, "makefolder is not supported by this executor"
end
local exists = false
if type(self.IsFolder) == "function" then
local ok, result = pcall(self.IsFolder, self.Folder)
exists = ok and result == true
end
if not exists then
local ok, err = pcall(self.MakeFolder, self.Folder)
if not ok then
local message = tostring(err):lower()
if not (message:find("exist") or message:find("already")) then
return false, tostring(err)
end
end
end
return true
end
function StorageAdapter:Write(fileName, content)
if type(self.WriteFile) ~= "function" then
return false, "writefile is not supported by this executor"
end
local path, pathError = self:NormalizeName(fileName)
if not path then return false, pathError end
local folderOk, folderError = self:_EnsureFolder()
if not folderOk then return false, folderError end
if type(content) ~= "string" then return false, "File content must be a string" end
local ok, err = pcall(self.WriteFile, path, content)
if not ok then return false, tostring(err) end
return true, path
end
function StorageAdapter:Read(fileName)
if type(self.ReadFile) ~= "function" then
return false, "readfile is not supported by this executor"
end
local path, pathError = self:NormalizeName(fileName)
if not path then return false, pathError end
if type(self.IsFile) == "function" then
local existsOk, exists = pcall(self.IsFile, path)
if existsOk and not exists then
return false, "Configuration file does not exist: " .. path
end
end
local ok, content = pcall(self.ReadFile, path)
if not ok then return false, tostring(content) end
if type(content) ~= "string" or content == "" then
return false, "Configuration file is empty or unreadable"
end
return true, content, path
end
function StorageAdapter:Delete(fileName)
if type(self.DeleteFile) ~= "function" then
return false, "delfile is not supported by this executor"
end
local path, pathError = self:NormalizeName(fileName)
if not path then return false, pathError end
if type(self.IsFile) == "function" then
local existsOk, exists = pcall(self.IsFile, path)
if existsOk and not exists then
return false, "Configuration file does not exist: " .. path
end
end
local ok, err = pcall(self.DeleteFile, path)
if not ok then return false, tostring(err) end
return true, path
end
function StorageAdapter:List()
if type(self.ListFiles) ~= "function" then
return false, "listfiles is not supported by this executor"
end
if self.Folder ~= "" and type(self.IsFolder) == "function" then
local existsOk, exists = pcall(self.IsFolder, self.Folder)
if existsOk and not exists then return true, {} end
end
local ok, files = pcall(self.ListFiles, self.Folder)
if not ok and self.Folder == "" then
ok, files = pcall(self.ListFiles, ".")
end
if not ok then return false, tostring(files) end
local result, seen = {}, {}
if type(files) == "table" then
for _, path in ipairs(files) do
local name = tostring(path):match("([^/\\]+)$") or tostring(path)
if #name > 5 and name:lower():sub(-5) == ".json" then
local base = name:sub(1, -6)
if not seen[base] then
seen[base] = true
result[#result + 1] = base
end
end
end
end
table.sort(result)
return true, result
end
return StorageAdapter
end)()

Modules.ConfigManager = (function()
local ConfigManager = {}
ConfigManager.__index = ConfigManager
local SCHEMA_VERSION = 4
local Util = Modules.Util
local function serialize(value, seen, depth)
depth = (depth or 0) + 1
if depth > 32 then error("Configuration nesting limit exceeded", 0) end
if typeof(value) == "Color3" then
return {__JustHubType = "Color3", R = value.R, G = value.G, B = value.B}
end
if typeof(value) == "EnumItem" then
return value.Name
end
if type(value) ~= "table" then
local valueType = type(value)
if valueType == "number" then
if not Util.IsFinite(value) then error("Configuration contains a non-finite number", 0) end
return value
end
if valueType == "string" or valueType == "boolean" then
return value
end
if value == nil then return nil end
error("Unsupported config value type: " .. typeof(value), 0)
end
seen = seen or {}
if seen[value] then error("Configuration contains a cyclic table", 0) end
seen[value] = true
local result = {}
local isArray = next(value) ~= nil and Util.IsDenseArray(value)
for key, child in pairs(value) do
local keyType = type(key)
if keyType ~= "string" and keyType ~= "number" then
error("Configuration keys must be strings or numbers", 0)
end
if keyType == "number" and not isArray then
error("Configuration tables must be dense arrays or string-keyed objects", 0)
end
result[key] = serialize(child, seen, depth)
end
seen[value] = nil
return result
end
local function deserialize(value, depth)
depth = (depth or 0) + 1
if depth > 32 then error("Configuration nesting limit exceeded", 0) end
if type(value) ~= "table" then return value end
if Util.IsDenseArray(value) then
local array = table.create(#value)
for index, child in ipairs(value) do array[index] = deserialize(child, depth) end
return array
end
local marker = value.__JustHubType or value.__type
if marker == "Color3" then
local red = tonumber(value.R)
local green = tonumber(value.G)
local blue = tonumber(value.B)
if not red or not green or not blue then
error("Configuration contains an invalid Color3 value", 0)
end
if red ~= red or green ~= green or blue ~= blue
or red == math.huge or red == -math.huge
or green == math.huge or green == -math.huge
or blue == math.huge or blue == -math.huge then
error("Configuration contains a non-finite Color3 value", 0)
end
return Color3.new(math.clamp(red, 0, 1), math.clamp(green, 0, 1), math.clamp(blue, 0, 1))
end
local result = {}
for key, child in pairs(value) do
result[key] = deserialize(child, depth)
end
return result
end
function ConfigManager.new(httpService, stateManager, storageAdapter, notify, metaBridge, frameworkVersion)
return setmetatable({
HttpService = httpService,
State = stateManager,
Storage = storageAdapter,
Notify = notify,
MetaBridge = metaBridge,
SchemaVersion = SCHEMA_VERSION,
FrameworkVersion = tostring(frameworkVersion or "unknown"),
Profiles = {},
}, ConfigManager)
end
function ConfigManager:Serialize(values)
return serialize(values)
end
function ConfigManager:Deserialize(values)
return deserialize(values)
end
function ConfigManager:_CollectValues()
local values = table.clone(self.State.Values)
for id, record in pairs(self.State.Registry) do
if record.ExternalSetter and type(record.Metadata) == "table" then
local getter = record.Metadata.getValue or record.Metadata.GetValue
if type(getter) == "function" then
local ok, value = pcall(getter)
if ok and value ~= nil then
values[id] = value
elseif not ok then
warn("[JustHub] Could not read external control '" .. tostring(id) .. "' for config: " .. tostring(value))
end
end
end
end
return values
end
function ConfigManager:Save(fileName)
if self.State.Destroyed then return false, "State manager is destroyed" end
local ok, json = pcall(function()
local payload = {
__JustHub = {
Version = SCHEMA_VERSION,
Framework = "JustHub",
FrameworkVersion = self.FrameworkVersion,
SavedAt = os.time(),
},
Values = serialize(self:_CollectValues()),
}
if self.MetaBridge and type(self.MetaBridge.Collect) == "function" then
local metaOk, meta = pcall(self.MetaBridge.Collect)
if metaOk and type(meta) == "table" then
payload.Save = serialize(meta)
end
end
return self.HttpService:JSONEncode(payload)
end)
if not ok then
return false, "JSON encoding failed: " .. tostring(json)
end
local writeOk, result = self.Storage:Write(fileName or "JustHub_Config.json", json)
if not writeOk then return false, result end
local savedName = tostring(result):match("([^/\\]+)%.json$")
if savedName then self.Profiles[savedName] = true end
if self.Notify then
self.Notify("Save Config", "Saved: " .. tostring(result), 3)
end
return true, result
end
function ConfigManager:_ExtractValues(decoded)
if type(decoded) ~= "table" then
return nil, "Configuration root must be an object"
end
if type(decoded.__JustHub) == "table" then
local version = tonumber(decoded.__JustHub.Version)
if not Util.IsFinite(version) then version = 1 end
if version > SCHEMA_VERSION then
return nil, "Configuration was created by a newer JustHub version"
end
if type(decoded.Values) ~= "table" then
return nil, "Configuration is missing its Values object"
end
return deserialize(decoded.Values), version
end
local legacy = table.clone(decoded)
for key, value in pairs(legacy) do
if type(value) == "table" and value.__JustHubInternal == "TransparencySettings" then
legacy[key] = nil
elseif key == "__JustHubMeta" or key == "Save" then
legacy[key] = nil
end
end
return deserialize(legacy), 3
end
function ConfigManager:Load(fileName)
local readOk, raw, resolvedPath = self.Storage:Read(fileName or "JustHub_Config.json")
if not readOk then return false, raw end
local decodeOk, decoded = pcall(function()
return self.HttpService:JSONDecode(raw)
end)
if not decodeOk then
return false, "Invalid JSON: " .. tostring(decoded)
end
local extractOk, values, version = pcall(function()
local result, schema = self:_ExtractValues(decoded)
if not result then error(schema, 0) end
return result, schema
end)
if not extractOk then
return false, "Invalid configuration: " .. tostring(values)
end
if version < SCHEMA_VERSION then
warn("[JustHub] Migrating legacy configuration schema v" .. tostring(version) .. " to v" .. SCHEMA_VERSION)
end
if self.MetaBridge and type(self.MetaBridge.Apply) == "function" and type(decoded.Save) == "table" then
local metaOk, metaErr = pcall(function()
self.MetaBridge.Apply(deserialize(decoded.Save))
end)
if not metaOk then
warn("[JustHub] Could not apply saved window settings: " .. tostring(metaErr))
end
end
local applyOk, report = self.State:ApplyConfig(values)
if not applyOk then return false, report end
if self.Notify then
local summary = type(report) == "table" and (" (" .. tostring(report.Applied) .. " applied, " .. tostring(report.Skipped) .. " skipped)") or ""
self.Notify("Load Config", "Loaded: " .. tostring(resolvedPath) .. summary, 3)
end
return true, report
end
function ConfigManager:Delete(fileName)
local ok, result = self.Storage:Delete(fileName or "JustHub_Config.json")
if ok then
local deletedName = tostring(fileName or "JustHub_Config"):match("([^/\\]+)%.json$") or tostring(fileName or "JustHub_Config")
self.Profiles[deletedName] = nil
end
if ok and self.Notify then
self.Notify("Delete Config", "Deleted: " .. tostring(result), 3)
end
return ok, result
end
function ConfigManager:List()
local ok, result = self.Storage:List()
local merged, seen = {}, {}
local function add(name)
name = tostring(name):match("([^/\\]+)%.json$") or tostring(name)
if name ~= "" and not seen[name] then
seen[name] = true
merged[#merged + 1] = name
end
end
if ok and type(result) == "table" then
for _, name in ipairs(result) do add(name) end
end
for name in pairs(self.Profiles or {}) do add(name) end
table.sort(merged)
return true, merged
end
ConfigManager.SchemaVersion = SCHEMA_VERSION
return ConfigManager
end)()

Modules.Localization = (function()
local Localization = {}
Localization.__index = Localization
local BUILTIN = {
en = {
Search = "Search controls...",
Select = "Select...",
SearchOptions = "Search options...",
SelectAll = "Select all",
ClearAll = "Clear all",
InputHere = "Type here...",
PasteHere = "Paste text here...",
Run = "Run",
SaveProfile = "Save profile",
LoadProfile = "Load profile",
DeleteProfile = "Delete profile",
ConfigName = "Profile name...",
NoProfiles = "No saved profiles yet",
PressKey = "Press a key...",
Locked = "Locked",
Unlocked = "Unlocked",
},
id = {
Search = "Cari kontrol...",
Select = "Pilih...",
SearchOptions = "Cari opsi...",
SelectAll = "Pilih semua",
ClearAll = "Hapus semua",
InputHere = "Ketik di sini...",
PasteHere = "Tempel teks di sini...",
Run = "Jalankan",
SaveProfile = "Simpan profil",
LoadProfile = "Muat profil",
DeleteProfile = "Hapus profil",
ConfigName = "Nama profil...",
NoProfiles = "Belum ada profil tersimpan",
PressKey = "Tekan tombol...",
Locked = "Terkunci",
Unlocked = "Tidak terkunci",
},
}
function Localization.new()
local languages = {}
for code, dictionary in pairs(BUILTIN) do languages[code] = table.clone(dictionary) end
return setmetatable({
Current = "en",
Languages = languages,
Tracked = setmetatable({}, {__mode = "k"}),
Listeners = {},
}, Localization)
end
function Localization:RegisterLanguage(language, dictionary)
if type(language) ~= "string" or language == "" or type(dictionary) ~= "table" then
return false, "Language and dictionary are required"
end
local merged = self.Languages[language] and table.clone(self.Languages[language]) or {}
for key, text in pairs(dictionary) do
if type(key) == "string" and type(text) == "string" then merged[key] = text end
end
self.Languages[language] = merged
if language == self.Current then self:Refresh() end
return true
end
function Localization:Track(instance, property, key)
if not instance or type(property) ~= "string" or type(key) ~= "string" then return false end
local bucket = self.Tracked[instance]
if not bucket then
bucket = {}
self.Tracked[instance] = bucket
end
bucket[property] = key
pcall(function() instance[property] = self:Get(key) end)
return true
end
function Localization:Untrack(instance, property)
local bucket = instance and self.Tracked[instance]
if not bucket then return end
if property then
bucket[property] = nil
if not next(bucket) then self.Tracked[instance] = nil end
else
self.Tracked[instance] = nil
end
end
function Localization:AddListener(callback)
if type(callback) ~= "function" then return function() end end
local token = {Callback = callback}
self.Listeners[token] = true
return function() self.Listeners[token] = nil end
end
function Localization:Refresh()
for instance, properties in pairs(self.Tracked) do
local alive = false
pcall(function() alive = instance.Parent ~= nil end)
if alive then
for property, key in pairs(properties) do
pcall(function() instance[property] = self:Get(key) end)
end
end
end
local snapshot = {}
for token in pairs(self.Listeners) do snapshot[#snapshot + 1] = token end
for _, token in ipairs(snapshot) do
if self.Listeners[token] then
local ok, err = pcall(token.Callback, self.Current)
if not ok then warn("[JustHub] Localization listener failed: " .. tostring(err)) end
end
end
end
function Localization:Destroy()
table.clear(self.Tracked)
table.clear(self.Listeners)
end
function Localization:SetLanguage(language)
if type(language) ~= "string" or language == "" then
return false, "Language code must be a non-empty string"
end
if not self.Languages[language] then
return false, "Language is not registered: " .. language
end
local changed = self.Current ~= language
self.Current = language
if changed then self:Refresh() end
return true
end
function Localization:Get(key)
local text = self.Languages[self.Current] and self.Languages[self.Current][key]
if text == nil and self.Languages.en then text = self.Languages.en[key] end
if text == nil then text = BUILTIN.en[key] end
return text or tostring(key)
end
return Localization
end)()

Modules.Permissions = (function()
local Permissions = {}
Permissions.__index = Permissions
local DEFAULT_ROLES = {guest = 0, member = 10, moderator = 50, admin = 100}
function Permissions.new()
return setmetatable({
Roles = table.clone(DEFAULT_ROLES),
CurrentRole = "member",
}, Permissions)
end
function Permissions:RegisterRole(name, rank)
if type(name) ~= "string" or name == "" or type(rank) ~= "number"
or rank ~= rank or rank == math.huge or rank == -math.huge then
return false, "Role requires a name and numeric rank"
end
self.Roles[name] = rank
return true
end
function Permissions:SetRole(name)
if type(name) ~= "string" or self.Roles[name] == nil then
return false, "Unknown role"
end
self.CurrentRole = name
return true
end
function Permissions:Check(requiredRole)
if type(requiredRole) ~= "string" or self.Roles[requiredRole] == nil then
return false
end
local current = self.Roles[self.CurrentRole]
if current == nil then return false end
return current >= self.Roles[requiredRole]
end
function Permissions:Destroy()
table.clear(self.Roles)
end
return Permissions
end)()

Modules.Sound = (function()
return function(context)
local Instance = context.Instance
local SoundService = context.SoundService
local RootScope = context.RootScope
local Sound = {}
Sound.__index = Sound
function Sound.new()
return setmetatable({
Sounds = {ButtonClick = 0, SliderMove = 0},
}, Sound)
end
function Sound:Play(name, volume)
if RootScope.Destroyed then return false, "JustHub has been destroyed" end
local assetId = self.Sounds[name]
local numericId = tonumber(assetId) or tonumber(tostring(assetId or ""):match("%d+"))
if not numericId or numericId <= 0 then
return false, "Sound is not configured"
end
local scope = RootScope:CreateScope("Sound:" .. tostring(name))
local audio = Instance.new("Sound")
audio.Name = "JustHubSound"
audio.SoundId = "rbxassetid://" .. tostring(math.floor(numericId))
audio.Volume = Modules.Util.ClampNumber(volume, 0, 1, 0.6)
audio.Parent = SoundService
scope:TrackInstance(audio)
scope:Connect(audio.Ended, function() scope:Destroy() end)
local ok, err = pcall(function() audio:Play() end)
if not ok then
scope:Destroy()
return false, tostring(err)
end
scope:Delay(15, function() scope:Destroy() end)
return true
end
return Sound
end
end)()

Modules.Components = (function()
return function(context)
local Enum = context.Enum
local Util = context.Util
local TweenInfo = context.TweenInfo
local UserInputService = context.UserInputService
local Theme = context.Theme
local State = context.State
local Library = context.Library
local RootScope = context.RootScope
local Kit = context.Kit
local Tokens = Theme.Tokens
local Methods = {}
local keybindRegistry = {}
local make = function(className, properties, parent)
return Kit.make(className, properties, parent, "Failed to set")
end
local bind = Kit.bind
local rounded = Kit.corner
local stroke = Kit.stroke
local textLabel = Kit.text
local LocalizationManager = context.LocalizationManager
local function localize(key)
return context.Localize(key)
end
local function track(instance, property, key)
if LocalizationManager then LocalizationManager:Track(instance, property, key) end
return instance
end
local function applyRole(frame, options)
local role = options and options.Role
if type(role) ~= "string" or role == "" then return end
frame:SetAttribute("JustHubRole", role)
Library._roleFrames[frame] = true
Library:_RefreshRoleFrame(frame)
end
local function nextOrder(section)
section._order = (section._order or 0) + 1
return section._order
end
local function refreshSearch()
local window = Library.Window
if window and type(window.ApplySearch) == "function" then window:ApplySearch() end
end
local function normalizeKeyName(value)
if typeof(value) == "EnumItem" then
if value.EnumType ~= Enum.KeyCode then return nil end
return value.Name
end
if type(value) ~= "string" or value == "" then return nil end
if value == "None" then return "None" end
local ok, key = pcall(function() return Enum.KeyCode[value] end)
if ok and typeof(key) == "EnumItem" then return key.Name end
return nil
end
local function fireInit(scope, title, callback, value)
if type(callback) ~= "function" then return end
task.defer(function()
if scope:IsAlive() then
Util.SafeCall("Initial callback " .. title, callback, value)
end
end)
end

local function isCapturingKeybind()
for record in pairs(keybindRegistry) do
if record.Capturing and record.Scope:IsAlive() then return true end
end
return false
end
Library._IsCapturingKeybind = isCapturingKeybind
if RootScope then
RootScope:Connect(UserInputService.InputBegan, function(inputObject, processed)
if inputObject.UserInputType ~= Enum.UserInputType.Keyboard then return end
local keyName = inputObject.KeyCode.Name
local snapshot = {}
for record in pairs(keybindRegistry) do snapshot[#snapshot + 1] = record end
local consumed = false
for _, record in ipairs(snapshot) do
if keybindRegistry[record] and record.Scope:IsAlive() and record.Capturing then
record.Capturing = false
consumed = true
if keyName == "Backspace" or keyName == "Delete" then
record.Handle:Set("None")
elseif keyName ~= "Escape" then
local normalized = record.Normalize(keyName)
if normalized ~= "None" then record.Handle:Set(normalized) end
end
if record.Button.Parent then record.Button.Text = record.Handle:Get() end
elseif keybindRegistry[record] and not record.Scope:IsAlive() then
keybindRegistry[record] = nil
end
end
if consumed or processed then return end
for _, record in ipairs(snapshot) do
if keybindRegistry[record] and record.Scope:IsAlive() then
local bound = record.Handle:Get()
if bound ~= "None" and keyName == bound and record.Callback then
Util.SafeCall("Keybind callback " .. record.Title, record.Callback, bound)
end
end
end
local toggleKey = normalizeKeyName(Library.ToggleKey)
if toggleKey and toggleKey ~= "None" and keyName == toggleKey and not isCapturingKeybind() then
Library:ToggleUIVisibility()
end
end)
end
local function actionButton(parent, text, position, size, options)
options = options or {}
local button = make("TextButton", {
Name = options.Name or "ActionButton",
Text = tostring(text or ""),
Position = position or UDim2.new(),
Size = size or UDim2.new(0, 90, 0, 30),
BackgroundColor3 = Theme:Get(options.ColorKey or "Color Hub 1"),
BackgroundTransparency = 0,
BorderSizePixel = 0,
AutoButtonColor = false,
Font = options.Font or Enum.Font.GothamSemibold,
TextSize = options.TextSize or Tokens.Typography.Small,
TextColor3 = Theme:Get(options.TextColorKey or "Color Text"),
ZIndex = options.ZIndex or 4,
}, parent)
bind(button, "BackgroundColor3", options.ColorKey or "Color Hub 1")
bind(button, "TextColor3", options.TextColorKey or "Color Text")
rounded(button, options.Radius or 7)
if options.Stroke ~= false then
stroke(button, options.StrokeKey or "Color Stroke", 1)
end
local scope = options.Scope
if scope then
scope:Connect(button.MouseEnter, function()
if not button.Parent then return end
scope:Tween(button, TweenInfo.new(Tokens.Animation.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
BackgroundColor3 = Theme:Get(options.HoverKey or "Color Stroke"),
})
end)
scope:Connect(button.MouseLeave, function()
if not button.Parent then return end
scope:Tween(button, TweenInfo.new(Tokens.Animation.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
BackgroundColor3 = Theme:Get(options.ColorKey or "Color Hub 1"),
})
end)
end
return button
end
local function newControlScope(section, frame, label)
local scope = section.Scope:CreateScope("Control:" .. tostring(label))
scope:TrackInstance(frame)
scope:Connect(frame.Destroying, function() scope:Destroy() end)
scope:AddCleanup(function()
Theme:UnbindTree(frame)
Library._roleFrames[frame] = nil
if LocalizationManager then
LocalizationManager:Untrack(frame)
local ok, descendants = pcall(function() return frame:GetDescendants() end)
if ok then
for _, descendant in ipairs(descendants) do LocalizationManager:Untrack(descendant) end
end
end
for index = #section.Controls, 1, -1 do
if section.Controls[index] == frame then
table.remove(section.Controls, index)
break
end
end
end)
return scope
end
local function makeCard(section, title, height, name)
local frame = make("Frame", {
Name = name or (Util.SanitizeName(title) .. "Control"),
Size = UDim2.new(1, -2, 0, height),
BackgroundColor3 = Theme:Get("Color Hub 2"),
BackgroundTransparency = 0,
BorderSizePixel = 0,
ClipsDescendants = true,
LayoutOrder = nextOrder(section),
ZIndex = 2,
}, section.Content)
bind(frame, "BackgroundColor3", "Color Hub 2")
rounded(frame, Tokens.Geometry.ControlRadius)
stroke(frame, "Color Stroke", 1)
frame:SetAttribute("JustHubSearch", tostring(title):lower())
table.insert(section.Controls, frame)
return frame
end
local function resolveControlId(section, title, options)
local explicit = options and (options.Flag or options.Id)
if type(explicit) == "string" and explicit ~= "" then
if State.Registry[explicit] then
warn("[JustHub] Control ID '" .. explicit .. "' is already registered; generating a unique ID instead")
else
return explicit
end
end
return section:MakeControlId(title)
end
local function createHandle(section, scope, title, default, validator, render, callback, controlId, normalizer)
local id = controlId or section:MakeControlId(title)
local handle, err = State:Create(id, default, validator, render, callback, {
shortName = title,
tab = section.TabName,
section = section.SectionName,
normalize = normalizer,
})
if not handle then
warn("[JustHub] Unable to register control '" .. id .. "': " .. tostring(err))
return nil, err
end
local registrySetter = context.RegisterBuiltinControl(id, handle, {
shortName = title,
defaultValue = Util.Clone(default),
tab = section.TabName,
section = section.SectionName,
})
scope:AddCleanup(function()
handle:Destroy()
Library.ControlRegistry[id] = nil
Library.Controls[id] = nil
if registrySetter then
for alias, setter in pairs(Library.ControlAliases) do
if setter == registrySetter then
Library.ControlAliases[alias] = nil
end
end
end
if type(Library._SyncControlAliases) == "function" then Library:_SyncControlAliases() end
end)
refreshSearch()
return handle
end
local function finiteNumber(value)
return type(value) == "number" and Util.IsFinite(value)
end
function Methods:addMenu(name)
local title = tostring((type(name) == "table" and (name.Name or name.Text)) or name or "Menu")
local frame = make("Frame", {
Name = Util.SanitizeName(title) .. "Menu",
Size = UDim2.new(1, -2, 0, Tokens.Controls.Menu),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0,
BorderSizePixel = 0,
LayoutOrder = nextOrder(self),
}, self.Content)
bind(frame, "BackgroundColor3", "Color Hub 1")
rounded(frame, 8)
stroke(frame, "Color Stroke", 1)
textLabel(frame, title, UDim2.new(0, 12, 0, 0), UDim2.new(1, -24, 1, 0), {
Font = Enum.Font.GothamBold,
TextSize = Tokens.Typography.Section,
})
frame:SetAttribute("JustHubSearch", title:lower())
table.insert(self.Controls, frame)
newControlScope(self, frame, title)
if type(name) == "table" then applyRole(frame, name) end
refreshSearch()
return frame
end
function Methods:addChromaToggle()
return self:addToggle({
Name = "Chroma animation",
Default = Theme.ChromaEnabled,
Callback = function(enabled)
Library:ToggleChroma(enabled)
end,
})
end
function Methods:addToggle(options)
options = type(options) == "table" and options or {}
local title = tostring(options.Name or "Toggle")
local default = options.Default == true
local callback = type(options.Callback) == "function" and options.Callback or nil
local frame = makeCard(self, title, Tokens.Controls.Toggle)
local scope = newControlScope(self, frame, title)
applyRole(frame, options)
textLabel(frame, title, UDim2.new(0, 14, 0, 0), UDim2.new(1, -94, 1, 0), {
Font = Enum.Font.GothamMedium, TextSize = 13, Truncate = true,
})
local switch = make("Frame", {
Name = "Switch",
Size = UDim2.new(0, 46, 0, 24),
Position = UDim2.new(1, -60, 0.5, -12),
BackgroundColor3 = default and Theme:Get("Color Theme") or Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 3,
}, frame)
bind(switch, "BackgroundColor3", default and "Color Theme" or "Color Hub 1")
rounded(switch, 12)
stroke(switch, "Color Stroke", 1)
local knob = make("Frame", {
Size = UDim2.new(0, 18, 0, 18),
Position = default and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
BackgroundColor3 = Theme:Get("Color Text"),
BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 4,
}, switch)
bind(knob, "BackgroundColor3", "Color Text")
rounded(knob, 9)
local hit = make("TextButton", {
Size = UDim2.new(1, 0, 1, 0),
BackgroundTransparency = 1, Text = "", ZIndex = 5,
}, frame)
local handle = createHandle(self, scope, title, default,
function(value) return type(value) == "boolean", "Toggle value must be boolean" end,
function(value)
scope:Tween(knob, TweenInfo.new(Tokens.Animation.Toggle, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
Position = value and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9),
})
local key = value and "Color Theme" or "Color Hub 1"
Theme:UpdateBinding(switch, "BackgroundColor3", key)
scope:Tween(switch, TweenInfo.new(Tokens.Animation.Toggle, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
BackgroundColor3 = Theme:Get(key),
})
if value then
Theme:RegisterChroma(switch, "BackgroundColor3", "Color Theme")
else
Theme:UnregisterChroma(switch, "BackgroundColor3")
end
end,
callback, resolveControlId(self, title, options))
if not handle then return frame end
scope:Connect(hit.Activated, function()
handle:Set(not handle:Get())
end)
if options.FireOnInit == true then fireInit(scope, title, callback, default) end
return frame, handle
end
function Methods:addSlider(options)
options = type(options) == "table" and options or {}
local title = tostring(options.Name or "Slider")
local minimum = tonumber(options.Min)
local maximum = tonumber(options.Max)
local step = tonumber(options.Step or options.Float)
local default = tonumber(options.Default)
local callback = type(options.Callback) == "function" and options.Callback or nil
if not finiteNumber(minimum) then minimum = 0 end
if not finiteNumber(maximum) or maximum <= minimum then maximum = minimum + 100 end
if not finiteNumber(step) or step <= 0 then step = 1 end
if not finiteNumber(default) then default = minimum end
local function countDecimals(number)
local formatted = string.format("%.8f", number):gsub("0+$", ""):gsub("%.$", "")
local dot = formatted:find("%.")
return dot and (#formatted - dot) or 0
end
local precision = math.max(countDecimals(minimum), countDecimals(maximum), countDecimals(step))
local function snap(value)
local bounded = math.clamp(value, minimum, maximum)
local steps = math.floor(((bounded - minimum) / step) + 0.5)
local snapped = math.clamp(minimum + steps * step, minimum, maximum)
return tonumber(string.format("%." .. precision .. "f", snapped))
end
local function format(value)
return precision == 0 and tostring(math.floor(value + 0.5)) or string.format("%." .. precision .. "f", value)
end
default = snap(default)
local frame = makeCard(self, title, Tokens.Controls.Slider)
local scope = newControlScope(self, frame, title)
applyRole(frame, options)
textLabel(frame, title, UDim2.new(0, 14, 0, 5), UDim2.new(0.68, -14, 0, 20), {
Font = Enum.Font.GothamMedium, TextSize = 13, Truncate = true,
})
local valueBox = make("TextBox", {
Size = UDim2.new(0, 62, 0, 24),
Position = UDim2.new(1, -76, 0, 4),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0,
Text = format(default),
Font = Enum.Font.GothamSemibold, TextSize = 12,
TextColor3 = Theme:Get("Color Text"),
ClearTextOnFocus = false,
TextXAlignment = Enum.TextXAlignment.Center,
}, frame)
bind(valueBox, "BackgroundColor3", "Color Hub 1")
bind(valueBox, "TextColor3", "Color Text")
rounded(valueBox, 6)
stroke(valueBox)
local trackButton = make("TextButton", {
Size = UDim2.new(1, -28, 0, 22),
Position = UDim2.new(0, 14, 0, 36),
BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 4,
}, frame)
local track = make("Frame", {
Size = UDim2.new(1, 0, 0, 6),
Position = UDim2.new(0, 0, 0.5, -3),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 3,
}, trackButton)
bind(track, "BackgroundColor3", "Color Hub 1")
rounded(track, 4)
local ratio = (default - minimum) / (maximum - minimum)
local fill = make("Frame", {
Size = UDim2.new(ratio, 0, 1, 0),
BackgroundColor3 = Theme:Get("Color Theme"),
BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 4,
}, track)
bind(fill, "BackgroundColor3", "Color Theme")
rounded(fill, 4)
Theme:RegisterChroma(fill, "BackgroundColor3", "Color Theme")
local thumb = make("Frame", {
AnchorPoint = Vector2.new(0.5, 0.5),
Size = UDim2.new(0, 16, 0, 16),
Position = UDim2.new(1, 0, 0.5, 0),
BackgroundColor3 = Theme:Get("Color Text"),
BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 5,
}, fill)
bind(thumb, "BackgroundColor3", "Color Text")
rounded(thumb, 8)
local function render(value)
valueBox.Text = format(value)
fill.Size = UDim2.new(math.clamp((value - minimum) / (maximum - minimum), 0, 1), 0, 1, 0)
end
local handle = createHandle(self, scope, title, default,
function(value)
return finiteNumber(value) and value >= minimum and value <= maximum,
"Slider value must be finite and inside its configured bounds"
end,
render, callback, resolveControlId(self, title, options),
function(value)
local numeric = tonumber(value)
if finiteNumber(numeric) then return snap(numeric) end
return value
end)
if not handle then return frame end
local dragInput
local dragConnection, endConnection
local function valueFromPosition(position)
local localX = position.X - track.AbsolutePosition.X
local fraction = math.clamp(localX / math.max(1, track.AbsoluteSize.X), 0, 1)
return snap(minimum + fraction * (maximum - minimum))
end
local function stopDrag()
if dragConnection then scope:Disconnect(dragConnection); dragConnection = nil end
if endConnection then scope:Disconnect(endConnection); endConnection = nil end
dragInput = nil
handle:EndEdit(true)
end
scope:AddCleanup(function()
dragInput = nil
dragConnection = nil
endConnection = nil
end)
scope:Connect(trackButton.InputBegan, function(input)
if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
return
end
if dragInput then return end
dragInput = input
handle:BeginEdit()
scope:Tween(thumb, TweenInfo.new(0.1), {Size = UDim2.new(0, 20, 0, 20)})
handle:SetLive(valueFromPosition(input.Position), {skipCallback = true})
dragConnection = scope:Connect(UserInputService.InputChanged, function(changed)
if not dragInput then return end
local isMouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1
and changed.UserInputType == Enum.UserInputType.MouseMovement
local isTouch = dragInput.UserInputType == Enum.UserInputType.Touch and changed == dragInput
if isMouse or isTouch then
handle:SetLive(valueFromPosition(changed.Position), {skipCallback = true})
end
end)
endConnection = scope:Connect(UserInputService.InputEnded, function(ended)
local isMouse = dragInput and dragInput.UserInputType == Enum.UserInputType.MouseButton1
and ended.UserInputType == Enum.UserInputType.MouseButton1
if dragInput and (ended == dragInput or isMouse) then
scope:Tween(thumb, TweenInfo.new(0.1), {Size = UDim2.new(0, 16, 0, 16)})
stopDrag()
end
end)
end)
scope:Connect(UserInputService.WindowFocusReleased, function()
if dragInput then
scope:Tween(thumb, TweenInfo.new(0.1), {Size = UDim2.new(0, 16, 0, 16)})
stopDrag()
end
end)
scope:Connect(valueBox.FocusLost, function()
local numeric = tonumber(Util.Trim(valueBox.Text))
if finiteNumber(numeric) then
handle:Set(snap(numeric))
end
valueBox.Text = format(handle:Get())
end)
if options.FireOnInit == true then fireInit(scope, title, callback, default) end
return frame, handle
end
function Methods:addLabel(options)
options = type(options) == "string" and {Text = options} or (type(options) == "table" and options or {})
local title = tostring(options.Text or options.Name or "Label")
local alignment = tostring(options.Align or "Left")
local frame = make("Frame", {
Name = "LabelControl",
Size = UDim2.new(1, -4, 0, Util.ClampNumber(options.Height, 12, 400, Tokens.Controls.Label)),
BackgroundTransparency = 1, BorderSizePixel = 0,
LayoutOrder = nextOrder(self),
}, self.Content)
local xAlignment = Enum.TextXAlignment.Left
if alignment == "Center" then xAlignment = Enum.TextXAlignment.Center end
if alignment == "Right" then xAlignment = Enum.TextXAlignment.Right end
local colorKey = (type(options.ColorKey) == "string" and Theme:Get(options.ColorKey) ~= nil) and options.ColorKey or "Color Text"
local label = textLabel(frame, title, UDim2.new(0, 8, 0, 0), UDim2.new(1, -16, 1, 0), {
Align = xAlignment, Wrapped = true,
ColorKey = colorKey,
TextSize = Util.ClampNumber(options.TextSize, 6, 48, 12),
})
frame:SetAttribute("JustHubSearch", title:lower())
table.insert(self.Controls, frame)
local scope = newControlScope(self, frame, "Label")
applyRole(frame, options)
refreshSearch()
return {
Frame = frame,
SetText = function(_, newText)
if not scope:IsAlive() then return false end
local text = tostring(newText or "")
label.Text = text
frame:SetAttribute("JustHubSearch", text:lower())
refreshSearch()
return true
end,
GetText = function() return label.Text end,
Destroy = function() scope:Destroy() end,
}
end
function Methods:addTextBox(options)
options = type(options) == "table" and options or {}
local title = tostring(options.Name or "Text input")
local default = type(options.Default) == "string" and options.Default or ""
local callback = type(options.Callback) == "function" and options.Callback or nil
local frame = makeCard(self, title, Tokens.Controls.TextBox)
local scope = newControlScope(self, frame, title)
applyRole(frame, options)
textLabel(frame, title, UDim2.new(0, 12, 0, 0), UDim2.new(0.38, -12, 1, 0), {
Font = Enum.Font.GothamMedium, TextSize = 12, Truncate = true,
})
local input = make("TextBox", {
Name = "Input",
Position = UDim2.new(0.38, 0, 0.5, -16),
Size = UDim2.new(0.62, -12, 0, 32),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0,
Text = default,
PlaceholderText = type(options.Placeholder) == "string" and options.Placeholder or localize("InputHere"),
Font = Enum.Font.Gotham, TextSize = 12,
TextColor3 = Theme:Get("Color Text"),
PlaceholderColor3 = Theme:Get("Color Dark Text"),
ClearTextOnFocus = false,
TextXAlignment = Enum.TextXAlignment.Left,
}, frame)
bind(input, "BackgroundColor3", "Color Hub 1")
bind(input, "TextColor3", "Color Text")
bind(input, "PlaceholderColor3", "Color Dark Text")
rounded(input, 6)
stroke(input)
make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, input)
if type(options.Placeholder) ~= "string" then track(input, "PlaceholderText", "InputHere") end
local maxLength = tonumber(options.MaxLength)
if not finiteNumber(maxLength) or maxLength < 1 then maxLength = nil else maxLength = math.floor(maxLength) end
local handle = createHandle(self, scope, title, default,
function(value) return type(value) == "string", "TextBox value must be a string" end,
function(value) if input.Text ~= value then input.Text = value end end,
callback, resolveControlId(self, title, options),
function(value)
if type(value) == "number" or type(value) == "boolean" then value = tostring(value) end
if type(value) == "string" and maxLength and #value > maxLength then value = value:sub(1, maxLength) end
return value
end)
if not handle then return frame end
scope:Connect(input.FocusLost, function(enterPressed)
if options.OnlyOnEnter == true and not enterPressed then
input.Text = handle:Get()
return
end
handle:Set(input.Text)
if input.Text ~= handle:Get() then input.Text = handle:Get() end
end)
if options.FireOnInit == true then fireInit(scope, title, callback, default) end
return frame, handle
end
local function createDropdownShell(section, title, defaultText)
local frame = makeCard(section, title, Tokens.Dimensions.DropdownHeader, Util.SanitizeName(title) .. "Dropdown")
frame.ClipsDescendants = true
local header = make("TextButton", {
Name = "DropdownHeader",
Size = UDim2.new(1, 0, 0, Tokens.Dimensions.DropdownHeader),
BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 4,
}, frame)
textLabel(header, title, UDim2.new(0, 12, 0, 0), UDim2.new(0.48, -12, 1, 0), {
Font = Enum.Font.GothamMedium, TextSize = 12, Truncate = true, ZIndex = 5,
})
local selected = textLabel(header, defaultText, UDim2.new(0.48, 0, 0, 0), UDim2.new(0.47, -24, 1, 0), {
Align = Enum.TextXAlignment.Right, ColorKey = "Color Dark Text",
TextSize = 11, Truncate = true, ZIndex = 5,
})
local arrow = textLabel(header, "▼", UDim2.new(1, -30, 0, 0), UDim2.new(0, 20, 1, 0), {
Align = Enum.TextXAlignment.Center, TextSize = 11, ColorKey = "Color Dark Text", ZIndex = 5,
})
local body = make("Frame", {
Name = "DropdownBody",
Position = UDim2.new(0, 0, 0, Tokens.Dimensions.DropdownHeader),
Size = UDim2.new(1, 0, 0, 0),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0,
ClipsDescendants = true, ZIndex = 8,
}, frame)
bind(body, "BackgroundColor3", "Color Hub 1")
return frame, header, selected, arrow, body
end
local function updateDropdownSize(scope, frame, body, arrow, isOpen, bodyHeight)
local headerHeight = Tokens.Dimensions.DropdownHeader
local targetHeight = isOpen and (headerHeight + bodyHeight) or headerHeight
scope:Tween(frame, TweenInfo.new(Tokens.Animation.Popup, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
Size = UDim2.new(1, -2, 0, targetHeight),
})
scope:Tween(body, TweenInfo.new(Tokens.Animation.Popup, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
Size = UDim2.new(1, 0, 0, isOpen and bodyHeight or 0),
})
scope:Tween(arrow, TweenInfo.new(Tokens.Animation.Popup), {
Rotation = isOpen and 180 or 0,
})
end
local function createDropdownSearch(parent, textSize)
local search = make("TextBox", {
BackgroundColor3 = Theme:Get("Color Hub 2"),
BackgroundTransparency = 0, BorderSizePixel = 0,
Text = "", PlaceholderText = localize("SearchOptions"),
Font = Enum.Font.Gotham, TextSize = textSize or 11,
TextColor3 = Theme:Get("Color Text"),
PlaceholderColor3 = Theme:Get("Color Dark Text"),
ClearTextOnFocus = false, ZIndex = 10,
}, parent)
track(search, "PlaceholderText", "SearchOptions")
make("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, search)
bind(search, "BackgroundColor3", "Color Hub 2")
bind(search, "TextColor3", "Color Text")
bind(search, "PlaceholderColor3", "Color Dark Text")
rounded(search, 6)
stroke(search)
return search
end
local function createDropdownList(body)
local list = make("ScrollingFrame", {
Position = UDim2.new(0, 8, 0, 42),
Size = UDim2.new(1, -16, 1, -48),
BackgroundTransparency = 1, BorderSizePixel = 0,
ScrollBarThickness = 3,
AutomaticCanvasSize = Enum.AutomaticSize.Y,
CanvasSize = UDim2.new(), ZIndex = 9,
}, body)
bind(list, "ScrollBarImageColor3", "Color Stroke")
make("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}, list)
return list
end
local function makeOptionButton(list, display, isPreset, order)
local button = make("TextButton", {
Size = UDim2.new(1, -4, 0, 30),
LayoutOrder = order or 0,
BackgroundColor3 = Theme:Get("Color Hub 2"),
BackgroundTransparency = 0, BorderSizePixel = 0,
Text = "  " .. display,
Font = Enum.Font.Gotham, TextSize = 11,
TextTruncate = Enum.TextTruncate.AtEnd,
TextColor3 = Theme:Get(isPreset and "Color Theme" or "Color Text"),
TextXAlignment = Enum.TextXAlignment.Left,
AutoButtonColor = false, ZIndex = 10,
}, list)
bind(button, "BackgroundColor3", "Color Hub 2")
bind(button, "TextColor3", isPreset and "Color Theme" or "Color Text")
rounded(button, 5)
return button
end
local function bindOptionHover(rowScope, button)
rowScope:Connect(button.MouseEnter, function()
if button.Parent then
rowScope:Tween(button, TweenInfo.new(Tokens.Animation.Hover), {BackgroundColor3 = Theme:Get("Color Stroke")})
end
end)
rowScope:Connect(button.MouseLeave, function()
if button.Parent then
rowScope:Tween(button, TweenInfo.new(Tokens.Animation.Hover), {BackgroundColor3 = Theme:Get("Color Hub 2")})
end
end)
end
local function bindDropdownEscape(scope, frame, body, arrow, bodyHeight, getOpen, setOpen)
scope:Connect(UserInputService.InputBegan, function(input, processed)
if processed then return end
if getOpen() and input.KeyCode == Enum.KeyCode.Escape then
setOpen(false)
updateDropdownSize(scope, frame, body, arrow, false, bodyHeight)
end
end)
end
function Methods:addDropdown(options)
options = type(options) == "table" and options or {}
local title = tostring(options.Name or "Dropdown")
local default = type(options.Default) == "string" and options.Default or ""
local items = Util.NormalizeStringArray(options.Options or options.Items)
local presets = Util.NormalizeStringArray(options.Presets)
local callback = type(options.Callback) == "function" and options.Callback or nil
local bodyHeight = Tokens.Dimensions.DropdownSingle
local frame, header, selected, arrow, body = createDropdownShell(self, title, default ~= "" and default or localize("Select"))
local scope = newControlScope(self, frame, title)
applyRole(frame, options)
local search = createDropdownSearch(body, 11)
search.Position = UDim2.new(0, 8, 0, 8)
search.Size = UDim2.new(1, -16, 0, 28)
local list = createDropdownList(body)
local isOpen = false
local records = {}
local handle
local function renderFilter(term)
local lower = tostring(term or ""):lower()
for _, record in ipairs(records) do
record.Button.Visible = lower == "" or record.Display:lower():find(lower, 1, true) ~= nil
end
end
local function displayFor(value)
for _, record in ipairs(records) do
if record.Value == value then return record.Display end
end
return tostring(value or "")
end
local function renderSelected()
local value = handle and handle:Get() or default
selected.Text = value ~= "" and displayFor(value) or localize("Select")
for _, record in ipairs(records) do
local key = (record.Value == value and "Color Theme") or (record.IsPreset and "Color Theme" or "Color Text")
record.Button.Font = record.Value == value and Enum.Font.GothamSemibold or Enum.Font.Gotham
Theme:UpdateBinding(record.Button, "TextColor3", key)
record.Button.TextColor3 = Theme:Get(key)
end
end
local function rebuild(newItems)
for _, record in ipairs(records) do
Theme:UnbindTree(record.Button)
record.Scope:Destroy()
end
table.clear(records)
local seen = {}
local function addOption(value, isPreset)
if seen[value] then return end
seen[value] = true
local display = isPreset and ("★ " .. value) or value
local rowScope = scope:CreateScope("DropdownItem")
local button = makeOptionButton(list, display, isPreset, #records + 1)
rowScope:TrackInstance(button)
rowScope:Connect(button.Activated, function()
handle:Set(value)
isOpen = false
updateDropdownSize(scope, frame, body, arrow, false, bodyHeight)
search.Text = ""
end)
bindOptionHover(rowScope, button)
table.insert(records, {Value = value, Display = display, Button = button, Scope = rowScope, IsPreset = isPreset})
end
for _, preset in ipairs(presets) do addOption(preset, true) end
for _, item in ipairs(Util.NormalizeStringArray(newItems)) do addOption(item, false) end
renderFilter(search.Text)
renderSelected()
end
handle = createHandle(self, scope, title, default,
function(value) return type(value) == "string", "Dropdown value must be a string" end,
function() renderSelected() end,
callback, resolveControlId(self, title, options))
if not handle then return frame end
rebuild(items)
if LocalizationManager then scope:AddCleanup(LocalizationManager:AddListener(renderSelected)) end
scope:Connect(search:GetPropertyChangedSignal("Text"), function() renderFilter(search.Text) end)
scope:Connect(header.Activated, function()
isOpen = not isOpen
updateDropdownSize(scope, frame, body, arrow, isOpen, bodyHeight)
if isOpen then search.Text = ""; renderFilter("") end
end)
bindDropdownEscape(scope, frame, body, arrow, bodyHeight, function() return isOpen end, function(v) isOpen = v end)
if options.FireOnInit == true then fireInit(scope, title, callback, handle:Get()) end
return {
Frame = frame,
Handle = handle,
Refresh = function(_, newList, keepSelection)
if not scope:IsAlive() then return false end
items = Util.NormalizeStringArray(newList)
rebuild(items)
if keepSelection == false then
local current = handle:Get()
local exists = false
for _, record in ipairs(records) do
if record.Value == current then exists = true break end
end
if not exists then handle:Set("") end
end
return true
end,
Clear = function()
if not scope:IsAlive() then return false end
handle:Set("")
isOpen = false
search.Text = ""
updateDropdownSize(scope, frame, body, arrow, false, bodyHeight)
return true
end,
GetValue = function() return handle:Get() end,
SetValue = function(_, value) return handle:Set(value) end,
Destroy = function() scope:Destroy() end,
}
end
function Methods:addMultiDropdown(options)
options = type(options) == "table" and options or {}
local title = tostring(options.Name or "Multi select")
local default = Util.NormalizeStringArray(options.Default)
local items = Util.NormalizeStringArray(options.Options or options.Items)
local presets = Util.NormalizeStringArray(options.Presets)
local callback = type(options.Callback) == "function" and options.Callback or nil
local bodyHeight = Tokens.Dimensions.DropdownMulti
table.sort(default)
local defaultText = #default > 0 and table.concat(default, ", ") or localize("Select")
local frame, header, selected, arrow, body = createDropdownShell(self, title, defaultText)
local scope = newControlScope(self, frame, title)
applyRole(frame, options)
local toolbar = make("Frame", {
Position = UDim2.new(0, 8, 0, 7),
Size = UDim2.new(1, -16, 0, 28),
BackgroundTransparency = 1, ZIndex = 10,
}, body)
local selectAll = actionButton(toolbar, localize("SelectAll"), UDim2.new(0, 0, 0, 0), UDim2.new(0, 74, 1, 0), {
ColorKey = "Color Theme", TextSize = 10, Stroke = false, Scope = scope,
})
local clearAll = actionButton(toolbar, localize("ClearAll"), UDim2.new(0, 80, 0, 0), UDim2.new(0, 70, 1, 0), {
ColorKey = "Color Hub 2", TextSize = 10, Scope = scope,
})
selectAll.TextColor3 = Theme:Get("Color Hub 1")
Theme:UpdateBinding(selectAll, "TextColor3", "Color Hub 1")
track(selectAll, "Text", "SelectAll")
track(clearAll, "Text", "ClearAll")
local search = createDropdownSearch(toolbar, 10)
search.Position = UDim2.new(0, 156, 0, 0)
search.Size = UDim2.new(1, -156, 1, 0)
local list = createDropdownList(body)
local selectedSet = {}
for _, item in ipairs(default) do selectedSet[item] = true end
local records = {}
local handle
local function sortedSelection()
local result = {}
for item, active in pairs(selectedSet) do
if active then table.insert(result, item) end
end
table.sort(result)
return result
end
local function updateLabel()
local selectedItems = sortedSelection()
selected.Text = #selectedItems > 0 and table.concat(selectedItems, ", ") or localize("Select")
end
local function renderFilter(term)
local lower = tostring(term or ""):lower()
for _, record in ipairs(records) do
record.Button.Visible = lower == "" or record.Display:lower():find(lower, 1, true) ~= nil
local colorKey = selectedSet[record.Value] == true and "Color Theme" or "Color Hub 1"
record.Check.BackgroundColor3 = Theme:Get(colorKey)
Theme:UpdateBinding(record.Check, "BackgroundColor3", colorKey)
end
end
local function updateState()
local values = sortedSelection()
updateLabel()
renderFilter(search.Text)
handle:Set(values)
end
local pruneSelection = true
local function rebuild(newList)
for _, record in ipairs(records) do
Theme:UnbindTree(record.Button)
record.Scope:Destroy()
end
table.clear(records)
local allowed = {}
local function addOption(value, isPreset)
if allowed[value] then return end
allowed[value] = true
local rowScope = scope:CreateScope("MultiDropdownItem")
local display = isPreset and ("★ " .. value) or value
local button = makeOptionButton(list, display, isPreset, #records + 1)
button.TextTruncate = Enum.TextTruncate.AtEnd
rowScope:TrackInstance(button)
local check = make("Frame", {
Size = UDim2.new(0, 14, 0, 14),
Position = UDim2.new(1, -24, 0.5, -7),
BackgroundColor3 = selectedSet[value] and Theme:Get("Color Theme") or Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 11,
}, button)
bind(check, "BackgroundColor3", selectedSet[value] and "Color Theme" or "Color Hub 1")
rounded(check, 4)
stroke(check)
rowScope:Connect(button.Activated, function()
selectedSet[value] = not selectedSet[value]
updateState()
end)
bindOptionHover(rowScope, button)
table.insert(records, {Value = value, Display = display, Button = button, Check = check, Scope = rowScope})
end
for _, preset in ipairs(presets) do addOption(preset, true) end
for _, item in ipairs(Util.NormalizeStringArray(newList)) do addOption(item, false) end
local pruned = false
if pruneSelection ~= false then
for item in pairs(selectedSet) do
if not allowed[item] then
selectedSet[item] = nil
pruned = true
end
end
end
renderFilter(search.Text)
updateLabel()
if pruned and handle then
handle:Set(sortedSelection())
end
end
handle = createHandle(self, scope, title, default,
function(value)
if not Util.IsDenseArray(value) then
return false, "MultiDropdown value must be a dense array of strings"
end
for _, item in ipairs(value) do
if type(item) ~= "string" then return false, "MultiDropdown values must be strings" end
end
return true
end,
function(value)
table.clear(selectedSet)
for _, item in ipairs(value) do selectedSet[item] = true end
updateLabel()
renderFilter(search.Text)
end,
callback, resolveControlId(self, title, options),
function(value)
if type(value) == "string" then value = {value} end
if type(value) ~= "table" then return value end
local normalized = Util.NormalizeStringArray(value)
table.sort(normalized)
return normalized
end)
if not handle then return frame end
rebuild(items)
if LocalizationManager then scope:AddCleanup(LocalizationManager:AddListener(updateLabel)) end
scope:Connect(search:GetPropertyChangedSignal("Text"), function() renderFilter(search.Text) end)
scope:Connect(selectAll.Activated, function()
for _, item in ipairs(items) do selectedSet[item] = true end
for _, item in ipairs(presets) do selectedSet[item] = true end
updateState()
end)
scope:Connect(clearAll.Activated, function()
table.clear(selectedSet)
updateState()
end)
local isOpen = false
scope:Connect(header.Activated, function()
isOpen = not isOpen
updateDropdownSize(scope, frame, body, arrow, isOpen, bodyHeight)
if isOpen then search.Text = ""; renderFilter("") end
end)
bindDropdownEscape(scope, frame, body, arrow, bodyHeight, function() return isOpen end, function(v) isOpen = v end)
if options.FireOnInit == true then fireInit(scope, title, callback, handle:Get()) end
return {
Frame = frame,
Handle = handle,
Refresh = function(_, newList, keepSelection)
if not scope:IsAlive() then return false end
items = Util.NormalizeStringArray(newList)
pruneSelection = keepSelection ~= true
rebuild(items)
pruneSelection = true
return true
end,
Clear = function()
if not scope:IsAlive() then return false end
table.clear(selectedSet)
updateState()
return true
end,
GetValue = function() return handle:Get() end,
SetValue = function(_, value) return handle:Set(value) end,
Destroy = function() scope:Destroy() end,
}
end
function Methods:addColorPicker(options)
options = type(options) == "table" and options or {}
local title = tostring(options.Name or "Color")
local default = typeof(options.Default) == "Color3" and options.Default or Color3.fromRGB(80, 200, 160)
local callback = type(options.Callback) == "function" and options.Callback or nil
local frame = makeCard(self, title, Tokens.Controls.ColorPicker)
local scope = newControlScope(self, frame, title)
applyRole(frame, options)
textLabel(frame, title, UDim2.new(0, 12, 0, 4), UDim2.new(0.6, -12, 0, 22), {
Font = Enum.Font.GothamMedium, TextSize = 12,
})
local preview = make("Frame", {
Size = UDim2.new(0, 58, 0, 24),
Position = UDim2.new(1, -72, 0, 4),
BackgroundColor3 = default,
BackgroundTransparency = 0, BorderSizePixel = 0,
}, frame)
rounded(preview, 5)
stroke(preview)
local presets = {
Color3.fromRGB(239, 68, 68), Color3.fromRGB(34, 197, 94),
Color3.fromRGB(59, 130, 246), Color3.fromRGB(234, 179, 8),
Color3.fromRGB(168, 85, 247), Color3.fromRGB(6, 182, 212),
Color3.fromRGB(255, 255, 255), Color3.fromRGB(24, 24, 27),
}
local presetRow = make("Frame", {
Position = UDim2.new(0, 12, 0, 34),
Size = UDim2.new(1, -24, 0, 22),
BackgroundTransparency = 1,
}, frame)
make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}, presetRow)
local rBox, gBox, bBox, hexBox
local function sync(color)
preview.BackgroundColor3 = color
if rBox then
rBox.Text = tostring(math.floor(color.R * 255 + 0.5))
gBox.Text = tostring(math.floor(color.G * 255 + 0.5))
bBox.Text = tostring(math.floor(color.B * 255 + 0.5))
hexBox.Text = "#" .. color:ToHex():upper()
end
end
local handle = createHandle(self, scope, title, default,
function(value) return typeof(value) == "Color3", "ColorPicker value must be Color3" end,
sync, callback, resolveControlId(self, title, options),
function(value)
if type(value) == "string" then
local ok, color = pcall(Color3.fromHex, (value:gsub("#", "")))
if ok and typeof(color) == "Color3" then return color end
elseif type(value) == "table" and typeof(value) ~= "Color3" then
local red, green, blue = tonumber(value.R or value[1]), tonumber(value.G or value[2]), tonumber(value.B or value[3])
if finiteNumber(red) and finiteNumber(green) and finiteNumber(blue) then
if red > 1 or green > 1 or blue > 1 then
return Color3.fromRGB(math.clamp(red, 0, 255), math.clamp(green, 0, 255), math.clamp(blue, 0, 255))
end
return Color3.new(math.clamp(red, 0, 1), math.clamp(green, 0, 1), math.clamp(blue, 0, 1))
end
end
return value
end)
if not handle then return frame end
for index, color in ipairs(presets) do
local swatch = make("TextButton", {
Size = UDim2.new(0, 20, 0, 20),
LayoutOrder = index,
BackgroundColor3 = color,
BackgroundTransparency = 0, BorderSizePixel = 0,
Text = "", AutoButtonColor = false,
}, presetRow)
rounded(swatch, 10)
stroke(swatch, "Color Stroke", 1)
scope:Connect(swatch.Activated, function() handle:Set(color) end)
end
local inputRow = make("Frame", {
Position = UDim2.new(0, 12, 0, 63),
Size = UDim2.new(1, -24, 0, 24),
BackgroundTransparency = 1,
}, frame)
make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, inputRow)
local boxOrder = 0
local function colorBox(name, initial, width, textColor)
boxOrder += 1
local box = make("TextBox", {
Name = name,
LayoutOrder = boxOrder,
Size = UDim2.new(0, width, 1, 0),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0,
Text = initial,
Font = Enum.Font.GothamMedium, TextSize = 10,
TextColor3 = textColor or Theme:Get("Color Text"),
ClearTextOnFocus = false,
TextXAlignment = Enum.TextXAlignment.Center,
}, inputRow)
bind(box, "BackgroundColor3", "Color Hub 1")
if not textColor then bind(box, "TextColor3", "Color Text") end
rounded(box, 4)
stroke(box)
return box
end
rBox = colorBox("Red", "", 38, Color3.fromRGB(255, 115, 115))
gBox = colorBox("Green", "", 38, Color3.fromRGB(115, 230, 140))
bBox = colorBox("Blue", "", 38, Color3.fromRGB(115, 165, 255))
hexBox = colorBox("Hex", "", 82)
sync(default)
local function commitRgb()
local red, green, blue = tonumber(rBox.Text), tonumber(gBox.Text), tonumber(bBox.Text)
if not (finiteNumber(red) and finiteNumber(green) and finiteNumber(blue)) then
sync(handle:Get())
return
end
handle:Set(Color3.fromRGB(
math.floor(math.clamp(red, 0, 255) + 0.5),
math.floor(math.clamp(green, 0, 255) + 0.5),
math.floor(math.clamp(blue, 0, 255) + 0.5)
))
end
local function commitHex()
local hex = Util.Trim(hexBox.Text):gsub("#", "")
local valid = hex:match("^%x%x%x%x%x%x$") or hex:match("^%x%x%x$")
local ok, color = false, nil
if valid then ok, color = pcall(Color3.fromHex, hex) end
if ok and typeof(color) == "Color3" then
handle:Set(color)
end
sync(handle:Get())
end
local function commitRgbAndSync()
commitRgb()
sync(handle:Get())
end
scope:Connect(rBox.FocusLost, commitRgbAndSync)
scope:Connect(gBox.FocusLost, commitRgbAndSync)
scope:Connect(bBox.FocusLost, commitRgbAndSync)
scope:Connect(hexBox.FocusLost, commitHex)
if options.FireOnInit == true then fireInit(scope, title, callback, handle:Get()) end
return frame, handle
end
function Methods:addScriptBox(options)
options = type(options) == "table" and options or {}
local title = tostring(options.Name or "Script editor")
local default = type(options.Default) == "string" and options.Default or ""
local callback = type(options.Callback) == "function" and options.Callback or nil
local frame = makeCard(self, title, Tokens.Controls.ScriptBox)
local scope = newControlScope(self, frame, title)
applyRole(frame, options)
textLabel(frame, title, UDim2.new(0, 12, 0, 5), UDim2.new(1, -24, 0, 20), {
Font = Enum.Font.GothamMedium, TextSize = 12,
})
local input = make("TextBox", {
Position = UDim2.new(0, 12, 0, 30),
Size = UDim2.new(1, -96, 0, 88),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0,
Text = default,
PlaceholderText = type(options.Placeholder) == "string" and options.Placeholder or localize("PasteHere"),
Font = Enum.Font.Code, TextSize = 11,
ClipsDescendants = true,
TextColor3 = Theme:Get("Color Text"),
ClearTextOnFocus = false,
MultiLine = true,
TextWrapped = true,
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
}, frame)
bind(input, "BackgroundColor3", "Color Hub 1")
bind(input, "TextColor3", "Color Text")
rounded(input, 6)
stroke(input)
make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 6)}, input)
local runButton = actionButton(frame, options.ButtonText and tostring(options.ButtonText) or localize("Run"), UDim2.new(1, -76, 0, 54), UDim2.new(0, 64, 0, 34), {
ColorKey = "Color Theme", TextColorKey = "Color Hub 1", Scope = scope,
})
if type(options.Placeholder) ~= "string" then track(input, "PlaceholderText", "PasteHere") end
if not options.ButtonText then track(runButton, "Text", "Run") end
local handle = createHandle(self, scope, title, default,
function(value) return type(value) == "string", "ScriptBox value must be a string" end,
function(value) if input.Text ~= value then input.Text = value end end,
nil, resolveControlId(self, title, options))
if not handle then return frame end
scope:Connect(input.FocusLost, function() handle:Set(input.Text, {skipCallback = true}) end)
scope:Connect(runButton.Activated, function()
handle:Set(input.Text, {skipCallback = true})
if callback then Util.SafeCall("ScriptBox callback " .. title, callback, input.Text) end
end)
return frame, handle
end
function Methods:addBind(options)
options = type(options) == "table" and options or {}
local title = tostring(options.Name or "Keybind")
local requestedDefault = options.Default
local default = requestedDefault
if default == nil then default = "RightShift" end
default = normalizeKeyName(default) or "RightShift"
local callback = type(options.Callback) == "function" and options.Callback or nil
local changedCallback = type(options.ChangedCallback) == "function" and options.ChangedCallback or nil
local frame = makeCard(self, title, Tokens.Controls.Bind)
local scope = newControlScope(self, frame, title)
applyRole(frame, options)
textLabel(frame, title, UDim2.new(0, 12, 0, 0), UDim2.new(0.55, -12, 1, 0), {
Font = Enum.Font.GothamMedium, TextSize = 12, Truncate = true,
})
local button = make("TextButton", {
Position = UDim2.new(0.58, 0, 0.5, -15),
Size = UDim2.new(0.42, -12, 0, 30),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0,
Text = default,
Font = Enum.Font.GothamSemibold, TextSize = 11,
TextColor3 = Theme:Get("Color Text"),
AutoButtonColor = false,
TextXAlignment = Enum.TextXAlignment.Center,
}, frame)
bind(button, "BackgroundColor3", "Color Hub 1")
bind(button, "TextColor3", "Color Text")
rounded(button, 6)
stroke(button)
local blacklist = {
Escape = true, Tab = true, Backspace = true, Return = true, Unknown = true,
}
local function normalizeKey(value)
local name = normalizeKeyName(value)
if not name or name == "None" or blacklist[name] then return "None" end
return name
end
local defaultKey = normalizeKey(default)
if defaultKey == "None" and requestedDefault ~= nil and requestedDefault ~= "None" then
warn("[JustHub] Keybind '" .. title .. "' default is not a supported key, using RightShift")
defaultKey = "RightShift"
end
button.Text = defaultKey
local handle = createHandle(self, scope, title, defaultKey,
function(value)
return type(value) == "string" and (value == "None" or normalizeKey(value) == value),
"Keybind must be a valid, supported key name"
end,
function(value) button.Text = value end,
changedCallback, resolveControlId(self, title, options),
function(value)
if value == nil or value == "" then return "None" end
local name = normalizeKeyName(value)
if name then return name end
return value
end)
if not handle then return frame end
local keybindRecord = {
Title = title,
Button = button,
Handle = handle,
Scope = scope,
Callback = callback,
Normalize = normalizeKey,
Capturing = false,
}
keybindRegistry[keybindRecord] = true
scope:AddCleanup(function()
keybindRegistry[keybindRecord] = nil
end)
scope:Connect(button.Activated, function()
local capturing = not keybindRecord.Capturing
if capturing then
for record in pairs(keybindRegistry) do
if record ~= keybindRecord and record.Capturing then
record.Capturing = false
if record.Button.Parent then record.Button.Text = record.Handle:Get() end
end
end
end
keybindRecord.Capturing = capturing
button.Text = capturing and localize("PressKey") or handle:Get()
end)
return frame, handle
end
function Methods:addButton(options)
options = type(options) == "table" and options or {}
local title = tostring(options.Name or "Action")
local buttonText = tostring(options.ButtonText or "Run")
local callback = type(options.Callback) == "function" and options.Callback or function() end
local cooldown = Util.ClampNumber(options.Cooldown, 0, 60, 0)
local lastActivated = -math.huge
local frame = makeCard(self, title, Tokens.Controls.Button)
local scope = newControlScope(self, frame, title)
applyRole(frame, options)
textLabel(frame, title, UDim2.new(0, 12, 0, 0), UDim2.new(0.56, -12, 1, 0), {
Font = Enum.Font.GothamMedium, TextSize = 12, Truncate = true,
})
local button = actionButton(frame, buttonText, UDim2.new(0.56, 0, 0.5, -15), UDim2.new(0.44, -12, 0, 30), {
ColorKey = "Color Theme", TextColorKey = "Color Hub 1", Scope = scope, TextSize = 11,
})
local enabled = true
scope:Connect(button.Activated, function()
if not enabled then return end
local now = os.clock()
if now - lastActivated < cooldown then return end
lastActivated = now
Util.SafeCall("Button callback " .. title, callback)
end)
local handle = setmetatable({
Frame = frame,
Instance = button,
Activated = button.Activated,
SetEnabled = function(_, value)
enabled = value ~= false
button.Active = enabled
button.Selectable = enabled
button.TextTransparency = enabled and 0 or 0.5
return enabled
end,
GetEnabled = function() return enabled end,
Fire = function() button.Activated:Fire() end,
}, {
__index = function(_, key) return button[key] end,
__newindex = function(_, key, value) button[key] = value end,
})
refreshSearch()
return frame, handle
end
function Methods:addConfigManager()
local title = "Configuration profiles"
local frame = makeCard(self, title, Tokens.Controls.ConfigManager, "ConfigManagerControl")
local scope = newControlScope(self, frame, title)
frame:SetAttribute("JustHubSearch", "configuration profiles config save load delete")
local input = make("TextBox", {
Position = UDim2.new(0, 10, 0, 10),
Size = UDim2.new(1, -20, 0, 30),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0,
Text = "DefaultConfig",
PlaceholderText = localize("ConfigName"),
Font = Enum.Font.Gotham, TextSize = 11,
TextColor3 = Theme:Get("Color Text"),
PlaceholderColor3 = Theme:Get("Color Dark Text"),
ClearTextOnFocus = false,
TextXAlignment = Enum.TextXAlignment.Left,
}, frame)
bind(input, "BackgroundColor3", "Color Hub 1")
bind(input, "TextColor3", "Color Text")
bind(input, "PlaceholderColor3", "Color Dark Text")
track(input, "PlaceholderText", "ConfigName")
make("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, input)
rounded(input, 6)
stroke(input)
local saveButton = actionButton(frame, localize("SaveProfile"), UDim2.new(0, 10, 0, 50), UDim2.new(0.32, -8, 0, 28), {
ColorKey = "Color Theme", TextColorKey = "Color Hub 1", Scope = scope, TextSize = 10,
})
local loadButton = actionButton(frame, localize("LoadProfile"), UDim2.new(0.34, 0, 0, 50), UDim2.new(0.32, -8, 0, 28), {
ColorKey = "Color Hub 1", Scope = scope, TextSize = 10,
})
local deleteButton = actionButton(frame, localize("DeleteProfile"), UDim2.new(0.68, -2, 0, 50), UDim2.new(0.32, -8, 0, 28), {
ColorKey = "Color Stroke", Scope = scope, TextSize = 10,
})
track(saveButton, "Text", "SaveProfile")
track(loadButton, "Text", "LoadProfile")
track(deleteButton, "Text", "DeleteProfile")
local profileList = make("ScrollingFrame", {
Name = "Profiles",
Position = UDim2.new(0, 10, 0, 86),
Size = UDim2.new(1, -20, 0, 46),
BackgroundTransparency = 1, BorderSizePixel = 0,
ScrollBarThickness = 3,
ScrollingDirection = Enum.ScrollingDirection.X,
CanvasSize = UDim2.new(0, 0, 0, 0),
ScrollBarImageColor3 = Theme:Get("Color Dark Text"),
}, frame)
make("UIListLayout", {
FillDirection = Enum.FillDirection.Horizontal,
Padding = UDim.new(0, 6),
VerticalAlignment = Enum.VerticalAlignment.Center,
}, profileList)
local emptyProfiles = textLabel(profileList, localize("NoProfiles"), UDim2.new(0, 0, 0, 0), UDim2.new(0, 200, 1, 0), {
TextSize = 11, ColorKey = "Color Dark Text", Truncate = true,
})
local function refreshProfiles()
local names = Library:ListConfigs()
for _, child in ipairs(profileList:GetChildren()) do
if child:IsA("TextButton") then child:Destroy() end
end
emptyProfiles.Visible = #names == 0
for _, name in ipairs(names) do
local chip = make("TextButton", {
Name = "Profile",
Size = UDim2.new(0, 96, 0, 24),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0,
AutoButtonColor = false,
Font = Enum.Font.GothamMedium, TextSize = 10,
Text = name,
TextColor3 = Theme:Get("Color Text"),
TextTruncate = Enum.TextTruncate.AtEnd,
}, profileList)
rounded(chip, 6)
stroke(chip)
bind(chip, "BackgroundColor3", "Color Hub 1")
bind(chip, "TextColor3", "Color Text")
scope:TrackInstance(chip)
scope:Connect(chip.Activated, function()
input.Text = name
end)
end
profileList.CanvasSize = UDim2.new(0, #names * 102, 0, 0)
end
local busy = false
local function run(label, action)
if busy then return end
busy = true
local ok, result = Util.SafeCall("Config " .. label, action, Util.Trim(input.Text))
busy = false
refreshProfiles()
if not ok then
Library:Notify({Title = label, Message = tostring(result), Duration = 4})
end
end
scope:Connect(saveButton.Activated, function()
run("Save Config", function(name)
local ok, err = Library:SaveConfig(name)
if not ok then Library:Notify({Title = "Save Config", Message = tostring(err), Duration = 4}) end
end)
end)
scope:Connect(loadButton.Activated, function()
run("Load Config", function(name)
local ok, result = Library:LoadConfig(name)
if not ok then Library:Notify({Title = "Load Config", Message = tostring(result), Duration = 4}) end
end)
end)
scope:Connect(deleteButton.Activated, function()
run("Delete Config", function(name)
local ok, result = Library:DeleteConfig(name)
if not ok then Library:Notify({Title = "Delete Config", Message = tostring(result), Duration = 4}) end
end)
end)
local handle = {
Frame = frame,
Input = input,
Refresh = refreshProfiles,
List = function() return Library:ListConfigs() end,
GetName = function() return input.Text end,
SetName = function(_, value) input.Text = tostring(value or "") end,
}
refreshProfiles()
refreshSearch()
return frame, handle
end
Methods.AddMenu = Methods.addMenu
Methods.AddChromaToggle = Methods.addChromaToggle
Methods.AddToggle = Methods.addToggle
Methods.AddSlider = Methods.addSlider
Methods.AddLabel = Methods.addLabel
Methods.AddTextBox = Methods.addTextBox
Methods.AddDropdown = Methods.addDropdown
Methods.AddMultiDropdown = Methods.addMultiDropdown
Methods.AddColorPicker = Methods.addColorPicker
Methods.AddScriptBox = Methods.addScriptBox
Methods.AddBind = Methods.addBind
Methods.AddButton = Methods.addButton
Methods.AddConfigManager = Methods.addConfigManager
return Methods
end
end)()

Modules.Window = (function()
return function(context)
local Instance = context.Instance
local Enum = context.Enum
local Players = context.Players
local UserInputService = context.UserInputService
local Theme = context.Theme
local RootScope = context.RootScope
local Components = context.Components
local Library = context.Library
local TweenInfo = context.TweenInfo
local Util = context.Util
local Kit = context.Kit
local Tokens = Theme.Tokens
local Window = {}
Window.__index = Window
local make = function(className, properties, parent)
return Kit.make(className, properties, parent, "Window property error")
end
local bind = Kit.bind
local corner = Kit.corner
local makeText = Kit.text
local function border(object, thickness)
return Kit.stroke(object, "Color Stroke", thickness)
end
local function makeHeaderButton(parent, name, glyph, colorKey, order)
local button = make("TextButton", {
Name = name,
Text = glyph,
Size = UDim2.new(0, 28, 0, 28),
LayoutOrder = order,
BackgroundColor3 = Theme:Get(colorKey or "Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0,
AutoButtonColor = false,
Font = Enum.Font.GothamBold, TextSize = 13,
TextColor3 = Theme:Get("Color Text"),
ZIndex = 5,
}, parent)
bind(button, "BackgroundColor3", colorKey or "Color Hub 1")
bind(button, "TextColor3", "Color Text")
corner(button, 7)
border(button)
return button
end
local function getViewport()
local camera = workspace.CurrentCamera
if camera and camera.ViewportSize.X > 0 and camera.ViewportSize.Y > 0 then return camera.ViewportSize end
return Vector2.new(1280, 720)
end
local function resolveIcon(iconName)
if type(iconName) ~= "string" or iconName == "" then return nil end
local asset = Library.Icons[iconName] or Library.Icons[iconName:lower()]
if asset then return asset end
if iconName:match("^rbxassetid://%d+$") or iconName:match("^rbxasset://") or iconName:match("^https?://") then return iconName end
if iconName:match("^%d+$") then return "rbxassetid://" .. iconName end
return nil
end
function Window.new(options)
local createdScope
local buildOk, builtWindow = xpcall(function()
options = type(options) == "table" and options or {}
local player = Players.LocalPlayer
if not player then
error("JustHub requires a client context with Players.LocalPlayer", 2)
end
local windowScope = RootScope:CreateScope("Window")
createdScope = windowScope
local parent = typeof(options.Parent) == "Instance" and options.Parent or nil
if not parent then
parent = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 30)
if options.UseCoreGui == true then
local candidates = {}
if type(gethui) == "function" then
local hiddenOk, hidden = pcall(gethui)
if hiddenOk and typeof(hidden) == "Instance" then candidates[#candidates + 1] = hidden end
end
local ok, core = pcall(function() return game:GetService("CoreGui") end)
if ok and core then candidates[#candidates + 1] = core end
for _, candidate in ipairs(candidates) do
local probe = Instance.new("ScreenGui")
local parentOk = pcall(function() probe.Parent = candidate end)
Util.SafeDestroy(probe)
if parentOk then
parent = candidate
break
end
end
end
end
if not parent then
error("JustHub could not find a valid GUI container", 0)
end
for _, child in ipairs(parent:GetChildren()) do
if child.Name == "JustHub" or child.Name == "JustHubShowUI" or (child.Name == "JustHubLoadingScreen" and child ~= Library._activeLoadingScreen) then
local cleanup = child:FindFirstChild("__JustHubCleanup")
if cleanup and cleanup:IsA("BindableFunction") then
pcall(function() cleanup:Invoke() end)
end
Util.SafeDestroy(child)
end
end
local screen = make("ScreenGui", {
Name = "JustHub",
ResetOnSpawn = false,
IgnoreGuiInset = true,
ZIndexBehavior = Enum.ZIndexBehavior.Global,
DisplayOrder = math.floor(Util.ClampNumber(options.DisplayOrder, -2147483648, 2147483647, 900)),
}, parent)
windowScope:TrackInstance(screen)
windowScope:AddCleanup(function() Theme:UnbindTree(screen) end)
Library.ScreenGui = screen
Library.ScreenGuis = {screen}
if options.ToggleKey ~= nil then Library.ToggleKey = options.ToggleKey end
local bridge = make("BindableFunction", {Name = "__JustHubCleanup"}, screen)
bridge.OnInvoke = function()
Library:Destroy()
return true
end
local viewport = getViewport()
local savedSize = type(Library.Save.UISize) == "table" and Library.Save.UISize or {}
local desiredWidth = Util.ClampNumber(options.Width or savedSize[1], 0, 10000, 760)
local desiredHeight = Util.ClampNumber(options.Height or savedSize[2], 0, 10000, 520)
local maxInitialWidth = math.max(240, viewport.X - 24)
local maxInitialHeight = math.max(200, viewport.Y - 24)
local minInitialWidth = math.min(Tokens.Dimensions.MinWidth, maxInitialWidth)
local minInitialHeight = math.min(Tokens.Dimensions.MinHeight, maxInitialHeight)
local width = math.clamp(desiredWidth, minInitialWidth, maxInitialWidth)
local height = math.clamp(desiredHeight, minInitialHeight, maxInitialHeight)
local main = make("Frame", {
Name = "MainFrame",
AnchorPoint = Vector2.new(0.5, 0.5),
Position = UDim2.fromScale(0.5, 0.5),
Size = UDim2.fromOffset(width, height),
BackgroundColor3 = Theme:Get("Color Hub 2"),
BackgroundTransparency = 0, BorderSizePixel = 0,
ClipsDescendants = true, Active = true, ZIndex = 1,
}, screen)
bind(main, "BackgroundColor3", "Color Hub 2")
corner(main, Tokens.Geometry.WindowRadius)
border(main, 1)
local header = make("Frame", {
Name = "TopBar",
Size = UDim2.new(1, 0, 0, Tokens.Dimensions.Header),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0,
Active = true, ZIndex = 2,
}, main)
bind(header, "BackgroundColor3", "Color Hub 1")
local title = makeText(header, options.Name or "JustHub", UDim2.new(0, 20, 0, 7), UDim2.new(1, -180, 0, 22), {
Font = Enum.Font.GothamBold, TextSize = 17, Truncate = true,
})
local subtitle = makeText(header, tostring(options.Subtitle or options.SubTitle or "MODULAR INTERFACE FRAMEWORK"), UDim2.new(0, 20, 0, 30), UDim2.new(1, -180, 0, 16), {
Font = Enum.Font.GothamMedium, TextSize = 9, ColorKey = "Color Dark Text", Truncate = true,
})
local headerButtons = make("Frame", {
Name = "HeaderActions",
AnchorPoint = Vector2.new(1, 0.5),
Position = UDim2.new(1, -14, 0.5, 0),
Size = UDim2.new(0, 146, 0, 30),
BackgroundTransparency = 1, ZIndex = 4,
}, header)
make("UIListLayout", {
FillDirection = Enum.FillDirection.Horizontal,
HorizontalAlignment = Enum.HorizontalAlignment.Right,
VerticalAlignment = Enum.VerticalAlignment.Center,
Padding = UDim.new(0, 6),
SortOrder = Enum.SortOrder.LayoutOrder,
}, headerButtons)
local minimizeButton = makeHeaderButton(headerButtons, "MinimizeButton", "−", "Color Hub 2", 1)
local maximizeButton = makeHeaderButton(headerButtons, "MaximizeButton", "□", "Color Hub 2", 2)
local lockButton = makeHeaderButton(headerButtons, "LockButton", "U", "Color Hub 2", 3)
local closeButton = makeHeaderButton(headerButtons, "CloseButton", "×", "Color Stroke", 4)
local body = make("Frame", {
Name = "Body",
Position = UDim2.new(0, 0, 0, Tokens.Dimensions.Header),
Size = UDim2.new(1, 0, 1, -82),
BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
}, main)
local sideWidth = math.floor(Util.ClampNumber(options.SidebarWidth or Library.Save.TabSize, 100, 320, Tokens.Dimensions.Sidebar))
local sidebar = make("Frame", {
Name = "Sidebar",
Position = UDim2.new(0, 14, 0, 12),
Size = UDim2.new(0, sideWidth, 1, -24),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 2,
}, body)
bind(sidebar, "BackgroundColor3", "Color Hub 1")
corner(sidebar, Tokens.Geometry.SidebarRadius)
border(sidebar)
local sidebarTitle = makeText(sidebar, "JUSTHUB", UDim2.new(0, 14, 0, 14), UDim2.new(1, -28, 0, 24), {
Font = Enum.Font.GothamBlack, TextSize = 15,
})
local sidebarSubtitle = makeText(sidebar, "CONTROL CENTER", UDim2.new(0, 14, 0, 36), UDim2.new(1, -28, 0, 16), {
Font = Enum.Font.GothamMedium, TextSize = 8, ColorKey = "Color Dark Text",
})
local playerCard = make("Frame", {
Position = UDim2.new(0, 10, 0, 64),
Size = UDim2.new(1, -20, 0, 44),
BackgroundColor3 = Theme:Get("Color Hub 2"),
BackgroundTransparency = 0, BorderSizePixel = 0,
}, sidebar)
bind(playerCard, "BackgroundColor3", "Color Hub 2")
corner(playerCard, 7)
makeText(playerCard, player.DisplayName or player.Name, UDim2.new(0, 9, 0, 0), UDim2.new(1, -18, 1, 0), {
Font = Enum.Font.GothamSemibold, TextSize = 11, Truncate = true,
})
local tabList = make("ScrollingFrame", {
Name = "TabList",
Position = UDim2.new(0, 8, 0, 118),
Size = UDim2.new(1, -16, 1, -130),
BackgroundTransparency = 1, BorderSizePixel = 0,
ScrollBarThickness = 2,
AutomaticCanvasSize = Enum.AutomaticSize.Y,
CanvasSize = UDim2.new(), ZIndex = 3,
}, sidebar)
bind(tabList, "ScrollBarImageColor3", "Color Stroke")
make("UIListLayout", {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}, tabList)
local content = make("Frame", {
Name = "ContentContainer",
Position = UDim2.new(0, sideWidth + 28, 0, 12),
Size = UDim2.new(1, -(sideWidth + 42), 1, -24),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0,
ClipsDescendants = true, ZIndex = 2,
}, body)
bind(content, "BackgroundColor3", "Color Hub 1")
corner(content, 10)
border(content)
local searchFrame = make("Frame", {
Name = "SearchFrame",
Position = UDim2.new(0, 12, 0, 12),
Size = UDim2.new(1, -24, 0, 36),
BackgroundColor3 = Theme:Get("Color Hub 2"),
BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 3,
}, content)
bind(searchFrame, "BackgroundColor3", "Color Hub 2")
corner(searchFrame, 7)
border(searchFrame)
makeText(searchFrame, "⌕", UDim2.new(0, 10, 0, 0), UDim2.new(0, 20, 1, 0), {
Font = Enum.Font.GothamBold, TextSize = 20, ColorKey = "Color Dark Text", Align = Enum.TextXAlignment.Center,
})
local searchBox = make("TextBox", {
Name = "SearchBox",
Position = UDim2.new(0, 34, 0, 0),
Size = UDim2.new(1, -44, 1, 0),
BackgroundTransparency = 1, BorderSizePixel = 0,
Text = "",
PlaceholderText = context.Localize("Search"),
Font = Enum.Font.Gotham, TextSize = 11,
TextColor3 = Theme:Get("Color Text"),
PlaceholderColor3 = Theme:Get("Color Dark Text"),
ClearTextOnFocus = false,
TextXAlignment = Enum.TextXAlignment.Left,
}, searchFrame)
if context.LocalizationManager then context.LocalizationManager:Track(searchBox, "PlaceholderText", "Search") end
bind(searchBox, "TextColor3", "Color Text")
bind(searchBox, "PlaceholderColor3", "Color Dark Text")
local pages = make("Frame", {
Name = "TabPages",
Position = UDim2.new(0, 12, 0, 60),
Size = UDim2.new(1, -24, 1, -72),
BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2,
}, content)
local footer = make("Frame", {
Name = "Footer",
Position = UDim2.new(0, 14, 1, -22),
Size = UDim2.new(1, -28, 0, 16),
BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
}, main)
makeText(footer, "JustHub " .. tostring(Library.Info.Version), UDim2.new(0, 0, 0, 0), UDim2.new(0.6, 0, 1, 0), {
TextSize = 9, ColorKey = "Color Dark Text",
})
makeText(footer, "READY", UDim2.new(1, -72, 0, 0), UDim2.new(0, 72, 1, 0), {
TextSize = 9, ColorKey = "Color Theme", Font = Enum.Font.GothamBold, Align = Enum.TextXAlignment.Right,
})
local resizeHandle = make("TextButton", {
Name = "ResizeHandle",
Position = UDim2.new(1, -20, 1, -20),
Size = UDim2.new(0, 18, 0, 18),
BackgroundTransparency = 1,
Text = "◢",
Font = Enum.Font.GothamBold, TextSize = 12,
TextColor3 = Theme:Get("Color Dark Text"),
AutoButtonColor = false, ZIndex = 10,
}, main)
bind(resizeHandle, "TextColor3", "Color Dark Text")
local notificationContainer = make("Frame", {
Name = "NotificationContainer",
AnchorPoint = Vector2.new(1, 0),
Position = UDim2.new(1, -18, 0, 18),
Size = UDim2.new(0, 310, 1, -36),
BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 100,
}, screen)
make("UIListLayout", {
HorizontalAlignment = Enum.HorizontalAlignment.Right,
VerticalAlignment = Enum.VerticalAlignment.Top,
Padding = UDim.new(0, 8),
SortOrder = Enum.SortOrder.LayoutOrder,
}, notificationContainer)
Library.NotificationContainer = notificationContainer
local window = setmetatable({
Name = tostring(options.Name or "JustHub"),
ScreenGui = screen,
MainFrame = main,
Tabs = {},
Scope = windowScope,
Sidebar = sidebar,
Content = content,
SearchBox = searchBox,
IsMaximized = false,
IsMinimized = false,
Locked = Library.Save.Locked == true,
_restoreSize = UDim2.fromOffset(width, height),
_restorePosition = UDim2.fromScale(0.5, 0.5),
_minimizedFrom = nil,
}, Window)
Library.Window = window
windowScope:Connect(screen.Destroying, function()
if Library.Window == window then Library.Window = nil end
if Library.ScreenGui == screen then Library.ScreenGui = nil end
if Library.NotificationContainer == notificationContainer then Library.NotificationContainer = nil end
if type(Library.ScreenGuis) == "table" then
for index = #Library.ScreenGuis, 1, -1 do
if Library.ScreenGuis[index] == screen then table.remove(Library.ScreenGuis, index) end
end
end
windowScope:Destroy()
end)
local applyResponsive
local function currentSize()
local size = main.Size
if size.X.Scale == 0 and size.Y.Scale == 0 then
return Vector2.new(size.X.Offset, size.Y.Offset)
end
return main.AbsoluteSize
end
local function clampPosition()
local vp = getViewport()
local size = currentSize()
local halfW, halfH = size.X / 2, size.Y / 2
local pos = main.Position
local centerX = vp.X * pos.X.Scale + pos.X.Offset
local centerY = vp.Y * pos.Y.Scale + pos.Y.Offset
local margin = 8
local minX = math.min(halfW + margin, vp.X / 2)
local maxX = math.max(vp.X - halfW - margin, vp.X / 2)
local minY = math.min(halfH + margin, vp.Y / 2)
local maxY = math.max(vp.Y - halfH - margin, vp.Y / 2)
centerX = math.clamp(centerX, minX, maxX)
centerY = math.clamp(centerY, minY, maxY)
main.Position = UDim2.new(pos.X.Scale, centerX - vp.X * pos.X.Scale, pos.Y.Scale, centerY - vp.Y * pos.Y.Scale)
return main.Position
end
local function savePosition()
local pos = main.Position
Library.Save.Position = {X = pos.X.Scale, Y = pos.Y.Scale, XOffset = pos.X.Offset, YOffset = pos.Y.Offset}
end
local function selectTab(activeTab)
window.ActiveTab = activeTab
for _, tab in ipairs(window.Tabs) do
local active = tab == activeTab
tab.Content.Visible = active
tab.Indicator.Visible = active
local buttonKey = active and "Color Hub 2" or "Color Hub 1"
Theme:UpdateBinding(tab.Button, "BackgroundColor3", buttonKey)
if not tab.Scope:Tween(tab.Button, TweenInfo.new(Tokens.Animation.Tab, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = Theme:Get(buttonKey)}) then
tab.Button.BackgroundColor3 = Theme:Get(buttonKey)
end
tab.Label.TextColor3 = Theme:Get(active and "Color Text" or "Color Dark Text")
Theme:UpdateBinding(tab.Label, "TextColor3", active and "Color Text" or "Color Dark Text")
if tab.Icon then
tab.Icon.ImageColor3 = Theme:Get(active and "Color Text" or "Color Dark Text")
Theme:UpdateBinding(tab.Icon, "ImageColor3", active and "Color Text" or "Color Dark Text")
end
end
end
function window:SelectTab(tabName)
for _, tab in ipairs(self.Tabs) do
if tab == tabName or tab.Name == tabName then
selectTab(tab)
return true
end
end
return false
end
function window:GetTab(tabName)
for _, tab in ipairs(self.Tabs) do
if tab.Name == tabName then return tab end
end
return nil
end
local function isRoleHidden(frame)
return frame:GetAttribute("JustHubRoleHidden") == true
end
function window:ApplySearch()
local term = Util.Trim(searchBox.Text):lower()
for _, tab in ipairs(self.Tabs) do
for _, section in ipairs(tab.Sections) do
local visibleCount = 0
for _, child in ipairs(section.Controls) do
if child.Parent then
local searchable = child:GetAttribute("JustHubSearch") or child.Name
local matches = term == "" or tostring(searchable):lower():find(term, 1, true) ~= nil
local visible = matches and not isRoleHidden(child)
child.Visible = visible
if visible then visibleCount += 1 end
end
end
section.Frame.Visible = term == "" or visibleCount > 0
end
end
end
function window:addTab(tabName, iconName)
tabName = tostring(tabName or "Tab")
local tabScope = self.Scope:CreateScope("Tab:" .. tabName)
self._tabOrder = (self._tabOrder or 0) + 1
local button = make("TextButton", {
Name = Util.SanitizeName(tabName) .. "TabButton",
Size = UDim2.new(1, 0, 0, 38),
BackgroundColor3 = Theme:Get("Color Hub 1"),
BackgroundTransparency = 0, BorderSizePixel = 0,
Text = "", AutoButtonColor = false,
LayoutOrder = self._tabOrder, ZIndex = 4,
}, tabList)
tabScope:TrackInstance(button)
bind(button, "BackgroundColor3", "Color Hub 1")
corner(button, 7)
local indicator = make("Frame", {
Name = "ActiveIndicator",
Position = UDim2.new(0, 5, 0.5, -8),
Size = UDim2.new(0, 3, 0, 16),
BackgroundColor3 = Theme:Get("Color Theme"),
BackgroundTransparency = 0, BorderSizePixel = 0,
Visible = false, ZIndex = 5,
}, button)
bind(indicator, "BackgroundColor3", "Color Theme")
corner(indicator, 2)
local iconAsset = resolveIcon(iconName)
local icon
if iconAsset then
icon = make("ImageLabel", {
Name = "TabIcon",
Position = UDim2.new(0, 14, 0.5, -8),
Size = UDim2.new(0, 16, 0, 16),
BackgroundTransparency = 1,
Image = iconAsset,
ImageColor3 = Theme:Get("Color Dark Text"),
ZIndex = 5,
}, button)
bind(icon, "ImageColor3", "Color Dark Text")
end
local textX = icon and 38 or 15
local label = makeText(button, tabName, UDim2.new(0, textX, 0, 0), UDim2.new(1, -(textX + 8), 1, 0), {
Font = Enum.Font.GothamMedium, TextSize = 11, ColorKey = "Color Dark Text", Truncate = true, ZIndex = 5,
})
local page = make("ScrollingFrame", {
Name = Util.SanitizeName(tabName) .. "Page",
Size = UDim2.new(1, 0, 1, 0),
BackgroundTransparency = 1, BorderSizePixel = 0,
ScrollBarThickness = 3,
AutomaticCanvasSize = Enum.AutomaticSize.Y,
CanvasSize = UDim2.new(),
Visible = false, ZIndex = 3,
}, pages)
tabScope:TrackInstance(page)
bind(page, "ScrollBarImageColor3", "Color Stroke")
make("UIListLayout", {
Padding = UDim.new(0, 10),
SortOrder = Enum.SortOrder.LayoutOrder,
HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, page)
make("UIPadding", {
PaddingTop = UDim.new(0, 2),
PaddingBottom = UDim.new(0, 10),
PaddingLeft = UDim.new(0, 2),
PaddingRight = UDim.new(0, 2),
}, page)
local tab = {
Name = tabName,
Button = button,
Content = page,
Sections = {},
Indicator = indicator,
Icon = icon,
Label = label,
Scope = tabScope,
}
table.insert(self.Tabs, tab)
tabScope:AddCleanup(function()
Theme:UnbindTree(button)
Theme:UnbindTree(page)
for index = #window.Tabs, 1, -1 do
if window.Tabs[index] == tab then
table.remove(window.Tabs, index)
break
end
end
if window.ActiveTab == tab then
window.ActiveTab = nil
if window.Tabs[1] and not windowScope.Destroyed then selectTab(window.Tabs[1]) end
end
end)
function tab:Select()
selectTab(tab)
end
function tab:Destroy()
tabScope:Destroy()
end
tabScope:Connect(page.Destroying, function() tabScope:Destroy() end)
tabScope:Connect(button.Destroying, function() tabScope:Destroy() end)
tabScope:Connect(button.Activated, function() selectTab(tab) end)
tabScope:Connect(button.MouseEnter, function()
if self.ActiveTab ~= tab then
tabScope:Tween(button, TweenInfo.new(Tokens.Animation.Hover), {BackgroundColor3 = Theme:Get("Color Stroke")})
end
end)
tabScope:Connect(button.MouseLeave, function()
tabScope:Tween(button, TweenInfo.new(Tokens.Animation.Hover), {BackgroundColor3 = Theme:Get(self.ActiveTab == tab and "Color Hub 2" or "Color Hub 1")})
end)
function tab:addSection(sectionName)
sectionName = tostring(sectionName or "Section")
local sectionScope = tabScope:CreateScope("Section:" .. sectionName)
tab._sectionOrder = (tab._sectionOrder or 0) + 1
local frame = make("Frame", {
Name = Util.SanitizeName(sectionName) .. "Section",
Size = UDim2.new(1, -4, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
BackgroundColor3 = Theme:Get("Color Hub 2"),
BackgroundTransparency = 0, BorderSizePixel = 0,
LayoutOrder = tab._sectionOrder, ZIndex = 3,
}, page)
sectionScope:TrackInstance(frame)
bind(frame, "BackgroundColor3", "Color Hub 2")
corner(frame, Tokens.Geometry.CardRadius)
border(frame)
makeText(frame, sectionName, UDim2.new(0, 12, 0, 0), UDim2.new(1, -24, 0, 36), {
Font = Enum.Font.GothamBold, TextSize = 13,
})
local sectionContent = make("Frame", {
Name = "SectionContent",
Position = UDim2.new(0, 0, 0, 36),
Size = UDim2.new(1, 0, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
BackgroundTransparency = 1, BorderSizePixel = 0,
}, frame)
make("UIListLayout", {
Padding = UDim.new(0, 7),
SortOrder = Enum.SortOrder.LayoutOrder,
HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, sectionContent)
make("UIPadding", {
PaddingTop = UDim.new(0, 2),
PaddingBottom = UDim.new(0, 12),
PaddingLeft = UDim.new(0, 10),
PaddingRight = UDim.new(0, 10),
}, sectionContent)
local section = {
Name = sectionName,
Frame = frame,
Content = sectionContent,
TabName = tabName,
SectionName = sectionName,
Scope = sectionScope,
Controls = {},
_controlCounts = {},
}
function section:MakeControlId(controlName)
local base = Util.MakeId(self.TabName, self.SectionName, controlName)
local registry = Library.StateManager and Library.StateManager.Registry or {}
local count = self._controlCounts[base] or 0
local candidate
repeat
count += 1
candidate = count == 1 and base or (base .. "#" .. tostring(count))
until not registry[candidate]
self._controlCounts[base] = count
return candidate
end
function section:Destroy()
sectionScope:Destroy()
end
setmetatable(section, {__index = Components})
sectionScope:AddCleanup(function()
Theme:UnbindTree(frame)
for index = #tab.Sections, 1, -1 do
if tab.Sections[index] == section then
table.remove(tab.Sections, index)
break
end
end
end)
sectionScope:Connect(frame.Destroying, function() sectionScope:Destroy() end)
table.insert(tab.Sections, section)
return section
end
tab.AddSection = tab.addSection
if #self.Tabs == 1 then selectTab(tab) end
if applyResponsive then applyResponsive() end
return tab
end
window.AddTab = window.addTab
applyResponsive = function()
local newViewport = getViewport()
local maxW = math.max(240, newViewport.X - 24)
local maxH = math.max(200, newViewport.Y - 24)
local minW = math.min(Tokens.Dimensions.MinWidth, maxW)
local minH = math.min(Tokens.Dimensions.MinHeight, maxH)
if window.IsMaximized then
main.Size = UDim2.fromOffset(maxW, maxH)
main.Position = UDim2.fromScale(0.5, 0.5)
elseif not window.IsMinimized then
local size = currentSize()
local desiredW = math.clamp(size.X > 0 and size.X or width, minW, maxW)
local desiredH = math.clamp(size.Y > 0 and size.Y or height, minH, maxH)
main.Size = UDim2.fromOffset(desiredW, desiredH)
end
local measured = currentSize()
local currentWidth = measured.X > 0 and measured.X or width
local compact = newViewport.X < 700 or currentWidth < 520
local targetSide = compact and 116 or sideWidth
sidebar.Size = UDim2.new(0, targetSide, 1, -24)
content.Position = UDim2.new(0, targetSide + 28, 0, 12)
content.Size = UDim2.new(1, -(targetSide + 42), 1, -24)
sidebarSubtitle.Visible = not compact
playerCard.Visible = not compact
tabList.Position = UDim2.new(0, 8, 0, compact and 64 or 118)
tabList.Size = UDim2.new(1, -16, 1, compact and -76 or -130)
sidebarTitle.Text = compact and "JH" or "JUSTHUB"
for _, tab in ipairs(window.Tabs) do
if tab.Icon then
tab.Label.Visible = not compact
tab.Icon.Position = compact and UDim2.new(0.5, -8, 0.5, -8) or UDim2.new(0, 14, 0.5, -8)
else
tab.Label.Visible = true
tab.Label.TextXAlignment = compact and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
tab.Label.Position = compact and UDim2.new(0, 4, 0, 0) or UDim2.new(0, 15, 0, 0)
tab.Label.Size = compact and UDim2.new(1, -8, 1, 0) or UDim2.new(1, -23, 1, 0)
end
end
clampPosition()
end
local viewportConnection
local function bindViewport(camera)
if viewportConnection then
windowScope:Disconnect(viewportConnection)
viewportConnection = nil
end
if camera then
viewportConnection = windowScope:Connect(camera:GetPropertyChangedSignal("ViewportSize"), applyResponsive)
end
applyResponsive()
end
windowScope:Connect(workspace:GetPropertyChangedSignal("CurrentCamera"), function()
bindViewport(workspace.CurrentCamera)
end)
bindViewport(workspace.CurrentCamera)
windowScope:Connect(searchBox:GetPropertyChangedSignal("Text"), function()
window:ApplySearch()
end)
local dragInput, dragStart, startPosition
local resizeInput, resizeStart, resizeSize
local function popLayout(fromSize, fromPosition, toSize, toPosition)
	if windowScope:IsAlive() then
		main.Size = fromSize
		main.Position = fromPosition or main.Position
		local played = windowScope:Tween(main, TweenInfo.new(Tokens.Animation.Popup, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = toSize,
			Position = toPosition or main.Position,
		})
		if played then return end
	end
	main.Size = toSize
	main.Position = toPosition or main.Position
end
local function animateIntro()
	if not windowScope:IsAlive() then return end
	local toSize = main.Size
	local toPosition = main.Position
	local fromSize = UDim2.new(0, math.max(120, math.floor(toSize.X.Offset * 0.9)), 0, math.max(80, math.floor(toSize.Y.Offset * 0.9)))
	main.Size = fromSize
	local played = windowScope:Tween(main, TweenInfo.new(Tokens.Animation.Popup, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = toSize,
		Position = toPosition,
	})
	if not played then
		main.Size = toSize
	end
end
window.AnimateIntro = animateIntro
local function enterMinimized()
if window.IsMinimized then return end
if window.IsMaximized then
window._minimizedFrom = {Size = window._restoreSize or main.Size, Position = window._restorePosition or main.Position}
window.IsMaximized = false
window._restoreSize = nil
window._restorePosition = nil
else
window._minimizedFrom = {Size = main.Size, Position = main.Position}
end
local fromSize, fromPosition = main.Size, main.Position
dragInput = nil
resizeInput = nil
window.IsMinimized = true
body.Visible = false
footer.Visible = false
resizeHandle.Visible = false
main.Size = UDim2.new(0, math.max(Tokens.Dimensions.MinWidth, currentSize().X), 0, Tokens.Dimensions.Header)
clampPosition()
popLayout(fromSize, fromPosition, main.Size, main.Position)
end
local function leaveMinimized()
if not window.IsMinimized then return end
window.IsMinimized = false
body.Visible = true
footer.Visible = true
local from = window._minimizedFrom
window._minimizedFrom = nil
if from then
local fromSize, fromPosition = main.Size, main.Position
main.Size = from.Size
main.Position = from.Position
popLayout(fromSize, fromPosition, main.Size, main.Position)
end
applyResponsive()
resizeHandle.Visible = not window.Locked and not window.IsMaximized
savePosition()
end
windowScope:Connect(minimizeButton.Activated, function()
if window.IsMinimized then leaveMinimized() else enterMinimized() end
end)
windowScope:Connect(maximizeButton.Activated, function()
if window.IsMinimized then
leaveMinimized()
return
end
if window.IsMaximized then
local fromSize, fromPosition = main.Size, main.Position
window.IsMaximized = false
main.Size = window._restoreSize
main.Position = window._restorePosition
window._restoreSize = nil
window._restorePosition = nil
popLayout(fromSize, fromPosition, main.Size, main.Position)
else
window._restoreSize = main.Size
window._restorePosition = main.Position
window.IsMaximized = true
dragInput = nil
resizeInput = nil
local fromSize, fromPosition = main.Size, main.Position
local current = getViewport()
main.Size = UDim2.fromOffset(math.max(240, current.X - 24), math.max(200, current.Y - 24))
main.Position = UDim2.fromScale(0.5, 0.5)
popLayout(fromSize, fromPosition, main.Size, main.Position)
end
applyResponsive()
resizeHandle.Visible = not window.Locked and not window.IsMaximized
savePosition()
end)
function window:SetLocked(value)
self.Locked = value == true
if self.Locked then
dragInput = nil
resizeInput = nil
end
resizeHandle.Visible = not self.Locked and not self.IsMaximized and not self.IsMinimized
Library.Save.Locked = self.Locked
lockButton.Text = self.Locked and "L" or "U"
local key = self.Locked and "Color Theme" or "Color Hub 2"
lockButton.BackgroundColor3 = Theme:Get(key)
Theme:UpdateBinding(lockButton, "BackgroundColor3", key)
end
windowScope:Connect(lockButton.Activated, function()
window:SetLocked(not window.Locked)
dragInput = nil
resizeInput = nil
Library:Notify({
Title = "Window",
Message = window.Locked and context.Localize("Locked") or context.Localize("Unlocked"),
Duration = 2,
})
end)
windowScope:Connect(closeButton.Activated, function()
if window.IsMinimized then leaveMinimized() end
window:Hide()
savePosition()
end)
windowScope:Connect(header.InputBegan, function(input)
if window.Locked or window.IsMaximized then return end
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
dragInput = input
dragStart = input.Position
startPosition = main.Position
end
end)
windowScope:Connect(UserInputService.InputChanged, function(input)
if not dragInput then return end
local matchingMouse = dragInput.UserInputType == Enum.UserInputType.MouseButton1
and input.UserInputType == Enum.UserInputType.MouseMovement
local matchingTouch = dragInput.UserInputType == Enum.UserInputType.Touch and input == dragInput
if matchingMouse or matchingTouch then
local delta = input.Position - dragStart
main.Position = UDim2.new(
startPosition.X.Scale, startPosition.X.Offset + delta.X,
startPosition.Y.Scale, startPosition.Y.Offset + delta.Y
)
clampPosition()
end
end)
windowScope:Connect(UserInputService.InputEnded, function(input)
if dragInput and (input == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then
dragInput = nil
savePosition()
end
end)
windowScope:Connect(resizeHandle.InputBegan, function(input)
if window.Locked or window.IsMaximized or window.IsMinimized then return end
if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
resizeInput = input
resizeStart = input.Position
resizeSize = main.AbsoluteSize
end
end)
windowScope:Connect(UserInputService.InputChanged, function(input)
if not resizeInput then return end
local matchingMouse = resizeInput.UserInputType == Enum.UserInputType.MouseButton1
and input.UserInputType == Enum.UserInputType.MouseMovement
local matchingTouch = resizeInput.UserInputType == Enum.UserInputType.Touch and input == resizeInput
if matchingMouse or matchingTouch then
local delta = input.Position - resizeStart
local current = getViewport()
local maxWidth = math.max(240, current.X - 24)
local maxHeight = math.max(200, current.Y - 24)
local newWidth = math.clamp(resizeSize.X + delta.X, math.min(Tokens.Dimensions.MinWidth, maxWidth), maxWidth)
local newHeight = math.clamp(resizeSize.Y + delta.Y, math.min(Tokens.Dimensions.MinHeight, maxHeight), maxHeight)
main.Size = UDim2.fromOffset(newWidth, newHeight)
window._restoreSize = main.Size
applyResponsive()
end
end)
windowScope:Connect(UserInputService.InputEnded, function(input)
if resizeInput and (input == resizeInput or (resizeInput.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseButton1)) then
resizeInput = nil
local finalSize = currentSize()
Library.Save.UISize = {finalSize.X, finalSize.Y}
clampPosition()
savePosition()
end
end)
windowScope:Connect(UserInputService.WindowFocusReleased, function()
dragInput = nil
resizeInput = nil
end)
function window:Show()
if self.ScreenGui and self.ScreenGui.Parent then
self.ScreenGui.Enabled = true
if windowScope:IsAlive() then animateIntro() end
return true
end
return false
end
function window:Hide()
if self.ScreenGui and self.ScreenGui.Parent then
self.ScreenGui.Enabled = false
dragInput = nil
resizeInput = nil
return true
end
return false
end
function window:Toggle()
if self.ScreenGui and self.ScreenGui.Parent then
if self.ScreenGui.Enabled then return self:Hide() end
return self:Show()
end
return false
end
function window:IsVisible()
return self.ScreenGui ~= nil and self.ScreenGui.Parent ~= nil and self.ScreenGui.Enabled
end
function window:SetTitle(newTitle)
title.Text = tostring(newTitle or "JustHub")
end
function window:SetSubtitle(newSubtitle)
subtitle.Text = tostring(newSubtitle or "")
end
function window:SetSize(newWidth, newHeight)
local current = getViewport()
local maxWidth = math.max(240, current.X - 24)
local maxHeight = math.max(200, current.Y - 24)
local widthValue = math.floor(Util.ClampNumber(newWidth, math.min(Tokens.Dimensions.MinWidth, maxWidth), maxWidth, width))
local heightValue = math.floor(Util.ClampNumber(newHeight, math.min(Tokens.Dimensions.MinHeight, maxHeight), maxHeight, height))
if self.IsMinimized then
self._minimizedFrom = {Size = UDim2.fromOffset(widthValue, heightValue), Position = main.Position}
self._restoreSize = self._minimizedFrom.Size
Library.Save.UISize = {widthValue, heightValue}
return true
end
self.IsMaximized = false
main.Size = UDim2.fromOffset(widthValue, heightValue)
self._restoreSize = main.Size
self._restorePosition = main.Position
Library.Save.UISize = {widthValue, heightValue}
applyResponsive()
savePosition()
return true
end
function window:SetSidebarWidth(newWidth)
sideWidth = math.floor(Util.ClampNumber(newWidth, 100, 320, Tokens.Dimensions.Sidebar))
Library.Save.TabSize = sideWidth
applyResponsive()
return true
end
function window:GetSize()
local size = currentSize()
return size.X, size.Y
end
function window:GetPosition()
local pos = main.Position
local viewport = getViewport()
return viewport.X * pos.X.Scale + pos.X.Offset, viewport.Y * pos.Y.Scale + pos.Y.Offset
end
function window:SetPosition(newX, newY)
local viewport = getViewport()
local size = currentSize()
local halfW, halfH = size.X / 2, size.Y / 2
local centerX, centerY
if type(newX) == "table" then
local scalarX = Util.ClampNumber(newX.X, 0, 1, 0.5)
local scalarY = Util.ClampNumber(newX.Y, 0, 1, 0.5)
centerX = viewport.X * scalarX + Util.ClampNumber(newX.XOffset, -viewport.X, viewport.X, 0)
centerY = viewport.Y * scalarY + Util.ClampNumber(newX.YOffset, -viewport.Y, viewport.Y, 0)
else
centerX = Util.ClampNumber(newX, 0, viewport.X, viewport.X / 2)
centerY = Util.ClampNumber(newY, 0, viewport.Y, viewport.Y / 2)
end
local minX = math.min(halfW + 8, viewport.X / 2)
local maxX = math.max(viewport.X - halfW - 8, viewport.X / 2)
local minY = math.min(halfH + 8, viewport.Y / 2)
local maxY = math.max(viewport.Y - halfH - 8, viewport.Y / 2)
main.Position = UDim2.fromOffset(math.clamp(centerX, minX, maxX), math.clamp(centerY, minY, maxY))
savePosition()
return true
end
function window:IsLocked()
return self.Locked == true
end
function window:Destroy()
Library:Destroy()
end
local savedPosition = Library.Save.Position
if type(savedPosition) == "table" and Util.IsFinite(savedPosition.X) and Util.IsFinite(savedPosition.Y) and Util.IsFinite(savedPosition.XOffset) and Util.IsFinite(savedPosition.YOffset) then
main.Position = UDim2.new(savedPosition.X, savedPosition.XOffset, savedPosition.Y, savedPosition.YOffset)
end
applyResponsive()
if window.Locked then
window:SetLocked(true)
end
if Library.Save.Transparency and Library.Save.Transparency > 0 then
Library:SetTransparency(Library.Save.Transparency)
end
return window
end, debug.traceback)
if not buildOk then
if createdScope then createdScope:Destroy() end
error(builtWindow, 0)
end
return builtWindow
end
return Window
end
end)()

Modules.Notifications = (function()
return function(context)
local Enum = context.Enum
local Theme = context.Theme
local RootScope = context.RootScope
local TweenInfo = context.TweenInfo
local Library = context.Library
local Kit = context.Kit
local Notifications = {}
local notificationOrder = 0
local MAX_NOTIFICATIONS = 6
local make = function(className, properties, parent)
return Kit.make(className, properties, parent, nil)
end
local bind = Kit.bind
function Notifications.Notify(options)
options = type(options) == "table" and options or {}
local title = tostring(options.Title or "JustHub")
local message = tostring(options.Message or "")
local duration = math.clamp(tonumber(options.Duration) or 4, 0, 60)
local showProgress = options.ShowProgress == true
local callback = type(options.Callback) == "function" and options.Callback or nil
local container = Library.NotificationContainer
if not container or not container.Parent then
local ok, err = pcall(function()
game:GetService("StarterGui"):SetCore("SendNotification", {
Title = title, Text = message, Duration = duration,
})
end)
if not ok then
warn("[JustHub] Notification fallback unavailable: " .. tostring(err))
end
return nil
end
local existing = {}
for _, child in ipairs(container:GetChildren()) do
if child:IsA("Frame") and child.Name == "NotificationSurface" and child:GetAttribute("JustHubClosing") ~= true then
existing[#existing + 1] = child
end
end
if #existing >= MAX_NOTIFICATIONS then
table.sort(existing, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
for index = 1, #existing - MAX_NOTIFICATIONS + 1 do
local oldest = existing[index]
pcall(function() oldest:Destroy() end)
end
end
local scope = RootScope:CreateScope("Notification:" .. title)
notificationOrder += 1
local frame = make("Frame", {
Name = "NotificationSurface",
Size = UDim2.new(1, 0, 0, 0),
BackgroundColor3 = Theme:Get("Color Hub 2"),
BackgroundTransparency = 0, BorderSizePixel = 0,
ClipsDescendants = true,
LayoutOrder = notificationOrder,
ZIndex = 101,
}, container)
scope:TrackInstance(frame)
scope:Connect(frame.Destroying, function() scope:Destroy() end)
scope:AddCleanup(function() Theme:UnbindTree(frame) end)
bind(frame, "BackgroundColor3", "Color Hub 2")
make("UICorner", {CornerRadius = UDim.new(0, 9)}, frame)
local border = make("UIStroke", {
Color = Theme:Get("Color Stroke"), Thickness = 1, Transparency = 0,
}, frame)
bind(border, "Color", "Color Stroke")
local accent = make("Frame", {
Position = UDim2.new(0, 0, 0, 0),
Size = UDim2.new(0, 3, 1, 0),
BackgroundColor3 = Theme:Get("Color Theme"),
BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 103,
}, frame)
bind(accent, "BackgroundColor3", "Color Theme")
local titleLabel = make("TextLabel", {
Name = "Title",
Position = UDim2.new(0, 14, 0, 8),
Size = UDim2.new(1, -26, 0, 20),
BackgroundTransparency = 1, BorderSizePixel = 0,
Text = title,
Font = Enum.Font.GothamBold, TextSize = 13,
TextColor3 = Theme:Get("Color Text"),
TextXAlignment = Enum.TextXAlignment.Left,
TextTruncate = Enum.TextTruncate.AtEnd,
ZIndex = 103,
}, frame)
bind(titleLabel, "TextColor3", "Color Text")
local body = make("TextLabel", {
Name = "Message",
Position = UDim2.new(0, 14, 0, 31),
Size = UDim2.new(1, -26, 0, 0),
AutomaticSize = Enum.AutomaticSize.Y,
BackgroundTransparency = 1, BorderSizePixel = 0,
Text = message,
Font = Enum.Font.Gotham, TextSize = 11,
TextColor3 = Theme:Get("Color Dark Text"),
TextXAlignment = Enum.TextXAlignment.Left,
TextYAlignment = Enum.TextYAlignment.Top,
TextWrapped = true, ZIndex = 103,
}, frame)
bind(body, "TextColor3", "Color Dark Text")
local progress
if showProgress then
progress = make("Frame", {
Position = UDim2.new(0, 0, 1, -3),
Size = UDim2.new(1, 0, 0, 3),
BackgroundColor3 = Theme:Get("Color Theme"),
BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 104,
}, frame)
bind(progress, "BackgroundColor3", "Color Theme")
end
local function dismiss(activate)
if frame:GetAttribute("JustHubClosing") then return end
frame:SetAttribute("JustHubClosing", true)
scope:Tween(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
Size = UDim2.new(1, 0, 0, 0),
})
scope:Delay(0.22, function() scope:Destroy() end)
if activate and callback then
local ok, err = pcall(callback)
if not ok then warn("[JustHub] Notification callback failed: " .. tostring(err)) end
end
end
local hitbox = make("TextButton", {
Name = "Dismiss",
Size = UDim2.new(1, 0, 1, 0),
BackgroundTransparency = 1, BorderSizePixel = 0,
Text = "", AutoButtonColor = false, ZIndex = 105,
}, frame)
scope:TrackInstance(hitbox)
scope:Connect(hitbox.Activated, function() dismiss(true) end)
scope:Delay(0, function()
if not scope:IsAlive() then return end
local textHeight = math.max(body.TextBounds.Y, body.AbsoluteSize.Y)
local height = 8 + 20 + math.max(18, textHeight) + (showProgress and 7 or 4)
scope:Tween(frame, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
Size = UDim2.new(1, 0, 0, height),
})
if progress then
scope:Tween(progress, TweenInfo.new(math.max(0.05, duration), Enum.EasingStyle.Linear), {
Size = UDim2.new(0, 0, 0, 3),
})
end
scope:Delay(duration, function() dismiss(false) end)
end)
return frame
end
return Notifications
end
end)()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local SoundService = game:GetService("SoundService")
local Util = Modules.Util
local ResourceManager = Modules.ResourceManager
local function resolveGlobalEnv()
if type(getgenv) == "function" then
local ok, env = pcall(getgenv)
if ok and type(env) == "table" then return env end
end
return _G
end
local GlobalEnv = resolveGlobalEnv()
local RootScope = ResourceManager.new("JustHubRoot")
local Theme = Modules.ThemeManager.new(RunService, RootScope)
local State = Modules.StateManager.new({HistoryLimit = 100})
local Storage = Modules.StorageAdapter.new()
local Localization = Modules.Localization.new()
local Permissions = Modules.Permissions.new()
local Kit = Modules.UiKit({Instance = Instance, Enum = Enum, Theme = Theme})
local SoundController = Modules.Sound({
Instance = Instance,
SoundService = SoundService,
RootScope = RootScope,
}).new()
local JustHub = {}
JustHub.__index = JustHub
local previousInstance = rawget(GlobalEnv, "__JustHubInstance")
if type(previousInstance) == "table" and previousInstance ~= JustHub and type(previousInstance.Destroy) == "function" then
pcall(previousInstance.Destroy, previousInstance)
end
JustHub.Info = {
Name = "JustHub",
Version = "2.1.0",
SchemaVersion = Modules.ConfigManager.SchemaVersion,
}
JustHub.Save = {
UISize = {760, 520},
TabSize = 168,
Theme = "Darker",
Locked = false,
Transparency = 0,
}
JustHub.Themes = Theme.Themes
JustHub.DesignTokens = Theme.Tokens
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
JustHub.ConfigData = State.Values
JustHub.ControlRegistry = {}
JustHub.ControlAliases = {}
JustHub.AmbiguousControlAliases = State.AmbiguousAliases
JustHub.Controls = State.Controls
JustHub.Localization = Localization.Languages
JustHub.CurrentLang = Localization.Current
JustHub.UserRole = Permissions.CurrentRole
JustHub.UndoStack = State.UndoStack
JustHub.RedoStack = State.RedoStack
JustHub.Sounds = SoundController.Sounds
JustHub.Connections = RootScope.Connections
JustHub.ScreenGuis = {}
JustHub.ThemeObjects = Theme.Bindings
JustHub.ChromaObjects = Theme.Chroma
JustHub.ChromaEnabled = false
JustHub.KeySystem = {Enabled = false, Key = ""}
JustHub.PromoNotifyEnabled = false
JustHub._destroyed = false
JustHub._initializing = false
JustHub._promoThread = nil
JustHub._customTheme = nil
JustHub.ToggleKey = nil
JustHub._roleFrames = setmetatable({}, {__mode = "k"})
JustHub.ResourceManager = RootScope
JustHub.StateManager = State
JustHub.ThemeManager = Theme
JustHub.StorageAdapter = Storage
JustHub.LocalizationManager = Localization
JustHub.Permissions = Permissions
local Notifications = Modules.Notifications({
Instance = Instance,
Enum = Enum,
Theme = Theme,
RootScope = RootScope,
TweenInfo = TweenInfo,
Library = JustHub,
Kit = Kit,
})
local function collectSaveMeta()
local meta = {
UISize = type(JustHub.Save.UISize) == "table" and {JustHub.Save.UISize[1], JustHub.Save.UISize[2]} or {760, 520},
TabSize = JustHub.Save.TabSize,
Theme = JustHub.Save.Theme,
Locked = JustHub.Save.Locked,
Transparency = JustHub.Save.Transparency,
Position = type(JustHub.Save.Position) == "table" and table.clone(JustHub.Save.Position) or nil,
}
if JustHub.Save.Theme == "Custom" and JustHub._customTheme then
meta.CustomTheme = JustHub._customTheme
end
return meta
end
local function applySaveMeta(meta)
if type(meta) ~= "table" then return end
if type(meta.UISize) == "table" then
local w = tonumber(meta.UISize[1])
local h = tonumber(meta.UISize[2])
if Util.IsFinite(w) and Util.IsFinite(h) then
JustHub.Save.UISize = {w, h}
end
end
local tabSize = tonumber(meta.TabSize)
if Util.IsFinite(tabSize) then JustHub.Save.TabSize = math.floor(math.clamp(tabSize, 100, 320)) end
if type(meta.Locked) == "boolean" then JustHub.Save.Locked = meta.Locked end
local transparency = tonumber(meta.Transparency)
if Util.IsFinite(transparency) then JustHub.Save.Transparency = math.clamp(transparency, 0, 1) end
if type(meta.Position) == "table" then
local px, py = tonumber(meta.Position.X), tonumber(meta.Position.Y)
local ox, oy = tonumber(meta.Position.XOffset), tonumber(meta.Position.YOffset)
if Util.IsFinite(px) and Util.IsFinite(py) and Util.IsFinite(ox) and Util.IsFinite(oy) then
JustHub.Save.Position = {X = px, Y = py, XOffset = ox, YOffset = oy}
end
end
if type(meta.CustomTheme) == "table" and Theme:IsValid(meta.CustomTheme) then
JustHub._customTheme = table.clone(meta.CustomTheme)
end
local function copySize(size)
if type(size) ~= "table" then return nil end
return {size[1], size[2]}
end
JustHub.Save.UISize = copySize(JustHub.Save.UISize) or {760, 520}
if type(meta.Theme) == "string" then
if meta.Theme == "Custom" and JustHub._customTheme then
JustHub:UpdateTheme(JustHub._customTheme)
elseif Theme.Themes[meta.Theme] then
JustHub:UpdateTheme(meta.Theme)
end
end
if JustHub.Window then
local position = JustHub.Save.Position
JustHub.Window:SetSize(JustHub.Save.UISize[1], JustHub.Save.UISize[2])
if type(JustHub.Window.SetSidebarWidth) == "function" then JustHub.Window:SetSidebarWidth(JustHub.Save.TabSize) end
if position and type(JustHub.Window.SetPosition) == "function" then
JustHub.Window:SetPosition(position)
end
JustHub.Window:SetLocked(JustHub.Save.Locked)
end
if JustHub.Save.Transparency > 0 then
JustHub:SetTransparency(JustHub.Save.Transparency)
end
end
JustHub.ConfigManager = Modules.ConfigManager.new(
HttpService,
State,
Storage,
function(title, message, duration)
JustHub:Notify({Title = title, Message = message, Duration = duration})
end,
{Collect = collectSaveMeta, Apply = applySaveMeta},
JustHub.Info.Version
)
function JustHub:_SyncControlAliases()
for alias in pairs(self.ControlAliases) do
local target = State.Aliases[alias]
if not target or State.AmbiguousAliases[alias] or not self.ControlRegistry[target] then
self.ControlAliases[alias] = nil
end
end
for alias, target in pairs(State.Aliases) do
if not State.AmbiguousAliases[alias] and self.ControlRegistry[target] then
self.ControlAliases[alias] = self.ControlRegistry[target]
end
end
end
function JustHub:_RefreshRoleFrame(frame)
if not frame then return end
local role = frame:GetAttribute("JustHubRole")
local hidden = type(role) == "string" and role ~= "" and not Permissions:Check(role)
frame:SetAttribute("JustHubRoleHidden", hidden)
if hidden then
frame.Visible = false
elseif self.Window and type(self.Window.ApplySearch) == "function" then
self.Window:ApplySearch()
else
frame.Visible = true
end
end
local function registerBuiltinControl(id, handle, metadata)
local setter = function(value)
local ok, err = handle:Set(value)
if not ok then error(err, 0) end
return ok
end
JustHub.ControlRegistry[id] = setter
JustHub.Controls[id] = metadata
for alias, target in pairs(State.Aliases) do
if target == id then JustHub.Controls[alias] = metadata end
end
JustHub:_SyncControlAliases()
return setter
end
local Components = Modules.Components({
Instance = Instance,
Enum = Enum,
Util = Util,
TweenInfo = TweenInfo,
UserInputService = UserInputService,
Theme = Theme,
State = State,
RootScope = RootScope,
Library = JustHub,
Kit = Kit,
Localize = function(key) return Localization:Get(key) end,
LocalizationManager = Localization,
RegisterBuiltinControl = registerBuiltinControl,
})
local WindowModule = Modules.Window({
Instance = Instance,
Enum = Enum,
Players = Players,
UserInputService = UserInputService,
Theme = Theme,
RootScope = RootScope,
Components = Components,
Library = JustHub,
TweenInfo = TweenInfo,
Util = Util,
Kit = Kit,
Localize = function(key) return Localization:Get(key) end,
LocalizationManager = Localization,
})
function JustHub:IsAlive()
return not self._destroyed
end
function JustHub:RegisterControl(id, setter, metadata)
if not self:IsAlive() then return false, "JustHub has been destroyed" end
local ok, err = State:RegisterExternal(id, setter, metadata)
if not ok then
warn("[JustHub] RegisterControl failed: " .. tostring(err))
return false, err
end
self.ControlRegistry[id] = setter
self.Controls[id] = type(metadata) == "table" and metadata or {}
self:_SyncControlAliases()
return true
end
function JustHub:UnregisterControl(id)
if type(id) ~= "string" then return false, "Control ID must be a string" end
local canonical = State.Registry[id] and id or State.Aliases[id]
if not canonical then return false, "Unknown control: " .. id end
local record = State.Registry[canonical]
if record and not record.ExternalSetter then
return false, "Built-in controls are removed by destroying their element"
end
State:Unregister(canonical)
self.ControlRegistry[canonical] = nil
self.Controls[canonical] = nil
self:_SyncControlAliases()
return true
end
function JustHub:GetValue(id)
return State:Get(id)
end
function JustHub:SetValue(id, value)
if not self:IsAlive() then return false, "JustHub has been destroyed" end
return State:Set(id, value)
end
function JustHub:SetUserRole(roleName)
local ok, err = Permissions:SetRole(roleName)
if ok then
self.UserRole = Permissions.CurrentRole
self:_RefreshRoles()
end
return ok, err
end
function JustHub:_RefreshRoles()
local frames = {}
for frame in pairs(self._roleFrames) do frames[#frames + 1] = frame end
for _, frame in ipairs(frames) do
local alive = false
pcall(function() alive = frame.Parent ~= nil end)
if alive then
local role = frame:GetAttribute("JustHubRole")
frame:SetAttribute("JustHubRoleHidden", type(role) == "string" and role ~= "" and not Permissions:Check(role))
else
self._roleFrames[frame] = nil
end
end
if self.Window and type(self.Window.ApplySearch) == "function" then
self.Window:ApplySearch()
else
for _, frame in ipairs(frames) do
if self._roleFrames[frame] then frame.Visible = frame:GetAttribute("JustHubRoleHidden") ~= true end
end
end
end
function JustHub:CheckRole(requiredRole)
return Permissions:Check(requiredRole)
end
function JustHub:RegisterRole(name, rank)
local ok, err = Permissions:RegisterRole(name, rank)
if ok then self:_RefreshRoles() end
return ok, err
end
function JustHub:AddUndo(controlKey, oldValue, newValue)
return State:AddUndo(controlKey, oldValue, newValue)
end
function JustHub:Undo()
return State:Undo()
end
function JustHub:Redo()
return State:Redo()
end
function JustHub:ApplyConfig(configData)
return State:ApplyConfig(configData)
end
function JustHub:RegisterTheme(name, definition)
local ok, err = Theme:Register(name, definition)
if not ok then
warn("[JustHub] RegisterTheme failed: " .. tostring(err))
end
return ok, err
end
function JustHub:UpdateTheme(newTheme)
if not self:IsAlive() then return false, "JustHub has been destroyed" end
local ok, err = Theme:Apply(newTheme)
if not ok then return false, err end
if type(newTheme) == "table" then
self._customTheme = table.clone(Theme.Current)
self.Save.Theme = "Custom"
else
self._customTheme = nil
self.Save.Theme = newTheme
end
return true
end
function JustHub:GetThemeNames()
local names = {}
for name in pairs(Theme.Themes) do names[#names + 1] = name end
table.sort(names)
return names
end
function JustHub:SetTheme(newTheme)
return self:UpdateTheme(newTheme)
end
function JustHub:UpdateThemeObject(instance, property, themeKey)
return Theme:UpdateBinding(instance, property, themeKey)
end
function JustHub:ToggleChroma(enabled)
if enabled == nil then enabled = not Theme.ChromaEnabled end
self.ChromaEnabled = Theme:SetChroma(enabled)
return self.ChromaEnabled
end
function JustHub:UnregisterChroma(instance, property)
Theme:UnregisterChroma(instance, property)
end
function JustHub:PlaySound(name, volume)
return SoundController:Play(name, volume)
end
function JustHub:SetLanguage(language)
local ok, err = Localization:SetLanguage(language)
if ok then self.CurrentLang = Localization.Current end
return ok, err
end
function JustHub:RegisterLanguage(language, dictionary)
return Localization:RegisterLanguage(language, dictionary)
end
function JustHub:LocalizeText(textKey)
return Localization:Get(tostring(textKey or ""))
end
function JustHub:SaveConfig(fileName)
return self.ConfigManager:Save(fileName)
end
function JustHub:LoadConfig(fileName)
return self.ConfigManager:Load(fileName)
end
function JustHub:ListConfigs()
local ok, result = self.ConfigManager:List()
if not ok then return {}, tostring(result) end
return result
end
function JustHub:DeleteConfig(fileName)
return self.ConfigManager:Delete(fileName)
end
function JustHub:Notify(options)
if not self:IsAlive() then return nil end
return Notifications.Notify(options)
end
function JustHub:PromoNotify(interval)
if not self.PromoNotifyEnabled then
return false, "Promo notifications are disabled"
end
if self._promoThread then
return false, "Promo notification loop is already running"
end
if not (self.ScreenGui and self.ScreenGui.Parent) then
return false, "Create a window before starting promo notifications"
end
interval = Util.ClampNumber(interval, 10, 3600, 60)
local marker = {}
self._promoThread = marker
RootScope:Spawn(function(isAlive)
while isAlive() and self._promoThread == marker and self.PromoNotifyEnabled and self.ScreenGui and self.ScreenGui.Parent do
self:Notify({
Title = "JustHub",
Message = "Thanks for using JustHub " .. self.Info.Version,
Duration = 3,
ShowProgress = true,
})
task.wait(interval)
end
if self._promoThread == marker then self._promoThread = nil end
end)
return true
end
function JustHub:StopPromoNotify()
self._promoThread = nil
return true
end
function JustHub:ToggleUIVisibility()
if self.Window then
self.Window:Toggle()
return true
end
if self.ScreenGui and self.ScreenGui.Parent then
self.ScreenGui.Enabled = not self.ScreenGui.Enabled
return true
end
return false
end
JustHub._transparencyTargets = setmetatable({}, {__mode = "k"})
function JustHub:RegisterTransparency(instance, baseValue, property)
if typeof(instance) ~= "Instance" then return false, "RegisterTransparency expects an Instance" end
property = property or "BackgroundTransparency"
if property ~= "BackgroundTransparency" and property ~= "Transparency" then
return false, "Transparency property must be BackgroundTransparency or Transparency"
end
if property == "BackgroundTransparency" and not instance:IsA("GuiObject") then
return false, "BackgroundTransparency requires a GuiObject"
end
if property == "Transparency" and not (instance:IsA("UIStroke") or instance:IsA("ImageLabel") or instance:IsA("ImageButton")) then
return false, "Transparency requires a UIStroke or Image"
end
local base = Util.ClampNumber(baseValue, 0, 1, 0)
self._transparencyTargets[instance] = {Property = property, Base = base}
pcall(function() instance[property] = math.clamp(base + self.Save.Transparency, 0, 1) end)
return true
end
function JustHub:UnregisterTransparency(instance)
if instance == nil then
table.clear(self._transparencyTargets)
return true
end
self._transparencyTargets[instance] = nil
return true
end
function JustHub:SetTransparency(value)
local number = tonumber(value)
if not Util.IsFinite(number) then
return false, "Transparency value must be finite"
end
number = math.clamp(number, 0, 1)
self.Save.Transparency = number
for instance, record in pairs(self._transparencyTargets) do
if not instance.Parent then
self._transparencyTargets[instance] = nil
else
pcall(function() instance[record.Property] = math.clamp(record.Base + number, 0, 1) end)
end
end
if self.ScreenGui and self.ScreenGui.Parent then
for _, descendant in ipairs(self.ScreenGui:GetDescendants()) do
if descendant:IsA("GuiObject") then
local base = descendant:GetAttribute("JustHubBaseTransparency")
if base == nil then
base = descendant.BackgroundTransparency
descendant:SetAttribute("JustHubBaseTransparency", base)
end
pcall(function() descendant.BackgroundTransparency = math.clamp(base + number, 0, 1) end)
elseif descendant:IsA("UIStroke") then
local base = descendant:GetAttribute("JustHubBaseTransparency")
if base == nil then
base = descendant.Transparency
descendant:SetAttribute("JustHubBaseTransparency", base)
end
pcall(function() descendant.Transparency = math.clamp(base + number, 0, 1) end)
end
end
end
return true
end
function JustHub:SetToggleKey(key)
if key == nil or key == "None" then
self.ToggleKey = nil
return true
end
if typeof(key) == "EnumItem" and key.EnumType == Enum.KeyCode then
self.ToggleKey = key.Name
return true
end
if type(key) == "string" then
local ok, keyCode = pcall(function() return Enum.KeyCode[key] end)
if ok and typeof(keyCode) == "EnumItem" then
self.ToggleKey = keyCode.Name
return true
end
end
return false, "Toggle key must be a valid KeyCode"
end
function JustHub:SetKey(key)
if type(key) ~= "string" or key == "" then
return false, "Key must be a non-empty string"
end
self.KeySystem.Enabled = true
self.KeySystem.Key = key
return true
end
function JustHub:CheckKey(inputKey)
if not self.KeySystem.Enabled then return true end
return type(inputKey) == "string" and inputKey == self.KeySystem.Key
end
function JustHub:CreateWindow(options)
if not self:IsAlive() then
return nil, "JustHub has been destroyed"
end
if self.Window and self.ScreenGui and self.ScreenGui.Parent then
return self.Window
end
options = type(options) == "table" and options or {}
local selectedTheme = options.Theme or ((self.Save.Theme == "Custom" and self._customTheme) and self._customTheme) or self.Save.Theme or "Darker"
if type(selectedTheme) == "string" then
if not Theme.Themes[selectedTheme] then selectedTheme = "Darker" end
elseif not Theme:IsValid(selectedTheme) then
selectedTheme = "Darker"
end
local themeOk, themeError = Theme:Apply(selectedTheme)
if not themeOk then
warn("[JustHub] Initial theme fallback: " .. tostring(themeError))
Theme:Apply("Darker")
selectedTheme = "Darker"
end
if type(selectedTheme) == "table" then
self._customTheme = table.clone(selectedTheme)
self.Save.Theme = "Custom"
else
self.Save.Theme = selectedTheme
end
local ok, result = pcall(function()
return WindowModule.new(options)
end)
if not ok then
warn("[JustHub] CreateWindow failed: " .. tostring(result))
return nil, result
end
self.Window = result
self.ScreenGui = result.ScreenGui
if self._activeLoadingScreen ~= nil then
result.ScreenGui.Enabled = false
self._pendingWindowReveal = true
if type(self._loadingDoneCallbacks) ~= "table" then self._loadingDoneCallbacks = {} end
table.insert(self._loadingDoneCallbacks, function()
if self:IsAlive() and self.Window == result then
result.ScreenGui.Enabled = true
if type(result.AnimateIntro) == "function" then
result:AnimateIntro()
end
end
end)
elseif type(result.AnimateIntro) == "function" then
result:AnimateIntro()
end
return result
end
function JustHub:ShowLoadingScreen(duration, callback)
if not self:IsAlive() then return false end
duration = math.clamp(tonumber(duration) or 1.5, 0, 15)
local player = Players.LocalPlayer
if not player then return false end
local parent = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 30)
if not parent then return false end
local scope = RootScope:CreateScope("LoadingScreen")
local screen = Instance.new("ScreenGui")
screen.Name = "JustHubLoadingScreen"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 1000
screen.Parent = parent
scope:TrackInstance(screen)
self._activeLoadingScreen = screen
scope:AddCleanup(function() Theme:UnbindTree(screen) end)
scope:Connect(screen.Destroying, function() scope:Destroy() end)
local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Theme:Get("Color Hub 1")
backdrop.BackgroundTransparency = 0
backdrop.BorderSizePixel = 0
backdrop.Parent = screen
Theme:Bind(backdrop, "BackgroundColor3", "Color Hub 1")
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(280, 112)
panel.BackgroundColor3 = Theme:Get("Color Hub 2")
panel.BackgroundTransparency = 0
panel.BorderSizePixel = 0
panel.Parent = backdrop
Theme:Bind(panel, "BackgroundColor3", "Color Hub 2")
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local heading = Instance.new("TextLabel")
heading.BackgroundTransparency = 1
heading.Position = UDim2.new(0, 16, 0, 14)
heading.Size = UDim2.new(1, -32, 0, 24)
heading.Font = Enum.Font.GothamBold
heading.TextSize = 16
heading.Text = tostring(self.Info.Name)
heading.TextColor3 = Theme:Get("Color Text")
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.Parent = panel
Theme:Bind(heading, "TextColor3", "Color Text")
local rail = Instance.new("Frame")
rail.Position = UDim2.new(0, 16, 0, 68)
rail.Size = UDim2.new(1, -32, 0, 6)
rail.BackgroundColor3 = Theme:Get("Color Hub 1")
rail.BackgroundTransparency = 0
rail.BorderSizePixel = 0
rail.Parent = panel
Theme:Bind(rail, "BackgroundColor3", "Color Hub 1")
Instance.new("UICorner", rail).CornerRadius = UDim.new(1, 0)
local fill = Instance.new("Frame")
fill.Size = UDim2.new(0, 0, 1, 0)
fill.BackgroundColor3 = Theme:Get("Color Theme")
fill.BackgroundTransparency = 0
fill.BorderSizePixel = 0
fill.Parent = rail
Theme:Bind(fill, "BackgroundColor3", "Color Theme")
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
scope:Tween(fill, TweenInfo.new(math.max(0.05, duration), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
Size = UDim2.new(1, 0, 1, 0),
})
local finished = false
local function finish()
if finished then return end
finished = true
if self._activeLoadingScreen == screen then self._activeLoadingScreen = nil end
local pending = self._loadingDoneCallbacks
if type(pending) == "table" then
self._loadingDoneCallbacks = nil
for _, pendingCallback in ipairs(pending) do
Util.SafeCall("Loading finish callback", pendingCallback)
end
end
if type(callback) == "function" and self:IsAlive() then
task.defer(function()
if self:IsAlive() then Util.SafeCall("Loading callback", callback) end
end)
end
end
scope:AddCleanup(finish)
scope:Delay(duration, function()
scope:Destroy()
end)
return true
end
function JustHub:InitializeUI(options)
if not self:IsAlive() or self._initializing then
return false, "Initialization is already running or JustHub is destroyed"
end
if self.Window then return true, self.Window end
options = type(options) == "table" and options or {}
self._initializing = true
if options.ShowLoadingScreen ~= false then
Util.SafeCall("Auto loading screen", function()
self:ShowLoadingScreen(options.LoadingDuration or 1.4, options.LoadingCallback)
end)
end
local window, err = self:CreateWindow(options)
self._initializing = false
if not window then
self:Notify({Title = "Initialization failed", Message = tostring(err), Duration = 5})
return false, err
end
return true, window
end
function JustHub:GetConfigCapabilities()
return Storage:Capabilities()
end
function JustHub:Destroy()
if self._destroyed then return end
self._destroyed = true
self.PromoNotifyEnabled = false
self._initializing = false
self._promoThread = nil
if rawget(GlobalEnv, "__JustHubInstance") == self then
GlobalEnv.__JustHubInstance = nil
end
Theme:Destroy()
State:Destroy()
Permissions:Destroy()
RootScope:Destroy()
Localization:Destroy()
table.clear(self._roleFrames)
self.ToggleKey = nil
table.clear(self.ControlRegistry)
table.clear(self.ControlAliases)
table.clear(self.ScreenGuis)
self.ScreenGui = nil
self.Window = nil
self._loadingDoneCallbacks = nil
self._pendingWindowReveal = nil
self._activeLoadingScreen = nil
self.NotificationContainer = nil
self._customTheme = nil
self.ConfigData = {}
end
GlobalEnv.__JustHubInstance = JustHub
return JustHub
