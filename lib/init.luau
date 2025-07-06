--!strict
--!optimize 2

-- requirements
local promise = require("./packages/promise")

-- types
export type envConstants = "LOGGING_ENABLED" | "LOGGING_PREFIX" | "USE_FULL_NAME"
export type predicate<T> = (T) -> boolean
export type lifecycleModule = {
	init: (() -> any)?,
	start: (() -> any)?,
	waitFor: ((moduleName: string) -> any)?,
	[string]: any,
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

--[=[
	@class loader

	a lightweight, lifecycle-aware & promise-based module loader for roblox. designed for modular architecture, dependency safety, and async initialisation.
]=]
local loader = {} :: loader

--[=[
	@class internal

	internal functions and properties, accessible by exposure
]=]
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
		if not LOGGING_ENABLED then
			return
		end
		print(LOGGING_PREFIX .. msg)
	end,

	warn = function(msg: string): ()
		if not LOGGING_ENABLED then
			return
		end
		warn(LOGGING_PREFIX .. msg)
	end,

	error = function(msg: string): ()
		if not LOGGING_ENABLED then
			return
		end
		error(LOGGING_PREFIX .. msg)
	end,
}

-- get instance name or fullname
-- i lowkey implemented this cause i didn't want to print the whole
-- path name, however it could see useful in debug purposes

--[=[
	formats the instance's name, used for debug purposes

	@within internal
	@param instance instance -- the instance to find the name of
	@return number -- formatted name
]=]
internal.getInstanceName = function(instance: Instance): string
	return USE_FULL_NAME and instance:GetFullName() or instance.Name
end

--[=[
	change the loader's constants, used to modify the behaviour of loader at runtime

	@within internal
	@param envConstant envConstants -- "LOGGING_ENABLED" | "LOGGING_PREFIX" | "USE_FULL_NAME"
	@param newValue any
	@return ()
]=]
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

--[=[
	wait for a module to be loaded, then you can use promise methods, like ':andThen()' to do stuff in your module

	@within loader
	@param name string 
	@return any
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

-- safely require + run lifecycle methods

--[=[
	safely require and run lifecycle methods

	@within internal
	@param module ModuleScript 
	@return any
]=]
internal.safeRequire = function(module: ModuleScript): any
	local moduleName: string = internal.getInstanceName(module)
	return promise.new(function(resolve, reject)
		local ok: boolean, result: any = pcall(require, module)
		if not ok :: boolean then
			internal.log.warn(`failed to require {moduleName}: {result}`)
			reject(result)
			return
		end

		internal.log.print(`required module: {moduleName}`)
		local mod: lifecycleModule = result
		loadedModules[moduleName] = mod :: lifecycleModule

		-- add waitFor to module so they can call it internally
		mod.waitFor = internal.waitFor

		-- init lifecycle
		local initOk: boolean, initErr: boolean = true, nil
		if typeof(mod.init) == "function" then
			internal.log.print(`calling init on {moduleName}`)
			initOk, initErr = pcall(mod.init)
			if not initOk :: boolean then
				internal.log.warn(`init failed for {moduleName}: {initErr}`)
			end
		end

		-- prepare start promise but don't run yet
		startedPromises[moduleName] = promise.new(function(startResolve)
			if typeof(mod.start) == "function" then
				internal.log.print(`calling start on {moduleName}`)
				local success: boolean, err: any = pcall(mod.start)
				if not success :: boolean then
					internal.log.warn(`start failed for {moduleName}: {err}`)
					return
				end
			end
			startResolve(true)
			return
		end)

		resolve(mod)
		return
	end) :: any
end

--[=[
	internal module loader function

	@within loader
	@param container Instance
	@param useDescendants boolean
	@param predicate predicate<Instance>? 
	@return any
]=]
internal.load_modules = function(container: Instance, useDescendants: boolean, predicate: predicate<Instance>?): any
	local containerName: string = internal.getInstanceName(container)
	internal.log.print(`{if useDescendants then "loading descendants" else "loading children"} in {containerName}`)

	local t0: number = os.clock()
	local instances: { Instance } = if useDescendants then container:GetDescendants() else container:GetChildren()
	local filtered: { ModuleScript } = {}

	for _: number, inst: Instance in ipairs(instances :: { Instance }) do
		if inst:IsA("ModuleScript") and (not predicate or predicate(inst :: Instance)) then
			table.insert(filtered, inst)
		end
	end

	local moduleCount: number = #filtered
	local promises: { any } = {}
	for _: number, moduleScript: ModuleScript in ipairs(filtered :: { ModuleScript }) do
		table.insert(promises, internal.safeRequire(moduleScript :: ModuleScript))
	end

	return promise
		.all(promises)
		:andThen(function()
			return promise.all(startedPromises) :: any
		end)
		:andThen(function()
			if LOGGING_ENABLED :: boolean then
				local elapsed: number = (os.clock() - t0) * 1000
				internal.log.print(`successfully loaded {moduleCount} modules in {string.format("%.2f", elapsed)}ms`)
			end
			return true
		end)
		:catch(function(err)
			internal.log.warn(`failed to load one or more modules from {containerName}: {err}`)
			return false
		end) :: any
end

loader.load_children = function(self: loader, container: Instance, predicate: predicate<Instance>?): any
	return internal.load_modules(container, false, predicate) :: any
end

loader.load_descendants = function(self: loader, container: Instance, predicate: predicate<Instance>?): any
	return internal.load_modules(container, true, predicate) :: any
end

-- expose internal functions
loader.exposeInternal = function(): internal
	return internal :: internal
end

return loader :: loader
