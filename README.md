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
where missing, installs **Tailscale** via its upstream installer, and symlinks every
config. It backs up anything it replaces to `<file>.pre-loki.<timestamp>`.

After install, join the tailnet once per box (interactive, browser login):
`sudo tailscale up --hostname=$(hostname -s) --ssh`. On Windows, `install.ps1` winget-
installs Tailscale alongside the other tools; sign in from the tray icon.

Flags: `--no-tools` (link configs only) · `--tools-only` (install packages only).

## Windows (native)

On Windows everything runs **natively**: WezTerm opens **native PowerShell** in your
project dir, and `claude`, `git`, `yazi`, `eza`, `bat`, `lazygit`, **`zellij`** … (the
tools on your Windows PATH) all just work — with a real `C:\` / `Q:\` prompt.
`wezterm.lua` is OS-aware and picks `pwsh` (PowerShell 7) if installed, else Windows
PowerShell.

**zellij is native on Windows since 0.44.** `install.ps1` fetches the **latest** build
straight from GitHub releases (winget lags), drops `zellij.exe` in
`%LOCALAPPDATA%\Zellij`, and puts it on PATH. `loki-shell.ps1` points it at the shared
config via `ZELLIJ_CONFIG_DIR`, so you get the same cyan-matrix theme + `loki-dev` /
`loki-agent` layouts. Launch with **`LEADER-z`** (`Ctrl-a` then `z`) or `zd` / `za`.

One Windows wrinkle: zellij spawns **`cmd.exe`** in panes by default, and cmd never
loads `loki-shell.ps1` — so Alt-k/yazi and the aliases would be dead *inside* zellij.
`install.ps1` fixes this by generating a Windows config
(`%LOCALAPPDATA%\loki-zellij\config.kdl` = the shared `config.kdl` + `default_shell
"pwsh.exe"`) and `loki-shell.ps1` aims `ZELLIJ_CONFIG_FILE` at it, so panes spawn
**PowerShell** instead. (Known upstream quirk: with a pwsh `default_shell`, new panes may
open in your home dir rather than the current one — zellij issue #5052.) Re-run
`install.ps1` after editing `zellij/config.kdl` so the Windows copy tracks it.

The remaining WSL-only piece is **tmux** (no native Windows build) — so the `loki-agent`
layout's tmux pane is the one thing that still needs WSL; `loki-dev` (yazi sidebar) is
fully native.

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
| **`Alt-k`**   | **pop open yazi in the current pane** — quits back to the dir you browsed to. Bound at the shell level so it works over SSH too (opens yazi on the *remote* box). Same chord on Linux (bash/ble.sh) and native Windows (PSReadLine). |
| `y`           | the function `Alt-k` runs — yazi that cd's to its last dir on quit |
| `zd` / `za`   | zellij dev layout / dev + tmux agent monitor |
| `zin` / `zind`| **nested** zellij for an SSH'd-into box (control key `Ctrl-o`, not `Ctrl-g`) |
| `yz`          | yazi in a floating zellij pane |
| `z <dir>`     | zoxide smart jump |
| `ll` `la` `lt`| eza listings with icons + git |

> **Why Alt-k and not a wezterm key?** A wezterm keybinding always spawns yazi
> *locally*. Putting the binding in the shell means wezterm just forwards `Alt-k`
> (ESC k) to whichever shell has focus — so inside an SSH session it opens yazi
> on the **remote** machine, browsing the remote filesystem. That's the
> "SSH passthrough". `LEADER-y` (`Ctrl-a` then `y`) still opens a *local* yazi
> tab when you want one.

## Nesting (local zellij ⊃ ssh ⊃ remote zellij)

Run zellij, SSH into another box, run zellij there, and drive **both** at once:

| Key | Controls |
|-----|----------|
| `Ctrl-g` | the **outer** zellij (the first one you started) |
| `Ctrl-o` | the **inner** zellij — start it with `zin`/`zind` so its control key doesn't clash with the outer's `Ctrl-g`. The keystroke passes through the outer's locked mode to reach it. |
| `Ctrl-b` | **tmux**, at any depth |
| `Alt-k`  | **yazi** — unbound in zellij on purpose, so it falls through every layer to the focused shell and opens yazi on *that* box (works on the inner/remote pane too) |

Keep the outer in its default **locked** mode so `Ctrl-o`/`Ctrl-b` pass through. To
drive the inner session use its **mode keys** (`Ctrl-o` then `p`/`t`/`r`…) — the outer
eats bare `Alt-*` zellij shortcuts in locked mode (`Alt-k` is the deliberate exception).

**On Windows** zellij is now native, so a local Windows zellij can be your **outer**
layer (`Ctrl-g`): start it with `LEADER-z`/`zd`, SSH into a Linux box from a pane, run
`zin` there for the **inner** (`Ctrl-o`). Or skip the local one — PowerShell + SSH just
forward `Ctrl-g`/`Ctrl-o`/`Ctrl-b`, so the first zellij you start after SSHing in is the
outer and a further `ssh … && zin` is the inner. WezTerm's leader is `Ctrl-a`, which
clashes with nothing. See the **NEST** section in `cheatsheet.html`.

## Palette

`bg #04110d` · `cyan #00f0c0` · `neon #2afadf` · `green #00d68f` · `blue #5ef1ff` ·
`yellow #b8e994` · `red #ff5d62`. One palette, shared across all tools.
