-- Dual_Address_Beam_Test.lua
-- Perintah 2 start address sekaligus: 1 dan 17 (ClaraS14 16-ch)

_G.StopDualBeam = true
task.wait(0.1)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer or Players.PlayerAdded:Wait()

local parentGui = (gethui and gethui()) or player:WaitForChild("PlayerGui")
local old = parentGui:FindFirstChild("DualBeamGui")
if old then old:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "DualBeamGui"
sg.ResetOnSpawn = false
sg.DisplayOrder = 1012
sg.Parent = parentGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(250, 96)
panel.Position = UDim2.fromOffset(10, 50)
panel.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = sg
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)

local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(1, -12, 0, 34)
lbl.Position = UDim2.fromOffset(6, 4)
lbl.BackgroundTransparency = 1
lbl.TextColor3 = Color3.fromRGB(120, 245, 175)
lbl.TextSize = 10
lbl.Font = Enum.Font.Code
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.TextWrapped = true
lbl.Text = "Dual Addr [1 & 17] Ready"
lbl.Parent = panel

local function getUdpRemote()
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if vehicles then
		local lp = string.lower(player.Name)
		for _, c in ipairs(vehicles:GetChildren()) do
			if c.Name == player.Name .. "'s Car" or string.find(string.lower(c.Name), lp, 1, true) then
				local r = c:FindFirstChild("UDP_DMXDATA", true)
				if r and (r:IsA("RemoteEvent") or r:IsA("UnreliableRemoteEvent")) then
					return r
				end
			end
		end
	end
	return ReplicatedStorage:FindFirstChild("UDP_DMXDATA", true) or Workspace:FindFirstChild("UDP_DMXDATA", true)
end

local lastVal = {}
local function sendCh(remote, ch, val)
	local v = math.clamp(math.floor(val), 0, 255)
	if lastVal[ch] == v then return end
	lastVal[ch] = v
	local buf = buffer.create(3)
	buffer.writeu16(buf, 0, ch)
	buffer.writeu8(buf, 2, v)
	remote:FireServer(buf)
end

local ADDRESSES = { 1, 17 }
local autoMove = false
_G.StopDualBeam = false

local function openBothGates()
	local r = getUdpRemote()
	if not r then
		lbl.Text = "UDP_DMXDATA tidak ketemu"
		return
	end
	for _, base in ipairs(ADDRESSES) do
		local off = base - 1
		sendCh(r, off + 8, 255) -- Dimmer
		sendCh(r, off + 7, 0)   -- Shutter off
	end
	lbl.Text = "Gate ON -> Addr 1 & 17"
end

local function mkBtn(txt, x, y, w, cb)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w, 24)
	b.Position = UDim2.fromOffset(x, y)
	b.BackgroundColor3 = Color3.fromRGB(45, 48, 56)
	b.TextColor3 = Color3.fromRGB(240, 242, 248)
	b.Text = txt
	b.TextSize = 10
	b.Font = Enum.Font.GothamBold
	b.BorderSizePixel = 0
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.MouseButton1Click:Connect(cb)
	return b
end

mkBtn("GATE 1&17", 6, 42, 76, openBothGates)

local moveBtn = mkBtn("AUTO: OFF", 87, 42, 76, function()
	autoMove = not autoMove
	if autoMove then
		openBothGates()
	end
end)

mkBtn("CLOSE", 168, 42, 76, function()
	_G.StopDualBeam = true
	autoMove = false
	sg:Destroy()
end)

task.spawn(function()
	local x = 128
	local y = 43
	local lastUi = 0

	while not _G.StopDualBeam do
		task.wait(0.08)
		moveBtn.Text = autoMove and "AUTO: ON" or "AUTO: OFF"
		moveBtn.BackgroundColor3 = autoMove and Color3.fromRGB(11, 136, 153) or Color3.fromRGB(45, 48, 56)

		if autoMove then
			local r = getUdpRemote()
			if r then
				local t = tick() * 2.2
				local progress = (math.sin(t) + 1) / 2
				local targetX = 64 + progress * (192 - 64)
				-- Address 17 gerak berlawanan arah pan biar kelihatan kompak
				local targetX2 = 256 - targetX
				local targetY = math.clamp(43 + math.cos(t) * 14, 0, 255)

				x = x + (targetX - x) * 0.35
				y = y + (targetY - y) * 0.35

				local sx1 = math.floor(x)
				local sx2 = math.clamp(math.floor(256 - sx1), 64, 192)
				local sy = math.floor(y)

				-- Kirim ke Addr 1 (CH 1 & 2)
				sendCh(r, 1, sx1)
				sendCh(r, 2, sy)

				-- Kirim ke Addr 17 (CH 17 & 18)
				sendCh(r, 17, sx2)
				sendCh(r, 18, sy)

				if tick() - lastUi >= 0.6 then
					lastUi = tick()
					lbl.Text = string.format("A1 P:%d | A17 P:%d | T:%d", sx1, sx2, sy)
				end
			end
		end
	end
end)
