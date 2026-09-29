local cloneref = cloneref or function(x) return x end
local Players = cloneref(game:GetService("Players"))
local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local RunService = cloneref(game:GetService("RunService"))
local HttpService = cloneref(game:GetService("HttpService"))
local Lighting = cloneref(game:GetService("Lighting"))
local LocalPlayer = Players.LocalPlayer

local Library = {
	Toggles = {}, Options = {}, Keybinds = {}, Unloaded = false, Folder = "DexoriUI",
	_signals = {}, _unload = {}, _refresh = {}, _popover = nil, _t0 = os.clock(),
}
pcall(function()
	getgenv().Toggles = Library.Toggles
	getgenv().Options = Library.Options
end)

local Settings = { Accent = { 214, 40, 48 }, MenuKey = "Insert" }
Library.Settings = Settings

local Palette = {
	Window = Color3.fromRGB(9, 9, 12), Sidebar = Color3.fromRGB(255, 255, 255), Card = Color3.fromRGB(255, 255, 255),
	Control = Color3.fromRGB(255, 255, 255), Hover = Color3.fromRGB(255, 255, 255), Stroke = Color3.fromRGB(255, 255, 255),
	Popover = Color3.fromRGB(17, 17, 21), Switch = Color3.fromRGB(62, 62, 70), Knob = Color3.fromRGB(165, 165, 175),
	Text = Color3.fromRGB(238, 238, 242), SubText = Color3.fromRGB(158, 158, 168), Muted = Color3.fromRGB(104, 104, 116),
}
local Alpha = { Window = 0.3, Sidebar = 0.965, Card = 0.968, Control = 0.935, Hover = 0.93, Stroke = 0.915, Popover = 0.16 }
local function F(weight) return Font.new("rbxasset://fonts/families/BuilderSans.json", weight or Enum.FontWeight.Regular) end
local FONT, FONT_M, FONT_SB, FONT_B = F(), F(Enum.FontWeight.Medium), F(Enum.FontWeight.SemiBold), F(Enum.FontWeight.Bold)

local function accent() return Color3.fromRGB(Settings.Accent[1], Settings.Accent[2], Settings.Accent[3]) end
local function col(key)
	if key == "Accent" then return accent() end
	return Palette[key]
end

local Registry = {}
local function reg(o, prop, key)
	Registry[#Registry + 1] = { o, prop, key }
	o[prop] = col(key)
	if prop == "BackgroundColor3" and Alpha[key] and o.BackgroundTransparency == 0 then o.BackgroundTransparency = Alpha[key] end
	return o
end

local function new(class, props, parent)
	local o = Instance.new(class)
	if props then for k, v in pairs(props) do o[k] = v end end
	if parent then o.Parent = parent end
	return o
end
local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r or 6) }, o) end
local function stroke(o, key, tr)
	local s = new("UIStroke", { Thickness = 1, Transparency = tr or Alpha.Stroke, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
	reg(s, "Color", key or "Stroke")
	return s
end
local function pad(o, t, r, b, l)
	return new("UIPadding", { PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r or t), PaddingBottom = UDim.new(0, b or t), PaddingLeft = UDim.new(0, l or r or t) }, o)
end
local function list(o, gap, dir)
	return new("UIListLayout", { Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = dir or Enum.FillDirection.Vertical }, o)
end
local function tween(o, props, t, style)
	local tw = TweenService:Create(o, TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function text(parent, str, size, key, font, extra)
	local t = new("TextLabel", {
		BackgroundTransparency = 1, Text = str or "", TextSize = size or 13, FontFace = font or FONT,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
	reg(t, "TextColor3", key or "Text")
	if extra then for k, v in pairs(extra) do t[k] = v end end
	return t
end
local function button(parent, extra)
	local b = new("TextButton", { BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, parent)
	if extra then for k, v in pairs(extra) do b[k] = v end end
	return b
end
local function chevron(parent, dir, size, key)
	local c = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size or 10, size or 10) }, parent)
	local a = (dir == "down" and 45) or (dir == "up" and -135) or (dir == "left" and 135) or -45
	local l1 = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(0.62, 0, 0, 1.6), BorderSizePixel = 0 }, c)
	local l2 = l1:Clone()
	l2.Parent = c
	reg(l1, "BackgroundColor3", key or "SubText")
	reg(l2, "BackgroundColor3", key or "SubText")
	local r = math.rad(a)
	local d = 0.18
	l1.Position = UDim2.new(0.5 - math.cos(r) * d, 0, 0.5 - math.sin(r) * d, 0)
	l1.Rotation = a
	l2.Position = UDim2.new(0.5 + math.sin(r) * d, 0, 0.5 - math.cos(r) * d, 0)
	l2.Rotation = a + 90
	return c
end
local function conn(sig, fn)
	local c = sig:Connect(fn)
	Library._signals[#Library._signals + 1] = c
	return c
end
local function fileOk() return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function" end
local function ensureFolder(p)
	pcall(function() if isfolder and not isfolder(p) then makefolder(p) end end)
end

local function loadSettings()
	if not fileOk() then return end
	pcall(function()
		local p = Library.Folder .. "/ui.json"
		if isfile(p) then
			local d = HttpService:JSONDecode(readfile(p))
			for k, v in pairs(d) do if Settings[k] ~= nil then Settings[k] = v end end
		end
	end)
end
local function saveSettings()
	if not fileOk() then return end
	pcall(function()
		ensureFolder(Library.Folder)
		writefile(Library.Folder .. "/ui.json", HttpService:JSONEncode(Settings))
	end)
end

function Library:ApplyTheme()
	local keep = {}
	for _, e in ipairs(Registry) do
		if e[1].Parent ~= nil or e[1]:IsA("UIStroke") then
			local ok = pcall(function() e[1][e[2]] = col(e[3]) end)
			if ok then keep[#keep + 1] = e end
		end
	end
	Registry = keep
	for _, fn in ipairs(self._refresh) do pcall(fn) end
end
function Library:SetAccent(c)
	Settings.Accent = { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
	self:ApplyTheme()
	saveSettings()
end
function Library:OnUnload(fn) table.insert(self._unload, fn) end

local Gui = new("ScreenGui", { Name = "DexoriGlass", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50 })
pcall(function() Gui.Parent = (gethui and gethui()) or cloneref(game:GetService("CoreGui")) end)
if not Gui.Parent then Gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
Library.ScreenGui = Gui

local Overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 200 }, Gui)
local Catcher = button(Overlay, { Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 200 })

local GlassDOF = nil
local function glassBehind(frame, inset, isOn)
	if not GlassDOF then
		GlassDOF = new("DepthOfFieldEffect", { Name = "DexoriGlass", FarIntensity = 0, FocusDistance = 51.6, InFocusRadius = 50, NearIntensity = 1, Enabled = false }, Lighting)
	end
	local part = new("Part", { Name = "DexoriGlass", Color = Color3.new(0, 0, 0), Material = Enum.Material.Glass, Size = Vector3.new(1, 1, 0), Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1 })
	local mesh = new("SpecialMesh", { MeshType = Enum.MeshType.Brick, Offset = Vector3.new(0, 0, -0.000001) }, part)
	conn(RunService.RenderStepped, function()
		local cam = workspace.CurrentCamera
		local show = cam and frame.Parent and frame.Visible and (isOn == nil or isOn()) and not Library.Unloaded
		if not show then part.Transparency = 1 return end
		if part.Parent ~= cam then part.Parent = cam end
		local pos, size = frame.AbsolutePosition, frame.AbsoluteSize
		local i = inset or 0
		local function at(x, y) local r = cam:ViewportPointToRay(x, y) return r.Origin + r.Direction * 0.001 end
		local tl = at(pos.X + i, pos.Y + i)
		local tr = at(pos.X + size.X - i, pos.Y + i)
		local br = at(pos.X + size.X - i, pos.Y + size.Y - i)
		part.CFrame = CFrame.fromMatrix((tl + br) / 2, cam.CFrame.XVector, cam.CFrame.YVector, cam.CFrame.ZVector)
		mesh.Scale = Vector3.new((tr - tl).Magnitude, (br - tr).Magnitude, 0)
		part.Transparency = 0.98
	end)
	Library:OnUnload(function() part:Destroy() end)
	return part
end
local function closePopover()
	local p = Library._popover
	Library._popover = nil
	Catcher.Visible = false
	if p and p.Parent then
		tween(p, { GroupTransparency = 1 }, 0.12)
		task.delay(0.12, function() if p.Parent then p.Visible = false end end)
	end
end
conn(Catcher.MouseButton1Click, closePopover)
local function openPopover(pop, anchor, side)
	if Library._popover == pop then closePopover() return end
	closePopover()
	Library._popover = pop
	Catcher.Visible = true
	pop.Visible = true
	pop.GroupTransparency = 1
	task.defer(function()
		local ap, as = anchor.AbsolutePosition, anchor.AbsoluteSize
		local vs = Gui.AbsoluteSize
		local ps = pop.AbsoluteSize
		local x, y
		if side == "below" then x, y = ap.X + as.X - ps.X, ap.Y + as.Y + 6
		elseif side == "above" then x, y = ap.X, ap.Y - ps.Y - 6
		else x, y = ap.X + as.X + 8, ap.Y end
		x = math.clamp(x, 6, vs.X - ps.X - 6)
		y = math.clamp(y, 6, vs.Y - ps.Y - 6)
		pop.Position = UDim2.fromOffset(x, y + 6)
		tween(pop, { GroupTransparency = 0, Position = UDim2.fromOffset(x, y) }, 0.16)
	end)
end
local function makePopover(width)
	local p = new("CanvasGroup", { Size = UDim2.fromOffset(width or 240, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 210, GroupTransparency = 1 }, Overlay)
	reg(p, "BackgroundColor3", "Popover")
	corner(p, 10)
	stroke(p)
	pad(p, 6)
	list(p, 0)
	glassBehind(p, 3, function() return p.Visible and p.GroupTransparency < 0.95 end)
	return p
end

local Section = {}
Section.__index = Section

local function addRow(sec, h, noDivider)
	sec._rows = sec._rows + 1
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, h or 40), BackgroundTransparency = 1, LayoutOrder = sec._rows }, sec.Body)
	if sec._rows > 1 and not noDivider and not sec._flat then
		local d = new("Frame", { Size = UDim2.new(1, -24, 0, 1), Position = UDim2.fromOffset(12, 0), BorderSizePixel = 0 }, row)
		reg(d, "BackgroundColor3", "Stroke")
	end
	return row
end
local function rowLabel(row, str, sub)
	local l = text(row, str, 14, "Text", FONT, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0) })
	if sub then l.Size = UDim2.new(0.5, 0, 1, 0) end
	return l
end
local function rightBox(row)
	local r = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 }, row)
	local l = list(r, 8, Enum.FillDirection.Horizontal)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.HorizontalAlignment = Enum.HorizontalAlignment.Right
	return r
end
local function tooltip(target, tip)
	if not tip then return end
	local tt
	conn(target.MouseEnter, function()
		tt = new("TextLabel", { AutomaticSize = Enum.AutomaticSize.XY, Text = tip, TextSize = 12, FontFace = FONT, ZIndex = 250, BackgroundTransparency = 0.05 }, Overlay)
		reg(tt, "BackgroundColor3", "Popover")
		reg(tt, "TextColor3", "SubText")
		corner(tt, 6)
		stroke(tt)
		pad(tt, 6, 8)
		local m = UserInputService:GetMouseLocation()
		tt.Position = UDim2.fromOffset(m.X + 14, m.Y - 6)
	end)
	conn(target.MouseLeave, function() if tt then tt:Destroy() tt = nil end end)
end
local function newObj(kind, idx, cfg)
	local o = { Type = kind, Idx = idx, Value = nil, Callback = cfg.Callback, _changed = {}, Text = cfg.Text or idx }
	function o:OnChanged(fn) table.insert(self._changed, fn) end
	function o:_fire()
		if self.Callback then task.spawn(self.Callback, self.Value) end
		for _, fn in ipairs(self._changed) do task.spawn(fn, self.Value) end
	end
	return o
end

local function makeSwitch(parent, getOn)
	local sw = new("Frame", { Size = UDim2.fromOffset(34, 20), BorderSizePixel = 0 }, parent)
	corner(sw, 10)
	local knob = new("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3), BorderSizePixel = 0 }, sw)
	corner(knob, 7)
	local function paint(anim)
		local on = getOn()
		local pos = on and UDim2.fromOffset(17, 3) or UDim2.fromOffset(3, 3)
		local bg = on and col("Accent") or col("Switch")
		local kc = on and Color3.new(1, 1, 1) or col("Knob")
		if anim then tween(knob, { Position = pos, BackgroundColor3 = kc }, 0.16) tween(sw, { BackgroundColor3 = bg }, 0.16)
		else knob.Position, knob.BackgroundColor3, sw.BackgroundColor3 = pos, kc, bg end
	end
	table.insert(Library._refresh, function() paint(false) end)
	return sw, paint
end

function Section:AddToggle(idx, cfg)
	cfg = cfg or {}
	local row = addRow(self)
	local o = newObj("Toggle", idx, cfg)
	o.Value = cfg.Default == true
	local box = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(14, 14), ZIndex = 3 }, row)
	reg(box, "BackgroundColor3", "Control")
	corner(box, 4)
	local bs = stroke(box, "Stroke", 0.82)
	local fill = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 4 }, box)
	corner(fill, 4)
	local tick = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 5 }, box)
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(3.5, 1.6), Position = UDim2.new(0.5, -2.5, 0.5, 1.2), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 6 }, tick)
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6.5, 1.6), Position = UDim2.new(0.5, 1, 0.5, -0.4), Rotation = -45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 6 }, tick)
	local tickScale = new("UIScale", { Scale = 0 }, tick)
	local lab = text(row, cfg.Text or idx, 14, "Text", FONT, { Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -46, 1, 0) })
	local right = rightBox(row)
	o._right = right
	local function render(anim)
		local on = o.Value
		local t = anim and 0.18 or 0
		fill.BackgroundColor3 = col("Accent")
		tween(fill, { BackgroundTransparency = on and 0 or 1 }, t)
		tween(tickScale, { Scale = on and 1 or 0 }, anim and 0.22 or 0, Enum.EasingStyle.Back)
		bs.Color = on and col("Accent") or col("Stroke")
		bs.Transparency = on and 0.2 or 0.82
		tween(lab, { TextColor3 = on and col("Text") or col("SubText") }, t)
	end
	table.insert(Library._refresh, function() render(false) end)
	render(false)
	local hit = button(row, { Size = UDim2.new(1, -120, 1, 0), ZIndex = 2 })
	conn(hit.MouseButton1Click, function() o:SetValue(not o.Value) end)
	conn(hit.MouseEnter, function() if not o.Value then tween(lab, { TextColor3 = col("Text") }, 0.1) end end)
	conn(hit.MouseLeave, function() if not o.Value then tween(lab, { TextColor3 = col("SubText") }, 0.1) end end)
	tooltip(hit, cfg.Tooltip)
	function o:SetValue(v, silent)
		v = v == true
		if v == self.Value then return end
		self.Value = v
		render(true)
		if Library._arrayRefresh then Library._arrayRefresh() end
		if not silent then self:_fire() end
	end
	function o:SetText(t) lab.Text = t end
	function o:AddKeyPicker(kidx, kcfg) kcfg = kcfg or {} kcfg._parent = self return Section._keypicker(right, kidx, kcfg, 10) end
	function o:AddColorPicker(cidx, ccfg) return Section._colorpicker(right, cidx, ccfg or {}, 20) end
	function o:AddSettings(width)
		local pop = makePopover(width or 260)
		local sec = setmetatable({ Body = pop, _rows = 0, _flat = false, _page = self._page }, Section)
		local dots = button(right, { Size = UDim2.fromOffset(20, 20), Text = "···", TextSize = 14, FontFace = FONT_B, LayoutOrder = 5 })
		reg(dots, "TextColor3", "SubText")
		conn(dots.MouseButton1Click, function() openPopover(pop, dots, "right") end)
		return sec
	end
	o.Frame = row
	o.Array = cfg.Array ~= false
	Library.Toggles[idx] = o
	if cfg.Settings then o.Settings = o:AddSettings() end
	return o
end

function Section:AddSlider(idx, cfg)
	cfg = cfg or {}
	local row = addRow(self, 50)
	local o = newObj("Slider", idx, cfg)
	o.Min, o.Max, o.Rounding, o.Suffix = cfg.Min or 0, cfg.Max or 100, cfg.Rounding or 0, cfg.Suffix or ""
	o.Value = math.clamp(cfg.Default or o.Min, o.Min, o.Max)
	text(row, cfg.Text or idx, 14, "Text", FONT, { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -100, 0, 18) })
	local chip = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 5), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 3 }, row)
	reg(chip, "BackgroundColor3", "Control")
	corner(chip, 6)
	stroke(chip)
	pad(chip, 0, 7)
	local chipScale = new("UIScale", { Scale = 1 }, chip)
	local box = new("TextBox", { Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, TextSize = 12, FontFace = FONT_SB, ClearTextOnFocus = false, Text = "", ZIndex = 4 }, chip)
	reg(box, "TextColor3", "Text")
	local track = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -9), Size = UDim2.new(1, -24, 0, 6), ZIndex = 3 }, row)
	reg(track, "BackgroundColor3", "Control")
	corner(track, 3)
	stroke(track)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, ZIndex = 4 }, track)
	reg(fill, "BackgroundColor3", "Accent")
	corner(fill, 3)
	local fglow = new("UIStroke", { Thickness = 2, Transparency = 0.75 }, fill)
	reg(fglow, "Color", "Accent")
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 6 }, track)
	corner(knob, 7)
	local kr = new("UIStroke", { Thickness = 2, Transparency = 0.35 }, knob)
	reg(kr, "Color", "Accent")
	local function fmt(v)
		if o.Rounding <= 0 then return tostring(math.floor(v + 0.5)) end
		return string.format("%." .. o.Rounding .. "f", v)
	end
	local function draw(anim)
		local a = (o.Value - o.Min) / math.max(o.Max - o.Min, 1e-9)
		if anim then tween(fill, { Size = UDim2.fromScale(a, 1) }, 0.08) tween(knob, { Position = UDim2.fromScale(a, 0.5) }, 0.08)
		else fill.Size, knob.Position = UDim2.fromScale(a, 1), UDim2.fromScale(a, 0.5) end
		box.Text = (cfg.Prefix or "") .. fmt(o.Value) .. o.Suffix
	end
	function o:SetValue(v, silent)
		v = tonumber(v) or self.Value
		local m = 10 ^ self.Rounding
		v = math.clamp(math.floor(v * m + 0.5) / m, self.Min, self.Max)
		if v == self.Value then draw(true) return end
		self.Value = v
		draw(true)
		if not silent then self:_fire() end
	end
	function o:SetMax(v) self.Max = v self:SetValue(self.Value, true) end
	function o:SetMin(v) self.Min = v self:SetValue(self.Value, true) end
	local dragging = false
	local hit = button(track, { Size = UDim2.new(1, 12, 0, 22), Position = UDim2.fromOffset(-6, -8), ZIndex = 7 })
	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		o:SetValue(o.Min + (o.Max - o.Min) * a)
	end
	conn(hit.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			tween(knob, { Size = UDim2.fromOffset(14, 14) }, 0.12, Enum.EasingStyle.Back)
			tween(chipScale, { Scale = 1.08 }, 0.12, Enum.EasingStyle.Back)
			fromX(i.Position.X)
		end
	end)
	conn(UserInputService.InputChanged, function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end end)
	conn(UserInputService.InputEnded, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			tween(knob, { Size = UDim2.fromOffset(10, 10) }, 0.14)
			tween(chipScale, { Scale = 1 }, 0.14)
		end
	end)
	conn(box.FocusLost, function() o:SetValue((string.gsub(box.Text, "[^%d%.%-]", ""))) draw(false) end)
	draw(false)
	tooltip(row, cfg.Tooltip)
	o.Frame = row
	Library.Options[idx] = o
	return o
end

function Section:AddDropdown(idx, cfg)
	cfg = cfg or {}
	local row = addRow(self, 44)
	local o = newObj("Dropdown", idx, cfg)
	o.Values, o.Multi = cfg.Values or {}, cfg.Multi == true
	local title = cfg.Text or idx
	local sel = button(row, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -24, 0, 30), ZIndex = 3 })
	reg(sel, "BackgroundColor3", "Control")
	corner(sel, 8)
	stroke(sel)
	text(sel, title, 13, "SubText", FONT, { Position = UDim2.fromOffset(11, 0), Size = UDim2.new(0.5, -11, 1, 0), ZIndex = 4 })
	local lab = text(sel, "", 13, "Text", FONT_SB, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -28, 0, 0), Size = UDim2.new(0.5, -30, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
	local pill = new("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -28, 0.5, 0), Size = UDim2.fromOffset(18, 16), Visible = false, TextSize = 10, FontFace = FONT_B, TextColor3 = Color3.new(1, 1, 1), ZIndex = 5 }, sel)
	reg(pill, "BackgroundColor3", "Accent")
	corner(pill, 8)
	local ch = chevron(sel, "down", 9)
	ch.AnchorPoint = Vector2.new(0.5, 0.5)
	ch.Position = UDim2.new(1, -14, 0.5, 0)
	conn(sel.MouseEnter, function() tween(sel, { BackgroundTransparency = 0.9 }, 0.1) end)
	conn(sel.MouseLeave, function() tween(sel, { BackgroundTransparency = Alpha.Control }, 0.1) end)
	local pop = makePopover(math.max(cfg.Width or 240, 200))
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = -3 }, pop)
	text(head, title, 13, "Text", FONT_SB, { Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -90, 1, 0) })
	text(head, o.Multi and "pick any" or "pick one", 11, "Muted", FONT, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.fromOffset(80, 24), TextXAlignment = Enum.TextXAlignment.Right })
	local scroll = new("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, LayoutOrder = 1 }, pop)
	reg(scroll, "ScrollBarImageColor3", "Accent")
	list(scroll, 2)
	local search
	local function isSel(v) if o.Multi then return o.Value[v] == true end return o.Value == v end
	local function display()
		if o.Multi then
			local t = {}
			for _, v in ipairs(o.Values) do if o.Value[v] then t[#t + 1] = tostring(v) end end
			lab.Text = #t == 1 and t[1] or (#t == 0 and (cfg.Placeholder or "none") or "")
			pill.Visible = #t > 1
			pill.Text = tostring(#t)
		else lab.Text = o.Value ~= nil and tostring(o.Value) or (cfg.Placeholder or "none") end
	end
	local function build()
		for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		local q = search and string.lower(search.Text) or ""
		local n = 0
		for i, v in ipairs(o.Values) do
			if q == "" or string.find(string.lower(tostring(v)), q, 1, true) then
				n = n + 1
				local on = isSel(v)
				local b = button(scroll, { Size = UDim2.new(1, 0, 0, 28), LayoutOrder = i, BackgroundTransparency = on and 0.9 or 1 })
				reg(b, "BackgroundColor3", "Hover")
				b.BackgroundTransparency = on and 0.9 or 1
				corner(b, 6)
				local mark = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(4, on and 14 or 0), BorderSizePixel = 0 }, b)
				reg(mark, "BackgroundColor3", "Accent")
				corner(mark, 2)
				text(b, tostring(v), 13, on and "Text" or "SubText", on and FONT_SB or FONT, { Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -28, 1, 0) })
				conn(b.MouseEnter, function() if not isSel(v) then tween(b, { BackgroundTransparency = 0.94 }, 0.1) end end)
				conn(b.MouseLeave, function() if not isSel(v) then tween(b, { BackgroundTransparency = 1 }, 0.1) end end)
				conn(b.MouseButton1Click, function()
					if o.Multi then
						o.Value[v] = not o.Value[v] or nil
						display() build() o:_fire()
					else
						o:SetValue(v)
						closePopover()
					end
				end)
			end
		end
		scroll.Size = UDim2.new(1, 0, 0, math.min(n * 30, 240))
	end
	if #o.Values > 8 or cfg.Search then
		search = new("TextBox", { Size = UDim2.new(1, 0, 0, 28), PlaceholderText = "search", Text = "", TextSize = 13, FontFace = FONT, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = -1 }, pop)
		reg(search, "BackgroundColor3", "Control")
		reg(search, "TextColor3", "Text")
		reg(search, "PlaceholderColor3", "Muted")
		corner(search, 6)
		pad(search, 0, 8)
		conn(search:GetPropertyChangedSignal("Text"), build)
	end
	if o.Multi then
		o.Value = {}
		if type(cfg.Default) == "table" then for k, v in pairs(cfg.Default) do if type(k) == "number" then o.Value[v] = true elseif v then o.Value[k] = true end end end
	else
		local d = cfg.Default
		if type(d) == "number" then d = o.Values[d] end
		o.Value = d
		if o.Value == nil and not cfg.AllowNull then o.Value = o.Values[1] end
	end
	function o:SetValue(v, silent)
		if self.Multi then
			self.Value = {}
			if type(v) == "table" then for k, x in pairs(v) do if type(k) == "number" then self.Value[x] = true elseif x then self.Value[k] = true end end end
		else
			if v == self.Value then display() return end
			self.Value = v
		end
		display()
		if pop.Visible then build() end
		if not silent then self:_fire() end
	end
	function o:SetValues(vals)
		self.Values = vals or {}
		if not self.Multi and self.Value ~= nil and not table.find(self.Values, self.Value) then self.Value = cfg.AllowNull and nil or self.Values[1] end
		display()
		if pop.Visible then build() end
	end
	function o:Display() self:SetValues(self.Values) end
	conn(sel.MouseButton1Click, function() build() openPopover(pop, sel, "below") end)
	display()
	tooltip(row, cfg.Tooltip)
	o.Frame = row
	Library.Options[idx] = o
	return o
end

function Section:AddInput(idx, cfg)
	cfg = cfg or {}
	local row = addRow(self)
	local o = newObj("Input", idx, cfg)
	o.Value = tostring(cfg.Default or "")
	local hasLabel = cfg.Text ~= nil and cfg.Text ~= ""
	if hasLabel then rowLabel(row, cfg.Text, true) end
	local box = new("TextBox", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = hasLabel and UDim2.fromOffset(cfg.Width or 150, 26) or UDim2.new(1, -24, 0, 26), Text = o.Value, PlaceholderText = cfg.Placeholder or "", TextSize = 13, FontFace = FONT, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left }, row)
	reg(box, "BackgroundColor3", "Control")
	reg(box, "TextColor3", "Text")
	reg(box, "PlaceholderColor3", "Muted")
	corner(box, 5)
	stroke(box)
	pad(box, 0, 8)
	local function commit()
		local v = box.Text
		if cfg.Numeric then v = string.gsub(v, "[^%d%.%-]", "") box.Text = v end
		if v ~= o.Value then o.Value = v o:_fire() end
	end
	if cfg.Finished then conn(box.FocusLost, commit) else conn(box:GetPropertyChangedSignal("Text"), commit) end
	function o:SetValue(v, silent) self.Value = tostring(v) box.Text = self.Value if not silent then self:_fire() end end
	o.Frame = row
	Library.Options[idx] = o
	return o
end

function Section:AddButton(a, b)
	local cfg = type(a) == "table" and a or { Text = a, Func = b }
	local row = addRow(self, 44)
	local btn = button(row, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -24, 0, 28), Text = cfg.Text or "Button", TextSize = 13, FontFace = FONT_M })
	reg(btn, "BackgroundColor3", "Control")
	reg(btn, "TextColor3", "Text")
	corner(btn, 6)
	stroke(btn)
	local armed = false
	conn(btn.MouseEnter, function() tween(btn, { BackgroundTransparency = 0.88 }, 0.1) end)
	conn(btn.MouseLeave, function() tween(btn, { BackgroundTransparency = Alpha.Control }, 0.1) end)
	conn(btn.MouseButton1Click, function()
		if cfg.DoubleClick and not armed then
			armed = true
			btn.Text = "Are you sure?"
			task.delay(2, function() if armed then armed = false btn.Text = cfg.Text end end)
			return
		end
		armed = false
		btn.Text = cfg.Text
		if cfg.Func then task.spawn(cfg.Func) end
	end)
	tooltip(btn, cfg.Tooltip)
	local o = { Type = "Button", Frame = row }
	function o.AddButton(_, x, y) return self:AddButton(x, y) end
	return o
end

function Section:AddLabel(str, wrap)
	local row = addRow(self, 34)
	local l = rowLabel(row, str)
	reg(l, "TextColor3", "SubText")
	if wrap then
		l.TextWrapped = true
		l.TextTruncate = Enum.TextTruncate.None
		row.AutomaticSize = Enum.AutomaticSize.Y
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Size = UDim2.new(1, -24, 0, 34)
		pad(row, 8, 0)
	end
	local o = { Type = "Label", Frame = row }
	function o.SetText(_, s) l.Text = s end
	function o.AddColorPicker(_, idx, cfg) return Section._colorpicker(rightBox(row), idx, cfg or {}, 1) end
	function o.AddKeyPicker(_, idx, cfg) return Section._keypicker(rightBox(row), idx, cfg or {}, 1) end
	return o
end

function Section:AddDivider()
	local row = addRow(self, 10, true)
	return { Type = "Divider", Frame = row }
end

function Section:AddColorPicker(idx, cfg)
	cfg = cfg or {}
	local row = addRow(self)
	rowLabel(row, cfg.Text or cfg.Title or idx)
	return Section._colorpicker(rightBox(row), idx, cfg, 1)
end

function Section:AddKeyPicker(idx, cfg)
	cfg = cfg or {}
	local row = addRow(self)
	rowLabel(row, cfg.Text or idx)
	return Section._keypicker(rightBox(row), idx, cfg, 1)
end

Section._colorpicker = function(parent, idx, cfg, order)
	local o = newObj("ColorPicker", idx, cfg)
	o.Value = cfg.Default or Color3.new(1, 1, 1)
	o.Transparency = cfg.Transparency or 0
	local sw = button(parent, { Size = UDim2.fromOffset(18, 18), LayoutOrder = order or 20, BackgroundTransparency = 0, BackgroundColor3 = o.Value })
	corner(sw, 4)
	stroke(sw)
	local pop = makePopover(222)
	local h, s, v = o.Value:ToHSV()
	local sv = new("Frame", { Size = UDim2.new(1, 0, 0, 150), BorderSizePixel = 0, BackgroundColor3 = Color3.fromHSV(h, 1, 1), LayoutOrder = 1 }, pop)
	corner(sv, 6)
	local white = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, sv)
	corner(white, 6)
	new("UIGradient", { Transparency = NumberSequence.new(0, 1) }, white)
	local black = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, sv)
	corner(black, 6)
	new("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90 }, black)
	local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 5 }, sv)
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, dot)
	corner(dot, 5)
	local gap = new("Frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundTransparency = 1, LayoutOrder = 2 }, pop)
	local _ = gap
	local hue = new("Frame", { Size = UDim2.new(1, 0, 0, 10), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 3 }, pop)
	corner(hue, 5)
	local kp = {}
	for i = 0, 6 do kp[#kp + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1)) end
	new("UIGradient", { Color = ColorSequence.new(kp) }, hue)
	local hk = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(4, 14), Position = UDim2.fromScale(h, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5 }, hue)
	corner(hk, 2)
	local gap2 = new("Frame", { Size = UDim2.new(1, 0, 0, 8), BackgroundTransparency = 1, LayoutOrder = 4 }, pop)
	local _2 = gap2
	local hex = new("TextBox", { Size = UDim2.new(1, 0, 0, 26), TextSize = 12, FontFace = FONT_M, ClearTextOnFocus = false, LayoutOrder = 5 }, pop)
	reg(hex, "BackgroundColor3", "Control")
	reg(hex, "TextColor3", "Text")
	corner(hex, 5)
	local function draw()
		sw.BackgroundColor3 = o.Value
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		dot.Position = UDim2.fromScale(s, 1 - v)
		hk.Position = UDim2.fromScale(h, 0.5)
		hex.Text = "#" .. o.Value:ToHex()
	end
	local function set(fire)
		o.Value = Color3.fromHSV(h, s, v)
		draw()
		if fire then o:_fire() end
	end
	function o:SetValueRGB(c, t, silent)
		self.Value = c
		if t ~= nil then self.Transparency = t end
		h, s, v = c:ToHSV()
		draw()
		if not silent then self:_fire() end
	end
	function o:SetValue(c, t, silent)
		if type(c) == "table" then c = Color3.fromHSV(c[1], c[2], c[3]) end
		self:SetValueRGB(c, t, silent)
	end
	local drag = nil
	local function upd(pos)
		if drag == "sv" then
			s = math.clamp((pos.X - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
			v = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
			set(true)
		elseif drag == "h" then
			h = math.clamp((pos.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 0.999)
			set(true)
		end
	end
	conn(sv.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = "sv" upd(i.Position) end end)
	conn(hue.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = "h" upd(i.Position) end end)
	conn(UserInputService.InputChanged, function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then upd(i.Position) end end)
	conn(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = nil end end)
	conn(hex.FocusLost, function()
		local ok, c = pcall(function() return Color3.fromHex(string.gsub(hex.Text, "#", "")) end)
		if ok and c then o:SetValueRGB(c) else draw() end
	end)
	conn(sw.MouseButton1Click, function() openPopover(pop, sw, "right") end)
	draw()
	Library.Options[idx] = o
	return o
end

local function keyName(k)
	if k == nil or k == "None" then return "None" end
	if typeof(k) == "EnumItem" then
		if k == Enum.UserInputType.MouseButton1 then return "Mb1" end
		if k == Enum.UserInputType.MouseButton2 then return "Mb2" end
		if k == Enum.UserInputType.MouseButton3 then return "Mmb" end
		return k.Name
	end
	return tostring(k)
end
local function toKey(v)
	if typeof(v) == "EnumItem" then return v end
	if type(v) ~= "string" or v == "None" or v == "" then return nil end
	local ok, k = pcall(function() return Enum.KeyCode[v] end)
	if ok and k then return k end
	if v == "MB1" or v == "Mb1" then return Enum.UserInputType.MouseButton1 end
	if v == "MB2" or v == "Mb2" then return Enum.UserInputType.MouseButton2 end
	if v == "MB3" or v == "Mmb" then return Enum.UserInputType.MouseButton3 end
	return nil
end

Section._keypicker = function(parent, idx, cfg, order)
	local o = newObj("KeyPicker", idx, cfg)
	o.Value = toKey(cfg.Default)
	o.Mode = cfg.Mode or "Toggle"
	o.Toggled = false
	o.SyncToggleState = cfg.SyncToggleState
	o.ChangedCallback = cfg.ChangedCallback
	o.Text = cfg.Text or idx
	local chip = button(parent, { Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order or 10, TextSize = 12, FontFace = FONT_M, BackgroundTransparency = 0 })
	reg(chip, "BackgroundColor3", "Control")
	reg(chip, "TextColor3", "SubText")
	corner(chip, 5)
	pad(chip, 0, 7)
	local listening = false
	local function draw() chip.Text = listening and "..." or keyName(o.Value) end
	function o:GetState()
		if self.Mode == "Always" then return true end
		if self.Mode == "Hold" then
			if self.Value == nil then return false end
			if self.Value.EnumType == Enum.UserInputType then return UserInputService:IsMouseButtonPressed(self.Value) end
			return UserInputService:IsKeyDown(self.Value)
		end
		return self.Toggled
	end
	function o:SetValue(v, silent)
		if type(v) == "table" then if v[2] then self.Mode = v[2] end v = v[1] end
		self.Value = toKey(v)
		draw()
		if not silent and self.ChangedCallback then task.spawn(self.ChangedCallback, self.Value) end
		if Library._keysRefresh then Library._keysRefresh() end
	end
	function o:OnClick(fn) table.insert(self._changed, fn) end
	conn(chip.MouseButton1Click, function() listening = true draw() end)
	conn(chip.MouseButton2Click, function()
		local modes = { "Toggle", "Hold", "Always" }
		o.Mode = modes[(table.find(modes, o.Mode) or 1) % 3 + 1]
		Library:Notify({ Title = o.Text, Description = "mode: " .. o.Mode, Time = 1.5 })
		if Library._keysRefresh then Library._keysRefresh() end
	end)
	conn(UserInputService.InputBegan, function(i, gpe)
		if listening then
			local k = nil
			if i.UserInputType == Enum.UserInputType.Keyboard then
				k = (i.KeyCode == Enum.KeyCode.Escape or i.KeyCode == Enum.KeyCode.Backspace) and "None" or i.KeyCode
			elseif i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.MouseButton2 or i.UserInputType == Enum.UserInputType.MouseButton3 then
				k = i.UserInputType
			end
			if k then
				listening = false
				task.defer(function() o:SetValue(k) end)
			end
			return
		end
		if gpe or o.Value == nil then return end
		local hit = (i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode == o.Value) or (i.UserInputType == o.Value)
		if not hit then return end
		if o.Mode == "Toggle" then
			o.Toggled = not o.Toggled
			if cfg._parent and o.SyncToggleState then cfg._parent:SetValue(o.Toggled) end
		end
		if o.Callback then task.spawn(o.Callback, o:GetState()) end
		for _, fn in ipairs(o._changed) do task.spawn(fn, o:GetState()) end
		if Library._keysRefresh then Library._keysRefresh() end
	end)
	if cfg._parent and o.SyncToggleState then
		cfg._parent:OnChanged(function(v) o.Toggled = v if Library._keysRefresh then Library._keysRefresh() end end)
	end
	draw()
	o.Frame = chip
	Library.Options[idx] = o
	table.insert(Library.Keybinds, o)
	if Library._keysRefresh then Library._keysRefresh() end
	return o
end

function Section:AddESPPreview(cfg)
	cfg = cfg or {}
	local H = cfg.Height or 250
	local row = addRow(self, H + 38, true)
	local tabBar = new("Frame", { Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 }, row)
	corner(tabBar, 7)
	stroke(tabBar)
	pad(tabBar, 2)
	list(tabBar, 2, Enum.FillDirection.Horizontal)
	local canvas = new("Frame", { Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, H), ClipsDescendants = true }, row)
	reg(canvas, "BackgroundColor3", "Control")
	corner(canvas, 10)
	stroke(canvas)
	for i = 1, 14 do new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(i / 15, 0, 0, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.95, BorderSizePixel = 0 }, canvas) end
	for i = 1, 8 do new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, i / 9, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.95, BorderSizePixel = 0 }, canvas) end
	local glowVp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.new(1, 1, 1), LightColor = Color3.new(1, 1, 1), ZIndex = 2 }, canvas)
	local glowWm = new("WorldModel", {}, glowVp)
	local glowCam = new("Camera", { FieldOfView = 34 }, glowVp)
	glowVp.CurrentCamera = glowCam
	local vp = new("ViewportFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Ambient = Color3.fromRGB(190, 190, 200), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.5, -1, -0.8), ZIndex = 3 }, canvas)
	local wm = new("WorldModel", {}, vp)
	local cam = new("Camera", { FieldOfView = 34 }, vp)
	vp.CurrentCamera = cam
	local dummy, glowParts = nil, {}
	local yaw, dist = math.rad(20), 8.5
	local glowOn, glowColour = true, accent()
	local function applyGlow() for _, g in ipairs(glowParts) do g.part.Transparency = glowOn and 0 or 1 g.part.Color = glowColour end end
	local function buildGlow(m)
		for _, g in ipairs(glowParts) do pcall(function() g.part:Destroy() end) end
		glowParts = {}
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 1 then
				local shell
				local sm = d:FindFirstChildOfClass("SpecialMesh")
				if d:IsA("MeshPart") then
					shell = d:Clone()
					for _, c in ipairs(shell:GetChildren()) do c:Destroy() end
					shell.TextureID = ""
				elseif sm then
					shell = d:Clone()
					for _, c in ipairs(shell:GetChildren()) do if not c:IsA("SpecialMesh") then c:Destroy() end end
				else
					shell = Instance.new("Part")
					shell.Shape = (d:IsA("Part") and d.Shape) or Enum.PartType.Block
				end
				shell.Name, shell.Anchored, shell.CanCollide, shell.CastShadow, shell.Material = "_glow", true, false, false, Enum.Material.Neon
				local ssm = shell:FindFirstChildOfClass("SpecialMesh")
				if ssm and ssm.MeshType == Enum.MeshType.FileMesh then
					ssm.TextureId = ""
					ssm.Scale = ssm.Scale * (1 + 0.035 / math.max(d.Size.Y, 0.5))
					shell.Size = d.Size
				else
					shell.Size = d.Size + Vector3.new(0.035, 0.035, 0.035)
				end
				shell.Parent = glowWm
				glowParts[#glowParts + 1] = { part = shell, src = d }
			end
		end
		applyGlow()
	end
	task.spawn(function()
		local ok, m = pcall(function() return Players:CreateHumanoidModelFromUserId(tonumber(cfg.UserId) or LocalPlayer.UserId) end)
		if not ok or not m then
			local ok2, m2 = pcall(function() return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15) end)
			m = ok2 and m2 or nil
		end
		if not m then return end
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("LuaSourceContainer") then d:Destroy() end end
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
		m:PivotTo(CFrame.new())
		m.Parent = wm
		dummy = m
		buildGlow(m)
		pcall(function()
			local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
			local anim = Instance.new("Animation")
			anim.AnimationId = hum.RigType == Enum.HumanoidRigType.R6 and "rbxassetid://180435571" or "rbxassetid://507766666"
			local track = animator:LoadAnimation(anim)
			track.Looped = true
			track:Play()
		end)
	end)
	local dragging, lastX = false, 0
	local sink = button(canvas, { Size = UDim2.fromScale(1, 1), ZIndex = 8 })
	conn(sink.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging, lastX = true, i.Position.X end end)
	conn(sink.InputChanged, function(i) if i.UserInputType == Enum.UserInputType.MouseWheel then dist = math.clamp(dist - i.Position.Z, 4, 16) end end)
	conn(UserInputService.InputChanged, function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then yaw = yaw + (i.Position.X - lastX) * 0.012 lastX = i.Position.X end end)
	conn(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
	local zoom = new("Frame", { Position = UDim2.new(1, -32, 1, -58), Size = UDim2.fromOffset(24, 50), BackgroundTransparency = 1, ZIndex = 12 }, canvas)
	list(zoom, 4)
	for i, spec in ipairs({ { "+", -1.5 }, { "-", 1.5 } }) do
		local zb = button(zoom, { Size = UDim2.fromOffset(22, 22), Text = spec[1], TextSize = 14, FontFace = FONT_B, LayoutOrder = i, ZIndex = 13 })
		reg(zb, "BackgroundColor3", "Popover")
		reg(zb, "TextColor3", "SubText")
		zb.BackgroundTransparency = 0.3
		corner(zb, 7)
		stroke(zb)
		conn(zb.MouseButton1Click, function() dist = math.clamp(dist + spec[2], 4, 16) end)
	end
	text(canvas, "drag to rotate   scroll to zoom", 11, "Muted", FONT, { Position = UDim2.new(0, 10, 1, -18), Size = UDim2.fromOffset(220, 12), ZIndex = 12 })
	local preview = { Frame = row, Tabs = {}, Active = nil, Canvas = canvas }
	local function project(world)
		local rel = cam.CFrame:PointToObjectSpace(world)
		if rel.Z > -0.05 then return nil end
		local sz = canvas.AbsoluteSize
		if sz.X < 1 or sz.Y < 1 then return nil end
		local th = math.tan(math.rad(cam.FieldOfView) * 0.5)
		local px = (rel.X / -rel.Z) / (th * (sz.X / sz.Y))
		local py = (rel.Y / -rel.Z) / th
		return Vector2.new((px * 0.5 + 0.5) * sz.X, (0.5 - py * 0.5) * sz.Y)
	end
	for _, name in ipairs(cfg.Tabs or { "Enemy", "Team" }) do
		local page = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 9 }, canvas)
		local card = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(160, 36), BackgroundTransparency = 1, ZIndex = 9 }, page)
		local nameL = new("TextLabel", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4, Text = LocalPlayer.Name, ZIndex = 10 }, card)
		local subL = new("TextLabel", { Size = UDim2.new(1, 0, 0, 12), BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 11, TextColor3 = Color3.fromRGB(220, 220, 225), TextStrokeTransparency = 0.4, Text = "[12m]", ZIndex = 10 }, card)
		local barBg = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(60, 3), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 1, BorderColor3 = Color3.new(0, 0, 0), ZIndex = 10 }, card)
		local bar = new("Frame", { Size = UDim2.fromScale(0.72, 1), BackgroundColor3 = Color3.fromRGB(71, 255, 0), BorderSizePixel = 0, ZIndex = 11 }, barBg)
		local tracer = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(1, 60), BackgroundColor3 = accent(), BorderSizePixel = 0, Visible = false, ZIndex = 8 }, page)
		local tab = { Name = name, Page = page, Colour = accent(), Parts = { Name = nameL, Distance = subL, HealthBg = barBg, Health = bar, Tracer = tracer, Card = card }, _show = { Name = true, Distance = true, HealthBg = true, Outline = true } }
		function tab._layout()
			if not dummy then return end
			local ok, cf, ext = pcall(function() return dummy:GetBoundingBox() end)
			if not ok then return end
			local top = project(cf.Position + Vector3.new(0, ext.Y * 0.5 + 0.4, 0))
			local bottom = project(cf.Position - Vector3.new(0, ext.Y * 0.5, 0))
			if not top then return end
			card.Position = UDim2.fromOffset(math.floor(top.X + 0.5), math.floor(top.Y + 0.5))
			local y = 36
			for _, r in ipairs({ { barBg, 3, "HealthBg" }, { subL, 12, "Distance" }, { nameL, 14, "Name" } }) do
				if tab._show[r[3]] then
					y = y - r[2]
					r[1].Position = UDim2.new(r[1] == barBg and 0.5 or 0, 0, 0, y)
					y = y - 2
				end
			end
			if bottom then
				local ox, oy = canvas.AbsoluteSize.X * 0.5, canvas.AbsoluteSize.Y
				local dx, dy = bottom.X - ox, bottom.Y - oy
				tracer.Position = UDim2.fromOffset(math.floor(ox), math.floor(oy))
				tracer.Size = UDim2.fromOffset(1, math.floor(math.sqrt(dx * dx + dy * dy) + 0.5))
				tracer.Rotation = -math.deg(math.atan2(dx, -dy))
			end
		end
		function tab.SetColour(_, c) tab.Colour = c tracer.BackgroundColor3 = c if preview.Active == tab then glowColour = c applyGlow() end end
		function tab.SetOutline(_, on) tab._show.Outline = on and true or false if preview.Active == tab then glowOn = tab._show.Outline applyGlow() end end
		function tab.SetText(_, which, t) local p = tab.Parts[which] if p and p:IsA("TextLabel") then p.Text = t end end
		function tab.SetHealth(_, frac)
			frac = math.clamp(frac or 1, 0, 1)
			bar.Size = UDim2.fromScale(frac, 1)
			bar.BackgroundColor3 = Color3.fromRGB(math.floor(255 * (1 - frac)), math.floor(255 * frac), 0)
		end
		function tab.Set(_, settings)
			for key, val in pairs(settings) do
				if typeof(val) == "boolean" then
					if key == "Box" or key == "Outline" or key == "Highlight" then tab:SetOutline(val)
					elseif tab.Parts[key] then tab.Parts[key].Visible = val tab._show[key] = val end
				elseif typeof(val) == "Color3" then
					if key == "Box" or key == "Outline" or key == "Highlight" or key == "Colour" then tab:SetColour(val)
					elseif key == "Name" then nameL.TextColor3 = val
					elseif key == "Tracer" then tracer.BackgroundColor3 = val end
				end
			end
		end
		local tb = button(tabBar, { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1 })
		corner(tb, 5)
		pad(tb, 0, 9)
		local tl = text(tb, string.lower(name), 11, "SubText", FONT_SB, { Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X })
		function tab.Select()
			for _, o in ipairs(preview.Tabs) do
				o.Page.Visible = false
				tween(o._label, { TextColor3 = col("SubText") }, 0.1)
				tween(o._btn, { BackgroundTransparency = 1 }, 0.1)
			end
			page.Visible = true
			tween(tl, { TextColor3 = col("Accent") }, 0.1)
			tween(tb, { BackgroundTransparency = 0.93 }, 0.1)
			preview.Active = tab
			glowOn, glowColour = tab._show.Outline, tab.Colour
			applyGlow()
		end
		tab._label, tab._btn = tl, tb
		conn(tb.MouseButton1Click, tab.Select)
		table.insert(preview.Tabs, tab)
	end
	conn(RunService.RenderStepped, function()
		if not row.Parent or not canvas.AbsoluteSize.X then return end
		if dummy then
			local ok, cf = pcall(function() return dummy:GetBoundingBox() end)
			local pivot = ok and cf.Position or Vector3.zero
			cam.CFrame = CFrame.new(pivot + Vector3.new(math.sin(yaw) * dist, dist * 0.1, math.cos(yaw) * dist), pivot)
			glowCam.CFrame = cam.CFrame
			for _, g in ipairs(glowParts) do if g.src.Parent then g.part.CFrame = g.src.CFrame end end
		end
		for _, t in ipairs(preview.Tabs) do if t.Page.Visible then t._layout() end end
	end)
	if preview.Tabs[1] then preview.Tabs[1].Select() end
	return preview
end

local Page = {}
Page.__index = Page
local function makePage(host, name)
	local cg = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, GroupTransparency = 1 }, host)
	local cols = {}
	for i = 1, 2 do
		local sc = new("ScrollingFrame", { Size = UDim2.new(0.5, -7, 1, 0), Position = UDim2.new((i - 1) * 0.5, (i - 1) * 7, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, cg)
		reg(sc, "ScrollBarImageColor3", "Accent")
		list(sc, 12)
		pad(sc, 0, 2, 12, 0)
		cols[i] = sc
	end
	return setmetatable({ Name = name, Frame = cg, _cols = cols, _count = 0 }, Page)
end
function Page:_section(colIdx, name)
	self._count = self._count + 1
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = self._count }, self._cols[colIdx])
	list(holder, 8)
	if name and name ~= "" then text(holder, string.upper(name), 12, "Muted", FONT_M, { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1 }) end
	local body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2 }, holder)
	reg(body, "BackgroundColor3", "Card")
	corner(body, 8)
	stroke(body)
	list(body, 0)
	return setmetatable({ Body = body, Holder = holder, _rows = 0, _page = self }, Section)
end
function Page:AddLeftGroupbox(name) return self:_section(1, name) end
function Page:AddRightGroupbox(name) return self:_section(2, name) end
Page.AddLeftSection, Page.AddRightSection = Page.AddLeftGroupbox, Page.AddRightGroupbox

function Library:Notify(a, b)
	local opts = type(a) == "table" and a or { Description = tostring(a), Time = b }
	if not self._notifyHolder then
		local h = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.new(0, 240, 1, -24), BackgroundTransparency = 1, ZIndex = 180 }, Gui)
		list(h, 6)
		self._notifyHolder = h
	end
	local W = 236
	local slot = new("Frame", { Size = UDim2.fromOffset(W, 34), BackgroundTransparency = 1, ZIndex = 180 }, self._notifyHolder)
	local card = new("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.new(1, W + 20, 0, 0), ClipsDescendants = true, ZIndex = 181 }, slot)
	reg(card, "BackgroundColor3", "Popover")
	card.BackgroundTransparency = 0.08
	corner(card, 8)
	stroke(card)
	local dot = new("Frame", { Size = UDim2.fromOffset(5, 5), Position = UDim2.new(0, 12, 0, 15), BorderSizePixel = 0, ZIndex = 182 }, card)
	reg(dot, "BackgroundColor3", "Accent")
	corner(dot, 3)
	local body = text(card, "", 12, "Text", FONT_M, { Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -38, 1, 0), RichText = true, ZIndex = 182 })
	local title, desc = opts.Title, opts.Description or ""
	if title and desc ~= "" then
		body.Text = string.format('%s  <font color="rgb(150,150,160)">%s</font>', title, desc)
	else
		body.Text = title or desc
	end
	task.defer(function()
		if body.TextBounds.X > W - 44 then
			body.TextWrapped = true
			body.TextTruncate = Enum.TextTruncate.None
			slot.Size = UDim2.fromOffset(W, 48)
			body.Position = UDim2.fromOffset(26, 6)
			body.Size = UDim2.new(1, -38, 0, 36)
			body.TextYAlignment = Enum.TextYAlignment.Top
			dot.Position = UDim2.new(0, 12, 0, 12)
		end
	end)
	tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.22)
	local function kill()
		if not slot.Parent then return end
		tween(card, { Position = UDim2.new(1, W + 20, 0, 0) }, 0.16)
		task.delay(0.17, function() slot:Destroy() end)
	end
	task.delay(opts.Time or 4, kill)
	conn(card.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then kill() end end)
	return { Frame = card, Destroy = kill }
end

local function makeDraggable(handle, target)
	local dragging, start, origin = false, nil, nil
	conn(handle.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, start, origin = true, i.Position, target.Position
		end
	end)
	conn(UserInputService.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - start
			target.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
		end
	end)
	conn(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
end

local function avatarImage()
	return "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
end

local function buildArray()
	local frame = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(240, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, ZIndex = 140 }, Gui)
	local l = list(frame, 2)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Right
	Library._arrayRefresh = function()
		if not frame.Visible then return end
		for _, c in ipairs(frame:GetChildren()) do if c:IsA("TextLabel") then c:Destroy() end end
		local names = {}
		for _, t in pairs(Library.Toggles) do if t.Value and t.Array and t.Frame and t.Frame.Parent then names[#names + 1] = t.Text end end
		table.sort(names, function(a, b) return #a > #b end)
		for i, n in ipairs(names) do
			local lab = new("TextLabel", { Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Text = n, TextSize = 14, FontFace = FONT_SB, LayoutOrder = i, BackgroundTransparency = 0.25, ZIndex = 141 }, frame)
			reg(lab, "BackgroundColor3", "Window")
			reg(lab, "TextColor3", "Text")
			pad(lab, 0, 8)
			local bar = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 8, 0, 0), Size = UDim2.new(0, 2, 1, 0), BorderSizePixel = 0 }, lab)
			reg(bar, "BackgroundColor3", "Accent")
		end
	end
	return frame
end
function Library:SetArrayList(on) if self._array then self._array.Visible = on and true or false if on then self._arrayRefresh() end end end

function Library:CreateWindow(cfg)
	cfg = cfg or {}
	loadSettings()
	if cfg.Accent and not Library._accentSet then Settings.Accent = { math.floor(cfg.Accent.R * 255), math.floor(cfg.Accent.G * 255), math.floor(cfg.Accent.B * 255) } end
	local W, H = cfg.MinWidth or 640, cfg.MinHeight or 440
	local win = { Tabs = {}, _nav = {}, _order = 0 }
	local root = new("CanvasGroup", { Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2), Size = UDim2.fromOffset(W, H), ZIndex = 10 }, Gui)
	reg(root, "BackgroundColor3", "Window")
	corner(root, 12)
	stroke(root, "Stroke", 0.88)
	local scale = new("UIScale", { Scale = 1 }, root)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.12) }) }, root)
	local sheen = new("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.86, BorderSizePixel = 0, ZIndex = 11 }, root)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, sheen)
	glassBehind(root, 4, function() return root.Visible end)

	local side = new("Frame", { Size = UDim2.new(0, 172, 1, 0), BorderSizePixel = 0 }, root)
	reg(side, "BackgroundColor3", "Sidebar")
	local sline = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 1, 1, 0), BorderSizePixel = 0 }, side)
	reg(sline, "BackgroundColor3", "Stroke")
	local nav = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 1, -12 - 76), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, side)
	list(nav, 3)
	pad(nav, 0, 10, 0, 10)

	local ucard = button(side, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -10), Size = UDim2.new(1, -16, 0, 56) })
	reg(ucard, "BackgroundColor3", "Hover")
	ucard.BackgroundTransparency = 1
	corner(ucard, 8)
	local uline = new("Frame", { Position = UDim2.new(0, 8, 1, -76), Size = UDim2.new(1, -16, 0, 1), BorderSizePixel = 0 }, side)
	reg(uline, "BackgroundColor3", "Stroke")
	local uav = new("ImageLabel", { Position = UDim2.fromOffset(8, 10), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, Image = avatarImage() }, ucard)
	corner(uav, 18)
	text(ucard, LocalPlayer.DisplayName, 13, "Text", FONT_M, { Position = UDim2.fromOffset(54, 11), Size = UDim2.new(1, -80, 0, 17) })
	text(ucard, cfg.UserSubtitle or "Lifetime", 12, "SubText", FONT, { Position = UDim2.fromOffset(54, 28), Size = UDim2.new(1, -80, 0, 15) })
	local uch = chevron(ucard, "right", 9)
	uch.AnchorPoint = Vector2.new(1, 0.5)
	uch.Position = UDim2.new(1, -10, 0.5, 0)
	conn(ucard.MouseEnter, function() tween(ucard, { BackgroundTransparency = 0.94 }, 0.12) end)
	conn(ucard.MouseLeave, function() tween(ucard, { BackgroundTransparency = 1 }, 0.12) end)

	local content = new("Frame", { Position = UDim2.fromOffset(172, 0), Size = UDim2.new(1, -172, 1, 0), BackgroundTransparency = 1 }, root)
	local top = new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1 }, content)
	local tline = new("Frame", { Position = UDim2.new(0, 14, 0, 58), Size = UDim2.new(1, -28, 0, 1), BorderSizePixel = 0 }, content)
	reg(tline, "BackgroundColor3", "Stroke")
	local host = new("Frame", { Position = UDim2.fromOffset(14, 72), Size = UDim2.new(1, -28, 1, -84), BackgroundTransparency = 1, ClipsDescendants = true }, content)
	local crumb = new("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, Visible = false }, host)
	local _c = crumb
	makeDraggable(top, root)

	local header = new("CanvasGroup", { Size = UDim2.fromOffset(W, 36), ZIndex = 10 }, Gui)
	reg(header, "BackgroundColor3", "Window")
	corner(header, 10)
	stroke(header, "Stroke", 0.88)
	glassBehind(header, 3, function() return root.Visible end)
	pad(header, 0, 14, 0, 10)
	local hl = list(header, 12, Enum.FillDirection.Horizontal)
	hl.VerticalAlignment = Enum.VerticalAlignment.Center
	new("ImageLabel", { Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Image = cfg.Logo or "rbxassetid://83607561451748", LayoutOrder = 0 }, header)
	local function stat(order, unit)
		local seg = new("Frame", { Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = order }, header)
		local sl = list(seg, 4, Enum.FillDirection.Horizontal)
		sl.VerticalAlignment = Enum.VerticalAlignment.Center
		local v = text(seg, "", 12, "Text", FONT_B, { Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1 })
		if unit then text(seg, unit, 12, "SubText", FONT_M, { Size = UDim2.fromOffset(0, 36), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2 }) end
		local sep = new("Frame", { Size = UDim2.fromOffset(1, 12), BorderSizePixel = 0, LayoutOrder = order + 0.5 }, header)
		reg(sep, "BackgroundColor3", "Stroke")
		sep.BackgroundTransparency = 0.85
		return v, sep
	end
	local fpsV = stat(1, "FPS")
	local msV = stat(2, "MS")
	local tV = stat(3)
	local locV = stat(4)
	local userV, lastSep = stat(5)
	lastSep.Visible = false
	userV.Text = LocalPlayer.DisplayName
	local hav = new("ImageLabel", { Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Image = avatarImage(), LayoutOrder = 6 }, header)
	corner(hav, 10)
	local frames, acc = 0, 0
	conn(RunService.RenderStepped, function(dt)
		header.Visible = root.Visible
		header.Position = root.Position - UDim2.fromOffset(0, 44)
		header.Size = UDim2.fromOffset(root.AbsoluteSize.X, 36)
		frames, acc = frames + 1, acc + dt
		if acc >= 0.5 then
			fpsV.Text = tostring(math.floor(frames / acc + 0.5))
			frames, acc = 0, 0
			local ping = 0
			pcall(function() ping = LocalPlayer:GetNetworkPing() * 1000 end)
			msV.Text = tostring(math.floor(ping + 0.5))
			local sec = math.floor(os.clock() - Library._t0)
			tV.Text = string.format("%02d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60)
		end
	end)
	task.spawn(function()
		local ok, cc = pcall(function() return game:GetService("LocalizationService"):GetCountryRegionForPlayerAsync(LocalPlayer) end)
		locV.Text = ok and cc or "--"
	end)
	makeDraggable(header, root)
	Library.Watermark = header

	local function confirm(title, desc, onYes)
		local shade = button(root, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, ZIndex = 60 })
		tween(shade, { BackgroundTransparency = 0.45 }, 0.15)
		local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 132), ZIndex = 61 }, shade)
		reg(box, "BackgroundColor3", "Popover")
		box.BackgroundTransparency = 0.04
		corner(box, 10)
		stroke(box)
		text(box, title, 14, "Text", FONT_SB, { Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 18), ZIndex = 62 })
		text(box, desc, 12, "SubText", FONT, { Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -32, 0, 40), TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 62 })
		local function close2() tween(shade, { BackgroundTransparency = 1 }, 0.12) task.delay(0.12, function() shade:Destroy() end) end
		for i, spec in ipairs({ { "Cancel", false }, { "Unload", true } }) do
			local b = button(box, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, i == 1 and -104 or -16, 1, -14), Size = UDim2.fromOffset(80, 28), Text = spec[1], TextSize = 13, FontFace = FONT_SB, ZIndex = 62 })
			if spec[2] then reg(b, "BackgroundColor3", "Accent") b.BackgroundTransparency = 0 b.TextColor3 = Color3.new(1, 1, 1)
			else reg(b, "BackgroundColor3", "Control") reg(b, "TextColor3", "Text") end
			corner(b, 7)
			conn(b.MouseButton1Click, function() close2() if spec[2] then task.delay(0.13, onYes) end end)
		end
	end
	local close = button(top, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 14), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, ZIndex = 20 })
	reg(close, "BackgroundColor3", "Hover")
	corner(close, 7)
	for _, r in ipairs({ 45, -45 }) do
		local ln = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 1.6), Rotation = r, BorderSizePixel = 0, ZIndex = 21 }, close)
		reg(ln, "BackgroundColor3", "SubText")
	end
	conn(close.MouseEnter, function() tween(close, { BackgroundTransparency = 0.92 }, 0.1) end)
	conn(close.MouseLeave, function() tween(close, { BackgroundTransparency = 1 }, 0.1) end)
	conn(close.MouseButton1Click, function()
		confirm("unload " .. (cfg.Title or "the menu") .. "?", "this closes the menu for this session. you'll need to re-execute to open it again.", function() Library:Unload() end)
	end)
	local grip = button(root, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, -4), Size = UDim2.fromOffset(18, 18), ZIndex = 30 })
	for k = 1, 3 do
		local dot = new("Frame", { AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(3, 3), BorderSizePixel = 0, ZIndex = 31 }, grip)
		dot.Position = UDim2.new(1, -(k - 1) * 5, 1, 0)
		reg(dot, "BackgroundColor3", "Muted")
		corner(dot, 2)
		if k > 1 then
			local d2 = dot:Clone()
			d2.Parent = grip
			d2.Position = UDim2.new(1, 0, 1, -(k - 1) * 5)
			reg(d2, "BackgroundColor3", "Muted")
		end
	end
	local resizing, rStart, rSize = false, nil, nil
	conn(grip.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			resizing, rStart, rSize = true, i.Position, root.AbsoluteSize
		end
	end)
	conn(UserInputService.InputChanged, function(i)
		if resizing and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - rStart
			local vs = Gui.AbsoluteSize
			root.Size = UDim2.fromOffset(math.clamp(rSize.X + d.X, cfg.MinWidth or 640, vs.X - 20), math.clamp(rSize.Y + d.Y, cfg.MinHeight or 440, vs.Y - 20))
		end
	end)
	conn(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then resizing = false end end)
	local cfgSel = button(top, { Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(206, 30) })
	reg(cfgSel, "BackgroundColor3", "Control")
	corner(cfgSel, 6)
	stroke(cfgSel)
	local cfgLab = text(cfgSel, "No config", 13, "Text", FONT, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -30, 1, 0) })
	local cch = chevron(cfgSel, "down", 9)
	cch.AnchorPoint = Vector2.new(1, 0.5)
	cch.Position = UDim2.new(1, -9, 0.5, 0)
	local cfgPop = makePopover(260)
	local cHead = new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = 0 }, cfgPop)
	text(cHead, "Configs", 13, "Text", FONT_SB, { Position = UDim2.fromOffset(6, 0), Size = UDim2.new(1, -90, 1, 0) })
	local cCount = text(cHead, "", 11, "Muted", FONT, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0), Size = UDim2.fromOffset(80, 26), TextXAlignment = Enum.TextXAlignment.Right })
	local cfgList = new("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 1 }, cfgPop)
	reg(cfgList, "ScrollBarImageColor3", "Accent")
	list(cfgList, 2)
	local cLine = new("Frame", { Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, LayoutOrder = 2 }, cfgPop)
	reg(cLine, "BackgroundColor3", "Stroke")
	local cGap = new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, LayoutOrder = 3 }, cfgPop)
	local _cg = cGap
	local cfgName = new("TextBox", { Size = UDim2.new(1, 0, 0, 28), PlaceholderText = "config name", Text = "", TextSize = 13, FontFace = FONT, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 4 }, cfgPop)
	reg(cfgName, "BackgroundColor3", "Control")
	reg(cfgName, "TextColor3", "Text")
	reg(cfgName, "PlaceholderColor3", "Muted")
	corner(cfgName, 6)
	stroke(cfgName)
	pad(cfgName, 0, 8)
	local cGap2 = new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, LayoutOrder = 5 }, cfgPop)
	local _cg2 = cGap2
	local cBtns = new("Frame", { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = 6 }, cfgPop)
	local bl = list(cBtns, 6, Enum.FillDirection.Horizontal)
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local refreshCfgList
	local function currentName() return cfgName.Text ~= "" and cfgName.Text or Library._currentConfig end
	local armed = nil
	for i, spec in ipairs({ { "Save", "Accent" }, { "Autoload", "Control" }, { "Delete", "Control" } }) do
		local b = button(cBtns, { Size = UDim2.new(1 / 3, -4, 1, 0), Text = spec[1], TextSize = 12, FontFace = FONT_SB, LayoutOrder = i })
		reg(b, "BackgroundColor3", spec[2])
		if spec[2] == "Accent" then b.BackgroundTransparency = 0 b.TextColor3 = Color3.new(1, 1, 1) else reg(b, "TextColor3", "Text") end
		corner(b, 6)
		stroke(b)
		conn(b.MouseButton1Click, function()
			local n = currentName()
			if not n or n == "" then Library:Notify({ Title = "configs", Description = "type a name first", Time = 2 }) return end
			if spec[1] == "Save" then
				Library:SaveConfig(n)
				cfgLab.Text = n
			elseif spec[1] == "Autoload" then
				Library:SetAutoload(n)
			else
				if armed ~= b then armed = b b.Text = "Sure?" task.delay(2, function() if armed == b then armed = nil b.Text = "Delete" end end) return end
				armed = nil
				b.Text = "Delete"
				Library:DeleteConfig(n)
				cfgLab.Text = "No config"
				cfgName.Text = ""
			end
			refreshCfgList()
		end)
	end
	refreshCfgList = function()
		for _, c in ipairs(cfgList:GetChildren()) do if c:IsA("TextButton") or c:IsA("TextLabel") then c:Destroy() end end
		local names = Library:ListConfigs()
		cCount.Text = #names .. " saved"
		for i, n in ipairs(names) do
			local on = n == Library._currentConfig
			local b = button(cfgList, { Size = UDim2.new(1, 0, 0, 28), LayoutOrder = i, BackgroundTransparency = on and 0.9 or 1 })
			reg(b, "BackgroundColor3", "Hover")
			b.BackgroundTransparency = on and 0.9 or 1
			corner(b, 6)
			local mark = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(4, on and 14 or 0), BorderSizePixel = 0 }, b)
			reg(mark, "BackgroundColor3", "Accent")
			corner(mark, 2)
			text(b, n, 13, on and "Text" or "SubText", on and FONT_SB or FONT, { Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -28, 1, 0) })
			conn(b.MouseEnter, function() if not on then tween(b, { BackgroundTransparency = 0.94 }, 0.1) end end)
			conn(b.MouseLeave, function() if not on then tween(b, { BackgroundTransparency = 1 }, 0.1) end end)
			conn(b.MouseButton1Click, function()
				Library:LoadConfig(n)
				cfgLab.Text = n
				cfgName.Text = n
				closePopover()
			end)
		end
		if #names == 0 then text(cfgList, "no configs yet", 12, "Muted", FONT, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(6, 0), TextXAlignment = Enum.TextXAlignment.Center }) end
		cfgList.Size = UDim2.new(1, 0, 0, math.min(math.max(#names, 1) * 30, 180))
	end
	conn(cfgSel.MouseButton1Click, function() refreshCfgList() openPopover(cfgPop, cfgSel, "below") end)
	Library._setConfigLabel = function(n) cfgLab.Text = n or "No config" end

	local current, currentBtn = nil, nil
	local function showPage(page)
		if current == page then return end
		local old = current
		current = page
		if old then
			tween(old.Frame, { GroupTransparency = 1 }, 0.14)
			task.delay(0.14, function() if current ~= old then old.Frame.Visible = false end end)
		end
		page.Frame.Visible = true
		page.Frame.Position = UDim2.fromOffset(0, 8)
		tween(page.Frame, { GroupTransparency = 0, Position = UDim2.fromOffset(0, 0) }, 0.22)
	end
	win._showPage = showPage

	local function navButton(name, icon, indent)
		win._order = win._order + 1
		local b = button(nav, { Size = UDim2.new(1, 0, 0, 34), LayoutOrder = win._order, BackgroundTransparency = 1 })
		reg(b, "BackgroundColor3", "Hover")
		corner(b, 7)
		local x = 12 + (indent or 0)
		local ic
		if icon then
			ic = new("ImageLabel", { Position = UDim2.fromOffset(x, 9), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1, Image = type(icon) == "number" and ("rbxassetid://" .. icon) or icon }, b)
			reg(ic, "ImageColor3", "SubText")
		else
			ic = new("Frame", { Position = UDim2.fromOffset(x + 4, 13), Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0 }, b)
			reg(ic, "BackgroundColor3", "Muted")
			corner(ic, 3)
		end
		local lab = text(b, name, 14, "SubText", FONT_M, { Position = UDim2.fromOffset(x + 26, 0), Size = UDim2.new(1, -(x + 30), 1, 0) })
		local entry = { b = b, ic = ic, lab = lab, name = name }
		local function paint()
			local on = currentBtn == entry
			b.BackgroundTransparency = on and 0.93 or 1
			lab.TextColor3 = on and col("Text") or col("SubText")
			if ic:IsA("ImageLabel") then ic.ImageColor3 = on and col("Accent") or col("SubText") else ic.BackgroundColor3 = on and col("Accent") or col("Muted") end
		end
		entry.paint = paint
		table.insert(Library._refresh, paint)
		conn(b.MouseEnter, function() if currentBtn ~= entry then tween(b, { BackgroundTransparency = 0.955 }, 0.1) end end)
		conn(b.MouseLeave, function() if currentBtn ~= entry then tween(b, { BackgroundTransparency = 1 }, 0.1) end end)
		table.insert(win._nav, entry)
		return entry
	end
	local function select(entry, page)
		local prev = currentBtn
		currentBtn = entry
		if prev then prev.paint() end
		entry.paint()
		showPage(page)
	end

	function win:AddCategory(name)
		win._order = win._order + 1
		local h = text(nav, string.upper(name), 12, "Muted", FONT_M, { Size = UDim2.new(1, 0, 0, 30), LayoutOrder = win._order, TextYAlignment = Enum.TextYAlignment.Bottom })
		pad(h, 0, 0, 6, 12)
		table.insert(win._nav, { header = h })
		return h
	end
	function win:AddTab(name, icon)
		local page = makePage(host, name)
		local entry = navButton(name, icon, 0)
		local tab = page
		tab._entry = entry
		tab._subs = {}
		conn(entry.b.MouseButton1Click, function()
			if #tab._subs > 0 then
				local open = not tab._open
				tab._open = open
				for _, s in ipairs(tab._subs) do s._entry.b.Visible = open end
				if open then select(tab._subs[1]._entry, tab._subs[1]) end
			else
				select(entry, page)
			end
		end)
		function tab:AddSubTab(sname, sicon)
			local sp = makePage(host, sname)
			local se = navButton(sname, sicon, 14)
			se.b.Visible = false
			sp._entry = se
			conn(se.b.MouseButton1Click, function() select(se, sp) end)
			table.insert(tab._subs, sp)
			return sp
		end
		table.insert(win.Tabs, tab)
		if not current then task.defer(function() if not current then select(entry, page) end end) end
		return tab
	end

	function Section:AddPage(name, cfg2)
		cfg2 = cfg2 or {}
		local row = addRow(self)
		rowLabel(row, name)
		local right = rightBox(row)
		local ch2 = chevron(right, "right", 9)
		ch2.LayoutOrder = 100
		local hit = button(row, { Size = UDim2.fromScale(1, 1) })
		local sub = makePage(host, name)
		local back = button(sub.Frame, { Size = UDim2.new(1, 0, 0, 26), ZIndex = 5 })
		local bch = chevron(back, "left", 9)
		bch.Position = UDim2.fromOffset(2, 8)
		text(back, (self._page and self._page.Name and (self._page.Name .. "  /  ") or "") .. name, 13, "SubText", FONT_M, { Position = UDim2.fromOffset(18, 0), Size = UDim2.new(1, -18, 1, 0) })
		for _, sc in ipairs(sub._cols) do sc.Position = sc.Position + UDim2.fromOffset(0, 34) sc.Size = sc.Size - UDim2.fromOffset(0, 34) end
		local from = self._page
		conn(hit.MouseButton1Click, function() showPage(sub) end)
		conn(back.MouseButton1Click, function() if from then showPage(from) end end)
		tooltip(hit, cfg2.Tooltip)
		return sub
	end

	local pop = makePopover(250)
	local ph = new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, LayoutOrder = 0 }, pop)
	local pav = new("ImageLabel", { Position = UDim2.fromOffset(6, 10), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, Image = avatarImage() }, ph)
	corner(pav, 18)
	text(ph, LocalPlayer.DisplayName, 13, "Text", FONT_M, { Position = UDim2.fromOffset(52, 11), Size = UDim2.new(1, -60, 0, 17) })
	text(ph, cfg.UserSubtitle or "Lifetime", 12, "SubText", FONT, { Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -60, 0, 15) })
	local pline = new("Frame", { Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, LayoutOrder = 1 }, pop)
	reg(pline, "BackgroundColor3", "Stroke")
	local ps = setmetatable({ Body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 }, pop), _rows = 0, _flat = true }, Section)
	list(ps.Body, 0)
	local menuKey = ps:AddKeyPicker("_UIMenuKey", { Text = "Menu Key", Default = Settings.MenuKey, Mode = "Toggle" })
	menuKey.ChangedCallback = function(k) Settings.MenuKey = k and k.Name or "None" saveSettings() end
	for i, kb in ipairs(Library.Keybinds) do if kb == menuKey then table.remove(Library.Keybinds, i) break end end
	conn(ucard.MouseButton1Click, function() openPopover(pop, ucard, "right") end)

	function win:SetVisible(on)
		root.Visible = on
		if GlassDOF then GlassDOF.Enabled = on end
		if on then scale.Scale = 0.97 tween(scale, { Scale = 1 }, 0.18) end
		if not on then closePopover() end
	end
	function Library:Toggle(on) if on == nil then on = not root.Visible end win:SetVisible(on) end
	function Library:SetVisible(on) win:SetVisible(on) end
	conn(UserInputService.InputBegan, function(i, gpe)
		if gpe or menuKey.Value == nil then return end
		if (i.UserInputType == Enum.UserInputType.Keyboard and i.KeyCode == menuKey.Value) or i.UserInputType == menuKey.Value then Library:Toggle() end
	end)
	if cfg.MenuKey and Settings.MenuKey == "Insert" then menuKey:SetValue(cfg.MenuKey, true) end

	Library.KeybindFrame = new("Frame", { Visible = false, Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, Gui)
	Library._array = buildArray()
	Library._window = win
	if cfg.AutoShow == false then win:SetVisible(false) else win:SetVisible(true) end
	Library:ApplyTheme()
	return win
end

function Library:SetWatermarkVisibility() end
function Library:SetWatermark() end

local function cfgPath(n) return Library.Folder .. "/configs/" .. n .. ".json" end
function Library:ListConfigs()
	local out = {}
	if not (fileOk() and listfiles) then return out end
	ensureFolder(self.Folder)
	ensureFolder(self.Folder .. "/configs")
	pcall(function()
		for _, f in ipairs(listfiles(self.Folder .. "/configs")) do
			local n = string.match(f, "([^/\\]+)%.json$")
			if n then out[#out + 1] = n end
		end
	end)
	table.sort(out)
	return out
end
function Library:SaveConfig(name)
	if not fileOk() then return false end
	local data = { toggles = {}, options = {} }
	for idx, t in pairs(self.Toggles) do if string.sub(idx, 1, 3) ~= "_UI" then data.toggles[idx] = t.Value end end
	for idx, o in pairs(self.Options) do
		if string.sub(idx, 1, 3) ~= "_UI" then
			if o.Type == "Slider" or o.Type == "Input" then data.options[idx] = { o.Type, o.Value }
			elseif o.Type == "Dropdown" then data.options[idx] = { o.Type, o.Value }
			elseif o.Type == "ColorPicker" then data.options[idx] = { o.Type, o.Value:ToHex(), o.Transparency }
			elseif o.Type == "KeyPicker" then data.options[idx] = { o.Type, keyName(o.Value), o.Mode } end
		end
	end
	ensureFolder(self.Folder)
	ensureFolder(self.Folder .. "/configs")
	local ok = pcall(writefile, cfgPath(name), HttpService:JSONEncode(data))
	if ok then self._currentConfig = name self:Notify({ Title = "configs", Description = "saved " .. name, Time = 2 }) end
	return ok
end
function Library:LoadConfig(name)
	if not fileOk() or not isfile(cfgPath(name)) then return false end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(cfgPath(name))) end)
	if not ok or type(data) ~= "table" then return false end
	for idx, v in pairs(data.toggles or {}) do local t = self.Toggles[idx] if t then pcall(t.SetValue, t, v) end end
	for idx, d in pairs(data.options or {}) do
		local o = self.Options[idx]
		if o and type(d) == "table" then
			pcall(function()
				if d[1] == "ColorPicker" then o:SetValueRGB(Color3.fromHex(d[2]), d[3])
				elseif d[1] == "KeyPicker" then o:SetValue({ d[2] == "Mb2" and "MB2" or d[2] == "Mb1" and "MB1" or d[2], d[3] })
				else o:SetValue(d[2]) end
			end)
		end
	end
	self._currentConfig = name
	if self._setConfigLabel then self._setConfigLabel(name) end
	return true
end
function Library:DeleteConfig(name) pcall(delfile, cfgPath(name)) if self._currentConfig == name then self._currentConfig = nil end end
function Library:SetAutoload(name) pcall(function() ensureFolder(self.Folder) writefile(self.Folder .. "/autoload.txt", name) end) self:Notify({ Title = "configs", Description = name .. " will load automatically", Time = 2 }) end
function Library:LoadAutoload()
	if not fileOk() then return end
	local ok, n = pcall(readfile, self.Folder .. "/autoload.txt")
	if ok and n and n ~= "" then self:LoadConfig(n) end
end

function Library:Unload()
	if self.Unloaded then return end
	self.Unloaded = true
	for _, fn in ipairs(self._unload) do pcall(fn) end
	for _, c in ipairs(self._signals) do pcall(function() c:Disconnect() end) end
	if GlassDOF then pcall(function() GlassDOF:Destroy() end) end
	pcall(function() Gui:Destroy() end)
end

return Library
