# star-wars-terminal: Jedi prompt for PowerShell (Windows PowerShell 5.1 and PowerShell 7 on any OS).
# Loaded from your PowerShell profile by the installer.

$SwtHome = if ($env:SWT_HOME) { $env:SWT_HOME } else { Join-Path (Join-Path $HOME '.config') 'star-wars-terminal' }

# Lightsaber color. Red is kept for failed commands, so it isn't offered here.
$SaberColors = [ordered]@{ blue = 0x89B4FA; green = 0xA6E3A1; purple = 0xCBA6F7; yellow = 0xF9E2AF; white = 0xEFF1F5 }
$SaberFile = Join-Path $SwtHome 'saber.txt'
if (Test-Path $SaberFile) {
    $saved = "$(Get-Content $SaberFile -TotalCount 1)".Trim()
    if ($SaberColors.Contains($saved)) { $env:JEDI_SABER = $saved }
}

# Usage: saber green   (no argument shows the current color and the options)
function saber {
    param([ValidateSet('blue', 'green', 'purple', 'yellow', 'white')][string] $Color)
    if (-not $Color) {
        $current = if ($env:JEDI_SABER) { $env:JEDI_SABER } else { 'blue' }
        "Current saber: $current. Options: $($SaberColors.Keys -join ', ')"
        return
    }
    $env:JEDI_SABER = $Color.ToLower()
    Set-Content -Path $SaberFile -Value $env:JEDI_SABER
}

# Prompt
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $swtShell = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
    oh-my-posh init $swtShell --config (Join-Path $SwtHome 'jedi.omp.json') | Invoke-Expression
}

# A line from the Jedi Archives for each new session
$swtQuotes = Join-Path (Join-Path $SwtHome 'shell') 'quotes.txt'
if (Test-Path $swtQuotes) {
    $text, $by = (Get-Content $swtQuotes | Where-Object { $_ -match '\|' } | Get-Random) -split '\|', 2
    $ink = { param([int] $Hex) "$([char]27)[38;2;$(($Hex -shr 16) -band 255);$(($Hex -shr 8) -band 255);$($Hex -band 255)m" }
    $crest = if ($env:JEDI_SABER) { $SaberColors[$env:JEDI_SABER] } else { $SaberColors.blue }
    $reset = "$([char]27)[0m"
    Write-Host "$(& $ink $crest)$([char]0xEDD8)$reset $(& $ink 0xA6ADC8)$text$reset $(& $ink 0x6C7086)- $by$reset"
}
