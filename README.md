# ⚙️ Loader

A lightweight, lifecycle-aware module loader for Roblox. This utility ensures a consistent `init → start` boot process across your game’s services and modules. Designed for modular architecture, dependency safety, and async initialization.

> ⚠️ This is a **Promise-based** module loader. You should be familiar with [Promise](https://eryn.io/roblox-lua-promise/) usage in Roblox to use it effectively.

---

## 🚀 Key Features

- 🔁 **Consistent Lifecycle**: Each module can optionally export `init()` and `start()` for structured loading.
- ⏳ **Async Safety**: Modules are `required` safely, and `start()` is deferred until `init()` of all modules is complete.
- 🧩 **Dependency Coordination**: Use `waitFor("ModuleName")` to safely depend on another module’s completion.
- 📦 **Batch Loading**: Load all children or descendant `ModuleScripts` from a container.

---

## 📦 Installation

Drop the module into your project and `require()` it once during bootstrap.

```lua
local Loader = require(path.to.loader)
```

⸻

## 📜 Module Lifecycle Order

Each module can export the following optional functions and you can include your own:

```lua
init(): () -> ()
-- Called immediately after require().
-- Use it to set up values, caches, or internal state.
-- All init() methods are called before any start().
```

```lua
start(): () -> ()
-- Called after all modules’ init() have run.
-- Use this to begin logic, connect systems, or run loops.
-- Automatically runs asynchronously.
```

```lua
waitFor(name: string): Promise<any>
-- Provided automatically in each module’s returned table.
-- Lets you await other modules’ startup before proceeding.
```

⸻

🧩 Public API

```lua
loader.load_children(container: Instance, predicate?: (Instance) -> boolean): Promise<boolean>
-- Loads all ModuleScripts that are direct children of the container.
-- If a predicate is provided, only ModuleScripts where predicate(module) == true will be loaded.
-- ✅ Optional predicate to filter modules.
-- ✅ Returns a Promise that resolves after all modules are started.
```

```lua
Loader:load_children(game.ReplicatedStorage.Modules)
```

⸻

```lua
loader.load_descendants(container: Instance, predicate?: (Instance) -> boolean): Promise<boolean>
-- Loads all ModuleScripts found recursively in the container’s descendants.
-- If a predicate is provided, only ModuleScripts where predicate(module) == true will be loaded.
```

```lua
Loader:load_descendants(game.ServerScriptService.Services)
```

⸻

🔍 Predicate Examples

Here are some example predicates you can pass into `load_children` or `load_descendants` to control which modules are loaded:

```lua
-- Load only modules whose name ends with "Service"
local function endsWithService(module)
    return module.Name:match("Service$") ~= nil
end

Loader:load_descendants(script.Modules, endsWithService)
```

```lua
-- Load only modules that have a specific tag
local CollectionService = game:GetService("CollectionService")

local function isTagged(module)
    return CollectionService:HasTag(module, "LoadMe")
end

Loader:load_descendants(script.Modules, isTagged)
```

```lua
-- Load only modules in a specific namespace
local function isCoreModule(module)
    return module.Name:sub(1, 5) == "Core_"
end

Loader:load_children(script.Modules, isCoreModule)
```

⸻
✅ Best Practices

- ✅ Use `init()` for setup logic and `start()` for beginning execution.
- ✅ Use `waitFor("ModuleName")` to safely coordinate between modules.
- ✅ Use `loader.load_descendants(...)` to recursively load all modules from a centralized folder.
- ❌ Avoid chaining `require()` calls that assume the target module has already completed startup.
- ❌ Don’t create circular dependencies between modules.

⸻

📁 Example Module

```lua
-- PlayerService.lua

local PlayerService = {}

function PlayerService.init()
    print("PlayerService initializing...")
end

function PlayerService.start()
    print("PlayerService starting...")
end

return PlayerService
```

⸻

🧪 Example Bootstrap

```lua
local Loader = require(script.Parent.Loader)

Loader:load_descendants(game.ServerScriptService.Modules):andThen(function()
    print("All modules loaded and started.")
end)
```
