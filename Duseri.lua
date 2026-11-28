--!strict
-- DMX Controller UI (350x340) - Synced With Working Tes_Beam_UDP_DMXDATA Logic

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
local parentGui = (gethui and gethui()) or player:WaitForChild("PlayerGui")

local MAX_CHANNELS = 512
local MIN_VALUE = 0
local MAX_VALUE = 255
local SEND_THROTTLE = 0.03

--// Remote Resolver (Same priority as Tes_Beam_UDP_DMXDATA)
local function isDmxRemote(obj: Instance): boolean
	return obj:IsA("RemoteEvent") or obj:IsA("UnreliableRemoteEvent")
end

local function getOwnCar(): Instance?
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if not vehicles then
		return nil
	end
	local lp = string.lower(player.Name)
	for _, c in ipairs(vehicles:GetChildren()) do
		if c.Name == player.Name .. "'s Car" or string.find(string.lower(c.Name), lp, 1, true) then
			return c
		end
	end
	return nil
end

local function findUdpDmxRemote(): (any, string)
	local car = getOwnCar()
	if car then
		local r = car:FindFirstChild("UDP_DMXDATA", true)
		if r and isDmxRemote(r) then
			return r, "CAR:" .. car.Name
		end
	end

	local rRs = ReplicatedStorage:FindFirstChild("UDP_DMXDATA", true)
	if rRs and isDmxRemote(rRs) then
		return rRs, "RS"
	end

	local rWs = Workspace:FindFirstChild("UDP_DMXDATA", true)
	if rWs and isDmxRemote(rWs) then
		return rWs, "WS"
	end

	return nil, "UDP_DMXDATA tidak ditemukan"
end

local udpRemote: any, remoteSrc: string = findUdpDmxRemote()

task.spawn(function()
	local vehicles = Workspace:FindFirstChild("Vehicles") or Workspace:WaitForChild("Vehicles", 30)
	if not udpRemote then
		udpRemote, remoteSrc = findUdpDmxRemote()
	end
	if vehicles then
		vehicles.ChildAdded:Connect(function()
			task.wait(0.15)
			local r, src = findUdpDmxRemote()
			if r then
				udpRemote, remoteSrc = r, src
			end
		end)
	end
end)

--// Fixture Profiles (Offset relative to Address: Address=1 -> CH 1=Pan, CH 2=Tilt, CH 7=Shutter, CH 8=Dimmer)
local BarWashProfile = {
	Group = "BarWash",
	Span = 8,
	Dimmer = 7,
	Shutter = 6,
	Red = 2,
	Green = 3,
	Blue = 4,
	Effect = 5,
	Effect2 = 6,
	Speed = 7,
}

local DEVICE_PROFILES: { [string]: { [string]: any } } = {
	["ClaraS14"] = {
		Group = "MovingHead",
		Span = 16,
		Pan = 0,     -- Address + 0 (CH 1)
		Tilt = 1,    -- Address + 1 (CH 2)
		Shutter = 6, -- Address + 6 (CH 7)
		Dimmer = 7,  -- Address + 7 (CH 8)
		Color = 2,
		Gobo = 3,
		Prism = 4,
		Focus = 5,
		Speed = 8,
	},
	["Wallwasher_24X3W"] = BarWashProfile,
	["StrobeBar_192_Segment"] = BarWashProfile,
	["STROBE_1000W"] = {
		Group = "Strobe1000W",
		Span = 8,
		Shutter = 6,
		Dimmer = 7,
		Effect = 4,
		Effect2 = 5,
		Speed = 8,
	},
	["Parled"] = {
		Group = "Parled",
		Span = 8,
		Red = 1,
		Green = 2,
		Blue = 3,
		White = 4,
		Shutter = 6,
		Dimmer = 7,
	},
	["Blinder"] = {
		Group = "Blinder",
		Span = 8,
		Red = 1,
		Green = 2,
		Blue = 3,
		Shutter = 6,
		Dimmer = 7,
		Effect = 4,
		Speed = 5,
	},
}

local DEVICE_PARAM_ORDER: { [string]: { string } } = {
	["ClaraS14"] = { "Dimmer", "Shutter", "Pan", "Tilt", "Color", "Gobo", "Prism", "Focus", "Speed" },
	["Wallwasher_24X3W"] = { "Dimmer", "Shutter", "Red", "Green", "Blue", "Effect", "Effect2", "Speed" },
	["StrobeBar_192_Segment"] = { "Dimmer", "Shutter", "Red", "Green", "Blue", "Effect", "Effect2", "Speed" },
	["STROBE_1000W"] = { "Dimmer", "Shutter", "Effect", "Effect2", "Speed" },
	["Parled"] = { "Dimmer", "Shutter", "Red", "Green", "Blue", "White" },
	["Blinder"] = { "Dimmer", "Shutter", "Red", "Green", "Blue", "Effect", "Speed" },
}

local PARAM_META: { [string]: { label: string, kind: string } } = {
	Dimmer = { label = "Dimmer", kind = "percent" },
	Shutter = { label = "Strobe", kind = "dmx" },
	Red = { label = "Warna R", kind = "dmx" },
	Green = { label = "Warna G", kind = "dmx" },
	Blue = { label = "Warna B", kind = "dmx" },
	White = { label = "Warna W", kind = "dmx" },
	Effect = { label = "Effect", kind = "dmx" },
	Effect2 = { label = "Effect2", kind = "dmx" },
	Speed = { label = "SpeedEffect", kind = "dmx" },
	Pan = { label = "Pan", kind = "pan" },
	Tilt = { label = "Tilt", kind = "tilt" },
	Color = { label = "Color", kind = "dmx" },
	Gobo = { label = "Gobo", kind = "dmx" },
	Prism = { label = "Prism", kind = "dmx" },
	Focus = { label = "Focus", kind = "dmx" },
}

local AVAILABLE_DEVICE_TYPES = {
	"ClaraS14",
	"Wallwasher_24X3W",
	"StrobeBar_192_Segment",
	"STROBE_1000W",
	"Parled",
	"Blinder",
}

local function getShortTag(devType: string): string
	local s = string.lower(devType)
	if string.find(s, "clara", 1, true) then return "CL" end
	if string.find(s, "wallwasher", 1, true) then return "WW" end
	if string.find(s, "strobebar", 1, true) then return "SB" end
	if string.find(s, "strobe", 1, true) then return "ST" end
	if string.find(s, "parled", 1, true) then return "PL" end
	if string.find(s, "blinder", 1, true) then return "BL" end
	return string.upper(string.sub(devType, 1, 2))
end

local function getProfile(devType: string): { [string]: any }
	return DEVICE_PROFILES[devType] or {
		Group = "Generic",
		Span = 8,
		Dimmer = 7,
		Shutter = 6,
	}
end

local function getParamListForDevice(devType: string): { string }
	local custom = DEVICE_PARAM_ORDER[devType]
	if custom then
		return custom
	end
	local prof = getProfile(devType)
	local out = {}
	for key, val in pairs(prof) do
		if key ~= "Group" and key ~= "Span" and type(val) == "number" then
			table.insert(out, key)
		end
	end
	table.sort(out, function(a, b)
		return prof[a] < prof[b]
	end)
	return out
end

type PatchedItem = {
	Index: number,
	Type: string,
	Address: number,
	EndAddress: number,
	Profile: { [string]: any },
}

local state = {
	universe = 1,
	addDeviceIdx = 1,
	patchedByUniv = {} :: { [number]: { PatchedItem } },
	selectedIndices = {} :: { [number]: boolean },
	activeBoxIndex = nil :: number?,
	activeParam = "Dimmer",
	paramRatios = {
		Dimmer = 0,
		Shutter = 0,
		Red = 0,
		Green = 0,
		Blue = 0,
		White = 0,
		Effect = 0,
		Effect2 = 0,
		Speed = 0,
		Pan = 0.5,
		Tilt = 43 / 255,
		Color = 0,
		Gobo = 0,
		Prism = 0,
		Focus = 0,
	} :: { [string]: number },
	univBuffers = {} :: { [number]: buffer },
	lastSendTime = {} :: { [string]: number },
	lastSentVal = {} :: { [string]: number },
}

local function ensureUniverse(univ: number)
	if not state.patchedByUniv[univ] then
		state.patchedByUniv[univ] = {}
	end
	if not state.univBuffers[univ] then
		state.univBuffers[univ] = buffer.create(MAX_CHANNELS)
	end
end

ensureUniverse(1)
ensureUniverse(2)

local function rebuildAllUniverses()
	for univ, buf in pairs(state.univBuffers) do
		buffer.fill(buf, 0, 0, MAX_CHANNELS)
		local list = state.patchedByUniv[univ] or {}
		for _, item in ipairs(list) do
			local prof = item.Profile
			for key, offset in pairs(prof) do
				if key ~= "Group" and key ~= "Span" and type(offset) == "number" then
					local ch = item.Address + offset
					if ch >= 1 and ch <= MAX_CHANNELS then
						local ratio = state.paramRatios[key] or 0
						local val = math.clamp(math.floor(ratio * MAX_VALUE + 0.5), MIN_VALUE, MAX_VALUE)
						buffer.writeu8(buf, ch - 1, val)
					end
				end
			end
		end
	end
end

local function patchDevice(devType: string)
	local prof = getProfile(devType)
	local span: number = prof.Span or 8
	local targetUniv = state.universe
	ensureUniverse(targetUniv)

	local list = state.patchedByUniv[targetUniv]
	local startAddr = 1
	if #list > 0 then
		startAddr = list[#list].EndAddress + 1
	end
	local endAddr = startAddr + span - 1

	if endAddr > MAX_CHANNELS then
		targetUniv = targetUniv + 1
		ensureUniverse(targetUniv)
		list = state.patchedByUniv[targetUniv]
		startAddr = (#list > 0) and (list[#list].EndAddress + 1) or 1
		endAddr = startAddr + span - 1
	end

	local item: PatchedItem = {
		Index = #list + 1,
		Type = devType,
		Address = startAddr,
		EndAddress = endAddr,
		Profile = prof,
	}
	table.insert(list, item)
	state.universe = targetUniv
	state.selectedIndices = { [item.Index] = true }
	state.activeBoxIndex = item.Index
	rebuildAllUniverses()
end

local function sendChannelValue(univ: number, channel: number, rawVal: number, bypassThrottle: boolean?)
	if channel < 1 or channel > MAX_CHANNELS then
		return
	end

	local val = math.clamp(math.floor(rawVal + 0.5), MIN_VALUE, MAX_VALUE)
	ensureUniverse(univ)
	buffer.writeu8(state.univBuffers[univ], channel - 1, val)

	local key = tostring(univ) .. ":" .. tostring(channel)
	local now = os.clock()
	local lastT = state.lastSendTime[key] or 0
	local lastV = state.lastSentVal[key]

	if not bypassThrottle then
		if lastV == val then
			return
		end
		if (now - lastT) < SEND_THROTTLE then
			return
		end
	end

	state.lastSendTime[key] = now
	state.lastSentVal[key] = val

	if not udpRemote then
		udpRemote, remoteSrc = findUdpDmxRemote()
	end

	if udpRemote then
		local buf = buffer.create(3)
		buffer.writeu16(buf, 0, channel)
		buffer.writeu8(buf, 2, val)
		pcall(function()
			udpRemote:FireServer(buf)
		end)
	end
end

--// UI Construction (350x340)
local existingGui = parentGui:FindFirstChild("DMXController350x340")
if existingGui then
	existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DMXController350x340"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = parentGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.fromOffset(350, 340)
mainFrame.Position = UDim2.new(0.5, -175, 0.5, -170)
mainFrame.BackgroundColor3 = Color3.fromRGB(16, 19, 26)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(45, 55, 75)
mainStroke.Thickness = 1
mainStroke.Parent = mainFrame

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 34)
header.BackgroundColor3 = Color3.fromRGB(23, 28, 38)
header.BorderSizePixel = 0
header.Active = true
header.Parent = mainFrame
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 122, 1, 0)
titleLabel.Position = UDim2.fromOffset(10, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "DMX 512 • 350x340"
titleLabel.TextColor3 = Color3.fromRGB(235, 240, 250)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 11
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local addrBadge = Instance.new("TextLabel")
addrBadge.Name = "AddrBadge"
addrBadge.Size = UDim2.new(0, 156, 1, 0)
addrBadge.Position = UDim2.fromOffset(132, 0)
addrBadge.BackgroundTransparency = 1
addrBadge.Text = "U1 • Kosong"
addrBadge.TextColor3 = Color3.fromRGB(120, 200, 255)
addrBadge.Font = Enum.Font.GothamMedium
addrBadge.TextSize = 10
addrBadge.TextTruncate = Enum.TextTruncate.AtEnd
addrBadge.TextXAlignment = Enum.TextXAlignment.Right
addrBadge.Parent = header

local minBtn = Instance.new("TextButton")
minBtn.Name = "MinimizeBtn"
minBtn.Size = UDim2.fromOffset(22, 22)
minBtn.Position = UDim2.new(1, -54, 0.5, -11)
minBtn.BackgroundColor3 = Color3.fromRGB(40, 48, 64)
minBtn.Text = "-"
minBtn.TextColor3 = Color3.fromRGB(235, 242, 255)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 14
minBtn.BorderSizePixel = 0
minBtn.Active = true
minBtn.Parent = header
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.fromOffset(22, 22)
closeBtn.Position = UDim2.new(1, -28, 0.5, -11)
closeBtn.BackgroundColor3 = Color3.fromRGB(145, 38, 48)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 11
closeBtn.BorderSizePixel = 0
closeBtn.Active = true
closeBtn.Parent = header
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 26)
tabBar.Position = UDim2.fromOffset(8, 38)
tabBar.BackgroundColor3 = Color3.fromRGB(22, 26, 35)
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame
Instance.new("UICorner", tabBar).CornerRadius = UDim.new(0, 6)

local function makeTabBtn(text: string, xOffset: number): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.5, -4, 1, -4)
	btn.Position = UDim2.fromOffset(xOffset, 2)
	btn.BackgroundColor3 = Color3.fromRGB(35, 42, 56)
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(240, 245, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.BorderSizePixel = 0
	btn.Parent = tabBar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)
	return btn
end

local tabPrefBtn = makeTabBtn("Preferensi", 2)
local tabReel2Btn = makeTabBtn("Reel 2", 171)

local pagesViewport = Instance.new("Frame")
pagesViewport.Size = UDim2.new(1, -16, 0, 266)
pagesViewport.Position = UDim2.fromOffset(8, 68)
pagesViewport.BackgroundTransparency = 1
pagesViewport.ClipsDescendants = true
pagesViewport.Parent = mainFrame

local pagesTrack = Instance.new("Frame")
pagesTrack.Size = UDim2.new(2, 0, 1, 0)
pagesTrack.Position = UDim2.fromScale(0, 0)
pagesTrack.BackgroundTransparency = 1
pagesTrack.Parent = pagesViewport

local pagePref = Instance.new("Frame")
pagePref.Size = UDim2.new(0.5, 0, 1, 0)
pagePref.Position = UDim2.fromScale(0, 0)
pagePref.BackgroundTransparency = 1
pagePref.Parent = pagesTrack

local pageReel2 = Instance.new("Frame")
pageReel2.Size = UDim2.new(0.5, 0, 1, 0)
pageReel2.Position = UDim2.fromScale(0.5, 0)
pageReel2.BackgroundTransparency = 1
pageReel2.Parent = pagesTrack

local currentPageIndex = 0

local function snapToPage(idx: number)
	currentPageIndex = math.clamp(idx, 0, 1)
	local targetPos = UDim2.fromScale(-currentPageIndex, 0)
	TweenService:Create(pagesTrack, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = targetPos,
	}):Play()

	if currentPageIndex == 0 then
		tabPrefBtn.BackgroundColor3 = Color3.fromRGB(48, 92, 165)
		tabReel2Btn.BackgroundColor3 = Color3.fromRGB(30, 35, 46)
	else
		tabPrefBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 46)
		tabReel2Btn.BackgroundColor3 = Color3.fromRGB(48, 92, 165)
	end
end

tabPrefBtn.MouseButton1Click:Connect(function() snapToPage(0) end)
tabReel2Btn.MouseButton1Click:Connect(function() snapToPage(1) end)

local isMinimized = false
minBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	tabBar.Visible = not isMinimized
	pagesViewport.Visible = not isMinimized
	mainFrame.Size = isMinimized and UDim2.fromOffset(350, 34) or UDim2.fromOffset(350, 340)
	minBtn.Text = isMinimized and "+" or "-"
end)

closeBtn.MouseButton1Click:Connect(function()
	screenGui:Destroy()
end)

do
	local dragging = false
	local dragStart = Vector2.zero
	local startPos = UDim2.new()

	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPos = mainFrame.Position
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
			mainFrame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end

--// PAGE 1: PREFERENSI
local devPrevBtn = Instance.new("TextButton")
devPrevBtn.Size = UDim2.fromOffset(24, 24)
devPrevBtn.Position = UDim2.fromOffset(0, 0)
devPrevBtn.BackgroundColor3 = Color3.fromRGB(32, 38, 50)
devPrevBtn.Text = "<"
devPrevBtn.TextColor3 = Color3.fromRGB(220, 230, 245)
devPrevBtn.Font = Enum.Font.GothamBold
devPrevBtn.TextSize = 12
devPrevBtn.BorderSizePixel = 0
devPrevBtn.Parent = pagePref
Instance.new("UICorner", devPrevBtn).CornerRadius = UDim.new(0, 5)

local devTypeLabel = Instance.new("TextButton")
devTypeLabel.Size = UDim2.fromOffset(174, 24)
devTypeLabel.Position = UDim2.fromOffset(28, 0)
devTypeLabel.BackgroundColor3 = Color3.fromRGB(26, 31, 41)
devTypeLabel.Text = AVAILABLE_DEVICE_TYPES[state.addDeviceIdx]
devTypeLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
devTypeLabel.Font = Enum.Font.GothamBold
devTypeLabel.TextSize = 11
devTypeLabel.BorderSizePixel = 0
devTypeLabel.Parent = pagePref
Instance.new("UICorner", devTypeLabel).CornerRadius = UDim.new(0, 5)

local devNextBtn = Instance.new("TextButton")
devNextBtn.Size = UDim2.fromOffset(24, 24)
devNextBtn.Position = UDim2.fromOffset(206, 0)
devNextBtn.BackgroundColor3 = Color3.fromRGB(32, 38, 50)
devNextBtn.Text = ">"
devNextBtn.TextColor3 = Color3.fromRGB(220, 230, 245)
devNextBtn.Font = Enum.Font.GothamBold
devNextBtn.TextSize = 12
devNextBtn.BorderSizePixel = 0
devNextBtn.Parent = pagePref
Instance.new("UICorner", devNextBtn).CornerRadius = UDim.new(0, 5)

local addFixtureBtn = Instance.new("TextButton")
addFixtureBtn.Size = UDim2.fromOffset(58, 24)
addFixtureBtn.Position = UDim2.fromOffset(234, 0)
addFixtureBtn.BackgroundColor3 = Color3.fromRGB(42, 130, 88)
addFixtureBtn.Text = "+ Patch"
addFixtureBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
addFixtureBtn.Font = Enum.Font.GothamBold
addFixtureBtn.TextSize = 11
addFixtureBtn.BorderSizePixel = 0
addFixtureBtn.Parent = pagePref
Instance.new("UICorner", addFixtureBtn).CornerRadius = UDim.new(0, 5)

local univBtn = Instance.new("TextButton")
univBtn.Size = UDim2.fromOffset(38, 24)
univBtn.Position = UDim2.fromOffset(296, 0)
univBtn.BackgroundColor3 = Color3.fromRGB(45, 54, 72)
univBtn.Text = "U1"
univBtn.TextColor3 = Color3.fromRGB(150, 215, 255)
univBtn.Font = Enum.Font.GothamBold
univBtn.TextSize = 11
univBtn.BorderSizePixel = 0
univBtn.Parent = pagePref
Instance.new("UICorner", univBtn).CornerRadius = UDim.new(0, 5)

local patchSummaryLabel = Instance.new("TextLabel")
patchSummaryLabel.Size = UDim2.new(1, 0, 0, 18)
patchSummaryLabel.Position = UDim2.fromOffset(0, 27)
patchSummaryLabel.BackgroundTransparency = 1
patchSummaryLabel.Text = "Patch: Kosong"
patchSummaryLabel.TextColor3 = Color3.fromRGB(165, 178, 200)
patchSummaryLabel.Font = Enum.Font.GothamMedium
patchSummaryLabel.TextSize = 10
patchSummaryLabel.TextTruncate = Enum.TextTruncate.AtEnd
patchSummaryLabel.TextXAlignment = Enum.TextXAlignment.Left
patchSummaryLabel.Parent = pagePref

local gridFrame = Instance.new("ScrollingFrame")
gridFrame.Size = UDim2.new(1, 0, 0, 96)
gridFrame.Position = UDim2.fromOffset(0, 47)
gridFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 33)
gridFrame.BorderSizePixel = 0
gridFrame.ScrollBarThickness = 3
gridFrame.CanvasSize = UDim2.fromOffset(0, 0)
gridFrame.Parent = pagePref
Instance.new("UICorner", gridFrame).CornerRadius = UDim.new(0, 6)

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(62, 38)
gridLayout.CellPadding = UDim2.fromOffset(4, 4)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local gridPadding = Instance.new("UIPadding")
gridPadding.PaddingTop = UDim.new(0, 4)
gridPadding.PaddingLeft = UDim.new(0, 4)
gridPadding.PaddingRight = UDim.new(0, 4)
gridPadding.PaddingBottom = UDim.new(0, 4)
gridPadding.Parent = gridFrame

gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	gridFrame.CanvasSize = UDim2.fromOffset(0, gridLayout.AbsoluteContentSize.Y + 8)
end)

local paramPrevBtn = Instance.new("TextButton")
paramPrevBtn.Size = UDim2.fromOffset(36, 26)
paramPrevBtn.Position = UDim2.fromOffset(0, 150)
paramPrevBtn.BackgroundColor3 = Color3.fromRGB(32, 38, 50)
paramPrevBtn.Text = "◁"
paramPrevBtn.TextColor3 = Color3.fromRGB(230, 238, 250)
paramPrevBtn.Font = Enum.Font.GothamBold
paramPrevBtn.TextSize = 12
paramPrevBtn.BorderSizePixel = 0
paramPrevBtn.Parent = pagePref
Instance.new("UICorner", paramPrevBtn).CornerRadius = UDim.new(0, 5)

local paramPillBtn = Instance.new("TextButton")
paramPillBtn.Size = UDim2.fromOffset(262, 26)
paramPillBtn.Position = UDim2.fromOffset(40, 150)
paramPillBtn.BackgroundColor3 = Color3.fromRGB(28, 34, 46)
paramPillBtn.Text = "Dimmer [Ch.8]"
paramPillBtn.TextColor3 = Color3.fromRGB(130, 215, 255)
paramPillBtn.Font = Enum.Font.GothamBold
paramPillBtn.TextSize = 11
paramPillBtn.BorderSizePixel = 0
paramPillBtn.Parent = pagePref
Instance.new("UICorner", paramPillBtn).CornerRadius = UDim.new(0, 5)

local paramNextBtn = Instance.new("TextButton")
paramNextBtn.Size = UDim2.fromOffset(32, 26)
paramNextBtn.Position = UDim2.fromOffset(306, 150)
paramNextBtn.BackgroundColor3 = Color3.fromRGB(32, 38, 50)
paramNextBtn.Text = "▷"
paramNextBtn.TextColor3 = Color3.fromRGB(230, 238, 250)
paramNextBtn.Font = Enum.Font.GothamBold
paramNextBtn.TextSize = 12
paramNextBtn.BorderSizePixel = 0
paramNextBtn.Parent = pagePref
Instance.new("UICorner", paramNextBtn).CornerRadius = UDim.new(0, 5)

local faderTrack = Instance.new("Frame")
faderTrack.Size = UDim2.new(1, 0, 0, 36)
faderTrack.Position = UDim2.fromOffset(0, 183)
faderTrack.BackgroundColor3 = Color3.fromRGB(25, 30, 41)
faderTrack.BorderSizePixel = 0
faderTrack.Active = true
faderTrack.Parent = pagePref
Instance.new("UICorner", faderTrack).CornerRadius = UDim.new(0, 6)

local faderFill = Instance.new("Frame")
faderFill.Size = UDim2.new(0, 0, 1, 0)
faderFill.BackgroundColor3 = Color3.fromRGB(58, 125, 220)
faderFill.BorderSizePixel = 0
faderFill.Parent = faderTrack
Instance.new("UICorner", faderFill).CornerRadius = UDim.new(0, 6)

local faderValueLabel = Instance.new("TextLabel")
faderValueLabel.Size = UDim2.new(1, -12, 1, 0)
faderValueLabel.Position = UDim2.fromOffset(6, 0)
faderValueLabel.BackgroundTransparency = 1
faderValueLabel.Text = "0 (0%)"
faderValueLabel.TextColor3 = Color3.fromRGB(245, 248, 255)
faderValueLabel.Font = Enum.Font.GothamBold
faderValueLabel.TextSize = 12
faderValueLabel.TextXAlignment = Enum.TextXAlignment.Right
faderValueLabel.Parent = faderTrack

local zeroBtn = Instance.new("TextButton")
zeroBtn.Size = UDim2.fromOffset(108, 30)
zeroBtn.Position = UDim2.fromOffset(0, 228)
zeroBtn.BackgroundColor3 = Color3.fromRGB(48, 34, 38)
zeroBtn.Text = "Zero Param"
zeroBtn.TextColor3 = Color3.fromRGB(255, 165, 175)
zeroBtn.Font = Enum.Font.GothamBold
zeroBtn.TextSize = 11
zeroBtn.BorderSizePixel = 0
zeroBtn.Parent = pagePref
Instance.new("UICorner", zeroBtn).CornerRadius = UDim.new(0, 6)

local fullBtn = Instance.new("TextButton")
fullBtn.Size = UDim2.fromOffset(108, 30)
fullBtn.Position = UDim2.fromOffset(115, 228)
fullBtn.BackgroundColor3 = Color3.fromRGB(32, 54, 46)
fullBtn.Text = "Full (255)"
fullBtn.TextColor3 = Color3.fromRGB(150, 255, 195)
fullBtn.Font = Enum.Font.GothamBold
fullBtn.TextSize = 11
fullBtn.BorderSizePixel = 0
fullBtn.Parent = pagePref
Instance.new("UICorner", fullBtn).CornerRadius = UDim.new(0, 6)

local selectAllBtn = Instance.new("TextButton")
selectAllBtn.Size = UDim2.fromOffset(108, 30)
selectAllBtn.Position = UDim2.fromOffset(230, 228)
selectAllBtn.BackgroundColor3 = Color3.fromRGB(36, 44, 60)
selectAllBtn.Text = "Select All"
selectAllBtn.TextColor3 = Color3.fromRGB(210, 225, 248)
selectAllBtn.Font = Enum.Font.GothamBold
selectAllBtn.TextSize = 11
selectAllBtn.BorderSizePixel = 0
selectAllBtn.Parent = pagePref
Instance.new("UICorner", selectAllBtn).CornerRadius = UDim.new(0, 6)

--// PAGE 2: REEL 2
local reelTitle = Instance.new("TextLabel")
reelTitle.Size = UDim2.new(1, 0, 0, 20)
reelTitle.Position = UDim2.fromOffset(0, 0)
reelTitle.BackgroundTransparency = 1
reelTitle.Text = "REEL 2 • MASTER & PATCH LIST"
reelTitle.TextColor3 = Color3.fromRGB(220, 232, 248)
reelTitle.Font = Enum.Font.GothamBold
reelTitle.TextSize = 11
reelTitle.TextXAlignment = Enum.TextXAlignment.Left
reelTitle.Parent = pageReel2

local blackoutBtn = Instance.new("TextButton")
blackoutBtn.Size = UDim2.fromOffset(162, 28)
blackoutBtn.Position = UDim2.fromOffset(0, 24)
blackoutBtn.BackgroundColor3 = Color3.fromRGB(135, 34, 42)
blackoutBtn.Text = "BLACKOUT (0)"
blackoutBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
blackoutBtn.Font = Enum.Font.GothamBold
blackoutBtn.TextSize = 11
blackoutBtn.BorderSizePixel = 0
blackoutBtn.Parent = pageReel2
Instance.new("UICorner", blackoutBtn).CornerRadius = UDim.new(0, 6)

local masterFullBtn = Instance.new("TextButton")
masterFullBtn.Size = UDim2.fromOffset(164, 28)
masterFullBtn.Position = UDim2.fromOffset(170, 24)
masterFullBtn.BackgroundColor3 = Color3.fromRGB(38, 92, 168)
masterFullBtn.Text = "ALL DIMMER 255"
masterFullBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
masterFullBtn.Font = Enum.Font.GothamBold
masterFullBtn.TextSize = 11
masterFullBtn.BorderSizePixel = 0
masterFullBtn.Parent = pageReel2
Instance.new("UICorner", masterFullBtn).CornerRadius = UDim.new(0, 6)

local clearAllBtn = Instance.new("TextButton")
clearAllBtn.Size = UDim2.new(1, 0, 0, 26)
clearAllBtn.Position = UDim2.fromOffset(0, 56)
clearAllBtn.BackgroundColor3 = Color3.fromRGB(76, 28, 36)
clearAllBtn.Text = "HAPUS SEMUA FIXTURE (UNIVERSE AKTIF)"
clearAllBtn.TextColor3 = Color3.fromRGB(255, 180, 185)
clearAllBtn.Font = Enum.Font.GothamBold
clearAllBtn.TextSize = 11
clearAllBtn.BorderSizePixel = 0
clearAllBtn.Parent = pageReel2
Instance.new("UICorner", clearAllBtn).CornerRadius = UDim.new(0, 6)

local patchDetailBox = Instance.new("TextLabel")
patchDetailBox.Size = UDim2.new(1, 0, 0, 178)
patchDetailBox.Position = UDim2.fromOffset(0, 88)
patchDetailBox.BackgroundColor3 = Color3.fromRGB(20, 24, 33)
patchDetailBox.Text = "Belum ada fixture di-patch."
patchDetailBox.TextColor3 = Color3.fromRGB(190, 205, 228)
patchDetailBox.Font = Enum.Font.Code
patchDetailBox.TextSize = 11
patchDetailBox.TextWrapped = true
patchDetailBox.TextYAlignment = Enum.TextYAlignment.Top
patchDetailBox.TextXAlignment = Enum.TextXAlignment.Left
patchDetailBox.BorderSizePixel = 0
patchDetailBox.Parent = pageReel2
Instance.new("UICorner", patchDetailBox).CornerRadius = UDim.new(0, 6)

local detailPad = Instance.new("UIPadding", patchDetailBox)
detailPad.PaddingTop = UDim.new(0, 8)
detailPad.PaddingLeft = UDim.new(0, 8)
detailPad.PaddingRight = UDim.new(0, 8)
detailPad.PaddingBottom = UDim.new(0, 8)

local function getActiveParamsForSelection(): { string }
	local list = state.patchedByUniv[state.universe] or {}
	local targetItem: PatchedItem? = nil
	if state.activeBoxIndex and list[state.activeBoxIndex] then
		targetItem = list[state.activeBoxIndex]
	else
		for idx, isSel in pairs(state.selectedIndices) do
			if isSel and list[idx] then
				targetItem = list[idx]
				break
			end
		end
	end

	if targetItem then
		return getParamListForDevice(targetItem.Type)
	end
	return { "Dimmer", "Shutter", "Red", "Green", "Blue", "White", "Effect", "Effect2", "Speed" }
end

local function formatParamDisplayText(paramName: string): string
	local meta = PARAM_META[paramName] or { label = paramName, kind = "dmx" }
	local list = state.patchedByUniv[state.universe] or {}
	local targetItem: PatchedItem? = nil
	if state.activeBoxIndex and list[state.activeBoxIndex] then
		targetItem = list[state.activeBoxIndex]
	end

	if targetItem then
		local offset = targetItem.Profile[paramName]
		if type(offset) == "number" then
			local ch = targetItem.Address + offset
			return meta.label .. " [Ch." .. tostring(ch) .. "]"
		end
	end
	return meta.label
end

local function formatRatioText(paramName: string, ratio: number): string
	local r = math.clamp(ratio, 0, 1)
	local dmxVal = math.clamp(math.floor(r * MAX_VALUE + 0.5), MIN_VALUE, MAX_VALUE)
	local meta = PARAM_META[paramName] or { label = paramName, kind = "dmx" }

	if meta.kind == "pan" then
		local deg = math.floor(r * 540 + 0.5)
		return tostring(dmxVal) .. " (" .. tostring(deg) .. "°)"
	elseif meta.kind == "tilt" then
		local deg = math.floor(r * 270 + 0.5)
		return tostring(dmxVal) .. " (" .. tostring(deg) .. "°)"
	elseif meta.kind == "percent" then
		local pct = math.floor(r * 100 + 0.5)
		return tostring(dmxVal) .. " (" .. tostring(pct) .. "%)"
	end
	return tostring(dmxVal)
end

local function syncParamAndFader()
	local params = getActiveParamsForSelection()
	local found = false
	for _, p in ipairs(params) do
		if p == state.activeParam then
			found = true
			break
		end
	end
	if not found and #params > 0 then
		state.activeParam = params[1]
	end

	paramPillBtn.Text = formatParamDisplayText(state.activeParam)

	local ratio = math.clamp(state.paramRatios[state.activeParam] or 0, 0, 1)
	faderFill.Size = UDim2.new(ratio, 0, 1, 0)
	faderValueLabel.Text = formatRatioText(state.activeParam, ratio)
end

local function getTargetFixtures(): { PatchedItem }
	local list = state.patchedByUniv[state.universe] or {}
	local targets: { PatchedItem } = {}
	local anySelected = false

	for idx, isSel in pairs(state.selectedIndices) do
		if isSel and list[idx] then
			anySelected = true
			table.insert(targets, list[idx])
		end
	end

	if not anySelected then
		for _, item in ipairs(list) do
			table.insert(targets, item)
		end
	end

	return targets
end

local function applyRatioToTargets(paramName: string, ratio: number)
	local r = math.clamp(ratio, 0, 1)
	state.paramRatios[paramName] = r
	local rawVal = math.clamp(math.floor(r * MAX_VALUE + 0.5), MIN_VALUE, MAX_VALUE)

	for _, item in ipairs(getTargetFixtures()) do
		local offset = item.Profile[paramName]
		if type(offset) == "number" then
			sendChannelValue(state.universe, item.Address + offset, rawVal, false)
		end
	end

	if paramName == state.activeParam then
		faderFill.Size = UDim2.new(r, 0, 1, 0)
		faderValueLabel.Text = formatRatioText(paramName, r)
	end
end

local function refreshGridAndLabels()
	univBtn.Text = "U" .. tostring(state.universe)
	devTypeLabel.Text = AVAILABLE_DEVICE_TYPES[state.addDeviceIdx]

	for _, child in ipairs(gridFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local list = state.patchedByUniv[state.universe] or {}
	local badgeParts: { string } = {}
	local detailLines: { string } = {}

	for idx, item in ipairs(list) do
		local tag = getShortTag(item.Type)
		local isSel = state.selectedIndices[idx] == true

		local box = Instance.new("TextButton")
		box.Name = "Box_" .. tostring(idx)
		box.LayoutOrder = idx
		box.BackgroundColor3 = isSel and Color3.fromRGB(52, 118, 212) or Color3.fromRGB(30, 36, 48)
		box.Text = "#" .. tostring(idx) .. " " .. tag .. "\n@" .. tostring(item.Address)
		box.TextColor3 = Color3.fromRGB(245, 248, 255)
		box.Font = Enum.Font.GothamBold
		box.TextSize = 10
		box.BorderSizePixel = 0
		box.Parent = gridFrame
		Instance.new("UICorner", box).CornerRadius = UDim.new(0, 5)

		local stroke = Instance.new("UIStroke")
		stroke.Color = (state.activeBoxIndex == idx) and Color3.fromRGB(140, 225, 255) or Color3.fromRGB(55, 65, 85)
		stroke.Thickness = (state.activeBoxIndex == idx) and 1.5 or 1
		stroke.Parent = box

		box.MouseButton1Click:Connect(function()
			state.activeBoxIndex = idx
			if state.selectedIndices[idx] then
				state.selectedIndices[idx] = nil
			else
				state.selectedIndices[idx] = true
			end
			refreshGridAndLabels()
		end)

		table.insert(badgeParts, "#" .. tostring(idx) .. "(" .. tag .. "@" .. tostring(item.Address) .. ")")
		table.insert(detailLines, string.format(
			"#%d | %-19s | Ch %d-%d (Span %d)",
			idx,
			item.Type,
			item.Address,
			item.EndAddress,
			item.Profile.Span or 8
		))
	end

	if #badgeParts == 0 then
		addrBadge.Text = "U" .. tostring(state.universe) .. " • Kosong"
		patchSummaryLabel.Text = "Patch: Kosong (" .. remoteSrc .. ")"
		patchDetailBox.Text = "Belum ada fixture di Universe " .. tostring(state.universe) .. ".\nRemote: " .. remoteSrc .. "\nKlik '+ Patch' di tab Preferensi."
	else
		addrBadge.Text = "U" .. tostring(state.universe) .. " • " .. table.concat(badgeParts, " ")
		patchSummaryLabel.Text = "Patch: " .. table.concat(badgeParts, " | ")
		patchDetailBox.Text = "Remote: " .. remoteSrc .. "\n" .. table.concat(detailLines, "\n")
	end

	syncParamAndFader()
end

local function clearCurrentUniverseFixtures()
	local univ = state.universe
	ensureUniverse(univ)

	local list = state.patchedByUniv[univ] or {}
	for _, item in ipairs(list) do
		for key, offset in pairs(item.Profile) do
			if key ~= "Group" and key ~= "Span" and type(offset) == "number" then
				sendChannelValue(univ, item.Address + offset, 0, true)
			end
		end
	end

	state.patchedByUniv[univ] = {}
	state.selectedIndices = {}
	state.activeBoxIndex = nil
	buffer.fill(state.univBuffers[univ], 0, 0, MAX_CHANNELS)
	refreshGridAndLabels()
end

do
	local sliding = false

	local function updateFromX(posX: number)
		local absPos = faderTrack.AbsolutePosition.X
		local absSize = math.max(1, faderTrack.AbsoluteSize.X)
		local ratio = math.clamp((posX - absPos) / absSize, 0, 1)
		applyRatioToTargets(state.activeParam, ratio)
	end

	faderTrack.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = true
			updateFromX(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromX(input.Position.X)
		end
	end)
end

devPrevBtn.MouseButton1Click:Connect(function()
	state.addDeviceIdx = ((state.addDeviceIdx - 2) % #AVAILABLE_DEVICE_TYPES) + 1
	refreshGridAndLabels()
end)

devNextBtn.MouseButton1Click:Connect(function()
	state.addDeviceIdx = (state.addDeviceIdx % #AVAILABLE_DEVICE_TYPES) + 1
	refreshGridAndLabels()
end)

addFixtureBtn.MouseButton1Click:Connect(function()
	patchDevice(AVAILABLE_DEVICE_TYPES[state.addDeviceIdx])
	refreshGridAndLabels()
end)

univBtn.MouseButton1Click:Connect(function()
	state.universe = (state.universe == 1) and 2 or 1
	ensureUniverse(state.universe)
	state.selectedIndices = {}
	state.activeBoxIndex = nil
	refreshGridAndLabels()
end)

local function stepParam(delta: number)
	local params = getActiveParamsForSelection()
	if #params == 0 then return end
	local idx = 1
	for i, p in ipairs(params) do
		if p == state.activeParam then
			idx = i
			break
		end
	end
	local nextIdx = ((idx - 1 + delta) % #params) + 1
	state.activeParam = params[nextIdx]
	syncParamAndFader()
end

paramPrevBtn.MouseButton1Click:Connect(function() stepParam(-1) end)
paramNextBtn.MouseButton1Click:Connect(function() stepParam(1) end)
paramPillBtn.MouseButton1Click:Connect(function() stepParam(1) end)

zeroBtn.MouseButton1Click:Connect(function() applyRatioToTargets(state.activeParam, 0) end)
fullBtn.MouseButton1Click:Connect(function() applyRatioToTargets(state.activeParam, 1) end)

selectAllBtn.MouseButton1Click:Connect(function()
	local list = state.patchedByUniv[state.universe] or {}
	if #list == 0 then return end
	local allSelected = true
	for i = 1, #list do
		if not state.selectedIndices[i] then
			allSelected = false
			break
		end
	end
	state.selectedIndices = {}
	if not allSelected then
		for i = 1, #list do
			state.selectedIndices[i] = true
		end
	end
	refreshGridAndLabels()
end)

blackoutBtn.MouseButton1Click:Connect(function()
	state.paramRatios.Dimmer = 0
	state.paramRatios.Shutter = 0
	local list = state.patchedByUniv[state.universe] or {}
	for _, item in ipairs(list) do
		if type(item.Profile.Dimmer) == "number" then
			sendChannelValue(state.universe, item.Address + item.Profile.Dimmer, 0, true)
		end
		if type(item.Profile.Shutter) == "number" then
			sendChannelValue(state.universe, item.Address + item.Profile.Shutter, 0, true)
		end
	end
	syncParamAndFader()
end)

masterFullBtn.MouseButton1Click:Connect(function()
	state.paramRatios.Dimmer = 1
	local list = state.patchedByUniv[state.universe] or {}
	for _, item in ipairs(list) do
		if type(item.Profile.Dimmer) == "number" then
			sendChannelValue(state.universe, item.Address + item.Profile.Dimmer, MAX_VALUE, true)
		end
	end
	syncParamAndFader()
end)

clearAllBtn.MouseButton1Click:Connect(function()
	clearCurrentUniverseFixtures()
end)

snapToPage(0)
refreshGridAndLabels()
