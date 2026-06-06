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
