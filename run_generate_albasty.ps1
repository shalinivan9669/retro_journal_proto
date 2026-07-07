$ErrorActionPreference = "Stop"

Write-Host "[Albasty] Generating low-poly model with Blender..."

$blenderCommand = Get-Command blender -ErrorAction SilentlyContinue
if ($blenderCommand) {
    $blender = $blenderCommand.Source
} else {
    $candidatePaths = @()

    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($registryPath in $registryPaths) {
        Get-ItemProperty $registryPath -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*Blender*" -and $_.InstallLocation } |
            ForEach-Object { $candidatePaths += Join-Path $_.InstallLocation "blender.exe" }
    }

    $typicalRoots = @(
        "C:\Program Files\Blender Foundation",
        "C:\Program Files",
        "C:\Program Files (x86)",
        "$env:LOCALAPPDATA\Programs",
        "S:\blender"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    foreach ($root in $typicalRoots) {
        Get-ChildItem -LiteralPath $root -Recurse -Filter blender.exe -ErrorAction SilentlyContinue |
            ForEach-Object { $candidatePaths += $_.FullName }
    }

    $blenderFile = $candidatePaths |
        Select-Object -Unique |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        ForEach-Object { Get-Item -LiteralPath $_ } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $blenderFile) {
        throw "Blender executable not found. Add blender to PATH or install Blender in a standard location."
    }

    $blender = $blenderFile.FullName
}

Write-Host "[Albasty] Blender: $blender"
$script = Join-Path $PSScriptRoot "blender_scripts/create_albasty_lowpoly.py"

if (-not (Test-Path $script)) {
    throw "Script not found: $script"
}

& $blender --background --python $script

$out = Join-Path $PSScriptRoot "assets/models/albasty_lowpoly.glb"
if (-not (Test-Path $out)) {
    throw "GLB was not created: $out"
}

Write-Host "[Albasty] Done: $out"
