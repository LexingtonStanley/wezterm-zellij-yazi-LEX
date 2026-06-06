# install.ps1 :: Windows-side bootstrap for the Loki terminal setup.
#
# On Windows the split is:
#   • WezTerm runs natively  -> this script installs its config + the font
#   • everything else (zellij, yazi, shell, ~/.loki-term) runs inside WSL,
#     where the normal Linux install.sh does the work.
# The wezterm.lua is OS-aware: it detects Windows and boots straight into WSL.
#
# Run from PowerShell:
#   irm https://raw.githubusercontent.com/LexingtonStanley/wezterm-zellij-yazi-LEX/master/install.ps1 | iex
#   (or, if you already cloned:  powershell -ExecutionPolicy Bypass -File ~\.loki-term\install.ps1)
#
# Flags:  -SkipFont   skip the Nerd Font install
#         -SkipWsl    don't touch WSL (only do the Windows-native bits)
[CmdletBinding()]
param(
  [switch]$SkipFont,
  [switch]$SkipWsl
)
$ErrorActionPreference = "Stop"
$RepoHttps = "https://github.com/LexingtonStanley/wezterm-zellij-yazi-LEX.git"
$RawBase   = "https://raw.githubusercontent.com/LexingtonStanley/wezterm-zellij-yazi-LEX/master"
$RepoDir   = Join-Path $env:USERPROFILE ".loki-term"

function Cyan($m){ Write-Host $m -ForegroundColor Cyan }
function Ok($m)  { Write-Host "  [ok] $m" -ForegroundColor Green }
function Warn($m){ Write-Host "  [!] $m" -ForegroundColor Yellow }

Cyan "==> Loki terminal :: Windows setup"

# ── 1. Get the repo (for wezterm.lua + future `git pull`) ────────────────
$haveGit = [bool](Get-Command git -ErrorAction SilentlyContinue)
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
  Warn "git not found on Windows — fetching just wezterm.lua (install Git for full sync)"
  New-Item -ItemType Directory -Force -Path (Join-Path $RepoDir "wezterm") | Out-Null
  Invoke-WebRequest "$RawBase/wezterm/wezterm.lua" -OutFile (Join-Path $RepoDir "wezterm\wezterm.lua")
}

# ── 2. Install the WezTerm config (~/.wezterm.lua, i.e. %USERPROFILE%) ────
$src = Join-Path $RepoDir "wezterm\wezterm.lua"
$dst = Join-Path $env:USERPROFILE ".wezterm.lua"
if (Test-Path $dst) {
  $bak = "$dst.pre-loki.$((Get-Date).ToString('yyyyMMdd-HHmmss'))"
  Move-Item $dst $bak -Force
  Warn "backed up existing .wezterm.lua -> $bak"
}
Copy-Item $src $dst -Force
Ok "installed $dst (it auto-detects Windows and boots WSL)"

# ── 3. JetBrainsMono Nerd Font (per-user, no admin needed) ───────────────
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

# ── 4. WSL side: clone repo + run the Linux install.sh ───────────────────
if (-not $SkipWsl) {
  $haveWsl = [bool](Get-Command wsl.exe -ErrorAction SilentlyContinue)
  if (-not $haveWsl) {
    Warn "WSL not found. Install it (admin PowerShell):  wsl --install"
    Warn "Then re-run this script to finish the Linux side."
  } else {
    Cyan "Setting up the Linux stack inside WSL (zellij/yazi/shell)…"
    Warn "WSL's install.sh may ask for your sudo password — that's expected."
    # LF-safe: clone with autocrlf disabled, and defensively strip any stray
    # CRs so install.sh's `#!/usr/bin/env bash` shebang can't become `bash\r`
    # (the bug that broke the first Windows install). Then run install.sh.
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
# reset --hard won't rewrite files git considers "clean" after EOL normalization,
# so force-strip CRs on disk (skip .ps1), then re-sync the index.
( cd "$REPO" && git ls-files | grep -v '\.ps1$' | xargs sed -i 's/\r$//' && git add --renormalize . ) || true
bash "$REPO/install.sh"
'@
    # -lc (login) so PATH/sudo TTY work; run on the console so sudo can prompt.
    wsl.exe -e bash -lc $wslCmd
    Ok "WSL side complete"
  }
}

Cyan "==> Done. Launch WezTerm — it will open straight into WSL."
Cyan "    Inside WSL:  zd  (zellij dev layout)   |   cheatsheet: ~/.loki-term/cheatsheet.html"
