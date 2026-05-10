import type { HubTheme } from "../theme";
import { createModuleCard, type ModuleRow } from "./ModuleCard";

export type { ModuleRow } from "./ModuleCard";

export function createModuleGrid(
	parent: Instance,
	theme: HubTheme,
	cardBg: Color3,
	modules: ReadonlyArray<ModuleRow>,
): {
	scroll: ScrollingFrame;
	rebuild: (
		activeCategory: string,
		searchFilter: string,
		toggles: Map<string, boolean>,
		favorites: Map<string, boolean>,
		setStatus: (t: string) => void,
	) => void;
} {
	const scroll = new Instance("ScrollingFrame");
	scroll.Name = "ModuleGrid";
	scroll.BackgroundTransparency = 1;
	scroll.BorderSizePixel = 0;
	scroll.ScrollBarThickness = 6;
	scroll.ScrollBarImageColor3 = theme.accent;
	scroll.CanvasSize = new UDim2(0, 0, 0, 0);
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y;
	scroll.Parent = parent;

	const grid = new Instance("UIGridLayout");
	grid.CellSize = new UDim2(0, 280, 0, 168);
	grid.CellPadding = new UDim2(0, 12, 0, 12);
	grid.SortOrder = Enum.SortOrder.LayoutOrder;
	grid.Parent = scroll;

	const pad = new Instance("UIPadding");
	pad.PaddingTop = new UDim(0, 4);
	pad.PaddingBottom = new UDim(0, 12);
	pad.PaddingLeft = new UDim(0, 8);
	pad.PaddingRight = new UDim(0, 8);
	pad.Parent = scroll;

	function moduleVisible(m: ModuleRow, activeCategory: string, searchFilter: string): boolean {
		if (activeCategory !== "all" && m.category !== activeCategory) {
			return false;
		}
		if (searchFilter === "") {
			return true;
		}
		const q = string.lower(searchFilter);
		return (
			string.find(string.lower(m.name), q, 1, true) !== undefined ||
			string.find(string.lower(m.description), q, 1, true) !== undefined
		);
	}

	function rebuild(
		activeCategory: string,
		searchFilter: string,
		toggles: Map<string, boolean>,
		favorites: Map<string, boolean>,
		setStatus: (t: string) => void,
	): void {
		for (const c of scroll.GetChildren()) {
			if (!c.IsA("UIGridLayout") && !c.IsA("UIPadding")) {
				c.Destroy();
			}
		}

		let order = 0;
		function nameFor(id: string): string {
			for (const x of modules) {
				if (x.id === id) {
					return x.name;
				}
			}
			return id;
		}

		for (const m of modules) {
			if (!moduleVisible(m, activeCategory, searchFilter)) {
				continue;
			}
			order++;
			createModuleCard(
				scroll,
				theme,
				cardBg,
				m,
				order,
				(id, on) => {
					toggles.set(id, on);
					setStatus(`${nameFor(id)} ${on ? "on" : "off"}`);
				},
				(id) => {
					setStatus(`Settings for ${nameFor(id)} — wire in phase 2.`);
				},
				(id, fav) => {
					favorites.set(id, fav);
				},
				(id) => toggles.get(id) === true,
				(id) => favorites.get(id) === true,
			);
		}
	}

	return { scroll, rebuild };
}
