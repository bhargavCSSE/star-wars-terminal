<#
star-wars-terminal installer for Windows.

  Install:    irm https://raw.githubusercontent.com/bhargavCSSE/star-wars-terminal/main/install.ps1 | iex
  Uninstall:  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/bhargavCSSE/star-wars-terminal/main/install.ps1))) -Uninstall
  From a clone:  .\install.ps1  [-Uninstall] [-SkipDependencies] [-WithClink]

What it does:
  - installs Oh My Posh and JetBrainsMono Nerd Font (winget, with fallbacks)
  - copies the theme to ~\.config\star-wars-terminal
  - hooks the prompt into Windows PowerShell and PowerShell 7 (every host, including VS Code)
  - themes Windows Terminal (Catppuccin Mocha, Nerd Font, starfield background) and the VS Code terminal
  - themes Command Prompt too when Clink is installed (or with -WithClink)
Every settings file it edits is backed up first. Running it again is safe.
#>
param([switch] $Uninstall, [switch] $SkipDependencies, [switch] $WithClink)

$SwtRepo = if ($env:SWT_REPO) { $env:SWT_REPO } else { 'bhargavCSSE/star-wars-terminal' }
$SwtBranch = if ($env:SWT_BRANCH) { $env:SWT_BRANCH } else { 'main' }
$SwtHome = if ($env:SWT_HOME) { $env:SWT_HOME } else { Join-Path $HOME '.config\star-wars-terminal' }
$SwtBegin = '# >>> star-wars-terminal >>>'
$SwtEnd = '# <<< star-wars-terminal <<<'
$SwtStamp = Get-Date -Format 'yyyyMMdd-HHmmss'

function Write-SwtStep([string] $Text) { Write-Host "$([char]0x2726) $Text" -ForegroundColor Cyan }
function Write-SwtOk([string] $Text) { Write-Host "  $Text" -ForegroundColor Green }
function Write-SwtNote([string] $Text) { Write-Host "  $Text" -ForegroundColor DarkGray }
function Write-SwtWarn([string] $Text) { Write-Host "  $Text" -ForegroundColor Yellow }

# ---------------------------------------------------------------- source files

function Get-SwtSource {
    if ($env:SWT_SOURCE -and (Test-Path (Join-Path $env:SWT_SOURCE 'theme\jedi.omp.json'))) { return $env:SWT_SOURCE }
    if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'theme\jedi.omp.json'))) { return $PSScriptRoot }
    $zip = Join-Path ([IO.Path]::GetTempPath()) "star-wars-terminal-$SwtStamp.zip"
    $dir = Join-Path ([IO.Path]::GetTempPath()) "star-wars-terminal-$SwtStamp"
    $url = "https://github.com/$SwtRepo/archive/refs/heads/$SwtBranch.zip"
    Write-SwtNote "Downloading $url"
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -ErrorAction Stop
    Expand-Archive -Path $zip -DestinationPath $dir -Force
    Remove-Item $zip -Force
    return (Get-ChildItem $dir -Directory | Select-Object -First 1).FullName
}

# ---------------------------------------------------------------- JSON helpers

# Reads JSON that may contain // or /* */ comments and trailing commas (Windows Terminal, VS Code).
function ConvertFrom-SwtJsonc([string] $Text) {
    $sb = New-Object System.Text.StringBuilder
    $inString = $false; $escaped = $false; $i = 0
    while ($i -lt $Text.Length) {
        $c = $Text[$i]
        if ($inString) {
            [void]$sb.Append($c)
            if ($escaped) { $escaped = $false } elseif ($c -eq [char]'\') { $escaped = $true } elseif ($c -eq [char]'"') { $inString = $false }
            $i++; continue
        }
        if ($c -eq [char]'"') { $inString = $true; [void]$sb.Append($c); $i++; continue }
        if ($c -eq [char]'/' -and $i + 1 -lt $Text.Length -and $Text[$i + 1] -eq [char]'/') {
            while ($i -lt $Text.Length -and $Text[$i] -ne [char]"`n") { $i++ }
            continue
        }
        if ($c -eq [char]'/' -and $i + 1 -lt $Text.Length -and $Text[$i + 1] -eq [char]'*') {
            $i += 2
            while ($i + 1 -lt $Text.Length -and -not ($Text[$i] -eq [char]'*' -and $Text[$i + 1] -eq [char]'/')) { $i++ }
            $i += 2; continue
        }
        [void]$sb.Append($c); $i++
    }
    $clean = [regex]::Replace($sb.ToString(), ',(\s*[}\]])', '$1')
    if (-not $clean.Trim()) { $clean = '{}' }
    return ($clean | ConvertFrom-Json)
}

function Set-SwtProperty($Object, [string] $Name, $Value) {
    if ($Object.PSObject.Properties[$Name]) { $Object.$Name = $Value }
    else { $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Save-SwtJson($Object, [string] $Path) {
    $json = $Object | ConvertTo-Json -Depth 64
    [IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Backup-SwtFile([string] $Path) {
    $backup = "$Path.swt-backup-$SwtStamp"
    Copy-Item $Path $backup -Force
    return $backup
}

# ---------------------------------------------------------------- profile blocks

function Add-SwtBlock([string] $Path, [string[]] $Lines) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    $existing = if (Test-Path $Path) { [IO.File]::ReadAllText($Path) } else { '' }
    if ($existing.Contains($SwtBegin)) { return $false }
    $block = (@('', $SwtBegin) + $Lines + @($SwtEnd)) -join "`r`n"
    [IO.File]::WriteAllText($Path, $existing.TrimEnd() + "`r`n" + $block + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    return $true
}

function Remove-SwtBlock([string] $Path) {
    if (-not (Test-Path $Path)) { return $false }
    $text = [IO.File]::ReadAllText($Path)
    $pattern = '(\r?\n)?' + [regex]::Escape($SwtBegin) + '[\s\S]*?' + [regex]::Escape($SwtEnd) + '\r?\n?'
    $new = [regex]::Replace($text, $pattern, '')
    if ($new -eq $text) { return $false }
    [IO.File]::WriteAllText($Path, $new, (New-Object System.Text.UTF8Encoding($false)))
    return $true
}

function Get-SwtProfilePaths {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    $paths = @(Join-Path $docs 'WindowsPowerShell\profile.ps1')
    if ((Get-Command pwsh -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $docs 'PowerShell'))) { $paths += Join-Path $docs 'PowerShell\profile.ps1' }
    return $paths
}

# ---------------------------------------------------------------- dependencies

function Test-SwtWinget { [bool](Get-Command winget -ErrorAction SilentlyContinue) }

function Install-SwtOhMyPosh {
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) { Write-SwtOk 'Oh My Posh is already installed.'; return }
    if (Test-SwtWinget) {
        winget install --id JanDeDobbeleer.OhMyPosh --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Host
        if ($LASTEXITCODE -eq 0) { Write-SwtOk 'Installed Oh My Posh.'; return }
    }
    Write-SwtNote 'Installing Oh My Posh with its official script.'
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))
}

function Test-SwtFont {
    try {
        Add-Type -AssemblyName System.Drawing
        return [bool]((New-Object System.Drawing.Text.InstalledFontCollection).Families | Where-Object { $_.Name -like 'JetBrainsMono NFM*' -or $_.Name -like 'JetBrainsMono Nerd Font Mono*' })
    } catch { return $false }
}

function Install-SwtFont {
    if (Test-SwtFont) { Write-SwtOk 'JetBrainsMono Nerd Font is already installed.'; return }
    if (Test-SwtWinget) {
        winget install --id DEVCOM.JetBrainsMonoNerdFont --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Host
        if ($LASTEXITCODE -eq 0) { Write-SwtOk 'Installed JetBrainsMono Nerd Font.'; return }
    }
    # Per-user install without admin rights
    Write-SwtNote 'Installing JetBrainsMono Nerd Font Mono for this user from the Nerd Fonts release.'
    $zip = Join-Path ([IO.Path]::GetTempPath()) "JetBrainsMono-$SwtStamp.zip"
    $dir = Join-Path ([IO.Path]::GetTempPath()) "JetBrainsMono-$SwtStamp"
    Invoke-WebRequest -Uri 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip' -OutFile $zip -UseBasicParsing -ErrorAction Stop
    Expand-Archive $zip -DestinationPath $dir -Force
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Force $fontDir | Out-Null
    foreach ($ttf in Get-ChildItem $dir -Filter 'JetBrainsMonoNerdFontMono-*.ttf') {
        $target = Join-Path $fontDir $ttf.Name
        Copy-Item $ttf.FullName $target -Force
        $name = "$($ttf.BaseName -replace 'JetBrainsMonoNerdFontMono-', 'JetBrainsMono Nerd Font Mono ') (TrueType)"
        New-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts' -Name $name -Value $target -PropertyType String -Force | Out-Null
    }
    Remove-Item $zip, $dir -Recurse -Force
    Write-SwtOk 'Installed JetBrainsMono Nerd Font Mono for this user.'
}

function Install-SwtClink {
    if (Get-SwtClinkProfile) { return }
    if (-not (Test-SwtWinget)) { Write-SwtWarn 'winget is not available; install Clink from https://chrisant996.github.io/clink/ and run this again.'; return }
    winget install --id chrisant996.Clink --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Host
}

# Clink's profile folder, or $null when Clink isn't installed
function Get-SwtClinkProfile {
    $installed = (Get-Command clink -ErrorAction SilentlyContinue) -or (Test-Path "${env:ProgramFiles(x86)}\clink\clink.bat") -or (Test-Path "$env:ProgramFiles\clink\clink.bat")
    if (-not $installed) { return $null }
    foreach ($hive in 'HKCU:', 'HKLM:') {
        $autorun = (Get-ItemProperty "$hive\Software\Microsoft\Command Processor" -ErrorAction SilentlyContinue).AutoRun
        if ($autorun -match '--profile\s+(?:"([^"]+)"|(\S+))') {
            $dir = if ($Matches[1]) { $Matches[1] } else { $Matches[2] }
            return ($dir -replace '^~', $HOME)
        }
    }
    return (Join-Path $env:LOCALAPPDATA 'clink')
}

# ---------------------------------------------------------------- steps

function Copy-SwtFiles([string] $Source) {
    New-Item -ItemType Directory -Force $SwtHome | Out-Null
    Copy-Item (Join-Path $Source 'theme\jedi.omp.json') (Join-Path $SwtHome 'jedi.omp.json') -Force
    Copy-Item (Join-Path $Source 'assets\starfield.png') (Join-Path $SwtHome 'starfield.png') -Force
    foreach ($folder in 'shell', 'terminals') {
        $target = Join-Path $SwtHome $folder
        New-Item -ItemType Directory -Force $target | Out-Null
        Copy-Item (Join-Path $Source "$folder\*") $target -Recurse -Force
    }
    Get-ChildItem $SwtHome -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
    Write-SwtOk "Copied the theme to $SwtHome"
}

function Set-SwtExecutionPolicy {
    $list = Get-ExecutionPolicy -List
    $effective = 'Restricted'
    foreach ($scope in 'MachinePolicy', 'UserPolicy', 'CurrentUser', 'LocalMachine') {
        $value = ($list | Where-Object Scope -eq $scope).ExecutionPolicy
        if ("$value" -ne 'Undefined') { $effective = "$value"; break }
    }
    if ($effective -notin 'Restricted', 'AllSigned') { return }
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
        Write-SwtOk 'Allowed local profile scripts to run (execution policy RemoteSigned for your user).'
    } catch {
        Write-SwtWarn "PowerShell's execution policy ($effective) blocks profile scripts, and it's set by policy. Ask your admin, or the prompt won't load in Windows PowerShell."
    }
}

function Update-SwtPowerShellProfiles {
    $hook = @(
        "`$swtPrompt = '$((Join-Path $SwtHome 'shell\jedi.ps1').Replace("'", "''"))'",
        'if (Test-Path $swtPrompt) { . $swtPrompt }'
    )
    foreach ($path in Get-SwtProfilePaths) {
        if (Add-SwtBlock $path $hook) { Write-SwtOk "Hooked the prompt into $path" } else { Write-SwtNote "Already hooked: $path" }
    }
}

function Update-SwtWindowsTerminal([string[]] $Paths) {
    $scheme = Get-Content (Join-Path $SwtHome 'terminals\windows-terminal-scheme.json') -Raw | ConvertFrom-Json
    $image = Join-Path $SwtHome 'starfield.png'
    $found = $false
    foreach ($path in $Paths) {
        if (-not (Test-Path $path)) { continue }
        $found = $true
        try {
            $settings = ConvertFrom-SwtJsonc ([IO.File]::ReadAllText($path))
            $backup = Backup-SwtFile $path
            $schemes = @($settings.schemes | Where-Object { $_ -and $_.name -ne $scheme.name }) + $scheme
            Set-SwtProperty $settings 'schemes' $schemes
            if (-not $settings.profiles) { Set-SwtProperty $settings 'profiles' ([pscustomobject]@{ defaults = [pscustomobject]@{}; list = @() }) }
            if ($settings.profiles -is [array]) { Set-SwtProperty $settings 'profiles' ([pscustomobject]@{ defaults = [pscustomobject]@{}; list = $settings.profiles }) }
            if (-not $settings.profiles.defaults) { Set-SwtProperty $settings.profiles 'defaults' ([pscustomobject]@{}) }
            $d = $settings.profiles.defaults
            Set-SwtProperty $d 'colorScheme' $scheme.name
            $font = if ($d.font) { $d.font } else { [pscustomobject]@{} }
            Set-SwtProperty $font 'face' 'JetBrainsMono Nerd Font Mono'
            Set-SwtProperty $d 'font' $font
            Set-SwtProperty $d 'backgroundImage' $image
            Set-SwtProperty $d 'backgroundImageAlignment' 'bottomRight'
            Set-SwtProperty $d 'backgroundImageStretchMode' 'uniformToFill'
            Set-SwtProperty $d 'backgroundImageOpacity' 1.0
            Save-SwtJson $settings $path
            Write-SwtOk "Themed Windows Terminal ($path). Backup: $backup"
        } catch {
            Write-SwtWarn "Couldn't update $path ($($_.Exception.Message)). Your file is unchanged."
        }
    }
    if (-not $found) { Write-SwtNote 'Windows Terminal settings not found. Open Windows Terminal once, then run this again to theme it.' }
}

function Get-SwtWindowsTerminalPaths {
    @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
}

function Update-SwtVSCode([string[]] $Paths) {
    $ours = Get-Content (Join-Path $SwtHome 'terminals\vscode-settings.json') -Raw | ConvertFrom-Json
    foreach ($path in $Paths) {
        if (-not (Test-Path (Split-Path $path -Parent))) { continue }
        try {
            $settings = if (Test-Path $path) { ConvertFrom-SwtJsonc ([IO.File]::ReadAllText($path)) } else { [pscustomobject]@{} }
            $backup = if (Test-Path $path) { Backup-SwtFile $path } else { $null }
            foreach ($prop in $ours.PSObject.Properties) {
                if ($prop.Name -eq 'workbench.colorCustomizations') {
                    $colors = if ($settings.'workbench.colorCustomizations') { $settings.'workbench.colorCustomizations' } else { [pscustomobject]@{} }
                    foreach ($c in $prop.Value.PSObject.Properties) { Set-SwtProperty $colors $c.Name $c.Value }
                    Set-SwtProperty $settings 'workbench.colorCustomizations' $colors
                } else { Set-SwtProperty $settings $prop.Name $prop.Value }
            }
            Save-SwtJson $settings $path
            if ($backup) { Write-SwtOk "Themed the VS Code terminal ($path). Backup: $backup" } else { Write-SwtOk "Themed the VS Code terminal ($path)." }
        } catch {
            Write-SwtWarn "Couldn't update $path ($($_.Exception.Message)). Your file is unchanged."
        }
    }
}

function Get-SwtVSCodePaths {
    foreach ($app in 'Code', 'Code - Insiders', 'Cursor', 'VSCodium') { Join-Path $env:APPDATA "$app\User\settings.json" }
}

function Update-SwtClink {
    $profileDir = Get-SwtClinkProfile
    if (-not $profileDir) { Write-SwtNote 'Command Prompt: install Clink (or run with -WithClink) to get the prompt there too.'; return }
    New-Item -ItemType Directory -Force $profileDir | Out-Null
    Copy-Item (Join-Path $SwtHome 'shell\jedi.lua') (Join-Path $profileDir 'star-wars-terminal.lua') -Force
    Write-SwtOk "Hooked the prompt into Command Prompt via Clink ($profileDir)"
}

# ---------------------------------------------------------------- main

function Install-StarWarsTerminal {
    Write-Host ''
    Write-Host '  A long time ago in a terminal far, far away...' -ForegroundColor Yellow
    Write-Host ''
    try { $source = Get-SwtSource } catch { Write-SwtWarn "Couldn't get the theme files: $($_.Exception.Message)"; return }

    if (-not ($SkipDependencies -or $env:SWT_SKIP_DEPS)) {
        Write-SwtStep 'Installing Oh My Posh and JetBrainsMono Nerd Font'
        try { Install-SwtOhMyPosh } catch { Write-SwtWarn "Oh My Posh: $($_.Exception.Message)" }
        try { Install-SwtFont } catch { Write-SwtWarn "Font: $($_.Exception.Message)" }
        if ($WithClink -or $env:SWT_WITH_CLINK) { try { Install-SwtClink } catch { Write-SwtWarn "Clink: $($_.Exception.Message)" } }
    }

    Write-SwtStep 'Copying the theme'
    Copy-SwtFiles $source

    Write-SwtStep 'Hooking the prompt into your shells'
    Set-SwtExecutionPolicy
    Update-SwtPowerShellProfiles
    Update-SwtClink

    Write-SwtStep 'Theming your terminals'
    Update-SwtWindowsTerminal (Get-SwtWindowsTerminalPaths)
    Update-SwtVSCode (Get-SwtVSCodePaths)

    if ($source -like "$([IO.Path]::GetTempPath())*") { Remove-Item (Split-Path $source -Parent) -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Host ''
    Write-Host '  Done. Open a new terminal window to see your lightsaber.' -ForegroundColor Green
    Write-Host '  Change its color any time:  saber green   (blue, green, purple, yellow, white)' -ForegroundColor Green
    Write-Host '  May the Force be with you.' -ForegroundColor Yellow
    Write-Host ''
}

function Uninstall-StarWarsTerminal {
    Write-SwtStep 'Removing star-wars-terminal'
    foreach ($path in Get-SwtProfilePaths) { if (Remove-SwtBlock $path) { Write-SwtOk "Unhooked $path" } }
    $clink = Get-SwtClinkProfile
    if ($clink -and (Test-Path (Join-Path $clink 'star-wars-terminal.lua'))) { Remove-Item (Join-Path $clink 'star-wars-terminal.lua') -Force; Write-SwtOk 'Unhooked Command Prompt (Clink)' }
    foreach ($path in Get-SwtWindowsTerminalPaths) {
        if (-not (Test-Path $path)) { continue }
        try {
            $settings = ConvertFrom-SwtJsonc ([IO.File]::ReadAllText($path))
            $d = $settings.profiles.defaults
            if ($d -and "$($d.backgroundImage)" -like "$SwtHome*") {
                $backup = Backup-SwtFile $path
                foreach ($name in 'backgroundImage', 'backgroundImageAlignment', 'backgroundImageStretchMode', 'backgroundImageOpacity') { $d.PSObject.Properties.Remove($name) }
                Save-SwtJson $settings $path
                Write-SwtOk "Removed the starfield background from Windows Terminal. Backup: $backup"
            }
        } catch { Write-SwtWarn "Couldn't update $path ($($_.Exception.Message))." }
    }
    if (Test-Path $SwtHome) { Remove-Item $SwtHome -Recurse -Force; Write-SwtOk "Removed $SwtHome" }
    Write-SwtNote 'Kept: Oh My Posh, the Nerd Font, the Catppuccin colors and the VS Code terminal settings.'
    Write-SwtNote 'Earlier versions of each edited settings file are saved next to it as *.swt-backup-*.'
}

if (-not $env:SWT_NO_AUTORUN) {
    if ($Uninstall -or $env:SWT_UNINSTALL) { Uninstall-StarWarsTerminal } else { Install-StarWarsTerminal }
}
