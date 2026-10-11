-- star-wars-terminal for WezTerm. Paste these lines into ~/.wezterm.lua before `return config`.
-- WezTerm ships the Catppuccin Mocha scheme built in.
config.font = wezterm.font("JetBrainsMono Nerd Font Mono")
config.color_scheme = "Catppuccin Mocha"
config.background = {
  {
    source = { File = wezterm.home_dir .. "/.config/star-wars-terminal/starfield.png" },
    width = "Cover",
    height = "Cover",
    horizontal_align = "Right",
    vertical_align = "Bottom",
  },
}
