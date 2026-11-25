-- DmxConsoleUI.lua (360x465)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Sesuaikan lokasi module PatchEngine.lua lu jika berbeda
local PatchEngine = require(ReplicatedStorage:WaitForChild("PatchEngine"))

-- Kumpulkan daftar nama fixture unik dari PatchEngine.Profiles
local fixtureNames = {}
do
	local seenProfiles = {}
	for name, profile in pairs(PatchEngine.Profiles or {}) do
		if type(profile) == "table" and not seenProfiles[profile] then
			seenProfiles[profile] = true
			table.insert(fixtureNames, name)
		end
	end
	table.sort(fixtureNames, function(a, b)
		if a == "ClaraS14" then return true end
		if b == "ClaraS14" then return false end
		return a < b
	end)
end

-- State UI & Patch
local state = {
	activeTab = "patch",
	page = 1,
	slotsPerPage = 12,
	fixtureIndex = 1,
	universe = 1,
	patchedList = {},
	rawFixtures = {},
}

local function getSelectedFixtureName()
	return fixtureNames[state.fixtureIndex] or "ClaraS14"
end

local function getNextFreeAddress(univ)
	local cursor = 1
	for _, item in ipairs(state.patchedList) do
		if item.Universe == univ then
			local endAddr = (item.Address or 1) + (item.Span or 1) - 1
			if endAddr >= cursor then
				cursor = endAddr + 1
			end
		end
	end
	return math.clamp(cursor, 1, 512)
end

-- Build ScreenGui 360x465
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DmxConsoleGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainWindow"
mainFrame.Size = UDim2.fromOffset(360, 465)
mainFrame.Position = UDim2.new(0.5, -180, 0.5, -232.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(58, 58, 60)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 18)
mainCorner.Parent = mainFrame

-- Header controls (— dan ◇)
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, -24, 0, 34)
topBar.Position = UDim2.fromOffset(12, 8)
topBar.BackgroundTransparency = 1
topBar.Parent = mainFrame

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.fromOffset(32, 26)
minBtn.Position = UDim2.new(1, -74, 0, 4)
minBtn.BackgroundTransparency = 1
minBtn.Text = "—"
minBtn.TextColor3 = Color3.fromRGB(220, 220, 224)
minBtn.TextSize = 20
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = topBar

local diamondBtn = Instance.new("TextButton")
diamondBtn.Size = UDim2.fromOffset(26, 26)
diamondBtn.Position = UDim2.new(1, -30, 0, 4)
diamondBtn.BackgroundColor3 = Color3.fromRGB(165, 165, 168)
diamondBtn.Text = ""
diamondBtn.Rotation = 45
diamondBtn.BorderSizePixel = 0
diamondBtn.Parent = topBar

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -24, 0, 1)
divider.Position = UDim2.fromOffset(12, 44)
divider.BackgroundColor3 = Color3.fromRGB(150, 150, 154)
divider.BorderSizePixel = 0
divider.Parent = mainFrame

-- Tabs: patch | Preferensi | main | Setting
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

-- Body Patch Container
local patchBody = Instance.new("Frame")
patchBody.Name = "PatchBody"
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

-- Grid 1..12 bersih tanpa label singkatan atas
local gridFrame = Instance.new("Frame")
gridFrame.Size = UDim2.new(1, 0, 0, 96)
gridFrame.Position = UDim2.fromOffset(0, 2)
gridFrame.BackgroundTransparency = 1
gridFrame.Parent = patchBody

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(49, 43)
gridLayout.CellPadding = UDim2.fromOffset(6.5, 8)
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local slotButtons = {}
for i = 1, state.slotsPerPage do
	local slot = Instance.new("TextButton")
	slot.Name = "Slot_" .. i
	slot.LayoutOrder = i
	slot.BackgroundColor3 = Color3.fromRGB(72, 72, 75)
	slot.Text = tostring(i)
	slot.TextColor3 = Color3.fromRGB(40, 40, 42)
	slot.TextSize = 15
	slot.Font = Enum.Font.GothamBold
	slot.BorderSizePixel = 0
	slot.Parent = gridFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(32, 32, 34)
	stroke.Thickness = 1.5
	stroke.Parent = slot

	slotButtons[i] = slot
end

-- page 1 & next page >
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

-- Tombol add fixture +
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

local addCorner = Instance.new("UICorner")
addCorner.CornerRadius = UDim.new(0, 8)
addCorner.Parent = addFixtureBtn

-- Baris < Fixture name >
local fixtureRow = Instance.new("Frame")
fixtureRow.Size = UDim2.new(1, 0, 0, 32)
fixtureRow.Position = UDim2.fromOffset(0, 184)
fixtureRow.BackgroundColor3 = Color3.fromRGB(74, 74, 77)
fixtureRow.BorderSizePixel = 0
fixtureRow.Parent = patchBody

local fixCorner = Instance.new("UICorner")
fixCorner.CornerRadius = UDim.new(1, 0)
fixCorner.Parent = fixtureRow

local fixStroke = Instance.new("UIStroke")
fixStroke.Color = Color3.fromRGB(34, 34, 36)
fixStroke.Thickness = 1.5
fixStroke.Parent = fixtureRow

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

-- Helper pill button / box
local function createPillBox(yPos, isInput, placeholderText)
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
		box.PlaceholderText = placeholderText
		box.PlaceholderColor3 = Color3.fromRGB(48, 48, 52)
		box.ClearTextOnFocus = false
	else
		box.Text = placeholderText
	end

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = box

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(34, 34, 36)
	stroke.Thickness = 1.5
	stroke.Parent = box

	return box
end

local countBox = createPillBox(222, true, "count fixture your add")
local universeBtn = createPillBox(258, false, "Universe 1")
local autoCalcBtn = createPillBox(294, false, "Auto calculate")

-- Badge U1 • 193 di pojok kanan bawah
local addrBadge = Instance.new("TextLabel")
addrBadge.Size = UDim2.fromOffset(78, 24)
addrBadge.Position = UDim2.new(1, -78, 1, -24)
addrBadge.BackgroundColor3 = Color3.fromRGB(168, 168, 172)
addrBadge.Text = "U" .. state.universe .. " • " .. getNextFreeAddress(state.universe)
addrBadge.TextColor3 = Color3.fromRGB(30, 30, 32)
addrBadge.TextSize = 12
addrBadge.Font = Enum.Font.GothamMedium
addrBadge.BorderSizePixel = 0
addrBadge.Parent = patchBody

local badgeCorner = Instance.new("UICorner")
badgeCorner.CornerRadius = UDim.new(0, 6)
badgeCorner.Parent = addrBadge

-- Refresh tampilan Grid, Page, Fixture, dan Badge
local function refreshUI()
	fixtureNameLabel.Text = getSelectedFixtureName()
	universeBtn.Text = "Universe " .. state.universe
	pageLabel.Text = "page " .. state.page

	local startIdx = (state.page - 1) * state.slotsPerPage
	for i = 1, state.slotsPerPage do
		local globalIndex = startIdx + i
		local patchedItem = state.patchedList[globalIndex]
		local btn = slotButtons[i]

		if patchedItem then
			btn.Text = tostring(patchedItem.Address)
			btn.TextColor3 = Color3.fromRGB(240, 245, 255)
			btn.BackgroundColor3 = Color3.fromRGB(48, 86, 132)
		else
			btn.Text = tostring(globalIndex)
			btn.TextColor3 = Color3.fromRGB(40, 40, 42)
			btn.BackgroundColor3 = Color3.fromRGB(72, 72, 75)
		end
	end

	addrBadge.Text = "U" .. state.universe .. " • " .. getNextFreeAddress(state.universe)
end

-- Wiring Tab
for _, tName in ipairs(tabNames) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(77, 26)
	btn.Text = tName
	btn.TextSize = 12
	btn.Font = Enum.Font.GothamMedium
	btn.BorderSizePixel = 0
	btn.Parent = tabContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn

	tabButtons[tName] = btn

	btn.MouseButton1Click:Connect(function()
		state.activeTab = tName
		for name, b in pairs(tabButtons) do
			if name == state.activeTab then
				b.BackgroundColor3 = Color3.fromRGB(33, 134, 235)
				b.TextColor3 = Color3.fromRGB(245, 248, 255)
			else
				b.BackgroundColor3 = Color3.fromRGB(115, 115, 119)
				b.TextColor3 = Color3.fromRGB(32, 32, 34)
			end
		end

		local isPatch = (state.activeTab == "patch")
		gridFrame.Visible = isPatch
		pageLabel.Visible = isPatch
		nextPageBtn.Visible = isPatch
		addFixtureBtn.Visible = isPatch
		fixtureRow.Visible = isPatch
		countBox.Visible = isPatch
		universeBtn.Visible = isPatch
		autoCalcBtn.Visible = isPatch
		addrBadge.Visible = isPatch
		placeholderBody.Visible = not isPatch
		placeholderBody.Text = "Tab: " .. state.activeTab
	end)
end

-- Set tab aktif awal ke "patch"
for name, b in pairs(tabButtons) do
	if name == "patch" then
		b.BackgroundColor3 = Color3.fromRGB(33, 134, 235)
		b.TextColor3 = Color3.fromRGB(245, 248, 255)
	else
		b.BackgroundColor3 = Color3.fromRGB(115, 115, 119)
		b.TextColor3 = Color3.fromRGB(32, 32, 34)
	end
end

-- Ganti fixture (< / >)
prevFixBtn.MouseButton1Click:Connect(function()
	state.fixtureIndex = ((state.fixtureIndex - 2) % #fixtureNames) + 1
	refreshUI()
end)

nextFixBtn.MouseButton1Click:Connect(function()
	state.fixtureIndex = (state.fixtureIndex % #fixtureNames) + 1
	refreshUI()
end)

-- Ganti Universe 1 / Universe 2
universeBtn.MouseButton1Click:Connect(function()
	state.universe = (state.universe == 1) and 2 or 1
	refreshUI()
end)

-- Auto calculate -> scan DmxLights vehicle & isi countBox
autoCalcBtn.MouseButton1Click:Connect(function()
	local selected = getSelectedFixtureName()
	local totalFound = PatchEngine.CountVehicleFixtures(player, selected)
	countBox.Text = tostring(totalFound)
end)

-- add fixture + -> patch sesuai countBox
addFixtureBtn.MouseButton1Click:Connect(function()
	local qty = tonumber(countBox.Text)
	if not qty or qty < 1 then
		qty = 1
	end
	qty = math.floor(qty)

	local selected = getSelectedFixtureName()
	for _ = 1, qty do
		table.insert(state.rawFixtures, {
			Type = selected,
			Universe = state.universe,
			Address = nil, -- dihitung otomatis oleh PatchEngine.AutoAddress
		})
	end

	PatchEngine.AutoAddress(state.rawFixtures, nil, 2)
	state.patchedList = PatchEngine.PatchAll(state.rawFixtures, nil, nil, false)
	refreshUI()
end)

-- next page >
nextPageBtn.MouseButton1Click:Connect(function()
	local totalPages = math.max(1, math.ceil(#state.patchedList / state.slotsPerPage))
	state.page = (state.page % totalPages) + 1
	refreshUI()
end)

-- Minimize (—) & toggle compact view (◇)
minBtn.MouseButton1Click:Connect(function()
	local isCollapsed = mainFrame.Size.Y.Offset <= 52
	mainFrame.Size = isCollapsed and UDim2.fromOffset(360, 465) or UDim2.fromOffset(360, 48)
	tabContainer.Visible = isCollapsed
	patchBody.Visible = isCollapsed
end)

diamondBtn.MouseButton1Click:Connect(function()
	state.page = 1
	refreshUI()
end)

refreshUI()
