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
# PSReadLine 2.2+: suggestions from history AND tab-completion (CompletionPredictor
# module, PowerShell 7 only), shown as a dropdown list. F2 flips list <-> inline.
if ($_prl -and $_prl.Version -ge [version]"2.2.0") {
  try {
    if ($PSVersionTable.PSVersion.Major -ge 7 -and (Get-Module -ListAvailable CompletionPredictor)) {
      Import-Module CompletionPredictor -ErrorAction Stop
      Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    }
  } catch {}
  try { Set-PSReadLineOption -PredictionViewStyle ListView } catch {}
  try { Set-PSReadLineKeyHandler -Key F2 -Function SwitchPredictionView } catch {}
}

# -- history: bigger, no duplicates; Up/Down search by what's typed ---------
# (type `git c`, press Up -> only commands starting with `git c`)
if ($_prl) {
  try {
    Set-PSReadLineOption -MaximumHistoryCount 100000 -HistoryNoDuplicates -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    # Tab opens a selectable completion menu instead of cycling one match.
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
  } catch {}
}

# -- fzf: fd for Ctrl-t (fast, respects .gitignore); Alt-c = fuzzy cd -------
if (_have fd) {
  $env:FZF_DEFAULT_COMMAND = 'fd --type f --hidden --exclude .git'
  $env:FZF_CTRL_T_COMMAND  = $env:FZF_DEFAULT_COMMAND
  $env:FZF_ALT_C_COMMAND   = 'fd --type d --hidden --exclude .git'
}
if ($_prl -and (Get-Command Invoke-FuzzySetLocation -ErrorAction SilentlyContinue)) {
  Set-PSReadLineKeyHandler -Key Alt+c -BriefDescription 'fuzzy cd' -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Invoke-FuzzySetLocation')
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
  }
}

# -- completions: carapace (flags/subcommands for git, winget, docker, gh...) -
# The init script is cached and regenerated only when carapace is updated.
$_carapace = Get-Command carapace -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if ($_carapace) {
  $_cache = Join-Path $env:LOCALAPPDATA 'carapace-init.ps1'
  if (-not (Test-Path $_cache) -or (Get-Item $_cache).LastWriteTime -lt (Get-Item $_carapace.Source).LastWriteTime) {
    & $_carapace.Source _carapace powershell | Out-File -Encoding utf8 $_cache
  }
  . $_cache
}
Remove-Variable _carapace, _cache -ErrorAction SilentlyContinue
# quick help: `tldr <command>` (tealdeer) shows short usage examples.

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
  # Resolve the real zellij.exe (CommandType Application) so the wrapper below can
  # call it without recursing into itself.
  function global:_LokiZjExe { (Get-Command zellij -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source }
  function global:_LokiZjNestedCfg { Join-Path $env:LOCALAPPDATA "loki-zellij\config-nested.kdl" }

  # Auto-nesting: wrap `zellij` so zellij-in-zellij "just works". When we're
  # already INSIDE a session ($env:ZELLIJ is set) and starting a NEW one, use
  # config-nested.kdl, whose control key is Ctrl-o -- so the inner session never
  # collides with the outer's Ctrl-g. Outside a session it's plain zellij (the
  # outer config via ZELLIJ_CONFIG_FILE, control = Ctrl-g). Ctrl-b still passes
  # through every locked layer to tmux. Session-management subcommands (attach,
  # ls, kill, action, ...) are passed through untouched -- only new sessions nest.
  # install.ps1 generates config-nested.kdl (= the loki config, Ctrl-g -> Ctrl-o,
  # + default_shell pwsh). zin/zind below force the nested config explicitly.
  function zellij {
    $exe = _LokiZjExe
    if (-not $exe) { Write-Error "zellij not found on PATH"; return }
    $nested = _LokiZjNestedCfg
    $sub = @($args | Where-Object { $_ -notlike '-*' })[0]
    $mgmt = @('attach','a','list-sessions','ls','list-aliases','kill-session','k',
              'kill-all-sessions','delete-session','delete-all-sessions','da','setup',
              'options','action','run','r','plugin','edit','e','convert-config','pipe')
    $isNewSession = -not ($sub -and ($mgmt -contains $sub))
    if ($env:ZELLIJ -and $isNewSession -and (Test-Path $nested)) { & $exe --config $nested @args }
    else { & $exe @args }
  }
  # zd/za go through the wrapper, so they auto-nest too when run inside a session.
  function zd { zellij --layout loki-dev @args }
  function za { zellij --layout loki-agent @args }
  # Explicit nested launchers -- force the inner (Ctrl-o) config regardless of
  # context (e.g. driving a remote box, or nesting from a non-zellij shell).
  function zin  { $exe = _LokiZjExe; & $exe --config (_LokiZjNestedCfg) @args }
  function zind { $exe = _LokiZjExe; & $exe --config (_LokiZjNestedCfg) --layout loki-dev @args }
} elseif (_have wsl) {
  function zd { wsl.exe -e bash -lic "zd" }
  function za { wsl.exe -e bash -lic "za" }
}

# -- atuin: full-screen history search on Ctrl-r (folder, exit code, duration)
# Overrides PSFzf's Ctrl-r when installed; Up arrow stays the prefix search.
# Loaded near the end because it wraps PSConsoleHostReadLine.
if ($_prl -and (_have atuin)) {
  try { atuin init powershell --disable-up-arrow --disable-ai | Out-String | Invoke-Expression } catch {}
}

# -- WezTerm shell integration ----------------------------------------------
# Tells WezTerm where each prompt starts, the current folder, and how long the
# last command took. Pairs with the "WEZTERM-NATIVE EXTRAS" in wezterm.lua:
#   * new tabs / splits open in the folder you're in   (OSC 7)
#   * Shift+Up / Shift+Down jump between prompts        (OSC 133)
#   * triple-click selects one command's whole output   (OSC 133)
#   * notification when a 30s+ command finishes unfocused (cmd_finished var)
# Only active inside WezTerm, and only once (guards against double-sourcing).
if (($env:TERM_PROGRAM -eq 'WezTerm' -or $env:WEZTERM_PANE) -and -not $global:__WezPromptOrig) {
  $global:__WezEsc = [char]27; $global:__WezBel = [char]7
  $global:__WezPromptOrig = $function:prompt
  $global:__WezLastId = -1

  function global:__WezOsc([string]$body) { "$($global:__WezEsc)]$body$($global:__WezBel)" }
  function global:__WezUserVar([string]$name, [string]$value) {
    __WezOsc ("1337;SetUserVar=$name=" + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($value)))
  }

  function global:prompt {
    $ok = $?; $code = $global:LASTEXITCODE
    $out = ''

    # End of the previous command's output, with its exit status.
    $last = Get-History -Count 1
    if ($last -and $last.Id -ne $global:__WezLastId) {
      $global:__WezLastId = $last.Id
      $status = if ($ok) { 0 } elseif ($code) { $code } else { 1 }
      $out += __WezOsc "133;D;$status"
      $secs = ($last.EndExecutionTime - $last.StartExecutionTime).TotalSeconds
      if ($secs -ge 30) {
        $cmd = $last.CommandLine; if ($cmd.Length -gt 60) { $cmd = $cmd.Substring(0, 57) + '...' }
        $verdict = if ($status -eq 0) { 'done' } else { "failed ($status)" }
        $out += __WezUserVar 'cmd_finished' ("{0} - {1} in {2:N0}s" -f $cmd, $verdict, $secs)
      }
    }

    # Current folder (real filesystem paths only).
    if ($PWD.Provider.Name -eq 'FileSystem') {
      $out += __WezOsc ('7;file://' + [Environment]::MachineName + '/' + $PWD.ProviderPath.Replace('\', '/'))
    }

    $global:LASTEXITCODE = $code
    # Re-create a failed $? so starship still shows the red error status.
    if (-not $ok) { Write-Error 'x' -ErrorAction SilentlyContinue }
    $body = & $global:__WezPromptOrig
    # A = prompt starts, B = prompt ends / user input starts.
    $out + (__WezOsc '133;A') + $body + (__WezOsc '133;B')
  }

  # C = command output starts: emitted right after Enter, wrapping whatever
  # PSConsoleHostReadLine is current (atuin's, if it loaded).
  $global:__WezReadLineOrig = $function:PSConsoleHostReadLine
  if ($global:__WezReadLineOrig) {
    function global:PSConsoleHostReadLine {
      $line = & $global:__WezReadLineOrig
      [Console]::Write((__WezOsc '133;C'))
      $line
    }
  }
}
