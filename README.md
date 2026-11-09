JustHub UI

<p align="center">
  <strong>A customizable Roblox GUI framework with a modern glass-inspired interface.</strong>
</p><p align="center">
  <img src="https://img.shields.io/badge/Version-3.1.0-8A2BE2?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Language-Luau-00A2FF?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Interface-Modern%20Glass-20C997?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Status-Development-orange?style=for-the-badge" />
</p>---

Overview

JustHub UI is a customizable Roblox GUI framework designed to provide a clean, lightweight, and visually consistent interface for Roblox client-side projects.

It combines a modern glass-inspired design with a flexible component system, customizable themes, interactive controls, configuration management, and built-in UI utilities.

The framework focuses on balancing visual quality, usability, performance, and maintainability.

Features

Modern Glass Surface

- Dark glass-inspired interface.
- Semi-transparent UI surfaces.
- Centralized transparency configuration.
- Consistent rounded corners.
- Subtle borders and surface hierarchy.
- Smooth UI transitions.
- Responsive layout adjustments.

Navigation System

- Sidebar-based navigation.
- Multiple navigation tabs.
- Animated active tab indicator.
- Active and inactive visual states.
- Optional tab icons.

UI Components

JustHub provides a collection of built-in UI components designed to simplify interface development and deliver consistent user interactions.

Available Components

- Toggle — Interactive boolean control for enabling or disabling features.
- Slider — Adjustable numerical input with customizable minimum, maximum, and default values.
- TextBox — Editable text input for entering custom user-defined values.
- Dropdown — Selection menu that allows users to choose a single option from a predefined list.
- MultiDropdown — Multi-selection menu that allows users to select multiple options simultaneously.
- Button — Interactive action element that executes a callback when clicked.
- Label — Static text element for displaying information, descriptions, and section content.
- ColorPicker — Color selection component for customizing interface or feature colors.
- Keybind — Keyboard binding component for assigning and handling user-defined key inputs.
- ScriptBox — Text editor component for entering and managing script content.
- ConfigManager — Configuration management interface for saving, loading, and deleting configurations.
- ChromaToggle — Control for enabling or disabling dynamic rainbow color effects.

Each component provides configurable properties and callback handling, allowing developers to integrate interactive elements into their interfaces with minimal setup.

JustHub includes multiple predefined themes.

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

Custom themes can also be registered through the theme API.

Configuration Management

Built-in configuration functionality:

- Save configurations.
- Load configurations.
- Delete configurations.
- JSON serialization.
- Color3 serialization and deserialization.
- Filename validation.
- Configuration application through registered controls.

Configuration persistence requires compatible executor file APIs.

Additional Systems

- Notification system.
- Searchable controls.
- Undo and Redo.
- Control registry.
- Theme switching.
- Chroma system.
- UI visibility control.
- Window dragging and resizing.
- Minimize and maximize.
- Window locking.
- Lifecycle management.

---

Installation

JustHub is distributed as a Lua source file.

1. Download "JustHub2.lua" from this repository.
2. Integrate the source into your Roblox client-side environment.
3. Initialize the framework before creating UI components.

The framework requires a client context with access to "Players.LocalPlayer".

Quick Start

The following example assumes JustHub has been loaded as a ModuleScript.

```
local JustHub = require(path.to.JustHub2)
```

-- Create the main window
```
local Window = JustHub:CreateWindow({
    Name = "My Hub",
    SubTitle = "My Custom Interface",
    Theme = "Darker"
})
```

-- Create a navigation tab
```
local MainTab = Window:addTab("Main", "home")
```

-- Create a section
```
local MainSection = MainTab:addSection("General")
```

-- Add a toggle
```
MainSection:addToggle({
    Name = "Example Toggle",
    Default = false,

    Callback = function(value)
        print("Toggle:", value)
    end
})
```

-- Add a slider
```
MainSection:addSlider({
    Name = "Walk Speed",
    Min = 16,
    Max = 100,
    Default = 16,

    Callback = function(value)
        print("Slider:", value)
    end
})
```

-- Add a button
```
MainSection:addButton({
    Name = "Example Action",
    ButtonText = "Execute",

    Callback = function()
        print("Button clicked!")
    end
})
```

Note: Replace the ModuleScript path with the actual location of your JustHub module.

---

Component Examples

Toggle

MainSection:addToggle({
    Name = "Enable Feature",
    Default = false,

    Callback = function(value)
        print(value)
    end
})

Slider
```
MainSection:addSlider({
    Name = "Speed",
    Min = 0,
    Max = 100,
    Default = 50,
    Step = 1,

    Callback = function(value)
        print(value)
    end
})
```

TextBox
```
MainSection:addTextBox({
    Name = "Player Name",
    Default = "",

    Callback = function(value)
        print(value)
    end
})
```

Dropdown
```
MainSection:addDropdown({
    Name = "Select Option",
    Default = "Option 1",

    Presets = {
        "Option 1",
        "Option 2",
        "Option 3"
    },

    Callback = function(value)
        print(value)
    end
})
```

MultiDropdown
```
MainSection:addMultiDropdown({
    Name = "Select Options",
    Presets = {
        "Option 1",
        "Option 2",
        "Option 3"
    },

    Callback = function(values)
        print(values)
    end
})
```

Button
```
MainSection:addButton({
    Name = "Test",
    ButtonText = "Click Me",

    Callback = function()
        print("Action executed")
    end
})
```

Config Manager
```
MainSection:addConfigManager()
```

Notification
```
JustHub:Notify({
    Title = "JustHub",
    Message = "Operation completed successfully!",
    Duration = 3
})
```

---

Theme Customization

Change the active theme using:
```
JustHub:SetTheme("Purple")
```
Register a custom theme:

```
JustHub:RegisterTheme("Custom", {
    ["Color Hub 1"] = Color3.fromRGB(15, 15, 20),
    ["Color Hub 2"] = Color3.fromRGB(25, 25, 30),
    ["Color Stroke"] = Color3.fromRGB(50, 50, 60),
    ["Color Theme"] = Color3.fromRGB(100, 255, 150),
    ["Color Text"] = Color3.fromRGB(255, 255, 255),
    ["Color Dark Text"] = Color3.fromRGB(170, 170, 180)
})

JustHub:SetTheme("Custom")
```

Transparency Configuration

JustHub uses a centralized transparency system to manage the appearance of different UI surfaces.

Change the overall transparency using:

JustHub:SetTransparency(0.15)

The transparency system derives individual surface values for:

- Main Window
- Sidebar
- Content
- Active and inactive tabs
- Sections
- Controls
- Input fields
- Dropdowns
- Popups
- Notifications
- Buttons

Individual surface values are managed internally through "JustHub.DesignTokens.Transparency".

The framework uses layered translucent surfaces rather than claiming native backdrop blur.

Configuration API

Save the current configuration:

```
local success, err = JustHub:SaveConfig("MyConfig.json")

if success then
    print("Configuration saved")
else
    warn(err)
end

Load a configuration:

local success, err = JustHub:LoadConfig("MyConfig.json")

if not success then
    warn(err)
end
```

Configuration persistence depends on compatible file APIs provided by the execution environment, including "writefile" and "readfile".

Deleting configurations through the built-in Config Manager additionally requires "delfile".

Additional API

Method| Description
"CreateWindow(options)"| Creates the main GUI window
"SetTheme(name)"| Changes the active theme
"RegisterTheme(name, definition)"| Registers a custom theme
"SetTransparency(alpha)"| Changes global transparency
"ToggleChroma(state)"| Enables or disables Chroma
"Notify(options)"| Displays a notification
"SaveConfig(fileName)"| Saves configuration
"LoadConfig(fileName)"| Loads configuration
"ApplyConfig(data)"| Applies configuration data
"Undo()"| Reverts the previous control change
"Redo()"| Restores the reverted change
"ToggleUIVisibility()"| Toggles GUI visibility
"SetKey(key)"| Configures the key system
"CheckKey(inputKey)"| Validates a key
"SetUserRole(role)"| Changes the user role
"CheckRole(role)"| Checks the current user role
"SetLanguage(lang)"| Changes the language identifier
"Destroy()"| Cleans up and destroys the UI

---

Performance & Architecture

JustHub is designed with performance and maintainability in mind.

Its internal architecture includes:

- Centralized design tokens.
- Reusable UI creation helpers.
- Theme object tracking.
- Control registration.
- Managed event connections.
- Tween management.
- Weak-reference surface registries.
- Cleanup and destruction routines.

The framework also includes safeguards for client initialization and GUI lifecycle management.

Compatibility

JustHub is designed for Roblox client-side execution.

Some functionality depends on APIs available only in specific execution environments.

In particular:

- Configuration saving requires "writefile".
- Configuration loading requires "readfile".
- Configuration deletion requires "delfile".
- GUI initialization requires a valid client context.

API availability and behavior may vary between environments.

Disclaimer

JustHub is an independent community-developed project and is not affiliated with, endorsed by, or officially supported by Roblox Corporation.

Users are responsible for ensuring that their usage complies with applicable platform rules and policies.

Development Status

JustHub is actively developed.

Future improvements may include:

- Further visual refinement.
- Improved configuration management.
- Additional UI components.
- Better responsive behavior.
- Performance optimizations.
- Additional customization options.


---

<p align="center">
  <strong>JustHub UI</strong>
  <br />
  <sub>Modern Interface. Flexible Components. Clean Architecture.</sub>
</p>
