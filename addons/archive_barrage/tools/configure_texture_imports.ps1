param(
    [string]$AddonRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$assetsRoot = Join-Path $AddonRoot 'assets'

if (-not (Test-Path -LiteralPath $assetsRoot)) {
    throw "Archive Barrage assets were not found: $assetsRoot"
}

$runtimeImports = Get-ChildItem -LiteralPath $assetsRoot -Recurse -File |
    Where-Object {
        $_.Name.EndsWith('.import') -and
        $_.FullName -notlike '*\generated\preview\*'
    }

foreach ($importFile in $runtimeImports) {
    $text = [IO.File]::ReadAllText($importFile.FullName)
    $text = $text -replace 'compress/mode=\d+', 'compress/mode=2'
    $text = $text -replace 'compress/high_quality=(true|false)', 'compress/high_quality=true'
    $text = $text -replace 'mipmaps/generate=(true|false)', 'mipmaps/generate=true'
    $text = $text -replace 'detect_3d/compress_to=\d+', 'detect_3d/compress_to=0'

    if ($importFile.Name -match 'normal(_gl)?') {
        $text = $text -replace 'compress/normal_map=\d+', 'compress/normal_map=1'
    }

    [IO.File]::WriteAllText($importFile.FullName, $text, $utf8NoBom)
}

# The terrain heightmap is sampled on the CPU at runtime. Preserve its 16-bit
# source precision and avoid mip filtering for deterministic player placement.
$terrainHeightImport = Join-Path $assetsRoot 'generated\terrain\barrage_hill_height_2k.png.import'
if (Test-Path -LiteralPath $terrainHeightImport) {
    $text = [IO.File]::ReadAllText($terrainHeightImport)
    $text = $text -replace 'compress/mode=\d+', 'compress/mode=0'
    $text = $text -replace 'compress/high_quality=(true|false)', 'compress/high_quality=false'
    $text = $text -replace 'mipmaps/generate=(true|false)', 'mipmaps/generate=false'
    $text = $text -replace 'detect_3d/compress_to=\d+', 'detect_3d/compress_to=0'
    [IO.File]::WriteAllText($terrainHeightImport, $text, $utf8NoBom)
}

Write-Output "Configured $($runtimeImports.Count) Archive Barrage texture imports."
