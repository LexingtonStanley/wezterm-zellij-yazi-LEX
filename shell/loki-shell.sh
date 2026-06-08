#!/usr/bin/env bash
# loki-shell.sh :: portable shell sugar — fzf, zoxide, eza, bat, starship.
# Part of ~/.loki-term. Sourced from ~/.bashrc by install.sh:
#     [ -f ~/.loki-term/shell/loki-shell.sh ] && . ~/.loki-term/shell/loki-shell.sh
#
# Everything is guarded by `command -v`, so this file is safe to source on a
# machine that's missing some of the tools — it just skips what isn't there.
# That's what makes it portable: copy ~/.loki-term across, run install.sh
# (or just add the source line), and you get whatever that box has.

# Only run for interactive shells.
case $- in *i*) ;; *) return ;; esac

# Ensure user-local bins are on PATH (zellij/yazi/starship can live in
# ~/.local/bin when installed without root — e.g. inside WSL without sudo).
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac

# ── ble.sh (fish-style autosuggestions: grey ghost text from history) ────
# This is the "predictive typing" — type a few chars and the rest of a past
# command appears greyed out; press → (Right) or End to accept, Ctrl-→ for one
# word. Bash has no such feature natively; ble.sh provides it. Must be sourced
# EARLY with --noattach, then attached at the very END of this file so it wraps
# the PROMPT_COMMAND that starship/fzf/zoxide install below.
# Install: see ~/.loki-term/install.sh (builds it to ~/.local/share/blesh).
if [ -f "$HOME/.local/share/blesh/ble.sh" ]; then
  source "$HOME/.local/share/blesh/ble.sh" --noattach
fi

# ── palette (matches wezterm / zellij / yazi / starship) ────────────────
_LK_CYAN='\[\033[38;2;0;240;192m\]'   # #00f0c0
_LK_NEON='\[\033[38;2;42;250;223m\]'  # #2afadf
_LK_GREEN='\[\033[38;2;0;214;143m\]'  # #00d68f
_LK_DIM='\[\033[38;2;43;107;96m\]'    # #2b6b60
_LK_RED='\[\033[38;2;255;93;98m\]'    # #ff5d62
_LK_YEL='\[\033[38;2;184;233;148m\]'  # #b8e994
_LK_RST='\[\033[0m\]'

# ── bat (Debian ships the binary as `batcat`) ───────────────────────────
if command -v batcat >/dev/null 2>&1; then
  alias bat='batcat'
  alias cat='batcat --style=plain --paging=never'
  export BAT_THEME="ansi"   # picks up the terminal's cyan-matrix ANSI palette
  _LK_BAT='batcat'
elif command -v bat >/dev/null 2>&1; then
  alias cat='bat --style=plain --paging=never'
  export BAT_THEME="ansi"
  _LK_BAT='bat'
fi
# Use bat as the colourising pager for --help and man.
if [ -n "${_LK_BAT:-}" ]; then
  export MANPAGER="sh -c 'col -bx | ${_LK_BAT} -l man -p'"
  export MANROFFOPT="-c"
  help() { "$@" --help 2>&1 | ${_LK_BAT} -l help -p; }
fi

# ── eza (modern ls with icons + git) ────────────────────────────────────
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --group-directories-first --icons=auto'
  alias l='eza -1 --icons=auto'
  alias ll='eza -lh --git --group-directories-first --icons=auto'
  alias la='eza -lha --git --group-directories-first --icons=auto'
  alias lt='eza -T -L2 --icons=auto'          # tree, 2 levels
  alias ltt='eza -T -L4 --icons=auto'         # tree, 4 levels
  export EZA_COLORS="di=38;2;0;240;192:ln=38;2;94;241;255:ex=38;2;0;214;143"
fi

# ── fzf (fuzzy finder: Ctrl-R history, Ctrl-T files, Alt-C cd) ───────────
if command -v fzf >/dev/null 2>&1; then
  # cyan-matrix colours + half-screen layout
  export FZF_DEFAULT_OPTS="\
--height=45% --layout=reverse --border=rounded --info=inline \
--prompt='❯ ' --pointer='▶' --marker='✓' \
--color=bg+:#0d3b33,bg:#04110d,spinner:#2afadf,hl:#5ef1ff \
--color=fg:#8af7e4,header:#00d68f,info:#2b6b60,pointer:#2afadf \
--color=marker:#00d68f,fg+:#c6fff4,prompt:#00f0c0,hl+:#2afadf,border:#2b6b60"
  # Prefer fd/rg for listing if present (faster, respects .gitignore).
  if command -v fdfind >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fdfind --type d --hidden --exclude .git'
  elif command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
  fi
  # Preview files with bat / dirs with eza in Ctrl-T / Alt-C.
  if [ -n "${_LK_BAT:-}" ]; then
    export FZF_CTRL_T_OPTS="--preview '${_LK_BAT} -n --color=always {} 2>/dev/null || cat {}' --preview-window=right:60%"
  fi
  command -v eza >/dev/null 2>&1 && \
    export FZF_ALT_C_OPTS="--preview 'eza -T -L2 --icons=always --color=always {}'"

  # Load keybindings + completion (fzf >=0.48 exposes `fzf --bash`;
  # otherwise fall back to Debian's example scripts).
  if fzf --bash >/dev/null 2>&1; then
    eval "$(fzf --bash)"
  else
    [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && . /usr/share/doc/fzf/examples/key-bindings.bash
    [ -f /usr/share/bash-completion/completions/fzf ] && . /usr/share/bash-completion/completions/fzf
  fi
fi

# ── zoxide (smart cd: `z partial-name` jumps to frecent dirs) ────────────
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash --cmd cd)"   # replaces `cd`; use `cdi` for interactive pick
fi

# ── yazi (file manager: Alt-k pops it open; quits back to its last dir) ───
# `y` wraps yazi so that quitting (q) drops you in whatever directory you
# browsed to — yazi writes its cwd to a temp file and we cd into it.
#
# The Alt-k binding lives in the SHELL, not in wezterm — and that's deliberate:
# it's what makes yazi work "over SSH passthrough". wezterm just forwards the
# Alt-k bytes (ESC k) to whichever shell has focus, so pressing Alt-k inside an
# SSH session fires the REMOTE box's binding and opens yazi on the REMOTE
# filesystem. A wezterm-level binding would instead always open yazi locally.
if command -v yazi >/dev/null 2>&1; then
  y() {
    local tmp cwd
    tmp="$(mktemp -t yazi-cwd.XXXXXX)" || { yazi "$@"; return; }
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp" 2>/dev/null)" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
      builtin cd -- "$cwd" || true
    fi
    rm -f -- "$tmp"
  }
  # Bind Alt-k → y. ble.sh owns the keymap when it's loaded, so use its binder
  # (`-c` hands the terminal cleanly to the full-screen TUI and redraws the
  # prompt on exit); otherwise fall back to plain readline (\ek = Alt-k).
  if [[ ${BLE_VERSION-} ]]; then
    ble-bind -c 'M-k' 'y'
  else
    bind -x '"\ek": y' 2>/dev/null
  fi
fi

# ── handy aliases ───────────────────────────────────────────────────────
alias yz='zellij action new-pane --floating --close-on-exit -- yazi 2>/dev/null || yazi'  # yazi pane in zellij, else plain
alias zd='zellij --layout loki-dev'      # dev layout w/ yazi sidebar
alias za='zellij --layout loki-agent'    # dev layout + tmux agent monitor
# Nested zellij: use AFTER you've SSH'd into a box from inside your local
# zellij. Control key becomes Ctrl-o (outer stays Ctrl-g), so they don't clash.
alias zin='zellij --config ~/.config/zellij/config-nested.kdl'
alias zind='zellij --config ~/.config/zellij/config-nested.kdl --layout loki-dev'
alias grep='grep --color=auto'
command -v rg >/dev/null 2>&1 && alias rg='rg --smart-case'

# ── prompt: starship if present, else cyan-matrix box (Parrot-style) ─────
if command -v starship >/dev/null 2>&1; then
  export STARSHIP_CONFIG="$HOME/.config/starship.toml"
  eval "$(starship init bash)"
else
  # Recoloured version of the classic Parrot box prompt: red → cyan/turquoise.
  PS1="${_LK_CYAN}\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[${_LK_RED}\342\234\227${_LK_CYAN}]\342\224\200\")[$(if [[ ${EUID} == 0 ]]; then echo "${_LK_RED}\u${_LK_YEL}@${_LK_NEON}\h"; else echo "${_LK_GREEN}\u${_LK_YEL}@${_LK_NEON}\h"; fi)${_LK_CYAN}]\342\224\200[${_LK_NEON}\w${_LK_CYAN}]\n${_LK_CYAN}\342\224\224\342\224\200\342\224\200\342\225\274 ${_LK_NEON}\\$ ${_LK_RST}"
fi

# ── cs (command cheatsheet) ─────────────────────────────────────────────
# Alt-s : fuzzy-pick a saved command and INSERT it on the current prompt line
# (the daily driver — "ask → try → pick → it's on my line"). Alt-/ in zellij
# opens the full browse pane. See ~/.local/share/cs (repo: terminal-cheatsheet).
if command -v cs >/dev/null 2>&1; then
  if [[ ${BLE_VERSION-} ]]; then
    function ble/widget/cs-insert {
      local c; c=$(cs --print </dev/tty)        # fzf draws on /dev/tty
      [[ $c ]] && ble/widget/insert-string "$c"
      ble/widget/redraw-line 2>/dev/null
    }
    ble-bind -f 'M-s' 'cs-insert'
  else
    __cs_insert() {
      local c; c=$(cs --print) || return
      [ -n "$c" ] || return
      READLINE_LINE="${READLINE_LINE:0:READLINE_POINT}${c}${READLINE_LINE:READLINE_POINT}"
      READLINE_POINT=$(( READLINE_POINT + ${#c} ))
    }
    bind -x '"\es": __cs_insert' 2>/dev/null    # \es = Alt-s
  fi
  # background, throttled login sync (<=1/15min per box; never blocks the shell)
  if command -v cs-sync >/dev/null 2>&1; then
    __cs_stamp="${XDG_RUNTIME_DIR:-/tmp}/.cs-sync.stamp"
    if [ ! -f "$__cs_stamp" ] || \
       [ $(( $(date +%s) - $(stat -c %Y "$__cs_stamp" 2>/dev/null || echo 0) )) -gt 900 ]; then
      touch "$__cs_stamp" 2>/dev/null
      ( CS_SYNC_QUIET=1 cs-sync >/dev/null 2>&1 & ) 2>/dev/null
    fi
  fi
fi

# ── attach ble.sh LAST (after starship/fzf/zoxide set PROMPT_COMMAND) ─────
# Tune the autosuggestion look to match the cyan-matrix palette: dim-teal ghost
# text, and accept the whole suggestion with → / End (ble.sh default).
if [[ ${BLE_VERSION-} ]]; then
  bleopt complete_auto_complete=1                          # ghost text on (default)
  bleopt complete_auto_history=1                           # source suggestions from history
  ble-face -s auto_complete 'fg=#2b6b60'                   # _LK_DIM grey-teal ghost text
  ble-attach
fi
