import type { HubTheme } from "../theme";

export interface TabDef {
	readonly id: string;
	readonly label: string;
}

export function createCategoryTabs(
	parent: Instance,
	theme: HubTheme,
	tabs: ReadonlyArray<TabDef>,
	onSelect: (id: string) => void,
): { row: Frame; setActive: (id: string) => void } {
	const row = new Instance("Frame");
	row.Name = "CategoryTabs";
	row.BackgroundTransparency = 1;
	row.Size = new UDim2(1, 0, 0, 32);
	row.ClipsDescendants = true;
	row.Parent = parent;

	const list = new Instance("UIListLayout");
	list.FillDirection = Enum.FillDirection.Horizontal;
	list.SortOrder = Enum.SortOrder.LayoutOrder;
	list.Padding = new UDim(0, 8);
	list.Parent = row;

	const buttons: Map<string, { btn: TextButton; underline: Frame }> = new Map();

	for (let i = 0; i < tabs.size(); i++) {
		const t = tabs[i]!;
		const wrap = new Instance("Frame");
		wrap.BackgroundTransparency = 1;
		wrap.Size = new UDim2(0, 0, 1, 0);
		wrap.AutomaticSize = Enum.AutomaticSize.X;
		wrap.LayoutOrder = i;
		wrap.Parent = row;

		const b = new Instance("TextButton");
		b.BackgroundTransparency = 1;
		b.Size = new UDim2(0, 0, 1, -6);
		b.AutomaticSize = Enum.AutomaticSize.X;
		b.Font = Enum.Font.GothamBold;
		b.TextSize = 11;
		b.Text = t.label;
		b.AutoButtonColor = false;
		b.Parent = wrap;

		const pad = new Instance("UIPadding");
		pad.PaddingLeft = new UDim(0, 10);
		pad.PaddingRight = new UDim(0, 10);
		pad.Parent = b;

		const underline = new Instance("Frame");
		underline.Name = "Underline";
		underline.Size = new UDim2(1, -20, 0, 2);
		underline.Position = new UDim2(0.5, 0, 1, -2);
		underline.AnchorPoint = new Vector2(0.5, 1);
		underline.BackgroundColor3 = theme.accent;
		underline.BorderSizePixel = 0;
		underline.Visible = false;
		underline.Parent = wrap;

		buttons.set(t.id, { btn: b, underline });

		b.MouseButton1Click.Connect(() => onSelect(t.id));
	}

	function setActive(id: string): void {
		for (const [tid, pair] of buttons) {
			const on = tid === id;
			pair.btn.TextColor3 = on ? theme.text : theme.textMuted;
			pair.underline.Visible = on;
		}
	}

	return { row, setActive };
}
