--!strict
--!optimize 2

local core = require("@self/core")
local types = require("@self/types")

export type envConstants = types.envConstants
export type predicate<T> = types.predicate<T>
export type lifecycleModule = types.lifecycleModule
export type loader = types.loader
export type log = types.log
export type internal = types.internal

return core.load_children
