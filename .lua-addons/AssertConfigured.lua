---@meta

---@class LuaDictionary
---@field [string] any

---@class LuaArray
---@field [integer] any

---@alias StringIndexable
---| table
---| LuaDictionary

---@alias Indexable
---| table
---| LuaDictionary
---| LuaArray

---@class LuaEnumerator
LuaEnumerator = {}

---@return boolean
function LuaEnumerator:moveNext() end

---@class LuaStringEnumerator : LuaEnumerator
LuaStringEnumerator = {}

---@return string, any
function LuaStringEnumerator:unpackCurrent() end

---@class LuaIntegerEnumerator : LuaEnumerator
LuaIntegerEnumerator = {}

---@return integer, any
function LuaIntegerEnumerator:unpackCurrent() end

---@class LuaAnyEnumerator : LuaEnumerator
LuaAnyEnumerator = {}

---@return any, any
function LuaAnyEnumerator:unpackCurrent() end

---@type StringIndexable
current = {}

---@type StringIndexable
chezmoi = {}

---@class ConfigLoadSettings
ConfigLoadSettings = {}

---@alias Encoding
---| "'utf8'"
---| "'utf8-bom'"
---| "'oem'"
---| "'utf32'"
---| "'utf32-bom'"
---| "'utf32-be'"
---| "'utf32-be-bom'"
---| "'ansi'"
---| "'ascii'"
---| "'utf16'"
---| "'utf16-bom'"
---| "'utf16-be'"
---| "'utf16-be-bom'"

---@return ConfigLoadSettings
---@param name Encoding Fallback encoding if the source file encoding cannot be determined. Defaults to utf8 no BOM.
function ConfigLoadSettings:withEncoding(name) end

---@return ConfigLoadSettings
---@param value integer
function ConfigLoadSettings:withMaxDepth(value) end

---@return ConfigLoadSettings
function ConfigLoadSettings:skipValidation() end

---@class AssertConfiguredSettings: ConfigLoadSettings
AssertConfiguredSettings = {}

---@type AssertConfiguredSettings
settings = {}

---@return AssertConfiguredSettings
function AssertConfiguredSettings:useLf() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:useCrLf() end

---@alias ConfigurationFormat
---| "lua"
---| "json"

---@return AssertConfiguredSettings
---@param name Encoding Fallback encoding if the source file encoding cannot be determined. Defaults to utf8 no BOM.
function AssertConfiguredSettings:withEncoding(name) end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:compressed() end

---@return AssertConfiguredSettings
---@param value integer
function AssertConfiguredSettings:withIndentSize(value) end

---@return AssertConfiguredSettings
---@param value string A string with a single character that will be used to indent the result configuration file.
function AssertConfiguredSettings:withIndentCharacter(value) end

---@return AssertConfiguredSettings
---@param value string The string that should be used when appending a new line to the result configuration file.
function AssertConfiguredSettings:withNewLine(value) end

---@return AssertConfiguredSettings
---@param value integer
function AssertConfiguredSettings:withMaxDepth(value) end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:skipValidation() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:loadChezmoiConfig() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:addFinalNewLine() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:loadAllLibs() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:loadBasicLib() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:loadBitwiseLib() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:loadCoroutineLib() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:loadIOLib() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:loadMathLib() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:loadModuleLib() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:loadOperatingSystemLib() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:loadStringLib() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:loadTableLib() end

---@return AssertConfiguredSettings
function AssertConfiguredSettings:clone() end

---@param source StringIndexable
---@param destination StringIndexable
---@param settings CopyKeysSettings?
function copyKeys(source, destination, settings) end

---@class CopyKeysSettings
---@field keysToExclude string[]?
---@field skipMissing boolean?

---@param source Indexable
---@param destination Indexable
---@param idKey string
---@param settings UpdateEntriesSettings?
function updateEntries(source, destination, idKey, settings) end

---@class UpdateEntriesSettings
---@field keysToExclude string[]?
---@field skipMissing boolean?

---@param target StringIndexable
---@param path string
---@return any
function ensureObjPath(target, path) end

---@generic T
---@param target StringIndexable
---@param path string
---@param value `T`
---@return T
function setObjPath(target, path, value) end

---@param source LuaArray
---@return LuaIntegerEnumerator
---@overload fun(source: LuaDictionary): LuaStringEnumerator
---@overload fun(source: table): LuaAnyEnumerator
function enumerate(source) end

---@param part1 string
---@param ... string
---@return string
function joinPath(part1, ...) end

---@param source Indexable
---@param keyFactory (fun(key: any, value: any): string) | string
---@param valueFactory (fun(key: any, value: any): string) | string | nil
---@return LuaDictionary
function toDict(source, keyFactory, valueFactory) end

---@param source StringIndexable
---@param key string
---@return boolean
function containsKey(source, key) end

---@param source StringIndexable
---@param key string
function removeKey(source, key) end

---@param source LuaArray
---@param item any
function addItem(source, item) end

---@param source LuaArray
---@param index integer
function removeAt(source, index) end

---@param capacity integer?
---@return LuaDictionary
function newDict(capacity) end

---@param source LuaArray | table
---@return LuaArray
function toArray(source) end

---@param ... any Items
---@return LuaArray
function newArray(...) end

---@return ConfigLoadSettings
---@param name Encoding
function loadConfigSettings(name) end

---@class LoadConfigParams
---@field encoding Encoding?
---@field format ConfigurationFormat?
LoadConfigParams = {}

---@param path string
---@param format ConfigurationFormat
---@param settings AssertConfiguredSettings
---@return LuaDictionary | LuaArray
---@overload fun(path: string, format: ConfigurationFormat): LuaDictionary | LuaArray
---@overload fun(path: string, settings: ConfigLoadSettings): LuaDictionary | LuaArray
---@overload fun(path: string, args: LoadConfigParams): LuaDictionary | LuaArray
---@overload fun(path: string): LuaDictionary | LuaArray
function loadConfig(path, format, settings) end
