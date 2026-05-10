--[[ Themed UI helpers for New_Mya hub and game modules. ]]

local TweenService = game:GetService("TweenService")

local function corner(inst: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
	return c
end

local function stroke(inst: Instance, theme: { border: Color3 }, thickness: number?)
	local s = Instance.new("UIStroke")
	s.Color = theme.border
	s.Thickness = thickness or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

local function padding(inst: Instance, p: number)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, p)
	pad.PaddingRight = UDim.new(0, p)
	pad.PaddingTop = UDim.new(0, p)
	pad.PaddingBottom = UDim.new(0, p)
	pad.Parent = inst
	return pad
end

return function(theme: { [string]: any })
	local UI = {}

	function UI.corner(inst: Instance)
		return corner(inst, theme.corner)
	end

	function UI.stroke(inst: Instance)
		return stroke(inst, theme)
	end

	function UI.padding(inst: Instance, p: number?)
		return padding(inst, p or theme.padding)
	end

	function UI.label(parent: Instance, text: string, size: number?, muted: boolean?)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.GothamMedium
		t.TextSize = size or 15
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextYAlignment = Enum.TextYAlignment.Top
		t.TextWrapped = true
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.Size = UDim2.new(1, 0, 0, 0)
		t.RichText = false
		t.TextColor3 = if muted then theme.textMuted else theme.text
		t.Text = text
		t.Parent = parent
		return t
	end

	function UI.button(parent: Instance, text: string, callback: () -> ())
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BorderSizePixel = 0
		b.Size = UDim2.new(1, 0, 0, 36)
		b.BackgroundColor3 = theme.surface
		b.Text = text
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 14
		b.TextColor3 = theme.text
		b.Parent = parent
		UI.corner(b)
		b.MouseEnter:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = theme.bgElevated }):Play()
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = theme.surface }):Play()
		end)
		b.MouseButton1Click:Connect(callback)
		return b
	end

	function UI.primaryButton(parent: Instance, text: string, callback: () -> ())
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.BorderSizePixel = 0
		b.Size = UDim2.new(1, 0, 0, 36)
		b.BackgroundColor3 = theme.accent
		b.Text = text
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 14
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.Parent = parent
		UI.corner(b)
		b.MouseEnter:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.12), {
				BackgroundColor3 = theme.accent:Lerp(Color3.new(1, 1, 1), 0.08),
			}):Play()
		end)
		b.MouseLeave:Connect(function()
			TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = theme.accent }):Play()
		end)
		b.MouseButton1Click:Connect(callback)
		return b
	end

	function UI.card(parent: Instance)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = theme.bgElevated
		f.Size = UDim2.new(1, 0, 0, 0)
		f.AutomaticSize = Enum.AutomaticSize.Y
		f.Parent = parent
		UI.corner(f)
		UI.stroke(f)
		UI.padding(f, theme.padding)
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		layout.Parent = f
		return f
	end

	function UI.panel(parent: Instance)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = theme.bgElevated
		f.Size = UDim2.new(1, 0, 0, 0)
		f.AutomaticSize = Enum.AutomaticSize.Y
		f.Parent = parent
		UI.corner(f)
		UI.padding(f, theme.padding)
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 8)
		layout.Parent = f
		return f
	end

	function UI.scroll(parent: Instance)
		local s = Instance.new("ScrollingFrame")
		s.BackgroundTransparency = 1
		s.BorderSizePixel = 0
		s.Size = UDim2.new(1, 0, 1, 0)
		s.ScrollBarThickness = 6
		s.ScrollBarImageColor3 = theme.accent
		s.CanvasSize = UDim2.new(0, 0, 0, 0)
		s.AutomaticCanvasSize = Enum.AutomaticSize.Y
		s.Parent = parent
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 10)
		layout.Parent = s
		return s
	end

	function UI.tweenFade(inst: Instance, target: number, duration: number?)
		TweenService:Create(inst, TweenInfo.new(duration or 0.18), { BackgroundTransparency = target }):Play()
	end

	return UI
end
