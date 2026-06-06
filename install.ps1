# install.ps1 :: Windows-side bootstrap for the Loki terminal setup.
#
# Windows is NATIVE by default:
#   * WezTerm runs natively and opens native PowerShell (claude/git/yazi/eza/...)
#   * this script installs the WezTerm config + Nerd Font + the CLI tools (winget)
#     and wires a PowerShell $PROFILE that loads loki-shell.ps1 (prompt + aliases)
#   * zellij has no native Windows build - it's the one piece that stays in WSL,
#     reachable on demand via WezTerm's LEADER-z (or `zd`/`za` from PowerShell)
#
# Want the old "boot the whole terminal into WSL" behaviour instead? Pass -WithWsl
# here AND set WIN_USE_WSL = true near the top of wezterm/wezterm.lua.
#
# Run from PowerShell:
#   irm https://raw.githubusercontent.com/LexingtonStanley/wezterm-zellij-yazi-LEX/master/install.ps1 | iex
#   (or, if you already cloned:  powershell -ExecutionPolicy Bypass -File ~\.loki-term\install.ps1)
#
# Flags:  -SkipFont    skip the Nerd Font install
#         -SkipTools   don't winget-install the CLI tools (config + font only)
#         -WithWsl     also set up the Linux stack inside WSL (for zellij etc.)
[CmdletBinding()]
param(
  [switch]$SkipFont,
  [switch]$SkipTools,
  [switch]$WithWsl
)
$ErrorActionPreference = "Stop"
$RepoHttps = "https://github.com/LexingtonStanley/wezterm-zellij-yazi-LEX.git"
$RawBase   = "https://raw.githubusercontent.com/LexingtonStanley/wezterm-zellij-yazi-LEX/master"
$RepoDir   = Join-Path $env:USERPROFILE ".loki-term"

function Cyan($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m)  { Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  [!] $m" -ForegroundColor Yellow }
function Have($n){ [bool](Get-Command $n -ErrorAction SilentlyContinue) }

Cyan "==> Loki terminal :: Windows setup (native)"

# -- 1. Get the repo (for wezterm.lua/loki-shell.ps1 + future `git pull`) --
$haveGit = Have git
if ($haveGit) {
  if (Test-Path (Join-Path $RepoDir ".git")) {
    Cyan "Updating existing clone at $RepoDir"
    git -C $RepoDir pull --ff-only | Out-Null
  } else {
    Cyan "Cloning repo to $RepoDir"
    git clone $RepoHttps $RepoDir | Out-Null
  }
  Ok "repo ready at $RepoDir"
} else {
  Warn "git not found - fetching just the files we need (install Git for full sync)"
  New-Item -ItemType Directory -Force -Path (Join-Path $RepoDir "wezterm") | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $RepoDir "shell")   | Out-Null
  Invoke-WebRequest "$RawBase/wezterm/wezterm.lua"   -OutFile (Join-Path $RepoDir "wezterm\wezterm.lua")
  Invoke-WebRequest "$RawBase/shell/loki-shell.ps1"  -OutFile (Join-Path $RepoDir "shell\loki-shell.ps1")
}

# -- 2. Install the WezTerm config (~/.wezterm.lua, i.e. %USERPROFILE%) ----
$src = Join-Path $RepoDir "wezterm\wezterm.lua"
$dst = Join-Path $env:USERPROFILE ".wezterm.lua"
if (Test-Path $dst) {
  $bak = "$dst.pre-loki.$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
  Move-Item $dst $bak -Force
  Warn "backed up existing .wezterm.lua -> $bak"
}
Copy-Item $src $dst -Force
Ok "installed $dst (opens native PowerShell)"

# Tidy: a stale ~/.config/wezterm/wezterm.lua would shadow nothing (~/.wezterm.lua
# wins) but causes confusion - point it out if present.
$alt = Join-Path $env:USERPROFILE ".config\wezterm\wezterm.lua"
if (Test-Path $alt) { Warn "note: a second config exists at $alt (it is ignored; ~/.wezterm.lua wins)" }

# -- 3. JetBrainsMono Nerd Font (per-user, no admin needed) ---------------
if (-not $SkipFont) {
  $fontInstalled = (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts","$env:WINDIR\Fonts" -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like "JetBrainsMono*NerdFont*" } | Select-Object -First 1)
  if ($fontInstalled) {
    Ok "JetBrainsMono Nerd Font already present"
  } else {
    Cyan "Installing JetBrainsMono Nerd Font (per-user)"
    $tmp = Join-Path $env:TEMP "JBMNerd"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $zip = Join-Path $tmp "JetBrainsMono.zip"
    Invoke-WebRequest "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -OutFile $zip
    Expand-Archive $zip -DestinationPath $tmp -Force
    $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
    $reg = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    Get-ChildItem $tmp -Filter "*.ttf" -Recurse | ForEach-Object {
      $dest = Join-Path $fontDir $_.Name
      Copy-Item $_.FullName $dest -Force
      $title = [System.IO.Path]::GetFileNameWithoutExtension($_.Name) + " (TrueType)"
      New-ItemProperty -Path $reg -Name $title -Value $dest -PropertyType String -Force | Out-Null
    }
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    Ok "font installed (you may need to restart WezTerm to see it)"
  }
}

# -- 4. Native CLI tools via winget (best-effort; skips whatever you have) --
if (-not $SkipTools) {
  if (-not (Have winget)) {
    Warn "winget not found - skipping tools. Install 'App Installer' from the Store, then re-run."
  } else {
    Cyan "Installing native CLI tools via winget (already-installed ones are skipped)..."
    # command-name -> winget id. starship/zoxide drive the prompt + `z`; the rest
    # back the loki-shell.ps1 aliases (ll/la/lt/catp/lg/y).
    $tools = [ordered]@{
      starship  = "Starship.Starship"
      zoxide    = "ajeetdsouza.zoxide"
      eza       = "eza-community.eza"
      bat       = "sharkdp.bat"
      fzf       = "junegunn.fzf"
      fd        = "sharkdp.fd"
      rg        = "BurntSushi.ripgrep.MSVC"
      yazi      = "sxyazi.yazi"
      lazygit   = "JesseDuffield.lazygit"
      delta     = "dandavison.delta"
      fastfetch = "Fastfetch-cli.Fastfetch"
    }
    foreach ($cmd in $tools.Keys) {
      if (Have $cmd) { Ok "$cmd already installed"; continue }
      $id = $tools[$cmd]
      Cyan "  installing $cmd ($id)"
      try {
        winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements -h | Out-Null
        Ok "$cmd installed"
      } catch { Warn "could not install $cmd ($id) - install it manually later" }
    }
    # PSFzf gives Ctrl-t / Ctrl-r fuzzy bindings in PowerShell (optional).
    if (-not (Get-Module -ListAvailable -Name PSFzf)) {
      try { Install-Module PSFzf -Scope CurrentUser -Force -ErrorAction Stop; Ok "PSFzf module installed" }
      catch { Warn "PSFzf module skipped (optional)" }
    }
    if (-not (Have claude)) {
      Warn "claude (Claude Code) not on PATH - install it with:  irm https://claude.ai/install.ps1 | iex"
    } else { Ok "claude already installed" }
  }
}

# -- 5. Wire loki-shell.ps1 into the PowerShell profile (prompt + aliases) --
# Windows PowerShell 5.1 and PowerShell 7 (pwsh) keep SEPARATE profile files.
# WezTerm prefers pwsh, so wire BOTH AllHosts profiles - otherwise running this
# from one edition silently leaves the other (often the one WezTerm opens)
# without the prompt/aliases/autosuggestions. The pwsh path is derived from the
# Documents folder so it's correct even when this runs under 5.1.
$lokiLine = ". `"$RepoDir\shell\loki-shell.ps1`""
$marker   = "loki-shell.ps1"
$docs     = [Environment]::GetFolderPath('MyDocuments')
$profiles = @(
  $PROFILE.CurrentUserAllHosts                       # the edition running this script
  Join-Path $docs 'WindowsPowerShell\profile.ps1'    # Windows PowerShell 5.1
  Join-Path $docs 'PowerShell\profile.ps1'           # PowerShell 7 (pwsh)
) | Select-Object -Unique
foreach ($profilePath in $profiles) {
  $profileDir = Split-Path $profilePath -Parent
  New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
  $already = (Test-Path $profilePath) -and (Select-String -Path $profilePath -SimpleMatch $marker -Quiet)
  if ($already) {
    Ok "PowerShell profile already sources loki-shell.ps1: $profilePath"
  } else {
    Add-Content -Path $profilePath -Value "`n# Loki terminal (added by install.ps1)`n$lokiLine`n"
    Ok "hooked loki-shell.ps1 into $profilePath"
  }
}

# -- 6. Optional: the WSL Linux stack (only with -WithWsl) -----------------
if ($WithWsl) {
  if (-not (Have wsl.exe)) {
    Warn "WSL not found. Install it (admin PowerShell):  wsl --install   then re-run with -WithWsl"
  } else {
    Cyan "Setting up the Linux stack inside WSL (zellij/yazi/shell)..."
    Warn "WSL's install.sh may ask for your sudo password - that's expected."
    # LF-safe: clone with autocrlf disabled and strip stray CRs so the shebang
    # can't become `bash\r`, then run install.sh.
    $wslCmd = @'
set -e
REPO="$HOME/.loki-term"
URL="https://github.com/LexingtonStanley/wezterm-zellij-yazi-LEX.git"
if [ -d "$REPO/.git" ]; then
  git -C "$REPO" config core.autocrlf false
  git -C "$REPO" config core.eol lf
  git -C "$REPO" fetch -q origin || true
  git -C "$REPO" reset --hard origin/master 2>/dev/null || git -C "$REPO" pull --ff-only || true
else
  git clone -c core.autocrlf=false -c core.eol=lf "$URL" "$REPO"
fi
( cd "$REPO" && git ls-files | grep -v '\.ps1$' | xargs sed -i 's/\r$//' && git add --renormalize . ) || true
bash "$REPO/install.sh"
'@
    wsl.exe -e bash -lc $wslCmd
    Ok "WSL side complete"
  }
}

Cyan "==> Done. Launch WezTerm - it opens native PowerShell in your project dir."
Cyan "    claude, git, yazi, ll/la/lt all work natively. zellij: press LEADER-z (Ctrl-a z) for a WSL session."
Cyan "    Cheatsheet: $RepoDir\cheatsheet.html"
