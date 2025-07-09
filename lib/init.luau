--!strict
--!optimize 2

local promise = require("./packages/promise")

--[=[
	@class loader

	a lightweight, lifecycle-aware & promise-based module loader for roblox. designed for modular architecture, dependency safety, and async initialisation.
]=]
local loader = {} :: loader

--[=[
	Loads child modules of a given container, applying an optional filter predicate.

	@method load_children
	@within loader
	@param container Instance -- the container whose children modules to load
	@param predicate predicate<Instance>? -- optional filter to select which modules to load
	@return any -- a promise resolving when all modules and their starts complete
]=]
loader.load_children = function(self: loader, container: Instance, predicate: predicate<Instance>?): any
	return internal.load_modules(container, false, predicate) :: any
end

--[=[
	Loads descendant modules of a given container, applying an optional filter predicate.

	@method load_descendants
	@within loader
	@param container Instance -- the container whose descendant modules to load
	@param predicate predicate<Instance>? -- optional filter to select which modules to load
	@return any -- a promise resolving when all modules and their starts complete
]=]
loader.load_descendants = function(self: loader, container: Instance, predicate: predicate<Instance>?): any
	return internal.load_modules(container, true, predicate) :: any
end

--[=[
	Exposes the internal utility class, granting access to core loader functions and configuration.

	@within loader
	@return internal -- the internal helper and configuration object
]=]
loader.exposeInternal = function(): internal
	return internal :: internal
end

return loader :: loader
