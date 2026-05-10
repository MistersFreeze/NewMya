import type { HubTheme } from "../theme";

export interface ModuleRow {
	readonly id: string;
	readonly name: string;
	readonly category: string;
	readonly description: string;
}

export function createModuleCard(
	parent: Instance,
	theme: HubTheme,
	cardBg: Color3,
	m: ModuleRow,
	layoutOrder: number,
	onToggle: (id: string, on: boolean) => void,
	onSettings: (id: string) => void,
	onFavoriteToggle: (id: string, fav: boolean) => void,
	getToggle: (id: string) => boolean,
	getFavorite: (id: string) => boolean,
): Frame {
	const card = new Instance("Frame");
	card.Name = m.id;
	card.LayoutOrder = layoutOrder;
	card.BackgroundColor3 = cardBg;
	card.BorderSizePixel = 0;
	card.Parent = parent;

	const cC = new Instance("UICorner");
	cC.CornerRadius = new UDim(0, 10);
	cC.Parent = card;

	const cS = new Instance("UIStroke");
	cS.Color = theme.border;
	cS.Parent = card;

	const icon = new Instance("TextLabel");
	icon.BackgroundTransparency = 1;
	icon.Position = new UDim2(0, 12, 0, 10);
	icon.Size = new UDim2(0, 18, 0, 18);
	icon.Text = "o";
	icon.Font = Enum.Font.GothamBold;
	icon.TextColor3 = theme.accent;
	icon.TextSize = 12;
	icon.Parent = card;

	const name = new Instance("TextLabel");
	name.BackgroundTransparency = 1;
	name.Position = new UDim2(0, 34, 0, 8);
	name.Size = new UDim2(1, -90, 0, 20);
	name.Font = Enum.Font.GothamBold;
	name.TextSize = 14;
	name.TextColor3 = theme.text;
	name.TextXAlignment = Enum.TextXAlignment.Left;
	name.Text = m.name;
	name.Parent = card;

	const catLbl = new Instance("TextLabel");
	catLbl.BackgroundTransparency = 1;
	catLbl.Position = new UDim2(0, 34, 0, 26);
	catLbl.Size = new UDim2(1, -90, 0, 14);
	catLbl.Font = Enum.Font.GothamBold;
	catLbl.TextSize = 9;
	catLbl.TextColor3 = theme.textMuted;
	catLbl.TextXAlignment = Enum.TextXAlignment.Left;
	catLbl.Text = string.upper(m.category);
	catLbl.Parent = card;

	const desc = new Instance("TextLabel");
	desc.BackgroundTransparency = 1;
	desc.Position = new UDim2(0, 12, 0, 52);
	desc.Size = new UDim2(1, -24, 0, 44);
	desc.Font = Enum.Font.Gotham;
	desc.TextSize = 12;
	desc.TextColor3 = theme.textMuted;
	desc.TextWrapped = true;
	desc.TextXAlignment = Enum.TextXAlignment.Left;
	desc.TextYAlignment = Enum.TextYAlignment.Top;
	desc.Text = m.description;
	desc.Parent = card;

	const toggleOn = getToggle(m.id);
	const toggleBg = new Instance("Frame");
	toggleBg.Position = new UDim2(1, -32, 0, 10);
	toggleBg.Size = new UDim2(0, 20, 0, 20);
	toggleBg.BackgroundColor3 = toggleOn ? theme.accent : theme.border;
	toggleBg.BorderSizePixel = 0;
	toggleBg.Parent = card;

	const tC = new Instance("UICorner");
	tC.CornerRadius = new UDim(0, 4);
	tC.Parent = toggleBg;

	const toggleHit = new Instance("TextButton");
	toggleHit.BackgroundTransparency = 1;
	toggleHit.Size = new UDim2(1, 0, 1, 0);
	toggleHit.Text = "";
	toggleHit.Parent = toggleBg;
	toggleHit.MouseButton1Click.Connect(() => {
		const isOn = !getToggle(m.id);
		toggleBg.BackgroundColor3 = isOn ? theme.accent : theme.border;
		onToggle(m.id, isOn);
	});

	const setBtn = new Instance("TextButton");
	setBtn.Size = new UDim2(0, 76, 0, 26);
	setBtn.Position = new UDim2(0, 12, 1, -34);
	setBtn.AnchorPoint = new Vector2(0, 1);
	setBtn.BackgroundColor3 = theme.accent;
	setBtn.TextColor3 = new Color3(1, 1, 1);
	setBtn.Font = Enum.Font.GothamBold;
	setBtn.TextSize = 11;
	setBtn.Text = "Settings";
	setBtn.AutoButtonColor = false;
	setBtn.Parent = card;

	const sB = new Instance("UICorner");
	sB.CornerRadius = new UDim(0, 8);
	sB.Parent = setBtn;
	setBtn.MouseButton1Click.Connect(() => onSettings(m.id));

	const star = new Instance("TextButton");
	star.BackgroundTransparency = 1;
	star.Size = new UDim2(0, 22, 0, 26);
	star.Position = new UDim2(0, 92, 1, -34);
	star.AnchorPoint = new Vector2(0, 1);
	star.Font = Enum.Font.GothamBold;
	star.TextSize = 16;
	const fav = getFavorite(m.id);
	star.TextColor3 = fav ? Color3.fromRGB(255, 220, 100) : theme.textMuted;
	star.Text = fav ? "*" : "-";
	star.AutoButtonColor = false;
	star.Parent = card;
	star.MouseButton1Click.Connect(() => {
		const nf = !getFavorite(m.id);
		star.TextColor3 = nf ? Color3.fromRGB(255, 220, 100) : theme.textMuted;
		star.Text = nf ? "*" : "-";
		onFavoriteToggle(m.id, nf);
	});

	const bindLbl = new Instance("TextLabel");
	bindLbl.BackgroundTransparency = 1;
	bindLbl.AnchorPoint = new Vector2(1, 1);
	bindLbl.Position = new UDim2(1, -12, 1, -30);
	bindLbl.Size = new UDim2(0, 44, 0, 16);
	bindLbl.Font = Enum.Font.GothamBold;
	bindLbl.TextSize = 10;
	bindLbl.TextColor3 = theme.text;
	bindLbl.TextXAlignment = Enum.TextXAlignment.Right;
	bindLbl.Text = "BIND";
	bindLbl.Parent = card;

	return card;
}
