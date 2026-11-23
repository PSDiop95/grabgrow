-- Empreintes des scripts du place ouvert dans Studio (mode Edit), à comparer
-- avec `lune run tools/repo_script_hashes.luau` avant toute publication.
-- Lecture seule. Format : <chemin>|<octets>|<djb2>, fins de ligne en LF.
-- Un chemin en double ou absent d'un côté signale un place non synchronisé.

local roots = {
	game.ReplicatedStorage:FindFirstChild("Shared"),
	game.ServerScriptService,
	game.ServerStorage:FindFirstChild("ServerOnlyConfig"),
	game.StarterPlayer.StarterPlayerScripts,
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
for _, root in ipairs(roots) do
	if root then
		for _, item in ipairs(root:GetDescendants()) do
			if item:IsA("LuaSourceContainer") then
				local size, h = digest((item :: any).Source)
				table.insert(lines, `{item:GetFullName()}|{size}|{h}`)
				task.wait()
			end
		end
	end
end
table.sort(lines)
return table.concat(lines, "\n")
