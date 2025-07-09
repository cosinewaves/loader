--!strict

local types = require("./types")

--[=[
	@class internal

	The `internal` class contains core utility functions, configurations, and lifecycle mechanisms
	used internally by the loader. These include logging tools, safe module requiring with lifecycle
	method execution (`init`, `start`), environment setting overrides, module tracking, and dependency
	waiting. This class is exposed through `loader.exposeInternal()` for advanced use cases such as 
	debugging, testing, or extending the loader’s behavior.
]=]
local internal = {} :: types.internal
internal.log = {} :: types.log

return internal
