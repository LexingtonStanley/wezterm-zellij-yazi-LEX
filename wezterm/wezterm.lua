-- ~/.wezterm.lua  ──  Loki terminal :: "matrix, but turquoise"
-- Portable across Linux/macOS/Windows. Falls back gracefully if the
-- JetBrainsMono Nerd Font isn't installed (WezTerm picks the next mono font).
--
-- Part of the ~/.loki-term portable setup. Install via ~/.loki-term/install.sh

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder and wezterm.config_builder() or {}

------------------------------------------------------------------------
-- PALETTE  (single source of truth — keep in sync with zellij/yazi/starship)
------------------------------------------------------------------------
local C = {
  bg        = "#04110d", -- near-black, faint green-cyan tint
  bg_soft   = "#082a23", -- surfaces / inactive
  fg        = "#8af7e4", -- soft turquoise text
  fg_bright = "#c6fff4", -- bright text
  cyan      = "#00f0c0", -- primary turquoise
  neon      = "#2afadf", -- neon accent (cursor / active)
  green     = "#00d68f", -- matrix green-cyan
  dim       = "#2b6b60", -- muted teal
  sel       = "#0d3b33", -- selection bg
  red       = "#ff5d62",
  yellow    = "#b8e994",
  magenta   = "#5ef1ff",
}

------------------------------------------------------------------------
-- FONT
------------------------------------------------------------------------
config.font = wezterm.font_with_fallback({
  "JetBrainsMono Nerd Font",
  "JetBrainsMono Nerd Font Mono",
  "JetBrains Mono",
  "FiraCode Nerd Font",
  "monospace",
})
config.font_size = 12.0
config.line_height = 1.05
config.harfbuzz_features = { "calt=1", "liga=1" } -- ligatures on

------------------------------------------------------------------------
-- COLORS  (cyan-matrix)
------------------------------------------------------------------------
config.colors = {
  foreground   = C.fg,
  background   = C.bg,
  cursor_bg    = C.neon,
  cursor_fg    = C.bg,
  cursor_border= C.neon,
  selection_bg = C.sel,
  selection_fg = C.fg_bright,
  scrollbar_thumb = C.dim,
  split        = C.cyan,

  ansi = {
    "#03110e", -- black
    C.red,     -- red
    C.green,   -- green
    C.yellow,  -- yellow
    C.cyan,    -- blue  -> turquoise
    C.magenta, -- magenta -> bright cyan
    C.cyan,    -- cyan
    C.fg,      -- white
  },
  brights = {
    C.dim,       -- bright black
    "#ff8b8f",   -- bright red
    C.neon,      -- bright green -> neon turquoise
    "#e6ffb0",   -- bright yellow
    C.neon,      -- bright blue
    "#9ef7ff",   -- bright magenta
    C.neon,      -- bright cyan
    C.fg_bright, -- bright white
  },

  tab_bar = {
    background = C.bg,
    active_tab   = { bg_color = C.cyan,     fg_color = C.bg,  intensity = "Bold" },
    inactive_tab = { bg_color = C.bg_soft,  fg_color = C.dim },
    inactive_tab_hover = { bg_color = C.sel, fg_color = C.neon },
    new_tab      = { bg_color = C.bg_soft,  fg_color = C.cyan },
    new_tab_hover= { bg_color = C.cyan,     fg_color = C.bg },
  },
}

------------------------------------------------------------------------
-- LOOK & FEEL
------------------------------------------------------------------------
config.window_background_opacity = 0.94
config.text_background_opacity = 1.0
config.macos_window_background_blur = 20
-- "RESIZE" = borderless/sleek (no OS title bar). Because there's no title bar
-- to grab, move the window with SUPER+drag or CTRL+SHIFT+drag (see mouse_bindings).
-- Prefer a normal draggable title bar instead? Change this to "TITLE | RESIZE".
config.window_decorations = "RESIZE"
config.window_padding = { left = 8, right = 8, top = 6, bottom = 4 }
config.scrollback_lines = 50000
config.enable_scroll_bar = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = false
config.hide_tab_bar_if_only_one_tab = true
config.audible_bell = "Disabled"
config.cursor_blink_rate = 500
config.default_cursor_style = "BlinkingBlock"
config.inactive_pane_hsb = { saturation = 0.85, brightness = 0.70 }

-- A subtle "matrix" feel: faint cyan window frame for the rare case the tab
-- bar is shown with multiple tabs.
config.window_frame = {
  font = wezterm.font({ family = "JetBrainsMono Nerd Font", weight = "Bold" }),
  active_titlebar_bg = C.bg,
  inactive_titlebar_bg = C.bg,
}

------------------------------------------------------------------------
-- KEYS
-- Leader = Ctrl-a (doesn't clash with zellij's Ctrl-g or tmux's Ctrl-b,
-- so WezTerm, zellij and tmux can be nested without key collisions).
------------------------------------------------------------------------
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
  -- Pop open yazi (file browser) in a new tab, in the current dir.
  { key = "y", mods = "LEADER", action = act.SpawnCommandInNewTab({ args = { "yazi" } }) },
  -- Launch / attach a zellij session in a new tab.
  { key = "z", mods = "LEADER", action = act.SpawnCommandInNewTab({ args = { "zellij" } }) },
  -- Splits (only relevant when used WITHOUT zellij — inside zellij let zellij drive).
  { key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "-",  mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "c",  mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "x",  mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
  { key = "f",  mods = "LEADER", action = act.ToggleFullScreen },
  { key = "[",  mods = "LEADER", action = act.ActivateCopyMode },
  -- Font size
  { key = "=",  mods = "CTRL", action = act.IncreaseFontSize },
  { key = "-",  mods = "CTRL", action = act.DecreaseFontSize },
  { key = "0",  mods = "CTRL", action = act.ResetFontSize },
}

------------------------------------------------------------------------
-- MOUSE
-- With a borderless window (window_decorations="RESIZE") there's no title
-- bar to grab, so bind a modifier+drag to move the whole window.
------------------------------------------------------------------------
config.mouse_bindings = {
  -- Hold SUPER (the ⊞/⌘ key) and left-drag anywhere to move the window.
  { event = { Drag = { streak = 1, button = "Left" } }, mods = "SUPER",
    action = act.StartWindowDrag },
  -- Fallback for keyboards where SUPER is awkward: Ctrl+Shift + left-drag.
  { event = { Drag = { streak = 1, button = "Left" } }, mods = "CTRL|SHIFT",
    action = act.StartWindowDrag },
  -- Keep normal click-to-position-cursor behaviour (don't open links on plain click).
  { event = { Up = { streak = 1, button = "Left" } }, mods = "NONE",
    action = act.CompleteSelection("PrimarySelection") },
  -- Ctrl+click opens hyperlinks under the cursor.
  { event = { Up = { streak = 1, button = "Left" } }, mods = "CTRL",
    action = act.OpenLinkAtMouseCursor },
}

-- Quick tab switching with Ctrl-Alt-<n>
for i = 1, 9 do
  table.insert(config.keys, {
    key = tostring(i), mods = "CTRL|ALT", action = act.ActivateTab(i - 1),
  })
end

------------------------------------------------------------------------
-- MISC
------------------------------------------------------------------------
config.term = "xterm-256color"  -- safe default; wezterm's own terminfo also works
config.front_end = "WebGpu"     -- crisp GPU rendering; falls back automatically
config.warn_about_missing_glyphs = false
config.adjust_window_size_when_changing_font_size = false

return config
