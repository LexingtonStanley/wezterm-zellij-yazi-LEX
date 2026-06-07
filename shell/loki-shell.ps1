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
# zellij runs NATIVELY on Windows since 0.44 — point it at the shared loki
# config dir (theme + loki-dev / loki-agent layouts live there). BUT Windows
# zellij spawns cmd.exe in panes by default, and cmd doesn't load THIS profile —
# so Alt-k/yazi and every alias would be dead inside zellij. install.ps1 writes
# a Windows config.kdl (= the shared one + `default_shell pwsh.exe`) and we point
# ZELLIJ_CONFIG_FILE at it so panes spawn PowerShell, which loads loki-shell.ps1.
if (Test-Path (Join-Path $LokiRepo "zellij\config.kdl")) {
  $env:ZELLIJ_CONFIG_DIR = Join-Path $LokiRepo "zellij"
  $winZjCfg = Join-Path $env:LOCALAPPDATA "loki-zellij\config.kdl"
  if (Test-Path $winZjCfg) { $env:ZELLIJ_CONFIG_FILE = $winZjCfg }
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
# yazi: `y` quits back to whatever dir you browsed to (cwd written to a temp
# file, then we Set-Location into it). `yz` is plain yazi. Alt+k pops it open in
# the current pane via PSReadLine — the same chord as the bash side, so the
# muscle-memory is identical whether you're on Windows or SSH'd into Linux.
if (_have yazi) {
  function y {
    $tmp = New-TemporaryFile
    try {
      yazi @args --cwd-file="$($tmp.FullName)"
      $cwd = (Get-Content -Raw -- $tmp.FullName -ErrorAction SilentlyContinue)
      if ($cwd) { $cwd = $cwd.Trim() }
      if ($cwd -and $cwd -ne $PWD.Path) { Set-Location -LiteralPath $cwd }
    } finally {
      Remove-Item -- $tmp.FullName -ErrorAction SilentlyContinue
    }
  }
  function yz { yazi @args }
  # Alt+k → run `y`: clear the line, type `y`, press Enter. (A scriptblock can't
  # cleanly host a full-screen TUI, so we drive the prompt instead — same trick
  # PSFzf uses.) Over SSH the REMOTE shell's Alt-k binding handles it instead.
  #
  # ROBUSTNESS: `Set-PSReadLineOption -EditMode ...` RESETS the entire PSReadLine
  # key-handler table. A profile that loads AFTER this one (classically the
  # personal CurrentHost $PROFILE, Microsoft.PowerShell_profile.ps1) calling
  # EditMode would silently wipe the binding. So bind it as a function and apply
  # it twice: now, AND once on the first OnIdle — which fires after every profile
  # has loaded, right before the first prompt — so loki always gets the last word.
  function global:LokiBindYazi {
    if (Get-Module PSReadLine) {
      Set-PSReadLineKeyHandler -Chord 'Alt+k' -BriefDescription 'yazi' -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('y')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
      }
    }
  }
  LokiBindYazi
  try { Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action { LokiBindYazi } | Out-Null } catch {}
}
if (_have lazygit)  { function lg { lazygit @args } }
if (_have git)      { function gs { git status @args }; function gl { git log --oneline --graph --decorate -20 @args } }
if (_have claude)   { function cl { claude @args } }

# zd / za: zellij dev layouts. Native Windows zellij (0.44+) reads the loki
# config via $ZELLIJ_CONFIG_DIR above, so these run natively. If native zellij
# isn't installed but WSL is, fall back to the WSL layouts so muscle-memory
# still works. (loki-agent has a tmux pane — tmux has no native Windows build,
# so that one pane is a no-op on native Windows; loki-dev's yazi sidebar works.)
if (_have zellij) {
  function zd { zellij --layout loki-dev @args }
  function za { zellij --layout loki-agent @args }
  # Nested zellij-in-zellij: the inner session's control key is Ctrl-o (the outer
  # stays Ctrl-g) so the two layers never clash -- same scheme as the Linux side.
  # install.ps1 generates config-nested.kdl (= the loki config with Ctrl-g ->
  # Ctrl-o, + default_shell pwsh) next to the outer Windows config; zin/zind point
  # at it. For the classic local-outer + SSH-remote-inner flow you'd run `zin` on
  # the REMOTE box; these cover nesting locally on native Windows. (Ctrl-b still
  # passes through every locked layer to tmux, as documented in the cheatsheet.)
  $_lokiZjNested = Join-Path $env:LOCALAPPDATA "loki-zellij\config-nested.kdl"
  if (Test-Path $_lokiZjNested) {
    function zin  { zellij --config (Join-Path $env:LOCALAPPDATA "loki-zellij\config-nested.kdl") @args }
    function zind { zellij --config (Join-Path $env:LOCALAPPDATA "loki-zellij\config-nested.kdl") --layout loki-dev @args }
  }
} elseif (_have wsl) {
  function zd { wsl.exe -e bash -lic "zd" }
  function za { wsl.exe -e bash -lic "za" }
}
