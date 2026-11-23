local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("MixerDmxUI") then
	playerGui.MixerDmxUI:Destroy()
end

local deviceCatalog = {
	{ name = "Device1", ch = 16 },
	{ name = "Clara514", ch = 16 },
	{ name = "ParledX64", ch = 6 },
	{ name = "Strobo_1000W", ch = 8 },
	{ name = "MiniBrute_4X", ch = 8 },
	{ name = "Wallwasher_24X3W", ch = 8 },
	{ name = "BlinderRing_2x50W", ch = 12 },
}

local CH_PER_PAGE = 16
local PAGE_COUNT = 6
local currentPage = 1
local selectedCh = 1
local selectedDeviceIndex = 1
local isMinimized = false

local pages = {}
for p = 1, PAGE_COUNT do
	pages[p] = {}
	for c = 1, CH_PER_PAGE do
		pages[p][c] = {
			page = p,
			chSlot = c,
			device = nil,
			chCount = 0,
			dmx = 1,
			universe = 1,
		}
	end
end

local onPatchChanged = function(activeSlotData, allPages)
	-- Sambungkan ke PatchEngine / ConsoleEngine saat siap
end

local function getUsedChannels(universe, skipPage, skipSlot)
	local maxEnd = 0
	for p = 1, PAGE_COUNT do
		for c = 1, CH_PER_PAGE do
			if not (p == skipPage and c == skipSlot) then
				local item = pages[p][c]
				if item.device and item.universe == universe then
					local endAddr = item.dmx + item.chCount - 1
					if endAddr > maxEnd then
						maxEnd = endAddr
					end
				end
			end
		end
	end
	return math.clamp(maxEnd, 0, 512)
end

local function calculateNextDmx(universe, skipPage, skipSlot)
	local used = getUsedChannels(universe, skipPage, skipSlot)
	return math.clamp(used + 1, 1, 512)
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MixerDmxUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 310, 0, 520)
mainFrame.Position = UDim2.new(0.5, -155, 0.5, -260)
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 26, 33)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(60, 72, 90)
mainStroke.Thickness = 1.5
mainStroke.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 0, 34)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Mixer dmx"
title.TextColor3 = Color3.fromRGB(240, 245, 255)
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

local btnMin = Instance.new("TextButton")
btnMin.Size = UDim2.new(0, 24, 0, 22)
btnMin.Position = UDim2.new(1, -60, 0, 6)
btnMin.BackgroundColor3 = Color3.fromRGB(34, 40, 50)
btnMin.Text = "-"
btnMin.TextColor3 = Color3.fromRGB(220, 230, 245)
btnMin.TextSize = 14
btnMin.Font = Enum.Font.GothamBold
btnMin.Parent = mainFrame
Instance.new("UICorner", btnMin).CornerRadius = UDim.new(0, 5)

local btnDiamond = Instance.new("TextButton")
btnDiamond.Size = UDim2.new(0, 24, 0, 22)
btnDiamond.Position = UDim2.new(1, -32, 0, 6)
btnDiamond.BackgroundColor3 = Color3.fromRGB(34, 40, 50)
btnDiamond.Text = "◇"
btnDiamond.TextColor3 = Color3.fromRGB(220, 230, 245)
btnDiamond.TextSize = 12
btnDiamond.Font = Enum.Font.GothamBold
btnDiamond.Parent = mainFrame
Instance.new("UICorner", btnDiamond).CornerRadius = UDim.new(0, 5)

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -16, 0, 1)
divider.Position = UDim2.new(0, 8, 0, 34)
divider.BackgroundColor3 = Color3.fromRGB(55, 65, 80)
divider.BorderSizePixel = 0
divider.Parent = mainFrame

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -36)
body.Position = UDim2.new(0, 0, 0, 36)
body.BackgroundTransparency = 1
body.Parent = mainFrame

-- Baris atas: Patch + 6 Page (P1..P6)
local btnPatch = Instance.new("TextButton")
btnPatch.Size = UDim2.new(0, 64, 0, 26)
btnPatch.Position = UDim2.new(0, 10, 0, 4)
btnPatch.BackgroundColor3 = Color3.fromRGB(32, 39, 50)
btnPatch.Text = "Patch"
btnPatch.TextColor3 = Color3.fromRGB(255, 255, 255)
btnPatch.TextSize = 11
btnPatch.Font = Enum.Font.GothamBold
btnPatch.Parent = body
Instance.new("UICorner", btnPatch).CornerRadius = UDim.new(0, 6)

local pageBar = Instance.new("Frame")
pageBar.Size = UDim2.new(1, -84, 0, 26)
pageBar.Position = UDim2.new(0, 78, 0, 4)
pageBar.BackgroundTransparency = 1
pageBar.Parent = body

local pageGrid = Instance.new("UIGridLayout")
pageGrid.CellSize = UDim2.new(1 / PAGE_COUNT, -3, 1, 0)
pageGrid.CellPadding = UDim2.new(0, 3, 0, 0)
pageGrid.Parent = pageBar

local pageButtons = {}
for p = 1, PAGE_COUNT do
	local pb = Instance.new("TextButton")
	pb.BackgroundColor3 = Color3.fromRGB(26, 31, 40)
	pb.Text = "P" .. p
	pb.TextColor3 = Color3.fromRGB(210, 220, 235)
	pb.TextSize = 10
	pb.Font = Enum.Font.GothamBold
	pb.Parent = pageBar
	Instance.new("UICorner", pb).CornerRadius = UDim.new(0, 5)
	pageButtons[p] = pb

	pb.MouseButton1Click:Connect(function()
		currentPage = p
		refreshUI()
	end)
end

-- Grid 16 Channel (4x4)
local chGridFrame = Instance.new("Frame")
chGridFrame.Size = UDim2.new(1, -20, 0, 152)
chGridFrame.Position = UDim2.new(0, 10, 0, 36)
chGridFrame.BackgroundTransparency = 1
chGridFrame.Parent = body

local chGrid = Instance.new("UIGridLayout")
chGrid.CellSize = UDim2.new(0.25, -5, 0.25, -5)
chGrid.CellPadding = UDim2.new(0, 6, 0, 6)
chGrid.Parent = chGridFrame

local chButtons = {}

-- List Device
local deviceListFrame = Instance.new("ScrollingFrame")
deviceListFrame.Size = UDim2.new(1, -20, 0, 96)
deviceListFrame.Position = UDim2.new(0, 10, 0, 194)
deviceListFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 26)
deviceListFrame.BorderSizePixel = 0
deviceListFrame.ScrollBarThickness = 3
deviceListFrame.Parent = body
Instance.new("UICorner", deviceListFrame).CornerRadius = UDim.new(0, 7)

local devLayout = Instance.new("UIListLayout")
devLayout.Padding = UDim.new(0, 3)
devLayout.Parent = deviceListFrame

local devPad = Instance.new("UIPadding")
devPad.PaddingTop = UDim.new(0, 4)
devPad.PaddingLeft = UDim.new(0, 6)
devPad.PaddingRight = UDim.new(0, 6)
devPad.Parent = deviceListFrame

-- Panel Detail Slot Terpilih
local infoPanel = Instance.new("Frame")
infoPanel.Size = UDim2.new(1, -20, 0, 178)
infoPanel.Position = UDim2.new(0, 10, 0, 296)
infoPanel.BackgroundColor3 = Color3.fromRGB(16, 20, 26)
infoPanel.BorderSizePixel = 0
infoPanel.Parent = body
Instance.new("UICorner", infoPanel).CornerRadius = UDim.new(0, 7)

local btnActiveDevice = Instance.new("TextButton")
btnActiveDevice.Size = UDim2.new(0, 134, 0, 28)
btnActiveDevice.Position = UDim2.new(0, 8, 0, 8)
btnActiveDevice.BackgroundColor3 = Color3.fromRGB(30, 37, 48)
btnActiveDevice.Text = deviceCatalog[1].name
btnActiveDevice.TextColor3 = Color3.fromRGB(240, 245, 255)
btnActiveDevice.TextSize = 11
btnActiveDevice.Font = Enum.Font.GothamBold
btnActiveDevice.Parent = infoPanel
Instance.new("UICorner", btnActiveDevice).CornerRadius = UDim.new(0, 6)

local lblSlotTag = Instance.new("TextLabel")
lblSlotTag.Size = UDim2.new(1, -152, 0, 28)
lblSlotTag.Position = UDim2.new(0, 144, 0, 8)
lblSlotTag.BackgroundTransparency = 1
lblSlotTag.Text = "P1 • CH 01"
lblSlotTag.TextColor3 = Color3.fromRGB(145, 160, 180)
lblSlotTag.TextSize = 10
lblSlotTag.Font = Enum.Font.GothamBold
lblSlotTag.TextXAlignment = Enum.TextXAlignment.Right
lblSlotTag.Parent = infoPanel

local lblDmxAndCh = Instance.new("TextLabel")
lblDmxAndCh.Size = UDim2.new(1, -16, 0, 24)
lblDmxAndCh.Position = UDim2.new(0, 8, 0, 42)
lblDmxAndCh.BackgroundTransparency = 1
lblDmxAndCh.Text = "Dmx 001 | U1: 0/512 | U2: 0/512"
lblDmxAndCh.TextColor3 = Color3.fromRGB(220, 230, 245)
lblDmxAndCh.TextSize = 11
lblDmxAndCh.Font = Enum.Font.GothamMedium
lblDmxAndCh.TextXAlignment = Enum.TextXAlignment.Left
lblDmxAndCh.Parent = infoPanel

local btnUniverse = Instance.new("TextButton")
btnUniverse.Size = UDim2.new(1, -16, 0, 32)
btnUniverse.Position = UDim2.new(0, 8, 0, 72)
btnUniverse.BackgroundColor3 = Color3.fromRGB(26, 32, 42)
btnUniverse.Text = "Universe 1 (touch tu u2)"
btnUniverse.TextColor3 = Color3.fromRGB(130, 205, 255)
btnUniverse.TextSize = 11
btnUniverse.Font = Enum.Font.GothamBold
btnUniverse.TextXAlignment = Enum.TextXAlignment.Left
btnUniverse.Parent = infoPanel
Instance.new("UICorner", btnUniverse).CornerRadius = UDim.new(0, 6)
local uPad = Instance.new("UIPadding")
uPad.PaddingLeft = UDim.new(0, 8)
uPad.Parent = btnUniverse

local btnAutoCalc = Instance.new("TextButton")
btnAutoCalc.Size = UDim2.new(1, -16, 0, 46)
btnAutoCalc.Position = UDim2.new(0, 8, 0, 114)
btnAutoCalc.BackgroundColor3 = Color3.fromRGB(45, 145, 200)
btnAutoCalc.Text = "Auto calculate"
btnAutoCalc.TextColor3 = Color3.fromRGB(255, 255, 255)
btnAutoCalc.TextSize = 12
btnAutoCalc.Font = Enum.Font.GothamBold
btnAutoCalc.Parent = infoPanel
Instance.new("UICorner", btnAutoCalc).CornerRadius = UDim.new(0, 6)

local function refreshUI()
	for p = 1, PAGE_COUNT do
		pageButtons[p].BackgroundColor3 = (p == currentPage)
			and Color3.fromRGB(45, 145, 200)
			or Color3.fromRGB(26, 31, 40)
	end

	local pageData = pages[currentPage]
	for c = 1, CH_PER_PAGE do
		local btn = chButtons[c]
		local item = pageData[c]
		local isSel = (c == selectedCh)
		btn.BackgroundColor3 = isSel and Color3.fromRGB(45, 145, 200)
			or (item.device and Color3.fromRGB(32, 42, 56) or Color3.fromRGB(26, 31, 40))
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	local activeItem = pageData[selectedCh]
	local activeDev = deviceCatalog[selectedDeviceIndex]

	btnActiveDevice.Text = activeItem.device or activeDev.name
	lblSlotTag.Text = string.format("P%d • CH %02d", currentPage, selectedCh)

	local dmxVal = activeItem.device and activeItem.dmx or calculateNextDmx(activeItem.universe, currentPage, selectedCh)
	local u1Used = getUsedChannels(1)
	local u2Used = getUsedChannels(2)
	lblDmxAndCh.Text = string.format("Dmx %03d | U1: %d/512 | U2: %d/512", dmxVal, u1Used, u2Used)

	if activeItem.universe == 1 then
		btnUniverse.Text = "Universe 1 (touch tu u2)"
	else
		btnUniverse.Text = "Universe 2 (touch tu u1)"
	end

	onPatchChanged(activeItem, pages)
end

for c = 1, CH_PER_PAGE do
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Color3.fromRGB(26, 31, 40)
	b.Text = tostring(c)
	b.TextColor3 = Color3.fromRGB(220, 230, 245)
	b.TextSize = 12
	b.Font = Enum.Font.GothamBold
	b.Parent = chGridFrame
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	chButtons[c] = b

	b.MouseButton1Click:Connect(function()
		selectedCh = c
		refreshUI()
	end)
end

for idx, dev in ipairs(deviceCatalog) do
	local rowBtn = Instance.new("TextButton")
	rowBtn.Size = UDim2.new(1, 0, 0, 24)
	rowBtn.BackgroundColor3 = Color3.fromRGB(26, 31, 40)
	rowBtn.Text = string.format("%d. %s (%dch)", idx, dev.name, dev.ch)
	rowBtn.TextColor3 = Color3.fromRGB(220, 230, 245)
	rowBtn.TextSize = 10
	rowBtn.Font = Enum.Font.GothamMedium
	rowBtn.TextXAlignment = Enum.TextXAlignment.Left
	rowBtn.Parent = deviceListFrame
	Instance.new("UICorner", rowBtn).CornerRadius = UDim.new(0, 5)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.Parent = rowBtn

	rowBtn.MouseButton1Click:Connect(function()
		selectedDeviceIndex = idx
		local item = pages[currentPage][selectedCh]
		item.device = dev.name
		item.chCount = dev.ch
		item.dmx = calculateNextDmx(item.universe, currentPage, selectedCh)
		refreshUI()
	end)
end
deviceListFrame.CanvasSize = UDim2.new(0, 0, 0, #deviceCatalog * 27 + 6)

btnActiveDevice.MouseButton1Click:Connect(function()
	selectedDeviceIndex += 1
	if selectedDeviceIndex > #deviceCatalog then
		selectedDeviceIndex = 1
	end
	local dev = deviceCatalog[selectedDeviceIndex]
	local item = pages[currentPage][selectedCh]
	item.device = dev.name
	item.chCount = dev.ch
	item.dmx = calculateNextDmx(item.universe, currentPage, selectedCh)
	refreshUI()
end)

btnUniverse.MouseButton1Click:Connect(function()
	local item = pages[currentPage][selectedCh]
	item.universe = (item.universe == 1) and 2 or 1
	if item.device then
		item.dmx = calculateNextDmx(item.universe, currentPage, selectedCh)
	end
	refreshUI()
end)

btnAutoCalc.MouseButton1Click:Connect(function()
	local item = pages[currentPage][selectedCh]
	local dev = deviceCatalog[selectedDeviceIndex]
	if not item.device then
		item.device = dev.name
		item.chCount = dev.ch
	end
	item.dmx = calculateNextDmx(item.universe, currentPage, selectedCh)
	refreshUI()
end)

btnMin.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	body.Visible = not isMinimized
	divider.Visible = not isMinimized
	mainFrame.Size = isMinimized and UDim2.new(0, 310, 0, 34) or UDim2.new(0, 310, 0, 520)
end)

btnDiamond.MouseButton1Click:Connect(function()
	screenGui:Destroy()
end)

refreshUI()
