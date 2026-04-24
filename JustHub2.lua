
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

local Hub = {}

Hub.Info = {
	Version = "3.0.0"
}

Hub.Save = {
	UISize = {560, 380},
	TabSize = 124,
	Theme = "Midnight"
}

Hub.Themes = {
	Midnight = {
		["Color Hub 1"] = Color3.fromRGB(18, 20, 26),
		["Color Hub 2"] = Color3.fromRGB(24, 27, 35),
		["Color Stroke"] = Color3.fromRGB(52, 58, 72),
		["Color Theme"] = Color3.fromRGB(118, 172, 255),
		["Color Text"] = Color3.fromRGB(244, 247, 252),
		["Color Dark Text"] = Color3.fromRGB(163, 171, 183)
	},
	Graphite = {
		["Color Hub 1"] = Color3.fromRGB(24, 24, 28),
		["Color Hub 2"] = Color3.fromRGB(32, 32, 38),
		["Color Stroke"] = Color3.fromRGB(68, 68, 78),
		["Color Theme"] = Color3.fromRGB(88, 205, 255),
		["Color Text"] = Color3.fromRGB(245, 245, 247),
		["Color Dark Text"] = Color3.fromRGB(168, 168, 176)
	},
	Slate = {
		["Color Hub 1"] = Color3.fromRGB(23, 29, 34),
		["Color Hub 2"] = Color3.fromRGB(32, 40, 46),
		["Color Stroke"] = Color3.fromRGB(58, 72, 82),
		["Color Theme"] = Color3.fromRGB(120, 255, 192),
		["Color Text"] = Color3.fromRGB(242, 248, 246),
		["Color Dark Text"] = Color3.fromRGB(156, 170, 168)
	},
	Lightstone = {
		["Color Hub 1"] = Color3.fromRGB(235, 237, 241),
		["Color Hub 2"] = Color3.fromRGB(248, 249, 251),
		["Color Stroke"] = Color3.fromRGB(202, 209, 218),
		["Color Theme"] = Color3.fromRGB(42, 136, 255),
		["Color Text"] = Color3.fromRGB(32, 37, 46),
		["Color Dark Text"] = Color3.fromRGB(102, 111, 125)
	}
}

Hub.ConfigData = {}
Hub.ControlRegistry = {}
Hub.Localization = {}
Hub.CurrentLang = "en"
Hub.UserRole = "member"
Hub.UndoStack = {}
Hub.RedoStack = {}
Hub.Connections = {}
Hub.ThemeObjects = {}
Hub.ChromaObjects = {}
Hub.Notifications = {}
Hub.ChromaEnabled = false

local player = Players.LocalPlayer
local playerGui = player and player:FindFirstChildOfClass("PlayerGui")

local function createInstance(className, properties, parent)
	local object = Instance.new(className)
	if properties then
		for key, value in pairs(properties) do
			object[key] = value
		end
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function safeCall(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	return pcall(fn, ...)
end

local function tween(object, goal, duration, easingStyle, easingDirection)
	local info = TweenInfo.new(
		duration or 0.18,
		easingStyle or Enum.EasingStyle.Quad,
		easingDirection or Enum.EasingDirection.Out
	)
	local anim = TweenService:Create(object, info, goal)
	anim:Play()
	return anim
end

local function themeFor(name)
	if type(name) == "table" then
		return name
	end
	return Hub.Themes[name or Hub.Save.Theme] or Hub.Themes.Midnight
end

local function currentTheme()
	return themeFor(Hub.Save.Theme)
end

local function trackTheme(object, property, key, customUpdater)
	local entry = {
		Instance = object,
		Property = property,
		ThemeKey = key,
		CustomFunc = customUpdater
	}
	table.insert(Hub.ThemeObjects, entry)
	if customUpdater then
		customUpdater()
	else
		local theme = currentTheme()
		if object and object.Parent and theme[key] ~= nil then
			object[property] = theme[key]
		end
	end
	return entry
end

local function trackChroma(object, property)
	table.insert(Hub.ChromaObjects, {
		Instance = object,
		Property = property
	})
end

local function removeTrackedChroma(instance)
	for i = #Hub.ChromaObjects, 1, -1 do
		if Hub.ChromaObjects[i].Instance == instance then
			table.remove(Hub.ChromaObjects, i)
		end
	end
end

local function removeAllConnections()
	for _, conn in ipairs(Hub.Connections) do
		if conn and conn.Disconnect then
			conn:Disconnect()
		end
	end
	table.clear(Hub.Connections)
end

local function clampNumber(value, minimum, maximum)
	return math.clamp(value, minimum, maximum)
end

local function roundToStep(value, step)
	if step <= 0 then
		return value
	end
	return math.floor((value / step) + 0.5) * step
end

local function formatStep(step)
	if step == math.floor(step) then
		return "%d"
	end
	local str = tostring(step)
	local dot = str:find("%.")
	if not dot then
		return "%.2f"
	end
	local precision = math.clamp(#str - dot, 0, 6)
	return "%." .. precision .. "f"
end

local function viewportSize()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1280, 720)
end

local function normalizedSize(width, height)
	local vp = viewportSize()
	local w = math.clamp(width, 320, math.floor(vp.X * 0.92))
	local h = math.clamp(height, 240, math.floor(vp.Y * 0.88))
	return UDim2.fromOffset(w, h)
end

local function applyBaseCard(card)
	card.BorderSizePixel = 0
	card.BackgroundTransparency = 0
	createInstance("UICorner", {CornerRadius = UDim.new(0, 10)}, card)
	trackTheme(card, "BackgroundColor3", "Color Hub 2")
	local stroke = createInstance("UIStroke", {
		Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	}, card)
	trackTheme(stroke, "Color", "Color Stroke")
	return stroke
end

local function currentControlValue(key, fallback)
	if Hub.ConfigData[key] ~= nil then
		return Hub.ConfigData[key]
	end
	Hub.ConfigData[key] = fallback
	return fallback
end

local function notifyCore(container, title, message, duration, progress)
	local card = createInstance("Frame", {
		Size = UDim2.fromOffset(320, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		AutomaticSize = Enum.AutomaticSize.Y
	}, container)

	local body = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0
	}, card)
	applyBaseCard(body)

	local header = createInstance("TextLabel", {
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = title or ""
	}, body)
	trackTheme(header, "TextColor3", "Color Text")

	local msg = createInstance("TextLabel", {
		Size = UDim2.new(1, -20, 0, 0),
		Position = UDim2.fromOffset(10, 32),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = message or ""
	}, body)
	trackTheme(msg, "TextColor3", "Color Dark Text")

	local accent = nil
	if progress then
		accent = createInstance("Frame", {
			Size = UDim2.new(1, 0, 0, 3),
			Position = UDim2.new(0, 0, 1, -3),
			BorderSizePixel = 0
		}, body)
		trackTheme(accent, "BackgroundColor3", "Color Theme")
		trackChroma(accent, "BackgroundColor3")
	end

	task.defer(function()
		task.wait(0.05)
		local height = 48 + msg.TextBounds.Y
		body.Size = UDim2.fromOffset(320, height)
		card.Size = UDim2.fromOffset(320, height)
		body.Position = UDim2.new(1, 40, 0, 0)
		tween(body, {Position = UDim2.new(0, 0, 0, 0)}, 0.25, Enum.EasingStyle.Quart)
		if accent then
			local progressTween = tween(accent, {Size = UDim2.new(0, 0, 0, 3)}, duration or 3, Enum.EasingStyle.Linear)
			task.delay(duration or 3, function()
				if progressTween then
					progressTween:Cancel()
				end
			end)
		end
		task.wait(duration or 3)
		local fade = tween(body, {BackgroundTransparency = 1}, 0.2)
		tween(header, {TextTransparency = 1}, 0.2)
		tween(msg, {TextTransparency = 1}, 0.2)
		if accent then
			tween(accent, {BackgroundTransparency = 1}, 0.2)
		end
		fade.Completed:Wait()
		if card then
			card:Destroy()
		end
	end)

	return card
end

task.spawn(function()
	while true do
		if Hub.ChromaEnabled then
			local hue = (tick() % 6) / 6
			local color = Color3.fromHSV(hue, 1, 1)
			for i = #Hub.ChromaObjects, 1, -1 do
				local data = Hub.ChromaObjects[i]
				if data.Instance and data.Instance.Parent then
					data.Instance[data.Property] = color
				else
					table.remove(Hub.ChromaObjects, i)
				end
			end
		end
		task.wait(0.03)
	end
end)

function Hub:ToggleChroma(state)
	self.ChromaEnabled = state and true or false
	if not self.ChromaEnabled then
		local theme = currentTheme()
		for _, data in ipairs(self.ChromaObjects) do
			if data.Instance and data.Instance.Parent and theme["Color Theme"] then
				data.Instance[data.Property] = theme["Color Theme"]
			end
		end
	end
end

function Hub:RegisterControl(key, updateFunc)
	self.ControlRegistry[key] = updateFunc
end

function Hub:AddUndo(key, oldValue, newValue)
	table.insert(self.UndoStack, {Key = key, Old = oldValue, New = newValue})
	if #self.UndoStack > 60 then
		table.remove(self.UndoStack, 1)
	end
	self.RedoStack = {}
end

function Hub:Undo()
	local item = self.UndoStack[#self.UndoStack]
	if not item then
		return
	end
	self.UndoStack[#self.UndoStack] = nil
	local handler = self.ControlRegistry[item.Key]
	if handler then
		handler(item.Old)
	end
	table.insert(self.RedoStack, item)
end

function Hub:Redo()
	local item = self.RedoStack[#self.RedoStack]
	if not item then
		return
	end
	self.RedoStack[#self.RedoStack] = nil
	local handler = self.ControlRegistry[item.Key]
	if handler then
		handler(item.New)
	end
	table.insert(self.UndoStack, item)
end

function Hub:ApplyConfig(configData)
	for key, value in pairs(configData or {}) do
		local handler = self.ControlRegistry[key]
		if handler then
			handler(value)
		end
	end
end

function Hub:RegisterTheme(name, definition)
	if type(name) == "string" and type(definition) == "table" then
		self.Themes[name] = definition
	end
end

function Hub:SetLanguage(lang)
	self.CurrentLang = lang or "en"
end

function Hub:LocalizeText(textKey)
	local lang = self.Localization[self.CurrentLang]
	if lang and lang[textKey] ~= nil then
		return lang[textKey]
	end
	return textKey
end

function Hub:SetUserRole(roleName)
	self.UserRole = roleName or "member"
end

function Hub:CheckRole(requiredRole)
	if not requiredRole then
		return true
	end
	return self.UserRole == requiredRole
end

function Hub:PlaySound(soundId)
	if not soundId or soundId == 0 then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. tostring(soundId)
	s.Volume = 1
	s.PlayOnRemove = true
	s.Parent = workspace
	s:Destroy()
end

function Hub:UpdateTheme(newTheme)
	self.Save.Theme = newTheme or self.Save.Theme
	local theme = currentTheme()
	for i = #self.ThemeObjects, 1, -1 do
		local data = self.ThemeObjects[i]
		if data.Instance and data.Instance.Parent then
			if data.CustomFunc then
				data.CustomFunc()
			elseif not (self.ChromaEnabled and data.ThemeKey == "Color Theme") then
				local value = theme[data.ThemeKey]
				if value ~= nil then
					data.Instance[data.Property] = value
				end
			end
		else
			table.remove(self.ThemeObjects, i)
		end
	end
end

function Hub:SetTheme(newTheme)
	self:UpdateTheme(newTheme)
end

local SectionMethods = {}
local TabMethods = {}

function SectionMethods:addMenu(name)
	local text = name and tostring(name) or "Menu"
	local frame = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1
	}, self.Content)

	local line = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 0.5, 0),
		BorderSizePixel = 0
	}, frame)
	trackTheme(line, "BackgroundColor3", "Color Stroke")

	local label = createInstance("TextLabel", {
		Size = UDim2.fromOffset(math.clamp(80 + (#text * 6), 90, 220), 20),
		Position = UDim2.new(0, 10, 0.5, -10),
		BackgroundTransparency = 0,
		Text = text,
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center
	}, frame)
	trackTheme(label, "BackgroundColor3", "Color Hub 1")
	trackTheme(label, "TextColor3", "Color Text")
	createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, label)
	local stroke = createInstance("UIStroke", {Thickness = 1}, label)
	trackTheme(stroke, "Color", "Color Stroke")
	return frame
end

function SectionMethods:addChromaToggle()
	return self:addToggle({
		Name = "Chroma Mode",
		Default = Hub.ChromaEnabled,
		Callback = function(state)
			Hub:ToggleChroma(state)
		end
	})
end

function SectionMethods:addToggle(options)
	options = options or {}
	local title = options.Name or "Toggle"
	local default = options.Default or false
	local callback = options.Callback or function() end
	local role = options.Role

	if role and not Hub:CheckRole(role) then
		return nil
	end

	local state = currentControlValue(title, default) and true or false
	local frame = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 0
	}, self.Content)
	applyBaseCard(frame)

	local label = createInstance("TextLabel", {
		Size = UDim2.new(1, -72, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left
	}, frame)
	trackTheme(label, "TextColor3", "Color Text")

	local pill = createInstance("Frame", {
		Size = UDim2.fromOffset(38, 20),
		Position = UDim2.new(1, -50, 0.5, -10),
		BorderSizePixel = 0
	}, frame)
	trackTheme(pill, "BackgroundColor3", state and "Color Theme" or "Color Hub 1")
	createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, pill)
	local pillStroke = createInstance("UIStroke", {Thickness = 1}, pill)
	trackTheme(pillStroke, "Color", "Color Stroke")

	local knob = createInstance("Frame", {
		Size = UDim2.fromOffset(16, 16),
		Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	}, pill)
	createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, knob)

	local button = createInstance("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false
	}, frame)

	local updating = false
	local function render(on)
		updating = true
		state = on and true or false
		Hub.ConfigData[title] = state
		tween(knob, {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}, 0.16)
		if not Hub.ChromaEnabled then
			tween(pill, {BackgroundColor3 = state and currentTheme()["Color Theme"] or currentTheme()["Color Hub 1"]}, 0.16)
		end
		updating = false
	end

	Hub:RegisterControl(title, function(val)
		local old = state
		render(val and true or false)
		Hub:AddUndo(title, old, state)
	end)

	render(state)
	safeCall(callback, state)

	local conn = button.MouseButton1Click:Connect(function()
		local old = state
		local nextState = not state
		render(nextState)
		safeCall(callback, nextState)
		Hub:AddUndo(title, old, nextState)
	end)
	table.insert(Hub.Connections, conn)
	if state then
		trackChroma(pill, "BackgroundColor3")
	end

	return {
		Set = function(_, value)
			render(value and true or false)
		end
	}
end

function SectionMethods:addButton(options)
	options = options or {}
	local title = options.Name or "Button"
	local callback = options.Callback or function() end
	local role = options.Role

	if role and not Hub:CheckRole(role) then
		return nil
	end

	local frame = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 0
	}, self.Content)
	applyBaseCard(frame)

	local label = createInstance("TextLabel", {
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left
	}, frame)
	trackTheme(label, "TextColor3", "Color Text")

	local accent = createInstance("Frame", {
		Size = UDim2.fromOffset(6, 16),
		Position = UDim2.new(1, -16, 0.5, -8),
		BorderSizePixel = 0
	}, frame)
	trackTheme(accent, "BackgroundColor3", "Color Theme")
	createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, accent)
	trackChroma(accent, "BackgroundColor3")

	local button = createInstance("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false
	}, frame)

	local conn = button.MouseButton1Click:Connect(function()
		safeCall(callback)
	end)
	table.insert(Hub.Connections, conn)

	return frame
end

function SectionMethods:addLabel(options)
	options = type(options) == "string" and {Text = options} or options or {}
	local text = options.Text or options.Name or "Label"
	local align = options.Align or "Left"

	local frame = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 28),
		BackgroundTransparency = 1
	}, self.Content)

	local label = createInstance("TextLabel", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = align == "Center" and Enum.TextXAlignment.Center or align == "Right" and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
	}, frame)
	trackTheme(label, "TextColor3", "Color Dark Text")

	if align == "Left" then
		createInstance("UIPadding", {
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4)
		}, label)
	end

	return {
		SetText = function(_, newText)
			label.Text = tostring(newText)
		end
	}
end

function SectionMethods:addTextBox(options)
	options = options or {}
	local title = options.Name or "TextBox"
	local default = options.Default or ""
	local callback = options.Callback or function() end

	local frame = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundTransparency = 0
	}, self.Content)
	applyBaseCard(frame)

	local label = createInstance("TextLabel", {
		Size = UDim2.new(0.42, -12, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left
	}, frame)
	trackTheme(label, "TextColor3", "Color Text")

	local input = createInstance("TextBox", {
		Size = UDim2.new(0.58, -18, 0, 26),
		Position = UDim2.new(0.42, 6, 0.5, -13),
		BorderSizePixel = 0,
		Text = default,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		ClearTextOnFocus = false,
		PlaceholderText = "Type here..."
	}, frame)
	trackTheme(input, "BackgroundColor3", "Color Hub 1")
	trackTheme(input, "TextColor3", "Color Text")
	trackTheme(input, "PlaceholderColor3", "Color Dark Text")
	createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, input)
	local stroke = createInstance("UIStroke", {Thickness = 1}, input)
	trackTheme(stroke, "Color", "Color Stroke")

	local conn = input.FocusLost:Connect(function()
		Hub.ConfigData[title] = input.Text
		safeCall(callback, input.Text)
	end)
	table.insert(Hub.Connections, conn)

	Hub:RegisterControl(title, function(value)
		input.Text = tostring(value or "")
	end)

	return {
		Set = function(_, value)
			input.Text = tostring(value or "")
		end
	}
end

function SectionMethods:addSlider(options)
	options = options or {}
	local title = options.Name or "Slider"
	local minVal = options.Min or 0
	local maxVal = options.Max or 100
	local step = options.Step or options.Float or 1
	if step <= 0 then
		step = 1
	end
	local default = options.Default or minVal
	local callback = options.Callback or function() end

	local value = currentControlValue(title, default)
	value = clampNumber(roundToStep(value, step), minVal, maxVal)
	Hub.ConfigData[title] = value

	local frame = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundTransparency = 0
	}, self.Content)
	applyBaseCard(frame)

	local label = createInstance("TextLabel", {
		Size = UDim2.new(0.62, -12, 0, 18),
		Position = UDim2.fromOffset(12, 4),
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left
	}, frame)
	trackTheme(label, "TextColor3", "Color Text")

	local valueBox = createInstance("TextBox", {
		Size = UDim2.fromOffset(52, 20),
		Position = UDim2.new(1, -64, 0, 4),
		BorderSizePixel = 0,
		Text = string.format(formatStep(step), value),
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		ClearTextOnFocus = false
	}, frame)
	trackTheme(valueBox, "BackgroundColor3", "Color Hub 1")
	trackTheme(valueBox, "TextColor3", "Color Text")
	createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, valueBox)
	local valueStroke = createInstance("UIStroke", {Thickness = 1}, valueBox)
	trackTheme(valueStroke, "Color", "Color Stroke")

	local barButton = createInstance("TextButton", {
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.fromOffset(12, 28),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false
	}, frame)

	local track = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 6),
		Position = UDim2.new(0, 0, 0.5, -3),
		BorderSizePixel = 0
	}, barButton)
	trackTheme(track, "BackgroundColor3", "Color Hub 1")
	createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, track)

	local fill = createInstance("Frame", {
		Size = UDim2.new((value - minVal) / (maxVal - minVal), 0, 1, 0),
		BorderSizePixel = 0
	}, track)
	trackTheme(fill, "BackgroundColor3", "Color Theme")
	createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)
	trackChroma(fill, "BackgroundColor3")

	local knob = createInstance("Frame", {
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(1, -7, 0.5, -7),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	}, fill)
	createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, knob)

	local dragging = false
	local function render(newValue, silent)
		value = clampNumber(roundToStep(newValue, step), minVal, maxVal)
		Hub.ConfigData[title] = value
		valueBox.Text = string.format(formatStep(step), value)
		local ratio = (value - minVal) / (maxVal - minVal)
		tween(fill, {Size = UDim2.new(ratio, 0, 1, 0)}, 0.08)
		if not silent then
			safeCall(callback, value)
		end
	end

	local function fromInput(input)
		local x = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		render(minVal + (maxVal - minVal) * x, false)
	end

	local conn1 = barButton.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromInput(input)
		end
	end)
	table.insert(Hub.Connections, conn1)

	local conn2 = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromInput(input)
		end
	end)
	table.insert(Hub.Connections, conn2)

	local conn3 = UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
		end
	end)
	table.insert(Hub.Connections, conn3)

	local conn4 = valueBox.FocusLost:Connect(function()
		local parsed = tonumber(valueBox.Text)
		if parsed then
			render(parsed, false)
		else
			valueBox.Text = string.format(formatStep(step), value)
		end
	end)
	table.insert(Hub.Connections, conn4)

	Hub:RegisterControl(title, function(newValue)
		render(tonumber(newValue) or value, true)
	end)

	render(value, true)

	return {
		Set = function(_, newValue)
			render(tonumber(newValue) or value, false)
		end
	}
end

function SectionMethods:addDropdown(options)
	options = options or {}
	local title = options.Name or "Dropdown"
	local items = options.Items or {}
	local presets = options.Presets or {}
	local multi = options.Multi or false
	local callback = options.Callback or function() end
	local default = options.Default or (multi and {} or (items[1] or ""))
	local selected = {}

	if multi then
		for _, item in ipairs(default) do
			selected[item] = true
		end
	end

	Hub.ConfigData[title] = default

	local frame = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 0
	}, self.Content)
	applyBaseCard(frame)

	local header = createInstance("TextButton", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false
	}, frame)

	local label = createInstance("TextLabel", {
		Size = UDim2.new(0.48, -12, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left
	}, header)
	trackTheme(label, "TextColor3", "Color Text")

	local current = createInstance("TextLabel", {
		Size = UDim2.new(0.45, -20, 1, 0),
		Position = UDim2.new(0.48, 0, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd
	}, header)
	trackTheme(current, "TextColor3", "Color Dark Text")

	local arrow = createInstance("TextLabel", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(1, -24, 0.5, -9),
		BackgroundTransparency = 1,
		Text = "⌄",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center
	}, header)
	trackTheme(arrow, "TextColor3", "Color Dark Text")

	local body = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, 44),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true
	}, frame)
	trackTheme(body, "BackgroundColor3", "Color Hub 2")
	local bodyStroke = createInstance("UIStroke", {Thickness = 1}, body)
	trackTheme(bodyStroke, "Color", "Color Stroke")
	createInstance("UICorner", {CornerRadius = UDim.new(0, 10)}, body)

	local scroll = createInstance("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ScrollBarThickness = 2,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0)
	}, body)
	trackTheme(scroll, "ScrollBarImageColor3", "Color Stroke")
	createInstance("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4)
	}, scroll)

	local open = false
	local function currentText()
		if multi then
			local values = {}
			for item, isOn in pairs(selected) do
				if isOn then
					table.insert(values, item)
				end
			end
			table.sort(values)
			return (#values > 0 and table.concat(values, ", ")) or "Select..."
		end
		return tostring(default ~= "" and default or "Select...")
	end

	local function applyCurrent()
		current.Text = currentText()
		if multi then
			local values = {}
			for item, isOn in pairs(selected) do
				if isOn then
					table.insert(values, item)
				end
			end
			table.sort(values)
			Hub.ConfigData[title] = values
			safeCall(callback, values)
		else
			Hub.ConfigData[title] = default
			safeCall(callback, default)
		end
	end

	local function renderItems()
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		local function createItem(name, isPreset)
			local item = createInstance("TextButton", {
				Size = UDim2.new(1, 0, 0, 30),
				BorderSizePixel = 0,
				Text = (multi and "   " or "") .. tostring(name),
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false
			}, scroll)
			trackTheme(item, "BackgroundColor3", "Color Hub 1")
			trackTheme(item, "TextColor3", isPreset and "Color Theme" or "Color Text")
			createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, item)

			if isPreset then
				trackChroma(item, "TextColor3")
			end

			local mark = nil
			if multi then
				mark = createInstance("Frame", {
					Size = UDim2.fromOffset(12, 12),
					Position = UDim2.fromOffset(8, 9),
					BorderSizePixel = 0
				}, item)
				trackTheme(mark, "BackgroundColor3", selected[name] and "Color Theme" or "Color Hub 2")
				createInstance("UICorner", {CornerRadius = UDim.new(0, 4)}, mark)
				local markStroke = createInstance("UIStroke", {Thickness = 1}, mark)
				trackTheme(markStroke, "Color", "Color Stroke")
			end

			local conn = item.MouseButton1Click:Connect(function()
				if multi then
					selected[name] = not selected[name]
					if mark then
						mark.BackgroundColor3 = selected[name] and currentTheme()["Color Theme"] or currentTheme()["Color Hub 2"]
						if selected[name] then
							trackChroma(mark, "BackgroundColor3")
						else
							removeTrackedChroma(mark)
						end
					end
					applyCurrent()
				else
					default = name
					applyCurrent()
					open = false
					tween(frame, {Size = UDim2.new(1, 0, 0, 44)}, 0.16)
					tween(body, {Size = UDim2.new(1, 0, 0, 0)}, 0.16)
					tween(arrow, {Rotation = 0}, 0.16)
				end
			end)
			table.insert(Hub.Connections, conn)
		end

		if not multi then
			for _, preset in ipairs(presets) do
				createItem("★ " .. tostring(preset), true)
			end
		end
		for _, item in ipairs(items) do
			createItem(item, false)
		end
	end

	renderItems()
	applyCurrent()

	local function setOpen(state)
		open = state and true or false
		tween(arrow, {Rotation = open and 180 or 0}, 0.16)
		tween(frame, {Size = open and UDim2.new(1, 0, 0, 176) or UDim2.new(1, 0, 0, 44)}, 0.18)
		tween(body, {Size = open and UDim2.new(1, 0, 0, 132) or UDim2.new(1, 0, 0, 0)}, 0.18)
	end

	local conn = header.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)
	table.insert(Hub.Connections, conn)

	Hub:RegisterControl(title, function(value)
		if multi and type(value) == "table" then
			selected = {}
			for _, item in ipairs(value) do
				selected[item] = true
			end
			applyCurrent()
			renderItems()
		elseif (not multi) and value ~= nil then
			default = tostring(value)
			applyCurrent()
		end
	end)

	return {
		Refresh = function(_, newItems)
			items = newItems or {}
			renderItems()
		end,
		Clear = function(_)
			items = {}
			default = multi and {} or ""
			selected = {}
			applyCurrent()
			renderItems()
		end
	}
end

function SectionMethods:addColorPicker(options)
	options = options or {}
	local title = options.Name or "ColorPicker"
	local default = options.Default or Color3.fromRGB(255, 255, 255)
	local callback = options.Callback or function() end

	local frame = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 84),
		BackgroundTransparency = 0
	}, self.Content)
	applyBaseCard(frame)

	local label = createInstance("TextLabel", {
		Size = UDim2.new(1, -70, 0, 18),
		Position = UDim2.fromOffset(12, 4),
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left
	}, frame)
	trackTheme(label, "TextColor3", "Color Text")

	local preview = createInstance("Frame", {
		Size = UDim2.fromOffset(46, 20),
		Position = UDim2.new(1, -58, 0, 4),
		BorderSizePixel = 0,
		BackgroundColor3 = default
	}, frame)
	createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, preview)
	local previewStroke = createInstance("UIStroke", {Thickness = 1}, preview)
	trackTheme(previewStroke, "Color", "Color Stroke")

	local function box(x, text, tint)
		local b = createInstance("TextBox", {
			Size = UDim2.fromOffset(42, 22),
			Position = UDim2.fromOffset(x, 34),
			Text = text,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			ClearTextOnFocus = false,
			BorderSizePixel = 0
		}, frame)
		trackTheme(b, "BackgroundColor3", "Color Hub 1")
		trackTheme(b, "TextColor3", "Color Text")
		createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, b)
		local stroke = createInstance("UIStroke", {Thickness = 1}, b)
		trackTheme(stroke, "Color", "Color Stroke")
		if tint then
			b.TextColor3 = tint
		end
		return b
	end

	local rBox = box(12, tostring(math.floor(default.R * 255)), Color3.fromRGB(255, 120, 120))
	local gBox = box(58, tostring(math.floor(default.G * 255)), Color3.fromRGB(120, 255, 120))
	local bBox = box(104, tostring(math.floor(default.B * 255)), Color3.fromRGB(120, 160, 255))
	local hexBox = box(150, "#" .. default:ToHex(), nil)
	hexBox.Size = UDim2.fromOffset(74, 22)

	local function applyColor(color)
		preview.BackgroundColor3 = color
		rBox.Text = tostring(math.floor(color.R * 255))
		gBox.Text = tostring(math.floor(color.G * 255))
		bBox.Text = tostring(math.floor(color.B * 255))
		hexBox.Text = "#" .. color:ToHex():upper()
		Hub.ConfigData[title] = color
		safeCall(callback, color)
	end

	local function fromRGB()
		local r = clampNumber(tonumber(rBox.Text) or 0, 0, 255)
		local g = clampNumber(tonumber(gBox.Text) or 0, 0, 255)
		local b = clampNumber(tonumber(bBox.Text) or 0, 0, 255)
		applyColor(Color3.fromRGB(r, g, b))
	end

	local function fromHex()
		local value = hexBox.Text:gsub("#", "")
		local ok, color = pcall(Color3.fromHex, value)
		if ok and color then
			applyColor(color)
		else
			hexBox.Text = "#" .. preview.BackgroundColor3:ToHex():upper()
		end
	end

	table.insert(Hub.Connections, rBox.FocusLost:Connect(fromRGB))
	table.insert(Hub.Connections, gBox.FocusLost:Connect(fromRGB))
	table.insert(Hub.Connections, bBox.FocusLost:Connect(fromRGB))
	table.insert(Hub.Connections, hexBox.FocusLost:Connect(fromHex))

	Hub:RegisterControl(title, function(value)
		if typeof(value) == "Color3" then
			preview.BackgroundColor3 = value
			rBox.Text = tostring(math.floor(value.R * 255))
			gBox.Text = tostring(math.floor(value.G * 255))
			bBox.Text = tostring(math.floor(value.B * 255))
			hexBox.Text = "#" .. value:ToHex():upper()
		end
	end)

	Hub.ConfigData[title] = default
	return frame
end

function SectionMethods:addScriptBox(options)
	options = options or {}
	local title = options.Name or "ScriptBox"
	local default = options.Default or ""
	local callback = options.Callback or function() end

	local frame = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundTransparency = 0
	}, self.Content)
	applyBaseCard(frame)

	local label = createInstance("TextLabel", {
		Size = UDim2.new(1, -66, 0, 18),
		Position = UDim2.fromOffset(12, 4),
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left
	}, frame)
	trackTheme(label, "TextColor3", "Color Text")

	local input = createInstance("TextBox", {
		Size = UDim2.new(1, -70, 0, 58),
		Position = UDim2.fromOffset(12, 28),
		BorderSizePixel = 0,
		Text = default,
		Font = Enum.Font.Code,
		TextSize = 12,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		PlaceholderText = "Paste code here..."
	}, frame)
	trackTheme(input, "BackgroundColor3", "Color Hub 1")
	trackTheme(input, "TextColor3", "Color Text")
	trackTheme(input, "PlaceholderColor3", "Color Dark Text")
	createInstance("UICorner", {CornerRadius = UDim.new(0, 8)}, input)
	local stroke = createInstance("UIStroke", {Thickness = 1}, input)
	trackTheme(stroke, "Color", "Color Stroke")

	local run = createInstance("TextButton", {
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.new(1, -50, 1, -50),
		Text = "▶",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false
	}, frame)
	trackTheme(run, "BackgroundColor3", "Color Theme")
	trackTheme(run, "TextColor3", "Color Hub 1")
	createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, run)
	trackChroma(run, "BackgroundColor3")

	local conn = run.MouseButton1Click:Connect(function()
		safeCall(callback, input.Text)
	end)
	table.insert(Hub.Connections, conn)

	Hub:RegisterControl(title, function(value)
		input.Text = tostring(value or "")
	end)

	return frame
end

function SectionMethods:addBind(options)
	options = options or {}
	local title = options.Name or "KeyBind"
	local default = options.Default or "RightShift"
	local callback = options.Callback or function() end

	local blacklist = {
		[Enum.KeyCode.W] = true,
		[Enum.KeyCode.A] = true,
		[Enum.KeyCode.S] = true,
		[Enum.KeyCode.D] = true,
		[Enum.KeyCode.Space] = true,
		[Enum.KeyCode.Tab] = true,
		[Enum.KeyCode.Escape] = true,
		[Enum.KeyCode.Backspace] = true,
		[Enum.KeyCode.Return] = true,
		[Enum.KeyCode.Unknown] = true
	}

	local frame = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 0
	}, self.Content)
	applyBaseCard(frame)

	local label = createInstance("TextLabel", {
		Size = UDim2.new(0.55, -12, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = title,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left
	}, frame)
	trackTheme(label, "TextColor3", "Color Text")

	local keyBox = createInstance("TextBox", {
		Size = UDim2.fromOffset(96, 24),
		Position = UDim2.new(1, -108, 0.5, -12),
		Text = tostring(default),
		Font = Enum.Font.GothamSemibold,
		TextSize = 11,
		ClearTextOnFocus = false,
		BorderSizePixel = 0
	}, frame)
	trackTheme(keyBox, "BackgroundColor3", "Color Hub 1")
	trackTheme(keyBox, "TextColor3", "Color Text")
	createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, keyBox)
	local stroke = createInstance("UIStroke", {Thickness = 1}, keyBox)
	trackTheme(stroke, "Color", "Color Stroke")

	local binding = nil
	local captureConn = nil
	local triggerConn = nil

	local function setBind(keyCode)
		if blacklist[keyCode] then
			keyBox.Text = binding and binding.Name or "None"
			return
		end
		binding = keyCode
		Hub.ConfigData[title] = keyCode.Name
		keyBox.Text = keyCode.Name
		if triggerConn then
			triggerConn:Disconnect()
		end
		triggerConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if not gameProcessed and binding and input.KeyCode == binding then
				safeCall(callback)
			end
		end)
		table.insert(Hub.Connections, triggerConn)
	end

	for _, keyCode in ipairs(Enum.KeyCode:GetEnumItems()) do
		if keyCode.Name:lower() == tostring(default):lower() then
			setBind(keyCode)
			break
		end
	end

	local conn = keyBox.Focused:Connect(function()
		keyBox.Text = "Press Key"
		if captureConn then
			captureConn:Disconnect()
		end
		captureConn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				setBind(input.KeyCode)
				keyBox:ReleaseFocus()
				if captureConn then
					captureConn:Disconnect()
					captureConn = nil
				end
			end
		end)
		table.insert(Hub.Connections, captureConn)
	end)
	table.insert(Hub.Connections, conn)

	Hub:RegisterControl(title, function(value)
		if typeof(value) == "EnumItem" then
			setBind(value)
		elseif type(value) == "string" then
			for _, keyCode in ipairs(Enum.KeyCode:GetEnumItems()) do
				if keyCode.Name:lower() == value:lower() then
					setBind(keyCode)
					break
				end
			end
		end
	end)

	return frame
end

function SectionMethods:addConfigManager()
	local frame = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 78),
		BackgroundTransparency = 0
	}, self.Content)
	applyBaseCard(frame)

	local label = createInstance("TextLabel", {
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(12, 4),
		BackgroundTransparency = 1,
		Text = "Config Manager",
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left
	}, frame)
	trackTheme(label, "TextColor3", "Color Text")

	local nameBox = createInstance("TextBox", {
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.fromOffset(12, 26),
		Text = "JustHub_Config",
		Font = Enum.Font.Gotham,
		TextSize = 11,
		ClearTextOnFocus = false,
		BorderSizePixel = 0
	}, frame)
	trackTheme(nameBox, "BackgroundColor3", "Color Hub 1")
	trackTheme(nameBox, "TextColor3", "Color Text")
	trackTheme(nameBox, "PlaceholderColor3", "Color Dark Text")
	createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, nameBox)
	local ns = createInstance("UIStroke", {Thickness = 1}, nameBox)
	trackTheme(ns, "Color", "Color Stroke")

	local saveBtn = createInstance("TextButton", {
		Size = UDim2.fromOffset(70, 20),
		Position = UDim2.fromOffset(12, 54),
		Text = "Save",
		Font = Enum.Font.GothamSemibold,
		TextSize = 11,
		AutoButtonColor = false
	}, frame)
	trackTheme(saveBtn, "BackgroundColor3", "Color Theme")
	trackTheme(saveBtn, "TextColor3", "Color Hub 1")
	createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, saveBtn)

	local loadBtn = createInstance("TextButton", {
		Size = UDim2.fromOffset(70, 20),
		Position = UDim2.fromOffset(90, 54),
		Text = "Load",
		Font = Enum.Font.GothamSemibold,
		TextSize = 11,
		AutoButtonColor = false
	}, frame)
	trackTheme(loadBtn, "BackgroundColor3", "Color Hub 1")
	trackTheme(loadBtn, "TextColor3", "Color Text")
	createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, loadBtn)
	local ls = createInstance("UIStroke", {Thickness = 1}, loadBtn)
	trackTheme(ls, "Color", "Color Stroke")

	local clearBtn = createInstance("TextButton", {
		Size = UDim2.fromOffset(70, 20),
		Position = UDim2.fromOffset(168, 54),
		Text = "Reset",
		Font = Enum.Font.GothamSemibold,
		TextSize = 11,
		AutoButtonColor = false
	}, frame)
	trackTheme(clearBtn, "BackgroundColor3", "Color Hub 1")
	trackTheme(clearBtn, "TextColor3", "Color Text")
	createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, clearBtn)
	local cs = createInstance("UIStroke", {Thickness = 1}, clearBtn)
	trackTheme(cs, "Color", "Color Stroke")

	local function configName()
		local raw = nameBox.Text:gsub("%s+", "_")
		if raw == "" then
			return "JustHub_Config"
		end
		return raw
	end

	local saveConn = saveBtn.MouseButton1Click:Connect(function()
		Hub:SaveConfig(configName() .. ".json")
	end)
	local loadConn = loadBtn.MouseButton1Click:Connect(function()
		Hub:LoadConfig(configName() .. ".json")
	end)
	local clearConn = clearBtn.MouseButton1Click:Connect(function()
		Hub.ConfigData = {}
		Hub:Notify({
			Title = "Config",
			Message = "Memory cleared",
			Duration = 2
		})
	end)
	table.insert(Hub.Connections, saveConn)
	table.insert(Hub.Connections, loadConn)
	table.insert(Hub.Connections, clearConn)

	return frame
end

function TabMethods:addSection(sectionName)
	local section = {
		Frame = createInstance("Frame", {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 0
		}, self.Page),
		Title = nil,
		Content = nil
	}
	applyBaseCard(section.Frame)

	local title = createInstance("TextLabel", {
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(10, 8),
		BackgroundTransparency = 1,
		Text = sectionName or "Section",
		Font = Enum.Font.GothamSemibold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left
	}, section.Frame)
	trackTheme(title, "TextColor3", "Color Text")
	section.Title = title

	local content = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1
	}, section.Frame)
	section.Content = content

	createInstance("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 8)
	}, content)
	createInstance("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10)
	}, content)

	setmetatable(section, {__index = SectionMethods})
	table.insert(self.Sections, section)
	return section
end

function TabMethods:Select()
	if self.Window and self.Window.SetActiveTab then
		self.Window:SetActiveTab(self)
	end
end

function Hub:CreateWindow(options)
	options = options or {}

	local windowObj = {
		Tabs = {},
		Sections = {},
		ActiveTab = nil,
		IsOpen = true,
		IsMinimized = false,
		WindowState = "normal",
		DragState = nil
	}

	local size = options.Size
	if type(size) == "table" then
		self.Save.UISize = {size[1] or self.Save.UISize[1], size[2] or self.Save.UISize[2]}
	end
	local width = self.Save.UISize[1]
	local height = self.Save.UISize[2]
	local finalSize = normalizedSize(width, height)

	local screenGui = createInstance("ScreenGui", {
		Name = options.Name or "JustHub",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global
	}, playerGui or player:WaitForChild("PlayerGui"))

	local root = createInstance("Frame", {
		Name = "Root",
		Size = finalSize,
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Visible = true
	}, screenGui)

	local shadow = createInstance("Frame", {
		Size = UDim2.new(1, 8, 1, 8),
		Position = UDim2.fromOffset(-4, -4),
		BackgroundTransparency = 1
	}, root)

	local shadowStroke = createInstance("UIStroke", {
		Thickness = 8,
		Transparency = 0.78,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	}, shadow)
	trackTheme(shadowStroke, "Color", "Color Hub 1")

	local main = createInstance("Frame", {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0,
		ClipsDescendants = true
	}, root)
	applyBaseCard(main)

	local header = createInstance("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 0,
		BorderSizePixel = 0
	}, main)
	trackTheme(header, "BackgroundColor3", "Color Hub 1")
	local headerStroke = createInstance("UIStroke", {Thickness = 1}, header)
	trackTheme(headerStroke, "Color", "Color Stroke")

	local titleText = createInstance("TextLabel", {
		Size = UDim2.new(0.58, 0, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Text = options.Title or "JustHub",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left
	}, header)
	trackTheme(titleText, "TextColor3", "Color Text")

	local subtitle = createInstance("TextLabel", {
		Size = UDim2.new(0.32, 0, 1, 0),
		Position = UDim2.new(0.58, 0, 0, 0),
		BackgroundTransparency = 1,
		Text = options.Subtitle or "Compact UI",
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right
	}, header)
	trackTheme(subtitle, "TextColor3", "Color Dark Text")

	local btnClose = createInstance("TextButton", {
		Size = UDim2.fromOffset(24, 20),
		Position = UDim2.new(1, -30, 0.5, -10),
		Text = "×",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		AutoButtonColor = false
	}, header)
	trackTheme(btnClose, "BackgroundColor3", "Color Hub 2")
	trackTheme(btnClose, "TextColor3", "Color Text")
	createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, btnClose)

	local btnMin = createInstance("TextButton", {
		Size = UDim2.fromOffset(24, 20),
		Position = UDim2.new(1, -58, 0.5, -10),
		Text = "–",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		AutoButtonColor = false
	}, header)
	trackTheme(btnMin, "BackgroundColor3", "Color Hub 2")
	trackTheme(btnMin, "TextColor3", "Color Text")
	createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, btnMin)

	local btnOpen = createInstance("TextButton", {
		Size = UDim2.fromOffset(24, 20),
		Position = UDim2.new(1, -86, 0.5, -10),
		Text = "◫",
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false
	}, header)
	trackTheme(btnOpen, "BackgroundColor3", "Color Theme")
	trackTheme(btnOpen, "TextColor3", "Color Hub 1")
	createInstance("UICorner", {CornerRadius = UDim.new(0, 6)}, btnOpen)

	local side = createInstance("Frame", {
		Size = UDim2.new(0, math.max(102, self.Save.TabSize), 1, -34),
		Position = UDim2.new(0, 0, 0, 34),
		BackgroundTransparency = 0,
		BorderSizePixel = 0
	}, main)
	trackTheme(side, "BackgroundColor3", "Color Hub 1")
	local sideStroke = createInstance("UIStroke", {Thickness = 1}, side)
	trackTheme(sideStroke, "Color", "Color Stroke")

	local tabScroll = createInstance("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, -12),
		Position = UDim2.fromOffset(0, 6),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0)
	}, side)
	trackTheme(tabScroll, "ScrollBarImageColor3", "Color Stroke")
	createInstance("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6)
	}, tabScroll)
	createInstance("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8)
	}, tabScroll)

	local pages = createInstance("Frame", {
		Size = UDim2.new(1, -(math.max(102, self.Save.TabSize)), 1, -34),
		Position = UDim2.new(0, math.max(102, self.Save.TabSize), 0, 34),
		BackgroundTransparency = 1
	}, main)

	local pageContainer = createInstance("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1
	}, pages)
	createInstance("UIPadding", {
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8)
	}, pageContainer)

	local pageScroll = createInstance("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.fromOffset(0, 0)
	}, pageContainer)
	trackTheme(pageScroll, "ScrollBarImageColor3", "Color Stroke")
	createInstance("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10)
	}, pageScroll)
	createInstance("UIPadding", {
		PaddingTop = UDim.new(0, 2),
		PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 2),
		PaddingRight = UDim.new(0, 4)
	}, pageScroll)

	local resizeGrip = createInstance("TextButton", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(1, -18, 1, -18),
		Text = "⤡",
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		AutoButtonColor = false
	}, main)
	trackTheme(resizeGrip, "BackgroundColor3", "Color Theme")
	trackTheme(resizeGrip, "TextColor3", "Color Hub 1")
	createInstance("UICorner", {CornerRadius = UDim.new(0, 5)}, resizeGrip)

	local overlay = createInstance("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Visible = true
	}, screenGui)

	local dragActive = false
	local dragStart = nil
	local startPos = nil

	local function setRootSize(newWidth, newHeight)
		local s = normalizedSize(newWidth, newHeight)
		root.Size = s
		self.Save.UISize = {math.floor(newWidth), math.floor(newHeight)}
	end

	local function setWindowVisible(isVisible)
		screenGui.Enabled = isVisible
		self.IsOpen = isVisible
	end

	local function applyMinimized(state)
		self.IsMinimized = state and true or false
		side.Visible = not self.IsMinimized
		pages.Visible = not self.IsMinimized
		resizeGrip.Visible = not self.IsMinimized
		shadow.Visible = not self.IsMinimized
		if self.IsMinimized then
			tween(main, {Size = UDim2.fromOffset(root.AbsoluteSize.X, 34)}, 0.16)
		else
			tween(main, {Size = UDim2.fromScale(1, 1)}, 0.16)
		end
	end

	local function selectTab(tab)
		for _, item in ipairs(windowObj.Tabs) do
			local active = item == tab
			item.Page.Visible = active
			if item.ActiveBar then
				item.ActiveBar.Visible = active
			end
			local theme = currentTheme()
			if item.Button then
				item.Button.BackgroundColor3 = active and theme["Color Theme"] or theme["Color Hub 2"]
			end
			if item.Label then
				item.Label.TextColor3 = active and theme["Color Hub 1"] or theme["Color Text"]
			end
		end
		windowObj.ActiveTab = tab
	end

	function windowObj:SetActiveTab(tab)
		selectTab(tab)
	end

	function windowObj:Open()
		setWindowVisible(true)
		main.BackgroundTransparency = 0
		root.Visible = true
	end

	function windowObj:Close()
		setWindowVisible(false)
	end

	function windowObj:Toggle()
		setWindowVisible(not screenGui.Enabled)
	end

	function windowObj:Resize(widthValue, heightValue)
		setRootSize(widthValue, heightValue)
	end

	local function createTabButton(tabObj)
		local button = createInstance("TextButton", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 0,
			Text = "",
			AutoButtonColor = false
		}, tabScroll)
		trackTheme(button, "BackgroundColor3", "Color Hub 2")
		createInstance("UICorner", {CornerRadius = UDim.new(0, 9)}, button)
		local stroke = createInstance("UIStroke", {Thickness = 1}, button)
		trackTheme(stroke, "Color", "Color Stroke")

		local label = createInstance("TextLabel", {
			Size = UDim2.new(1, -14, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			BackgroundTransparency = 1,
			Text = tabObj.Name,
			Font = Enum.Font.GothamSemibold,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left
		}, button)
		trackTheme(label, "TextColor3", "Color Text")

		local activeBar = createInstance("Frame", {
			Size = UDim2.new(0, 4, 0, 14),
			Position = UDim2.new(1, -9, 0.5, -7),
			BorderSizePixel = 0,
			Visible = false
		}, button)
		trackTheme(activeBar, "BackgroundColor3", "Color Theme")
		createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, activeBar)

		local conn = button.MouseButton1Click:Connect(function()
			selectTab(tabObj)
		end)
		table.insert(Hub.Connections, conn)

		tabObj.Button = button
		tabObj.Label = label
		tabObj.ActiveBar = activeBar
	end

	function windowObj:addTab(tabName)
		local tabObj = {
			Name = tabName or "Tab",
			Sections = {},
			Button = nil,
			Label = nil,
			ActiveBar = nil,
			Page = createInstance("Frame", {
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Visible = false,
				BackgroundTransparency = 1
			}, pageScroll),
			Window = windowObj
		}

		local layout = createInstance("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 10)
		}, tabObj.Page)

		createInstance("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2)
		}, tabObj.Page)

		createTabButton(tabObj)
		setmetatable(tabObj, {__index = TabMethods})
		table.insert(windowObj.Tabs, tabObj)

		if #windowObj.Tabs == 1 then
			tabObj.Page.Visible = true
			windowObj.ActiveTab = tabObj
		end

		return tabObj
	end

	local function layoutRoot()
		local tabWidth = math.max(102, self.Save.TabSize)
		side.Size = UDim2.new(0, tabWidth, 1, -34)
		pages.Position = UDim2.new(0, tabWidth, 0, 34)
		pages.Size = UDim2.new(1, -tabWidth, 1, -34)
	end

	layoutRoot()
	trackTheme(main, "BackgroundColor3", "Color Hub 2")

	local function startDrag(input)
		dragActive = true
		dragStart = input.Position
		startPos = root.Position
	end

	local function updateDrag(input)
		local delta = input.Position - dragStart
		root.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end

	local dragBegin = header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			startDrag(input)
		end
	end)
	table.insert(Hub.Connections, dragBegin)

	local dragChanged = UserInputService.InputChanged:Connect(function(input)
		if dragActive and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateDrag(input)
		end
	end)
	table.insert(Hub.Connections, dragChanged)

	local dragEnded = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragActive = false
		end
	end)
	table.insert(Hub.Connections, dragEnded)

	local resizeActive = false
	local resizeStart = nil
	local startSize = nil

	local function beginResize(input)
		resizeActive = true
		resizeStart = input.Position
		startSize = root.AbsoluteSize
	end

	local function updateResize(input)
		local delta = input.Position - resizeStart
		local newW = math.max(320, startSize.X + delta.X)
		local newH = math.max(240, startSize.Y + delta.Y)
		self.Save.UISize = {newW, newH}
		root.Size = UDim2.fromOffset(newW, newH)
	end

	local resizeBegin = resizeGrip.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginResize(input)
		end
	end)
	table.insert(Hub.Connections, resizeBegin)

	local resizeChanged = UserInputService.InputChanged:Connect(function(input)
		if resizeActive and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateResize(input)
		end
	end)
	table.insert(Hub.Connections, resizeChanged)

	local resizeEnded = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizeActive = false
		end
	end)
	table.insert(Hub.Connections, resizeEnded)

	local closeConn = btnClose.MouseButton1Click:Connect(function()
		windowObj:Close()
	end)
	local minConn = btnMin.MouseButton1Click:Connect(function()
		applyMinimized(not self.IsMinimized)
	end)
	local openConn = btnOpen.MouseButton1Click:Connect(function()
		if screenGui.Enabled then
			applyMinimized(false)
		else
			windowObj:Open()
		end
	end)
	table.insert(Hub.Connections, closeConn)
	table.insert(Hub.Connections, minConn)
	table.insert(Hub.Connections, openConn)

	function windowObj:Notify(options)
		return Hub:Notify(options)
	end

	function windowObj:Destroy()
		Hub:Destroy()
	end

	windowObj.ScreenGui = screenGui
	windowObj.Root = root
	windowObj.Main = main
	windowObj.Header = header
	windowObj.Sidebar = side
	windowObj.Pages = pageScroll
	windowObj.NotificationContainer = nil

	Hub.ScreenGui = screenGui
	Hub.Window = windowObj
	Hub.NotificationContainer = createInstance("Frame", {
		Size = UDim2.new(0, 340, 1, -18),
		Position = UDim2.new(1, -350, 0, 10),
		BackgroundTransparency = 1
	}, screenGui)
	createInstance("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Top,
		Padding = UDim.new(0, 8)
	}, Hub.NotificationContainer)
	createInstance("UIPadding", {
		PaddingTop = UDim.new(0, 2)
	}, Hub.NotificationContainer)

	for i, tab in ipairs(windowObj.Tabs) do
		if i == 1 then
			selectTab(tab)
		end
	end

	if options.Theme then
		self:UpdateTheme(options.Theme)
	end

	if options.DefaultTab then
		if type(options.DefaultTab) == "number" and windowObj.Tabs[options.DefaultTab] then
			selectTab(windowObj.Tabs[options.DefaultTab])
		else
			for _, tab in ipairs(windowObj.Tabs) do
				if tostring(tab.Name) == tostring(options.DefaultTab) then
					selectTab(tab)
					break
				end
			end
		end
	end

	return windowObj
end

function Hub:ShowLoadingScreen(duration, callback)
	duration = duration or 2.5
	callback = callback or function() end

	local gui = createInstance("ScreenGui", {
		Name = "JustHubLoading",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Global
	}, playerGui or player:WaitForChild("PlayerGui"))

	local overlay = createInstance("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BorderSizePixel = 0
	}, gui)
	trackTheme(overlay, "BackgroundColor3", "Color Hub 1")

	local card = createInstance("Frame", {
		Size = UDim2.fromOffset(280, 116),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 0
	}, overlay)
	applyBaseCard(card)

	local title = createInstance("TextLabel", {
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 12),
		BackgroundTransparency = 1,
		Text = "JustHub",
		Font = Enum.Font.GothamBold,
		TextSize = 18
	}, card)
	trackTheme(title, "TextColor3", "Color Text")

	local subtitle = createInstance("TextLabel", {
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 36),
		BackgroundTransparency = 1,
		Text = "Loading compact interface",
		Font = Enum.Font.Gotham,
		TextSize = 11
	}, card)
	trackTheme(subtitle, "TextColor3", "Color Dark Text")

	local bar = createInstance("Frame", {
		Size = UDim2.new(1, -20, 0, 10),
		Position = UDim2.fromOffset(10, 70),
		BorderSizePixel = 0
	}, card)
	trackTheme(bar, "BackgroundColor3", "Color Hub 1")
	createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, bar)
	local barStroke = createInstance("UIStroke", {Thickness = 1}, bar)
	trackTheme(barStroke, "Color", "Color Stroke")

	local fill = createInstance("Frame", {
		Size = UDim2.new(0, 0, 1, 0),
		BorderSizePixel = 0
	}, bar)
	trackTheme(fill, "BackgroundColor3", "Color Theme")
	createInstance("UICorner", {CornerRadius = UDim.new(1, 0)}, fill)
	trackChroma(fill, "BackgroundColor3")

	local tweenBar = tween(fill, {Size = UDim2.new(1, 0, 1, 0)}, duration, Enum.EasingStyle.Linear)

	task.spawn(function()
		while tweenBar and tweenBar.PlaybackState == Enum.PlaybackState.Playing do
			subtitle.TextTransparency = 0.1
			task.wait(0.12)
			subtitle.TextTransparency = 0.55
			task.wait(0.12)
		end
	end)

	tweenBar.Completed:Connect(function()
		task.wait(0.25)
		local fade = tween(overlay, {BackgroundTransparency = 1}, 0.25)
		tween(card, {BackgroundTransparency = 1}, 0.25)
		tween(title, {TextTransparency = 1}, 0.25)
		tween(subtitle, {TextTransparency = 1}, 0.25)
		tween(bar, {BackgroundTransparency = 1}, 0.25)
		tween(fill, {BackgroundTransparency = 1}, 0.25)
		fade.Completed:Wait()
		gui:Destroy()
		safeCall(callback)
	end)
end

function Hub:InitializeUI(options)
	self:ShowLoadingScreen(2.2, function()
		self.Window = self:CreateWindow(options or {})
	end)
end

function Hub:SaveConfig(fileName)
	fileName = fileName or "JustHub_Config.json"
	if not writefile then
		self:Notify({
			Title = "Save Config",
			Message = "File save is not available in this environment.",
			Duration = 3
		})
		return false
	end
	local ok, err = pcall(function()
		writefile(fileName, HttpService:JSONEncode(self.ConfigData))
	end)
	if ok then
		self:Notify({
			Title = "Save Config",
			Message = "Saved to " .. fileName,
			Duration = 3
		})
	else
		warn(err)
	end
	return ok
end

function Hub:LoadConfig(fileName)
	fileName = fileName or "JustHub_Config.json"
	if not readfile then
		self:Notify({
			Title = "Load Config",
			Message = "File load is not available in this environment.",
			Duration = 3
		})
		return {}
	end
	local data = {}
	local ok, result = pcall(function()
		return HttpService:JSONDecode(readfile(fileName))
	end)
	if ok and type(result) == "table" then
		data = result
		self.ConfigData = data
		self:ApplyConfig(data)
		self:Notify({
			Title = "Load Config",
			Message = "Loaded from " .. fileName,
			Duration = 3
		})
	else
		warn(result)
	end
	return data
end

function Hub:ToggleUIVisibility()
	if self.ScreenGui then
		self.ScreenGui.Enabled = not self.ScreenGui.Enabled
	end
end

function Hub:Notify(options)
	options = options or {}
	if self.NotificationContainer then
		return notifyCore(
			self.NotificationContainer,
			options.Title or "Notice",
			options.Message or "",
			options.Duration or 3,
			options.ShowProgress or false
		)
	end
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = options.Title or "Notice",
			Text = options.Message or "",
			Duration = options.Duration or 3
		})
	end)
end

function Hub:PromoNotify()
	self:Notify({
		Title = "JustHub",
		Message = "Fresh layout, smaller footprint, cleaner control flow.",
		Duration = 3,
		ShowProgress = true
	})
end

function Hub:Destroy()
	removeAllConnections()
	self.ThemeObjects = {}
	self.ChromaObjects = {}
	self.ConfigData = {}
	self.UndoStack = {}
	self.RedoStack = {}
	if self.ScreenGui then
		self.ScreenGui:Destroy()
		self.ScreenGui = nil
	end
	self.Window = nil
	self.NotificationContainer = nil
end

return Hub
