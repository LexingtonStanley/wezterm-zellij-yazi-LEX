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

  # Hook the shell file into ~/.bashrc (idempotent + self-healing).
  # IMPORTANT: source the file from $REPO, the *actual* install location — NOT a
  # hardcoded ~/.loki-term. If the repo is cloned elsewhere (e.g. GitHub's
  # default ~/<repo-name>), a hardcoded path silently no-ops behind the
  # `[ -f … ] &&` guard and the whole shell layer (cs/Alt-k/autosuggestions)
  # dies with no error. We rewrite any existing block so a stale path self-heals.
  local marker="# >>> loki-term shell >>>"
  local endmark="# <<< loki-term shell <<<"
  local shellfile="$REPO/shell/loki-shell.sh"
  local existed=0
  if grep -qF "$marker" "$HOME/.bashrc" 2>/dev/null; then
    existed=1
    # Strip the old block (portable in-place edit; no GNU-sed -i dependency).
    sed "/$marker/,/$endmark/d" "$HOME/.bashrc" > "$HOME/.bashrc.loki-tmp" \
      && mv "$HOME/.bashrc.loki-tmp" "$HOME/.bashrc"
  fi
  {
    echo ""
    echo "$marker"
    echo "[ -f \"$shellfile\" ] && . \"$shellfile\""
    echo "$endmark"
  } >> "$HOME/.bashrc"
  if [ "$existed" = 1 ]; then
    ok "refreshed loki-shell source line in ~/.bashrc -> $shellfile"
  else
    ok "added loki-shell source line to ~/.bashrc -> $shellfile"
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
      install_fzf_modern; install_zellij_apt; install_yazi_generic; install_wezterm_apt ;;
    dnf)
      sudo dnf install -y fzf zoxide eza bat fd-find ripgrep || warn "some dnf pkgs failed"
      install_fzf_modern; install_yazi_generic ;;
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
  install_blesh
  install_nerd_font
  install_tailscale
}

# ble.sh = fish-style autosuggestions (grey ghost text from history) for bash.
# Not packaged in apt; build from source into ~/.local/share/blesh. loki-shell.sh
# sources it automatically when present (guarded by a file check), so a box
# without it just falls back to plain bash line editing.
install_blesh() {
  [ -f "$HOME/.local/share/blesh/ble.sh" ] && { ok "ble.sh present (autosuggestions)"; return; }
  c "Installing ble.sh (bash autosuggestions)"
  ensure git git && ensure make make && ensure gawk gawk || { warn "ble.sh needs git/make/gawk"; return; }
  local tmp; tmp="$(mktemp -d)"
  git clone --recursive --depth 1 --shallow-submodules \
      https://github.com/akinomyoga/ble.sh.git "$tmp/ble.sh" >/dev/null 2>&1 \
    && make -C "$tmp/ble.sh" install PREFIX="$HOME/.local" >/dev/null 2>&1
  rm -rf "$tmp"
  [ -f "$HOME/.local/share/blesh/ble.sh" ] && ok "ble.sh installed (→ press → to accept a suggestion)" \
    || warn "ble.sh install failed"
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

# apt/dnf ship an ancient fzf (0.44.x on Ubuntu 24.04 / Debian) that lacks the
# `transform` bind action added in fzf 0.45 — which `cs`'s picker uses for its
# alt-c category cycler. On the old build fzf rejects the bind and exits
# instantly; cs captures stderr, so the picker just silently never appears.
# Drop a modern release binary into ~/.local/bin (early on PATH, no sudo needed,
# shadows the apt build) whenever the system fzf is missing or older than 0.45.
install_fzf_modern() {
  local need="0.45.0" cur=""
  have fzf && cur="$(fzf --version 2>/dev/null | awk '{print $1}')"
  if [ -n "$cur" ] && [ "$(printf '%s\n%s\n' "$need" "$cur" | sort -V | head -1)" = "$need" ]; then
    ok "fzf $cur ok (>= $need)"; return
  fi
  c "Installing modern fzf (system fzf ${cur:-absent} < $need; cs's picker needs it)"
  local arch a ver
  case "$(uname -m)" in
    x86_64) a=amd64 ;; aarch64|arm64) a=arm64 ;; armv7l) a=armv7 ;; *) a="$(uname -m)" ;;
  esac
  ver="$(curl -fsSL https://api.github.com/repos/junegunn/fzf/releases/latest \
        | grep -oE '"tag_name":[[:space:]]*"v?[0-9][^"]*' | grep -oE '[0-9][^"]+' | head -1)"
  [ -n "$ver" ] || { warn "couldn't resolve fzf release — cs search needs fzf >= $need"; return; }
  mkdir -p "$HOME/.local/bin"
  if curl -fsSL "https://github.com/junegunn/fzf/releases/download/v${ver}/fzf-${ver}-linux_${a}.tar.gz" \
       | tar -xz -C "$HOME/.local/bin" fzf; then
    chmod +x "$HOME/.local/bin/fzf"; hash -r 2>/dev/null || true
    ok "fzf $ver installed to ~/.local/bin (shadows apt's old build)"
  else
    warn "modern fzf install failed — cs interactive search needs fzf >= $need"
  fi
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

# Tailscale: upstream installer handles every distro's repo + keyring quirks,
# including the /etc/apt/keyrings vs /usr/share/keyrings list-file mismatch
# that bites hand-rolled installs on Debian-trixie-based boxes (Parrot 7 etc.).
# Doesn't run `tailscale up` — that needs interactive browser login per box.
install_tailscale() {
  have tailscale && { ok "tailscale present"; return; }
  c "Installing tailscale (upstream installer)"
  curl -fsSL https://tailscale.com/install.sh | sh >/dev/null 2>&1 \
    && ok "tailscale installed" \
    || warn "tailscale install failed — see https://tailscale.com/download"
}

# cs = the personal command cheatsheet. It lives in its OWN git repo
# (~/.local/share/cs) because its data store syncs bidirectionally across all
# boxes (lexbox primary + private GitHub mirror). loki-term just bootstraps it:
# clone if absent, reconcile if present, then run cs's own installer (PATH
# symlink, daily sync timer, completions). The shell/zellij integration
# (Alt-s insert-widget, Alt-/ pane, login sync) already ships in loki-shell.sh
# and config.kdl and no-ops until cs is on PATH.
CS_DIR="${CS_DIR:-$HOME/.local/share/cs}"
# tried in order; first reachable wins. Override with CS_REMOTE=… for a new box.
CS_REMOTES=(
  ${CS_REMOTE:-}
  "$HOME/git/terminal-cheatsheet.git"
  "lexde@lexbox:git/terminal-cheatsheet.git"
  "https://github.com/LexingtonStanley/terminal-cheatsheet.git"
)
# A box that cloned cs from the public GitHub mirror is effectively pull-only:
# it has no push credentials, so local `cs add`s never propagate AND every
# cs-sync prompts for a GitHub login (annoying on each new pane via the login
# hook). If the lexbox bare repo is reachable (key-based SSH — e.g. once the box
# is on Tailscale), repoint origin to it so the box becomes a full bidirectional
# peer. lexbox itself mirrors to GitHub, so leaf boxes don't need the GitHub URL.
cs_prefer_lexbox_remote() {
  local lexbox="lexde@lexbox:git/terminal-cheatsheet.git"
  local origin; origin="$(git -C "$CS_DIR" remote get-url origin 2>/dev/null || true)"
  case "$origin" in *github.com*) : ;; *) return 0 ;; esac   # only rescue a GitHub origin
  if GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' \
       git ls-remote "$lexbox" HEAD >/dev/null 2>&1; then
    git -C "$CS_DIR" remote set-url origin "$lexbox"
    git -C "$CS_DIR" remote set-url --push origin "$lexbox"
    ok "cs: repointed origin to lexbox (full peer; was GitHub pull-only)"
  fi
}

install_cs() {
  ensure git git >/dev/null 2>&1 || true
  have git     || { warn "cs needs git — skipping"; return; }
  have python3 || warn "cs needs python3 to run — will install code anyway"

  local origin="" known=0
  if [ -d "$CS_DIR/.git" ]; then
    origin="$(git -C "$CS_DIR" remote get-url origin 2>/dev/null || true)"
    case "$origin" in *terminal-cheatsheet*) known=1 ;; esac
  fi

  if [ "$known" = 1 ]; then
    c "Updating cs ($CS_DIR)"
  else
    c "Installing cs (command cheatsheet)"
    # a stale/disconnected copy (e.g. lexbox's early version) is moved aside
    if [ -e "$CS_DIR" ]; then
      mv "$CS_DIR" "${CS_DIR}.pre-loki.${TS}"
      warn "backed up existing $CS_DIR -> ${CS_DIR}.pre-loki.${TS}"
    fi
    local cloned=0 r
    for r in "${CS_REMOTES[@]}"; do
      [ -n "$r" ] || continue
      if git clone --quiet "$r" "$CS_DIR" 2>/dev/null; then
        ok "cloned cs from $r"; cloned=1; break
      fi
    done
    [ "$cloned" = 1 ] || {
      warn "could not clone cs (tried lexbox + GitHub). Set CS_REMOTE=<url> and re-run, or clone into $CS_DIR manually"
      return; }
  fi

  # Promote a GitHub-mirror origin to lexbox when reachable (full peer, no creds
  # prompt), then reconcile non-interactively so the installer can't hang on a
  # credential prompt or an unreachable remote.
  cs_prefer_lexbox_remote
  if [ -x "$CS_DIR/cs-sync" ]; then
    if GIT_TERMINAL_PROMPT=0 bash "$CS_DIR/cs-sync" >/dev/null 2>&1; then
      ok "cs synced (latest pulled, local changes pushed)"
    else
      warn "cs sync skipped (offline?) — run 'cs sync' later"
    fi
  fi

  if [ -x "$CS_DIR/install.sh" ]; then
    "$CS_DIR/install.sh" >/dev/null 2>&1 \
      && ok "cs installed — \`cs\` on PATH (try: cs, or Alt-/ in zellij)" \
      || warn "cs install.sh reported issues — run $CS_DIR/install.sh manually"
  fi
}

# ── run ─────────────────────────────────────────────────────────────────
c "▓▒░ Loki terminal setup ░▒▓   (repo: $REPO)"
[ "$DO_TOOLS" = 1 ] && install_pkgs
[ "$DO_LINK"  = 1 ] && link_configs
[ "$DO_TOOLS" = 1 ] && install_cs
c "Done. Open a new shell (or: source ~/.bashrc) and run:  zellij --layout loki-dev"
c "Cheatsheet: \`cs\` to search · Alt-/ in zellij · Alt-s inserts onto the prompt"
if have tailscale; then
  c "Tailscale: if this box isn't on the tailnet yet, join with:"
  c "    sudo tailscale up --hostname=$(hostname -s) --ssh"
fi
