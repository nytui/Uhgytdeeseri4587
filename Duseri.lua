-- DmxConsoleeUI_MobileDrag.lua (360x465)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- Ambil PatchEngine dari ReplicatedStorage kalau ada, kalau tidak pakai fallback bawaan
local PatchEngine
do
	local mod = ReplicatedStorage:FindFirstChild("PatchEngine")
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok and type(res) == "table" then
			PatchEngine = res
		end
	end
end

if not PatchEngine then
	PatchEngine = {}
	local BarWashProfile = {
		Group = "BarWash", Span = 8, Dimmer = 0, Shutter = 1, Red = 2, Green = 3, Blue = 4, Effect = 5, Speed = 7,
	}
	local ClaraS14Profile = {
		Group = "MovingBeam", Span = 16, X = 0, Y = 1, Shutter = 6, Dimmer = 7, Effect = 11, Speed = 14,
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

	local NameAliases = {
		["ClaraS14"] = { "claras14", "clara_s14", "clara s14" },
		["STROBE_1000W"] = { "strobe_1000w", "strobe1000", "strobo_1000w", "strobe 1000w" },
		["Wallwasher_24X3W"] = { "wallwasher_24x3w", "wallwasher", "wall washer" },
		["StrobeBar_192_Segment"] = { "strobebar_192_segment", "strobebar", "strobe bar" },
		["BlinderRing_2x50W"] = { "blinderring_2x50w", "blinderring", "blinder ring" },
		["Pixelbeambar"] = { "pixelbeambar", "pixelbar", "pixel beam bar" },
	}

	local function getOwnDmxFolder(plr)
		local vehicles = workspace:FindFirstChild("Vehicles")
		if not vehicles or not plr then
			return nil
		end

		local carModel = vehicles:FindFirstChild(plr.Name .. "'s Car")
		if not carModel then
			local lp = string.lower(plr.Name)
			for _, c in ipairs(vehicles:GetChildren()) do
				if string.find(string.lower(c.Name), lp, 1, true) then
					carModel = c
					break
				end
			end
		end
		if not carModel then
			return nil
		end

		local folder = carModel:FindFirstChild("Folder")
		local dmxFolder = folder and folder:FindFirstChild("DmxLights")
		if not dmxFolder then
			dmxFolder = carModel:FindFirstChild("DmxLights", true)
		end

		return dmxFolder
	end

	local function matchesAnyKey(itemName, keys)
		local lowerName = string.lower(tostring(itemName or ""))
		for _, k in ipairs(keys) do
			if lowerName == k or string.find(lowerName, k, 1, true) then
				return true
			end
		end
		return false
	end

	function PatchEngine.CountVehicleFixtures(plr, fixtureName)
		local dmxFolder = getOwnDmxFolder(plr)
		if not dmxFolder or type(fixtureName) ~= "string" or fixtureName == "" then
			return 0
		end

		local keys = NameAliases[fixtureName] or { string.lower(fixtureName) }
		local count = 0

		for _, item in ipairs(dmxFolder:GetChildren()) do
			if matchesAnyKey(item.Name, keys) then
				count += 1
			end
		end

		if count == 0 then
			for _, desc in ipairs(dmxFolder:GetDescendants()) do
				if matchesAnyKey(desc.Name, keys) then
					count += 1
				end
			end
		end

		return count
	end
end

-- Bersihkan GUI lama jika di-execute ulang
local parentTarget = player:WaitForChild("PlayerGui")
pcall(function()
	if gethui then
		parentTarget = gethui()
	end
end)
local oldGui = parentTarget:FindFirstChild("DmxConsoleGui")
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

local state = {
	page = 1,
	slotsPerPage = 12,
	fixtureIndex = 1,
	universe = 1,
	totalChannels = 0,
	nextAddress = 1,
}

local function getSelectedFixtureName()
	return fixtureNames[state.fixtureIndex] or "ClaraS14"
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DmxConsoleGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999
screenGui.Parent = parentTarget

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainWindow"
mainFrame.Size = UDim2.fromOffset(360, 465)
mainFrame.Position = UDim2.new(0.5, -180, 0.5, -232.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(58, 58, 60)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 18)

-- Drag handle di area top bar agar mulus di mobile tanpa bentrok tombol bawah
local dragBar = Instance.new("Frame")
dragBar.Name = "DragBar"
dragBar.Size = UDim2.new(1, 0, 0, 44)
dragBar.Position = UDim2.fromOffset(0, 0)
dragBar.BackgroundTransparency = 1
dragBar.Active = true
dragBar.Parent = mainFrame

do
	local dragging = false
	local dragInput = nil
	local dragStart = Vector2.zero
	local startPos = UDim2.new()

	dragBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = Vector2.new(input.Position.X, input.Position.Y)
			startPos = mainFrame.Position
			dragInput = input

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	dragBar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input == dragInput then
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

-- Top bar buttons (— dan ◇)
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(32, 26)
minBtn.Position = UDim2.new(1, -86, 0, 10)
minBtn.BackgroundTransparency = 1
minBtn.Text = "—"
minBtn.TextColor3 = Color3.fromRGB(220, 220, 224)
minBtn.TextSize = 20
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = dragBar

local diamondBtn = Instance.new("TextButton")
diamondBtn.Size = UDim2.fromOffset(24, 24)
diamondBtn.Position = UDim2.new(1, -42, 0, 12)
diamondBtn.BackgroundColor3 = Color3.fromRGB(165, 165, 168)
diamondBtn.Text = ""
diamondBtn.Rotation = 45
diamondBtn.BorderSizePixel = 0
diamondBtn.Parent = dragBar

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -24, 0, 1)
divider.Position = UDim2.fromOffset(12, 44)
divider.BackgroundColor3 = Color3.fromRGB(150, 150, 154)
divider.BorderSizePixel = 0
divider.Parent = mainFrame

-- Tabs
local tabNames = { "patch", "Preferensi", "main", "Setting" }
local tabButtons = {}
local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(1, -24, 0, 28)
tabContainer.Position = UDim2.fromOffset(12, 54)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Padding = UDim.new(0, 8)
tabLayout.Parent = tabContainer

local patchBody = Instance.new("Frame")
patchBody.Size = UDim2.new(1, -24, 1, -94)
patchBody.Position = UDim2.fromOffset(12, 90)
patchBody.BackgroundTransparency = 1
patchBody.Parent = mainFrame

local placeholderBody = Instance.new("TextLabel")
placeholderBody.Size = UDim2.fromScale(1, 1)
placeholderBody.BackgroundTransparency = 1
placeholderBody.TextColor3 = Color3.fromRGB(215, 215, 220)
placeholderBody.TextSize = 14
placeholderBody.Font = Enum.Font.GothamMedium
placeholderBody.Visible = false
placeholderBody.Parent = patchBody

-- Area atas: awalnya kosong, terisi kotak channel berurutan 1, 2, 3... saat add fixture +
local channelFrame = Instance.new("ScrollingFrame")
channelFrame.Name = "ChannelContainer"
channelFrame.Size = UDim2.new(1, 0, 0, 96)
channelFrame.Position = UDim2.fromOffset(0, 2)
channelFrame.BackgroundTransparency = 1
channelFrame.ScrollBarThickness = 3
channelFrame.CanvasSize = UDim2.fromOffset(0, 0)
channelFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
channelFrame.Parent = patchBody

local channelGrid = Instance.new("UIGridLayout")
channelGrid.CellSize = UDim2.fromOffset(49, 43)
channelGrid.CellPadding = UDim2.fromOffset(6.5, 8)
channelGrid.FillDirection = Enum.FillDirection.Horizontal
channelGrid.SortOrder = Enum.SortOrder.LayoutOrder
channelGrid.Parent = channelFrame

local pageLabel = Instance.new("TextLabel")
pageLabel.Size = UDim2.fromOffset(90, 20)
pageLabel.Position = UDim2.fromOffset(0, 104)
pageLabel.BackgroundTransparency = 1
pageLabel.Text = "page 1"
pageLabel.TextXAlignment = Enum.TextXAlignment.Left
pageLabel.TextColor3 = Color3.fromRGB(190, 190, 195)
pageLabel.TextSize = 13
pageLabel.Font = Enum.Font.Gotham
pageLabel.Parent = patchBody

local nextPageBtn = Instance.new("TextButton")
nextPageBtn.Size = UDim2.fromOffset(96, 20)
nextPageBtn.Position = UDim2.new(1, -96, 0, 104)
nextPageBtn.BackgroundTransparency = 1
nextPageBtn.Text = "next page >"
nextPageBtn.TextXAlignment = Enum.TextXAlignment.Right
nextPageBtn.TextColor3 = Color3.fromRGB(190, 190, 195)
nextPageBtn.TextSize = 13
nextPageBtn.Font = Enum.Font.Gotham
nextPageBtn.Parent = patchBody

local addFixtureBtn = Instance.new("TextButton")
addFixtureBtn.Size = UDim2.fromOffset(104, 28)
addFixtureBtn.Position = UDim2.new(1, -104, 0, 146)
addFixtureBtn.BackgroundColor3 = Color3.fromRGB(33, 134, 235)
addFixtureBtn.Text = "add fixture +"
addFixtureBtn.TextColor3 = Color3.fromRGB(245, 248, 255)
addFixtureBtn.TextSize = 13
addFixtureBtn.Font = Enum.Font.GothamMedium
addFixtureBtn.BorderSizePixel = 0
addFixtureBtn.Parent = patchBody
Instance.new("UICorner", addFixtureBtn).CornerRadius = UDim.new(0, 8)

local fixtureRow = Instance.new("Frame")
fixtureRow.Size = UDim2.new(1, 0, 0, 32)
fixtureRow.Position = UDim2.fromOffset(0, 184)
fixtureRow.BackgroundColor3 = Color3.fromRGB(74, 74, 77)
fixtureRow.BorderSizePixel = 0
fixtureRow.Parent = patchBody
Instance.new("UICorner", fixtureRow).CornerRadius = UDim.new(1, 0)
local fixStroke = Instance.new("UIStroke", fixtureRow)
fixStroke.Color = Color3.fromRGB(34, 34, 36)
fixStroke.Thickness = 1.5

local prevFixBtn = Instance.new("TextButton")
prevFixBtn.Size = UDim2.fromOffset(36, 32)
prevFixBtn.Position = UDim2.fromOffset(6, 0)
prevFixBtn.BackgroundTransparency = 1
prevFixBtn.Text = "◁"
prevFixBtn.TextColor3 = Color3.fromRGB(28, 28, 30)
prevFixBtn.TextSize = 16
prevFixBtn.Font = Enum.Font.GothamBold
prevFixBtn.Parent = fixtureRow

local fixtureNameLabel = Instance.new("TextLabel")
fixtureNameLabel.Size = UDim2.new(1, -92, 1, 0)
fixtureNameLabel.Position = UDim2.fromOffset(46, 0)
fixtureNameLabel.BackgroundTransparency = 1
fixtureNameLabel.Text = getSelectedFixtureName()
fixtureNameLabel.TextColor3 = Color3.fromRGB(42, 42, 45)
fixtureNameLabel.TextSize = 13
fixtureNameLabel.Font = Enum.Font.GothamMedium
fixtureNameLabel.Parent = fixtureRow

local nextFixBtn = Instance.new("TextButton")
nextFixBtn.Size = UDim2.fromOffset(36, 32)
nextFixBtn.Position = UDim2.new(1, -42, 0, 0)
nextFixBtn.BackgroundTransparency = 1
nextFixBtn.Text = "▷"
nextFixBtn.TextColor3 = Color3.fromRGB(28, 28, 30)
nextFixBtn.TextSize = 16
nextFixBtn.Font = Enum.Font.GothamBold
nextFixBtn.Parent = fixtureRow

local function createPill(yPos, isInput, textOrPlaceholder)
	local box = Instance.new(isInput and "TextBox" or "TextButton")
	box.Size = UDim2.new(1, 0, 0, 30)
	box.Position = UDim2.fromOffset(0, yPos)
	box.BackgroundColor3 = Color3.fromRGB(74, 74, 77)
	box.TextColor3 = Color3.fromRGB(38, 38, 41)
	box.TextSize = 13
	box.Font = Enum.Font.GothamMedium
	box.BorderSizePixel = 0
	box.Parent = patchBody
	if isInput then
		box.Text = ""
		box.PlaceholderText = textOrPlaceholder
		box.PlaceholderColor3 = Color3.fromRGB(48, 48, 52)
		box.ClearTextOnFocus = false
	else
		box.Text = textOrPlaceholder
	end
	Instance.new("UICorner", box).CornerRadius = UDim.new(1, 0)
	local stroke = Instance.new("UIStroke", box)
	stroke.Color = Color3.fromRGB(34, 34, 36)
	stroke.Thickness = 1.5
	return box
end

local countBox = createPill(222, true, "count fixture your add")
local universeBtn = createPill(258, false, "Universe 1")
local autoCalcBtn = createPill(294, false, "Auto calculate")

local addrBadge = Instance.new("TextLabel")
addrBadge.Size = UDim2.fromOffset(78, 24)
addrBadge.Position = UDim2.new(1, -78, 1, -24)
addrBadge.BackgroundColor3 = Color3.fromRGB(168, 168, 172)
addrBadge.Text = "U1 • 1"
addrBadge.TextColor3 = Color3.fromRGB(30, 30, 32)
addrBadge.TextSize = 12
addrBadge.Font = Enum.Font.GothamMedium
addrBadge.BorderSizePixel = 0
addrBadge.Parent = patchBody
Instance.new("UICorner", addrBadge).CornerRadius = UDim.new(0, 6)

local function refreshUI()
	fixtureNameLabel.Text = getSelectedFixtureName()
	universeBtn.Text = "Universe " .. state.universe
	pageLabel.Text = "page " .. state.page

	for _, child in ipairs(channelFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local startCh = (state.page - 1) * state.slotsPerPage + 1
	local endCh = math.min(state.totalChannels, state.page * state.slotsPerPage)

	for ch = startCh, endCh do
		local card = Instance.new("TextButton")
		card.Name = "Ch_" .. ch
		card.LayoutOrder = ch - startCh + 1
		card.BackgroundColor3 = Color3.fromRGB(72, 72, 75)
		card.Text = tostring(ch)
		card.TextColor3 = Color3.fromRGB(240, 245, 255)
		card.TextSize = 14
		card.Font = Enum.Font.GothamBold
		card.BorderSizePixel = 0
		card.Parent = channelFrame

		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
		local stroke = Instance.new("UIStroke", card)
		stroke.Color = Color3.fromRGB(32, 32, 34)
		stroke.Thickness = 1.5
	end

	addrBadge.Text = "U" .. state.universe .. " • " .. state.nextAddress
end

for _, tName in ipairs(tabNames) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(77, 26)
	btn.Text = tName
	btn.TextSize = 12
	btn.Font = Enum.Font.GothamMedium
	btn.BorderSizePixel = 0
	btn.Parent = tabContainer
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	tabButtons[tName] = btn

	btn.MouseButton1Click:Connect(function()
		for name, b in pairs(tabButtons) do
			if name == tName then
				b.BackgroundColor3 = Color3.fromRGB(33, 134, 235)
				b.TextColor3 = Color3.fromRGB(245, 248, 255)
			else
				b.BackgroundColor3 = Color3.fromRGB(115, 115, 119)
				b.TextColor3 = Color3.fromRGB(32, 32, 34)
			end
		end
		local isPatch = (tName == "patch")
		for _, child in ipairs(patchBody:GetChildren()) do
			if child ~= placeholderBody then
				child.Visible = isPatch
			end
		end
		placeholderBody.Visible = not isPatch
		placeholderBody.Text = "Tab: " .. tName
	end)
end

for name, b in pairs(tabButtons) do
	if name == "patch" then
		b.BackgroundColor3 = Color3.fromRGB(33, 134, 235)
		b.TextColor3 = Color3.fromRGB(245, 248, 255)
	else
		b.BackgroundColor3 = Color3.fromRGB(115, 115, 119)
		b.TextColor3 = Color3.fromRGB(32, 32, 34)
	end
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
	refreshUI()
end)

autoCalcBtn.MouseButton1Click:Connect(function()
	local total = PatchEngine.CountVehicleFixtures(player, getSelectedFixtureName())
	countBox.Text = tostring(total)
end)

addFixtureBtn.MouseButton1Click:Connect(function()
	local qty = math.floor(tonumber(countBox.Text) or 1)
	if qty < 1 then qty = 1 end

	local selected = getSelectedFixtureName()
	local prof = PatchEngine.Profiles[selected]
	local span = (prof and prof.Span) or 8

	state.totalChannels += qty
	state.nextAddress = math.clamp(state.nextAddress + (qty * span), 1, 512)
	refreshUI()
end)

nextPageBtn.MouseButton1Click:Connect(function()
	local totalPages = math.max(1, math.ceil(state.totalChannels / state.slotsPerPage))
	state.page = (state.page % totalPages) + 1
	refreshUI()
end)

minBtn.MouseButton1Click:Connect(function()
	local collapsed = mainFrame.Size.Y.Offset <= 52
	mainFrame.Size = collapsed and UDim2.fromOffset(360, 465) or UDim2.fromOffset(360, 48)
	tabContainer.Visible = collapsed
	patchBody.Visible = collapsed
end)

diamondBtn.MouseButton1Click:Connect(function()
	state.page = 1
	refreshUI()
end)

refreshUI()
