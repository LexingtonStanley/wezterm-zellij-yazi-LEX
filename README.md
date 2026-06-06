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

## Windows (via WSL)

Zellij and yazi don't run on native Windows — so on Windows the split is:
**WezTerm runs natively, and boots straight into WSL**, where the whole Linux
stack lives. `wezterm.lua` is OS-aware: it detects Windows and launches WSL for you.

From PowerShell:

```powershell
irm https://raw.githubusercontent.com/LexingtonStanley/wezterm-zellij-yazi-LEX/master/install.ps1 | iex
```

`install.ps1` installs the WezTerm config + JetBrainsMono Nerd Font on Windows, then
(inside WSL) clones the repo and runs `install.sh` for zellij/yazi/shell. If WSL isn't
present it tells you to run `wsl --install` first. Running the bash `install.sh` under
Git Bash/MSYS is blocked with a pointer to `install.ps1`.

### Working on Windows drives (Q:, D:, …) — make it yours

Inside WSL your Windows drives appear under `/mnt/<letter>` — so `Q:\Codings\Foo`
is `/mnt/q/Codings/Foo`. yazi and zellij run in WSL but operate on those files
through the mount. Three knobs, all near the top of `wezterm/wezterm.lua` and in
`yazi/keymap.toml`:

| Want | Edit | Example |
|------|------|---------|
| Open WezTerm in a specific dir | `WIN_START_DIR` in `wezterm/wezterm.lua` | `local WIN_START_DIR = "/mnt/d/projects"` |
| Use a non-default WSL distro | `WSL_DISTRO` in `wezterm/wezterm.lua` | `local WSL_DISTRO = "Ubuntu"` |
| yazi drive-jump shortcuts | `prepend_keymap` in `yazi/keymap.toml` | `{ on=["g","e"], run="cd /mnt/e", desc="Go: E:" }` |

Built-in yazi jumps (press `g` then the key): `l`=the LEX project, `q`/`c`/`d`/`x`/`z`=that
drive, `w`=WSL home. Add your own drives by copying a line in `yazi/keymap.toml`.

After editing on the **WSL side** (yazi/zellij/shell): `git -C ~/.loki-term pull && ~/.loki-term/install.sh --no-tools`.
After editing **`wezterm.lua`**: the Windows `%USERPROFILE%\.wezterm.lua` is a *copy*
(Windows symlinks need admin), so re-run `install.ps1` or copy `wezterm/wezterm.lua`
over it. WezTerm auto-reloads — just open a new window.

### Slow prompt / "command timed out"

Git and version commands on a `/mnt/<letter>` drive are slower than native WSL, which
can trip starship's timeout. Raise `command_timeout` / `scan_timeout` in
`starship/starship.toml` (already bumped to 2000ms / 300ms here). For heavy git/npm
work, the native WSL filesystem (`~`) is much faster than `/mnt`.

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
| `shell/loki-shell.sh`        | sourced from `~/.bashrc`: fzf, zoxide, eza, bat, aliases, prompt |
| `install.ps1`                | Windows bootstrap: WezTerm config + font, then WSL setup |
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
