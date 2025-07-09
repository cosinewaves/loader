--!strict

export type envConstants = "LOGGING_ENABLED" | "LOGGING_PREFIX" | "USE_FULL_NAME"
export type predicate<T> = (T) -> boolean
export type lifecycleModule = {
	init: (() -> any)?,
	start: (() -> any)?,
	waitFor: ((moduleName: string) -> any)?,
	[string]: any,
}
export type loader = {
	load_children: (container: Instance, predicate: predicate<Instance>?) -> any,
	load_descendants: (container: Instance, predicate: predicate<Instance>?) -> any,
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

return nil
