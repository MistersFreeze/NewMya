import type { HubTheme } from "../theme";

export function createHeader(parent: Instance, theme: HubTheme, brand: string): Frame {
	const titleBar = new Instance("Frame");
	titleBar.Name = "TitleBar";
	titleBar.BackgroundTransparency = 1;
	titleBar.Size = new UDim2(1, 0, 0, 36);
	titleBar.Parent = parent;

	const brandLbl = new Instance("TextLabel");
	brandLbl.BackgroundTransparency = 1;
	brandLbl.Position = new UDim2(0, 20, 0, 0);
	brandLbl.Size = new UDim2(0, 200, 1, 0);
	brandLbl.Font = Enum.Font.GothamMedium;
	brandLbl.TextSize = 14;
	brandLbl.TextColor3 = theme.textMuted;
	brandLbl.TextXAlignment = Enum.TextXAlignment.Left;
	brandLbl.TextYAlignment = Enum.TextYAlignment.Center;
	brandLbl.Text = brand;
	brandLbl.Parent = titleBar;

	const fav = new Instance("TextLabel");
	fav.BackgroundTransparency = 1;
	fav.Size = new UDim2(0, 80, 0, 20);
	fav.AnchorPoint = new Vector2(1, 0.5);
	fav.Position = new UDim2(1, -100, 0.5, 0);
	fav.Font = Enum.Font.GothamMedium;
	fav.TextSize = 12;
	fav.TextColor3 = theme.text;
	fav.Text = "Favorites";
	fav.Parent = titleBar;

	const friends = new Instance("TextLabel");
	friends.BackgroundTransparency = 1;
	friends.Size = new UDim2(0, 70, 0, 20);
	friends.AnchorPoint = new Vector2(1, 0.5);
	friends.Position = new UDim2(1, -16, 0.5, 0);
	friends.Font = Enum.Font.GothamMedium;
	friends.TextSize = 12;
	friends.TextColor3 = theme.text;
	friends.Text = "Friends";
	friends.Parent = titleBar;

	return titleBar;
}
