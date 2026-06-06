#!/usr/bin/env bash
#
# install.sh :: bootstrap the Loki terminal setup on any machine.
#
#   On a new device:
#       git clone <repo> ~/.loki-term     # or scp -r ~/.loki-term you@box:~/
#       ~/.loki-term/install.sh           # links configs + installs tools
#
# Idempotent. Backs up anything it would overwrite to <file>.pre-loki.<ts>.
# Flags:
#   --no-tools   only link configs, don't try to install packages
#   --tools-only only install packages, don't link configs
#
set -euo pipefail

# Detect the machine and route to the right installer.
# WSL reports "Linux" and proceeds normally (that's the supported Windows path).
# Git Bash / MSYS / Cygwin on *native* Windows can't run zellij — redirect to install.ps1.
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)
    echo "This is Git Bash / MSYS on native Windows — zellij/yazi need WSL here."
    echo "Run the Windows installer from PowerShell instead:"
    echo "    powershell -ExecutionPolicy Bypass -File \"$(dirname "${BASH_SOURCE[0]}")/install.ps1\""
    echo "It installs WezTerm's config + the font, then sets up the Linux stack inside WSL."
    exit 1 ;;
esac

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TS="$(date +%Y%m%d-%H%M%S 2>/dev/null || echo bak)"
DO_LINK=1; DO_TOOLS=1
for a in "$@"; do
  case "$a" in
    --no-tools)   DO_TOOLS=0 ;;
    --tools-only) DO_LINK=0 ;;
    *) echo "unknown flag: $a"; exit 2 ;;
  esac
done

c()   { printf '\033[38;2;0;240;192m%s\033[0m\n' "$*"; }   # cyan
ok()  { printf '\033[38;2;0;214;143m  ✓ %s\033[0m\n' "$*"; }
warn(){ printf '\033[38;2;184;233;148m  ! %s\033[0m\n' "$*"; }

# symlink $1 -> $2, backing up an existing real file/dir/link first
link() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    ok "$dst (already linked)"; return
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "${dst}.pre-loki.${TS}"
    warn "backed up existing $dst -> ${dst}.pre-loki.${TS}"
  fi
  ln -s "$src" "$dst"
  ok "linked $dst"
}

link_configs() {
  c "Linking configs from $REPO"
  link "$REPO/wezterm/wezterm.lua"            "$HOME/.wezterm.lua"
  link "$REPO/zellij/config.kdl"              "$HOME/.config/zellij/config.kdl"
  link "$REPO/zellij/themes/loki-matrix.kdl"  "$HOME/.config/zellij/themes/loki-matrix.kdl"
  link "$REPO/zellij/layouts/loki-dev.kdl"    "$HOME/.config/zellij/layouts/loki-dev.kdl"
  link "$REPO/zellij/layouts/loki-agent.kdl"  "$HOME/.config/zellij/layouts/loki-agent.kdl"
  link "$REPO/yazi/theme.toml"                "$HOME/.config/yazi/theme.toml"
  link "$REPO/yazi/yazi.toml"                 "$HOME/.config/yazi/yazi.toml"
  link "$REPO/yazi/keymap.toml"               "$HOME/.config/yazi/keymap.toml"
  link "$REPO/starship/starship.toml"         "$HOME/.config/starship.toml"

  # Nested-session config: identical to config.kdl but the control key is
  # Ctrl-o instead of Ctrl-g, so an *inner* zellij (e.g. one you open after
  # SSHing into another box from within your local zellij) doesn't fight the
  # outer one for Ctrl-g. Regenerated every run so it tracks config.kdl.
  # Launch a nested session with the `zin` alias (see loki-shell.sh).
  sed 's/Ctrl g/Ctrl o/g' "$REPO/zellij/config.kdl" > "$HOME/.config/zellij/config-nested.kdl"
  ok "generated config-nested.kdl (inner control key = Ctrl-o)"

  # Hook the shell file into ~/.bashrc (idempotent, marker-guarded).
  local marker="# >>> loki-term shell >>>"
  if ! grep -qF "$marker" "$HOME/.bashrc" 2>/dev/null; then
    {
      echo ""
      echo "$marker"
      echo '[ -f ~/.loki-term/shell/loki-shell.sh ] && . ~/.loki-term/shell/loki-shell.sh'
      echo "# <<< loki-term shell <<<"
    } >> "$HOME/.bashrc"
    ok "added loki-shell source line to ~/.bashrc"
  else
    ok "~/.bashrc already sources loki-shell"
  fi
}

# ── tool installation ───────────────────────────────────────────────────
have() { command -v "$1" >/dev/null 2>&1; }

pm_detect() {
  if   have apt;    then echo apt
  elif have dnf;    then echo dnf
  elif have pacman; then echo pacman
  elif have brew;   then echo brew
  else echo none; fi
}

# Make sure a command exists; if not, install the named package via the
# detected package manager. Usage: ensure <cmd> <apt-pkg> [dnf-pkg] [pacman-pkg]
ensure() {
  local cmd="$1" apt_p="${2:-$1}" dnf_p="${3:-$2}" pac_p="${4:-$2}"
  have "$cmd" && return 0
  case "$(pm_detect)" in
    apt)    sudo apt install -y "$apt_p" ;;
    dnf)    sudo dnf install -y "${dnf_p:-$apt_p}" ;;
    pacman) sudo pacman -S --noconfirm "${pac_p:-$apt_p}" ;;
    brew)   brew install "$apt_p" ;;
  esac >/dev/null 2>&1
  have "$cmd"
}

# Prerequisites the installer itself needs to fetch/unpack things.
install_prereqs() {
  c "Ensuring prerequisites (curl, unzip, tar, gpg, fontconfig)…"
  ensure curl       curl                && ok "curl"       || warn "curl missing — downloads will fail"
  ensure unzip      unzip               && ok "unzip"      || warn "unzip missing — zip extraction will fail"
  ensure tar        tar                 && ok "tar"
  ensure gpg        gnupg               && ok "gpg"
  ensure fc-cache   fontconfig          && ok "fontconfig" || warn "fontconfig missing — font won't register"
}

install_pkgs() {
  local pm; pm="$(pm_detect)"
  c "Installing CLI toolchain via: $pm"
  install_prereqs
  case "$pm" in
    apt)
      sudo apt update -qq || true
      sudo apt install -y fzf zoxide eza bat fd-find ripgrep || warn "some apt pkgs failed"
      install_zellij_apt; install_yazi_generic; install_wezterm_apt ;;
    dnf)
      sudo dnf install -y fzf zoxide eza bat fd-find ripgrep || warn "some dnf pkgs failed"
      install_yazi_generic ;;
    pacman)
      sudo pacman -Sy --noconfirm fzf zoxide eza bat fd ripgrep zellij yazi wezterm || warn "some pacman pkgs failed" ;;
    brew)
      brew install fzf zoxide eza bat fd ripgrep zellij yazi || warn "some brew pkgs failed"
      brew install --cask wezterm || true ;;
    *)
      warn "no known package manager; install fzf/zoxide/eza/bat/zellij/yazi manually" ;;
  esac
  if ! have starship; then
    c "Installing starship"
    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes || warn "starship install failed"
    # starship's installer prints generic "add this to your shell rc" advice —
    # ignore it: loki-shell.sh already runs `eval "$(starship init bash)"`.
    ok "starship wired automatically via loki-shell.sh — ignore its manual-setup printout"
  fi
  install_nerd_font
}

# Unzip a file to a dir using whatever's available (unzip, else bsdtar).
unpack_zip() {
  local zip="$1" dest="$2"
  if have unzip; then unzip -qo "$zip" -d "$dest"
  elif have bsdtar; then bsdtar -xf "$zip" -C "$dest"
  else return 1; fi
}

# zellij / wezterm aren't always in apt; fall back to upstream binaries.
install_zellij_apt() {
  have zellij && { ok "zellij present"; return; }
  c "Installing zellij (upstream binary)"
  local url; url="$(curl -fsSL https://api.github.com/repos/zellij-org/zellij/releases/latest \
        | grep -oE 'https://[^"]*x86_64-unknown-linux-musl\.tar\.gz' | head -1)"
  [ -n "$url" ] || { warn "couldn't resolve zellij release"; return; }
  curl -fsSL "$url" | sudo tar -xz -C /usr/local/bin zellij && ok "zellij installed"
}

install_wezterm_apt() {
  have wezterm && { ok "wezterm present"; return; }
  c "Installing wezterm (Fury APT repo)"
  curl -fsSL https://apt.fury.io/wez/gpg.key | sudo gpg --yes --dearmor -o /usr/share/keyrings/wezterm-fury.gpg
  echo "deb [signed-by=/usr/share/keyrings/wezterm-fury.gpg] https://apt.fury.io/wez/ * *" \
     | sudo tee /etc/apt/sources.list.d/wezterm.list >/dev/null
  sudo apt update -qq && sudo apt install -y wezterm || warn "wezterm install failed"
}

install_yazi_generic() {
  have yazi && { ok "yazi present"; return; }
  c "Installing yazi (upstream binary)"
  local url; url="$(curl -fsSL https://api.github.com/repos/sxyazi/yazi/releases/latest \
        | grep -oE 'https://[^"]*x86_64-unknown-linux-gnu\.zip' | head -1)"
  [ -n "$url" ] || { warn "couldn't resolve yazi release"; return; }
  ensure unzip unzip || { warn "need unzip to install yazi (sudo apt install unzip)"; return; }
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/y.zip" && unpack_zip "$tmp/y.zip" "$tmp" \
    && sudo install "$tmp"/yazi*/yazi /usr/local/bin/ \
    && sudo install "$tmp"/yazi*/ya   /usr/local/bin/ 2>/dev/null
  rm -rf "$tmp"; have yazi && ok "yazi installed" || warn "yazi install failed"
}

install_nerd_font() {
  if fc-list 2>/dev/null | grep -qi 'JetBrainsMono Nerd'; then ok "JetBrainsMono Nerd Font present"; return; fi
  c "Installing JetBrainsMono Nerd Font"
  ensure unzip unzip || { warn "need unzip to install the Nerd Font (sudo apt install unzip)"; return; }
  local dir="$HOME/.local/share/fonts/JetBrainsMonoNerd"; mkdir -p "$dir"
  local url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  local tmp; tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmp/f.zip" && unpack_zip "$tmp/f.zip" "$dir" \
    && fc-cache -f "$dir" >/dev/null 2>&1 && ok "font installed" || warn "font install failed"
  rm -rf "$tmp"
  rm -rf "$tmp"
}

# ── run ─────────────────────────────────────────────────────────────────
c "▓▒░ Loki terminal setup ░▒▓   (repo: $REPO)"
[ "$DO_TOOLS" = 1 ] && install_pkgs
[ "$DO_LINK"  = 1 ] && link_configs
c "Done. Open a new shell (or: source ~/.bashrc) and run:  zellij --layout loki-dev"
