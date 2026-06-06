# ◢◤ Loki Terminal

Portable, cyan/turquoise "matrix" terminal setup — **WezTerm · Zellij · Yazi · tmux · fzf** — that travels across every machine (incl. over SSH) from one directory.

## Quick start (any machine)

```bash
git clone <this-repo> ~/.loki-term
~/.loki-term/install.sh        # installs tools + links configs + hooks ~/.bashrc
exec bash                      # reload shell
zd                             # zellij dev layout with a yazi file sidebar
```

`install.sh` brings its own prerequisites (curl, unzip, gpg, fontconfig), installs the
toolchain via apt/dnf/pacman/brew, fetches WezTerm/Zellij/Yazi + JetBrainsMono Nerd Font
where missing, and symlinks every config. It backs up anything it replaces to
`<file>.pre-loki.<timestamp>`.

Flags: `--no-tools` (link configs only) · `--tools-only` (install packages only).

## Windows (native)

On Windows everything runs **natively**: WezTerm opens **native PowerShell** in your
project dir, and `claude`, `git`, `yazi`, `eza`, `bat`, `lazygit` … (the tools on your
Windows PATH) all just work — with a real `C:\` / `Q:\` prompt. `wezterm.lua` is
OS-aware and picks `pwsh` (PowerShell 7) if installed, else Windows PowerShell.

The one exception is **zellij**, which has no native Windows build. It stays in WSL and
is reachable on demand: press **`LEADER-z`** (`Ctrl-a` then `z`) in WezTerm, or run
`zd` / `za` from PowerShell.

From PowerShell:

```powershell
irm https://raw.githubusercontent.com/LexingtonStanley/wezterm-zellij-yazi-LEX/master/install.ps1 | iex
```

`install.ps1` installs the WezTerm config + JetBrainsMono Nerd Font, winget-installs the
native CLI tools (skipping whatever you already have), and hooks `loki-shell.ps1` into
your PowerShell `$PROFILE` for the cyan-matrix prompt (starship), `zoxide` jumps, and
the `ll`/`la`/`lt`/`catp`/`lg`/`y` aliases.

Flags: `-SkipFont` · `-SkipTools` (config + font only) · `-WithWsl` (also set up the
WSL Linux stack for zellij).

### Prefer the old boot-into-WSL behaviour?

Run `install.ps1 -WithWsl`, then set `WIN_USE_WSL = true` near the top of
`wezterm/wezterm.lua` (re-copy it to `%USERPROFILE%\.wezterm.lua`). WezTerm will then
boot the whole terminal into WSL like before.

### Make it yours — the knobs (all near the top of `wezterm/wezterm.lua`)

| Want | Edit | Example |
|------|------|---------|
| Open WezTerm in a specific dir (native) | `WIN_START_DIR_NATIVE` | `local WIN_START_DIR_NATIVE = "D:\\projects"` |
| Boot into WSL instead of PowerShell | `WIN_USE_WSL` | `local WIN_USE_WSL = true` |
| Start dir when in WSL mode | `WIN_START_DIR` | `local WIN_START_DIR = "/mnt/d/projects"` |
| Use a non-default WSL distro (zellij/WSL mode) | `WSL_DISTRO` | `local WSL_DISTRO = "Ubuntu"` |
| yazi drive-jump shortcuts | `prepend_keymap` in `yazi/keymap.toml` | `{ on=["g","e"], run="cd E:\\", desc="Go: E:" }` |

Built-in yazi jumps (press `g` then the key): `l`=the LEX project, `q`/`c`/`d`/`x`/`z`=that
drive, `w`=WSL home. Add your own drives by copying a line in `yazi/keymap.toml`.

After editing **`loki-shell.ps1`** (native Windows aliases/prompt): just open a new
PowerShell/WezTerm window — `$PROFILE` re-sources it.
After editing on the **WSL/Linux side** (yazi/zellij/shell): `git -C ~/.loki-term pull && ~/.loki-term/install.sh --no-tools`.
After editing **`wezterm.lua`**: the Windows `%USERPROFILE%\.wezterm.lua` is a *copy*
(Windows symlinks need admin), so re-run `install.ps1` or copy `wezterm/wezterm.lua`
over it. WezTerm auto-reloads — just open a new window.

### Slow prompt / "command timed out" (WSL mode only)

If you run in WSL mode, git/version commands on a `/mnt/<letter>` drive are slower than
native WSL and can trip starship's timeout. Raise `command_timeout` / `scan_timeout` in
`starship/starship.toml` (already bumped to 2000ms / 300ms here). For heavy git/npm
work, the native WSL filesystem (`~`) is much faster than `/mnt`. (Native PowerShell
mode runs directly on the Windows drive, so this doesn't apply.)

## What's inside

| Path | Role |
|------|------|
| `wezterm/wezterm.lua`        | WezTerm: cyan-matrix theme, leader `Ctrl-a`, SUPER/Ctrl+Shift-drag to move window |
| `zellij/config.kdl`          | Zellij: custom keybinds, `default_mode locked`, `loki-matrix` theme |
| `zellij/themes/loki-matrix.kdl` | The turquoise theme |
| `zellij/layouts/loki-dev.kdl`   | yazi file-browser sidebar + shell |
| `zellij/layouts/loki-agent.kdl` | …+ a tmux `agents` pane for inter-agent chat |
| `yazi/`                      | yazi theme.toml + yazi.toml |
| `starship/starship.toml`     | cyan-matrix prompt |
| `shell/loki-shell.sh`        | sourced from `~/.bashrc`: ble.sh autosuggestions, fzf, zoxide, eza, bat, aliases, prompt |
| `shell/loki-shell.ps1`       | native-Windows PowerShell profile: PSReadLine autosuggestions, starship, zoxide, eza/bat aliases |
| `install.ps1`                | Windows bootstrap (native): WezTerm config + font + CLI tools + PS profile |
| `cheatsheet.html`            | every keyboard shortcut, matrix-styled, searchable |

## Handy aliases (from `loki-shell.sh`)

| Alias | Does |
|-------|------|
| `zd` / `za`   | zellij dev layout / dev + tmux agent monitor |
| `zin` / `zind`| **nested** zellij for an SSH'd-into box (control key `Ctrl-o`, not `Ctrl-g`) |
| `yz`          | yazi in a floating zellij pane |
| `z <dir>`     | zoxide smart jump |
| `ll` `la` `lt`| eza listings with icons + git |

## Nesting (local zellij ⊃ ssh ⊃ remote zellij)

The outer (local) zellij owns `Ctrl-g`. Start the inner (remote) one with `zin` so its
control key is `Ctrl-o` — it passes through the outer's locked mode cleanly. tmux's
`Ctrl-b` works at any depth. See the **NEST** section in `cheatsheet.html`.

## Palette

`bg #04110d` · `cyan #00f0c0` · `neon #2afadf` · `green #00d68f` · `blue #5ef1ff` ·
`yellow #b8e994` · `red #ff5d62`. One palette, shared across all tools.
