--!strict
-- Crédits des assets tiers affichés en jeu (anomalie A-4, option C validée
-- le 2026-11-23 : panneau en jeu + ligne courte dans la description).
--
-- Source : docs/assets/ASSET_MANIFEST.md (colonne « attribution »). Les
-- 20 meshes Polyfork des ressources sont sous CC BY 4.0 et tous modifiés.
-- Toute ligne ajoutée ou retirée du manifeste doit l'être ici aussi.
-- Données d'affichage seulement : aucune règle de jeu.

export type Credit = {
	title: string,
	-- Identifiant de la fiche : https://polyfork.dev/asset/<slug>.
	slug: string,
}

local CreditsConfig = {}

CreditsConfig.Author = "Polyfork"
CreditsConfig.License = "CC BY 4.0"
CreditsConfig.UrlPrefix = "https://polyfork.dev/asset/"

-- Ordre alphabétique des titres (affichage).
CreditsConfig.Models = table.freeze({
	{ title = "Amethyst Ore Deposit", slug = "amethyst-ore-deposit-02d55d" },
	{ title = "Apple", slug = "apple-b15012" },
	{ title = "Boulder Field Cluster", slug = "boulder-field-cluster-08e364" },
	{ title = "Copper Ore Deposit", slug = "copper-ore-deposit-d5e58b" },
	{ title = "Crystal Shard", slug = "crystal-shard-9e0a83" },
	{ title = "Divination Orb", slug = "divination-orb-115d77" },
	{ title = "Emerald Ore Deposit", slug = "emerald-ore-deposit-4f0566" },
	{ title = "Fallen Log", slug = "fallen-log-1685fb" },
	{ title = "Fallen Oak Leaf", slug = "fallen-oak-leaf-5b15fe" },
	{ title = "Fossil Ribcage", slug = "fossil-ribcage-b243c5" },
	{ title = "Gem Chip Heap", slug = "gem-chip-heap-573355" },
	{ title = "Geode Boulder", slug = "geode-boulder-e8091d" },
	{ title = "Glowing Crystal Cluster", slug = "lair-crystal-column-877d1a" },
	{ title = "Gold Nugget", slug = "gold-nugget-ccd143" },
	{ title = "Medium Rock", slug = "medium-rock-e08405" },
	{ title = "Meteorite", slug = "meteorite-c400d9" },
	{ title = "Rough Diamond", slug = "rough-diamond-fecf28" },
	{ title = "Sandstone Outcrop", slug = "sandstone-outcrop-75800b" },
	{ title = "Sapphire Ore Deposit", slug = "sapphire-ore-deposit-f8a71a" },
	{ title = "Silver Ore Deposit", slug = "silver-ore-deposit-57f7c3" },
} :: { Credit })

-- Ligne d'attribution, au format de la fiche Polyfork :
-- « <Titre> by Polyfork (<URL>), CC BY 4.0 ».
function CreditsConfig.line(credit: Credit): string
	return `{credit.title} by {CreditsConfig.Author} ({CreditsConfig.UrlPrefix}{credit.slug}), {CreditsConfig.License}`
end

function CreditsConfig.lines(): { string }
	local result = table.create(#CreditsConfig.Models)
	for _, credit in ipairs(CreditsConfig.Models) do
		table.insert(result, CreditsConfig.line(credit))
	end
	return result
end

return CreditsConfig
