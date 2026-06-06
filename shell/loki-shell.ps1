# loki-shell.ps1 :: native-Windows PowerShell side of the Loki terminal setup.
# Sourced from your PowerShell $PROFILE by install.ps1. The bash equivalent is
# loki-shell.sh; this brings the same prompt/aliases/look to native PowerShell so
# claude + the CLI stack feel identical on Windows. Every block is guarded, so a
# missing tool just skips — it can never break your shell.

# UTF-8 everywhere (Nerd Font glyphs, box-drawing, emoji).
try { [Console]::OutputEncoding = [Text.UTF8Encoding]::new() } catch {}
$OutputEncoding = [Text.UTF8Encoding]::new()

$LokiRepo = Join-Path $env:USERPROFILE ".loki-term"

# Point the shared configs at the repo (single source of truth with the WSL side).
if (Test-Path (Join-Path $LokiRepo "starship\starship.toml")) {
  $env:STARSHIP_CONFIG = Join-Path $LokiRepo "starship\starship.toml"
}
if (Test-Path (Join-Path $LokiRepo "yazi")) {
  $env:YAZI_CONFIG_HOME = Join-Path $LokiRepo "yazi"
}

function _have($name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# ── prompt: starship (cyan-matrix theme shared with the rest of the stack) ──
if (_have starship) {
  Invoke-Expression (& starship init powershell)
}

# ── smart-jump: zoxide (provides `z` / `zi`) ───────────────────────────────
if (_have zoxide) {
  Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# ── fuzzy finder: PSFzf if the module is installed (Ctrl-t / Ctrl-r) ────────
if (Get-Module -ListAvailable -Name PSFzf -ErrorAction SilentlyContinue) {
  Import-Module PSFzf -ErrorAction SilentlyContinue
  try { Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' } catch {}
}

# ── listings: eza with icons + git (ll / la / lt), else fall back to dir ────
if (_have eza) {
  function ll { eza -lah --icons --group-directories-first --git @args }
  function la { eza -a  --icons --group-directories-first @args }
  function lt { eza --tree --level=2 --icons --git-ignore @args }
  function ls { eza --icons --group-directories-first @args }
} else {
  function ll { Get-ChildItem -Force @args }
}

# ── file preview: bat (keeps `cat` intact; use `catp` for the pretty one) ───
if (_have bat) { function catp { bat @args } }

# ── handy launchers ────────────────────────────────────────────────────────
if (_have yazi)     { function y  { yazi @args }; function yz { yazi @args } }
if (_have lazygit)  { function lg { lazygit @args } }
if (_have git)      { function gs { git status @args }; function gl { git log --oneline --graph --decorate -20 @args } }
if (_have claude)   { function cl { claude @args } }

# zd / za: the zellij dev layouts live in WSL (no native Windows zellij). These
# shortcuts open them there so muscle-memory still works from native PowerShell.
if (_have wsl) {
  function zd { wsl.exe -e bash -lic "zd" }
  function za { wsl.exe -e bash -lic "za" }
}
