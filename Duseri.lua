-- DmxConsoleUI_SnapSwipe_DynamicParams.lua
-- Desain & tema gelap tetap (350x340) + Snap Swipe ↕
-- Parameter di Preferensi otomatis ngikutin device yang dipilih (Wallwasher: Effect/Warna/SpeedEffect | Clara: Pan/Tilt/Gobo/Prism/dll.)
-- Auto-spill > 512 ke Universe 2 + Transport U1 (3-byte buffer) & U2 ({ [2] = buf512 }) -> UDP_DMXDATA

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local MAX_CHANNELS = 512
local DEFAULT_MAX_UNIVERSES = 2
local REMOTE_NAME = "UDP_DMXDATA"
local SEND_THROTTLE = 0.04

-- ============================================================================
-- PATCH ENGINE
-- ============================================================================
local PatchEngine = {}
do
	local mod = ReplicatedStorage:FindFirstChild("PatchEngine")
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok and type(res) == "table" and type(res.PatchAll) == "function" then
			PatchEngine = res
		end
	end
end

if not PatchEngine.Profiles then
	local BarWashProfile = {
		Group = "BarWash", Span = 8, Dimmer = 0, Shutter = 1, Red = 2, Green = 3, Blue = 4, Effect = 5, Speed = 7,
	}
	local ClaraS14Profile = {
		Group = "MovingBeam",
		Span = 16,
		X = 0,
		Y = 1,
		PanFine = 2,
		TiltFine = 3,
		Shutter = 6,
		Dimmer = 7,
		Color = 8,
		Gobo = 9,
		Prism = 11,
		Effect = 11,
		Focus = 12,
		Speed = 14,
		GoboRotation = 14,
	}
	PatchEngine.Profiles = {
		["ClaraS14"] = ClaraS14Profile,
		["Wallwasher_24X3W"] = BarWashProfile,
		["StrobeBar_192_Segment"] = BarWashProfile,
		["STROBE_1000W"] = { Group = "Strobe1000W", Span = 8, Dimmer = 0, Shutter = 1, Red = 2, Green = 3, Blue = 4, Effect = 5, Speed = 7 },
		["Parled"] = { Group = "Parled", Span = 6, Dimmer = 0, Red = 1, Green = 2, Blue = 3, White = 4, Shutter = 5 },
		["BlinderRing_2x50W"] = { Group = "Blinder", Span = 12, Dimmer = 0, Shutter = 1, Pod1Mode = 2, Pod2Mode = 3, AmberDim = 4, BacklightDim = 5, RingDim = 6, Red = 7, Green = 8, Blue = 9, Effect = 10, Speed = 11 },
		["Blinder"] = { Group = "Blinder", Span = 8, Dimmer = 0, LED1 = 0, LED2 = 1, LED3 = 2, LED4 = 3 },
		["Fogger"] = { Group = "Fogger", Span = 16, X = 0, Dimmer = 2, Shutter = 4, Red = 5, Green = 8, Blue = 9, Effect = 12 },
		["Flower"] = { Group = "Flower", Span = 18, Dimmer = 0, Red = 1, Green = 2, Blue = 3, Effect = 4, Speed = 5, Shutter = 16 },
		["Miniled"] = { Group = "MiniLed", Span = 1, Dimmer = 0 },
		["Pixelbeambar"] = { Group = "PixelBar", Span = 20, Y = 0, Speed = 2, Effect = 3, Dimmer = 5, Shutter = 6, Red = 8, Green = 9, Blue = 10 },
		["Retrohex"] = { Group = "RetroHex", Span = 11, Dimmer = 0, Shutter = 3, Effect = 4, Red = 6, Green = 7, Blue = 8 },
		["Windmill"] = { Group = "Windmill", Span = 8, Dimmer = 0, Shutter = 1, Speed = 2, Effect = 3, Red = 5, Green = 6, Blue = 7 },
	}
end

-- Urutan & label parameter per jenis fixture biar tampilannya natural & ringkas
local PARAM_META = {
	X = { label = "Pan", maxDeg = 540 },
	Y = { label = "Tilt", maxDeg = 270 },
	PanFine = { label = "PanFine" },
	TiltFine = { label = "TiltFine" },
	Dimmer = { label = "Dimmer" },
	Shutter = { label = "Shutter" },
	Red = { label = "Warna R" },
	Green = { label = "Warna G" },
	Blue = { label = "Warna B" },
	White = { label = "Warna W" },
	Color = { label = "Warna" },
	Gobo = { label = "Gobo" },
	Prism = { label = "Prisma" },
	Effect = { label = "Effect" },
	Focus = { label = "Focus" },
	Speed = { label = "SpeedEffect" },
	GoboRotation = { label = "GoboRot" },
}

local DEVICE_PARAM_ORDER = {
	["ClaraS14"] = { "X", "Y", "Gobo", "Prism", "Color", "Dimmer", "Shutter", "Focus", "Speed", "PanFine", "TiltFine" },
	["Wallwasher_24X3W"] = { "Effect", "Red", "Green", "Blue", "Speed", "Dimmer", "Shutter" },
	["StrobeBar_192_Segment"] = { "Effect", "Red", "Green", "Blue", "Speed", "Dimmer", "Shutter" },
	["STROBE_1000W"] = { "Dimmer", "Shutter", "Red", "Green", "Blue", "Effect", "Speed" },
	["Parled"] = { "Red", "Green", "Blue", "White", "Dimmer", "Shutter" },
	["BlinderRing_2x50W"] = { "Dimmer", "Shutter", "Red", "Green", "Blue", "Effect", "Speed" },
	["Fogger"] = { "X", "Dimmer", "Shutter", "Red", "Green", "Blue", "Effect" },
	["Pixelbeambar"] = { "Y", "Effect", "Red", "Green", "Blue", "Speed", "Dimmer", "Shutter" },
}

local NameAliases = {
	["ClaraS14"] = { "claras14", "clara_s14", "clara s14" },
	["STROBE_1000W"] = { "strobe_1000w", "strobe1000", "strobo_1000w", "strobe 1000w" },
	["Wallwasher_24X3W"] = { "wallwasher_24x3w", "wallwasher", "wall washer" },
	["StrobeBar_192_Segment"] = { "strobebar_192_segment", "strobebar", "strobe bar" },
	["BlinderRing_2x50W"] = { "blinderring_2x50w", "blinderring", "blinder ring" },
	["Pixelbeambar"] = { "pixelbeambar", "pixelbar", "pixel beam bar" },
}

local function matchesAnyKey(itemName, keys)
	local lowerName = string.lower(tostring(itemName or ""))
	for _, k in ipairs(keys) do
		local keyLower = string.lower(tostring(k or ""))
		if keyLower ~= "" and (lowerName == keyLower or string.find(lowerName, keyLower, 1, true)) then
			return true
		end
	end
	return false
end

local function toAbsChannel(address, offset0, maxChannels)
	if type(address) ~= "number" or type(offset0) ~= "number" then return nil end
	if offset0 < 0 or offset0 >= (maxChannels or MAX_CHANNELS) then return nil end
	local ch = math.floor(address + offset0)
	return (ch >= 1 and ch <= MAX_CHANNELS) and ch or nil
end

-- ============================================================================
-- TRANSPORT: U1 (3-BYTE BUFFER) & U2 ({ [2] = buf512 }) -> UDP_DMXDATA
-- ============================================================================
local function getOwnCarModel(plr)
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if not vehicles or not plr then return nil end
	local exact = vehicles:FindFirstChild(plr.Name .. "'s Car")
	if exact then return exact end
	local lp = string.lower(plr.Name)
	for _, c in ipairs(vehicles:GetChildren()) do
		if string.find(string.lower(c.Name), lp, 1, true) then
			return c
		end
	end
	return nil
end

local function findUdpDmxRemote(plr)
	local carModel = getOwnCarModel(plr)
	if carModel then
		local r = carModel:FindFirstChild(REMOTE_NAME, true)
		if r and (r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent")) then
			return r
		end
	end
	local rRs = ReplicatedStorage:FindFirstChild(REMOTE_NAME, true)
	if rRs and (rRs:IsA("RemoteEvent") or rRs:IsA("UnreliableRemoteEvent")) then
		return rRs
	end
	local rWs = Workspace:FindFirstChild(REMOTE_NAME, true)
	if rWs and (rWs:IsA("RemoteEvent") or rWs:IsA("UnreliableRemoteEvent")) then
		return rWs
	end
	return nil
end

local DmxTransport = {}
DmxTransport.__index = DmxTransport

function DmxTransport.new(plr)
	local self = setmetatable({}, DmxTransport)
	self.Player = plr
	self.DataRemote = findUdpDmxRemote(plr)
	self.LastValues = { [1] = {}, [2] = {} }
	self.UniverseBuffers = {
		[2] = buffer.create(MAX_CHANNELS),
	}
	self.LastSendTick = {}
	self.TxCount = 0
	self:_bind()
	return self
end

function DmxTransport:_refreshRemote()
	local found = findUdpDmxRemote(self.Player)
	if found then
		self.DataRemote = found
	end
	return self.DataRemote
end

function DmxTransport:_bind()
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if vehicles then
		vehicles.ChildAdded:Connect(function()
			task.wait(0.25)
			self:_refreshRemote()
		end)
	end
	task.spawn(function()
		while not self.DataRemote do
			self:_refreshRemote()
			task.wait(1)
		end
	end)
end

function DmxTransport:SendChannel(univ, ch, dmxVal, force)
	local u = (tonumber(univ) == 2) and 2 or 1
	local channel = math.clamp(math.floor(tonumber(ch) or 1), 1, MAX_CHANNELS)
	local val = math.clamp(math.floor(tonumber(dmxVal) or 0), 0, 255)

	self.LastValues[u] = self.LastValues[u] or {}
	if not force and self.LastValues[u][channel] == val then
		return true
	end

	local key = u .. ":" .. channel
	local now = os.clock()
	if not force and self.LastSendTick[key] and (now - self.LastSendTick[key]) < SEND_THROTTLE then
		return true
	end

	local remote = self.DataRemote or self:_refreshRemote()
	if not remote then
		return false
	end

	self.LastValues[u][channel] = val
	self.LastSendTick[key] = now

	local ok = false
	if u == 2 then
		local buf512 = self.UniverseBuffers[2]
		if not buf512 then
			buf512 = buffer.create(MAX_CHANNELS)
			self.UniverseBuffers[2] = buf512
		end
		buffer.writeu8(buf512, channel - 1, val)
		ok = pcall(function()
			remote:FireServer({ [2] = buf512 })
		end)
	else
		local buf3 = buffer.create(3)
		buffer.writeu16(buf3, 0, channel)
		buffer.writeu8(buf3, 2, val)
		ok = pcall(function()
			remote:FireServer(buf3)
		end)
	end

	if ok then
		self.TxCount += 1
	end
	return ok
end

function DmxTransport:ClearUniverse(univ)
	local u = (tonumber(univ) == 2) and 2 or 1
	self.LastValues[u] = {}
	if u == 2 then
		local buf512 = buffer.create(MAX_CHANNELS)
		self.UniverseBuffers[2] = buf512
		local remote = self.DataRemote or self:_refreshRemote()
		if remote then
			pcall(function()
				remote:FireServer({ [2] = buf512 })
			end)
			self.TxCount += 1
		end
	end
end

local transport = DmxTransport.new(player)

-- ============================================================================
-- DARK THEME UI (350x340 - UKURAN NORMAL + TIKTOK/SHORTS SNAP SWIPE)
-- ============================================================================
local THEME = {
	bg = Color3.fromRGB(24, 25, 29),
	surface = Color3.fromRGB(38, 40, 46),
	surfaceAlt = Color3.fromRGB(48, 51, 58),
	stroke = Color3.fromRGB(58, 62, 70),
	divider = Color3.fromRGB(46, 49, 56),
	accent = Color3.fromRGB(11, 136, 153),
	primary = Color3.fromRGB(33, 134, 235),
	text = Color3.fromRGB(236, 238, 244),
	muted = Color3.fromRGB(154, 160, 172),
	track = Color3.fromRGB(64, 68, 76),
	badgeBg = Color3.fromRGB(44, 47, 54),
}

local WIN_W, WIN_H = 350, 340

local parentTarget = player:WaitForChild("PlayerGui")
pcall(function()
	if gethui then parentTarget = gethui() end
end)
local oldGui = parentTarget:FindFirstChild("DmxConsoleSnapGui")
if oldGui then oldGui:Destroy() end

local fixtureNames = {}
do
	local seen = {}
	for name, prof in pairs(PatchEngine.Profiles or {}) do
		if type(prof) == "table" and not seen[prof] then
			seen[prof] = true
			table.insert(fixtureNames, name)
		end
	end
	table.sort(fixtureNames, function(a, b)
		if a == "ClaraS14" then return true end
		if b == "ClaraS14" then return false end
		return a < b
	end)
end

local allRawFixtures = {}

local state = {
	activeTab = "patch",
	page = 1,
	slotsPerPage = 12,
	universe = 1,
	fixtureIndex = 1,
	addedCountByUniv = { [1] = 0, [2] = 0 },
	selectedBoxes = {},
	activeParamKey = "X",
	paramRatios = {},
	rawByUniv = { [1] = {}, [2] = {} },
	patchedByUniv = { [1] = {}, [2] = {} },
	nextAddress = 1,
	devicesPowerOn = false,
	reelIndex = 1,
}

local addrBadge

local function getSelectedFixtureName()
	return fixtureNames[state.fixtureIndex] or "ClaraS14"
end

local function getSelectedBoxList()
	local list = {}
	for idx, isSel in pairs(state.selectedBoxes) do
		if isSel then
			table.insert(list, idx)
		end
	end
	table.sort(list)
	return list
end

local function buildChannelsFromProfile(addr, span, prof)
	return {
		X = toAbsChannel(addr, prof.X, span),
		Y = toAbsChannel(addr, prof.Y, span),
		PanFine = toAbsChannel(addr, prof.PanFine, span),
		TiltFine = toAbsChannel(addr, prof.TiltFine, span),
		Shutter = toAbsChannel(addr, prof.Shutter, span),
		Dimmer = toAbsChannel(addr, prof.Dimmer, span),
		Color = toAbsChannel(addr, prof.Color, span),
		Gobo = toAbsChannel(addr, prof.Gobo, span),
		Prism = toAbsChannel(addr, prof.Prism, span),
		Effect = toAbsChannel(addr, prof.Effect, span),
		Focus = toAbsChannel(addr, prof.Focus, span),
		Speed = toAbsChannel(addr, prof.Speed or prof.GoboRotation, span),
		GoboRotation = toAbsChannel(addr, prof.GoboRotation or prof.Speed, span),
		Red = toAbsChannel(addr, prof.Red, span),
		Green = toAbsChannel(addr, prof.Green, span),
		Blue = toAbsChannel(addr, prof.Blue, span),
		White = toAbsChannel(addr, prof.White, span),
	}
end

local function resolveFixtureForBox(boxIdx)
	local patched = state.patchedByUniv[state.universe] or {}
	if patched[boxIdx] then
		return patched[boxIdx]
	end
	local profName = getSelectedFixtureName()
	local prof = PatchEngine.Profiles[profName] or {}
	local span = math.clamp(math.floor(tonumber(prof.Span) or 8), 1, MAX_CHANNELS)
	local fallbackAddr = math.clamp((boxIdx - 1) * span + 1, 1, MAX_CHANNELS)
	return {
		Address = fallbackAddr,
		Span = span,
		Universe = state.universe,
		Type = profName,
		Channels = buildChannelsFromProfile(fallbackAddr, span, prof),
	}
end

local function getActiveDeviceType()
	local selList = getSelectedBoxList()
	if #selList > 0 then
		local firstFix = resolveFixtureForBox(selList[1])
		if firstFix and firstFix.Type then
			return firstFix.Type
		end
	end
	return getSelectedFixtureName()
end

local function getAvailableParamsForDevice(devType)
	local prof = PatchEngine.Profiles[devType] or {}
	local available = {}
	local seen = {}

	local preferredOrder = DEVICE_PARAM_ORDER[devType] or {}
	for _, key in ipairs(preferredOrder) do
		if type(prof[key]) == "number" and not seen[key] then
			seen[key] = true
			table.insert(available, key)
		end
	end

	for key, val in pairs(prof) do
		if type(val) == "number" and key ~= "Span" and not seen[key] then
			seen[key] = true
			table.insert(available, key)
		end
	end

	if #available == 0 then
		table.insert(available, "X")
		table.insert(available, "Y")
	end

	return available
end

local function ensureValidActiveParam()
	local devType = getActiveDeviceType()
	local params = getAvailableParamsForDevice(devType)
	for _, k in ipairs(params) do
		if k == state.activeParamKey then
			return params
		end
	end
	state.activeParamKey = params[1]
	return params
end

local function getTargetFixtures()
	local selList = getSelectedBoxList()
	local list = {}
	if #selList > 0 then
		for _, boxIdx in ipairs(selList) do
			table.insert(list, resolveFixtureForBox(boxIdx))
		end
	else
		local total = state.addedCountByUniv[state.universe] or 0
		for idx = 1, total do
			table.insert(list, resolveFixtureForBox(idx))
		end
	end
	return list
end

local function updateBadge()
	if not addrBadge then return end
	local selList = getSelectedBoxList()
	local addrs = {}
	for _, boxIdx in ipairs(selList) do
		table.insert(addrs, tostring(resolveFixtureForBox(boxIdx).Address))
	end
	local tag = (#addrs > 0) and table.concat(addrs, ",") or tostring(state.nextAddress)
	local conn = transport.DataRemote and "OK" or ".."
	addrBadge.Text = "U" .. state.universe .. "•A[" .. tag .. "] " .. conn .. " TX:" .. transport.TxCount
end

local function setDevicesPower(isOn)
	state.devicesPowerOn = (isOn == true)
	local powerVal = state.devicesPowerOn and 255 or 0
	local targets = getTargetFixtures()
	local u = state.universe

	for _, fix in ipairs(targets) do
		if fix and fix.Channels then
			local ch = fix.Channels
			local hasDimmer = type(ch.Dimmer) == "number"
			local hasShutter = type(ch.Shutter) == "number"

			if hasDimmer then
				transport:SendChannel(u, ch.Dimmer, powerVal, true)
			end
			if hasShutter then
				transport:SendChannel(u, ch.Shutter, 0, true)
			end
			if not hasDimmer and not hasShutter and fix.Address then
				transport:SendChannel(u, fix.Address, powerVal, true)
			end
		end
	end

	updateBadge()
end

local function applyParamToSelected(paramKey, dmxVal)
	local clamped = math.clamp(math.floor(dmxVal), 0, 255)
	local u = state.universe
	local seen = {}

	for boxIdx, isSel in pairs(state.selectedBoxes) do
		if isSel then
			local fix = resolveFixtureForBox(boxIdx)
			local targetCh = fix.Channels and fix.Channels[paramKey]
			if targetCh and not seen[targetCh] then
				seen[targetCh] = true
				transport:SendChannel(u, targetCh, clamped, false)
			end
		end
	end

	updateBadge()
end

local function rebuildAllUniverses()
	for u = 1, DEFAULT_MAX_UNIVERSES do
		state.rawByUniv[u] = {}
		state.patchedByUniv[u] = {}
		state.addedCountByUniv[u] = 0
	end

	local cursors = { [1] = 1, [2] = 1 }

	for _, fix in ipairs(allRawFixtures) do
		local prof = PatchEngine.Profiles[fix.Type] or {}
		local span = math.clamp(math.floor(tonumber(prof.Span) or 8), 1, MAX_CHANNELS)
		local targetUniv = (tonumber(fix.Universe) == 2) and 2 or 1

		-- Aturan generik: kalau di Universe 1 melebihi 512 channel, otomatis lompat ke Universe 2
		if targetUniv == 1 and (cursors[1] + span - 1 > MAX_CHANNELS) then
			targetUniv = 2
		end

		if cursors[targetUniv] + span - 1 <= MAX_CHANNELS then
			local addr = cursors[targetUniv]
			cursors[targetUniv] = addr + span
			fix.Universe = targetUniv
			fix.Address = addr

			table.insert(state.rawByUniv[targetUniv], fix)
			table.insert(state.patchedByUniv[targetUniv], {
				Address = addr,
				EndAddress = addr + span - 1,
				Span = span,
				Universe = targetUniv,
				Type = fix.Type,
				Channels = buildChannelsFromProfile(addr, span, prof),
			})
			state.addedCountByUniv[targetUniv] += 1
		end
	end

	local curU = state.universe
	local curPatched = state.patchedByUniv[curU] or {}
	local highestEnd = 0
	for _, item in ipairs(curPatched) do
		if (item.EndAddress or 0) > highestEnd then
			highestEnd = item.EndAddress
		end
	end
	state.nextAddress = math.clamp(highestEnd + 1, 1, MAX_CHANNELS)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DmxConsoleSnapGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
screenGui.Parent = parentTarget

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainWindow"
mainFrame.Size = UDim2.fromOffset(WIN_W, WIN_H)
mainFrame.Position = UDim2.new(0.5, -math.floor(WIN_W / 2), 0.5, -math.floor(WIN_H / 2))
mainFrame.BackgroundColor3 = THEME.bg
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 16)
local mainStroke = Instance.new("UIStroke", mainFrame)
mainStroke.Color = THEME.stroke
mainStroke.Thickness = 1.2

-- Top Bar
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 38)
topBar.BackgroundTransparency = 1
topBar.Active = true
topBar.Parent = mainFrame

do
	local dragging = false
	local dragInput = nil
	local dragStart = Vector2.zero
	local startPos = UDim2.new()

	topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPos = mainFrame.Position
			dragInput = input
		end
	end)

	topBar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
			dragInput = input
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input == dragInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			mainFrame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

local reelIndicator = Instance.new("TextLabel")
reelIndicator.Size = UDim2.fromOffset(140, 24)
reelIndicator.Position = UDim2.fromOffset(14, 7)
reelIndicator.BackgroundTransparency = 1
reelIndicator.Text = "REEL 1/2 • SWIPE ↕"
reelIndicator.TextXAlignment = Enum.TextXAlignment.Left
reelIndicator.TextColor3 = THEME.muted
reelIndicator.TextSize = 11
reelIndicator.Font = Enum.Font.GothamBold
reelIndicator.Parent = topBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(32, 26)
minBtn.Position = UDim2.new(1, -80, 0, 6)
minBtn.BackgroundTransparency = 1
minBtn.Text = "—"
minBtn.TextColor3 = THEME.muted
minBtn.TextSize = 19
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(32, 26)
closeBtn.Position = UDim2.new(1, -42, 0, 6)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "×"
closeBtn.TextColor3 = THEME.muted
closeBtn.TextSize = 23
closeBtn.Font = Enum.Font.Gotham
closeBtn.Parent = topBar

local topLine = Instance.new("Frame")
topLine.Size = UDim2.new(1, -24, 0, 1)
topLine.Position = UDim2.fromOffset(12, 38)
topLine.BackgroundColor3 = THEME.divider
topLine.BorderSizePixel = 0
topLine.Parent = mainFrame

-- Reel Viewport
local reelViewport = Instance.new("Frame")
reelViewport.Name = "ReelViewport"
reelViewport.Size = UDim2.new(1, -24, 1, -46)
reelViewport.Position = UDim2.fromOffset(12, 42)
reelViewport.BackgroundTransparency = 1
reelViewport.ClipsDescendants = true
reelViewport.Active = true
reelViewport.Parent = mainFrame

local reelTrack = Instance.new("Frame")
reelTrack.Name = "ReelTrack"
reelTrack.Size = UDim2.new(1, 0, 2, 0)
reelTrack.Position = UDim2.fromOffset(0, 0)
reelTrack.BackgroundTransparency = 1
reelTrack.Parent = reelViewport

local reelHeight = WIN_H - 46

local function snapToReel(idx)
	local clampedIdx = math.clamp(idx, 1, 2)
	state.reelIndex = clampedIdx
	reelIndicator.Text = "REEL " .. clampedIdx .. "/2 • SWIPE ↕"
	local targetY = -(clampedIdx - 1) * reelHeight
	TweenService:Create(
		reelTrack,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(0, targetY) }
	):Play()
end

-- Gesture snap-swipe vertikal
do
	local swiping = false
	local swipeInput = nil
	local startY = 0
	local baseTrackY = 0

	reelViewport.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			swiping = true
			swipeInput = input
			startY = input.Position.Y
			baseTrackY = reelTrack.Position.Y.Offset
		end
	end)

	reelViewport.InputChanged:Connect(function(input)
		if swiping and (input == swipeInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			local deltaY = input.Position.Y - startY
			local minY = -reelHeight
			local maxY = 0
			local nextY = math.clamp(baseTrackY + deltaY, minY - 24, maxY + 24)
			reelTrack.Position = UDim2.fromOffset(0, nextY)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if swiping and (input == swipeInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			swiping = false
			local deltaY = input.Position.Y - startY
			if deltaY < -38 then
				snapToReel(state.reelIndex + 1)
			elseif deltaY > 38 then
				snapToReel(state.reelIndex - 1)
			else
				snapToReel(state.reelIndex)
			end
		end
	end)
end

-- ============================================================================
-- REEL 1: 4 TAB + GRID + PATCH / PREFERENSI / MAIN / SETTING
-- ============================================================================
local reel1 = Instance.new("Frame")
reel1.Size = UDim2.new(1, 0, 0.5, 0)
reel1.Position = UDim2.fromOffset(0, 0)
reel1.BackgroundTransparency = 1
reel1.Parent = reelTrack

local tabNames = { "patch", "Preferensi", "main", "Setting" }
local tabButtons = {}
local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1, 0, 0, 26)
tabContainer.Position = UDim2.fromOffset(0, 2)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = reel1

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Padding = UDim.new(0, 7)
tabLayout.Parent = tabContainer

local bodyFrame = Instance.new("Frame")
bodyFrame.Size = UDim2.new(1, 0, 1, -32)
bodyFrame.Position = UDim2.fromOffset(0, 32)
bodyFrame.BackgroundTransparency = 1
bodyFrame.Parent = reel1

-- Shared Channel Grid (sinkron 1:1 di patch & Preferensi)
local sharedChannelHolder = Instance.new("Frame")
sharedChannelHolder.Size = UDim2.new(1, 0, 0, 106)
sharedChannelHolder.Position = UDim2.fromOffset(0, 0)
sharedChannelHolder.BackgroundTransparency = 1
sharedChannelHolder.Parent = bodyFrame

local channelFrame = Instance.new("ScrollingFrame")
channelFrame.Name = "ChannelContainer"
channelFrame.Size = UDim2.new(1, 0, 0, 82)
channelFrame.Position = UDim2.fromOffset(0, 0)
channelFrame.BackgroundTransparency = 1
channelFrame.ScrollBarThickness = 2
channelFrame.ScrollBarImageColor3 = THEME.stroke
channelFrame.CanvasSize = UDim2.fromOffset(0, 0)
channelFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
channelFrame.Parent = sharedChannelHolder

local channelGrid = Instance.new("UIGridLayout")
channelGrid.CellSize = UDim2.fromOffset(48, 36)
channelGrid.CellPadding = UDim2.fromOffset(6, 6)
channelGrid.FillDirection = Enum.FillDirection.Horizontal
channelGrid.SortOrder = Enum.SortOrder.LayoutOrder
channelGrid.Parent = channelFrame

local pageLabel = Instance.new("TextLabel")
pageLabel.Size = UDim2.fromOffset(88, 18)
pageLabel.Position = UDim2.fromOffset(0, 86)
pageLabel.BackgroundTransparency = 1
pageLabel.Text = "page 1"
pageLabel.TextXAlignment = Enum.TextXAlignment.Left
pageLabel.TextColor3 = THEME.muted
pageLabel.TextSize = 12
pageLabel.Font = Enum.Font.Gotham
pageLabel.Parent = sharedChannelHolder

local nextPageBtn = Instance.new("TextButton")
nextPageBtn.Size = UDim2.fromOffset(96, 18)
nextPageBtn.Position = UDim2.new(1, -96, 0, 86)
nextPageBtn.BackgroundTransparency = 1
nextPageBtn.Text = "next page >"
nextPageBtn.TextXAlignment = Enum.TextXAlignment.Right
nextPageBtn.TextColor3 = THEME.muted
nextPageBtn.TextSize = 12
nextPageBtn.Font = Enum.Font.Gotham
nextPageBtn.Parent = sharedChannelHolder

-- Tab 1: Patch
local patchPage = Instance.new("Frame")
patchPage.Size = UDim2.new(1, 0, 1, -108)
patchPage.Position = UDim2.fromOffset(0, 108)
patchPage.BackgroundTransparency = 1
patchPage.Visible = true
patchPage.Parent = bodyFrame

local addFixtureBtn = Instance.new("TextButton")
addFixtureBtn.Size = UDim2.fromOffset(102, 25)
addFixtureBtn.Position = UDim2.new(1, -102, 0, 0)
addFixtureBtn.BackgroundColor3 = THEME.primary
addFixtureBtn.Text = "add fixture +"
addFixtureBtn.TextColor3 = THEME.text
addFixtureBtn.TextSize = 12
addFixtureBtn.Font = Enum.Font.GothamMedium
addFixtureBtn.BorderSizePixel = 0
addFixtureBtn.Parent = patchPage
Instance.new("UICorner", addFixtureBtn).CornerRadius = UDim.new(0, 7)

local fixtureRow = Instance.new("Frame")
fixtureRow.Size = UDim2.new(1, 0, 0, 28)
fixtureRow.Position = UDim2.fromOffset(0, 29)
fixtureRow.BackgroundColor3 = THEME.surface
fixtureRow.BorderSizePixel = 0
fixtureRow.Parent = patchPage
Instance.new("UICorner", fixtureRow).CornerRadius = UDim.new(1, 0)
local fixStroke = Instance.new("UIStroke", fixtureRow)
fixStroke.Color = THEME.stroke
fixStroke.Thickness = 1.2

local prevFixBtn = Instance.new("TextButton")
prevFixBtn.Size = UDim2.fromOffset(34, 28)
prevFixBtn.Position = UDim2.fromOffset(4, 0)
prevFixBtn.BackgroundTransparency = 1
prevFixBtn.Text = "◁"
prevFixBtn.TextColor3 = THEME.muted
prevFixBtn.TextSize = 14
prevFixBtn.Font = Enum.Font.GothamBold
prevFixBtn.Parent = fixtureRow

local fixtureNameLabel = Instance.new("TextLabel")
fixtureNameLabel.Size = UDim2.new(1, -84, 1, 0)
fixtureNameLabel.Position = UDim2.fromOffset(42, 0)
fixtureNameLabel.BackgroundTransparency = 1
fixtureNameLabel.Text = getSelectedFixtureName()
fixtureNameLabel.TextColor3 = THEME.text
fixtureNameLabel.TextSize = 12
fixtureNameLabel.Font = Enum.Font.GothamMedium
fixtureNameLabel.Parent = fixtureRow

local nextFixBtn = Instance.new("TextButton")
nextFixBtn.Size = UDim2.fromOffset(34, 28)
nextFixBtn.Position = UDim2.new(1, -38, 0, 0)
nextFixBtn.BackgroundTransparency = 1
nextFixBtn.Text = "▷"
nextFixBtn.TextColor3 = THEME.muted
nextFixBtn.TextSize = 14
nextFixBtn.Font = Enum.Font.GothamBold
nextFixBtn.Parent = fixtureRow

local function createPill(parent, yPos, isInput, textOrPlaceholder)
	local box = Instance.new(isInput and "TextBox" or "TextButton")
	box.Size = UDim2.new(1, 0, 0, 27)
	box.Position = UDim2.fromOffset(0, yPos)
	box.BackgroundColor3 = THEME.surface
	box.TextColor3 = THEME.text
	box.TextSize = 12
	box.Font = Enum.Font.GothamMedium
	box.BorderSizePixel = 0
	box.Parent = parent
	if isInput then
		box.Text = ""
		box.PlaceholderText = textOrPlaceholder
		box.PlaceholderColor3 = THEME.muted
		box.ClearTextOnFocus = false
	else
		box.Text = textOrPlaceholder
	end
	Instance.new("UICorner", box).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke", box)
	stroke.Color = THEME.stroke
	stroke.Thickness = 1.2
	return box
end

local countBox = createPill(patchPage, 61, true, "count fixture your add")
local universeBtn = createPill(patchPage, 92, false, "Universe 1")
local autoCalcBtn = createPill(patchPage, 123, false, "Auto calculate")

addrBadge = Instance.new("TextLabel")
addrBadge.Size = UDim2.fromOffset(162, 20)
addrBadge.Position = UDim2.new(1, -162, 1, -20)
addrBadge.BackgroundColor3 = THEME.badgeBg
addrBadge.Text = "U1•A[1] .. TX:0"
addrBadge.TextColor3 = THEME.text
addrBadge.TextSize = 10
addrBadge.Font = Enum.Font.GothamBold
addrBadge.BorderSizePixel = 0
addrBadge.Parent = patchPage
Instance.new("UICorner", addrBadge).CornerRadius = UDim.new(0, 6)
local badgeStroke = Instance.new("UIStroke", addrBadge)
badgeStroke.Color = THEME.stroke
badgeStroke.Thickness = 1

-- Tab 2: Preferensi (Otomatis ngikutin device: Effect/Warna/SpeedEffect | Pan/Tilt/Gobo/Prisma/dll. + fader)
local prefPage = Instance.new("Frame")
prefPage.Size = UDim2.new(1, 0, 1, -108)
prefPage.Position = UDim2.fromOffset(0, 108)
prefPage.BackgroundTransparency = 1
prefPage.Visible = false
prefPage.Parent = bodyFrame

local paramSelectorRow = Instance.new("Frame")
paramSelectorRow.Size = UDim2.new(1, -100, 0, 26)
paramSelectorRow.Position = UDim2.fromOffset(0, 8)
paramSelectorRow.BackgroundColor3 = THEME.surfaceAlt
paramSelectorRow.BorderSizePixel = 0
paramSelectorRow.Parent = prefPage
Instance.new("UICorner", paramSelectorRow).CornerRadius = UDim.new(0, 6)
local paramRowStroke = Instance.new("UIStroke", paramSelectorRow)
paramRowStroke.Color = THEME.stroke
paramRowStroke.Thickness = 1

local prevParamBtn = Instance.new("TextButton")
prevParamBtn.Size = UDim2.fromOffset(28, 26)
prevParamBtn.Position = UDim2.fromOffset(0, 0)
prevParamBtn.BackgroundTransparency = 1
prevParamBtn.Text = "◁"
prevParamBtn.TextColor3 = THEME.muted
prevParamBtn.TextSize = 13
prevParamBtn.Font = Enum.Font.GothamBold
prevParamBtn.Parent = paramSelectorRow

local activeParamLabel = Instance.new("TextButton")
activeParamLabel.Size = UDim2.new(1, -56, 1, 0)
activeParamLabel.Position = UDim2.fromOffset(28, 0)
activeParamLabel.BackgroundColor3 = THEME.accent
activeParamLabel.Text = "Pan"
activeParamLabel.TextColor3 = THEME.text
activeParamLabel.TextSize = 12
activeParamLabel.Font = Enum.Font.GothamBold
activeParamLabel.BorderSizePixel = 0
activeParamLabel.Parent = paramSelectorRow
Instance.new("UICorner", activeParamLabel).CornerRadius = UDim.new(0, 5)

local nextParamBtn = Instance.new("TextButton")
nextParamBtn.Size = UDim2.fromOffset(28, 26)
nextParamBtn.Position = UDim2.new(1, -28, 0, 0)
nextParamBtn.BackgroundTransparency = 1
nextParamBtn.Text = "▷"
nextParamBtn.TextColor3 = THEME.muted
nextParamBtn.TextSize = 13
nextParamBtn.Font = Enum.Font.GothamBold
nextParamBtn.Parent = paramSelectorRow

local numberDegLabel = Instance.new("TextLabel")
numberDegLabel.Size = UDim2.fromOffset(92, 26)
numberDegLabel.Position = UDim2.new(1, -92, 0, 8)
numberDegLabel.BackgroundColor3 = THEME.surfaceAlt
numberDegLabel.Text = "0°"
numberDegLabel.TextColor3 = THEME.text
numberDegLabel.TextSize = 12
numberDegLabel.Font = Enum.Font.GothamBold
numberDegLabel.BorderSizePixel = 0
numberDegLabel.Parent = prefPage
Instance.new("UICorner", numberDegLabel).CornerRadius = UDim.new(0, 4)
local degStroke = Instance.new("UIStroke", numberDegLabel)
degStroke.Color = THEME.stroke
degStroke.Thickness = 1

local faderHitArea = Instance.new("TextButton")
faderHitArea.Size = UDim2.new(1, 0, 0, 32)
faderHitArea.Position = UDim2.fromOffset(0, 46)
faderHitArea.BackgroundTransparency = 1
faderHitArea.Text = ""
faderHitArea.AutoButtonColor = false
faderHitArea.Parent = prefPage

local faderTrack = Instance.new("Frame")
faderTrack.Size = UDim2.new(1, 0, 0, 6)
faderTrack.Position = UDim2.fromOffset(0, 13)
faderTrack.BackgroundColor3 = THEME.track
faderTrack.BorderSizePixel = 0
faderTrack.Parent = faderHitArea
Instance.new("UICorner", faderTrack).CornerRadius = UDim.new(1, 0)

local faderThumb = Instance.new("TextButton")
faderThumb.Size = UDim2.fromOffset(36, 22)
faderThumb.Position = UDim2.fromOffset(0, -8)
faderThumb.BackgroundColor3 = THEME.accent
faderThumb.Text = ""
faderThumb.BorderSizePixel = 0
faderThumb.Parent = faderTrack
Instance.new("UICorner", faderThumb).CornerRadius = UDim.new(0, 4)

local function formatParamValueText(paramKey, ratio)
	local meta = PARAM_META[paramKey] or {}
	if meta.maxDeg then
		local degVal = math.floor(ratio * meta.maxDeg + 0.5)
		return tostring(degVal) .. "°"
	end
	return tostring(math.floor(ratio * 255 + 0.5))
end

local function syncFaderForActiveParam(sendDmx)
	ensureValidActiveParam()
	local key = state.activeParamKey
	local r = math.clamp(state.paramRatios[key] or 0, 0, 1)
	local maxOffset = math.max(1, faderTrack.AbsoluteSize.X - faderThumb.AbsoluteSize.X)
	faderThumb.Position = UDim2.fromOffset(math.floor(r * maxOffset), -8)

	local meta = PARAM_META[key] or {}
	activeParamLabel.Text = meta.label or key
	numberDegLabel.Text = formatParamValueText(key, r)

	if sendDmx then
		local dmxVal = math.floor(r * 255 + 0.5)
		applyParamToSelected(key, dmxVal)
	end
end

local function setFaderRatio(ratio)
	ensureValidActiveParam()
	local key = state.activeParamKey
	state.paramRatios[key] = math.clamp(ratio, 0, 1)
	syncFaderForActiveParam(true)
end

local function cycleParam(step)
	local params = ensureValidActiveParam()
	local curIdx = 1
	for i, k in ipairs(params) do
		if k == state.activeParamKey then
			curIdx = i
			break
		end
	end
	local nextIdx = ((curIdx - 1 + step) % #params) + 1
	state.activeParamKey = params[nextIdx]
	syncFaderForActiveParam(false)
end

do
	local sliding = false
	local slideInput = nil

	local function updateFromX(posX)
		local left = faderTrack.AbsolutePosition.X
		local width = math.max(1, faderTrack.AbsoluteSize.X)
		setFaderRatio((posX - left) / width)
	end

	local function beginSlide(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			slideInput = input
			updateFromX(input.Position.X)
		end
	end

	faderHitArea.InputBegan:Connect(beginSlide)
	faderThumb.InputBegan:Connect(beginSlide)

	UserInputService.InputEnded:Connect(function(input)
		if input == slideInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if sliding and (input == slideInput or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
			updateFromX(input.Position.X)
		end
	end)
end

-- Tab 3: main
local mainPage = Instance.new("TextLabel")
mainPage.Size = UDim2.fromScale(1, 1)
mainPage.BackgroundTransparency = 1
mainPage.TextColor3 = THEME.text
mainPage.TextSize = 13
mainPage.Font = Enum.Font.GothamMedium
mainPage.TextWrapped = true
mainPage.Visible = false
mainPage.Parent = bodyFrame

-- Tab 4: Setting
local settingPage = Instance.new("Frame")
settingPage.Size = UDim2.fromScale(1, 1)
settingPage.BackgroundTransparency = 1
settingPage.Visible = false
settingPage.Parent = bodyFrame

local devicesPowerBtn = createPill(settingPage, 8, false, "Devices Power: OFF")
local clearAllBtn = createPill(settingPage, 46, false, "Reset / Clear Patch")

-- ============================================================================
-- REEL 2: SNAP-SWIPE KE BAWAH (DEVICES POWER, RESET, & STATUS RINGKAS)
-- ============================================================================
local reel2 = Instance.new("Frame")
reel2.Size = UDim2.new(1, 0, 0.5, 0)
reel2.Position = UDim2.fromOffset(0, reelHeight)
reel2.BackgroundTransparency = 1
reel2.Parent = reelTrack

local reel2Title = Instance.new("TextLabel")
reel2Title.Size = UDim2.new(1, 0, 0, 22)
reel2Title.Position = UDim2.fromOffset(0, 4)
reel2Title.BackgroundTransparency = 1
reel2Title.Text = "QUICK DEVICES & SYSTEM"
reel2Title.TextXAlignment = Enum.TextXAlignment.Left
reel2Title.TextColor3 = THEME.muted
reel2Title.TextSize = 12
reel2Title.Font = Enum.Font.GothamBold
reel2Title.Parent = reel2

local reel2PowerBtn = createPill(reel2, 34, false, "Devices Power: OFF")
local reel2ClearBtn = createPill(reel2, 70, false, "Reset / Clear Patch")

local reel2StatusCard = Instance.new("TextLabel")
reel2StatusCard.Size = UDim2.new(1, 0, 0, 118)
reel2StatusCard.Position = UDim2.fromOffset(0, 108)
reel2StatusCard.BackgroundColor3 = THEME.surface
reel2StatusCard.TextColor3 = THEME.text
reel2StatusCard.TextSize = 12
reel2StatusCard.Font = Enum.Font.GothamMedium
reel2StatusCard.TextXAlignment = Enum.TextXAlignment.Left
reel2StatusCard.TextYAlignment = Enum.TextYAlignment.Top
reel2StatusCard.TextWrapped = true
reel2StatusCard.BorderSizePixel = 0
reel2StatusCard.Parent = reel2
Instance.new("UICorner", reel2StatusCard).CornerRadius = UDim.new(0, 10)
local cardStroke = Instance.new("UIStroke", reel2StatusCard)
cardStroke.Color = THEME.stroke
cardStroke.Thickness = 1.2

local backToReel1Btn = createPill(reel2, 236, false, "↑ Swipe / Tap Back to Reel 1")

local function syncPowerButtonStyle()
	local txt = "Devices Power: " .. (state.devicesPowerOn and "ON" or "OFF")
	local col = state.devicesPowerOn and THEME.accent or THEME.surface
	devicesPowerBtn.Text = txt
	devicesPowerBtn.BackgroundColor3 = col
	reel2PowerBtn.Text = txt
	reel2PowerBtn.BackgroundColor3 = col
end

local function toggleDevicesPower()
	setDevicesPower(not state.devicesPowerOn)
	syncPowerButtonStyle()
end

devicesPowerBtn.MouseButton1Click:Connect(toggleDevicesPower)
reel2PowerBtn.MouseButton1Click:Connect(toggleDevicesPower)
backToReel1Btn.MouseButton1Click:Connect(function()
	snapToReel(1)
end)

local function getOwnDmxFolder()
	local carModel = getOwnCarModel(player)
	if not carModel then return nil end
	local misc = carModel:FindFirstChild("Misc")
	if misc and misc:FindFirstChild("DmxLights") then
		return misc:FindFirstChild("DmxLights")
	end
	local folder = carModel:FindFirstChild("Folder")
	return (folder and folder:FindFirstChild("DmxLights")) or carModel:FindFirstChild("DmxLights", true)
end

local function refreshUI()
	fixtureNameLabel.Text = getSelectedFixtureName()
	universeBtn.Text = "Universe " .. state.universe
	pageLabel.Text = "page " .. state.page
	syncPowerButtonStyle()

	for _, child in ipairs(channelFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local totalBoxes = state.addedCountByUniv[state.universe] or 0
	if totalBoxes > 0 then
		local startIdx = (state.page - 1) * state.slotsPerPage + 1
		local endIdx = math.min(totalBoxes, state.page * state.slotsPerPage)

		for idx = startIdx, endIdx do
			local isSelected = state.selectedBoxes[idx] == true
			local card = Instance.new("TextButton")
			card.Name = "Box_" .. idx
			card.LayoutOrder = idx - startIdx + 1
			card.BackgroundColor3 = isSelected and THEME.accent or THEME.surface
			card.Text = tostring(idx)
			card.TextColor3 = isSelected and THEME.text or THEME.muted
			card.TextSize = 13
			card.Font = Enum.Font.GothamBold
			card.BorderSizePixel = 0
			card.Parent = channelFrame

			Instance.new("UICorner", card).CornerRadius = UDim.new(0, 7)
			local stroke = Instance.new("UIStroke", card)
			stroke.Color = isSelected and THEME.accent or THEME.stroke
			stroke.Thickness = 1.2

			-- Klik kotak hanya select/deselect; tidak langsung menyalakan device
			card.MouseButton1Click:Connect(function()
				state.selectedBoxes[idx] = not state.selectedBoxes[idx]
				refreshUI()
			end)
		end
	end

	syncFaderForActiveParam(false)

	updateBadge()
	local selList = getSelectedBoxList()
	local addrs = {}
	for _, boxIdx in ipairs(selList) do
		table.insert(addrs, tostring(resolveFixtureForBox(boxIdx).Address))
	end
	local activeDev = getActiveDeviceType()
	local statusStr = "Universe: U" .. state.universe .. (state.universe == 2 and " (512B)" or " (3B)")
		.. "\nDevice: " .. activeDev
		.. "\nSelected Box: " .. ((#selList > 0) and table.concat(selList, ", ") or "None")
		.. "\nStart Addr: " .. ((#addrs > 0) and table.concat(addrs, ", ") or "None")
		.. "\nDevices Power: " .. (state.devicesPowerOn and "ON" or "OFF")

	mainPage.Text = statusStr
	reel2StatusCard.Text = "  " .. string.gsub(statusStr, "\n", "\n  ")
end

for _, tName in ipairs(tabNames) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(76, 26)
	btn.Text = tName
	btn.TextSize = 12
	btn.Font = Enum.Font.GothamMedium
	btn.BorderSizePixel = 0
	btn.Parent = tabContainer
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	tabButtons[tName] = btn

	btn.MouseButton1Click:Connect(function()
		state.activeTab = tName
		for name, b in pairs(tabButtons) do
			local active = (name == tName)
			b.BackgroundColor3 = active and THEME.accent or THEME.surfaceAlt
			b.TextColor3 = active and THEME.text or THEME.muted
		end
		sharedChannelHolder.Visible = (tName == "patch" or tName == "Preferensi")
		patchPage.Visible = (tName == "patch")
		prefPage.Visible = (tName == "Preferensi")
		mainPage.Visible = (tName == "main")
		settingPage.Visible = (tName == "Setting")
		if tName == "Preferensi" then
			task.defer(function()
				syncFaderForActiveParam(false)
			end)
		end
	end)
end

for name, b in pairs(tabButtons) do
	local active = (name == state.activeTab)
	b.BackgroundColor3 = active and THEME.accent or THEME.surfaceAlt
	b.TextColor3 = active and THEME.text or THEME.muted
end

prevFixBtn.MouseButton1Click:Connect(function()
	state.fixtureIndex = ((state.fixtureIndex - 2) % #fixtureNames) + 1
	refreshUI()
end)

nextFixBtn.MouseButton1Click:Connect(function()
	state.fixtureIndex = (state.fixtureIndex % #fixtureNames) + 1
	refreshUI()
end)

universeBtn.MouseButton1Click:Connect(function()
	state.universe = (state.universe == 1) and 2 or 1
	state.page = 1
	state.selectedBoxes = {}
	rebuildAllUniverses()
	refreshUI()
end)

autoCalcBtn.MouseButton1Click:Connect(function()
	local dmxFolder = getOwnDmxFolder()
	local keys = NameAliases[getSelectedFixtureName()] or { string.lower(getSelectedFixtureName()) }
	local found = 0
	if dmxFolder then
		for _, desc in ipairs(dmxFolder:GetDescendants()) do
			if matchesAnyKey(desc.Name, keys) then
				found += 1
			end
		end
	end
	countBox.Text = tostring(found)
end)

addFixtureBtn.MouseButton1Click:Connect(function()
	local qty = math.max(1, math.floor(tonumber(countBox.Text) or 1))
	local fixName = getSelectedFixtureName()
	for _ = 1, qty do
		table.insert(allRawFixtures, {
			Type = fixName,
			Universe = state.universe,
		})
	end

	rebuildAllUniverses()
	refreshUI()
end)

nextPageBtn.MouseButton1Click:Connect(function()
	local totalBoxes = state.addedCountByUniv[state.universe] or 0
	local totalPages = math.max(1, math.ceil(totalBoxes / state.slotsPerPage))
	state.page = (state.page % totalPages) + 1
	refreshUI()
end)

prevParamBtn.MouseButton1Click:Connect(function()
	cycleParam(-1)
end)

nextParamBtn.MouseButton1Click:Connect(function()
	cycleParam(1)
end)

activeParamLabel.MouseButton1Click:Connect(function()
	cycleParam(1)
end)

local function resetPatchState()
	allRawFixtures = {}
	for u = 1, DEFAULT_MAX_UNIVERSES do
		state.rawByUniv[u] = {}
		state.patchedByUniv[u] = {}
		state.addedCountByUniv[u] = 0
		transport:ClearUniverse(u)
	end
	state.selectedBoxes = {}
	state.devicesPowerOn = false
	state.paramRatios = {}
	state.nextAddress = 1
	state.page = 1
	refreshUI()
end

clearAllBtn.MouseButton1Click:Connect(resetPatchState)
reel2ClearBtn.MouseButton1Click:Connect(resetPatchState)

minBtn.MouseButton1Click:Connect(function()
	local collapsed = mainFrame.Size.Y.Offset <= 46
	mainFrame.Size = collapsed and UDim2.fromOffset(WIN_W, WIN_H) or UDim2.fromOffset(WIN_W, 42)
	reelViewport.Visible = collapsed
	reelIndicator.Visible = collapsed
end)

closeBtn.MouseButton1Click:Connect(function()
	if screenGui then
		screenGui:Destroy()
	end
end)

refreshUI()
