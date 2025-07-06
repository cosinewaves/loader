# ⚙️ Loader

A lightweight, lifecycle-aware module loader for Roblox. This utility ensures a consistent `init → start` boot process across your game’s services and modules. Designed for modular architecture, dependency safety, and async initialization.

---

## 🚀 Key Features

- 🔁 **Consistent Lifecycle**: Each module can optionally export `init()` and `start()` for structured loading.
- ⏳ **Async Safety**: Modules are `required` safely, and `start()` is deferred until `init()` of all modules is complete.
- 🧩 **Dependency Coordination**: Use `waitFor("ModuleName")` to safely depend on another module’s completion.
- 📦 **Batch Loading**: Load all children or descendant `ModuleScripts` from a container.
- 🪛 **Runtime Configuration**: Enable logs, switch to full instance names, or change logging prefix dynamically.
- 🧪 **Exposed Internals**: Useful for extending behavior, debugging, or hooking into loader internals.

---

## 📦 Installation

Drop the module into your project and `require()` it once during bootstrap.

```lua
local Loader = require(path.to.loader)
```

⸻

## 📜 Module Lifecycle Order

Each module can export the following optional functions:

`init(): () -> ()`
• Called immediately after require().
• Use it to set up values, caches, or internal state.
• All init() methods are called before any start().

`start(): () -> ()`
• Called after all modules’ init() have run.
• Use this to begin logic, connect systems, or run loops.
• Automatically runs asynchronously.

`waitFor(name: string): Promise<any>`
• Provided automatically in each module’s returned table.
• Lets you await other modules’ startup before proceeding.

⸻

🧩 Public API

loader.load_children(container: Instance, predicate?: (Instance) -> boolean): Promise<boolean>

Loads all ModuleScripts that are direct children of the container.
• ✅ Optional predicate to filter modules.
• ✅ Returns a Promise that resolves after all modules are started.

Loader:load_children(game.ReplicatedStorage.Modules)

⸻

loader.load_descendants(container: Instance, predicate?: (Instance) -> boolean): Promise<boolean>

Loads all ModuleScripts found recursively in the container’s descendants.

Loader:load_descendants(game.ServerScriptService.Services)

⸻

loader.exposeInternal(): internal

Reveals internal utilities for advanced use or debugging.

local internal = Loader.exposeInternal()
internal.change_env_const("USE_FULL_NAME", true)

⸻

🔧 Internal API (via exposeInternal())

Logging

log.print(msg: string)
log.warn(msg: string)
log.error(msg: string)

Configuration

change_env_const(key: "LOGGING_ENABLED" | "LOGGING_PREFIX" | "USE_FULL_NAME", value: any)

Module Tools

getInstanceName(instance: Instance): string
waitFor(moduleName: string): Promise
safeRequire(moduleScript: ModuleScript): Promise

⸻

✅ Best Practices
• ✅ Use init() for setup and start() for logic execution.
• ✅ Use waitFor() to ensure dependent modules are ready.
• ❌ Avoid require() chaining that assumes a module is ready immediately.
• ❌ Don’t rely on circular module dependencies.
• ✅ Use loader.load_descendants(...) during game bootstrap from a central “Modules” folder.

⸻

📁 Example Module

-- PlayerService.lua

local PlayerService = {}

function PlayerService.init()
print("PlayerService initializing...")
end

function PlayerService.start()
print("PlayerService starting...")
end

return PlayerService

⸻

🧪 Example Bootstrap

local Loader = require(script.Parent.Loader)

Loader:load_descendants(game.ServerScriptService.Modules):andThen(function()
print("All modules loaded and started.")
end)
