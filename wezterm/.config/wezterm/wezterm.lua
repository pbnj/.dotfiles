local wezterm = require("wezterm")
local config = {}

config.color_scheme = "Tokyo Night Moon"
config.enable_scroll_bar = false
config.font = wezterm.font("FiraCode Nerd Font")
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"
config.window_background_opacity = 0.90
config.macos_window_background_blur = 25

return config
