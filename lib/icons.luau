local Icons = {
	search = "⌕",
	esp = "◉",
	silent_aim = "◎",
	aim_assist = "◌",
	walk_speed = "↔",
	jump_speed = "↑",
	close = "",
	minimize = "",
	settings = "⚙",
	favorite_on = "♥",
	favorite_off = "♡",
	changelog = "✦",
	friends = "☻",
}

function Icons.get(name: string): string
	return Icons[name] or "•"
end

return Icons
