--!strict

local types = require("./types")
local promise = require("../packages/promise")
local lifecycles = require("./lifecycles")

local LOGGING_ENABLED: boolean = true
local LOGGING_PREFIX: string = `({script.Name}::internal) `
local USE_FULL_NAME: boolean = false

local startedPromises: { [string]: any } = {}

--[=[
	@class internal

	The `internal` class contains core utility functions, configurations, and lifecycle mechanisms
	used internally by the loader. These include logging tools, safe module requiring with lifecycle
	method execution (`init`, `start`), environment setting overrides, module tracking, and dependency
	waiting.
]=]
local internal = {} :: types.internal
internal.log = {} :: types.log

--[=[
	Prints a formatted message to the output console if logging is enabled.

	@within internal
	@param msg string -- the message to print
	@return ()
]=]
function internal.log.print(msg: string): ()
	if not LOGGING_ENABLED then
		return
	end
	print(LOGGING_PREFIX .. msg)
end

--[=[
	Sends a formatted warning message to the output console if logging is enabled.

	@within internal
	@param msg string -- the warning message to display
	@return ()
]=]
function internal.log.warn(msg: string): ()
	if not LOGGING_ENABLED then
		return
	end
	warn(LOGGING_PREFIX .. msg)
end

--[=[
	Raises a formatted error message and halts execution if logging is enabled.

	@within internal
	@param msg string -- the error message to raise
	@return ()
]=]
function internal.log.error(msg: string): ()
	if not LOGGING_ENABLED then
		return
	end
	error(LOGGING_PREFIX .. msg)
end

--[=[
	Returns a formatted name for the given instance, used primarily for logging and debugging.

	@within internal
	@param instance Instance -- the instance whose name or full name will be returned
	@return string -- the formatted name (either `Name` or `FullName` depending on config)
]=]
internal.getInstanceName = function(instance: Instance): string
	return USE_FULL_NAME and instance:GetFullName() or instance.Name
end

--[=[
	Dynamically updates one of the loader’s runtime configuration constants.

	This allows toggling logging, changing the log prefix, or switching between 
	instance names and full names in debug output.

	@within internal
	@param envConstant envConstants -- one of "LOGGING_ENABLED", "LOGGING_PREFIX", or "USE_FULL_NAME"
	@param newValue any -- the new value to assign to the selected constant
	@return ()
]=]
internal.change_env_const = function(envConstant: types.envConstants, newValue: any): ()
	if envConstant == "LOGGING_ENABLED" then
		LOGGING_ENABLED = newValue
	elseif envConstant == "LOGGING_PREFIX" then
		LOGGING_PREFIX = newValue
	elseif envConstant == "USE_FULL_NAME" then
		USE_FULL_NAME = newValue
	end
end

--[=[
	Waits for the specified module to finish its `start` lifecycle before continuing.

	Returns a promise that resolves when the target module has completed starting,
	allowing dependent modules to sequence their initialization using methods like `:andThen()`.

	@within internal
	@param name string -- the name of the module to wait for
	@return any -- a resolving or rejecting promise based on module availability
]=]
internal.waitFor = function(name: string): any
	local startPromise: any = startedPromises[name]
	if startPromise :: any then
		return startPromise :: any
	else
		internal.log.warn(`waitFor called for unknown module: {name}`)
		return promise.reject(`no module named {name} has been loaded yet`) :: any
	end
end

--[=[
	Safely requires a module and executes its lifecycle methods (`init` and `start`).

	If the module exports `init`, it is invoked immediately.
	If it exports `start`, a start promise is created and tracked.
	Also injects `waitFor` into the module so it can depend on others.

	@within internal
	@param module ModuleScript -- the module to require and initialize
	@return any -- a promise resolving to the required module
]=]
internal.safeRequire = function(module: ModuleScript): any
	local moduleName = internal.getInstanceName(module)
	return promise.new(function(resolve, reject)
		local ok, result = pcall(require, module)
		if not ok then
			internal.log.warn(`failed to require {moduleName}: {result}`)
			return reject(result)
		end

		internal.log.print(`required module: {moduleName}`)
		local mod = result :: types.lifecycleModule

		-- add waitFor
		local _promises = lifecycles.connect(moduleName, mod, internal.waitFor)

		-- resolve once module is required; start happens asynchronously inside lifecycles.connect
		resolve(mod)
	end)
end

--[=[
	Loads and initializes modules from a specified container, optionally including descendants,
	and filters them using an optional predicate.

	Each module is safely required, its lifecycle methods invoked, and start promises tracked.
	Returns a promise that resolves after all modules and their start routines complete.

	@within internal
	@param container Instance -- the Roblox instance containing modules to load
	@param useDescendants boolean -- whether to include all descendants (true) or only direct children (false)
	@param predicate predicate<Instance>? -- optional filter function to select modules
	@return any -- a promise resolving to true if all modules loaded successfully, false otherwise
]=]
internal.load_modules = function(
	container: Instance,
	useDescendants: boolean,
	predicate: types.predicate<Instance>?
): any
	local containerName: string = internal.getInstanceName(container)
	internal.log.print(`{if useDescendants then "loading descendants" else "loading children"} in {containerName}`)

	local t0: number = os.clock()
	local instances: { Instance } = if useDescendants then container:GetDescendants() else container:GetChildren()
	local filtered: { ModuleScript } = {}

	for _, inst in ipairs(instances) do
		if inst:IsA("ModuleScript") and (not predicate or predicate(inst)) then
			table.insert(filtered, inst)
		end
	end

	local moduleCount = #filtered
	local promises = {}

	for _, moduleScript in ipairs(filtered) do
		table.insert(promises, internal.safeRequire(moduleScript))
	end

	return promise
		.all(promises)
		:andThen(function()
			-- Wait for all modules' "start" lifecycle to complete
			local waitStartPromises = {}
			for _, moduleScript in ipairs(filtered) do
				local name = internal.getInstanceName(moduleScript)
				table.insert(waitStartPromises, lifecycles.waitFor(name, "start"))
			end
			return promise.all(waitStartPromises)
		end)
		:andThen(function()
			if LOGGING_ENABLED :: boolean then
				local elapsed = (os.clock() - t0) * 1000
				internal.log.print(`successfully loaded {moduleCount} modules in {string.format("%.2f", elapsed)}ms`)
			end
			return true
		end)
		:catch(function(err)
			internal.log.warn(`failed to load one or more modules from {containerName}: {err}`)
			return false
		end)
end

return internal
