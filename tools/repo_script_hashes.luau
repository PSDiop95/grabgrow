-- Empreintes des scripts du dépôt, selon le mappage de default.project.json.
-- À comparer avec tools/studio/place_script_hashes.luau (même format).
-- Usage : lune run tools/repo_script_hashes.luau

local fs = require("@lune/fs")

local ROOTS = {
	{ "src/ReplicatedStorage/Shared", "ReplicatedStorage.Shared" },
	{ "src/ServerScriptService", "ServerScriptService" },
	{ "src/ServerStorage/ServerOnlyConfig", "ServerStorage.ServerOnlyConfig" },
	{ "src/StarterPlayer/StarterPlayerScripts", "StarterPlayer.StarterPlayerScripts" },
}

local function digest(source: string): (number, number)
	source = string.gsub(source, "\r\n", "\n")
	local h = 5381
	for i = 1, #source do
		h = (h * 33 + string.byte(source, i)) % 4294967296
	end
	return #source, h
end

local lines = {}
local function walk(dir: string, prefix: string)
	for _, name in ipairs(fs.readDir(dir)) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			walk(path, `{prefix}.{name}`)
		elseif string.match(name, "%.lua$") then
			local base = string.gsub(string.gsub(name, "%.lua$", ""), "%.server$", "")
			base = string.gsub(base, "%.client$", "")
			local size, h = digest(fs.readFile(path))
			table.insert(lines, `{prefix}.{base}|{size}|{h}`)
		end
	end
end

for _, root in ipairs(ROOTS) do
	walk(root[1], root[2])
end
table.sort(lines)
print(table.concat(lines, "\n"))
