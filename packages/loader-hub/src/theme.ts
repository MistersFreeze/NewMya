export interface HubTheme {
	readonly bg: Color3;
	readonly bgElevated: Color3;
	readonly surface: Color3;
	readonly border: Color3;
	readonly text: Color3;
	readonly textMuted: Color3;
	readonly accent: Color3;
}

export function defaultHubTheme(): HubTheme {
	return {
		bg: Color3.fromRGB(18, 18, 22),
		bgElevated: Color3.fromRGB(28, 28, 34),
		surface: Color3.fromRGB(22, 22, 28),
		border: Color3.fromRGB(44, 44, 56),
		text: Color3.fromRGB(240, 240, 245),
		textMuted: Color3.fromRGB(140, 140, 155),
		accent: Color3.fromRGB(90, 90, 243),
	};
}
