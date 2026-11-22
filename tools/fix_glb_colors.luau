--!nocheck
-- Correction des couleurs de sommets des GLB Polyfork (T10.1, risque R1).
-- Usage (racine du dépôt) : lune run tools/fix_glb_colors.luau
--
-- Outil de développement : absent du jeu (non mappé dans
-- default.project.json). Lit assets_src/polyfork/<id>.glb et écrit
-- assets_src/polyfork/fixed/<id>.glb (dossier ignoré par Git, D-026). Les
-- fichiers source ne sont jamais modifiés.
--
-- Constat T10.1 : glTF stocke COLOR_0 en linéaire ; l'import Roblox les lit
-- comme du sRGB, d'où des modèles bien trop sombres. Le script convertit
-- chaque couleur de sommet linéaire -> sRGB (courbe sRGB standard), en
-- place dans le bloc binaire : JSON, géométrie et taille du fichier
-- inchangés. Chaque accesseur n'est converti qu'une fois (l'améthyste
-- partage le sien entre deux primitives).
--
-- Recoloration (modification documentée dans ASSET_MANIFEST.md, CC BY 4.0
-- « modifié ») : la feuille, rousse à l'origine, passe au vert de Green
-- Valley. Correspondance par couleur source (linéaire, arrondie à 0,01) ->
-- couleur cible sRGB 0..255. Palette contrastée avec l'herbe de Green
-- Valley (116, 178, 92) : limbe vert-jaune clair, bord vert très foncé
-- (décision du propriétaire, 2026-11-22 ; hypothèse visuelle à valider).

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local SOURCE_DIR = "assets_src/polyfork"
local OUTPUT_DIR = "assets_src/polyfork/fixed"

local RECOLOR = {
	["fallen-oak-leaf-5b15fe"] = {
		["0.37,0.03,0.05"] = { 214, 232, 76 }, -- rouge -> limbe
		["0.47,0.15,0.06"] = { 176, 214, 52 }, -- orange -> taches
		["0.55,0.36,0.17"] = { 250, 250, 196 }, -- beige -> nervures
		["0.18,0.21,0.07"] = { 40, 98, 30 }, -- olive -> bord
	},
}

local FILES = {
	"fallen-oak-leaf-5b15fe",
	"copper-ore-deposit-d5e58b",
	"silver-ore-deposit-57f7c3",
	"amethyst-ore-deposit-02d55d",
}

local GLB_MAGIC = 0x46546C67 -- "glTF"
local CHUNK_JSON = 0x4E4F534A
local CHUNK_BIN = 0x004E4942

local COMPONENT = {
	[5126] = { size = 4, max = 1 }, -- FLOAT
	[5121] = { size = 1, max = 255 }, -- UNSIGNED_BYTE normalisé
	[5123] = { size = 2, max = 65535 }, -- UNSIGNED_SHORT normalisé
}

local function linearToSrgb(c: number): number
	c = math.clamp(c, 0, 1)
	if c <= 0.0031308 then
		return 12.92 * c
	end
	return 1.055 * c ^ (1 / 2.4) - 0.055
end

local function readComponent(buf: buffer, offset: number, componentType: number): number
	if componentType == 5126 then
		return buffer.readf32(buf, offset)
	elseif componentType == 5121 then
		return buffer.readu8(buf, offset) / 255
	end
	return buffer.readu16(buf, offset) / 65535
end

local function writeComponent(buf: buffer, offset: number, componentType: number, value: number)
	value = math.clamp(value, 0, 1)
	if componentType == 5126 then
		buffer.writef32(buf, offset, value)
	elseif componentType == 5121 then
		buffer.writeu8(buf, offset, math.floor(value * 255 + 0.5))
	else
		buffer.writeu16(buf, offset, math.floor(value * 65535 + 0.5))
	end
end

local function key(r: number, g: number, b: number): string
	local function round(x: number): string
		return string.format("%.2f", math.floor(x * 100 + 0.5) / 100)
	end
	return `{tonumber(round(r))},{tonumber(round(g))},{tonumber(round(b))}`
end

local function fixFile(id: string)
	local source = fs.readFile(`{SOURCE_DIR}/{id}.glb`)
	local buf = buffer.fromstring(source)
	assert(buffer.readu32(buf, 0) == GLB_MAGIC, `{id} : pas un GLB`)
	local jsonLength = buffer.readu32(buf, 12)
	assert(buffer.readu32(buf, 16) == CHUNK_JSON, `{id} : bloc JSON attendu`)
	local gltf = serde.decode("json", buffer.readstring(buf, 20, jsonLength))
	local binHeader = 20 + jsonLength
	assert(buffer.readu32(buf, binHeader + 4) == CHUNK_BIN, `{id} : bloc BIN attendu`)
	local binStart = binHeader + 8

	local recolor = RECOLOR[id]
	local done = {}
	local converted, recolored, unmatched = 0, 0, {}
	for _, mesh in ipairs(gltf.meshes) do
		for _, primitive in ipairs(mesh.primitives) do
			local accessorIndex = primitive.attributes.COLOR_0
			if accessorIndex == nil or done[accessorIndex] then
				continue
			end
			done[accessorIndex] = true
			local accessor = gltf.accessors[accessorIndex + 1]
			local view = gltf.bufferViews[accessor.bufferView + 1]
			local component = assert(COMPONENT[accessor.componentType], `{id} : type de composante non géré`)
			local comps = if accessor.type == "VEC4" then 4 else 3
			local stride = view.byteStride or comps * component.size
			local base = binStart + (view.byteOffset or 0) + (accessor.byteOffset or 0)
			for index = 0, accessor.count - 1 do
				local offset = base + index * stride
				local r = readComponent(buf, offset, accessor.componentType)
				local g = readComponent(buf, offset + component.size, accessor.componentType)
				local b = readComponent(buf, offset + 2 * component.size, accessor.componentType)
				local target = if recolor then recolor[key(r, g, b)] else nil
				local out
				if target then
					-- Cible déjà en sRGB 0..255.
					out = { target[1] / 255, target[2] / 255, target[3] / 255 }
					recolored += 1
				else
					if recolor then
						unmatched[key(r, g, b)] = true
					end
					out = { linearToSrgb(r), linearToSrgb(g), linearToSrgb(b) }
				end
				for c = 1, 3 do
					writeComponent(buf, offset + (c - 1) * component.size, accessor.componentType, out[c])
				end
				converted += 1
			end
		end
	end
	assert(next(unmatched) == nil, `{id} : couleurs sans correspondance de recoloration`)
	fs.writeFile(`{OUTPUT_DIR}/{id}.glb`, buffer.tostring(buf))
	print(`[fix_glb_colors] {id} : {converted} sommets convertis, {recolored} recolorés -> {OUTPUT_DIR}/{id}.glb`)
end

if not fs.isDir(OUTPUT_DIR) then
	fs.writeDir(OUTPUT_DIR)
end
for _, id in ipairs(FILES) do
	fixFile(id)
end
