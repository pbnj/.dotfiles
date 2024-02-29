local wezterm = require("wezterm")

return {
  color_scheme = "Tokyo Night Moon",
  enable_scroll_bar = false,
  font = wezterm.font("Iosevka Nerd Font"),
  font_size = 14.0,
  hide_tab_bar_if_only_one_tab = true,
  window_decorations = "RESIZE",
  keys = {
    {
      key = "w",
      mods = "CMD",
      action = wezterm.action.CloseCurrentPane({ confirm = true }),
    },
    {
      key = "w",
      mods = "CMD",
      action = wezterm.action.CloseCurrentTab({ confirm = true }),
    },
  },
}
