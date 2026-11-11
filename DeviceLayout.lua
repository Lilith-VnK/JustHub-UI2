-- DeviceLayout.lua
-- Adaptive Desktop/Mobile layout support for JustHub UI.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DeviceLayout = {}
DeviceLayout.__index = DeviceLayout

function DeviceLayout:GetViewport()
	local camera = Workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

function DeviceLayout:Detect()
	local viewport = self:GetViewport()
	local isTouch = UserInputService.TouchEnabled
	local isKeyboard = UserInputService.KeyboardEnabled
	local isSmallScreen = viewport.X < 900

	local mode
	if isTouch and not isKeyboard then
		mode = "mobile"
	elseif isTouch and isKeyboard then
		mode = isSmallScreen and "mobile" or "desktop"
	else
		mode = "desktop"
	end

	self.IsTouch = isTouch
	self.IsKeyboard = isKeyboard
	self.Viewport = viewport
	self.Mode = mode

	return mode
end

function DeviceLayout:Apply(justHub)
	local viewport = self.Viewport
	local mode = self.Mode
	local save = justHub.Save
	local tokens = justHub.DesignTokens

	if mode == "mobile" then
		local width = math.clamp(viewport.X * 0.92, 300, 520)
		local height = math.clamp(viewport.Y * 0.68, 320, 560)

		save.UISize = {width, height}
		save.TabSize = math.clamp(width * 0.20, 48, 72)
		self.Scale = 0.82

		tokens.Spacing.XS = 3
		tokens.Spacing.SM = 6
		tokens.Spacing.MD = 9
		tokens.Spacing.LG = 12
		tokens.Spacing.XL = 16

		tokens.Geometry.WindowRadius = 12
		tokens.Geometry.ControlRadius = 10
		tokens.Geometry.ButtonRadius = 10
	else
		save.UISize = {620, 440}
		save.TabSize = 135
		self.Scale = 1

		tokens.Spacing.XS = 4
		tokens.Spacing.SM = 8
		tokens.Spacing.MD = 12
		tokens.Spacing.LG = 16
		tokens.Spacing.XL = 20

		tokens.Geometry.WindowRadius = 14
		tokens.Geometry.ControlRadius = 9
		tokens.Geometry.ButtonRadius = 7
	end

	return self.Scale
end

function DeviceLayout:Watch(justHub)
	local camera = Workspace.CurrentCamera
	if not camera then return end

	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:Detect()
		self:Apply(justHub)
	end)
end

function DeviceLayout:Init(justHub)
	self:Detect()
	self:Apply(justHub)
	self:Watch(justHub)

	justHub.GetDeviceMode = function()
		return self.Mode
	end

	justHub.IsMobile = function()
		return self.Mode == "mobile"
	end

	justHub.IsDesktop = function()
		return self.Mode == "desktop"
	end

	justHub.IsTouchDevice = function()
		return self.IsTouch
	end

	justHub.GetViewport = function()
		return self.Viewport
	end

	return self
end

return DeviceLayout
