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
local Alpha = { Window = 0.3, Sidebar = 0.965, Card = 0.968, Control = 0.935, Hover = 0.93, Stroke = 0.915, Popover = 0.04 }
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
	rowLabel(row, cfg.Text or idx)
	local right = rightBox(row)
	o._right = right
	local sw, paint = makeSwitch(right, function() return o.Value end)
	sw.LayoutOrder = 100
	paint(false)
	local hit = button(row, { Size = UDim2.new(1, -110, 1, 0) })
	local hit2 = button(sw, { Size = UDim2.fromScale(1, 1) })
	local function flip() o:SetValue(not o.Value) end
	conn(hit.MouseButton1Click, flip)
	conn(hit2.MouseButton1Click, flip)
	tooltip(hit, cfg.Tooltip)
	function o:SetValue(v, silent)
		v = v == true
		if v == self.Value then return end
		self.Value = v
		paint(true)
		if Library._arrayRefresh then Library._arrayRefresh() end
		if not silent then self:_fire() end
	end
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
	local row = addRow(self)
	local o = newObj("Slider", idx, cfg)
	o.Min, o.Max, o.Rounding, o.Suffix = cfg.Min or 0, cfg.Max or 100, cfg.Rounding or 0, cfg.Suffix or ""
	o.Value = math.clamp(cfg.Default or o.Min, o.Min, o.Max)
	rowLabel(row, cfg.Text or idx, true)
	local right = rightBox(row)
	local track = new("Frame", { Size = UDim2.fromOffset(cfg.TrackWidth or 100, 4), BorderSizePixel = 0 }, right)
	reg(track, "BackgroundColor3", "Control")
	corner(track, 2)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, track)
	reg(fill, "BackgroundColor3", "Accent")
	corner(fill, 2)
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3 }, track)
	corner(knob, 6)
	local box = new("TextBox", { Size = UDim2.fromOffset(46, 24), TextSize = 12, FontFace = FONT_M, ClearTextOnFocus = false, Text = "" }, right)
	reg(box, "BackgroundColor3", "Control")
	reg(box, "TextColor3", "Text")
	corner(box, 5)
	stroke(box)
	local function fmt(v)
		if o.Rounding <= 0 then return tostring(math.floor(v + 0.5)) end
		return string.format("%." .. o.Rounding .. "f", v)
	end
	local function draw(anim)
		local a = (o.Value - o.Min) / math.max(o.Max - o.Min, 1e-9)
		if anim then tween(fill, { Size = UDim2.fromScale(a, 1) }, 0.08) tween(knob, { Position = UDim2.fromScale(a, 0.5) }, 0.08)
		else fill.Size, knob.Position = UDim2.fromScale(a, 1), UDim2.fromScale(a, 0.5) end
		box.Text = fmt(o.Value) .. o.Suffix
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
	local hit = button(track, { Size = UDim2.new(1, 12, 0, 20), Position = UDim2.fromOffset(-6, -8), ZIndex = 4 })
	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		o:SetValue(o.Min + (o.Max - o.Min) * a)
	end
	conn(hit.InputBegan, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true fromX(i.Position.X) end end)
	conn(UserInputService.InputChanged, function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end end)
	conn(UserInputService.InputEnded, function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
	conn(box.FocusLost, function() o:SetValue(string.gsub(box.Text, "[^%d%.%-]", "")) draw(false) end)
	draw(false)
	tooltip(row, cfg.Tooltip)
	o.Frame = row
	Library.Options[idx] = o
	return o
end

function Section:AddDropdown(idx, cfg)
	cfg = cfg or {}
	local row = addRow(self)
	local o = newObj("Dropdown", idx, cfg)
	o.Values, o.Multi = cfg.Values or {}, cfg.Multi == true
	rowLabel(row, cfg.Text or idx, true)
	local right = rightBox(row)
	local sel = button(right, { Size = UDim2.fromOffset(cfg.Width or 132, 26) })
	reg(sel, "BackgroundColor3", "Control")
	corner(sel, 5)
	stroke(sel)
	local lab = text(sel, "", 13, "Text", FONT, { Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -28, 1, 0) })
	local ch = chevron(sel, "down", 9)
	ch.AnchorPoint = Vector2.new(1, 0.5)
	ch.Position = UDim2.new(1, -8, 0.5, 0)
	local pop = makePopover(math.max(cfg.Width or 132, 160))
	local scroll = new("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.None, BackgroundTransparency = 1, ScrollBarThickness = 2, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 }, pop)
	reg(scroll, "ScrollBarImageColor3", "Accent")
	list(scroll, 2)
	local search
	local function isSel(v) if o.Multi then return o.Value[v] == true end return o.Value == v end
	local function display()
		if o.Multi then
			local t = {}
			for _, v in ipairs(o.Values) do if o.Value[v] then t[#t + 1] = tostring(v) end end
			lab.Text = #t > 0 and table.concat(t, ", ") or (cfg.Placeholder or "None")
		else lab.Text = o.Value ~= nil and tostring(o.Value) or (cfg.Placeholder or "None") end
	end
	local function build()
		for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		local q = search and string.lower(search.Text) or ""
		local n = 0
		for i, v in ipairs(o.Values) do
			if q == "" or string.find(string.lower(tostring(v)), q, 1, true) then
				n = n + 1
				local b = button(scroll, { Size = UDim2.new(1, 0, 0, 28), LayoutOrder = i, BackgroundTransparency = isSel(v) and 0.9 or 1 })
				reg(b, "BackgroundColor3", "Hover")
				corner(b, 6)
				local t = text(b, tostring(v), 13, isSel(v) and "Accent" or "Text", FONT, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0) })
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
				local _ = t
			end
		end
		scroll.Size = UDim2.new(1, 0, 0, math.min(n * 30, 240))
	end
	if #o.Values > 8 or cfg.Search then
		search = new("TextBox", { Size = UDim2.new(1, 0, 0, 28), PlaceholderText = "Search", Text = "", TextSize = 13, FontFace = FONT, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = -1 }, pop)
		reg(search, "BackgroundColor3", "Control")
		reg(search, "TextColor3", "Text")
		reg(search, "PlaceholderColor3", "Muted")
		corner(search, 6)
		pad(search, 0, 8)
		conn(search:GetPropertyChangedSignal("Text"), build)
		scroll.LayoutOrder = 1
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
	local row = addRow(self, cfg.Height or 260, true)
	local vp = new("ViewportFrame", { Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, LightColor = Color3.new(1, 1, 1), Ambient = Color3.fromRGB(170, 170, 180) }, row)
	local cam = new("Camera", { FieldOfView = 40 }, vp)
	vp.CurrentCamera = cam
	task.spawn(function()
		local ch = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
		local was = ch.Archivable
		ch.Archivable = true
		local ok, clone = pcall(function() return ch:Clone() end)
		ch.Archivable = was
		if not (ok and clone) then return end
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") then d:Destroy() end
		end
		local root = clone:FindFirstChild("HumanoidRootPart")
		if root then root.Anchored = true end
		clone:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(180), 0))
		clone.Parent = vp
		cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.3, -9.5), Vector3.new(0, 0, 0))
	end)
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.46, 0.8), BackgroundTransparency = 1 }, vp.Parent)
	local bs = new("UIStroke", { Thickness = 1, Color = Color3.new(1, 1, 1) }, box)
	local name = text(vp.Parent, LocalPlayer.DisplayName, 12, "Text", FONT_SB, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.12, -2), Size = UDim2.fromOffset(160, 16), TextXAlignment = Enum.TextXAlignment.Center })
	local hb = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.27, -4, 0.52, 0), Size = UDim2.new(0, 3, 0.8, 0), BackgroundColor3 = Color3.fromRGB(70, 220, 110), BorderSizePixel = 0 }, vp.Parent)
	local dist = text(vp.Parent, "12 st", 11, "SubText", FONT, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.92, 2), Size = UDim2.fromOffset(120, 14), TextXAlignment = Enum.TextXAlignment.Center })
	local parts = { Box = box, Name = name, Health = hb, Distance = dist }
	local o = { Type = "ESPPreview", Frame = row }
	function o.Set(_, what, on, color)
		local p = parts[what]
		if not p then return end
		p.Visible = on ~= false
		if color then
			if what == "Box" then bs.Color = color elseif p:IsA("TextLabel") then p.TextColor3 = color else p.BackgroundColor3 = color end
		end
	end
	return o
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
	local opts = type(a) == "table" and a or { Title = "dexori", Description = tostring(a), Time = b }
	if not self._notifyHolder then
		local h = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -16), Size = UDim2.fromOffset(300, 400), BackgroundTransparency = 1, ZIndex = 180 }, Gui)
		local l = list(h, 8)
		l.VerticalAlignment = Enum.VerticalAlignment.Bottom
		self._notifyHolder = h
	end
	local card = new("CanvasGroup", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, GroupTransparency = 1, ZIndex = 181 }, self._notifyHolder)
	reg(card, "BackgroundColor3", "Popover")
	corner(card, 10)
	stroke(card)
	pad(card, 10, 12, 10, 16)
	local bar = new("Frame", { Size = UDim2.new(0, 3, 1, -16), Position = UDim2.new(0, -10, 0, 8), BorderSizePixel = 0 }, card)
	reg(bar, "BackgroundColor3", "Accent")
	corner(bar, 2)
	local inner = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 }, card)
	list(inner, 2)
	text(inner, opts.Title or "dexori", 13, "Text", FONT_SB, { Size = UDim2.new(1, 0, 0, 16) })
	if opts.Description and opts.Description ~= "" then
		text(inner, opts.Description, 12, "SubText", FONT, { Size = UDim2.new(1, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2 })
	end
	tween(card, { GroupTransparency = 0 }, 0.2)
	task.delay(opts.Time or 4, function()
		if not card.Parent then return end
		tween(card, { GroupTransparency = 1 }, 0.25)
		task.wait(0.26)
		card:Destroy()
	end)
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

local function buildStats()
	local pill = new("Frame", { Position = UDim2.fromOffset(100, 60), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 150 }, Gui)
	reg(pill, "BackgroundColor3", "Window")
	pill.BackgroundTransparency = 0.12
	corner(pill, 15)
	stroke(pill)
	pad(pill, 0, 12, 0, 10)
	local l = list(pill, 14, Enum.FillDirection.Horizontal)
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	local logo = new("Frame", { Size = UDim2.fromOffset(14, 14), BorderSizePixel = 0, LayoutOrder = 0, ZIndex = 151 }, pill)
	reg(logo, "BackgroundColor3", "Accent")
	corner(logo, 4)
	local function seg(order, w)
		local s = new("Frame", { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, LayoutOrder = order }, pill)
		local ll = list(s, 5, Enum.FillDirection.Horizontal)
		ll.VerticalAlignment = Enum.VerticalAlignment.Center
		local dot = new("Frame", { Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0 }, s)
		reg(dot, "BackgroundColor3", "Accent")
		corner(dot, 3)
		local v = text(s, "", 12, "Text", FONT_B, { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, ZIndex = 151 })
		local u = text(s, "", 12, "SubText", FONT_M, { Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, ZIndex = 151 })
		local _ = w
		return v, u
	end
	local fpsV, fpsU = seg(1) fpsU.Text = "FPS"
	local msV, msU = seg(2) msU.Text = "MS"
	local tV = seg(3)
	local locV = seg(4)
	local userV = seg(5)
	userV.Text = LocalPlayer.DisplayName
	local av = new("ImageLabel", { Size = UDim2.fromOffset(20, 20), LayoutOrder = 6, BackgroundTransparency = 1, Image = avatarImage(), ZIndex = 151 }, pill)
	corner(av, 10)
	Library._statsAvatar = av
	local frames, acc = 0, 0
	conn(RunService.RenderStepped, function(dt)
		frames, acc = frames + 1, acc + dt
		if acc >= 0.5 then
			fpsV.Text = tostring(math.floor(frames / acc + 0.5))
			frames, acc = 0, 0
			local ping = 0
			pcall(function() ping = LocalPlayer:GetNetworkPing() * 1000 end)
			msV.Text = tostring(math.floor(ping + 0.5))
			local s = math.floor(os.clock() - Library._t0)
			tV.Text = string.format("%02d:%02d:%02d", s // 3600, (s % 3600) // 60, s % 60)
		end
	end)
	task.spawn(function()
		local ok, cc = pcall(function() return game:GetService("LocalizationService"):GetCountryRegionForPlayerAsync(LocalPlayer) end)
		locV.Text = ok and cc or "--"
	end)
	makeDraggable(pill, pill)
	return pill
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
	local W, H = 860, 640
	if typeof(cfg.Size) == "UDim2" then W, H = cfg.Size.X.Offset, cfg.Size.Y.Offset end
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
	local logoRow = new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1 }, side)
	local logoTxt = text(logoRow, cfg.Title or "Dexori", 16, "Text", FONT_B, { Position = UDim2.fromOffset(26, 0), Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X })
	local badge = new("TextLabel", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Text = cfg.Badge or "PRO", TextSize = 12, FontFace = FONT_SB, BackgroundTransparency = 0.8 }, logoRow)
	reg(badge, "BackgroundColor3", "Accent")
	reg(badge, "TextColor3", "Accent")
	corner(badge, 5)
	pad(badge, 0, 6)
	local function placeBadge() badge.Position = UDim2.new(0, 26 + logoTxt.TextBounds.X + 8, 0.5, 0) end
	conn(logoTxt:GetPropertyChangedSignal("TextBounds"), placeBadge)
	placeBadge()
	local nav = new("ScrollingFrame", { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66 - 76), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, side)
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
	makeDraggable(logoRow, root)

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
		Library:Toggle(false)
		Library:Notify({ Title = cfg.Title or "Dexori", Description = "menu hidden. Press " .. (Settings.MenuKey or "Insert") .. " to open it.", Time = 3 })
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
	local cfgPop = makePopover(240)
	local cfgList = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 1 }, cfgPop)
	list(cfgList, 2)
	local cfgSec = setmetatable({ Body = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2 }, cfgPop), _rows = 0, _flat = true }, Section)
	list(cfgSec.Body, 0)
	local cfgName = cfgSec:AddInput("_UIConfigName", { Placeholder = "config name", Finished = true })
	local function refreshCfgList()
		for _, c in ipairs(cfgList:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		for i, n in ipairs(Library:ListConfigs()) do
			local b = button(cfgList, { Size = UDim2.new(1, 0, 0, 28), LayoutOrder = i, BackgroundTransparency = 1 })
			reg(b, "BackgroundColor3", "Hover")
			corner(b, 6)
			text(b, n, 13, n == Library._currentConfig and "Accent" or "Text", FONT, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0) })
			conn(b.MouseEnter, function() tween(b, { BackgroundTransparency = 0.94 }, 0.1) end)
			conn(b.MouseLeave, function() tween(b, { BackgroundTransparency = 1 }, 0.1) end)
			conn(b.MouseButton1Click, function()
				Library:LoadConfig(n)
				cfgLab.Text = n
				cfgName:SetValue(n, true)
				closePopover()
			end)
		end
	end
	cfgSec:AddButton({ Text = "Save", Func = function()
		local n = cfgName.Value ~= "" and cfgName.Value or Library._currentConfig
		if not n or n == "" then Library:Notify({ Title = "configs", Description = "type a name first", Time = 2 }) return end
		Library:SaveConfig(n)
		cfgLab.Text = n
		refreshCfgList()
	end })
	cfgSec:AddButton({ Text = "Set as autoload", Func = function()
		if Library._currentConfig then Library:SetAutoload(Library._currentConfig) end
	end })
	cfgSec:AddButton({ Text = "Delete", DoubleClick = true, Func = function()
		local n = cfgName.Value ~= "" and cfgName.Value or Library._currentConfig
		if n then Library:DeleteConfig(n) end
		cfgLab.Text = "No config"
		refreshCfgList()
	end })
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

	Library._stats = buildStats()
	Library.Watermark = Library._stats
	Library.KeybindFrame = new("Frame", { Visible = false, Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }, Gui)
	Library._array = buildArray()
	Library._window = win
	if cfg.AutoShow == false then win:SetVisible(false) else win:SetVisible(true) end
	Library:ApplyTheme()
	return win
end

function Library:SetWatermarkVisibility(on) if self._stats then self._stats.Visible = on and true or false end end
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
