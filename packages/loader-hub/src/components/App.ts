import { createBottomNav } from "./BottomNav";
import { createCategoryTabs } from "./CategoryTabs";
import { createHeader } from "./Header";
import { createModuleGrid, type ModuleRow } from "./ModuleGrid";
import { defaultHubTheme, type HubTheme } from "../theme";

const DEMO_MODULES: ReadonlyArray<ModuleRow> = [
	{ id: "left_clicker", name: "Left Clicker", category: "combat", description: "Reduce your own knockback." },
	{ id: "speed", name: "Speed", category: "movements", description: "Adjust walk speed." },
	{ id: "flight", name: "Flight", category: "movements", description: "Low-gravity hover stub." },
	{ id: "esp", name: "ESP", category: "visuals", description: "Highlight entities." },
	{ id: "fullbright", name: "Fullbright", category: "visuals", description: "Ambient lighting tweak." },
	{ id: "teleport", name: "Teleport", category: "utilities", description: "Saved locations stub." },
];

const TAB_DEFS = [
	{ id: "all", label: "ALL" },
	{ id: "combat", label: "COMBAT" },
	{ id: "movements", label: "MOVEMENTS" },
	{ id: "visuals", label: "VISUALS" },
	{ id: "utilities", label: "UTILITIES" },
] as const;

export interface MountOptions {
	readonly brand: string;
	readonly version: string;
	readonly theme?: HubTheme;
}

/**
 * Builds the Krokmou-style hub shell under `parent` (typically a Frame inside ScreenGui).
 * v1: layout and navigation only; module loading stays in Luau bootstrap.
 */
export function mountKrokmouShell(parent: Instance, options: MountOptions): void {
	const theme = options.theme ?? defaultHubTheme();
	const cardBg = theme.bgElevated;
	const toggles = new Map<string, boolean>();
	const favorites = new Map<string, boolean>();

	const main = new Instance("Frame");
	main.Name = "MyaHubMain";
	main.AnchorPoint = new Vector2(0.5, 0.5);
	main.Position = new UDim2(0.5, 0, 0.5, 0);
	main.Size = new UDim2(0, 520, 0, 620);
	main.BackgroundColor3 = theme.bg;
	main.BorderSizePixel = 0;
	main.Parent = parent;

	const mainCorner = new Instance("UICorner");
	mainCorner.CornerRadius = new UDim(0, 14);
	mainCorner.Parent = main;

	const mainStroke = new Instance("UIStroke");
	mainStroke.Color = theme.border;
	mainStroke.Parent = main;

	createHeader(main, theme, options.brand);

	const searchBox = new Instance("TextBox");
	searchBox.Name = "Search";
	searchBox.Position = new UDim2(0, 20, 0, 42);
	searchBox.Size = new UDim2(1, -40, 0, 34);
	searchBox.BackgroundColor3 = theme.bgElevated;
	searchBox.TextColor3 = theme.text;
	searchBox.PlaceholderText = "Search";
	searchBox.PlaceholderColor3 = theme.textMuted;
	searchBox.Font = Enum.Font.Gotham;
	searchBox.TextSize = 14;
	searchBox.ClearTextOnFocus = false;
	searchBox.Text = "";
	searchBox.Parent = main;

	const sC = new Instance("UICorner");
	sC.CornerRadius = new UDim(0, 8);
	sC.Parent = searchBox;

	const sP = new Instance("UIPadding");
	sP.PaddingLeft = new UDim(0, 12);
	sP.PaddingRight = new UDim(0, 12);
	sP.Parent = searchBox;

	const tabHost = new Instance("Frame");
	tabHost.BackgroundTransparency = 1;
	tabHost.Position = new UDim2(0, 12, 0, 82);
	tabHost.Size = new UDim2(1, -24, 0, 32);
	tabHost.Parent = main;

	let activeCategory = "all";
	let searchFilter = "";

	const { scroll, rebuild } = createModuleGrid(main, theme, cardBg, DEMO_MODULES);
	scroll.Position = new UDim2(0, 0, 0, 118);
	scroll.Size = new UDim2(1, 0, 1, -178);

	const { bar, setStatus } = createBottomNav(main, theme, `v${options.version}`, (key) => {
		if (key === "settings") {
			setStatus("Settings panel is a stub in v1.");
		} else if (key === "players") {
			setStatus("Friends list is a stub in v1.");
		} else {
			setStatus("Modules");
		}
	});
	bar.Position = new UDim2(0, 0, 1, -48);
	bar.AnchorPoint = new Vector2(0, 1);

	function refreshGrid(): void {
		rebuild(activeCategory, searchFilter, toggles, favorites, setStatus);
	}

	const { setActive } = createCategoryTabs(tabHost, theme, TAB_DEFS, (id) => {
		activeCategory = id;
		setActive(id);
		refreshGrid();
	});
	setActive(activeCategory);

	searchBox.GetPropertyChangedSignal("Text").Connect(() => {
		searchFilter = searchBox.Text;
		refreshGrid();
	});

	refreshGrid();

	const titleBar = main.WaitForChild("TitleBar") as Frame;
	const UserInputService = game.GetService("UserInputService");
	let drag: RBXScriptConnection | undefined;
	let dragStart: Vector2 | undefined;
	let startPos: UDim2 | undefined;

	titleBar.InputBegan.Connect((input) => {
		if (input.UserInputType === Enum.UserInputType.MouseButton1 || input.UserInputType === Enum.UserInputType.Touch) {
			dragStart = new Vector2(input.Position.X, input.Position.Y);
			startPos = main.Position;
			if (drag) {
				drag.Disconnect();
			}
			drag = UserInputService.InputChanged.Connect((inp) => {
				if (dragStart === undefined || startPos === undefined) {
					return;
				}
				if (inp.UserInputType === Enum.UserInputType.MouseMovement || inp.UserInputType === Enum.UserInputType.Touch) {
					const delta = new Vector2(inp.Position.X - dragStart.X, inp.Position.Y - dragStart.Y);
					main.Position = new UDim2(
						startPos.X.Scale,
						startPos.X.Offset + delta.X,
						startPos.Y.Scale,
						startPos.Y.Offset + delta.Y,
					);
				}
			});
		}
	});

	titleBar.InputEnded.Connect((input) => {
		if (input.UserInputType === Enum.UserInputType.MouseButton1 || input.UserInputType === Enum.UserInputType.Touch) {
			dragStart = undefined;
			startPos = undefined;
			if (drag) {
				drag.Disconnect();
				drag = undefined;
			}
		}
	});

	UserInputService.InputEnded.Connect((input) => {
		if (input.UserInputType === Enum.UserInputType.MouseButton1 || input.UserInputType === Enum.UserInputType.Touch) {
			dragStart = undefined;
			startPos = undefined;
			if (drag) {
				drag.Disconnect();
				drag = undefined;
			}
		}
	});
}
