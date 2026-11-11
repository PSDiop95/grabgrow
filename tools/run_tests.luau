--!nocheck
-- Lance Tests/RunTests.server.lua hors de Roblox Studio, avec Lune.
-- Usage (racine du dépôt) : lune run tools/run_tests.luau
--
-- Outil de développement : absent du jeu (non mappé dans
-- default.project.json). Il simule le strict nécessaire de l'API Roblox
-- pour charger les modules de logique pure :
--   * `game:GetService(nom)` -> dossier src/<nom> ;
--   * `script`, `.Parent`, accès aux enfants, `WaitForChild` ;
--   * `require(instance)` avec cache par module ;
--   * RunService:IsStudio() = true.
-- Rien d'autre n'existe (ni Players, ni DataStoreService, ni task) : un
-- module qui en dépend échoue ici et doit être testé dans Studio.
--
-- Code de sortie : 0 si aucun avertissement, 1 sinon.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local SOURCE_ROOT = "src"
local ENTRY = { "ServerScriptService", "Tests", "RunTests" }

local moduleCache = {}
local warnings = 0

-- L'arborescence est lue une fois au démarrage : Lune interdit les appels
-- de fichiers depuis une métaméthode.
local function newInstance(path: string, name: string, parent: any): any
	local children = {}
	local source: string? = nil
	local instance
	instance = setmetatable({}, {
		__index = function(_, key)
			if key == "Name" then
				return name
			elseif key == "Parent" then
				return parent
			elseif key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, childName: string)
					return children[childName]
				end
			elseif key == "IsStudio" then
				return function()
					return true
				end
			end
			local child = children[key]
			if child == nil then
				error(`{tostring(key)} n'est pas un enfant de {path}`, 2)
			end
			return child
		end,
	})

	if string.sub(path, 1, 1) == "<" then
		-- Service simulé sans fichier.
	elseif fs.isDir(path) then
		for _, entryName in fs.readDir(path) do
			local childPath = `{path}/{entryName}`
			local childName = entryName
			if fs.isFile(childPath) then
				childName = string.gsub(entryName, "%.luau?$", "")
				childName = string.gsub(childName, "%.server$", "")
			end
			children[childName] = newInstance(childPath, childName, instance)
		end
	elseif fs.isFile(path) then
		source = fs.readFile(path)
	end

	rawset(instance, "__path", path)
	rawset(instance, "__source", source)
	return instance
end

local services = {}
for _, serviceName in fs.readDir(SOURCE_ROOT) do
	services[serviceName] = newInstance(`{SOURCE_ROOT}/{serviceName}`, serviceName, nil)
end
services.RunService = newInstance("<RunService>", "RunService", nil)

local game = {}
function game:GetService(serviceName: string)
	local service = services[serviceName]
	if service == nil then
		error(`service {serviceName} non simulé par tools/run_tests.luau`, 2)
	end
	return service
end

local function trackedWarn(...)
	warnings += 1
	warn(...)
end

local run

local function requireInstance(instance: any): any
	local path = rawget(instance, "__path")
	if path == nil then
		error("require : instance attendue", 2)
	end
	local cached = moduleCache[path]
	if cached then
		return cached.value
	end
	local value = run(instance)
	moduleCache[path] = { value = value }
	return value
end

function run(instance: any): any
	local path = rawget(instance, "__path")
	local chunk = luau.load(rawget(instance, "__source"), {
		debugName = path,
		environment = {
			game = game,
			script = instance,
			require = requireInstance,
			warn = trackedWarn,
		},
	})
	return chunk()
end

local entry = game:GetService(ENTRY[1])
for index = 2, #ENTRY do
	entry = entry[ENTRY[index]]
end
run(entry)

if warnings > 0 then
	print(`[run_tests] {warnings} avertissement(s)`)
	process.exit(1)
end
