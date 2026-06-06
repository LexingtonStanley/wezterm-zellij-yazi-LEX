# loki-shell.ps1 :: native-Windows PowerShell side of the Loki terminal setup.
# Sourced from your PowerShell $PROFILE by install.ps1. The bash equivalent is
# loki-shell.sh; this brings the same prompt/aliases/look to native PowerShell so
# claude + the CLI stack feel identical on Windows. Every block is guarded, so a
# missing tool just skips - it can never break your shell.

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

# -- prompt: starship (cyan-matrix theme shared with the rest of the stack) --
if (_have starship) {
  Invoke-Expression (& starship init powershell)
}

# -- smart-jump: zoxide (provides `z` / `zi`) -------------------------------
if (_have zoxide) {
  Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

# -- fuzzy finder: PSFzf if the module is installed (Ctrl-t / Ctrl-r) --------
if (Get-Module -ListAvailable -Name PSFzf -ErrorAction SilentlyContinue) {
  Import-Module PSFzf -ErrorAction SilentlyContinue
  try { Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' } catch {}
}

# -- predictive autosuggestions: PSReadLine ghost text from history ----------
# The native-Windows equivalent of ble.sh on the Linux side: as you type, the
# rest of a previous command appears greyed out - press Right/End to accept.
# Needs PSReadLine 2.1+ (ships with Windows 10+ / PowerShell 7); guarded so an
# older host just skips it instead of erroring.
# Gate on the module VERSION (not a runtime probe): -PredictionSource arrived in
# PSReadLine 2.1, so 5.1's in-box 2.0 cleanly skips the whole block. Each option
# is set independently so a no-op (e.g. PredictionSource is inert until a real
# interactive console attaches) can't abort the colour/view-style that follow.
$_prl = Get-Module PSReadLine
if (-not $_prl) { Import-Module PSReadLine -ErrorAction SilentlyContinue; $_prl = Get-Module PSReadLine }
if ($_prl -and $_prl.Version -ge [version]"2.1.0") {
  try { Set-PSReadLineOption -PredictionSource History } catch {}
  try { Set-PSReadLineOption -PredictionViewStyle InlineView } catch {}
  try { Set-PSReadLineOption -Colors @{ InlinePrediction = "#2b6b60" } } catch {}  # dim teal, matches ble.sh
}

# -- listings: eza with icons + git (ll / la / lt), else fall back to dir ----
if (_have eza) {
  function ll { eza -lah --icons --group-directories-first --git @args }
  function la { eza -a  --icons --group-directories-first @args }
  function lt { eza --tree --level=2 --icons --git-ignore @args }
  function ls { eza --icons --group-directories-first @args }
} else {
  function ll { Get-ChildItem -Force @args }
}

# -- file preview: bat (keeps `cat` intact; use `catp` for the pretty one) ---
if (_have bat) { function catp { bat @args } }

# -- handy launchers --------------------------------------------------------
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
