local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("ConsoleUI") then
	playerGui.ConsoleUI:Destroy()
end

local deviceCatalog = {
	{ name = "Clara", ch = 16 },
	{ name = "Clara514", ch = 16 },
	{ name = "ParledX64", ch = 6 },
	{ name = "Strobo_1000W", ch = 8 },
	{ name = "MiniBrute_4X", ch = 8 },
	{ name = "Wallwasher_24X3W", ch = 8 },
	{ name = "BlinderRing_2x50W", ch = 12 },
}

local WIDTH_X = 360
local HEIGHT_Y = 465
local CH_PER_PAGE = 16
local PAGE_COUNT = 6
local currentPage = 1
local lastActiveCh = 1
local selectedDeviceIndex = 1
local isMinimized = false

local BLUE_ACTIVE = Color3.fromRGB(45, 145, 200)
local PATCHED_IDLE = Color3.fromRGB(32, 42, 56)
local EMPTY_IDLE = Color3.fromRGB(26, 31, 40)

local refreshUI

local pages = {}
for p = 1, PAGE_COUNT do
	pages[p] = {}
	for c = 1, CH_PER_PAGE do
		pages[p][c] = {
			page = p,
			chSlot = c,
			selected = false,
			device = nil,
			chCount = 0,
			dmx = 0,
			universe = 1,
		}
	end
end

pages[1][1].selected = true

local onPatchChanged = function(selectedItems, firstItem, allPages)
	-- Sambungkan ke ConsoleEngine saat siap
end

-- Batas alamat terakhir yang terpakai di satu universe
local function getMaxEnd(universe, skipSet)
	local maxEnd = 0
	for p = 1, PAGE_COUNT do
		for c = 1, CH_PER_PAGE do
			local key = p .. ":" .. c
			local item = pages[p][c]
			if not (skipSet and skipSet[key]) and item.device and item.universe == universe then
				local endAddr = item.dmx + item.chCount - 1
				if endAddr > maxEnd then
					maxEnd = endAddr
				end
			end
		end
	end
	return maxEnd
end

-- Kasih alamat berurutan ke semua slot target (pakai chCount tiap device)
local function assignSequentialDmx(targets, devName, chCount)
	if #targets == 0 then return end

	local skipSet = {}
	for _, item in ipairs(targets) do
		skipSet[item.page .. ":" .. item.chSlot] = true
	end

	local cursors = {
		[1] = getMaxEnd(1, skipSet) + 1,
		[2] = getMaxEnd(2, skipSet) + 1,
	}

	for _, item in ipairs(targets) do
		local u = (item.universe == 2) and 2 or 1
		local useCh = chCount or (item.chCount > 0 and item.chCount or 16)
		local startAddr = cursors[u]

		item.device = devName or item.device or deviceCatalog[selectedDeviceIndex].name
		item.chCount = useCh
		item.dmx = startAddr

		cursors[u] = startAddr + useCh
	end
end

local function getSelectedInCurrentPage()
	local list = {}
	for c = 1, CH_PER_PAGE do
		if pages[currentPage][c].selected then
			table.insert(list, pages[currentPage][c])
		end
	end
	return list
end

local function getTargets()
	local targets = getSelectedInCurrentPage()
	if #targets == 0 then
		targets = { pages[currentPage][lastActiveCh] }
	end
	return targets
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ConsoleUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, WIDTH_X, 0, HEIGHT_Y)
mainFrame.Position = UDim2.new(0.5, -math.floor(WIDTH_X / 2), 0.5, -math.floor(HEIGHT_Y / 2))
mainFrame.BackgroundColor3 = Color3.fromRGB(22, 26, 33)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -80, 0, 32)
title.Position = UDim2.new(0, 12, 0, 0)
title.BackgroundTransparency = 1
title.Text = "Console"
title.TextColor3 = Color3.fromRGB(240, 245, 255)
title.TextSize = 13
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = mainFrame

local btnMin = Instance.new("TextButton")
btnMin.Size = UDim2.new(0, 24, 0, 22)
btnMin.Position = UDim2.new(1, -60, 0, 5)
btnMin.BackgroundColor3 = Color3.fromRGB(34, 40, 50)
btnMin.Text = "-"
btnMin.TextColor3 = Color3.fromRGB(220, 230, 245)
btnMin.TextSize = 14
btnMin.Font = Enum.Font.GothamBold
btnMin.Parent = mainFrame
Instance.new("UICorner", btnMin).CornerRadius = UDim.new(0, 5)

local btnClose = Instance.new("TextButton")
btnClose.Size = UDim2.new(0, 24, 0, 22)
btnClose.Position = UDim2.new(1, -32, 0, 5)
btnClose.BackgroundColor3 = Color3.fromRGB(34, 40, 50)
btnClose.Text = "x"
btnClose.TextColor3 = Color3.fromRGB(220, 230, 245)
btnClose.TextSize = 12
btnClose.Font = Enum.Font.GothamBold
btnClose.Parent = mainFrame
Instance.new("UICorner", btnClose).CornerRadius = UDim.new(0, 5)

local body = Instance.new("Frame")
body.Size = UDim2.new(1, 0, 1, -34)
body.Position = UDim2.new(0, 0, 0, 34)
body.BackgroundTransparency = 1
body.Parent = mainFrame

-- Grid 16 channel
local chGridFrame = Instance.new("Frame")
chGridFrame.Size = UDim2.new(1, -20, 0, 132)
chGridFrame.Position = UDim2.new(0, 10, 0, 6)
chGridFrame.BackgroundTransparency = 1
chGridFrame.Parent = body

local chGrid = Instance.new("UIGridLayout")
chGrid.CellSize = UDim2.new(0.25, -5, 0.25, -4)
chGrid.CellPadding = UDim2.new(0, 6, 0, 5)
chGrid.Parent = chGridFrame

-- Bar P1..P6 (di bawah grid channel)
local pageBar = Instance.new("Frame")
pageBar.Size = UDim2.new(1, -20, 0, 28)
pageBar.Position = UDim2.new(0, 10, 0, 146)
pageBar.BackgroundColor3 = Color3.fromRGB(16, 20, 26)
pageBar.BorderSizePixel = 0
pageBar.Parent = body
Instance.new("UICorner", pageBar).CornerRadius = UDim.new(0, 6)

local pageButtons = {}
local gap = 4
local btnW = math.floor((WIDTH_X - 20 - gap * (PAGE_COUNT + 1)) / PAGE_COUNT)

for p = 1, PAGE_COUNT do
	local pb = Instance.new("TextButton")
	pb.Size = UDim2.new(0, btnW, 0, 22)
	pb.Position = UDim2.new(0, gap + (p - 1) * (btnW + gap), 0, 3)
	pb.BackgroundColor3 = EMPTY_IDLE
	pb.Text = "P" .. p
	pb.TextColor3 = Color3.fromRGB(220, 230, 245)
	pb.TextSize = 10
	pb.Font = Enum.Font.GothamBold
	pb.Parent = pageBar
	Instance.new("UICorner", pb).CornerRadius = UDim.new(0, 5)
	pageButtons[p] = pb

	pb.MouseButton1Click:Connect(function()
		currentPage = p
		local hasSel = false
		for c = 1, CH_PER_PAGE do
			if pages[currentPage][c].selected then
				hasSel = true
				break
			end
		end
		if not hasSel then
			pages[currentPage][lastActiveCh].selected = true
		end
		refreshUI()
	end)
end

-- Bawah: kiri list device, kanan detail
local bottomSplit = Instance.new("Frame")
bottomSplit.Size = UDim2.new(1, -20, 0, 212)
bottomSplit.Position = UDim2.new(0, 10, 0, 184)
bottomSplit.BackgroundTransparency = 1
bottomSplit.Parent = body

local deviceListFrame = Instance.new("ScrollingFrame")
deviceListFrame.Size = UDim2.new(0.46, -4, 1, 0)
deviceListFrame.BackgroundColor3 = Color3.fromRGB(16, 20, 26)
deviceListFrame.BorderSizePixel = 0
deviceListFrame.ScrollBarThickness = 3
deviceListFrame.Parent = bottomSplit
Instance.new("UICorner", deviceListFrame).CornerRadius = UDim.new(0, 7)

local devLayout = Instance.new("UIListLayout")
devLayout.Padding = UDim.new(0, 3)
devLayout.Parent = deviceListFrame

local devPad = Instance.new("UIPadding")
devPad.PaddingTop = UDim.new(0, 4)
devPad.PaddingLeft = UDim.new(0, 6)
devPad.PaddingRight = UDim.new(0, 6)
devPad.Parent = deviceListFrame

local infoPanel = Instance.new("Frame")
infoPanel.Size = UDim2.new(0.54, -4, 1, 0)
infoPanel.Position = UDim2.new(0.46, 8, 0, 0)
infoPanel.BackgroundColor3 = Color3.fromRGB(16, 20, 26)
infoPanel.BorderSizePixel = 0
infoPanel.Parent = bottomSplit
Instance.new("UICorner", infoPanel).CornerRadius = UDim.new(0, 7)

local btnActiveDevice = Instance.new("TextButton")
btnActiveDevice.Size = UDim2.new(0, 96, 0, 28)
btnActiveDevice.Position = UDim2.new(0, 8, 0, 8)
btnActiveDevice.BackgroundColor3 = Color3.fromRGB(30, 37, 48)
btnActiveDevice.Text = deviceCatalog[1].name
btnActiveDevice.TextColor3 = Color3.fromRGB(240, 245, 255)
btnActiveDevice.TextSize = 11
btnActiveDevice.Font = Enum.Font.GothamBold
btnActiveDevice.Parent = infoPanel
Instance.new("UICorner", btnActiveDevice).CornerRadius = UDim.new(0, 6)

local lblSelSummary = Instance.new("TextLabel")
lblSelSummary.Size = UDim2.new(1, -112, 0, 28)
lblSelSummary.Position = UDim2.new(0, 108, 0, 8)
lblSelSummary.BackgroundTransparency = 1
lblSelSummary.Text = "P1 • Biru: 1"
lblSelSummary.TextColor3 = Color3.fromRGB(130, 205, 255)
lblSelSummary.TextSize = 10
lblSelSummary.Font = Enum.Font.GothamBold
lblSelSummary.TextXAlignment = Enum.TextXAlignment.Right
lblSelSummary.Parent = infoPanel

local lblDmxAddr = Instance.new("TextLabel")
lblDmxAddr.Size = UDim2.new(1, -16, 0, 26)
lblDmxAddr.Position = UDim2.new(0, 8, 0, 44)
lblDmxAddr.BackgroundTransparency = 1
lblDmxAddr.Text = "Dmx 001"
lblDmxAddr.TextColor3 = Color3.fromRGB(220, 230, 245)
lblDmxAddr.TextSize = 11
lblDmxAddr.Font = Enum.Font.GothamMedium
lblDmxAddr.TextXAlignment = Enum.TextXAlignment.Left
lblDmxAddr.Parent = infoPanel

local btnUniverse = Instance.new("TextButton")
btnUniverse.Size = UDim2.new(1, -16, 0, 34)
btnUniverse.Position = UDim2.new(0, 8, 0, 78)
btnUniverse.BackgroundColor3 = Color3.fromRGB(26, 32, 42)
btnUniverse.Text = "Universe 1 (touch tu u2)"
btnUniverse.TextColor3 = Color3.fromRGB(130, 205, 255)
btnUniverse.TextSize = 10
btnUniverse.Font = Enum.Font.GothamBold
btnUniverse.TextXAlignment = Enum.TextXAlignment.Left
btnUniverse.Parent = infoPanel
Instance.new("UICorner", btnUniverse).CornerRadius = UDim.new(0, 6)
local uPad = Instance.new("UIPadding")
uPad.PaddingLeft = UDim.new(0, 8)
uPad.Parent = btnUniverse

local btnAutoCalc = Instance.new("TextButton")
btnAutoCalc.Size = UDim2.new(1, -16, 0, 56)
btnAutoCalc.Position = UDim2.new(0, 8, 0, 146)
btnAutoCalc.BackgroundColor3 = BLUE_ACTIVE
btnAutoCalc.Text = "Auto calculate"
btnAutoCalc.TextColor3 = Color3.fromRGB(255, 255, 255)
btnAutoCalc.TextSize = 12
btnAutoCalc.Font = Enum.Font.GothamBold
btnAutoCalc.Parent = infoPanel
Instance.new("UICorner", btnAutoCalc).CornerRadius = UDim.new(0, 6)

-- Grid channel dibuat dulu supaya refreshUI punya tombolnya
local chButtons = {}
for c = 1, CH_PER_PAGE do
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = EMPTY_IDLE
	b.Text = tostring(c)
	b.TextColor3 = Color3.fromRGB(220, 230, 245)
	b.TextSize = 12
	b.Font = Enum.Font.GothamBold
	b.Parent = chGridFrame
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	chButtons[c] = b

	b.MouseButton1Click:Connect(function()
		local item = pages[currentPage][c]
		item.selected = not item.selected
		lastActiveCh = c
		refreshUI()
	end)
end

refreshUI = function()
	for p = 1, PAGE_COUNT do
		pageButtons[p].BackgroundColor3 = (p == currentPage) and BLUE_ACTIVE or EMPTY_IDLE
	end

	local pageData = pages[currentPage]
	local selectedItems = {}

	for c = 1, CH_PER_PAGE do
		local btn = chButtons[c]
		local item = pageData[c]
		if item.selected then
			table.insert(selectedItems, item)
			btn.BackgroundColor3 = BLUE_ACTIVE
		elseif item.device then
			btn.BackgroundColor3 = PATCHED_IDLE
		else
			btn.BackgroundColor3 = EMPTY_IDLE
		end
	end

	local first = selectedItems[1] or pageData[lastActiveCh]
	local lastPatched = nil
	for _, item in ipairs(selectedItems) do
		if item.device and item.dmx > 0 then
			lastPatched = item
		end
	end

	btnActiveDevice.Text = first.device or deviceCatalog[selectedDeviceIndex].name
	lblSelSummary.Text = string.format("P%d • Biru: %d", currentPage, #selectedItems)

	if first.device and first.dmx > 0 and lastPatched and lastPatched ~= first then
		lblDmxAddr.Text = string.format("Dmx %03d..%03d", first.dmx, lastPatched.dmx + lastPatched.chCount - 1)
	elseif first.device and first.dmx > 0 then
		lblDmxAddr.Text = string.format("Dmx %03d", first.dmx)
	else
		lblDmxAddr.Text = string.format("Dmx %03d", getMaxEnd(first.universe, nil) + 1)
	end

	btnUniverse.Text = (first.universe == 1) and "Universe 1 (touch tu u2)" or "Universe 2 (touch tu u1)"

	onPatchChanged(selectedItems, first, pages)
end

local function pickDevice(idx)
	selectedDeviceIndex = idx
	local dev = deviceCatalog[idx]
	assignSequentialDmx(getTargets(), dev.name, dev.ch)
	refreshUI()
end

for idx, dev in ipairs(deviceCatalog) do
	local rowBtn = Instance.new("TextButton")
	rowBtn.Size = UDim2.new(1, 0, 0, 24)
	rowBtn.BackgroundColor3 = EMPTY_IDLE
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
		pickDevice(idx)
	end)
end
deviceListFrame.CanvasSize = UDim2.new(0, 0, 0, #deviceCatalog * 27 + 6)

btnActiveDevice.MouseButton1Click:Connect(function()
	pickDevice(selectedDeviceIndex % #deviceCatalog + 1)
end)

btnUniverse.MouseButton1Click:Connect(function()
	local targets = getTargets()
	for _, item in ipairs(targets) do
		item.universe = (item.universe == 1) and 2 or 1
	end
	assignSequentialDmx(targets, nil, nil)
	refreshUI()
end)

btnAutoCalc.MouseButton1Click:Connect(function()
	local dev = deviceCatalog[selectedDeviceIndex]
	assignSequentialDmx(getTargets(), dev.name, dev.ch)
	refreshUI()
end)

btnMin.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	body.Visible = not isMinimized
	mainFrame.Size = isMinimized and UDim2.new(0, WIDTH_X, 0, 32) or UDim2.new(0, WIDTH_X, 0, HEIGHT_Y)
end)

btnClose.MouseButton1Click:Connect(function()
	screenGui:Destroy()
end)

refreshUI()
