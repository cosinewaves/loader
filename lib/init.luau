--!strict
--!optimize 2

-- requirements
local promise = require("@self/promise")

-- types
export type envConstants = "LOGGING_ENABLED" | "LOGGING_PREFIX" | "USE_FULL_NAME"
export type predicate<T> = (T) -> boolean
export type lifecycleModule = {
	init: (() -> any)?,
	start: (() -> any)?,
	waitFor: ((moduleName: string) -> any)?,
	[string]: any
}
export type loader = {
	load_children: (self: loader, container: Instance, predicate: predicate<Instance>?) -> any,
	load_descendants: (self: loader, container: Instance, predicate: predicate<Instance>?) -> any,
	exposeInternal: () -> internal,
}
export type log = {
	print: (msg: string) -> (),
	warn: (msg: string) -> (),
	error: (msg: string) -> (),
}
export type internal = {
	log: log,
	safeRequire: (module: ModuleScript) -> any,
	getInstanceName: (instance: Instance) -> string,
	change_env_const: (envConstant: envConstants, newValue: any) -> (),
	waitFor: (name: string) -> any,
	load_modules: (container: Instance, useDescendants: boolean, predicate: predicate<Instance>?) -> any,
}

-- metatables
local loader = {} :: loader
local internal = {} :: internal

-- constants
local LOGGING_ENABLED: boolean = true
local LOGGING_PREFIX: string = `({script.Name}::internal) `
local USE_FULL_NAME: boolean = false

-- module tracking
local loadedModules: { [string]: lifecycleModule } = {}
local startedPromises: { [string]: any } = {}

-- internal logging
internal.log = {
	print = function(msg: string): ()
		if not LOGGING_ENABLED then return end
		print(LOGGING_PREFIX .. msg)
	end,
	warn = function(msg: string): ()
		if not LOGGING_ENABLED then return end
		warn(LOGGING_PREFIX .. msg)
	end,
	error = function(msg: string): ()
		if not LOGGING_ENABLED then return end
		error(LOGGING_PREFIX .. msg)
	end,
}

-- get instance name or fullname
-- i lowkey implemented this cause i didn't want to print the whole
-- path name, however it could see useful in debug purposes
internal.getInstanceName = function(instance: Instance): string
	return USE_FULL_NAME and instance:GetFullName() or instance.Name
end

-- update runtime config
internal.change_env_const = function(envConstant: envConstants, newValue: any): ()
	if envConstant == "LOGGING_ENABLED" then
		LOGGING_ENABLED = newValue
	elseif envConstant == "LOGGING_PREFIX" then
		LOGGING_PREFIX = newValue
	elseif envConstant == "USE_FULL_NAME" then
		USE_FULL_NAME = newValue
	end
end

-- wait for a named module to finish starting;
-- for example, wait for PlayerService to start before starting
-- DataService - as loading data before player has properly
-- been setup will cause errors
internal.waitFor = function(name: string): any
	local startPromise = startedPromises[name]
	if startPromise then
		return startPromise
	else
		internal.log.warn(`waitFor called for unknown module: {name}`)
		return promise.reject(`no module named {name} has been loaded yet`)
	end
end

-- safely require + run lifecycle methods
internal.safeRequire = function(module: ModuleScript): any
	local moduleName: string = internal.getInstanceName(module)
	return promise.new(function(resolve, reject)
		local ok, result = pcall(require, module)
		if not ok then
			internal.log.warn(`failed to require {moduleName}: {result}`)
			reject(result)
			return
		end

		internal.log.print(`required module: {moduleName}`)
		local mod = result :: lifecycleModule
		loadedModules[moduleName] = mod

		-- add waitFor to module so they can call it internally
		mod.waitFor = internal.waitFor

		-- init lifecycle
		local initOk, initErr = true, nil
		if typeof(mod.init) == "function" then
			internal.log.print(`calling init on {moduleName}`)
			initOk, initErr = pcall(mod.init)
			if not initOk then
				internal.log.warn(`init failed for {moduleName}: {initErr}`)
			end
		end

		-- prepare start promise but don't run yet
		startedPromises[moduleName] = promise.new(function(startResolve)
			if typeof(mod.start) == "function" then
				internal.log.print(`calling start on {moduleName}`)
				local success, err = pcall(mod.start)
				if not success then
					internal.log.warn(`start failed for {moduleName}: {err}`)
				end
			end
			startResolve(true)
		end)

		resolve(mod)
	end)
end


-- internal shared module loader
internal.load_modules = function(container: Instance, useDescendants: boolean, predicate: predicate<Instance>?): any
	local containerName = internal.getInstanceName(container)
	internal.log.print(`{if useDescendants then "loading descendants" else "loading children"} in {containerName}`)

	local t0 = os.clock()
	local instances = if useDescendants then container:GetDescendants() else container:GetChildren()
	local filtered = {}

	for _, inst in ipairs(instances) do
		if inst:IsA("ModuleScript") and (not predicate or predicate(inst)) then
			table.insert(filtered, inst)
		end
	end

	local moduleCount = #filtered
	local promises = {}
	for _, moduleScript in ipairs(filtered) do
		table.insert(promises, internal.safeRequire(moduleScript :: ModuleScript))
	end

	return promise.all(promises)
		:andThen(function()
			return promise.all(startedPromises)
		end)
		:andThen(function()
			if LOGGING_ENABLED then
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

loader.load_children = function(self: loader, container: Instance, predicate: predicate<Instance>?): any
	return internal.load_modules(container, false, predicate)
end

loader.load_descendants = function(self: loader, container: Instance, predicate: predicate<Instance>?): any
	return internal.load_modules(container, true, predicate)
end

-- expose internal functions
loader.exposeInternal = function(): internal
	return internal
end

return loader :: loader