-- ~/.wezterm.lua  ──  Loki terminal :: "matrix, but turquoise"
-- Portable across Linux/macOS/Windows. Falls back gracefully if the
-- JetBrainsMono Nerd Font isn't installed (WezTerm picks the next mono font).
-- On conair the font IS installed (~/.local/share/fonts/JetBrainsMonoNerd/),
-- so the first-choice family resolves directly.
--
-- Part of the ~/.loki-term portable setup. Install via ~/.loki-term/install.sh

local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder and wezterm.config_builder() or {}

------------------------------------------------------------------------
-- PLATFORM DETECTION
-- One config for Linux / macOS / Windows. On Windows, WezTerm runs NATIVELY
-- and opens native PowerShell by default — so claude, git, yazi, eza, bat,
-- and zellij (native on Windows since 0.44) all just work from your Windows
-- PATH, with a real C:\ / Q:\ prompt. LEADER-z launches native zellij.
--
-- Prefer the old "boot straight into WSL" behaviour (or no native zellij on a
-- given box)? Flip WIN_USE_WSL = true and LEADER-z routes through WSL instead.
------------------------------------------------------------------------
local triple = wezterm.target_triple
local is_windows = triple:find("windows") ~= nil
local is_mac = triple:find("darwin") ~= nil
local WSL_DISTRO = nil -- e.g. "Ubuntu" or "Debian"; nil = default distro

-- Windows behaviour: false = native PowerShell + native tools (default).
--                    true  = boot the whole terminal into WSL (the Linux stack).
local WIN_USE_WSL = false

-- Where WezTerm opens on Windows when running NATIVE (WIN_USE_WSL = false).
-- A normal Windows path. Set to nil to use your home dir (%USERPROFILE%).
local WIN_START_DIR_NATIVE = "Q:\\Codings\\ClaudeCodeProjects\\LEX"

-- Where WezTerm opens on Windows when running via WSL (WIN_USE_WSL = true).
-- Windows drives mount under /mnt/<letter>, so Q:\Codings\... => /mnt/q/Codings/...
-- Set to "~" for the WSL home instead. (Ignored on Linux/macOS.)
local WIN_START_DIR = "/mnt/q/Codings/ClaudeCodeProjects/LEX"

-- Build the arg list that runs `cmd` inside a login+interactive WSL shell
-- (so PATH/aliases load). Used for the zellij convenience on Windows, and for
-- every tool when WIN_USE_WSL = true.
local function wsl_cmd(cmd)
  local args = { "wsl.exe" }
  if WSL_DISTRO then table.insert(args, "-d"); table.insert(args, WSL_DISTRO) end
  for _, a in ipairs({ "--cd", WIN_START_DIR, "-e", "bash", "-lic", cmd }) do table.insert(args, a) end
  return args
end

-- Spawn `cmd` the right way for this platform: natively on Linux/macOS and on
-- native Windows (the tool must be on PATH), or via WSL when WIN_USE_WSL = true.
local function run_cmd(cmd)
  if is_windows and WIN_USE_WSL then return wsl_cmd(cmd) end
  return { cmd }
end

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
config.window_background_opacity = is_windows and 0.96 or 0.94
config.text_background_opacity = 1.0
if is_mac then config.macos_window_background_blur = 20 end
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
  -- Pop open yazi in a new LOCAL tab (Ctrl-a then y). Native everywhere (incl.
  -- Windows); only routed through WSL when WIN_USE_WSL = true.
  -- NOTE: the everyday yazi shortcut is Alt-k, bound at the SHELL level
  -- (loki-shell.sh / loki-shell.ps1) so it opens yazi in the CURRENT pane and
  -- works over SSH (Alt-k inside an SSH session opens yazi on the remote box).
  -- wezterm deliberately does NOT bind Alt-k — it forwards it to the shell.
  { key = "y", mods = "LEADER", action = act.SpawnCommandInNewTab({ args = run_cmd("yazi") }) },
  -- Launch / attach a zellij session in a new tab. Native everywhere now
  -- (zellij gained a native Windows build in 0.44); run_cmd() routes it through
  -- WSL only when WIN_USE_WSL = true.
  { key = "z", mods = "LEADER", action = act.SpawnCommandInNewTab({ args = run_cmd("zellij") }) },
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
-- Treat left-Alt as Meta so chords like Alt-k send ESC+k (\ek) to the shell,
-- which is what the readline / ble.sh / PSReadLine yazi binding listens for —
-- locally AND through SSH. (Right-Alt stays composing for accented chars.)
config.send_composed_key_when_left_alt_is_pressed = false
config.warn_about_missing_glyphs = false
config.adjust_window_size_when_changing_font_size = false

------------------------------------------------------------------------
-- WINDOWS: open native PowerShell by default (claude/git/yazi/eza/… on PATH),
-- starting in your project dir. Flip WIN_USE_WSL = true to boot into WSL instead.
-- pwsh (PowerShell 7) is preferred if installed; otherwise Windows PowerShell.
------------------------------------------------------------------------
if is_windows then
  if WIN_USE_WSL then
    local prog = { "wsl.exe" }
    if WSL_DISTRO then table.insert(prog, "-d"); table.insert(prog, WSL_DISTRO) end
    table.insert(prog, "--cd"); table.insert(prog, WIN_START_DIR)
    config.default_prog = prog
  else
    -- Prefer pwsh.exe (PowerShell 7) if it's installed, else Windows PowerShell.
    local ok, found = pcall(wezterm.run_child_process,
      { "pwsh", "-NoLogo", "-NoProfile", "-Command", "exit 0" })
    local have_pwsh = ok and found
    config.default_prog = have_pwsh and { "pwsh.exe", "-NoLogo" } or { "powershell.exe", "-NoLogo" }
    if WIN_START_DIR_NATIVE then config.default_cwd = WIN_START_DIR_NATIVE end
  end
end

------------------------------------------------------------------------
-- WEZTERM-NATIVE EXTRAS
-- Most useful when WezTerm owns the screen (native tabs/panes). Inside a
-- full-screen multiplexer (zellij / herdr / tmux) the prompt-jump, output
-- selection and file:line links only see that multiplexer's screen.
--
-- Shell side: the prompt must emit OSC 7 (cwd), OSC 133 (prompt markers) and
-- the `cmd_finished` user var. loki-shell.ps1 does this on Windows.
-- TODO(linux): add the bash equivalent to loki-shell.sh.
------------------------------------------------------------------------
local SEP = is_windows and "\\" or "/"

-- Absolute path of the pane's folder (from the prompt's OSC 7), or nil.
local function pane_cwd(pane)
  local cwd = pane:get_current_working_dir()
  if not cwd then return nil end
  local path
  if type(cwd) == "userdata" then path = cwd.file_path
  else path = (tostring(cwd):gsub("^file://[^/]*", "")) end
  if is_windows then path = path:gsub("^/(%a:)", "%1"):gsub("/", "\\") end
  return path
end

local function short_cwd(pane)
  local path = pane_cwd(pane)
  if not path then return "" end
  local home = is_windows and wezterm.home_dir:gsub("/", "\\") or wezterm.home_dir
  if path:lower():sub(1, #home) == home:lower() then path = "~" .. path:sub(#home + 1) end
  return path
end

-- STATUS BAR (right side of the tab bar)
--   [ LEADER ]  shown while Ctrl-a is armed (you have 1s to press the key)
--   workspace · current folder · time
-- The tab bar stays visible with one tab so this is always on screen.
config.hide_tab_bar_if_only_one_tab = false
config.status_update_interval = 1000

wezterm.on("update-status", function(window, pane)
  local cells = {}
  if window:leader_is_active() then
    table.insert(cells, { Background = { Color = "#ffcc00" } })
    table.insert(cells, { Foreground = { Color = C.bg } })
    table.insert(cells, { Attribute = { Intensity = "Bold" } })
    table.insert(cells, { Text = " LEADER " })
    table.insert(cells, "ResetAttributes")
    table.insert(cells, { Text = " " })
  end
  table.insert(cells, { Foreground = { Color = C.dim } })
  table.insert(cells, { Text = window:active_workspace() .. "  " })
  table.insert(cells, { Foreground = { Color = C.fg } })
  table.insert(cells, { Text = short_cwd(pane) .. "  " })
  table.insert(cells, { Foreground = { Color = C.cyan } })
  table.insert(cells, { Text = wezterm.strftime("%a %d %b  %H:%M") .. " " })
  window:set_right_status(wezterm.format(cells))
end)

-- LONG-COMMAND NOTIFICATIONS: the shell sets a `cmd_finished` user var when a
-- command took 30s+. If this window isn't focused, pop a desktop notification.
wezterm.on("user-var-changed", function(window, pane, name, value)
  if name == "cmd_finished" and not window:is_focused() then
    window:toast_notification("WezTerm", value, nil, 6000)
  end
end)

-- SHELL-INTEGRATION KEYS (need the OSC 133 prompt markers)
--   Shift+Up / Shift+Down   jump to previous / next prompt
--   triple-click            select one command's whole output
table.insert(config.keys, { key = "UpArrow",   mods = "SHIFT", action = act.ScrollToPrompt(-1) })
table.insert(config.keys, { key = "DownArrow", mods = "SHIFT", action = act.ScrollToPrompt(1) })
table.insert(config.mouse_bindings, { event = { Down = { streak = 3, button = "Left" } },
  mods = "NONE", action = act.SelectTextAtMouseCursor("SemanticZone") })

-- PROJECT / WORKSPACE SWITCHER
--   LEADER-w   fuzzy list: open workspaces (●) + your zoxide folders. Picking a
--              folder creates/switches to a workspace named after it, so each
--              project keeps its own tabs. Type to filter, Enter, Esc cancels.
--   LEADER-s   just the open workspaces
local function folder_name(dir) return dir:match("([^\\/]+)[\\/]*$") or dir end

table.insert(config.keys, { key = "w", mods = "LEADER", action = wezterm.action_callback(function(window, pane)
  local choices = {}
  for _, ws in ipairs(wezterm.mux.get_workspace_names()) do
    table.insert(choices, { id = "ws:" .. ws, label = "● " .. ws })
  end
  local ok, success, stdout = pcall(wezterm.run_child_process, { "zoxide", "query", "--list" })
  if ok and success then
    for dir in (stdout or ""):gmatch("[^\r\n]+") do
      table.insert(choices, { id = "dir:" .. dir, label = "  " .. folder_name(dir) .. "   " .. dir })
    end
  end
  window:perform_action(act.InputSelector({
    title = "Switch project",
    fuzzy = true,
    fuzzy_description = "Project: ",
    choices = choices,
    action = wezterm.action_callback(function(win, p, id)
      if not id then return end
      if id:sub(1, 3) == "ws:" then
        win:perform_action(act.SwitchToWorkspace({ name = id:sub(4) }), p)
      else
        local dir = id:sub(5)
        win:perform_action(act.SwitchToWorkspace({ name = folder_name(dir), spawn = { cwd = dir } }), p)
      end
    end),
  }), pane)
end) })
table.insert(config.keys, { key = "s", mods = "LEADER",
  action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES", title = "Workspaces" }) })

-- CLICKABLE file:line  (Ctrl+click, like other links)
-- `src/app.py:42`, `C:\x\y.ts:10:5` etc. in any output become links. Opens in
-- $EDITOR, else the first of code / cursor / nvim / hx / micro on PATH, else a
-- read-only bat view in a new tab scrolled to the line (q to close).
-- Known quirk: `host.com:8080` also looks like file:line (gives "not found").
config.hyperlink_rules = wezterm.default_hyperlink_rules()
table.insert(config.hyperlink_rules, {
  regex = [[\b(?:[A-Za-z]:[\\/])?[\w.\-\\/]*\w\.[A-Za-z][A-Za-z0-9]{0,5}:\d+(?::\d+)?\b]],
  format = "editfile:$0",
})

local function on_path(exe)
  local probe = is_windows and { "where.exe", "/q", exe } or { "sh", "-c", "command -v " .. exe }
  local ok, found = pcall(wezterm.run_child_process, probe)
  return ok and found
end

local GIT_LESS = "C:\\Program Files\\Git\\usr\\bin\\less.exe"

wezterm.on("open-uri", function(window, pane, uri)
  local target = uri:match("^editfile:(.*)$")
  if not target then return end  -- a normal URL: let WezTerm open it
  target = target:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
  local path, line = target:match("^(.-):(%d+)")
  if not path then return false end
  if is_windows then path = path:gsub("/", "\\") end
  local absolute = path:match("^%a:[\\/]") or path:match("^[\\/]") or path:match("^~")
  if not absolute then
    local cwd = pane_cwd(pane)
    if cwd then path = cwd:gsub("[\\/]$", "") .. SEP .. path end
  end
  path = path:gsub("^~", wezterm.home_dir)
  local f = io.open(path, "r")
  if not f then
    window:toast_notification("WezTerm", "File not found: " .. path, nil, 3000)
    return false
  end
  f:close()

  local function term_tab(args) window:perform_action(act.SpawnCommandInNewTab({ args = args }), pane) end
  local function gui(cmd, ...)
    local args = is_windows and { "cmd.exe", "/c", cmd, ... } or { cmd, ... }
    wezterm.background_child_process(args)
  end

  local editor = os.getenv("EDITOR")
  if editor and editor ~= "" then
    if editor:match("code") or editor:match("cursor") then gui(editor, "-g", path .. ":" .. line)
    else term_tab({ editor, "+" .. line, path }) end
  elseif on_path("code")   then gui("code", "-g", path .. ":" .. line)
  elseif on_path("cursor") then gui("cursor", "-g", path .. ":" .. line)
  elseif on_path("nvim")   then term_tab({ "nvim", "+" .. line, path })
  elseif on_path("hx")     then term_tab({ "hx", path .. ":" .. line })
  elseif on_path("micro")  then term_tab({ "micro", path .. ":" .. line })
  elseif is_windows then
    local q = "'" .. path:gsub("'", "''") .. "'"
    local view
    local lf = io.open(GIT_LESS, "r")
    if lf then
      lf:close()
      view = "bat --style=numbers --color=always --highlight-line " .. line .. " " .. q
          .. " | & '" .. GIT_LESS .. "' -R -j.3 +" .. line .. "g"
    else
      view = "bat --paging=always --style=numbers --highlight-line " .. line .. " " .. q
    end
    term_tab({ "pwsh.exe", "-NoLogo", "-NoProfile", "-Command", view })
  else
    local q = "'" .. path:gsub("'", "'\\''") .. "'"
    term_tab({ "sh", "-c", "$(command -v bat || command -v batcat) --style=numbers --color=always"
      .. " --highlight-line " .. line .. " " .. q .. " | less -R -j.3 +" .. line .. "g" })
  end
  return false
end)

return config
