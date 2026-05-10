import type { HubTheme } from "../theme";

export function createBottomNav(
	parent: Instance,
	theme: HubTheme,
	versionText: string,
	onNav: (key: string) => void,
): { bar: Frame; setStatus: (t: string) => void } {
	const bar = new Instance("Frame");
	bar.Name = "BottomNav";
	bar.BackgroundColor3 = theme.surface;
	bar.BorderSizePixel = 0;
	bar.Size = new UDim2(1, 0, 0, 48);
	bar.Parent = parent;

	const topLine = new Instance("Frame");
	topLine.Size = new UDim2(1, 0, 0, 1);
	topLine.BackgroundColor3 = theme.border;
	topLine.BorderSizePixel = 0;
	topLine.Parent = bar;

	const status = new Instance("TextLabel");
	status.Name = "Status";
	status.BackgroundTransparency = 1;
	status.Position = new UDim2(0, 16, 0, 0);
	status.Size = new UDim2(1, -200, 1, 0);
	status.Font = Enum.Font.Gotham;
	status.TextSize = 12;
	status.TextColor3 = theme.textMuted;
	status.TextXAlignment = Enum.TextXAlignment.Left;
	status.Text = "Ready";
	status.Parent = bar;

	const ver = new Instance("TextLabel");
	ver.BackgroundTransparency = 1;
	ver.AnchorPoint = new Vector2(1, 0.5);
	ver.Position = new UDim2(1, -16, 0.5, 0);
	ver.Size = new UDim2(0, 120, 0, 20);
	ver.Font = Enum.Font.GothamMedium;
	ver.TextSize = 11;
	ver.TextColor3 = theme.textMuted;
	ver.TextXAlignment = Enum.TextXAlignment.Right;
	ver.Text = versionText;
	ver.Parent = bar;

	const navWrap = new Instance("Frame");
	navWrap.BackgroundTransparency = 1;
	navWrap.AnchorPoint = new Vector2(0.5, 0.5);
	navWrap.Position = new UDim2(0.5, 0, 0.5, 0);
	navWrap.Size = new UDim2(0, 120, 0, 36);
	navWrap.Parent = bar;

	const list = new Instance("UIListLayout");
	list.FillDirection = Enum.FillDirection.Horizontal;
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center;
	list.Padding = new UDim(0, 16);
	list.Parent = navWrap;

	function navBtn(label: string, accent: boolean): TextButton {
		const b = new Instance("TextButton");
		b.Size = new UDim2(0, 36, 0, 36);
		b.BackgroundColor3 = accent ? theme.accent : theme.bgElevated;
		b.TextColor3 = accent ? new Color3(1, 1, 1) : theme.text;
		b.Font = Enum.Font.GothamBold;
		b.TextSize = 14;
		b.Text = label;
		b.AutoButtonColor = false;
		b.Parent = navWrap;
		const c = new Instance("UICorner");
		c.CornerRadius = new UDim(0, 8);
		c.Parent = b;
		return b;
	}

	navBtn("M", true).MouseButton1Click.Connect(() => onNav("modules"));
	navBtn("S", false).MouseButton1Click.Connect(() => onNav("settings"));
	navBtn("P", false).MouseButton1Click.Connect(() => onNav("players"));

	function setStatus(t: string): void {
		status.Text = t;
	}

	return { bar, setStatus };
}
