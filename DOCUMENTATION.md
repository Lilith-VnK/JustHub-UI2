# JustHub UI Documentation

JustHub UI is a customizable Roblox GUI framework with a modern glass-inspired interface, adaptive Desktop/Mobile layout support, reusable UI components, themes, notifications, and configuration management.

## Requirements

- Roblox client-side environment
- `Players.LocalPlayer` must be available
- For configuration persistence: `writefile`, `readfile`, and optionally `delfile`

## Quick Start

Use this pattern to load JustHub directly:

```lua
local JustHub = loadstring(game:HttpGet("https://raw.githubusercontent.com/Lilith-VnK/JustHub-UI2/refs/heads/main/JustHub2.lua"))()

if getgenv().JustHubInstance then
    getgenv().JustHubInstance:Destroy()
end

getgenv().JustHubInstance = JustHub

JustHub:SetUserRole("admin")

JustHub:InitializeUI({
    Name = "Just Hub UI",
    Theme = "Darker"
})
```

## Adaptive Device Layout

JustHub can automatically detect whether the user is on Desktop or Mobile.

```lua
local DeviceLayout = loadstring(game:HttpGet("https://raw.githubusercontent.com/Lilith-VnK/JustHub-UI2/refs/heads/feature/adaptive-device-layout/DeviceLayout.lua"))()

DeviceLayout:Init(JustHub)
```

Call this after loading JustHub and before creating the window.

### Device Detection Rules

| Device condition | Selected mode |
|---|---|
| Touch enabled, keyboard disabled | Mobile |
| Touch and keyboard enabled, small screen | Mobile |
| Touch and keyboard enabled, large screen | Desktop |
| Keyboard only | Desktop |

### Adaptive Sizes

| Mode | Window size | Sidebar | Scale |
|---|---:|---:|---:|
| Desktop | 620 x 440 | 135 px | 1.0 |
| Mobile | 92% screen width, 68% screen height | 48-72 px | 0.82 |

## Complete Example

```lua
local JustHub = loadstring(game:HttpGet("https://raw.githubusercontent.com/Lilith-VnK/JustHub-UI2/refs/heads/main/JustHub2.lua"))()

if getgenv().JustHubInstance then
    getgenv().JustHubInstance:Destroy()
end

getgenv().JustHubInstance = JustHub

JustHub:SetUserRole("admin")

local DeviceLayout = loadstring(game:HttpGet("https://raw.githubusercontent.com/Lilith-VnK/JustHub-UI2/refs/heads/feature/adaptive-device-layout/DeviceLayout.lua"))()
DeviceLayout:Init(JustHub)

JustHub:InitializeUI({
    Name = "Just Hub UI",
    Theme = "Darker"
})

task.spawn(function()
    while not JustHub.Window do
        task.wait()
    end

    local window = JustHub.Window

    local heroTab = window:addTab("Hero", "award")
    local settingsTab = window:addTab("Settings", "cog")

    local power = heroTab:addSection("Powers")
    local util = heroTab:addSection("Utilities")
    local config = settingsTab:addSection("Config")

    power:addSlider({
        Name = "Flight Speed",
        Min = 10,
        Max = 200,
        Step = 1.5,
        Default = 50,
        Callback = function(value)
            print("Flight speed:", value)
        end
    })

    power:addMultiDropdown({
        Name = "Abilities",
        Items = {"Flight", "Laser", "Invisibility"},
        Default = {"Flight"},
        Callback = function(selected)
            print(table.concat(selected, ", "))
        end
    })

    util:addChromaToggle()
    util:addConfigManager()

    JustHub:Notify({
        Title = "Ready",
        Message = "System initialized safely.",
        Duration = 5,
        ShowProgress = true
    })
end)
```

## Device API

```lua
print(JustHub:GetDeviceMode())
print(JustHub:IsMobile())
print(JustHub:IsDesktop())
print(JustHub:IsTouchDevice())
print(JustHub:GetViewport())
```

## Components

### Toggle

```lua
section:addToggle({
    Name = "Enable Feature",
    Default = false,
    Callback = function(value)
        print(value)
    end
})
```

### Slider

```lua
section:addSlider({
    Name = "Speed",
    Min = 0,
    Max = 100,
    Step = 1,
    Default = 50,
    Callback = function(value)
        print(value)
    end
})
```

### TextBox

```lua
section:addTextBox({
    Name = "Player Name",
    Default = "",
    Callback = function(value)
        print(value)
    end
})
```

### Dropdown

```lua
section:addDropdown({
    Name = "Select Option",
    Default = "Option 1",
    Items = {"Option 1", "Option 2", "Option 3"},
    Callback = function(value)
        print(value)
    end
})
```

### MultiDropdown

```lua
section:addMultiDropdown({
    Name = "Select Options",
    Items = {"Option 1", "Option 2", "Option 3"},
    Default = {"Option 1"},
    Callback = function(selected)
        print(table.concat(selected, ", "))
    end
})
```

### Button

```lua
section:addButton({
    Name = "Test",
    ButtonText = "Click Me",
    Callback = function()
        print("Button clicked")
    end
})
```

### Label

```lua
section:addLabel({
    Name = "Information",
    Text = "JustHub UI is ready."
})
```

### ColorPicker

```lua
section:addColorPicker({
    Name = "Accent Color",
    Default = Color3.fromRGB(0, 170, 255),
    Callback = function(color)
        print(color)
    end
})
```

### Keybind

```lua
section:addKeybind({
    Name = "Toggle UI",
    Default = Enum.KeyCode.RightControl,
    Callback = function(key)
        print("Keybind changed:", key)
    end
})
```

### ScriptBox

```lua
section:addScriptBox({
    Name = "Custom Script",
    Default = "print('Hello')",
    Callback = function(code)
        print(code)
    end
})
```

### Config Manager

```lua
section:addConfigManager()
```

### Chroma Toggle

```lua
section:addChromaToggle()
```

## Notifications

```lua
JustHub:Notify({
    Title = "Success",
    Message = "Settings saved successfully.",
    Duration = 4,
    ShowProgress = true
})
```

## Themes

```lua
JustHub:SetTheme("Purple")
```

Available themes:

- Darker
- Dark
- Purple
- Light
- Neon
- Forest
- Aqua
- Crimson
- Solar
- Pastel
- Cyber
- Ocean
- Desert
- Galaxy
- Vintage
- Rainbow
- Midnight

## Custom Theme

```lua
JustHub:RegisterTheme("MyTheme", {
    ["Color Hub 1"] = Color3.fromRGB(15, 15, 20),
    ["Color Hub 2"] = Color3.fromRGB(25, 25, 30),
    ["Color Stroke"] = Color3.fromRGB(50, 50, 60),
    ["Color Theme"] = Color3.fromRGB(100, 255, 150),
    ["Color Text"] = Color3.fromRGB(255, 255, 255),
    ["Color Dark Text"] = Color3.fromRGB(170, 170, 180)
})

JustHub:SetTheme("MyTheme")
```

## Configuration

```lua
local success, err = JustHub:SaveConfig("MyConfig.json")

if success then
    print("Configuration saved")
else
    warn(err)
end
```

```lua
local success, err = JustHub:LoadConfig("MyConfig.json")

if not success then
    warn(err)
end
```

## Cleanup

```lua
JustHub:Destroy()
getgenv().JustHubInstance = nil
```

## Disclaimer

JustHub UI is an independent community project and is not affiliated with, endorsed by, or officially supported by Roblox Corporation. Users are responsible for ensuring that their usage complies with applicable platform rules and policies.
