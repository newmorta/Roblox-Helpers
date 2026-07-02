-- Services Roblox
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- Variables
local camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

local EspHarkening = {}
local Drawings = {}
local Connections = {}

-- Listas de filtrado
local Whitelist = {} -- UserIds o nombres de jugadores a mostrar SIEMPRE
local Blacklist = {} -- UserIds o nombres de jugadores a NUNCA mostrar
local TargetTeams = {} -- Nombres de equipos específicos a mostrar
local IgnoreTeams = {} -- Nombres de equipos a ignorar

local Colors = {
	Enemy = Color3.fromRGB(255, 25, 25),
	Ally = Color3.fromRGB(25, 255, 25),
	Neutral = Color3.fromRGB(255, 255, 255),
	Selected = Color3.fromRGB(255, 210, 0),
	Health = Color3.fromRGB(0, 255, 0),
	Distance = Color3.fromRGB(200, 200, 200),
	Rainbow = nil,
	Target = Color3.fromRGB(255, 0, 255), -- Color para targets específicos
	Friend = Color3.fromRGB(0, 150, 255) -- Color para amigos
}

local Settings = {
	Enabled = false,
	
	-- Modos de TeamCheck: "Off", "Standard", "Specific", "Whitelist", "Blacklist"
	TeamCheckMode = "Standard",
	
	-- Standard: Solo enemigos (diferente equipo)
	TeamCheck = false,
	ShowTeam = false, -- Mostrar aliados del mismo equipo
	
	-- Specific Teams: Mostrar solo estos equipos
	TargetSpecificTeams = false,
	
	-- Whitelist/Blacklist
	UseWhitelist = false,
	UseBlacklist = false,
	
	-- Prioridad: Whitelist > Blacklist > TeamCheck
	
	VisibilityCheck = true,
	BoxESP = false,
	BoxStyle = "Corner",
	BoxOutline = true,
	BoxFilled = false,
	BoxFillTransparency = 0.5,
	BoxThickness = 1,
	TracerESP = false,
	TracerOrigin = "Bottom",
	TracerStyle = "Line",
	TracerThickness = 1,
	HealthESP = false,
	HealthStyle = "Bar",
	HealthBarSide = "Left",
	HealthTextSuffix = "HP",
	NameESP = false,
	NameMode = "DisplayName",
	ShowDistance = true,
	DistanceUnit = "studs",
	TextSize = 14,
	TextFont = 2,
	RainbowSpeed = 1,
	MaxDistance = 1000,
	RefreshRate = 1/144,
	Snaplines = false,
	SnaplineStyle = "Straight",
	RainbowEnabled = false,
	RainbowBoxes = false,
	RainbowTracers = false,
	RainbowText = false,
	ChamsEnabled = false,
	ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
	ChamsFillColor = Color3.fromRGB(255, 0, 0),
	ChamsOccludedColor = Color3.fromRGB(150, 0, 0),
	ChamsTransparency = 0.5,
	ChamsOutlineTransparency = 0,
	ChamsOutlineThickness = 0.1,
	SkeletonESP = false,
	SkeletonColor = Color3.fromRGB(255, 255, 255),
	SkeletonThickness = 1.5,
	SkeletonTransparency = 1
}

-- Utilidades
local function DestroyObject(object)
	if typeof(object) == "table" then
		for _, value in pairs(object) do
			DestroyObject(value)
		end
		return
	end
	if typeof(object) == "Instance" then
		object:Destroy()
		return
	end
	if typeof(object) == "userdata" then
		pcall(function() object:Remove() end)
	end
end

local function NewDrawing(class, properties)
	local drawing = Drawing.new(class)
	for property, value in pairs(properties) do
		drawing[property] = value
	end
	return drawing
end

-- ============ SISTEMA DE FILTRADO AVANZADO ============

function EspHarkening:AddToWhitelist(identifier)
	-- Puede ser UserId (number) o nombre (string)
	table.insert(Whitelist, identifier)
end

function EspHarkening:RemoveFromWhitelist(identifier)
	for i, v in ipairs(Whitelist) do
		if v == identifier then
			table.remove(Whitelist, i)
			return true
		end
	end
	return false
end

function EspHarkening:ClearWhitelist()
	table.clear(Whitelist)
end

function EspHarkening:AddToBlacklist(identifier)
	table.insert(Blacklist, identifier)
end

function EspHarkening:RemoveFromBlacklist(identifier)
	for i, v in ipairs(Blacklist) do
		if v == identifier then
			table.remove(Blacklist, i)
			return true
		end
	end
	return false
end

function EspHarkening:ClearBlacklist()
	table.clear(Blacklist)
end

function EspHarkening:AddTargetTeam(teamName)
	table.insert(TargetTeams, teamName)
end

function EspHarkening:RemoveTargetTeam(teamName)
	for i, v in ipairs(TargetTeams) do
		if v == teamName then
			table.remove(TargetTeams, i)
			return true
		end
	end
	return false
end

function EspHarkening:ClearTargetTeams()
	table.clear(TargetTeams)
end

function EspHarkening:AddIgnoreTeam(teamName)
	table.insert(IgnoreTeams, teamName)
end

function EspHarkening:RemoveIgnoreTeam(teamName)
	for i, v in ipairs(IgnoreTeams) do
		if v == teamName then
			table.remove(IgnoreTeams, i)
			return true
		end
	end
	return false
end

function EspHarkening:ClearIgnoreTeams()
	table.clear(IgnoreTeams)
end

-- Función principal de verificación
function EspHarkening:ShouldShowESP(player)
	if player == localPlayer then return false end
	
	local playerId = player.UserId
	local playerName = player.Name
	local team = player.Team
	local teamName = team and team.Name or "Neutral"
	
	-- 1. Prioridad máxima: Whitelist
	if Settings.UseWhitelist then
		for _, id in ipairs(Whitelist) do
			if id == playerId or id == playerName then
				return true, "Whitelist", Colors.Target
			end
		end
		-- Si está activada la whitelist y no está en ella, no mostrar
		return false, "NotWhitelisted", nil
	end
	
	-- 2. Blacklist (segunda prioridad)
	if Settings.UseBlacklist then
		for _, id in ipairs(Blacklist) do
			if id == playerId or id == playerName then
				return false, "Blacklisted", nil
			end
		end
	end
	
	-- 3. Equipos específicos a ignorar
	for _, tName in ipairs(IgnoreTeams) do
		if teamName == tName then
			return false, "IgnoredTeam", nil
		end
	end
	
	-- 4. Solo equipos específicos target
	if Settings.TargetSpecificTeams then
		local isTargetTeam = false
		for _, tName in ipairs(TargetTeams) do
			if teamName == tName then
				isTargetTeam = true
				break
			end
		end
		if not isTargetTeam then
			return false, "NotTargetTeam", nil
		end
		return true, "TargetTeam", Colors.Target
	end
	
	-- 5. TeamCheck estándar
	if Settings.TeamCheck then
		if team == localPlayer.Team then
			if Settings.ShowTeam then
				return true, "Ally", Colors.Ally
			else
				return false, "AllyHidden", nil
			end
		else
			return true, "Enemy", Colors.Enemy
		end
	end
	
	-- 6. Sin filtros - mostrar todos
	return true, "Neutral", Colors.Neutral
end

local function GetTracerOrigin()
	local origin = Settings.TracerOrigin
	if origin == "Bottom" then
		return Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
	elseif origin == "Top" then
		return Vector2.new(camera.ViewportSize.X/2, 0)
	elseif origin == "Mouse" then
		return UserInputService:GetMouseLocation()
	else
		return Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
	end
end

-- Creación de elementos ESP
local function CreateBox()
	local defaults = {
		Visible = false,
		Color = Colors.Enemy,
		Thickness = Settings.BoxThickness,
	}
	return {
		TopLeft = NewDrawing("Line", defaults),
		TopRight = NewDrawing("Line", defaults),
		BottomLeft = NewDrawing("Line", defaults),
		BottomRight = NewDrawing("Line", defaults),
		Left = NewDrawing("Line", defaults),
		Right = NewDrawing("Line", defaults),
		Top = NewDrawing("Line", defaults),
		Bottom = NewDrawing("Line", defaults),
	}
end

local function CreateTracer()
	return NewDrawing("Line", {
		Visible = false,
		Color = Colors.Enemy,
		Thickness = Settings.TracerThickness
	})
end

local function CreateInfo()
	return {
		Name = NewDrawing("Text", {
			Visible = false,
			Center = true,
			Outline = true,
			Font = Settings.TextFont,
			Size = Settings.TextSize,
			Color = Colors.Enemy
		}),
		Distance = NewDrawing("Text", {
			Visible = false,
			Center = true,
			Outline = true,
			Font = Settings.TextFont,
			Size = Settings.TextSize,
			Color = Colors.Distance
		})
	}
end

local function CreateHealthBar()
	return {
		Outline = NewDrawing("Square", {Visible = false}),
		Fill = NewDrawing("Square", {
			Visible = false,
			Filled = true,
			Color = Colors.Health
		}),
		Text = NewDrawing("Text", {
			Visible = false,
			Center = true,
			Font = Settings.TextFont,
			Size = Settings.TextSize,
			Color = Colors.Health
		})
	}
end

local function CreateHighlight()
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Settings.ChamsFillColor
	highlight.OutlineColor = Settings.ChamsOutlineColor
	highlight.FillTransparency = Settings.ChamsTransparency
	highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = Settings.ChamsEnabled
	return highlight
end

local function CreateSkeleton()
	local defaults = {
		Visible = false,
		Color = Settings.SkeletonColor,
		Thickness = Settings.SkeletonThickness,
		Transparency = Settings.SkeletonTransparency
	}
	return {
		Head = NewDrawing("Line", defaults),
		Neck = NewDrawing("Line", defaults),
		UpperSpine = NewDrawing("Line", defaults),
		LowerSpine = NewDrawing("Line", defaults),
		LeftShoulder = NewDrawing("Line", defaults),
		LeftUpperArm = NewDrawing("Line", defaults),
		LeftLowerArm = NewDrawing("Line", defaults),
		LeftHand = NewDrawing("Line", defaults),
		RightShoulder = NewDrawing("Line", defaults),
		RightUpperArm = NewDrawing("Line", defaults),
		RightLowerArm = NewDrawing("Line", defaults),
		RightHand = NewDrawing("Line", defaults),
		LeftHip = NewDrawing("Line", defaults),
		LeftUpperLeg = NewDrawing("Line", defaults),
		LeftLowerLeg = NewDrawing("Line", defaults),
		LeftFoot = NewDrawing("Line", defaults),
		RightHip = NewDrawing("Line", defaults),
		RightUpperLeg = NewDrawing("Line", defaults),
		RightLowerLeg = NewDrawing("Line", defaults),
		RightFoot = NewDrawing("Line", defaults)
	}
end

local function CreateSnapline()
	return NewDrawing("Line", {
		Visible = false,
		Color = Colors.Enemy,
		Thickness = 1
	})
end

-- Funciones principales del módulo
function EspHarkening:CreateESP(player)
	if player == localPlayer then return end
	if Drawings[player] then return Drawings[player] end

	Drawings[player] = {
		Box = CreateBox(),
		Tracer = CreateTracer(),
		HealthBar = CreateHealthBar(),
		Info = CreateInfo(),
		Highlight = CreateHighlight(),
		Skeleton = CreateSkeleton(),
		Snapline = CreateSnapline()
	}

	return Drawings[player]
end

function EspHarkening:RemoveESP(player)
	local esp = Drawings[player]
	if not esp then return end

	DestroyObject(esp.Box)
	DestroyObject(esp.Tracer)
	DestroyObject(esp.HealthBar)
	DestroyObject(esp.Info)
	DestroyObject(esp.Skeleton)
	DestroyObject(esp.Snapline)
	
	if esp.Highlight then
		esp.Highlight:Destroy()
	end

	Drawings[player] = nil
end

function EspHarkening:ClearAllESP()
	for player, _ in pairs(Drawings) do
		self:RemoveESP(player)
	end
	table.clear(Drawings)
end

function EspHarkening:HideAllESP()
	for _, esp in pairs(Drawings) do
		for _, obj in pairs(esp.Box) do obj.Visible = false end
		esp.Tracer.Visible = false
		for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
		for _, obj in pairs(esp.Info) do obj.Visible = false end
		esp.Snapline.Visible = false
		for _, line in pairs(esp.Skeleton) do line.Visible = false end
		if esp.Highlight then esp.Highlight.Enabled = false end
	end
end

function EspHarkening:HidePlayerESP(player)
	local esp = Drawings[player]
	if not esp then return end
	for _, obj in pairs(esp.Box) do obj.Visible = false end
	esp.Tracer.Visible = false
	for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
	for _, obj in pairs(esp.Info) do obj.Visible = false end
	esp.Snapline.Visible = false
	for _, line in pairs(esp.Skeleton) do line.Visible = false end
	if esp.Highlight then esp.Highlight.Enabled = false end
end

-- Funciones de actualización específicas
function EspHarkening:UpdateBox(esp, character, color, boxPosition, boxSize, screenSize, cf)
	if not Settings.BoxESP then
		for _, obj in pairs(esp.Box) do obj.Visible = false end
		return
	end

	local size = character:GetExtentsSize()
	
	if Settings.BoxStyle == "ThreeD" then
		local front = {
			TL = camera:WorldToViewportPoint((cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2)).Position),
			TR = camera:WorldToViewportPoint((cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2)).Position),
			BL = camera:WorldToViewportPoint((cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2)).Position),
			BR = camera:WorldToViewportPoint((cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2)).Position)
		}
		
		local back = {
			TL = camera:WorldToViewportPoint((cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2)).Position),
			TR = camera:WorldToViewportPoint((cf * CFrame.new(size.X/2, size.Y/2, size.Z/2)).Position),
			BL = camera:WorldToViewportPoint((cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2)).Position),
			BR = camera:WorldToViewportPoint((cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2)).Position)
		}
		
		if not (front.TL.Z > 0 and front.TR.Z > 0 and front.BL.Z > 0 and front.BR.Z > 0 and
			   back.TL.Z > 0 and back.TR.Z > 0 and back.BL.Z > 0 and back.BR.Z > 0) then
			for _, obj in pairs(esp.Box) do obj.Visible = false end
			return
		end
		
		local function toVector2(v3) return Vector2.new(v3.X, v3.Y) end
		front.TL, front.TR = toVector2(front.TL), toVector2(front.TR)
		front.BL, front.BR = toVector2(front.BL), toVector2(front.BR)
		back.TL, back.TR = toVector2(back.TL), toVector2(back.TR)
		back.BL, back.BR = toVector2(back.BL), toVector2(back.BR)
		
		esp.Box.TopLeft.From = front.TL; esp.Box.TopLeft.To = front.TR; esp.Box.TopLeft.Visible = true
		esp.Box.TopRight.From = front.TR; esp.Box.TopRight.To = front.BR; esp.Box.TopRight.Visible = true
		esp.Box.BottomLeft.From = front.BL; esp.Box.BottomLeft.To = front.BR; esp.Box.BottomLeft.Visible = true
		esp.Box.BottomRight.From = front.TL; esp.Box.BottomRight.To = front.BL; esp.Box.BottomRight.Visible = true
		esp.Box.Left.From = back.TL; esp.Box.Left.To = back.TR; esp.Box.Left.Visible = true
		esp.Box.Right.From = back.TR; esp.Box.Right.To = back.BR; esp.Box.Right.Visible = true
		esp.Box.Top.From = back.BL; esp.Box.Top.To = back.BR; esp.Box.Top.Visible = true
		esp.Box.Bottom.From = back.TL; esp.Box.Bottom.To = back.BL; esp.Box.Bottom.Visible = true
		
	elseif Settings.BoxStyle == "Corner" then
		local cornerSize = boxSize.X * 0.2
		
		esp.Box.TopLeft.From = boxPosition
		esp.Box.TopLeft.To = boxPosition + Vector2.new(cornerSize, 0)
		esp.Box.TopLeft.Visible = true
		
		esp.Box.TopRight.From = boxPosition + Vector2.new(boxSize.X, 0)
		esp.Box.TopRight.To = boxPosition + Vector2.new(boxSize.X - cornerSize, 0)
		esp.Box.TopRight.Visible = true
		
		esp.Box.BottomLeft.From = boxPosition + Vector2.new(0, boxSize.Y)
		esp.Box.BottomLeft.To = boxPosition + Vector2.new(cornerSize, boxSize.Y)
		esp.Box.BottomLeft.Visible = true
		
		esp.Box.BottomRight.From = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
		esp.Box.BottomRight.To = boxPosition + Vector2.new(boxSize.X - cornerSize, boxSize.Y)
		esp.Box.BottomRight.Visible = true
		
		esp.Box.Left.From = boxPosition
		esp.Box.Left.To = boxPosition + Vector2.new(0, cornerSize)
		esp.Box.Left.Visible = true
		
		esp.Box.Right.From = boxPosition + Vector2.new(boxSize.X, 0)
		esp.Box.Right.To = boxPosition + Vector2.new(boxSize.X, cornerSize)
		esp.Box.Right.Visible = true
		
		esp.Box.Top.From = boxPosition + Vector2.new(0, boxSize.Y)
		esp.Box.Top.To = boxPosition + Vector2.new(0, boxSize.Y - cornerSize)
		esp.Box.Top.Visible = true
		
		esp.Box.Bottom.From = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
		esp.Box.Bottom.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y - cornerSize)
		esp.Box.Bottom.Visible = true
		
	else -- Full box
		esp.Box.Left.From = boxPosition
		esp.Box.Left.To = boxPosition + Vector2.new(0, boxSize.Y)
		esp.Box.Left.Visible = true
		
		esp.Box.Right.From = boxPosition + Vector2.new(boxSize.X, 0)
		esp.Box.Right.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
		esp.Box.Right.Visible = true
		
		esp.Box.Top.From = boxPosition
		esp.Box.Top.To = boxPosition + Vector2.new(boxSize.X, 0)
		esp.Box.Top.Visible = true
		
		esp.Box.Bottom.From = boxPosition + Vector2.new(0, boxSize.Y)
		esp.Box.Bottom.To = boxPosition + Vector2.new(boxSize.X, boxSize.Y)
		esp.Box.Bottom.Visible = true
		
		esp.Box.TopLeft.Visible = false
		esp.Box.TopRight.Visible = false
		esp.Box.BottomLeft.Visible = false
		esp.Box.BottomRight.Visible = false
	end
	
	for _, obj in pairs(esp.Box) do
		if obj.Visible then
			obj.Color = color
			obj.Thickness = Settings.BoxThickness
		end
	end
end

function EspHarkening:UpdateTracer(esp, pos, color)
	if not Settings.TracerESP then
		esp.Tracer.Visible = false
		return
	end
	
	esp.Tracer.From = GetTracerOrigin()
	esp.Tracer.To = Vector2.new(pos.X, pos.Y)
	esp.Tracer.Color = color
	esp.Tracer.Visible = true
end

function EspHarkening:UpdateHealthBar(esp, humanoid, boxPosition, boxSize, screenSize)
	if not Settings.HealthESP then
		for _, obj in pairs(esp.HealthBar) do obj.Visible = false end
		return
	end
	
	local health = humanoid.Health
	local maxHealth = humanoid.MaxHealth
	local healthPercent = math.clamp(health/maxHealth, 0, 1)
	
	local barHeight = screenSize * 0.8
	local barWidth = 4
	local barPos = Vector2.new(
		boxPosition.X - barWidth - 2,
		boxPosition.Y + (screenSize - barHeight)/2
	)
	
	esp.HealthBar.Outline.Size = Vector2.new(barWidth, barHeight)
	esp.HealthBar.Outline.Position = barPos
	esp.HealthBar.Outline.Visible = true
	
	esp.HealthBar.Fill.Size = Vector2.new(barWidth - 2, barHeight * healthPercent)
	esp.HealthBar.Fill.Position = Vector2.new(barPos.X + 1, barPos.Y + barHeight * (1-healthPercent))
	esp.HealthBar.Fill.Color = Color3.fromRGB(255 - (255 * healthPercent), 255 * healthPercent, 0)
	esp.HealthBar.Fill.Visible = true
	
	if Settings.HealthStyle == "Both" or Settings.HealthStyle == "Text" then
		esp.HealthBar.Text.Text = math.floor(health) .. Settings.HealthTextSuffix
		esp.HealthBar.Text.Position = Vector2.new(barPos.X + barWidth + 2, barPos.Y + barHeight/2)
		esp.HealthBar.Text.Visible = true
	else
		esp.HealthBar.Text.Visible = false
	end
end

function EspHarkening:UpdateInfo(esp, player, boxPosition, boxSize, color, distance)
	if not Settings.NameESP then
		esp.Info.Name.Visible = false
	else
		local text = Settings.NameMode == "DisplayName" and player.DisplayName or player.Name
		if Settings.ShowDistance then
			text = text .. " [" .. math.floor(distance) .. "]"
		end
		esp.Info.Name.Text = text
		esp.Info.Name.Position = Vector2.new(boxPosition.X + boxSize.X/2, boxPosition.Y - 20)
		esp.Info.Name.Color = color
		esp.Info.Name.Visible = true
	end
	
	if Settings.ShowDistance and not Settings.NameESP then
		esp.Info.Distance.Text = math.floor(distance) .. " " .. Settings.DistanceUnit
		esp.Info.Distance.Position = Vector2.new(boxPosition.X + boxSize.X/2, boxPosition.Y + boxSize.Y + 5)
		esp.Info.Distance.Visible = true
	else
		esp.Info.Distance.Visible = false
	end
end

function EspHarkening:UpdateSnapline(esp, pos, color)
	if not Settings.Snaplines then
		esp.Snapline.Visible = false
		return
	end
	
	esp.Snapline.From = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y)
	esp.Snapline.To = Vector2.new(pos.X, pos.Y)
	esp.Snapline.Color = color
	esp.Snapline.Visible = true
end

function EspHarkening:UpdateHighlight(esp, character, color)
	if not esp.Highlight then return end
	
	if Settings.ChamsEnabled and character then
		esp.Highlight.Parent = character
		esp.Highlight.FillColor = Settings.ChamsFillColor
		esp.Highlight.OutlineColor = color or Settings.ChamsOutlineColor
		esp.Highlight.FillTransparency = Settings.ChamsTransparency
		esp.Highlight.OutlineTransparency = Settings.ChamsOutlineTransparency
		esp.Highlight.Enabled = true
	else
		esp.Highlight.Enabled = false
	end
end

function EspHarkening:UpdateSkeleton(esp, character)
	if not Settings.SkeletonESP then
		for _, line in pairs(esp.Skeleton) do line.Visible = false end
		return
	end
	
	local function getBonePositions(char)
		if not char then return nil end
		
		return {
			Head = char:FindFirstChild("Head"),
			UpperTorso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"),
			LowerTorso = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso"),
			LeftUpperArm = char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm"),
			LeftLowerArm = char:FindFirstChild("LeftLowerArm") or char:FindFirstChild("Left Arm"),
			LeftHand = char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm"),
			RightUpperArm = char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm"),
			RightLowerArm = char:FindFirstChild("RightLowerArm") or char:FindFirstChild("Right Arm"),
			RightHand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"),
			LeftUpperLeg = char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg"),
			LeftLowerLeg = char:FindFirstChild("LeftLowerLeg") or char:FindFirstChild("Left Leg"),
			LeftFoot = char:FindFirstChild("LeftFoot") or char:FindFirstChild("Left Leg"),
			RightUpperLeg = char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg"),
			RightLowerLeg = char:FindFirstChild("RightLowerLeg") or char:FindFirstChild("Right Leg"),
			RightFoot = char:FindFirstChild("RightFoot") or char:FindFirstChild("Right Leg")
		}
	end
	
	local function drawBone(from, to, line)
		if not from or not to then 
			line.Visible = false
			return 
		end
		
		local fromScreen, fromVisible = camera:WorldToViewportPoint(from.Position)
		local toScreen, toVisible = camera:WorldToViewportPoint(to.Position)
		
		if not (fromVisible and toVisible) or fromScreen.Z < 0 or toScreen.Z < 0 then
			line.Visible = false
			return
		end
		
		line.From = Vector2.new(fromScreen.X, fromScreen.Y)
		line.To = Vector2.new(toScreen.X, toScreen.Y)
		line.Color = Settings.SkeletonColor
		line.Thickness = Settings.SkeletonThickness
		line.Transparency = Settings.SkeletonTransparency
		line.Visible = true
	end
	
	local bones = getBonePositions(character)
	if not bones or not (bones.Head and bones.UpperTorso) then
		for _, line in pairs(esp.Skeleton) do line.Visible = false end
		return
	end
	
	drawBone(bones.Head, bones.UpperTorso, esp.Skeleton.Head)
	drawBone(bones.UpperTorso, bones.LowerTorso, esp.Skeleton.UpperSpine)
	drawBone(bones.UpperTorso, bones.LeftUpperArm, esp.Skeleton.LeftShoulder)
	drawBone(bones.LeftUpperArm, bones.LeftLowerArm, esp.Skeleton.LeftUpperArm)
	drawBone(bones.LeftLowerArm, bones.LeftHand, esp.Skeleton.LeftLowerArm)
	drawBone(bones.UpperTorso, bones.RightUpperArm, esp.Skeleton.RightShoulder)
	drawBone(bones.RightUpperArm, bones.RightLowerArm, esp.Skeleton.RightUpperArm)
	drawBone(bones.RightLowerArm, bones.RightHand, esp.Skeleton.RightLowerArm)
	drawBone(bones.LowerTorso, bones.LeftUpperLeg, esp.Skeleton.LeftHip)
	drawBone(bones.LeftUpperLeg, bones.LeftLowerLeg, esp.Skeleton.LeftUpperLeg)
	drawBone(bones.LeftLowerLeg, bones.LeftFoot, esp.Skeleton.LeftLowerLeg)
	drawBone(bones.LowerTorso, bones.RightUpperLeg, esp.Skeleton.RightHip)
	drawBone(bones.RightUpperLeg, bones.RightLowerLeg, esp.Skeleton.RightUpperLeg)
	drawBone(bones.RightLowerLeg, bones.RightFoot, esp.Skeleton.RightLowerLeg)
end

-- Función principal de actualización
function EspHarkening:UpdatePlayerESP(player)
	if not Settings.Enabled then return end
	if player == localPlayer then return end
	
	-- Verificar si debe mostrarse
	local shouldShow, reason, customColor = self:ShouldShowESP(player)
	if not shouldShow then
		self:HidePlayerESP(player)
		return
	end
	
	local esp = Drawings[player]
	if not esp then
		esp = self:CreateESP(player)
	end
	
	local character = player.Character
	if not character then 
		self:HidePlayerESP(player)
		return 
	end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then 
		self:HidePlayerESP(player)
		return 
	end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		self:HidePlayerESP(player)
		return
	end
	
	local pos, onScreen = camera:WorldToViewportPoint(rootPart.Position)
	local distance = (rootPart.Position - camera.CFrame.Position).Magnitude
	
	if not onScreen or distance > Settings.MaxDistance then
		self:HidePlayerESP(player)
		return
	end
	
	-- Determinar color final
	local color = customColor
	if Settings.RainbowEnabled then
		local hue = (tick() * Settings.RainbowSpeed) % 1
		color = Color3.fromHSV(hue, 1, 1)
	elseif not color then
		if reason == "Enemy" then color = Colors.Enemy
		elseif reason == "Ally" then color = Colors.Ally
		elseif reason == "Neutral" then color = Colors.Neutral
		else color = Colors.Enemy end
	end
	
	local size = character:GetExtentsSize()
	local cf = rootPart.CFrame
	
	local top = camera:WorldToViewportPoint(cf * CFrame.new(0, size.Y/2, 0).Position)
	local bottom = camera:WorldToViewportPoint(cf * CFrame.new(0, -size.Y/2, 0).Position)
	
	if top.Z < 0 or bottom.Z < 0 then
		self:HidePlayerESP(player)
		return
	end
	
	local screenSize = bottom.Y - top.Y
	local boxWidth = screenSize * 0.65
	local boxPosition = Vector2.new(top.X - boxWidth/2, top.Y)
	local boxSize = Vector2.new(boxWidth, screenSize)
	
	-- Actualizar cada componente
	self:UpdateBox(esp, character, color, boxPosition, boxSize, screenSize, cf)
	self:UpdateTracer(esp, pos, color)
	self:UpdateHealthBar(esp, humanoid, boxPosition, boxSize, screenSize)
	self:UpdateInfo(esp, player, boxPosition, boxSize, color, distance)
	self:UpdateSnapline(esp, pos, color)
	self:UpdateSkeleton(esp, character)
	self:UpdateHighlight(esp, character, color)
end

-- Control del sistema
function EspHarkening:Enable(enabled)
	if typeof(enabled) ~= "boolean" then
		return warn("[EspHarkening][Enable]: Expected boolean, got " .. typeof(enabled))
	end
	
	Settings.Enabled = enabled
	
	if enabled then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= localPlayer then
				self:CreateESP(player)
			end
		end
		
		if not Connections.Render then
			Connections.Render = RunService.RenderStepped:Connect(function()
				if not Settings.Enabled then return end
				for _, player in ipairs(Players:GetPlayers()) do
					self:UpdatePlayerESP(player)
				end
			end)
		end
		
		if not Connections.PlayerAdded then
			Connections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
				if Settings.Enabled then
					self:CreateESP(player)
				end
			end)
		end
		
		if not Connections.PlayerRemoving then
			Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
				self:RemoveESP(player)
			end)
		end
	else
		self:HideAllESP()
	end
end

function EspHarkening:Disable()
	self:Enable(false)
end

function EspHarkening:Destroy()
	self:Enable(false)
	
	for _, conn in pairs(Connections) do
		if conn then conn:Disconnect() end
	end
	table.clear(Connections)
	
	self:ClearAllESP()
end

-- Métodos de configuración
function EspHarkening:SetSetting(key, value)
	if Settings[key] ~= nil then
		Settings[key] = value
	else
		warn("[EspHarkening]: Setting '" .. tostring(key) .. "' not found")
	end
end

function EspHarkening:GetSetting(key)
	return Settings[key]
end

function EspHarkening:GetSettings()
	return Settings
end

function EspHarkening:SetColor(key, color)
	if Colors[key] ~= nil then
		Colors[key] = color
	else
		warn("[EspHarkening]: Color '" .. tostring(key) .. "' not found")
	end
end

function EspHarkening:GetColor(key)
	return Colors[key]
end

-- Métodos de lista
function EspHarkening:GetWhitelist() return Whitelist end
function EspHarkening:GetBlacklist() return Blacklist end
function EspHarkening:GetTargetTeams() return TargetTeams end
function EspHarkening:GetIgnoreTeams() return IgnoreTeams end

return EspHarkening
