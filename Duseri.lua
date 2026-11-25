-- DmxConsoleUI_Combined.lua
-- Gabungan Patch Engine + Transport Buffer (3-byte) + Mobile Console UI (360x465)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================================================
-- SECTION 1: PATCH ENGINE (0-based offset dari Start Address 1-based)
-- ============================================================================
local PatchEngine = {}
local MAX_CHANNELS = 512
local DEFAULT_MAX_UNIVERSES = 2

local BarWashProfile = {
	Group = "BarWash",
	Span = 8,
	Dimmer = 0,
	Shutter = 1,
	Red = 2,
	Green = 3,
	Blue = 4,
	Effect = 5,
	Speed = 7,
}

local ClaraS14Profile = {
	Group = "MovingBeam",
	Span = 16,
	X = 0,
	Y = 1,
	Shutter = 6,
	Dimmer = 7,
	Effect = 11,
	Speed = 14,
}

PatchEngine.Profiles = {
	["ClaraS14"] = ClaraS14Profile,
	["Wallwasher_24X3W"] = BarWashProfile,
	["StrobeBar_192_Segment"] = BarWashProfile,
	["STROBE_1000W"] = {
		Group = "Strobe1000W",
		Span = 8,
		Dimmer = 0,
		Shutter = 1,
		Red = 2,
		Green = 3,
		Blue = 4,
		Effect = 5,
		Speed = 7,
	},
	["Parled"] = {
		Group = "Parled",
		Span = 6,
		Dimmer = 0,
		Red = 1,
		Green = 2,
		Blue = 3,
		White = 4,
		Shutter = 5,
	},
	["BlinderRing_2x50W"] = {
		Group = "Blinder",
		Span = 12,
		Dimmer = 0,
		Shutter = 1,
		Pod1Mode = 2,
		Pod2Mode = 3,
		AmberDim = 4,
		BacklightDim = 5,
		RingDim = 6,
		Red = 7,
		Green = 8,
		Blue = 9,
		Effect = 10,
		Speed = 11,
	},
	["Blinder"] = {
		Group = "Blinder",
		Span = 8,
		Dimmer = 0,
		LED1 = 0,
		LED2 = 1,
		LED3 = 2,
		LED4 = 3,
	},
	["Fogger"] = {
		Group = "Fogger",
		Span = 16,
		X = 0,
		Dimmer = 2,
		Shutter = 4,
		Red = 5,
		Green = 8,
		Blue = 9,
		Effect = 12,
	},
	["Flower"] = {
		Group = "Flower",
		Span = 18,
		Dimmer = 0,
		Red = 1,
		Green = 2,
		Blue = 3,
		Effect = 4,
		Speed = 5,
		Shutter = 16,
	},
	["Miniled"] = {
		Group = "MiniLed",
		Span = 1,
		Dimmer = 0,
	},
	["Pixelbeambar"] = {
		Group = "PixelBar",
		Span = 20,
		Y = 0,
		Speed = 2,
		Effect = 3,
		Dimmer = 5,
		Shutter = 6,
		Red = 8,
		Green = 9,
		Blue = 10,
	},
	["Retrohex"] = {
		Group = "RetroHex",
		Span = 11,
		Dimmer = 0,
		Shutter = 3,
		Effect = 4,
		Red = 6,
		Green = 7,
		Blue = 8,
	},
	["Windmill"] = {
		Group = "Windmill",
		Span = 8,
		Dimmer = 0,
		Shutter = 1,
		Speed = 2,
		Effect = 3,
		Red = 5,
		Green = 6,
		Blue = 7,
	},
}

local NameAliases = {
	["ClaraS14"] = { "claras14", "clara_s14", "clara s14" },
	["STROBE_1000W"] = { "strobe_1000w", "strobe1000", "strobo_1000w", "strobe 1000w" },
	["Wallwasher_24X3W"] = { "wallwasher_24x3w", "wallwasher", "wall washer" },
	["StrobeBar_192_Segment"] = { "strobebar_192_segment", "strobebar", "strobe bar" },
	["BlinderRing_2x50W"] = { "blinderring_2x50w", "blinderring", "blinder ring" },
	["Pixelbeambar"] = { "pixelbeambar", "pixelbar", "pixel beam bar" },
}

local function matchesAnyAlias(name, aliases)
	local lower = string.lower(tostring(name or ""))
	for _, key in ipairs(aliases) do
		local k = string.lower(key)
		if lower == k or string.find(lower, k, 1, true) == 1 then
			return true
		end
	end
	return false
end

local function resolveProfileKey(rawType)
	if type(rawType) ~= "string" or rawType == "" then
		return nil
	end
	if PatchEngine.Profiles[rawType] then
		return rawType
	end
	for key, aliases in pairs(NameAliases) do
		if matchesAnyAlias(rawType, aliases) then
			return key
		end
	end
	for key in pairs(PatchEngine.Profiles) do
		if string.lower(key) == string.lower(rawType) then
			return key
		end
	end
	return rawType
end

local function toAbsChannel(address, offset0, maxChannels)
	if type(address) ~= "number" or type(offset0) ~= "number" then
		return nil
	end
	if offset0 < 0 or offset0 >= (maxChannels or MAX_CHANNELS) then
		return nil
	end
	local ch = math.floor(address + offset0)
	if ch >= 1 and ch <= MAX_CHANNELS then
		return ch
	end
	return nil
end

local function resolveSpan(fixture, profile)
	if type(fixture.Channels) == "number" and fixture.Channels > 0 then
		return math.clamp(math.floor(fixture.Channels), 1, MAX_CHANNELS)
	end
	if type(profile) == "table" and type(profile.Span) == "number" and profile.Span > 0 then
		return math.clamp(math.floor(profile.Span), 1, MAX_CHANNELS)
	end
	return 8
end

function PatchEngine.AutoAddress(fixtures, maxUniverses)
	local limitUniv = maxUniverses or DEFAULT_MAX_UNIVERSES
	local cursors = {}
	for u = 1, limitUniv do
		cursors[u] = 1
	end

	local overflowList = {}

	for _, fix in ipairs(fixtures or {}) do
		local univ = math.clamp(math.floor(fix.Universe or 1), 1, limitUniv)
		fix.Universe = univ

		local typeKey = resolveProfileKey(fix.Type) or fix.Type
		fix.Type = typeKey

		local prof = PatchEngine.Profiles[typeKey]
		local span = resolveSpan(fix, prof)
		fix.Span = span

		if type(fix.Address) ~= "number" or fix.Address < 1 then
			if cursors[univ] + span - 1 <= MAX_CHANNELS then
				fix.Address = cursors[univ]
				cursors[univ] = fix.Address + span
				fix.Overflow = false
			else
				fix.Address = nil
				fix.Overflow = true
				table.insert(overflowList, fix)
			end
		else
			local clampedAddr = math.clamp(math.floor(fix.Address), 1, math.max(1, MAX_CHANNELS - span + 1))
			fix.Address = clampedAddr
			fix.Overflow = (clampedAddr + span - 1) > MAX_CHANNELS
			cursors[univ] = math.max(cursors[univ], clampedAddr + span)
		end
	end

	return fixtures, overflowList
end

function PatchEngine.SortPatched(patchedList)
	table.sort(patchedList, function(a, b)
		if (a.Universe or 999) ~= (b.Universe or 999) then
			return (a.Universe or 999) < (b.Universe or 999)
		end
		if (a.Address or 9999) ~= (b.Address or 9999) then
			return (a.Address or 9999) < (b.Address or 9999)
		end
		return tostring(a.Type) < tostring(b.Type)
	end)
	return patchedList
end

function PatchEngine.PatchFixture(fixture)
	local typeName = resolveProfileKey(fixture.Type) or fixture.Type
	local profile = PatchEngine.Profiles[typeName]
	local maxCh = resolveSpan(fixture, profile)

	local addr = math.clamp(math.floor(tonumber(fixture.Address) or 1), 1, math.max(1, MAX_CHANNELS - maxCh + 1))
	local endAddr = math.min(MAX_CHANNELS, addr + maxCh - 1)

	local p = profile or {}
	local shutterCh = toAbsChannel(addr, p.Shutter, maxCh)
	local dimmerCh = toAbsChannel(addr, p.Dimmer or 0, maxCh)

	return {
		Address = addr,
		EndAddress = endAddr,
		Span = maxCh,
		Universe = fixture.Universe or 1,
		Type = typeName,
		Group = p.Group or typeName or "Generic",
		Channels = {
			X = toAbsChannel(addr, p.X, maxCh),
			Y = toAbsChannel(addr, p.Y, maxCh),
			Shutter = shutterCh,
			Dimmer = dimmerCh,
			StrobeTarget = shutterCh or dimmerCh,
			Red = toAbsChannel(addr, p.Red, maxCh),
			Green = toAbsChannel(addr, p.Green, maxCh),
			Blue = toAbsChannel(addr, p.Blue, maxCh),
			White = toAbsChannel(addr, p.White, maxCh),
			Amber = toAbsChannel(addr, p.AmberDim, maxCh),
			Effect = toAbsChannel(addr, p.Effect, maxCh),
			Speed = toAbsChannel(addr, p.Speed, maxCh),
		},
	}
end

function PatchEngine.PatchAll(fixtures, universeFilter, autoAddress, maxUniverses)
	local limitUniv = maxUniverses or DEFAULT_MAX_UNIVERSES
	local overflow = {}

	if autoAddress then
		_, overflow = PatchEngine.AutoAddress(fixtures, limitUniv)
	end

	local patched = {}
	for _, fix in ipairs(fixtures or {}) do
		if not fix.Overflow then
			local univ = fix.Universe or 1
			if not universeFilter or univ == universeFilter then
				table.insert(patched, PatchEngine.PatchFixture(fix))
			end
		end
	end

	PatchEngine.SortPatched(patched)
	return patched, overflow
end

function PatchEngine.GetRoleChannels(patchedList, role, universeFilter)
	local result = {}
	for _, item in ipairs(patchedList or {}) do
		if not universeFilter or item.Universe == universeFilter then
			local ch = item.Channels and item.Channels[role]
			if type(ch) == "number" then
				table.insert(result, ch)
			end
		end
	end
	return result
end

function PatchEngine.GetFixtureAtChannel(patchedList, channel, universeFilter)
	local targetCh = tonumber(channel)
	if not targetCh then
		return nil
	end
	for _, item in ipairs(patchedList or {}) do
		if not universeFilter or item.Universe == universeFilter then
			local startCh = item.Address or 1
			local endCh = item.EndAddress or (startCh + (item.Span or 1) - 1)
			if targetCh >= startCh and targetCh <= endCh then
				return item
			end
		end
	end
	return nil
end

function PatchEngine.GetUniverseSummary(patchedList, universe)
	local count = 0
	local highestEnd = 0
	for _, item in ipairs(patchedList or {}) do
		if item.Universe == universe then
			count += 1
			local endCh = item.EndAddress or ((item.Address or 1) + (item.Span or 1) - 1)
			if endCh > highestEnd then
				highestEnd = endCh
			end
		end
	end
	return {
		Universe = universe,
		FixtureCount = count,
		HighestChannel = highestEnd,
		NextAddress = math.clamp(highestEnd + 1, 1, MAX_CHANNELS),
		RemainingChannels = math.max(0, MAX_CHANNELS - highestEnd),
	}
end

-- ============================================================================
-- SECTION 2: TRANSPORT BUFFER 3-BYTE -> carModel.Data
-- ============================================================================
local DmxTransport = {}
DmxTransport.__index = DmxTransport

local function matchOwnCar(model, playerName)
	if not model or not model:IsA("Model") or not playerName then
		return false
	end
	if model.Name == playerName .. "'s Car" then
		return true
	end
	return string.find(string.lower(model.Name), string.lower(playerName), 1, true) ~= nil
end

function DmxTransport.new(targetPlayer)
	local self = setmetatable({}, DmxTransport)
	self.Player = targetPlayer
	self.DataRemote = nil
	self.LastValues = {}
	self:_bindVehicles()
	return self
end

function DmxTransport:_attachCar(carModel)
	if not carModel or not matchOwnCar(carModel, self.Player.Name) then
		return
	end
	task.spawn(function()
		local remote = carModel:WaitForChild("Data", 30)
		if remote and (remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")) then
			self.DataRemote = remote
		end
	end)
end

function DmxTransport:_bindVehicles()
	local vehicles = workspace:FindFirstChild("Vehicles")
	if not vehicles then
		return
	end
	for _, child in ipairs(vehicles:GetChildren()) do
		self:_attachCar(child)
	end
	vehicles.ChildAdded:Connect(function(child)
		self:_attachCar(child)
	end)
end

function DmxTransport:SendChannel(channel, value, force)
	if type(channel) ~= "number" then
		return false
	end
	local ch = math.clamp(math.floor(channel), 1, MAX_CHANNELS)
	local val = math.clamp(math.floor(value or 0), 0, 255)

	if not force and self.LastValues[ch] == val then
		return true
	end
	self.LastValues[ch] = val

	if not self.DataRemote then
		return false
	end

	local buf = buffer.create(3)
	buffer.writeu16(buf, 0, ch)
	buffer.writeu8(buf, 2, val)
	self.DataRemote:FireServer(buf)
	return true
end

function DmxTransport:SetRoleValue(patchedList, role, value, universeFilter, force)
	local channels = PatchEngine.GetRoleChannels(patchedList, role, universeFilter)
	for _, ch in ipairs(channels) do
		self:SendChannel(ch, value, force)
	end
	return #channels
end

local transport = DmxTransport.new(player)

-- ============================================================================
-- SECTION 3: MOBILE CONSOLE UI (360x465) — PATCH + MAIN
-- ============================================================================
local FIXTURE_LIST = {
	"ClaraS14",
	"STROBE_1000W",
	"Parled",
	"Wallwasher_24X3W",
	"BlinderRing_2x50W",
	"Pixelbeambar",
}

local function getPlayerDmxLightsFolder()
	local vehicles = workspace:FindFirstChild("Vehicles")
	if not vehicles then
		return nil
	end
	local carModel = vehicles:FindFirstChild(player.Name .. "'s Car")
	if not carModel then
		local lowerName = string.lower(player.Name)
		for _, child in ipairs(vehicles:GetChildren()) do
			if string.find(string.lower(child.Name), lowerName, 1, true) then
				carModel = child
				break
			end
		end
	end
	local folder = carModel and carModel:FindFirstChild("Folder")
	return (folder and folder:FindFirstChild("DmxLights")) or (carModel and carModel:FindFirstChild("DmxLights", true))
end

local function countOwnFixtures(fixtureName)
	local dmxFolder = getPlayerDmxLightsFolder()
	if not dmxFolder then
		return 0
	end
	local aliases = NameAliases[fixtureName] or { string.lower(fixtureName) }
	local count = 0
	for _, item in ipairs(dmxFolder:GetChildren()) do
		if matchesAnyAlias(item.Name, aliases) then
			count += 1
		end
	end
	return count
end

-- Bersihkan UI lama jika di-re-execute
local oldGui = playerGui:FindFirstChild("DmxConsoleUI_Combined")
if oldGui then
	oldGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DmxConsoleUI_Combined"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.fromOffset(360, 465)
mainFrame.Position = UDim2.new(0.5, -180, 0.5, -232)
mainFrame.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(45, 52, 68)
mainStroke.Thickness = 1
mainStroke.Parent = mainFrame

-- Topbar (36 px)
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 36)
topBar.BackgroundColor3 = Color3.fromRGB(24, 28, 37)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 10)
topCorner.Parent = topBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -80, 1, 0)
titleLabel.Position = UDim2.fromOffset(12, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "DMX CONSOLE"
titleLabel.TextColor3 = Color3.fromRGB(235, 240, 250)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = topBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(28, 24)
minBtn.Position = UDim2.new(1, -66, 0.5, -12)
minBtn.BackgroundColor3 = Color3.fromRGB(36, 42, 54)
minBtn.Text = "—"
minBtn.TextColor3 = Color3.fromRGB(220, 226, 238)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 13
minBtn.Parent = topBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28, 24)
closeBtn.Position = UDim2.new(1, -34, 0.5, -12)
closeBtn.BackgroundColor3 = Color3.fromRGB(130, 36, 44)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 235, 238)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = topBar

-- Dragging untuk Mobile & PC
do
	local dragging = false
	local dragInput = nil
	local dragStart = nil
	local startPos = nil

	topBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = mainFrame.Position
			dragInput = input

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	topBar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then
			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end

-- Tab Bar (32 px)
local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1, -16, 0, 32)
tabBar.Position = UDim2.fromOffset(8, 42)
tabBar.BackgroundColor3 = Color3.fromRGB(22, 25, 33)
tabBar.BorderSizePixel = 0
tabBar.Parent = mainFrame

local patchTabBtn = Instance.new("TextButton")
patchTabBtn.Size = UDim2.new(0.5, -4, 1, -4)
patchTabBtn.Position = UDim2.fromOffset(2, 2)
patchTabBtn.BackgroundColor3 = Color3.fromRGB(48, 92, 185)
patchTabBtn.Text = "PATCH"
patchTabBtn.TextColor3 = Color3.new(1, 1, 1)
patchTabBtn.Font = Enum.Font.GothamBold
patchTabBtn.TextSize = 11
patchTabBtn.Parent = tabBar

local mainTabBtn = Instance.new("TextButton")
mainTabBtn.Size = UDim2.new(0.5, -4, 1, -4)
mainTabBtn.Position = UDim2.new(0.5, 2, 0, 2)
mainTabBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 46)
mainTabBtn.Text = "MAIN LIVE"
mainTabBtn.TextColor3 = Color3.fromRGB(185, 195, 212)
mainTabBtn.Font = Enum.Font.GothamBold
mainTabBtn.TextSize = 11
mainTabBtn.Parent = tabBar

-- Body Container
local bodyFrame = Instance.new("Frame")
bodyFrame.Size = UDim2.new(1, -16, 1, -82)
bodyFrame.Position = UDim2.fromOffset(8, 78)
bodyFrame.BackgroundTransparency = 1
bodyFrame.Parent = mainFrame

-- ============================================================================
-- TAB 1: PATCH
-- ============================================================================
local patchPage = Instance.new("Frame")
patchPage.Size = UDim2.fromScale(1, 1)
patchPage.BackgroundTransparency = 1
patchPage.Visible = true
patchPage.Parent = bodyFrame

local selectedFixtureIdx = 1
local fixtureCycleBtn = Instance.new("TextButton")
fixtureCycleBtn.Size = UDim2.new(1, -112, 0, 30)
fixtureCycleBtn.Position = UDim2.fromOffset(0, 0)
fixtureCycleBtn.BackgroundColor3 = Color3.fromRGB(28, 33, 44)
fixtureCycleBtn.Text = "Fix: " .. FIXTURE_LIST[selectedFixtureIdx]
fixtureCycleBtn.TextColor3 = Color3.fromRGB(230, 238, 252)
fixtureCycleBtn.Font = Enum.Font.GothamBold
fixtureCycleBtn.TextSize = 11
fixtureCycleBtn.Parent = patchPage

local countBox = Instance.new("TextBox")
countBox.Size = UDim2.fromOffset(50, 30)
countBox.Position = UDim2.new(1, -106, 0, 0)
countBox.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
countBox.Text = "1"
countBox.TextColor3 = Color3.fromRGB(255, 255, 255)
countBox.Font = Enum.Font.GothamBold
countBox.TextSize = 12
countBox.ClearTextOnFocus = false
countBox.Parent = patchPage

local addBtn = Instance.new("TextButton")
addBtn.Size = UDim2.fromOffset(50, 30)
addBtn.Position = UDim2.new(1, -50, 0, 0)
addBtn.BackgroundColor3 = Color3.fromRGB(38, 128, 82)
addBtn.Text = "ADD"
addBtn.TextColor3 = Color3.new(1, 1, 1)
addBtn.Font = Enum.Font.GothamBold
addBtn.TextSize = 11
addBtn.Parent = patchPage

local autoCalcBtn = Instance.new("TextButton")
autoCalcBtn.Size = UDim2.new(0.42, -3, 0, 28)
autoCalcBtn.Position = UDim2.fromOffset(0, 35)
autoCalcBtn.BackgroundColor3 = Color3.fromRGB(42, 52, 72)
autoCalcBtn.Text = "AUTO CALC"
autoCalcBtn.TextColor3 = Color3.fromRGB(220, 232, 250)
autoCalcBtn.Font = Enum.Font.GothamBold
autoCalcBtn.TextSize = 10
autoCalcBtn.Parent = patchPage

local univManualBtn = Instance.new("TextButton")
univManualBtn.Size = UDim2.new(0.33, -3, 0, 28)
univManualBtn.Position = UDim2.new(0.42, 0, 0, 35)
univManualBtn.BackgroundColor3 = Color3.fromRGB(54, 48, 86)
univManualBtn.Text = "UNIV: U1"
univManualBtn.TextColor3 = Color3.fromRGB(235, 230, 255)
univManualBtn.Font = Enum.Font.GothamBold
univManualBtn.TextSize = 10
univManualBtn.Parent = patchPage

local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0.25, 0, 0, 28)
clearBtn.Position = UDim2.new(0.75, 0, 0, 35)
clearBtn.BackgroundColor3 = Color3.fromRGB(110, 40, 46)
clearBtn.Text = "CLEAR"
clearBtn.TextColor3 = Color3.new(1, 1, 1)
clearBtn.Font = Enum.Font.GothamBold
clearBtn.TextSize = 10
clearBtn.Parent = patchPage

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 22)
statusLabel.Position = UDim2.fromOffset(0, 67)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "U1 | 0 Fix | Next Addr: 1 | Rem: 512"
statusLabel.TextColor3 = Color3.fromRGB(155, 170, 195)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 10
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = patchPage

local gridScroll = Instance.new("ScrollingFrame")
gridScroll.Size = UDim2.new(1, 0, 1, -118)
gridScroll.Position = UDim2.fromOffset(0, 92)
gridScroll.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
gridScroll.BorderSizePixel = 0
gridScroll.ScrollBarThickness = 4
gridScroll.CanvasSize = UDim2.new(0, 0, 0, 1300)
gridScroll.Parent = patchPage

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(38, 22)
gridLayout.CellPadding = UDim2.fromOffset(3, 3)
gridLayout.Parent = gridScroll

local inspectLabel = Instance.new("TextLabel")
inspectLabel.Size = UDim2.new(1, 0, 0, 20)
inspectLabel.Position = UDim2.new(1, -344, 1, -22)
inspectLabel.BackgroundColor3 = Color3.fromRGB(26, 30, 40)
inspectLabel.Text = "Tap channel box to inspect patch info"
inspectLabel.TextColor3 = Color3.fromRGB(210, 222, 240)
inspectLabel.Font = Enum.Font.Gotham
inspectLabel.TextSize = 10
inspectLabel.Parent = patchPage

-- ============================================================================
-- TAB 2: MAIN LIVE CONTROL (BUFFER 3-BYTE -> carModel.Data)
-- ============================================================================
local mainPage = Instance.new("Frame")
mainPage.Size = UDim2.fromScale(1, 1)
mainPage.BackgroundTransparency = 1
mainPage.Visible = false
mainPage.Parent = bodyFrame

local liveInfoLabel = Instance.new("TextLabel")
liveInfoLabel.Size = UDim2.new(1, 0, 0, 24)
liveInfoLabel.BackgroundTransparency = 1
liveInfoLabel.Text = "Live Output -> carModel.Data (3-byte buffer)"
liveInfoLabel.TextColor3 = Color3.fromRGB(165, 220, 185)
liveInfoLabel.Font = Enum.Font.GothamBold
liveInfoLabel.TextSize = 10
liveInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
liveInfoLabel.Parent = mainPage

local activeUniverse = 1
local rawByUniv = { [1] = {}, [2] = {} }
local patchedByUniv = { [1] = {}, [2] = {} }
local selectedChannel = nil
local channelButtons = {}

local function createRoleControlRow(parent, yPos, labelText, roleName, defaultVal)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 34)
	row.Position = UDim2.fromOffset(0, yPos)
	row.BackgroundColor3 = Color3.fromRGB(24, 28, 38)
	row.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromOffset(78, 1, 0, 0)
	lbl.Position = UDim2.fromOffset(8, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextColor3 = Color3.fromRGB(225, 232, 245)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 10
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local valBox = Instance.new("TextBox")
	valBox.Size = UDim2.fromOffset(48, 24)
	valBox.Position = UDim2.new(1, -54, 0.5, -12)
	valBox.BackgroundColor3 = Color3.fromRGB(16, 19, 26)
	valBox.Text = tostring(defaultVal)
	valBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	valBox.Font = Enum.Font.GothamBold
	valBox.TextSize = 10
	valBox.Parent = row

	local sendBtn = Instance.new("TextButton")
	sendBtn.Size = UDim2.fromOffset(56, 24)
	sendBtn.Position = UDim2.new(1, -116, 0.5, -12)
	sendBtn.BackgroundColor3 = Color3.fromRGB(48, 92, 185)
	sendBtn.Text = "SEND"
	sendBtn.TextColor3 = Color3.new(1, 1, 1)
	sendBtn.Font = Enum.Font.GothamBold
	sendBtn.TextSize = 10
	sendBtn.Parent = row

	local function pushValue()
		local num = math.clamp(math.floor(tonumber(valBox.Text) or 0), 0, 255)
		valBox.Text = tostring(num)
		local sentCount = transport:SetRoleValue(patchedByUniv[activeUniverse], roleName, num, activeUniverse, true)
		liveInfoLabel.Text = string.format("Sent %s=%d to %d ch (U%d) | Remote:%s",
			roleName, num, sentCount, activeUniverse, transport.DataRemote and "OK" or "WAIT")
	end

	sendBtn.MouseButton1Click:Connect(pushValue)
	valBox.FocusLost:Connect(pushValue)
end

createRoleControlRow(mainPage, 28, "Dimmer", "Dimmer", 255)
createRoleControlRow(mainPage, 68, "Shutter", "Shutter", 255)
createRoleControlRow(mainPage, 108, "Red", "Red", 0)
createRoleControlRow(mainPage, 148, "Green", "Green", 0)
createRoleControlRow(mainPage, 188, "Blue", "Blue", 0)
createRoleControlRow(mainPage, 228, "Beam X", "X", 128)
createRoleControlRow(mainPage, 268, "Beam Y", "Y", 128)
createRoleControlRow(mainPage, 308, "Effect", "Effect", 0)

local blackoutBtn = Instance.new("TextButton")
blackoutBtn.Size = UDim2.new(1, 0, 0, 30)
blackoutBtn.Position = UDim2.fromOffset(0, 348)
blackoutBtn.BackgroundColor3 = Color3.fromRGB(135, 35, 42)
blackoutBtn.Text = "BLACKOUT (0 ALL ROLES)"
blackoutBtn.TextColor3 = Color3.new(1, 1, 1)
blackoutBtn.Font = Enum.Font.GothamBold
blackoutBtn.TextSize = 11
blackoutBtn.Parent = mainPage

blackoutBtn.MouseButton1Click:Connect(function()
	for _, role in ipairs({ "Dimmer", "Shutter", "Red", "Green", "Blue", "X", "Y", "Effect", "Speed" }) do
		transport:SetRoleValue(patchedByUniv[activeUniverse], role, 0, activeUniverse, true)
	end
	liveInfoLabel.Text = "Blackout sent on U" .. activeUniverse
end)

-- ============================================================================
-- REFRESH GRID & STATE
-- ============================================================================
local function refreshPatchUI()
	univManualBtn.Text = "UNIV: U" .. activeUniverse
	local patched = patchedByUniv[activeUniverse]
	local summary = PatchEngine.GetUniverseSummary(patched, activeUniverse)

	statusLabel.Text = string.format(
		"U%d | %d Fix | Next Addr: %d | Rem: %d",
		activeUniverse,
		summary.FixtureCount,
		summary.NextAddress,
		summary.RemainingChannels
	)

	for ch = 1, MAX_CHANNELS do
		local btn = channelButtons[ch]
		if btn then
			local fix = PatchEngine.GetFixtureAtChannel(patched, ch, activeUniverse)
			local isSelected = (selectedChannel == ch)
			if isSelected then
				btn.BackgroundColor3 = Color3.fromRGB(235, 175, 45)
				btn.TextColor3 = Color3.fromRGB(15, 15, 15)
			elseif fix then
				btn.BackgroundColor3 = Color3.fromRGB(42, 118, 92)
				btn.TextColor3 = Color3.new(1, 1, 1)
			else
				btn.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
				btn.TextColor3 = Color3.fromRGB(135, 145, 165)
			end
		end
	end
end

for ch = 1, MAX_CHANNELS do
	local btn = Instance.new("TextButton")
	btn.Name = "Ch_" .. ch
	btn.Text = tostring(ch)
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 9
	btn.BorderSizePixel = 0
	btn.Parent = gridScroll
	channelButtons[ch] = btn

	btn.MouseButton1Click:Connect(function()
		selectedChannel = ch
		local fix = PatchEngine.GetFixtureAtChannel(patchedByUniv[activeUniverse], ch, activeUniverse)
		if fix then
			inspectLabel.Text = string.format(
				"Ch %d -> %s (%d..%d, %d ch)",
				ch,
				fix.Type,
				fix.Address,
				fix.EndAddress,
				fix.Span
			)
		else
			inspectLabel.Text = string.format("Ch %d -> Unpatched (U%d)", ch, activeUniverse)
		end
		refreshPatchUI()
	end)
end

fixtureCycleBtn.MouseButton1Click:Connect(function()
	selectedFixtureIdx = (selectedFixtureIdx % #FIXTURE_LIST) + 1
	fixtureCycleBtn.Text = "Fix: " .. FIXTURE_LIST[selectedFixtureIdx]
end)

autoCalcBtn.MouseButton1Click:Connect(function()
	local fixName = FIXTURE_LIST[selectedFixtureIdx]
	local found = countOwnFixtures(fixName)
	countBox.Text = tostring(math.max(1, found))
	inspectLabel.Text = string.format("Detected %d '%s' on your vehicle", found, fixName)
end)

univManualBtn.MouseButton1Click:Connect(function()
	activeUniverse = (activeUniverse == 1) and 2 or 1
	selectedChannel = nil
	inspectLabel.Text = "Switched to Universe " .. activeUniverse
	refreshPatchUI()
end)

addBtn.MouseButton1Click:Connect(function()
	local fixName = FIXTURE_LIST[selectedFixtureIdx]
	local qty = math.max(1, math.floor(tonumber(countBox.Text) or 1))
	for _ = 1, qty do
		table.insert(rawByUniv[activeUniverse], {
			Type = fixName,
			Universe = activeUniverse,
		})
	end

	local patched, overflow = PatchEngine.PatchAll(rawByUniv[activeUniverse], activeUniverse, true, DEFAULT_MAX_UNIVERSES)
	patchedByUniv[activeUniverse] = patched

	if #overflow > 0 then
		local filtered = {}
		for _, item in ipairs(rawByUniv[activeUniverse]) do
			if not item.Overflow then
				table.insert(filtered, item)
			end
		end
		rawByUniv[activeUniverse] = filtered
		inspectLabel.Text = "Some fixtures exceeded 512 ch on U" .. activeUniverse
	else
		inspectLabel.Text = string.format("Patched +%d %s on U%d", qty, fixName, activeUniverse)
	end

	refreshPatchUI()
end)

clearBtn.MouseButton1Click:Connect(function()
	rawByUniv[activeUniverse] = {}
	patchedByUniv[activeUniverse] = {}
	selectedChannel = nil
	inspectLabel.Text = "Cleared patch on U" .. activeUniverse
	refreshPatchUI()
end)

patchTabBtn.MouseButton1Click:Connect(function()
	patchPage.Visible = true
	mainPage.Visible = false
	patchTabBtn.BackgroundColor3 = Color3.fromRGB(48, 92, 185)
	mainTabBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 46)
end)

mainTabBtn.MouseButton1Click:Connect(function()
	patchPage.Visible = false
	mainPage.Visible = true
	mainTabBtn.BackgroundColor3 = Color3.fromRGB(48, 92, 185)
	patchTabBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 46)
	liveInfoLabel.Text = string.format(
		"U%d | %d Patched | Remote: %s",
		activeUniverse,
		#patchedByUniv[activeUniverse],
		transport.DataRemote and "CONNECTED" or "WAITING CAR"
	)
end)

local minimized = false
minBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	tabBar.Visible = not minimized
	bodyFrame.Visible = not minimized
	mainFrame.Size = minimized and UDim2.fromOffset(360, 36) or UDim2.fromOffset(360, 465)
end)

closeBtn.MouseButton1Click:Connect(function()
	screenGui:Destroy()
end)

refreshPatchUI()
