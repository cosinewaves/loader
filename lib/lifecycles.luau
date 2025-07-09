--!strict

local types = require("./types")
local promise = require("../packages/promise")

--[=[
	@class lifecycles
	
	Handles lifecycle method connections (`init`, `start`, etc.) for modules.
	Supports adding custom lifecycle methods and disconnecting them cleanly.
]=]
local lifecycles = {}

-- Stores all available lifecycle keys to execute and their execution order
local registeredLifecycles: { string } = { "init", "start" }

-- Maps module names to the connected module and its lifecycle promises
local lifecycleMap: {
	[string]: {
		module: types.lifecycleModule,
		promises: { [string]: any },
	},
} = {}

--[=[
	Adds a new lifecycle method name that modules can define and be invoked automatically.
	
	@within lifecycles
	@param name string -- the name of the lifecycle method (e.g., "shutdown")
]=]
function lifecycles.register(name: string)
	if not table.find(registeredLifecycles, name) then
		table.insert(registeredLifecycles, name)
	end
end

--[=[
	Connects and runs all registered lifecycle methods on the given module.
	Returns a table of promises keyed by lifecycle name.
	
	@within lifecycles
	@param name string -- the name of the module (used as key)
	@param module types.lifecycleModule -- the module to connect
	@param waitForFn ((name: string) -> any)? -- optional waitFor function to inject
	@return { [string]: any } -- promises for each lifecycle stage
]=]
function lifecycles.connect(
	name: string,
	module: types.lifecycleModule,
	waitForFn: ((name: string) -> any)?
): { [string]: any }
	local promiseMap: { [string]: any } = {}

	-- Inject waitFor if provided
	if waitForFn then
		module.waitFor = waitForFn
	end

	for _, lifecycleName in ipairs(registeredLifecycles) do
		local method = module[lifecycleName]
		if typeof(method) == "function" then
			-- Wrap each lifecycle method in a promise
			promiseMap[lifecycleName] = promise.new(function(resolve, reject)
				local ok, result = pcall(method)
				if ok then
					resolve(result)
				else
					reject(result)
				end
			end)
		end
	end

	lifecycleMap[name] = {
		module = module,
		promises = promiseMap,
	}

	return promiseMap
end

--[=[
	Disconnects lifecycle promises and cleanup for a given module by name.
	
	@within lifecycles
	@param name string -- the module name to disconnect
]=]
function lifecycles.disconnect(name: string): ()
	lifecycleMap[name] = nil
end

--[=[
	Waits for a specific lifecycle stage (e.g., "start") of a named module.
	
	@within lifecycles
	@param name string -- the module name
	@param lifecycle string -- the lifecycle stage to wait for (e.g., "start")
	@return any -- the associated promise, or rejected promise if missing
]=]
function lifecycles.waitFor(name: string, lifecycle: string): any
	local entry = lifecycleMap[name]
	if not entry then
		return promise.reject(`No module connected with name: {name}`)
	end

	local stagePromise = entry.promises[lifecycle]
	if not stagePromise then
		return promise.reject(`No lifecycle "{lifecycle}" found for module {name}`)
	end

	return stagePromise
end

--[=[
	Returns all registered lifecycle names (in execution order).
	Useful for debugging or adding logic externally.
	
	@within lifecycles
	@return { string } -- list of lifecycle method names
]=]
function lifecycles.getRegistered(): { string }
	return registeredLifecycles
end

return lifecycles
