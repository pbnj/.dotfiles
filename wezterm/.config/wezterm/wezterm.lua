local wezterm = require("wezterm")
local config = {}

config.color_scheme = "Tokyo Night Storm"
config.enable_scroll_bar = false
config.font = wezterm.font("JetBrains Mono")
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

return config
