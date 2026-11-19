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
return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
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
if self.Destroyed or not instance then return nil end
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
local token = {}
self.Threads[token] = true
token.Thread = task.spawn(function()
local ok, err = xpcall(function()
callback(function() return self:IsAlive() end)
end, debug.traceback)
if not ok then
warn("[JustHub] Task failed in " .. self.Label .. ": " .. tostring(err))
end
self.Threads[token] = nil
end)
return token.Thread
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
for token in pairs(self.Threads) do
if token.Thread then pcall(task.cancel, token.Thread) end
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

-- Full implementation follows in subsequent source segments
