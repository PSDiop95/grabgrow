--!strict
-- Anneau temporaire de portée du Magnet (A-40), côté client, purement
-- visuel : aucun effet sur la collecte ni sur le serveur.
--
-- Un CylinderHandleAdornment évidé (InnerRadius), attaché au
-- HumanoidRootPart et posé au niveau des pieds : il suit le joueur sans
-- boucle par frame, ne projette pas d'ombre et n'a pas de collision.
-- Affiché RING_SECONDS après un achat réussi, puis détruit. Un nouvel
-- affichage remplace le précédent.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local RangeRing = {}

-- Durée totale (décision du propriétaire : 2 à 3 s), dont l'apparition et
-- la disparition en fondu.
local RING_SECONDS = 2.5
local GROW_SECONDS = 0.25
local FADE_SECONDS = 0.6
-- Épaisseur du trait et hauteur du disque (studs).
local RING_WIDTH = 0.35
local RING_HEIGHT = 0.1
-- Au-dessus du sol, pour éviter le scintillement avec le terrain (studs).
local GROUND_OFFSET = 0.1
local RING_COLOR = Color3.fromRGB(110, 190, 255)
local RING_TRANSPARENCY = 0.25

local localPlayer = Players.LocalPlayer :: Player
local current: CylinderHandleAdornment? = nil

-- Affiche l'anneau de rayon `radius` (studs) autour du joueur local.
-- Sans personnage, ne fait rien.
function RangeRing.show(radius: number)
	if type(radius) ~= "number" or radius <= RING_WIDTH then
		return
	end
	local character = localPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if root == nil or not root:IsA("BasePart") or humanoid == nil then
		return
	end

	if current then
		current:Destroy()
		current = nil
	end

	local feet = root.Size.Y / 2 + humanoid.HipHeight
	local ring = Instance.new("CylinderHandleAdornment")
	ring.Name = "MagnetRangeRing"
	ring.Adornee = root
	-- Axe du cylindre (Z) tourné vers le haut : disque à plat.
	ring.CFrame = CFrame.new(0, -feet + GROUND_OFFSET, 0) * CFrame.Angles(math.rad(90), 0, 0)
	ring.Height = RING_HEIGHT
	ring.Radius = radius * 0.6
	ring.InnerRadius = radius * 0.6 - RING_WIDTH
	ring.Color3 = RING_COLOR
	ring.Transparency = RING_TRANSPARENCY
	ring.AlwaysOnTop = false
	ring.Parent = Workspace.CurrentCamera
	current = ring

	TweenService:Create(ring, TweenInfo.new(GROW_SECONDS, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Radius = radius,
		InnerRadius = radius - RING_WIDTH,
	}):Play()

	task.delay(RING_SECONDS - FADE_SECONDS, function()
		if current ~= ring then
			return
		end
		TweenService:Create(ring, TweenInfo.new(FADE_SECONDS), { Transparency = 1 }):Play()
	end)
	task.delay(RING_SECONDS, function()
		ring:Destroy()
		if current == ring then
			current = nil
		end
	end)
end

return RangeRing
