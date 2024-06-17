#!/usr/bin/env -S pwsh -nop
#requires -version 5

# (!) This file must to be saved in UTF-8 with BOM encoding in order to work with legacy Powershell 5.x

<#PSScriptInfo
.VERSION 2.4.1
.GUID a9a07f39-87e7-4164-9395-27cb54d86656
.AUTHOR Kied Llaentenn and contributers
.PROJECTURI https://github.com/kiedtl/winfetch
.COMPANYNAME
.COPYRIGHT
.TAGS neofetch screenfetch system-info commandline
.LICENSEURI https://github.com/kiedtl/winfetch/blob/master/LICENSE
.ICONURI https://lptstr.github.io/lptstr-images/proj/winfetch/logo.png
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
#>

<#
.SYNOPSIS
    Winfetch - Neofetch for Windows in PowerShell 5+
.DESCRIPTION
    Winfetch is a command-line system information utility for Windows written in PowerShell.
.PARAMETER image
    Display a pixelated image instead of the usual logo.
.PARAMETER ascii
    Display the image using ASCII characters instead of blocks.
.PARAMETER genconf
    Reset your configuration file to the default.
.PARAMETER configpath
    Specify a path to a custom config file.
.PARAMETER noimage
    Do not display any image or logo; display information only.
.PARAMETER logo
    Sets the version of Windows to derive the logo from.
.PARAMETER imgwidth
    Specify width for image/logo. Default is 35.
.PARAMETER blink
    Make the logo blink.
.PARAMETER stripansi
    Output without any text effects or colors.
.PARAMETER all
    Display all built-in info segments.
.PARAMETER help
    Display this help message.
.PARAMETER cpustyle
    Specify how to show information level for CPU usage
.PARAMETER memorystyle
    Specify how to show information level for RAM usage
.PARAMETER diskstyle
    Specify how to show information level for disks' usage
.PARAMETER batterystyle
    Specify how to show information level for battery
.PARAMETER showdisks
    Configure which disks are shown, use '-showdisks *' to show all.
.PARAMETER showpkgs
    Configure which package managers are shown, e.g. '-showpkgs winget,scoop,choco'.
.INPUTS
    System.String
.OUTPUTS
    System.String[]
.NOTES
    Run Winfetch without arguments to view core functionality.
#>
[CmdletBinding()]
param(
    [string][alias('i')]$image,
    [switch][alias('k')]$ascii,
    [switch][alias('g')]$genconf,
    [string][alias('c')]$configpath,
    [switch][alias('n')]$noimage,
    [string][alias('l')]$logo,
    [switch][alias('b')]$blink,
    [switch][alias('s')]$stripansi,
    [switch][alias('a')]$all,
    [switch][alias('h')]$help,
    [ValidateSet("text", "bar", "textbar", "bartext")][string]$cpustyle = "text",
    [ValidateSet("text", "bar", "textbar", "bartext")][string]$memorystyle = "text",
    [ValidateSet("text", "bar", "textbar", "bartext")][string]$diskstyle = "text",
    [ValidateSet("text", "bar", "textbar", "bartext")][string]$batterystyle = "text",
    [ValidateScript({$_ -gt 1 -and $_ -lt $Host.UI.RawUI.WindowSize.Width-1})][alias('w')][int]$imgwidth = 35,
    [array]$showdisks = @($env:SystemDrive),
    [array]$showpkgs = @("scoop", "choco")
)

if (-not ($IsWindows -or $PSVersionTable.PSVersion.Major -eq 5)) {
    Write-Error "Only supported on Windows."
    exit 1
}

# ===== DISPLAY HELP =====
if ($help) {
    if (Get-Command -Name less -ErrorAction Ignore) {
        Get-Help ($MyInvocation.MyCommand.Definition) -Full | less
    } else {
        Get-Help ($MyInvocation.MyCommand.Definition) -Full
    }
    exit 0
}


# ===== CONFIG MANAGEMENT =====
$defaultConfig = @'
# ===== WINFETCH CONFIGURATION =====

# $image = "~/winfetch.png"
# $noimage = $true

# Display image using ASCII characters
# $ascii = $true

# Set the version of Windows to derive the logo from.
# $logo = "Visnes"

# Specify width for image/logo
# $imgwidth = 52

# Make the logo blink
$blink = $true

# Display all built-in info segments.
# $all = $true

# Add a custom info line
# function info_custom_time {
#     return @{
#         title = "└─  じかん"
#         content = (Get-Date -Format "dd.MM.yyyy - HH:mm (K)")
#     }
# }

# Configure which disks are shown
# $ShowDisks = @("C:", "D:")
# Show all available disks
# $ShowDisks = @("*")

# Configure which package managers are shown
# disabling unused ones will improve speed
# $ShowPkgs = @("winget", "scoop", "choco")

# Use the following option to specify custom package managers.
# Create a function with that name as suffix, and which returns
# the number of packages. Two examples are shown here:
# $CustomPkgs = @("cargo", "just-install")
# function info_pkg_cargo {
#     return (cargo install --list | Where-Object {$_ -like "*:" }).Length
# }
# function info_pkg_just-install {
#     return (just-install list).Length
# }

# Configure how to show info for levels
# Default is for text only.
# 'bar' is for bar only.
# 'textbar' is for text + bar.
# 'bartext' is for bar + text.
$cpustyle = 'bartext'
$memorystyle = 'bartext'
$diskstyle = 'bartext'
# $batterystyle = 'bartext'

# Remove the '#' from any of the lines in
# the following to **enable** their output.

@(
# TITLE & SUBTITLE
    "title"
    "subtitle"
    "blank"
# OS, KERNEL, PS-PKGS, PWSH, UPTIME, TERMINAL, PKGS, THEME, DATETIME, BATTERY
    "software"
    "os"
    "kernel"
#    "ps_pkgs"  # takes some time
    "pwsh"
    "uptime"
#    "terminal"
#    "pkgs"
#    "theme"
    "datetime"
    "battery"
    "dashes_end"
    "blank"
# COMPUTER, CPU, GPU, MOTHERBOARD, TEMPERATURES, RESOLUTION, CPU_USAGE, MEMORY, DISK
    "hardware"
#    "computer"
    "cpu"
    "gpu"
#    "motherboard"
#   "temperatures" # Not used (yet), don't uncomment!
    "resolution"
#    "cpu_usage"
    "memory"
    "disk"
# LOCALE, LAYOUT, LOCAL_IP, PUBLIC_IP, FAKE_IP, WEATHER
    "dashes_fill"
    "other"
    "locale"
    "layout"
    "local_ip"
#    "public_ip"
    "redacted_ip"
#    "weather"
# END OF VIEW WITH COLORBAR
    "dashes_end"
    "blank"
    "colorbar"
)

'@

if (-not $configPath) {
    if ($env:WINFETCH_CONFIG_PATH) {
        $configPath = $env:WINFETCH_CONFIG_PATH
    } else {
        $configPath = "${env:USERPROFILE}\.config\winfetch\config.ps1"
    }
}

# generate default config
if ($genconf -and (Test-Path $configPath)) {
    $choiceYes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", `
        "overwrite your configuration with the default"
    $choiceNo = New-Object System.Management.Automation.Host.ChoiceDescription "&No", `
        "do nothing and exit"
    $result = $Host.UI.PromptForChoice("Resetting your config to default will overwrite it.",
        "Do you want to continue?", ($choiceYes, $choiceNo), 1)
    if ($result -eq 0) { Remove-Item -Path $configPath } else { exit 1 }
}

if (-not (Test-Path $configPath) -or [String]::IsNullOrWhiteSpace((Get-Content $configPath))) {
    New-Item -Type File -Path $configPath -Value $defaultConfig -Force | Out-Null
    if ($genconf) {
        Write-Host "Saved default config to '$configPath'."
        exit 0
    } else {
        Write-Host "Missing config: Saved default config to '$configPath'."
    }
}

# load config file
$config = . $configPath
if (-not $config -or $all) {
    $config = @(
        "title"
        "subtitle"
        "blank"
        "software"
        "os"
        "kernel"
        "ps_pkgs"
        "pwsh"
        "uptime"
        "terminal"
        "pkgs"
        "theme"
        "datetime"
        "battery"
        "dashes_end"
        "blank"
        "hardware"
        "computer"
        "cpu"
        "gpu"
        "motherboard"
        "resolution"
        "cpu_usage"
        "memory"
        "disk"
        "dashes_fill"
        "other"
        "locale"
        "layout"
        "local_ip"
        "public_ip"
        "redacted_ip"
        "weather"
        "dashes_end"
        "blank"
        "colorbar"
    )
}

# Prevent config from overriding specified parameters
foreach ($param in $PSBoundParameters.Keys) {
    Set-Variable $param $PSBoundParameters[$param]
}

# ===== VARIABLES =====
$e = [char]0x1B
$ansiRegex = '([\u001B\u009B][[\]()#;?]*(?:(?:(?:[a-zA-Z\d]*(?:;[-a-zA-Z\d\/#&.:=?%@~_]*)*)?\u0007)|(?:(?:\d{1,4}(?:;\d{0,4})*)?[\dA-PR-TZcf-ntqry=><~])))'
$cimSession = New-CimSession
$os = Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption,OSArchitecture -CimSession $cimSession
$t = if ($blink) { "5" } else { "1" }
$COLUMNS = $imgwidth

# ===== UTILITY FUNCTIONS =====
function get_percent_bar {
    param ([Parameter(Mandatory)][ValidateRange(0, 100)][int]$percent)

    $x = [char]9632
    $bar = $null

    $bar += "$e[97m[ $e[0m"
    for ($i = 1; $i -le ($barValue = ([math]::round($percent / 10))); $i++) {
        if ($i -le 6) { $bar += "$e[32m$x$e[0m" }
        elseif ($i -le 8) { $bar += "$e[93m$x$e[0m" }
        else { $bar += "$e[91m$x$e[0m" }
    }
    for ($i = 1; $i -le (10 - $barValue); $i++) { $bar += "$e[97m-$e[0m" }
    $bar += "$e[97m ]$e[0m"

    return $bar
}

function get_level_info {
    param (
        [string]$barprefix,
        [string]$style,
        [int]$percentage,
        [string]$text,
        [switch]$altstyle
    )

    switch ($style) {
        'bar' { return "$barprefix$(get_percent_bar $percentage)" }
        'textbar' { return "$text $(get_percent_bar $percentage)" }
        'bartext' { return "$barprefix$(get_percent_bar $percentage) $text" }
        default { if ($altstyle) { return "$percentage% ($text)" } else { return "$text ($percentage%)" }}
    }
}

function truncate_line {
    param (
        [string]$text,
        [int]$maxLength
    )
    $length = ($text -replace $ansiRegex, "").Length
    if ($length -le $maxLength) {
        return $text
    }
    $truncateAmt = $length - $maxLength
    $trucatedOutput = ""
    $parts = $text -split $ansiRegex

    for ($i = $parts.Length - 1; $i -ge 0; $i--) {
        $part = $parts[$i]
        if (-not $part.StartsWith([char]27) -and $truncateAmt -gt 0) {
            $num = if ($truncateAmt -gt $part.Length) {
                $part.Length
            } else {
                $truncateAmt
            }
            $truncateAmt -= $num
            $part = $part.Substring(0, $part.Length - $num)
        }
        $trucatedOutput = "$part$trucatedOutput"
    }

    return $trucatedOutput
}

# ===== IMAGE =====
$img = if (-not $noimage) {
    if ($image) {
        if ($image -eq 'wallpaper') {
            $image = (Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name Wallpaper).Wallpaper
        }

        Add-Type -AssemblyName 'System.Drawing'
        $OldImage = if (Test-Path $image -PathType Leaf) {
            [Drawing.Bitmap]::FromFile((Resolve-Path $image))
        } else {
            [Drawing.Bitmap]::FromStream((Invoke-WebRequest $image -UseBasicParsing).RawContentStream)
        }

        # Divide scaled height by 2.2 to compensate for ASCII characters being taller than they are wide
        [int]$ROWS = $OldImage.Height / $OldImage.Width * $COLUMNS / $(if ($ascii) { 2.2 } else { 1 })
        $Bitmap = New-Object System.Drawing.Bitmap @($OldImage, [Drawing.Size]"$COLUMNS,$ROWS")

        if ($ascii) {
            $chars = ' .,:;+iIH$@'
            for ($i = 0; $i -lt $Bitmap.Height; $i++) {
              $currline = ""
              for ($j = 0; $j -lt $Bitmap.Width; $j++) {
                $p = $Bitmap.GetPixel($j, $i)
                $currline += "$e[38;2;$($p.R);$($p.G);$($p.B)m$($chars[[math]::Floor($p.GetBrightness() * $chars.Length)])$e[0m"
              }
              $currline
            }
        } else {
            for ($i = 0; $i -lt $Bitmap.Height; $i += 2) {
                $currline = ""
                for ($j = 0; $j -lt $Bitmap.Width; $j++) {
                    $back = $Bitmap.GetPixel($j, $i)
                    if ($i -ge $Bitmap.Height - 1) {
                        $foreVT = ""
                    } else {
                        $fore = $Bitmap.GetPixel($j, $i + 1)
                        $foreVT = "$e[48;2;$($fore.R);$($fore.G);$($fore.B)m"
                    }
                    $backVT = "$e[38;2;$($back.R);$($back.G);$($back.B)m"
                    $currline += "$backVT$foreVT$([char]0x2580)$e[0m"
                }
                $currline
            }
        }

        $Bitmap.Dispose()
        $OldImage.Dispose()

    } else {
        if (-not $logo) {
            if ($os -Like "*Windows 11 *") {
                $logo = "Windows 11"
            } elseif ($os -Like "*Windows 10 *" -Or $os -Like "*Windows 8.1 *" -Or $os -Like "*Windows 8 *") {
                $logo = "Windows 10"
            } else {
                $logo = "Windows 7"
            }
        }

        if ($logo -eq "Windows 11") {
            $COLUMNS = 32
            @(
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
                "${e}[${t};34m                                 "
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
                "${e}[${t};34mlllllllllllllll   lllllllllllllll"
            )
        } elseif ($logo -eq "Windows 10" -Or $logo -eq "Windows 8.1" -Or $logo -eq "Windows 8") {
            $COLUMNS = 34
            @(
                "${e}[${t};34m                    ....,,:;+ccllll"
                "${e}[${t};34m      ...,,+:;  cllllllllllllllllll"
                "${e}[${t};34m,cclllllllllll  lllllllllllllllllll"
                "${e}[${t};34mllllllllllllll  lllllllllllllllllll"
                "${e}[${t};34mllllllllllllll  lllllllllllllllllll"
                "${e}[${t};34mllllllllllllll  lllllllllllllllllll"
                "${e}[${t};34mllllllllllllll  lllllllllllllllllll"
                "${e}[${t};34mllllllllllllll  lllllllllllllllllll"
                "${e}[${t};34m                                   "
                "${e}[${t};34mllllllllllllll  lllllllllllllllllll"
                "${e}[${t};34mllllllllllllll  lllllllllllllllllll"
                "${e}[${t};34mllllllllllllll  lllllllllllllllllll"
                "${e}[${t};34mllllllllllllll  lllllllllllllllllll"
                "${e}[${t};34mllllllllllllll  lllllllllllllllllll"
                "${e}[${t};34m``'ccllllllllll  lllllllllllllllllll"
                "${e}[${t};34m      ``' \\*::  :ccllllllllllllllll"
                "${e}[${t};34m                       ````````''*::cll"
                "${e}[${t};34m                                 ````"
            )
        } elseif ($logo -eq "Windows 7" -Or $logo -eq "Windows Vista" -Or $logo -eq "Windows XP") {
            $COLUMNS = 35
            @(
                "${e}[${t};31m        ,.=:!!t3Z3z.,               "
                "${e}[${t};31m       :tt:::tt333EE3               "
                "${e}[${t};31m       Et:::ztt33EEE  ${e}[32m@Ee.,      ..,"
                "${e}[${t};31m      ;tt:::tt333EE7 ${e}[32m;EEEEEEttttt33#"
                "${e}[${t};31m     :Et:::zt333EEQ. ${e}[32mSEEEEEttttt33QL"
                "${e}[${t};31m     it::::tt333EEF ${e}[32m@EEEEEEttttt33F "
                "${e}[${t};31m    ;3=*^``````'*4EEV ${e}[32m:EEEEEEttttt33@. "
                "${e}[${t};34m    ,.=::::it=., ${e}[31m`` ${e}[32m@EEEEEEtttz33QF  "
                "${e}[${t};34m   ;::::::::zt33)   ${e}[32m'4EEEtttji3P*   "
                "${e}[${t};34m  :t::::::::tt33 ${e}[33m:Z3z..  ${e}[32m```` ${e}[33m,..g.   "
                "${e}[${t};34m  i::::::::zt33F ${e}[33mAEEEtttt::::ztF    "
                "${e}[${t};34m ;:::::::::t33V ${e}[33m;EEEttttt::::t3     "
                "${e}[${t};34m E::::::::zt33L ${e}[33m@EEEtttt::::z3F     "
                "${e}[${t};34m{3=*^``````'*4E3) ${e}[33m;EEEtttt:::::tZ``     "
                "${e}[${t};34m            `` ${e}[33m:EEEEtttt::::z7       "
                "${e}[${t};33m                'VEzjt:;;z>*``       "
            )
        } elseif ($logo -eq "Visnes") {
            $COLUMNS = 54
            @(
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀[38;5;169m((#((⠀⠀⠀⠀))#))⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀[38;5;169m(#########(#####([38;5;168m(((((.⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀##*#[38;5;170m####[38;5;169m####[38;5;169m#######(([38;5;168m((⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀%###/######[38;5;169m####[38;5;169m#####[38;5;168m#⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀*#⠀⠀⠀⠀⠀⠀⠀⠀%[38;5;170m%###[38;5;170m####[38;5;170m#####[38;5;169m####[38;5;169m#⠀⠀⠀⠀⠀⠀⠀⠀[38;5;168m((⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀,####⠀⠀⠀⠀⠀⠀⠀⠀%%%%####[38;5;170m#########⠀⠀⠀⠀⠀⠀⠀⠀((((⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀###(###⠀⠀⠀⠀⠀⠀⠀⠀##[38;5;135m%%%######[38;5;170m####,⠀⠀⠀⠀⠀⠀⠀#[38;5;168m(((([38;5;168m(,⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀[38;5;074m####[38;5;069m##.#⠀⠀⠀⠀⠀⠀⠀⠀#[38;5;141m##%%%####[38;5;170m###,⠀⠀⠀⠀⠀⠀⠀####/([38;5;168m((⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀#####[38;5;074m####[38;5;104m#⠀⠀⠀⠀⠀⠀⠀⠀####[38;5;141m#%%%[38;5;170m####⠀⠀⠀⠀⠀⠀⠀##[38;5;169m####[38;5;168m##*(⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀[38;5;074m##⠀#[38;5;074m####[38;5;068m###⠀⠀⠀⠀⠀⠀⠀⠀##[38;5;140m#[38;5;140m###%[38;5;135m%%%⠀⠀⠀⠀⠀⠀⠀#([38;5;169m#[38;5;169m####[38;5;169m####⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀((######[38;5;074m####⠀⠀⠀⠀⠀⠀⠀⠀#[38;5;104m####[38;5;140m###⠀⠀⠀⠀⠀⠀⠀###[38;5;170m##*####,#⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀((([38;5;074m(########[38;5;074m#⠀⠀⠀⠀⠀⠀⠀⠀######⠀⠀⠀⠀⠀⠀⠀####[38;5;170m####[38;5;169m#####⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀(((((#[38;5;074m#######⠀⠀⠀⠀⠀⠀⠀,##[38;5;104m##⠀⠀⠀⠀⠀⠀⠀[38;5;135m%%*####*#####⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀*[38;5;038m((((([38;5;038m((##[38;5;074m####⠀⠀⠀⠀⠀⠀⠀⠀##⠀⠀⠀⠀⠀⠀.#[38;5;141m##%%[38;5;170m%###[38;5;170m####.⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀(((((((([38;5;074m(###[38;5;074m#⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀.####(##%%%[38;5;170m###⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀/([38;5;038m(((((((####⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀/##[38;5;104m####[38;5;140m####%%⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀⠀⠀(((([38;5;038m(((([38;5;038m((##,⠀⠀⠀⠀⠀⠀⠀⠀⠀##(#####[38;5;104m####(⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀((((([38;5;038m(((([38;5;074m(,⠀⠀⠀⠀⠀⠀⠀####[38;5;104m#######⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀((*((((,⠀⠀⠀⠀⠀#####[38;5;068m###⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀*((((,⠀⠀⠀#####[38;5;068m⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
                "${e}[${t};38;5;169m⠀"
            )
        } elseif ($logo -eq "Microsoft") {
            $COLUMNS = 13
            @(
                "${e}[${t};31m┌─────┐${e}[32m┌─────┐"
                "${e}[${t};31m│     │${e}[32m│     │"
                "${e}[${t};31m│     │${e}[32m│     │"
                "${e}[${t};31m└─────┘${e}[32m└─────┘"
                "${e}[${t};34m┌─────┐${e}[33m┌─────┐"
                "${e}[${t};34m│     │${e}[33m│     │"
                "${e}[${t};34m│     │${e}[33m│     │"
                "${e}[${t};34m└─────┘${e}[33m└─────┘"
            )
        } else {
            Write-Error 'Use one of the followings logos in the config file: Microsoft, Windows 11, Windows 10, Windows XP, Windows 7, Microsoft or Visnes.'
            exit 1
        }
    }
}




###############################
#  BLANKS, DASHES & COLORBAR  #
###############################

# ===== BLANK =====
function info_blank {
    return @{}
}

# ===== BLANK-D =====
function info_blank_d {
    return @{
        title = ""
        content = "│"
    }
}

# ===== BLANK-E =====
function info_blank_e {
    return @{
        title = ""
        content = "└"
    }
}

# ===== INFO_SOFTWARE =====
function info_software {
    $content_en = "╭─┤${e}[;31m Software information${e}[0m ├─────────────────────────────────────"
    $content_jp = "╭────┤${e}[;31m ソフトウエア情報${e}[0m├───────────────────────────────────────"

    if ([string]::IsNullOrEmpty($info_language)) {
        $info_language = "jp"
    }
    if ($info_language -eq "jp") {
        $content = $content_jp
    } else {
        $content = $content_en
    }
    return @{
        title   = ""
        content = $content
    }
}

# ===== INFO_HARDWARE =====
function info_hardware {
    $content_en = "╭─┤${e}[;32m Hardware information${e}[0m ├─────────────────────────────────────"
    $content_jp = "╭────┤${e}[;32m ハードウェア情報${e}[0m├───────────────────────────────────────"
    
    if ([string]::IsNullOrEmpty($info_language)) {
        $info_language = "jp"
    }
    if ($info_language -eq "jp") {
        $content = $content_jp
    } else {
        $content = $content_en
    }
    return @{
        title   = ""
        content = $content
    }
}


# ===== INFO_OTHER =====
function info_other {
    $content_en = "╭─┤${e}[;33m Other information${e}[0m ├────────────────────────────────────────"
    $content_jp = "╭────┤${e}[;33m その他情報${e}[0m├─────────────────────────────────────────────"

    if ([string]::IsNullOrEmpty($info_language)) {
        $info_language = "jp"
    }
    if ($info_language -eq "jp") {
        $content = $content_jp
    } else {
        $content = $content_en
    }
    return @{
        title   = ""
        content = $content
    }
}

# ===== DASHES-A =====
function info_dashes_end {
    return @{
        title   = ""
        content = "╰──────────────────────────────────────────────────────────────"
    }
}

# ===== DASHES-S =====
function info_dashes_fill {
    return @{
        title   = ""
        content = "│"
    }
}

# ===== DASHES =====
function info_dashes {
    $length = [System.Environment]::UserName.Length + $env:COMPUTERNAME.Length + 7
    return @{
        title   = ""
        content = ("─" * $length)
    }
}

# ===== COLORBAR =====
function info_colorbar {
    return @(
        @{
            title   = ""
            content = ('{0}[0;40m{1}{0}[0;41m{1}{0}[0;42m{1}{0}[0;43m{1}{0}[0;44m{1}{0}[0;45m{1}{0}[0;46m{1}{0}[0;47m{1}{0}[0;100m{1}{0}[0;101m{1}{0}[0;102m{1}{0}[0;103m{1}{0}[0;104m{1}{0}[0;105m{1}{0}[0;106m{1}{0}[0;107m{1}{0}[0m') -f $e, '    '
        }
    )
}


######################
#  TITLE & SUBTITLE  #
######################

# ===== TITLE =====
function info_title {
    param (
        [string]$e = [char]27
    )
    $width = [console]::WindowWidth - $COLUMNS
    $content = "░░▒▒▒▓▓▓▓█████   ${e}[1;31m{0}${e}[0m 󰁥  ${e}[1;36m{1}${e}[0m    █████▓▓▓▓▒▒▒░░" -f [System.Environment]::UserName, $env:COMPUTERNAME
    $contentVisibleLength = ($content -replace "\x1B\[[0-9;]*[A-Za-z]", "").Length
    $padding = [math]::Max(0, ($width - $contentVisibleLength) / 2 - 3)
    $centeredContent = (" " * $padding) + $content

    return @{
        title   = ""
        content = $centeredContent
    }
}

# ===== SUBTITLE =====
function info_subtitle {
    param (
        [string]$title = ""
    )

    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        # Japanese haiku (max 60 characters)
        $quotes_jp = @(
            "古池や蛙飛び込む水の音",
            "やまざくら花よりほかに知る人なし",
            "春過ぎて夏来にけらし白妙の",
            "あしびきの山鳥の尾のしだり尾の",
            "天の原ふりさけ見れば春日なる",
            "いますぐに月となりにけるかな",
            "あらし吹く秋の夕暮れは",
            "秋風にたなびく雲のたえ間より",
            "しづかさや岩に滲む水の音",
            "この道や行く人なしに秋のくれ",
            "昼顔の花の散るや秋の風",
            "霜柱に花やうき世のひまなき",
            "菜の花や月は東に日は西に",
            "春雨や草も腐らぬ青さ哉",
            "鶉鳴くや村のさびしき夕ぐれ",
            "梅に蟻のはいつもありけり",
            "雲の上にもまた雲たれ朝顔",
            "霧深し奥山に月は白し",
            "麦の穂にしづくて光る水",
            "花の色は移りにけりないたづらに"
        )
        $quotes = $quotes_jp
    } elseif ($info_language -eq "en") {
        # English quotes (max 60 characters)
        $quotes_en = @(
            "My selfie game is stronger than my will to adult.",
            "Avocado toast is basically life fuel.",
            "I'm not a morning person, or an afternoon person.",
            "Is this gluten-free, organic, and non-GMO?",
            "Netflix and chill is my cardio.",
            "I can't even without my coffee.",
            "Adulting is just not my thing.",
            "WiFi is my spirit animal.",
            "Hashtag blessed, but also stressed.",
            "Can I pay my rent in exposure?",
            "This bussy poppin'",
            "I need a vacation from my vacation.",
            "Sorry, I can't. I have plans with my bed.",
            "Living my best life, one meme at a time.",
            "I'm busy overthinking right now.",
            "Can we reschedule? Mercury is in retrograde.",
            "If it's not on Instagram, did it even happen?",
            "I'm 99% sure I'm a Disney princess.",
            "My Patronus is a pumpkin spice latte.",
            "I speak fluent emoji.",
            "Why buy a house when you can buy avocado toast?"
        )
        $quotes = $quotes_en
    }

    $content = Get-Random -InputObject $quotes
    $width = 60
    $contentLength = $content.Length
    $paddingLeft = [math]::Floor(($width - $contentLength) / 2)
    $paddingRight = $width - $contentLength - $paddingLeft
    $centeredContent = (" " * $paddingLeft) + $content + (" " * $paddingRight)

    return @{
        title   = $title
        content = $centeredContent
    }
}





#################################################################################
#  OS, KERNEL, PS-PKGS, PWSH, UPTIME, TERMINAL, PKGS, THEME, DATETIME, BATTERY  #
#################################################################################

# ===== OS =====
function info_os {
    $os = Get-WmiObject -Class Win32_OperatingSystem

    if ([string]::IsNullOrEmpty($info_language)) {
        $info_language = "jp"
    }

    $title_jp = "オーエス      "
    $title_en = "OS            "

    if ($info_language -eq "en") {
        $title = $title_en
    } else {
        $title = $title_jp
    }

    return @{
        title   = $title
        icon    = "├─  "
        content = "$($os.Caption.TrimStart('Microsoft ')) [$($os.OSArchitecture)]"
    }
}

# ===== KERNEL =====
function info_kernel {
    # Set default language to jp if $info_language is blank or not set
    if ([string]::IsNullOrEmpty($info_language)) {
        $info_language = "jp"
    }

    # Define titles for both languages
    $title_jp = "カーネル      "  # Japanese title
    $title_en = "Kernel        "   # English title

    # Select title based on $info_language
    if ($info_language -eq "en") {
        $title = $title_en
    } else {
        $title = $title_jp
    }

    return @{
        title   = $title
        icon    = "├─  "
        content = "$([System.Environment]::OSVersion.Version)"
    }
}

# ===== POWERSHELL PACKAGES =====
function info_ps_pkgs {
    $ps_pkgs = @()

    $pgp = Get-Package -ProviderName PowerShellGet
    $modulecount = $pgp.Where({$_.Metadata["tags"] -like "*PSModule*"}).count
    $scriptcount = $pgp.Where({$_.Metadata["tags"] -like "*PSScript*"}).count

    if ($modulecount) {
        if ($modulecount -eq 1) { $modulestring = "1 Module" }
        else { $modulestring = "$modulecount Modules" }

        $ps_pkgs += "$modulestring"
    }

    if ($scriptcount) {
        if ($scriptcount -eq 1) { $scriptstring = "1 Script" }
        else { $scriptstring = "$scriptcount Scripts" }

        $ps_pkgs += "$scriptstring"
    }

    if (-not $ps_pkgs) {
        $ps_pkgs = "(none)"
    }

    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        $title = "PS パッケージ "
    } elseif ($info_language -eq "en") {
        $title = "PS Packages   "
    }

    return @{
        title   = $title
        icon    = "├─  "
        content = $ps_pkgs -join ', '
    }
}

# ===== POWERSHELL VERSION =====
function info_pwsh {
    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        $title = "シェル        "
    } elseif ($info_language -eq "en") {
        $title = "Shell         "
    }

    return @{
        title   = $title
        icon    = "├─  "
        content = "PowerShell v$($PSVersionTable.PSVersion)"
    }
}


# ===== UPTIME =====
function info_uptime {
    $uptime = (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem -Property LastBootUpTime).LastBootUpTime
    $uptimeString = ""

    if ($uptime.Days -gt 0) {
        $uptimeString += "$($uptime.Days) day"
        if ($uptime.Days -gt 1) {
            $uptimeString += "s"
        }
        $uptimeString += " "
    }

    if ($uptime.Hours -gt 0) {
        $uptimeString += "$($uptime.Hours) hour"
        if ($uptime.Hours -gt 1) {
            $uptimeString += "s"
        }
        $uptimeString += " "
    }

    if ($uptime.Minutes -gt 0) {
        $uptimeString += "$($uptime.Minutes) minute"
        if ($uptime.Minutes -gt 1) {
            $uptimeString += "s"
        }
        $uptimeString += " "
    }

    if ($uptime.Seconds -gt 0) {
        $uptimeString += "$($uptime.Seconds) second"
        if ($uptime.Seconds -gt 1) {
            $uptimeString += "s"
        }
    }

    $uptimeString = $uptimeString.Trim()

    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        $title = "アップタイム  "
    } elseif ($info_language -eq "en") {
        $title = "Uptime        "
    }

    return @{
        title   = $title
        icon    = "├─⏻  "
        content = $uptimeString
    }
}


# ===== TERMINAL =====
# this section works by getting the parent processes of the current powershell instance.
function info_terminal {
    $programs = 'powershell', 'pwsh', 'winpty-agent', 'cmd', 'zsh', 'bash', 'fish', 'env', 'nu', 'elvish', 'csh', 'tcsh', 'python', 'xonsh'
    
    if ($PSVersionTable.PSEdition.ToString() -ne 'Core') {
        $parent = Get-Process -Id (Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $PID" -Property ParentProcessId).ParentProcessId -ErrorAction Ignore
        for () {
            if ($parent.ProcessName -in $programs) {
                $parent = Get-Process -Id (Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($parent.ID)" -Property ParentProcessId).ParentProcessId -ErrorAction Ignore
                continue
            }
            break
        }
    } else {
        $parent = (Get-Process -Id $PID).Parent
        for () {
            if ($parent.ProcessName -in $programs) {
                $parent = (Get-Process -Id $parent.ID).Parent
                continue
            }
            break
        }
    }

    $terminal = switch ($parent.ProcessName) {
        { $PSItem -in 'explorer', 'conhost' } { 'Windows Console' }
        'Console' { 'Console2/Z' }
        'ConEmuC64' { 'ConEmu' }
        'WindowsTerminal' { 'Windows Terminal' }
        'FluentTerminal.SystemTray' { 'Fluent Terminal' }
        'Code' { 'Visual Studio Code' }
        default { $PSItem }
    }

    if (-not $terminal) {
        $terminal = " (Unknown)"  # Using placeholder symbol for unknown terminal
    }

    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        $title = "「ターミナル」"
    } elseif ($info_language -eq "en") {
        $title = "Terminal      "
    }

    return @{
        title   = $title
        icon    = "├─  "
        content = $terminal
    }
}


# ===== PACKAGES =====
function info_pkgs {
    $pkgs = @()

    if ("winget" -in $ShowPkgs -and (Get-Command -Name winget -ErrorAction Ignore)) {
        $wingetpkg = (winget list | Where-Object {$_.Trim("`n`r`t`b-\|/ ").Length -ne 0} | Measure-Object).Count - 1

        if ($wingetpkg) {
            $pkgs += "$wingetpkg (system)"
        }
    }

    if ("choco" -in $ShowPkgs -and (Get-Command -Name choco -ErrorAction Ignore)) {
        $chocopkg = (& choco list)[-1].Split(' ')[0] - 1

        if ($chocopkg) {
            $pkgs += "$chocopkg (choco)"
        }
    }

    if ("scoop" -in $ShowPkgs) {
        $scoopdir = if ($Env:SCOOP) { "$Env:SCOOP\apps" } else { "$Env:UserProfile\scoop\apps" }

        if (Test-Path $scoopdir) {
            $scooppkg = (Get-ChildItem -Path $scoopdir -Directory).Count - 1
        }

        if ($scooppkg) {
            $pkgs += "$scooppkg (scoop)"
        }
    }

    foreach ($pkgitem in $CustomPkgs) {
        if (Test-Path Function:"info_pkg_$pkgitem") {
            $count = & "info_pkg_$pkgitem"
            $pkgs += "$count ($pkgitem)"
        }
    }

    if (-not $pkgs) {
        $pkgs = "(none)"
    }

    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        $title = "パッケージ    "
    } elseif ($info_language -eq "en") {
        $title = "Packages      "
    }

    return @{
        title   = $title
        icon    = "├─󰏗  "
        content = $pkgs -join ', '
    }
}


# ===== THEME =====
function info_theme {
    $themeinfo = Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name SystemUsesLightTheme, AppsUseLightTheme
    $themename = (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes' -Name CurrentTheme).CurrentTheme.Split('\')[-1].Replace('.theme', '')
    $systheme = if ($themeinfo.SystemUsesLightTheme) { "Light" } else { "Dark" }
    $apptheme = if ($themeinfo.AppsUseLightTheme) { "Light" } else { "Dark" }

    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        $title = "テーマ        "
    } elseif ($info_language -eq "en") {
        $title = "Theme         "
    }

    return @{
        title   = $title
        icon    = "├─  "
        content = "$themename (System: $systheme, Apps: $apptheme)"
    }
}


# ===== DATE AND TIME =====
function info_datetime {
    $currentDateTime = Get-Date
    $info_datetime_tz = [Regex]::Replace([System.TimeZoneInfo]::Local.StandardName, '([A-Z])\w+\s*', '$1')
    $info_datetime_ascii1 = ""
    $info_datetime_ascii2 = ""
    $formattedDateTime = '{0} {1:dd.MM.yyyy} {2} {3:HH:mm:ss} ({4})' -f $info_datetime_ascii1, $currentDateTime, $info_datetime_ascii2, $currentDateTime, $info_datetime_tz
    
    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        $title = "ローカル時間  "
    } elseif ($info_language -eq "en") {
        $title = "Local Time    "
    }

    return @{
        title   = $title
        icon    = "├─󱛡  "
        content = "$formattedDateTime"
    }
}


# ===== BATTERY =====
function info_battery {
    Add-Type -AssemblyName System.Windows.Forms
    $battery = [System.Windows.Forms.SystemInformation]::PowerStatus
    if ($battery.BatteryChargeStatus -eq 'NoSystemBattery') {
        return $null
    }

    $status = if ($battery.BatteryChargeStatus -like '*Charging*') {
        "Charging"
    } elseif ($battery.PowerLineStatus -like '*Online*') {
        "Plugged in"
    } else {
        "Discharging"
    }
    
    $timeRemaining = $battery.BatteryLifeRemaining / 60
    $timeFormatted = if ($timeRemaining -ge 0) {
        $hours = [math]::floor($timeRemaining / 60)
        $minutes = [math]::floor($timeRemaining % 60)
        ", ${hours}h ${minutes}m"
    }

    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        $title = "バッテリー"
    } elseif ($info_language -eq "en") {
        $title = "Battery"
    }

    return @{
        title   = $title
        icon    = "├─  "
        content = get_level_info "  " $batterystyle "$([math]::round($battery.BatteryLifePercent * 100))" "$status$timeFormatted" -altstyle
    }
}





########################################################################################
#  COMPUTER, CPU, GPU, MOTHERBOARD, TEMPERATURES, RESOLUTION, CPU_USAGE, MEMORY, DISK  #
########################################################################################

# ===== COMPUTER =====
function info_computer {
    $compsys = Get-CimInstance -ClassName Win32_ComputerSystem -Property Manufacturer, Model -CimSession $cimSession

    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        $title = "コンピュータ  "
    } elseif ($info_language -eq "en") {
        $title = "Host computer "
    }

    return @{
        title   = $title
        icon    = "├─  "
        content = '{0} {1}' -f $compsys.Manufacturer, $compsys.Model
    }
}


# ===== CPU & CPU TEMP =====
function info_cpu {
    $cpu = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $Env:COMPUTERNAME).OpenSubKey("HARDWARE\DESCRIPTION\System\CentralProcessor\0")
    $cpuname = $cpu.GetValue("ProcessorNameString")
    $cpuname = $cpuname -replace '\(R\)', '' -replace '\(TM\)', '' -replace 'Gen', '' -replace '5th', '' -replace '6th', '' -replace '7th', '' -replace '8th', '' -replace '9th', '' -replace '10th', '' -replace '11th', '' -replace '12th', '' -replace '13th', '' -replace '14th', '' -replace '15th', '' -replace '16th', ''
    $cpuname = $cpuname.Trim()
    if ($cpuname.Contains('@')) {
        $cpuname = ($cpuname -split '@')[0].Trim()
    }

    $cpuFrequencyGHz = [math]::Round($cpu.GetValue("~MHz") / 1000, 2)

    $tempcpu = Get-CimInstance -ClassName MSAcpi_ThermalZoneTemperature -Namespace "root/wmi"
    if ($tempcpu) {
        $cpuTempCelsius = $tempcpu.CurrentTemperature / 100
        $cpuTempInfo = " ($($cpuTempCelsius) °C)"
    } else {
        $cpuTempInfo = ""
    }

    return @{
        title   = "CPU "
        icon    = "├─  "
        content = "$cpuname @ $cpuFrequencyGHz GHz$cpuTempInfo"
    }
}

# ==== GPU ====
function info_gpu {
    [System.Collections.ArrayList]$lines = @()
    # Loop through Win32_VideoController
    foreach ($gpu in Get-CimInstance -ClassName Win32_VideoController -Property Name -CimSession $cimSession) {
        $gpuName = $gpu.Name
        if ($gpuName -like '*NVIDIA*' -or $gpuName -like '*AMD*') {
            [void]$lines.Add(@{
                title   = "GPU "
                icon = "├─  "
                content = $gpuName
            })
        }
    }
    return $lines
}

# ===== MOTHERBOARD =====
function info_motherboard {
    $motherboard = Get-CimInstance Win32_BaseBoard -CimSession $cimSession -Property Manufacturer, Product
    $manufacturer = $motherboard.Manufacturer
    $truncatedManufacturer = $manufacturer -replace 'TeK COMPUTER INC.', ''  # Replace with appropriate truncation for ASUS branding

    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        $title = "マザーボード  "
    } elseif ($info_language -eq "en") {
        $title = "Motherboard   "
    }

    return @{
        title   = $title
        icon    = "├─  "
        content = "{0} {1}" -f $truncatedManufacturer.Trim(), $motherboard.Product
    }
}


# Was going to add a separate line for temps, but couldn't find any way to show the GPU temp, so I put it on ice
# ==== TEMPERATURES ====
#function info_temperatures {
#    $tempcpu = Get-CimInstance MSAcpi_ThermalZoneTemperature -Namespace "root/wmi"
#    return @{
#        title   = "CPU 温度  "
#        icon    = "├─  "
#        content = "$($tempcpu.CurrentTemperature / 100) °C (CPU)"
#    }
#}

# ===== RESOLUTION =====
function info_resolution {
    Add-Type -AssemblyName System.Windows.Forms
    $displays = foreach ($monitor in [System.Windows.Forms.Screen]::AllScreens) {
        "$($monitor.Bounds.Size.Width)x$($monitor.Bounds.Size.Height)"
    }

    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        $title = "画面解像度    "
    } elseif ($info_language -eq "en") {
        $title = "Resolution(s) "
    }

    return @{
        title   = $title
        icon    = "├─󰹑  "
        content = $displays -join ', '
    }
}


# ===== CPU USAGE =====
function info_cpu_usage {
    # Get all running processes and assign to a variable to allow reuse
    $processes = [System.Diagnostics.Process]::GetProcesses()
    $loadpercent = 0
    $proccount = $processes.Count
    # Get the number of logical processors in the system
    $CPUs = [System.Environment]::ProcessorCount

    $timenow = [System.Datetime]::Now
    $processes.ForEach{
        if ($_.StartTime -gt 0) {
            # Replicate the functionality of New-Timespan
            $timespan = ($timenow.Subtract($_.StartTime)).TotalSeconds

            # Calculate the CPU usage of the process and add to the total
            $loadpercent += $_.CPU * 100 / $timespan / $CPUs
        }
    }

    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        $title = "CPU使用率     "
    } elseif ($info_language -eq "en") {
        $title = "CPU Usage     "
    }

    return @{
        title   = $title
        icon    = "├─  "
        content = get_level_info "" $cpustyle $loadpercent "$proccount processes" -altstyle
    }
}


# ===== MEMORY =====
function info_memory {
    $m = Get-CimInstance -ClassName Win32_OperatingSystem -Property TotalVisibleMemorySize, FreePhysicalMemory -CimSession $cimSession
    $total = $m.TotalVisibleMemorySize / 1mb
    $used = ($m.TotalVisibleMemorySize - $m.FreePhysicalMemory) / 1mb
    $usage = [math]::floor(($used / $total * 100))

    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        $title = "ラム          "
    } elseif ($info_language -eq "en") {
        $title = "Memory        "
    }

    return @{
        title   = $title
        icon    = "├─  "
        content = get_level_info "" $memorystyle $usage "$($used.ToString("#.##")) GiB / $($total.ToString("#.##")) GiB"
    }
}


# ===== DISK USAGE =====
function info_disk {
    [System.Collections.ArrayList]$lines = @()

    function to_units($value) {
        if ($value -gt 1tb) {
            return "$([math]::round($value / 1tb, 1)) TiB"
        } else {
            return "$([math]::floor($value / 1gb)) GiB"
        }
    }

    $drives = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady }
    $totalDrives = $drives.Count
    $currentDrive = 1

    $drives.ForEach{
        $diskLetter = $_.Name.SubString(0,2)

        if ($showDisks.Contains($diskLetter) -or $showDisks.Contains("*")) {
            try {
                if ($_.TotalSize -gt 0) {
                    $used = $_.TotalSize - $_.AvailableFreeSpace
                    $available = $_.AvailableFreeSpace
                    $usage = [math]::Floor(($used / $_.TotalSize * 100))
                    
                    $icon = if ($currentDrive -eq $totalDrives) { "├─  " } else { "├─  " }
                    $currentDrive++
    
                    [void]$lines.Add(@{
                        title   = if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") { "ディスク ($diskLetter) " } elseif ($info_language -eq "en") { "Disk ($diskLetter)     " }
                        icon    = $icon
                        content = get_level_info "" $diskstyle $usage "$(to_units $available ) / $(to_units $_.TotalSize)" # Shows how much space is left.
                    })
                }
            } catch {
                $icon = if ($currentDrive -eq $totalDrives) { "├─  " } else { "├─  " }
                $currentDrive++
                
                [void]$lines.Add(@{
                    title   = if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") { "ディスク ($diskLetter)" } elseif ($info_language -eq "en") { "Disk ($diskLetter)   " }
                    icon    = $icon
                    content = "(Error)"
                })
            }
        }
    }
    return $lines
}





###########################################################
#  LOCALE, LAYOUT, LOCAL_IP, PUBLIC_IP, FAKE_IP, WEATHER  #
###########################################################

# ===== LOCALE =====
function info_locale {
    # Hashtables for language and region codes
    $localeLookup = @{
        "10" = "American Samoa";                             "100" = "Guinea";                            "10026358" = "Americas";                                                                                                                                            
        "10028789" = "Åland Islands";                        "10039880" = "Caribbean";                    "10039882" = "Northern Europe";                                                                                                                                            
        "10039883" = "Southern Africa";                      "101" = "Guyana";                            "10210824" = "Western Europe";                                                                                                                                            
        "10210825" = "Australia and New Zealand";            "103" = "Haiti";                             "104" = "Hong Kong SAR";                                                                                                                                            
        "10541" = "Europe";                                  "106" = "Honduras";                          "108" = "Croatia";                                                                                                                                            
        "109" = "Hungary";                                   "11" = "Argentina";                          "110" = "Iceland";                                                                                                                                            
        "111" = "Indonesia";                                 "113" = "India";                             "114" = "British Indian Ocean Territory";                                                                                                                                            
        "116" = "Iran";                                      "117" = "Israel";                            "118" = "Italy";                                                                                                                                            
        "119" = "Côte d'Ivoire";                             "12" = "Australia";                          "121" = "Iraq";                                                                                                                                            
        "122" = "Japan";                                     "124" = "Jamaica";                           "125" = "Jan Mayen";                                                                                                                                            
        "126" = "Jordan";                                    "127" = "Johnston Atoll";                    "129" = "Kenya";                                                                                                                                            
        "130" = "Kyrgyzstan";                                "131" = "North Korea";                       "133" = "Kiribati";                                                                                                                                            
        "134" = "Korea";                                     "136" = "Kuwait";                            "137" = "Kazakhstan";                                                                                                                                            
        "138" = "Laos";                                      "139" = "Lebanon";                           "14" = "Austria";                                                                                                                                            
        "140" = "Latvia";                                    "141" = "Lithuania";                         "142" = "Liberia";                                                                                                                                            
        "143" = "Slovakia";                                  "145" = "Liechtenstein";                     "146" = "Lesotho";                                                                                                                                            
        "147" = "Luxembourg";                                "148" = "Libya";                             "149" = "Madagascar";                                                                                                                                            
        "151" = "Macao SAR";                                 "15126" = "Isle of Man";                     "152" = "Moldova";                                                                                                                                            
        "154" = "Mongolia";                                  "156" = "Malawi";                            "157" = "Mali";                                                                                                                                            
        "158" = "Monaco";                                    "159" = "Morocco";                           "160" = "Mauritius";                                                                                                                                            
        "161832015" = "Saint Barthélemy";                    "161832256" = "U.S. Minor Outlying Islands"; "161832257" = "Latin America and the Caribbean";                                                                                                                                            
        "161832258" = "Bonaire, Sint Eustatius and Saba";    "162" = "Mauritania";                        "163" = "Malta";                                                                                                                                            
        "164" = "Oman";                                      "165" = "Maldives";                          "166" = "Mexico";                                                                                                                                            
        "167" = "Malaysia";                                  "168" = "Mozambique";                        "17" = "Bahrain";                                                                                                                                            
        "173" = "Niger";                                     "174" = "Vanuatu";                           "175" = "Nigeria";                                                                                                                                            
        "176" = "Netherlands";                               "177" = "Norway";                            "178" = "Nepal";                                                                                                                                            
        "18" = "Barbados";                                   "180" = "Nauru";                             "181" = "Suriname";                                                                                                                                            
        "182" = "Nicaragua";                                 "183" = "New Zealand";                       "184" = "Palestinian Authority";                                                                                                                                            
        "185" = "Paraguay";                                  "187" = "Peru";                              "19" = "Botswana";                                                                                                                                            
        "190" = "Pakistan";                                  "191" = "Poland";                            "192" = "Panama";                                                                                                                                            
        "193" = "Portugal";                                  "194" = "Papua New Guinea";                  "195" = "Palau";                                                                                                                                            
        "196" = "Guinea-Bissau";                             "19618" = "North Macedonia";                 "197" = "Qatar";                                                                                                                                            
        "198" = "Réunion";                                   "199" = "Marshall Islands";                  "2" = "Antigua and Barbuda";                                                                                                                                            
        "20" = "Bermuda";                                    "200" = "Romania";                           "201" = "Philippines";                                                                                                                                            
        "202" = "Puerto Rico";                               "203" = "Russia";                            "204" = "Rwanda";                                                                                                                                            
        "205" = "Saudi Arabia";                              "206" = "Saint Pierre and Miquelon";         "207" = "Saint Kitts and Nevis";                                                                                                                                            
        "208" = "Seychelles";                                "209" = "South Africa";                      "20900" = "Melanesia";                                                                                                                                            
        "21" = "Belgium";                                    "210" = "Senegal";                           "212" = "Slovenia";                                                                                                                                            
        "21206" = "Micronesia";                              "21242" = "Midway Islands";                  "2129" = "Asia";                                                                                                                                            
        "213" = "Sierra Leone";                              "214" = "San Marino";                        "215" = "Singapore";                                                                                                                                            
        "216" = "Somalia";                                   "217" = "Spain";                             "218" = "Saint Lucia";                                                                                                                                            
        "219" = "Sudan";                                     "22" = "Bahamas";                            "220" = "Svalbard";                                                                                                                                            
        "221" = "Sweden";                                    "222" = "Syria";                             "223" = "Switzerland";                                                                                                                                            
        "224" = "United Arab Emirates";                      "225" = "Trinidad and Tobago";               "227" = "Thailand";                                                                                                                                            
        "228" = "Tajikistan";                                "23" = "Bangladesh";                         "231" = "Tonga";                                                                                                                                            
        "232" = "Togo";                                      "233" = "São Tomé and Príncipe";             "234" = "Tunisia";                                                                                                                                            
        "235" = "Turkey";                                    "23581" = "Northern America";                "236" = "Tuvalu";                                                                                                                                            
        "237" = "Taiwan";                                    "238" = "Turkmenistan";                      "239" = "Tanzania";                                                                                                                                            
        "24" = "Belize";                                     "240" = "Uganda";                            "241" = "Ukraine";                                                                                                                                            
        "242" = "United Kingdom";                            "244" = "United States";                     "245" = "Burkina Faso";                                                                                                                                            
        "246" = "Uruguay";                                   "247" = "Uzbekistan";                        "248" = "Saint Vincent and the Grenadines";                                                                                                                                            
        "249" = "Venezuela";                                 "25" = "Bosnia and Herzegovina";             "251" = "Vietnam";                                                                                                                                            
        "252" = "U.S. Virgin Islands";                       "253" = "Vatican City";                      "254" = "Namibia";                                                                                                                                            
        "258" = "Wake Island";                               "259" = "Samoa";                             "26" = "Bolivia";                                                                                                                                            
        "260" = "Swaziland";                                 "261" = "Yemen";                             "26286" = "Polynesia";                                                                                                                                            
        "263" = "Zambia";                                    "264" = "Zimbabwe";                          "269" = "Serbia and Montenegro (Former)";                                                                                                                                            
        "27" = "Myanmar";                                    "270" = "Montenegro";                        "27082" = "Central America";                                                                                                                                            
        "271" = "Serbia";                                    "27114" = "Oceania";                         "273" = "Curaçao";                                                                                                                                            
        "276" = "South Sudan";                               "28" = "Benin";                              "29" = "Belarus";                                                                                                                                            
        "3" = "Afghanistan";                                 "30" = "Solomon Islands";                    "300" = "Anguilla";                                                                                                                                            
        "301" = "Antarctica";                                "302" = "Aruba";                             "303" = "Ascension Island";                                                                                                                                            
        "304" = "Ashmore and Cartier Islands";               "305" = "Baker Island";                      "306" = "Bouvet Island";                                                                                                                                            
        "307" = "Cayman Islands";                            "308" = "Channel Islands";                   "309" = "Christmas Island";                                                                                                                                            
        "30967" = "Sint Maarten";                            "310" = "Clipperton Island";                 "311" = "Cocos (Keeling) Islands";                                                                                                                                            
        "312" = "Cook Islands";                              "313" = "Coral Sea Islands";                 "31396" = "South America";                                                                                                                                            
        "314" = "Diego Garcia";                              "315" = "Falkland Islands";                  "317" = "French Guiana";                                                                                                                                            
        "31706" = "Saint Martin";                            "318" = "French Polynesia";                  "319" = "French Southern Territories";                                                                                                                                            
        "32" = "Brazil";                                     "321" = "Guadeloupe";                        "322" = "Guam";                                                                                                                                            
        "323" = "Guantanamo Bay";                            "324" = "Guernsey";                          "325" = "Heard Island and McDonald Islands";                                                                                                                                            
        "326" = "Howland Island";                            "327" = "Jarvis Island";                     "328" = "Jersey";                                                                                                                                            
        "329" = "Kingman Reef";                              "330" = "Martinique";                        "331" = "Mayotte";                                                                                                                                            
        "332" = "Montserrat";                                "333" = "Netherlands Antilles (Former)";     "334" = "New Caledonia";                                                                                                                                            
        "335" = "Niue";                                      "336" = "Norfolk Island";                    "337" = "Northern Mariana Islands";                                                                                                                                            
        "338" = "Palmyra Atoll";                             "339" = "Pitcairn Islands";                  "34" = "Bhutan";                                                                                                                                            
        "340" = "Rota Island";                               "341" = "Saipan";                            "342" = "South Georgia and the South Sandwich Islands";                                                                                                                                            
        "343" = "St Helena, Ascension and Tristan da Cunha"; "346" = "Tinian Island";                     "347" = "Tokelau";                                                                                                                                            
        "348" = "Tristan da Cunha";                          "349" = "Turks and Caicos Islands";          "35" = "Bulgaria";                                                                                                                                            
        "351" = "British Virgin Islands";                    "352" = "Wallis and Futuna";                 "37" = "Brunei";                                                                                                                                            
        "38" = "Burundi";                                    "39" = "Canada";                             "39070" = "World";                                                                                                                                            
        "4" = "Algeria";                                     "40" = "Cambodia";                           "41" = "Chad";                                                                                                                                            
        "42" = "Sri Lanka";                                  "42483" = "Western Africa";                  "42484" = "Middle Africa";                                                                                                                                            
        "42487" = "Northern Africa";                         "43" = "Congo";                              "44" = "Congo (DRC)";                                                                                                                                            
        "45" = "China";                                      "46" = "Chile";                              "47590" = "Central Asia";                                                                                                                                            
        "47599" = "South-Eastern Asia";                      "47600" = "Eastern Asia";                    "47603" = "Eastern Africa";                                                                                                                                            
        "47609" = "Eastern Europe";                          "47610" = "Southern Europe";                 "47611" = "Middle East";                                                                                                                                            
        "47614" = "Southern Asia";                           "49" = "Cameroon";                           "5" = "Azerbaijan";                                                                                                                                            
        "50" = "Comoros";                                    "51" = "Colombia";                           "54" = "Costa Rica";                                                                                                                                            
        "55" = "Central African Republic";                   "56" = "Cuba";                               "57" = "Cabo Verde";                                                                                                                                            
        "59" = "Cyprus";                                     "6" = "Albania";                             "61" = "Denmark";                                                                                                                                            
        "62" = "Djibouti";                                   "63" = "Dominica";                           "65" = "Dominican Republic";                                                                                                                                            
        "66" = "Ecuador";                                    "67" = "Egypt";                              "68" = "Ireland";                                                                                                                                            
        "69" = "Equatorial Guinea";                          "7" = "Armenia";                             "70" = "Estonia";                                                                                                                                            
        "71" = "Eritrea";                                    "72" = "El Salvador";                        "7299303" = "Timor-Leste";                                                                                                                                            
        "73" = "Ethiopia";                                   "742" = "Africa";                            "75" = "Czech Republic";                                                                                                                                            
        "77" = "Finland";                                    "78" = "Fiji";                               "8" = "Andorra";                                                                                                                                            
        "80" = "Micronesia";                                 "81" = "Faroe Islands";                      "84" = "France";                                                                                                                                            
        "86" = "Gambia";                                     "87" = "Gabon";                              "88" = "Georgia";                                                                                                                                            
        "89" = "Ghana";                                      "9" = "Angola";                              "90" = "Gibraltar";                                                                                                                                            
        "91" = "Grenada";                                    "93" = "Greenland";                          "94" = "Germany";                                                                                                                                            
        "98" = "Greece";                                     "99" = "Guatemala";                          "9914689" = "Kosovo";                                                                                                                                            
    }
    $languageLookup = @{
        "aa" = "Afar";                                                "aa-DJ" = "Afar (Djibouti)";                                       "aa-ER" = "Afar (Eritrea)";                                                                                                                                            
        "aa-ET" = "Afar (Ethiopia)";                                  "af" = "Afrikaans";                                                "af-NA" = "Afrikaans (Namibia)";                                                                                                                                            
        "af-ZA" = "Afrikaans (South Africa)";                         "agq" = "Aghem";                                                   "agq-CM" = "Aghem (Cameroon)";                                                                                                                                            
        "ak" = "Akan";                                                "ak-GH" = "Akan (Ghana)";                                          "am" = "Amharic";                                                                                                                                            
        "am-ET" = "Amharic (Ethiopia)";                               "ar" = "Arabic";                                                   "ar-001" = "Arabic (World)";                                                                                                                                            
        "ar-AE" = "Arabic (U.A.E.)";                                  "ar-BH" = "Arabic (Bahrain)";                                      "ar-DJ" = "Arabic (Djibouti)";                                                                                                                                            
        "ar-DZ" = "Arabic (Algeria)";                                 "ar-EG" = "Arabic (Egypt)";                                        "ar-ER" = "Arabic (Eritrea)";                                                                                                                                            
        "ar-IL" = "Arabic (Israel)";                                  "ar-IQ" = "Arabic (Iraq)";                                         "ar-JO" = "Arabic (Jordan)";                                                                                                                                            
        "ar-KM" = "Arabic (Comoros)";                                 "ar-KW" = "Arabic (Kuwait)";                                       "ar-LB" = "Arabic (Lebanon)";                                                                                                                                            
        "ar-LY" = "Arabic (Libya)";                                   "ar-MA" = "Arabic (Morocco)";                                      "ar-MR" = "Arabic (Mauritania)";                                                                                                                                            
        "ar-OM" = "Arabic (Oman)";                                    "ar-PS" = "Arabic (Palestinian Authority)";                        "ar-QA" = "Arabic (Qatar)";                                                                                                                                            
        "ar-SA" = "Arabic (Saudi Arabia)";                            "ar-SD" = "Arabic (Sudan)";                                        "ar-SO" = "Arabic (Somalia)";                                                                                                                                            
        "ar-SS" = "Arabic (South Sudan)";                             "ar-SY" = "Arabic (Syria)";                                        "ar-TD" = "Arabic (Chad)";                                                                                                                                            
        "ar-TN" = "Arabic (Tunisia)";                                 "ar-YE" = "Arabic (Yemen)";                                        "arn" = "Mapudungun";                                                                                                                                            
        "arn-CL" = "Mapudungun (Chile)";                              "as" = "Assamese";                                                 "as-IN" = "Assamese (India)";                                                                                                                                            
        "asa" = "Asu";                                                "asa-TZ" = "Asu (Tanzania)";                                       "ast" = "Asturian";                                                                                                                                            
        "ast-ES" = "Asturian (Spain)";                                "az" = "Azerbaijani";                                              "az-Cyrl" = "Azerbaijani (Cyrillic)";                                                                                                                                            
        "az-Cyrl-AZ" = "Azerbaijani (Cyrillic, Azerbaijan)";          "az-Latn" = "Azerbaijani (Latin)";                                 "az-Latn-AZ" = "Azerbaijani (Latin, Azerbaijan)";                                                                                                                                            
        "ba" = "Bashkir";                                             "ba-RU" = "Bashkir (Russia)";                                      "bas" = "Basaa";                                                                                                                                            
        "bas-CM" = "Basaa (Cameroon)";                                "be" = "Belarusian";                                               "be-BY" = "Belarusian (Belarus)";                                                                                                                                            
        "bem" = "Bemba";                                              "bem-ZM" = "Bemba (Zambia)";                                       "bez" = "Bena";                                                                                                                                            
        "bez-TZ" = "Bena (Tanzania)";                                 "bg" = "Bulgarian";                                                "bg-BG" = "Bulgarian (Bulgaria)";                                                                                                                                            
        "bin" = "Edo";                                                "bin-NG" = "Edo (Nigeria)";                                        "bm" = "Bambara";                                                                                                                                            
        "bm-Latn" = "Bambara (Latin)";                                "bm-Latn-ML" = "Bambara (Latin, Mali)";                            "bn" = "Bangla";                                                                                                                                            
        "bn-BD" = "Bangla (Bangladesh)";                              "bn-IN" = "Bangla (India)";                                        "bo" = "Tibetan";                                                                                                                                            
        "bo-CN" = "Tibetan (PRC)";                                    "bo-IN" = "Tibetan (India)";                                       "br" = "Breton";                                                                                                                                            
        "br-FR" = "Breton (France)";                                  "brx" = "Bodo";                                                    "brx-IN" = "Bodo (India)";                                                                                                                                            
        "bs" = "Bosnian";                                             "bs-Cyrl" = "Bosnian (Cyrillic)";                                  "bs-Cyrl-BA" = "Bosnian (Cyrillic, Bosnia and Herzegovina)";                                                                                                                                            
        "bs-Latn" = "Bosnian (Latin)";                                "bs-Latn-BA" = "Bosnian (Latin, Bosnia and Herzegovina)";          "byn" = "Blin";                                                                                                                                            
        "byn-ER" = "Blin (Eritrea)";                                  "ca" = "Catalan";                                                  "ca-AD" = "Catalan (Andorra)";                                                                                                                                            
        "ca-ES" = "Catalan (Catalan)";                                "ca-ES-valencia" = "Valencian (Spain)";                            "ca-FR" = "Catalan (France)";                                                                                                                                            
        "ca-IT" = "Catalan (Italy)";                                  "ce" = "Chechen";                                                  "ce-RU" = "Chechen (Russia)";                                                                                                                                            
        "cgg" = "Chiga";                                              "cgg-UG" = "Chiga (Uganda)";                                       "chr" = "Cherokee";                                                                                                                                            
        "chr-Cher" = "Cherokee (Cherokee)";                           "chr-Cher-US" = "Cherokee (Cherokee)";                             "co" = "Corsican";                                                                                                                                            
        "co-FR" = "Corsican (France)";                                "cs" = "Czech";                                                    "cs-CZ" = "Czech (Czechia / Czech Republic)";                                                                                                                                            
        "cu" = "Church Slavic";                                       "cu-RU" = "Church Slavic (Russia)";                                "cy" = "Welsh";                                                                                                                                            
        "cy-GB" = "Welsh (United Kingdom)";                           "da" = "Danish";                                                   "da-DK" = "Danish (Denmark)";                                                                                                                                            
        "da-GL" = "Danish (Greenland)";                               "dav" = "Taita";                                                   "dav-KE" = "Taita (Kenya)";                                                                                                                                            
        "de" = "German";                                              "de-AT" = "German (Austria)";                                      "de-BE" = "German (Belgium)";                                                                                                                                            
        "de-CH" = "German (Switzerland)";                             "de-DE" = "German (Germany)";                                      "de-IT" = "German (Italy)";                                                                                                                                            
        "de-LI" = "German (Liechtenstein)";                           "de-LU" = "German (Luxembourg)";                                   "dje" = "Zarma";                                                                                                                                            
        "dje-NE" = "Zarma (Niger)";                                   "dsb" = "Lower Sorbian";                                           "dsb-DE" = "Lower Sorbian (Germany)";                                                                                                                                            
        "dua" = "Duala";                                              "dua-CM" = "Duala (Cameroon)";                                     "dv" = "Divehi";                                                                                                                                            
        "dv-MV" = "Divehi (Maldives)";                                "dyo" = "Jola-Fonyi";                                              "dyo-SN" = "Jola-Fonyi (Senegal)";                                                                                                                                            
        "dz" = "Dzongkha";                                            "dz-BT" = "Dzongkha (Bhutan)";                                     "ebu" = "Embu";                                                                                                                                            
        "ebu-KE" = "Embu (Kenya)";                                    "ee" = "Ewe";                                                      "ee-GH" = "Ewe (Ghana)";                                                                                                                                            
        "ee-TG" = "Ewe (Togo)";                                       "el" = "Greek";                                                    "el-CY" = "Greek (Cyprus)";                                                                                                                                            
        "el-GR" = "Greek (Greece)";                                   "en" = "English";                                                  "en-001" = "English (World)";                                                                                                                                            
        "en-029" = "English (Caribbean)";                             "en-150" = "English (Europe)";                                     "en-AG" = "English (Antigua and Barbuda)";                                                                                                                                            
        "en-AI" = "English (Anguilla)";                               "en-AS" = "English (American Samoa)";                              "en-AT" = "English (Austria)";                                                                                                                                            
        "en-AU" = "English (Australia)";                              "en-BB" = "English (Barbados)";                                    "en-BE" = "English (Belgium)";                                                                                                                                            
        "en-BI" = "English (Burundi)";                                "en-BM" = "English (Bermuda)";                                     "en-BS" = "English (Bahamas)";                                                                                                                                            
        "en-BW" = "English (Botswana)";                               "en-BZ" = "English (Belize)";                                      "en-CA" = "English (Canada)";                                                                                                                                            
        "en-CC" = "English (Cocos [Keeling] Islands)";                "en-CH" = "English (Switzerland)";                                 "en-CK" = "English (Cook Islands)";                                                                                                                                            
        "en-CM" = "English (Cameroon)";                               "en-CX" = "English (Christmas Island)";                            "en-CY" = "English (Cyprus)";                                                                                                                                            
        "en-DE" = "English (Germany)";                                "en-DK" = "English (Denmark)";                                     "en-DM" = "English (Dominica)";                                                                                                                                            
        "en-ER" = "English (Eritrea)";                                "en-FI" = "English (Finland)";                                     "en-FJ" = "English (Fiji)";                                                                                                                                            
        "en-FK" = "English (Falkland Islands)";                       "en-FM" = "English (Micronesia)";                                  "en-GB" = "English (United Kingdom)";                                                                                                                                            
        "en-GD" = "English (Grenada)";                                "en-GG" = "English (Guernsey)";                                    "en-GH" = "English (Ghana)";                                                                                                                                            
        "en-GI" = "English (Gibraltar)";                              "en-GM" = "English (Gambia)";                                      "en-GU" = "English (Guam)";                                                                                                                                            
        "en-GY" = "English (Guyana)";                                 "en-HK" = "English (Hong Kong SAR)";                               "en-ID" = "English (Indonesia)";                                                                                                                                            
        "en-IE" = "English (Ireland)";                                "en-IL" = "English (Israel)";                                      "en-IM" = "English (Isle of Man)";                                                                                                                                            
        "en-IN" = "English (India)";                                  "en-IO" = "English (British Indian Ocean Territory)";              "en-JE" = "English (Jersey)";                                                                                                                                            
        "en-JM" = "English (Jamaica)";                                "en-KE" = "English (Kenya)";                                       "en-KI" = "English (Kiribati)";                                                                                                                                            
        "en-KN" = "English (Saint Kitts and Nevis)";                  "en-KY" = "English (Cayman Islands)";                              "en-LC" = "English (Saint Lucia)";                                                                                                                                            
        "en-LR" = "English (Liberia)";                                "en-LS" = "English (Lesotho)";                                     "en-MG" = "English (Madagascar)";                                                                                                                                            
        "en-MH" = "English (Marshall Islands)";                       "en-MO" = "English (Macao SAR)";                                   "en-MP" = "English (Northern Mariana Islands)";                                                                                                                                            
        "en-MS" = "English (Montserrat)";                             "en-MT" = "English (Malta)";                                       "en-MU" = "English (Mauritius)";                                                                                                                                            
        "en-MW" = "English (Malawi)";                                 "en-MY" = "English (Malaysia)";                                    "en-NA" = "English (Namibia)";                                                                                                                                            
        "en-NF" = "English (Norfolk Island)";                         "en-NG" = "English (Nigeria)";                                     "en-NL" = "English (Netherlands)";                                                                                                                                            
        "en-NR" = "English (Nauru)";                                  "en-NU" = "English (Niue)";                                        "en-NZ" = "English (New Zealand)";                                                                                                                                            
        "en-PG" = "English (Papua New Guinea)";                       "en-PH" = "English (Philippines)";                                 "en-PK" = "English (Pakistan)";                                                                                                                                            
        "en-PN" = "English (Pitcairn Islands)";                       "en-PR" = "English (Puerto Rico)";                                 "en-PW" = "English (Palau)";                                                                                                                                            
        "en-RW" = "English (Rwanda)";                                 "en-SB" = "English (Solomon Islands)";                             "en-SC" = "English (Seychelles)";                                                                                                                                            
        "en-SD" = "English (Sudan)";                                  "en-SE" = "English (Sweden)";                                      "en-SG" = "English (Singapore)";                                                                                                                                            
        "en-SH" = "English (St Helena, Ascension, Tristan da Cunha)"; "en-SI" = "English (Slovenia)";                                    "en-SL" = "English (Sierra Leone)";                                                                                                                                            
        "en-SS" = "English (South Sudan)";                            "en-SX" = "English (Sint Maarten)";                                "en-SZ" = "English (Swaziland)";                                                                                                                                            
        "en-TC" = "English (Turks and Caicos Islands)";               "en-TK" = "English (Tokelau)";                                     "en-TO" = "English (Tonga)";                                                                                                                                            
        "en-TT" = "English (Trinidad and Tobago)";                    "en-TV" = "English (Tuvalu)";                                      "en-TZ" = "English (Tanzania)";                                                                                                                                            
        "en-UG" = "English (Uganda)";                                 "en-UM" = "English (US Minor Outlying Islands)";                   "en-US" = "English (United States)";                                                                                                                                            
        "en-VC" = "English (Saint Vincent and the Grenadines)";       "en-VG" = "English (British Virgin Islands)";                      "en-VI" = "English (US Virgin Islands)";                                                                                                                                            
        "en-VU" = "English (Vanuatu)";                                "en-WS" = "English (Samoa)";                                       "en-ZA" = "English (South Africa)";                                                                                                                                            
        "en-ZM" = "English (Zambia)";                                 "en-ZW" = "English (Zimbabwe)";                                    "eo" = "Esperanto";                                                                                                                                            
        "eo-001" = "Esperanto (World)";                               "es" = "Spanish";                                                  "es-419" = "Spanish (Latin America)";                                                                                                                                            
        "es-AR" = "Spanish (Argentina)";                              "es-BO" = "Spanish (Bolivia)";                                     "es-BR" = "Spanish (Brazil)";                                                                                                                                            
        "es-BZ" = "Spanish (Belize)";                                 "es-CL" = "Spanish (Chile)";                                       "es-CO" = "Spanish (Colombia)";                                                                                                                                            
        "es-CR" = "Spanish (Costa Rica)";                             "es-CU" = "Spanish (Cuba)";                                        "es-DO" = "Spanish (Dominican Republic)";                                                                                                                                            
        "es-EC" = "Spanish (Ecuador)";                                "es-ES" = "Spanish (Spain)";                                       "es-GQ" = "Spanish (Equatorial Guinea)";                                                                                                                                            
        "es-GT" = "Spanish (Guatemala)";                              "es-HN" = "Spanish (Honduras)";                                    "es-MX" = "Spanish (Mexico)";                                                                                                                                            
        "es-NI" = "Spanish (Nicaragua)";                              "es-PA" = "Spanish (Panama)";                                      "es-PE" = "Spanish (Peru)";                                                                                                                                            
        "es-PH" = "Spanish (Philippines)";                            "es-PR" = "Spanish (Puerto Rico)";                                 "es-PY" = "Spanish (Paraguay)";                                                                                                                                            
        "es-SV" = "Spanish (El Salvador)";                            "es-US" = "Spanish (United States)";                               "es-UY" = "Spanish (Uruguay)";                                                                                                                                            
        "es-VE" = "Spanish (Venezuela)";                              "et" = "Estonian";                                                 "et-EE" = "Estonian (Estonia)";                                                                                                                                            
        "eu" = "Basque";                                              "eu-ES" = "Basque (Basque)";                                       "ewo" = "Ewondo";                                                                                                                                            
        "ewo-CM" = "Ewondo (Cameroon)";                               "fa" = "Persian";                                                  "fa-IR" = "Persian (Iran)";                                                                                                                                            
        "ff" = "Fulah";                                               "ff-CM" = "Fulah (Cameroon)";                                      "ff-GN" = "Fulah (Guinea)";                                                                                                                                            
        "ff-Latn" = "Fulah (Latin)";                                  "ff-Latn-SN" = "Fulah (Latin, Senegal)";                           "ff-MR" = "Fulah (Mauritania)";                                                                                                                                            
        "ff-NG" = "Fulah (Nigeria)";                                  "fi" = "Finnish";                                                  "fi-FI" = "Finnish (Finland)";                                                                                                                                            
        "fil" = "Filipino";                                           "fil-PH" = "Filipino (Philippines)";                               "fo" = "Faroese";                                                                                                                                            
        "fo-DK" = "Faroese (Denmark)";                                "fo-FO" = "Faroese (Faroe Islands)";                               "fr" = "French";                                                                                                                                            
        "fr-029" = "French (Caribbean)";                              "fr-BE" = "French (Belgium)";                                      "fr-BF" = "French (Burkina Faso)";                                                                                                                                            
        "fr-BI" = "French (Burundi)";                                 "fr-BJ" = "French (Benin)";                                        "fr-BL" = "French (Saint Barthélemy)";                                                                                                                                            
        "fr-CA" = "French (Canada)";                                  "fr-CD" = "French (Congo DRC)";                                    "fr-CF" = "French (Central African Republic)";                                                                                                                                            
        "fr-CG" = "French (Congo)";                                   "fr-CH" = "French (Switzerland)";                                  "fr-CI" = "French (Côte d’Ivoire)";                                                                                                                                            
        "fr-CM" = "French (Cameroon)";                                "fr-DJ" = "French (Djibouti)";                                     "fr-DZ" = "French (Algeria)";                                                                                                                                            
        "fr-FR" = "French (France)";                                  "fr-GA" = "French (Gabon)";                                        "fr-GF" = "French (French Guiana)";                                                                                                                                            
        "fr-GN" = "French (Guinea)";                                  "fr-GP" = "French (Guadeloupe)";                                   "fr-GQ" = "French (Equatorial Guinea)";                                                                                                                                            
        "fr-HT" = "French (Haiti)";                                   "fr-KM" = "French (Comoros)";                                      "fr-LU" = "French (Luxembourg)";                                                                                                                                            
        "fr-MA" = "French (Morocco)";                                 "fr-MC" = "French (Monaco)";                                       "fr-MF" = "French (Saint Martin)";                                                                                                                                            
        "fr-MG" = "French (Madagascar)";                              "fr-ML" = "French (Mali)";                                         "fr-MQ" = "French (Martinique)";                                                                                                                                            
        "fr-MR" = "French (Mauritania)";                              "fr-MU" = "French (Mauritius)";                                    "fr-NC" = "French (New Caledonia)";                                                                                                                                            
        "fr-NE" = "French (Niger)";                                   "fr-PF" = "French (French Polynesia)";                             "fr-PM" = "French (Saint Pierre and Miquelon)";                                                                                                                                            
        "fr-RE" = "French (Reunion)";                                 "fr-RW" = "French (Rwanda)";                                       "fr-SC" = "French (Seychelles)";                                                                                                                                            
        "fr-SN" = "French (Senegal)";                                 "fr-SY" = "French (Syria)";                                        "fr-TD" = "French (Chad)";                                                                                                                                            
        "fr-TG" = "French (Togo)";                                    "fr-TN" = "French (Tunisia)";                                      "fr-VU" = "French (Vanuatu)";                                                                                                                                            
        "fr-WF" = "French (Wallis and Futuna)";                       "fr-YT" = "French (Mayotte)";                                      "fur" = "Friulian";                                                                                                                                            
        "fur-IT" = "Friulian (Italy)";                                "fy" = "Frisian";                                                  "fy-NL" = "Frisian (Netherlands)";                                                                                                                                            
        "ga" = "Irish";                                               "ga-IE" = "Irish (Ireland)";                                       "gd" = "Scottish Gaelic";                                                                                                                                            
        "gd-GB" = "Scottish Gaelic (United Kingdom)";                 "gl" = "Galician";                                                 "gl-ES" = "Galician (Galician)";                                                                                                                                            
        "gn" = "Guarani";                                             "gn-PY" = "Guarani (Paraguay)";                                    "gsw" = "Alsatian";                                                                                                                                            
        "gsw-CH" = "Alsatian (Switzerland)";                          "gsw-FR" = "Alsatian (France)";                                    "gsw-LI" = "Alsatian (Liechtenstein)";                                                                                                                                            
        "gu" = "Gujarati";                                            "gu-IN" = "Gujarati (India)";                                      "guz" = "Gusii";                                                                                                                                            
        "guz-KE" = "Gusii (Kenya)";                                   "gv" = "Manx";                                                     "gv-IM" = "Manx (Isle of Man)";                                                                                                                                            
        "ha" = "Hausa";                                               "ha-Latn" = "Hausa (Latin)";                                       "ha-Latn-GH" = "Hausa (Latin, Ghana)";                                                                                                                                            
        "ha-Latn-NE" = "Hausa (Latin, Niger)";                        "ha-Latn-NG" = "Hausa (Latin, Nigeria)";                           "haw" = "Hawaiian";                                                                                                                                            
        "haw-US" = "Hawaiian (United States)";                        "he" = "Hebrew";                                                   "he-IL" = "Hebrew (Israel)";                                                                                                                                            
        "hi" = "Hindi";                                               "hi-IN" = "Hindi (India)";                                         "hr" = "Croatian";                                                                                                                                            
        "hr-BA" = "Croatian (Latin, Bosnia and Herzegovina)";         "hr-HR" = "Croatian (Croatia)";                                    "hsb" = "Upper Sorbian";                                                                                                                                            
        "hsb-DE" = "Upper Sorbian (Germany)";                         "hu" = "Hungarian";                                                "hu-HU" = "Hungarian (Hungary)";                                                                                                                                            
        "hy" = "Armenian";                                            "hy-AM" = "Armenian (Armenia)";                                    "ia" = "Interlingua";                                                                                                                                            
        "ia-001" = "Interlingua (World)";                             "ia-FR" = "Interlingua (France)";                                  "ibb" = "Ibibio";                                                                                                                                            
        "ibb-NG" = "Ibibio (Nigeria)";                                "id" = "Indonesian";                                               "id-ID" = "Indonesian (Indonesia)";                                                                                                                                            
        "ig" = "Igbo";                                                "ig-NG" = "Igbo (Nigeria)";                                        "ii" = "Yi";                                                                                                                                            
        "ii-CN" = "Yi (PRC)";                                         "is" = "Icelandic";                                                "is-IS" = "Icelandic (Iceland)";                                                                                                                                            
        "it" = "Italian";                                             "it-CH" = "Italian (Switzerland)";                                 "it-IT" = "Italian (Italy)";                                                                                                                                            
        "it-SM" = "Italian (San Marino)";                             "it-VA" = "Italian (Vatican City)";                                "iu" = "Inuktitut";                                                                                                                                            
        "iu-Cans" = "Inuktitut (Syllabics)";                          "iu-Cans-CA" = "Inuktitut (Syllabics, Canada)";                    "iu-Latn" = "Inuktitut (Latin)";                                                                                                                                            
        "iu-Latn-CA" = "Inuktitut (Latin, Canada)";                   "ja" = "Japanese";                                                 "ja-JP" = "Japanese (Japan)";                                                                                                                                            
        "jgo" = "Ngomba";                                             "jgo-CM" = "Ngomba (Cameroon)";                                    "jmc" = "Machame";                                                                                                                                            
        "jmc-TZ" = "Machame (Tanzania)";                              "jv" = "Javanese";                                                 "jv-Java" = "Javanese (Javanese)";                                                                                                                                            
        "jv-Java-ID" = "Javanese (Javanese, Indonesia)";              "jv-Latn" = "Javanese";                                            "jv-Latn-ID" = "Javanese (Indonesia)";                                                                                                                                            
        "ka" = "Georgian";                                            "ka-GE" = "Georgian (Georgia)";                                    "kab" = "Kabyle";                                                                                                                                            
        "kab-DZ" = "Kabyle (Algeria)";                                "kam" = "Kamba";                                                   "kam-KE" = "Kamba (Kenya)";                                                                                                                                            
        "kde" = "Makonde";                                            "kde-TZ" = "Makonde (Tanzania)";                                   "kea" = "Kabuverdianu";                                                                                                                                            
        "kea-CV" = "Kabuverdianu (Cabo Verde)";                       "khq" = "Koyra Chiini";                                            "khq-ML" = "Koyra Chiini (Mali)";                                                                                                                                            
        "ki" = "Kikuyu";                                              "ki-KE" = "Kikuyu (Kenya)";                                        "kk" = "Kazakh";                                                                                                                                            
        "kk-KZ" = "Kazakh (Kazakhstan)";                              "kkj" = "Kako";                                                    "kkj-CM" = "Kako (Cameroon)";                                                                                                                                            
        "kl" = "Greenlandic";                                         "kl-GL" = "Greenlandic (Greenland)";                               "kln" = "Kalenjin";                                                                                                                                            
        "kln-KE" = "Kalenjin (Kenya)";                                "km" = "Khmer";                                                    "km-KH" = "Khmer (Cambodia)";                                                                                                                                            
        "kn" = "Kannada";                                             "kn-IN" = "Kannada (India)";                                       "ko" = "Korean";                                                                                                                                            
        "ko-KP" = "Korean (North Korea)";                             "ko-KR" = "Korean (Korea)";                                        "kok" = "Konkani";                                                                                                                                            
        "kok-IN" = "Konkani (India)";                                 "kr" = "Kanuri";                                                   "kr-NG" = "Kanuri (Nigeria)";                                                                                                                                            
        "ks" = "Kashmiri";                                            "ks-Arab" = "Kashmiri (Perso-Arabic)";                             "ks-Arab-IN" = "Kashmiri (Perso-Arabic)";                                                                                                                                            
        "ks-Deva" = "Kashmiri (Devanagari)";                          "ks-Deva-IN" = "Kashmiri (Devanagari, India)";                     "ksb" = "Shambala";                                                                                                                                            
        "ksb-TZ" = "Shambala (Tanzania)";                             "ksf" = "Bafia";                                                   "ksf-CM" = "Bafia (Cameroon)";                                                                                                                                            
        "ksh" = "Colognian";                                          "ksh-DE" = "Ripuarian (Germany)";                                  "ku" = "Central Kurdish";                                                                                                                                            
        "ku-Arab" = "Central Kurdish (Arabic)";                       "ku-Arab-IQ" = "Central Kurdish (Iraq)";                           "ku-Arab-IR" = "Kurdish (Perso-Arabic, Iran)";                                                                                                                                            
        "kw" = "Cornish";                                             "kw-GB" = "Cornish (United Kingdom)";                              "ky" = "Kyrgyz";                                                                                                                                            
        "ky-KG" = "Kyrgyz (Kyrgyzstan)";                              "la" = "Latin";                                                    "la-001" = "Latin (World)";                                                                                                                                            
        "lag" = "Langi";                                              "lag-TZ" = "Langi (Tanzania)";                                     "lb" = "Luxembourgish";                                                                                                                                            
        "lb-LU" = "Luxembourgish (Luxembourg)";                       "lg" = "Ganda";                                                    "lg-UG" = "Ganda (Uganda)";                                                                                                                                            
        "lkt" = "Lakota";                                             "lkt-US" = "Lakota (United States)";                               "ln" = "Lingala";                                                                                                                                            
        "ln-AO" = "Lingala (Angola)";                                 "ln-CD" = "Lingala (Congo DRC)";                                   "ln-CF" = "Lingala (Central African Republic)";                                                                                                                                            
        "ln-CG" = "Lingala (Congo)";                                  "lo" = "Lao";                                                      "lo-LA" = "Lao (Lao P.D.R.)";                                                                                                                                            
        "lrc" = "Northern Luri";                                      "lrc-IQ" = "Northern Luri (Iraq)";                                 "lrc-IR" = "Northern Luri (Iran)";                                                                                                                                            
        "lt" = "Lithuanian";                                          "lt-LT" = "Lithuanian (Lithuania)";                                "lu" = "Luba-Katanga";                                                                                                                                            
        "lu-CD" = "Luba-Katanga (Congo DRC)";                         "luo" = "Luo";                                                     "luo-KE" = "Luo (Kenya)";                                                                                                                                            
        "luy" = "Luyia";                                              "luy-KE" = "Luyia (Kenya)";                                        "lv" = "Latvian";                                                                                                                                            
        "lv-LV" = "Latvian (Latvia)";                                 "mas" = "Masai";                                                   "mas-KE" = "Masai (Kenya)";                                                                                                                                            
        "mas-TZ" = "Masai (Tanzania)";                                "mer" = "Meru";                                                    "mer-KE" = "Meru (Kenya)";                                                                                                                                            
        "mfe" = "Morisyen";                                           "mfe-MU" = "Morisyen (Mauritius)";                                 "mg" = "Malagasy";                                                                                                                                            
        "mg-MG" = "Malagasy (Madagascar)";                            "mgh" = "Makhuwa-Meetto";                                          "mgh-MZ" = "Makhuwa-Meetto (Mozambique)";                                                                                                                                            
        "mgo" = "Meta'";                                              "mgo-CM" = "Meta' (Cameroon)";                                     "mi" = "Maori";                                                                                                                                            
        "mi-NZ" = "Maori (New Zealand)";                              "mk" = "Macedonian (FYROM)";                                       "mk-MK" = "Macedonian (Former Yugoslav Republic of Macedonia)";                                                                                                                                            
        "ml" = "Malayalam";                                           "ml-IN" = "Malayalam (India)";                                     "mn" = "Mongolian";                                                                                                                                            
        "mn-Cyrl" = "Mongolian (Cyrillic)";                           "mn-MN" = "Mongolian (Cyrillic, Mongolia)";                        "mn-Mong" = "Mongolian (Traditional Mongolian)";                                                                                                                                            
        "mn-Mong-CN" = "Mongolian (Traditional Mongolian, PRC)";      "mn-Mong-MN" = "Mongolian (Traditional Mongolian, Mongolia)";      "mni" = "Manipuri";                                                                                                                                            
        "mni-IN" = "Manipuri (India)";                                "moh" = "Mohawk";                                                  "moh-CA" = "Mohawk (Mohawk)";                                                                                                                                            
        "mr" = "Marathi";                                             "mr-IN" = "Marathi (India)";                                       "ms" = "Malay";                                                                                                                                            
        "ms-BN" = "Malay (Brunei Darussalam)";                        "ms-MY" = "Malay (Malaysia)";                                      "ms-SG" = "Malay (Latin, Singapore)";                                                                                                                                            
        "mt" = "Maltese";                                             "mt-MT" = "Maltese (Malta)";                                       "mua" = "Mundang";                                                                                                                                            
        "mua-CM" = "Mundang (Cameroon)";                              "my" = "Burmese";                                                  "my-MM" = "Burmese (Myanmar)";                                                                                                                                            
        "mzn" = "Mazanderani";                                        "mzn-IR" = "Mazanderani (Iran)";                                   "naq" = "Nama";                                                                                                                                            
        "naq-NA" = "Nama (Namibia)";                                  "nb" = "Norwegian (Bokmål)";                                       "nb-NO" = "Norwegian, Bokmål (Norway)";                                                                                                                                            
        "nb-SJ" = "Norwegian, Bokmål (Svalbard and Jan Mayen)";       "nd" = "North Ndebele";                                            "nd-ZW" = "North Ndebele (Zimbabwe)";                                                                                                                                            
        "nds" = "Low German";                                         "nds-DE" = "Low German (Germany)";                                 "nds-NL" = "Low German (Netherlands)";                                                                                                                                            
        "ne" = "Nepali";                                              "ne-IN" = "Nepali (India)";                                        "ne-NP" = "Nepali (Nepal)";                                                                                                                                            
        "nl" = "Dutch";                                               "nl-AW" = "Dutch (Aruba)";                                         "nl-BE" = "Dutch (Belgium)";                                                                                                                                            
        "nl-BQ" = "Dutch (Bonaire, Sint Eustatius and Saba)";         "nl-CW" = "Dutch (Curaçao)";                                       "nl-NL" = "Dutch (Netherlands)";                                                                                                                                            
        "nl-SR" = "Dutch (Suriname)";                                 "nl-SX" = "Dutch (Sint Maarten)";                                  "nmg" = "Kwasio";                                                                                                                                            
        "nmg-CM" = "Kwasio (Cameroon)";                               "nn" = "Norwegian (Nynorsk)";                                      "nn-NO" = "Norwegian, Nynorsk (Norway)";                                                                                                                                            
        "nnh" = "Ngiemboon";                                          "nnh-CM" = "Ngiemboon (Cameroon)";                                 "no" = "Norwegian";                                                                                                                                            
        "nqo" = "N'ko";                                               "nqo-GN" = "N'ko (Guinea)";                                        "nr" = "South Ndebele";                                                                                                                                            
        "nr-ZA" = "South Ndebele (South Africa)";                     "nso" = "Sesotho sa Leboa";                                        "nso-ZA" = "Sesotho sa Leboa (South Africa)";                                                                                                                                            
        "nus" = "Nuer";                                               "nus-SS" = "Nuer (South Sudan)";                                   "nyn" = "Nyankole";                                                                                                                                            
        "nyn-UG" = "Nyankole (Uganda)";                               "oc" = "Occitan";                                                  "oc-FR" = "Occitan (France)";                                                                                                                                            
        "om" = "Oromo";                                               "om-ET" = "Oromo (Ethiopia)";                                      "om-KE" = "Oromo (Kenya)";                                                                                                                                            
        "or" = "Odia";                                                "or-IN" = "Odia (India)";                                          "os" = "Ossetic";                                                                                                                                            
        "os-GE" = "Ossetian (Cyrillic, Georgia)";                     "os-RU" = "Ossetian (Cyrillic, Russia)";                           "pa" = "Punjabi";                                                                                                                                            
        "pa-Arab" = "Punjabi (Arabic)";                               "pa-Arab-PK" = "Punjabi (Islamic Republic of Pakistan)";           "pa-IN" = "Punjabi (India)";                                                                                                                                            
        "pap" = "Papiamento";                                         "pap-029" = "Papiamento (Caribbean)";                              "pl" = "Polish";                                                                                                                                            
        "pl-PL" = "Polish (Poland)";                                  "prg" = "Prussian";                                                "prg-001" = "Prussian (World)";                                                                                                                                            
        "prs" = "Dari";                                               "prs-AF" = "Dari (Afghanistan)";                                   "ps" = "Pashto";                                                                                                                                            
        "ps-AF" = "Pashto (Afghanistan)";                             "pt" = "Portuguese";                                               "pt-AO" = "Portuguese (Angola)";                                                                                                                                            
        "pt-BR" = "Portuguese (Brazil)";                              "pt-CH" = "Portuguese (Switzerland)";                              "pt-CV" = "Portuguese (Cabo Verde)";                                                                                                                                            
        "pt-GQ" = "Portuguese (Equatorial Guinea)";                   "pt-GW" = "Portuguese (Guinea-Bissau)";                            "pt-LU" = "Portuguese (Luxembourg)";                                                                                                                                            
        "pt-MO" = "Portuguese (Macao SAR)";                           "pt-MZ" = "Portuguese (Mozambique)";                               "pt-PT" = "Portuguese (Portugal)";                                                                                                                                            
        "pt-ST" = "Portuguese (São Tomé and Príncipe)";               "pt-TL" = "Portuguese (Timor-Leste)";                              "quc" = "K'iche'";                                                                                                                                            
        "quc-Latn" = "K'iche'";                                       "quc-Latn-GT" = "K'iche' (Guatemala)";                             "quz" = "Quechua";                                                                                                                                            
        "quz-BO" = "Quechua (Bolivia)";                               "quz-EC" = "Quechua (Ecuador)";                                    "quz-PE" = "Quechua (Peru)";                                                                                                                                            
        "rm" = "Romansh";                                             "rm-CH" = "Romansh (Switzerland)";                                 "rn" = "Rundi";                                                                                                                                            
        "rn-BI" = "Rundi (Burundi)";                                  "ro" = "Romanian";                                                 "ro-MD" = "Romanian (Moldova)";                                                                                                                                            
        "ro-RO" = "Romanian (Romania)";                               "rof" = "Rombo";                                                   "rof-TZ" = "Rombo (Tanzania)";                                                                                                                                            
        "ru" = "Russian";                                             "ru-BY" = "Russian (Belarus)";                                     "ru-KG" = "Russian (Kyrgyzstan)";                                                                                                                                            
        "ru-KZ" = "Russian (Kazakhstan)";                             "ru-MD" = "Russian (Moldova)";                                     "ru-RU" = "Russian (Russia)";                                                                                                                                            
        "ru-UA" = "Russian (Ukraine)";                                "rw" = "Kinyarwanda";                                              "rw-RW" = "Kinyarwanda (Rwanda)";                                                                                                                                            
        "rwk" = "Rwa";                                                "rwk-TZ" = "Rwa (Tanzania)";                                       "sa" = "Sanskrit";                                                                                                                                            
        "sa-IN" = "Sanskrit (India)";                                 "sah" = "Sakha";                                                   "sah-RU" = "Sakha (Russia)";                                                                                                                                            
        "saq" = "Samburu";                                            "saq-KE" = "Samburu (Kenya)";                                      "sbp" = "Sangu";                                                                                                                                            
        "sbp-TZ" = "Sangu (Tanzania)";                                "sd" = "Sindhi";                                                   "sd-Arab" = "Sindhi (Arabic)";                                                                                                                                            
        "sd-Arab-PK" = "Sindhi (Islamic Republic of Pakistan)";       "sd-Deva" = "Sindhi (Devanagari)";                                 "sd-Deva-IN" = "Sindhi (Devanagari, India)";                                                                                                                                            
        "se" = "Sami (Northern)";                                     "se-FI" = "Sami, Northern (Finland)";                              "se-NO" = "Sami, Northern (Norway)";                                                                                                                                            
        "se-SE" = "Sami, Northern (Sweden)";                          "seh" = "Sena";                                                    "seh-MZ" = "Sena (Mozambique)";                                                                                                                                            
        "ses" = "Koyraboro Senni";                                    "ses-ML" = "Koyraboro Senni (Mali)";                               "sg" = "Sango";                                                                                                                                            
        "sg-CF" = "Sango (Central African Republic)";                 "shi" = "Tachelhit";                                               "shi-Latn" = "Tachelhit (Latin)";                                                                                                                                            
        "shi-Latn-MA" = "Tachelhit (Latin, Morocco)";                 "shi-Tfng" = "Tachelhit (Tifinagh)";                               "shi-Tfng-MA" = "Tachelhit (Tifinagh, Morocco)";                                                                                                                                            
        "si" = "Sinhala";                                             "si-LK" = "Sinhala (Sri Lanka)";                                   "sk" = "Slovak";                                                                                                                                            
        "sk-SK" = "Slovak (Slovakia)";                                "sl" = "Slovenian";                                                "sl-SI" = "Slovenian (Slovenia)";                                                                                                                                            
        "sma" = "Sami (Southern)";                                    "sma-NO" = "Sami, Southern (Norway)";                              "sma-SE" = "Sami, Southern (Sweden)";                                                                                                                                            
        "smj" = "Sami (Lule)";                                        "smj-NO" = "Sami, Lule (Norway)";                                  "smj-SE" = "Sami, Lule (Sweden)";                                                                                                                                            
        "smn" = "Sami (Inari)";                                       "smn-FI" = "Sami, Inari (Finland)";                                "sms" = "Sami (Skolt)";                                                                                                                                            
        "sms-FI" = "Sami, Skolt (Finland)";                           "sn" = "Shona";                                                    "sn-Latn" = "Shona (Latin)";                                                                                                                                            
        "sn-Latn-ZW" = "Shona (Latin, Zimbabwe)";                     "so" = "Somali";                                                   "so-DJ" = "Somali (Djibouti)";                                                                                                                                            
        "so-ET" = "Somali (Ethiopia)";                                "so-KE" = "Somali (Kenya)";                                        "so-SO" = "Somali (Somalia)";                                                                                                                                            
        "sq" = "Albanian";                                            "sq-AL" = "Albanian (Albania)";                                    "sq-MK" = "Albanian (Macedonia, FYRO)";                                                                                                                                            
        "sq-XK" = "Albanian (Kosovo)";                                "sr" = "Serbian";                                                  "sr-Cyrl" = "Serbian (Cyrillic)";                                                                                                                                            
        "sr-Cyrl-BA" = "Serbian (Cyrillic, Bosnia and Herzegovina)";  "sr-Cyrl-ME" = "Serbian (Cyrillic, Montenegro)";                   "sr-Cyrl-RS" = "Serbian (Cyrillic, Serbia)";                                                                                                                                            
        "sr-Cyrl-XK" = "Serbian (Cyrillic, Kosovo)";                  "sr-Latn" = "Serbian (Latin)";                                     "sr-Latn-BA" = "Serbian (Latin, Bosnia and Herzegovina)";                                                                                                                                            
        "sr-Latn-ME" = "Serbian (Latin, Montenegro)";                 "sr-Latn-RS" = "Serbian (Latin, Serbia)";                          "sr-Latn-XK" = "Serbian (Latin, Kosovo)";                                                                                                                                            
        "ss" = "Swati";                                               "ss-SZ" = "Swati (Eswatini former Swaziland)";                     "ss-ZA" = "Swati (South Africa)";                                                                                                                                            
        "ssy" = "Saho";                                               "ssy-ER" = "Saho (Eritrea)";                                       "st" = "Southern Sotho";                                                                                                                                            
        "st-LS" = "Sesotho (Lesotho)";                                "st-ZA" = "Southern Sotho (South Africa)";                         "sv" = "Swedish";                                                                                                                                            
        "sv-AX" = "Swedish (Åland Islands)";                          "sv-FI" = "Swedish (Finland)";                                     "sv-SE" = "Swedish (Sweden)";                                                                                                                                            
        "sw" = "Kiswahili";                                           "sw-CD" = "Kiswahili (Congo DRC)";                                 "sw-KE" = "Kiswahili (Kenya)";                                                                                                                                            
        "sw-TZ" = "Kiswahili (Tanzania)";                             "sw-UG" = "Kiswahili (Uganda)";                                    "syr" = "Syriac";                                                                                                                                            
        "syr-SY" = "Syriac (Syria)";                                  "ta" = "Tamil";                                                    "ta-IN" = "Tamil (India)";                                                                                                                                            
        "ta-LK" = "Tamil (Sri Lanka)";                                "ta-MY" = "Tamil (Malaysia)";                                      "ta-SG" = "Tamil (Singapore)";                                                                                                                                            
        "te" = "Telugu";                                              "te-IN" = "Telugu (India)";                                        "teo" = "Teso";                                                                                                                                            
        "teo-KE" = "Teso (Kenya)";                                    "teo-UG" = "Teso (Uganda)";                                        "tg" = "Tajik";                                                                                                                                            
        "tg-Cyrl" = "Tajik (Cyrillic)";                               "tg-Cyrl-TJ" = "Tajik (Cyrillic, Tajikistan)";                     "th" = "Thai";                                                                                                                                            
        "th-TH" = "Thai (Thailand)";                                  "ti" = "Tigrinya";                                                 "ti-ER" = "Tigrinya (Eritrea)";                                                                                                                                            
        "ti-ET" = "Tigrinya (Ethiopia)";                              "tig" = "Tigre";                                                   "tig-ER" = "Tigre (Eritrea)";                                                                                                                                            
        "tk" = "Turkmen";                                             "tk-TM" = "Turkmen (Turkmenistan)";                                "tn" = "Setswana";                                                                                                                                            
        "tn-BW" = "Setswana (Botswana)";                              "tn-ZA" = "Setswana (South Africa)";                               "to" = "Tongan";                                                                                                                                            
        "to-TO" = "Tongan (Tonga)";                                   "tr" = "Turkish";                                                  "tr-CY" = "Turkish (Cyprus)";                                                                                                                                            
        "tr-TR" = "Turkish (Turkey)";                                 "ts" = "Tsonga";                                                   "ts-ZA" = "Tsonga (South Africa)";                                                                                                                                            
        "tt" = "Tatar";                                               "tt-RU" = "Tatar (Russia)";                                        "twq" = "Tasawaq";                                                                                                                                            
        "twq-NE" = "Tasawaq (Niger)";                                 "tzm" = "Tamazight";                                               "tzm-Arab" = "Central Atlas Tamazight (Arabic)";                                                                                                                                            
        "tzm-Arab-MA" = "Central Atlas Tamazight (Arabic, Morocco)";  "tzm-Latn" = "Tamazight (Latin)";                                  "tzm-Latn-DZ" = "Tamazight (Latin, Algeria)";                                                                                                                                            
        "tzm-Latn-MA" = "Central Atlas Tamazight (Latin, Morocco)";   "tzm-Tfng" = "Tamazight (Tifinagh)";                               "tzm-Tfng-MA" = "Central Atlas Tamazight (Tifinagh, Morocco)";                                                                                                                                            
        "ug" = "Uyghur";                                              "ug-CN" = "Uyghur (PRC)";                                          "uk" = "Ukrainian";                                                                                                                                            
        "uk-UA" = "Ukrainian (Ukraine)";                              "ur" = "Urdu";                                                     "ur-IN" = "Urdu (India)";                                                                                                                                            
        "ur-PK" = "Urdu (Islamic Republic of Pakistan)";              "uz" = "Uzbek";                                                    "uz-Arab" = "Uzbek (Perso-Arabic)";                                                                                                                                            
        "uz-Arab-AF" = "Uzbek (Perso-Arabic, Afghanistan)";           "uz-Cyrl" = "Uzbek (Cyrillic)";                                    "uz-Cyrl-UZ" = "Uzbek (Cyrillic, Uzbekistan)";                                                                                                                                            
        "uz-Latn" = "Uzbek (Latin)";                                  "uz-Latn-UZ" = "Uzbek (Latin, Uzbekistan)";                        "vai" = "Vai";                                                                                                                                            
        "vai-Latn" = "Vai (Latin)";                                   "vai-Latn-LR" = "Vai (Latin, Liberia)";                            "vai-Vaii" = "Vai (Vai)";                                                                                                                                            
        "vai-Vaii-LR" = "Vai (Vai, Liberia)";                         "ve" = "Venda";                                                    "ve-ZA" = "Venda (South Africa)";                                                                                                                                            
        "vi" = "Vietnamese";                                          "vi-VN" = "Vietnamese (Vietnam)";                                  "vo" = "Volapük";                                                                                                                                            
        "vo-001" = "Volapük (World)";                                 "vun" = "Vunjo";                                                   "vun-TZ" = "Vunjo (Tanzania)";                                                                                                                                            
        "wae" = "Walser";                                             "wae-CH" = "Walser (Switzerland)";                                 "wal" = "Wolaytta";                                                                                                                                            
        "wal-ET" = "Wolaytta (Ethiopia)";                             "wo" = "Wolof";                                                    "wo-SN" = "Wolof (Senegal)";                                                                                                                                            
        "xh" = "isiXhosa";                                            "xh-ZA" = "isiXhosa (South Africa)";                               "xog" = "Soga";                                                                                                                                            
        "xog-UG" = "Soga (Uganda)";                                   "yav" = "Yangben";                                                 "yav-CM" = "Yangben (Cameroon)";                                                                                                                                            
        "yi" = "Yiddish";                                             "yi-001" = "Yiddish (World)";                                      "yo" = "Yoruba";                                                                                                                                            
        "yo-BJ" = "Yoruba (Benin)";                                   "yo-NG" = "Yoruba (Nigeria)";                                      "zgh" = "Standard Moroccan Tamazight";                                                                                                                                            
        "zgh-Tfng" = "Standard Moroccan Tamazight (Tifinagh)";        "zgh-Tfng-MA" = "Standard Moroccan Tamazight (Tifinagh, Morocco)"; "zh" = "Chinese";                                                                                                                                            
        "zh-CN" = "Chinese (Simplified, PRC)";                        "zh-Hans" = "Chinese (Simplified)";                                "zh-Hans-HK" = "Chinese (Simplified Han, Hong Kong SAR)";                                                                                                                                            
        "zh-Hans-MO" = "Chinese (Simplified Han, Macao SAR)";         "zh-Hant" = "Chinese (Traditional)";                               "zh-HK" = "Chinese (Traditional, Hong Kong S.A.R.)";                                                                                                                                            
        "zh-MO" = "Chinese (Traditional, Macao S.A.R.)";              "zh-SG" = "Chinese (Simplified, Singapore)";                       "zh-TW" = "Chinese (Traditional, Taiwan)";                                                                                                                                            
        "zu" = "isiZulu";                                             "zu-ZA" = "isiZulu (South Africa)"
    }

    # Get the current user's language and region using the registry
    $Region = $localeLookup[(Get-ItemProperty -Path "HKCU:Control Panel\International\Geo").Nation]
    # Iterate through registry key in case multiple languages are configured
    (Get-ItemProperty -Path "HKCU:Control Panel\International\User Profile").Languages | ForEach-Object {
        $Languages += " - $($languageLookup[$_])"
    }

    if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") {
        return @{
            title   = "ロケール      "
            icon    = "├─  "
            content = "$Region$($Languages -join ', ')"
        }
    } elseif ($info_language -eq "en") {
        return @{
            title   = "Locale        "
            icon    = "├─  "
            content = "$Region$($Languages -join ', ')"
        }
    }
}

# ===== IMT KEYBOARD LAYOUT =====
# Wanted it to show the actual name, and not just the IMT numbers. Haven't figured that out yet.
function info_layout {
    $keyboardLayout = (Get-WinUserLanguageList)[0].InputMethodTips[0]
    return @{
        title   = if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") { "キーボード    " } elseif ($info_language -eq "en") { "Keyboard      " }
        icon    = "├─  "
        content = "$keyboardLayout (IMT)"
    }
}


# ===== LOCAL_IP =====
function info_local_ip {
    try {
        # Get all network adapters
        foreach ($ni in [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
            # Get the IP information of each adapter
            $properties = $ni.GetIPProperties()
            # Check if the adapter is online, has a gateway address, and the adapter does not have a loopback address
            if ($ni.OperationalStatus -eq 'Up' -and !($null -eq $properties.GatewayAddresses[0]) -and !$properties.GatewayAddresses[0].Address.ToString().Equals("0.0.0.0")) {
                # Check if adapter is a WiFi or Ethernet adapter
                if ($ni.NetworkInterfaceType -eq "Wireless80211" -or $ni.NetworkInterfaceType -eq "Ethernet") {
                    foreach ($ip in $properties.UnicastAddresses) {
                        if ($ip.Address.AddressFamily -eq "InterNetwork") {
                            if (!$local_ip) { $local_ip = $ip.Address.ToString() }
                        }
                    }
                }
            }
        }
    } catch {
    }
    return @{
        title   = if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") { "ローカル IP   " } elseif ($info_language -eq "en") { "Local IP      " }
        icon    = "├─󰩠  "
        content = if (-not $local_ip) {
            "$e[91m(Unknown)"
        } else {
            $local_ip
        }
    }
}


# ===== PUBLIC_IP =====
function info_public_ip {
    return @{
        title   = if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") { "パブリック IP " } elseif ($info_language -eq "en") { "Public IP     " }
        icon    = "├─  "
        content = try {
            Invoke-RestMethod ifconfig.me/ip
        } catch {
            "$e[91m(Network Error)"
        }
    }
}


# ===== REDACTED_IP =====
function info_redacted_ip {
    return @{
        title   = if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") { "伏字 IP       " } elseif ($info_language -eq "en") { "Redacted IP   " }
        icon    = "├─  "
        content = "▉▉▉.▉▉.▉▉▉.▉▉"
    }
}


# ===== WEATHER =====
function info_weather {
    return @{
        title   = if ([string]::IsNullOrEmpty($info_language) -or $info_language -eq "jp") { "位置情報      " } elseif ($info_language -eq "en") { "Weather       " }
        icon    = "├─󰖐  "
        content = try {
            (Invoke-RestMethod wttr.in/?format="%t+-+%C+(%l)").TrimStart("+")
        } catch {
            "$e[91m(Network Error)"
        }
    }
}





############################
#  THE REST OF THE SCRIPT  #
############################

if (-not $stripansi) {
    # unhide the cursor after a terminating error
    trap { "$e[?25h"; break }

    # reset terminal sequences and display a newline
    Write-Output "$e[0m$e[?25l"
} else {
    Write-Output ""
}

# write logo
if (-not $stripansi) {
    foreach ($line in $img) {
        Write-Output " $line"
    }
}

$GAP = 3
$writtenLines = 0
$freeSpace = $Host.UI.RawUI.WindowSize.Width - 1

# move cursor to top of image and to its right
if ($img -and -not $stripansi) {
    $freeSpace -= 1 + $COLUMNS + $GAP
    Write-Output "$e[$($img.Length + 1)A"
}

# write info
foreach ($item in $config) {
    if (Test-Path Function:"info_$item") {
        $info = & "info_$item"
    } else {
        $info = @{ title = "$e[31mfunction 'info_$item' not found" }
    }

    if (-not $info) {
        continue
    }

    if ($info -isnot [array]) {
        $info = @($info)
    }

    foreach ($line in $info) {
        $output = "$e[1;37m$($line["icon"])$e[0m"   #note: printing icons

        if ($line["icon"] -and $line["title"]) {
            $output += "  "
        }
        $output += "$e[1;31m$($line["title"])$e[0m" #note: items colors

        if ($line["title"] -and $line["content"]) {
            $output += ": "
        }

        $output += "$($line["content"])"

        if ($img) {
            if (-not $stripansi) {
                # move cursor to right of image
                $output = "$e[$(2 + $COLUMNS + $GAP)G$output"
            } else {
                # write image progressively
                $imgline = ("$($img[$writtenLines])"  -replace $ansiRegex, "").PadRight($COLUMNS)
                $output = " $imgline   $output"
            }
        }

        $writtenLines++

        if ($stripansi) {
            $output = $output -replace $ansiRegex, ""
            if ($output.Length -gt $freeSpace) {
                $output = $output.Substring(0, $output.Length - ($output.Length - $freeSpace))
            }
        } else {
            $output = truncate_line $output $freeSpace
        }

        Write-Output $output
    }
}

if ($stripansi) {
    # write out remaining image lines
    for ($i = $writtenLines; $i -lt $img.Length; $i++) {
        $imgline = ("$($img[$i])"  -replace $ansiRegex, "").PadRight($COLUMNS)
        Write-Output " $imgline"
    }
}

# move cursor back to the bottom and print 2 newlines
if (-not $stripansi) {
    $diff = $img.Length - $writtenLines
    if ($img -and $diff -gt 0) {
        Write-Output "$e[${diff}B"
    } else {
        Write-Output ""
    }
    Write-Output "$e[?25h"
} else {
    Write-Output "`n"
}
#  ___ ___  ___
# | __/ _ \| __|
# | _| (_) | _|
# |___\___/|_|
#
