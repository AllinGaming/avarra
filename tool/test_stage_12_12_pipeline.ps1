[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$buildRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot 'build'))
$proofRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $buildRoot "stage_12_12_e2e_$PID")
)

if (-not $proofRoot.StartsWith($buildRoot + [System.IO.Path]::DirectorySeparatorChar)) {
    throw "Refusing to use proof directory outside build: $proofRoot"
}
try {
    $forgeDirectory = Join-Path $proofRoot 'forge'
    $deliveryDirectory = Join-Path $proofRoot 'delivery'
    $catalogDirectory = Join-Path $proofRoot 'catalog'
    $gameDirectory = Join-Path $repositoryRoot 'apps/avarra_game'
    $exportPath = Join-Path $forgeDirectory 'champion-mission.avarra'
    $deliveryPath = Join-Path $deliveryDirectory 'champion-mission.avarra'
    New-Item -ItemType Directory -Force $forgeDirectory | Out-Null
    New-Item -ItemType Directory -Force $deliveryDirectory | Out-Null

    Push-Location $repositoryRoot
    try {
        & dart run apps/avarra_forge/bin/export_profiled_mission.dart $exportPath
        if ($LASTEXITCODE -ne 0) {
            throw "Forge profiled mission export failed with exit code $LASTEXITCODE"
        }
        Move-Item -LiteralPath $exportPath -Destination $deliveryPath
        & dart run apps/avarra_game/bin/runtime_import_proof.dart `
            $deliveryPath $catalogDirectory $gameDirectory
        if ($LASTEXITCODE -ne 0) {
            throw "Game profiled mission import failed with exit code $LASTEXITCODE"
        }
        Remove-Item -LiteralPath $deliveryPath
        & dart run apps/avarra_game/bin/runtime_import_proof.dart `
            --load-selected $catalogDirectory $gameDirectory
        if ($LASTEXITCODE -ne 0) {
            throw "Game profiled mission restart load failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}
finally {
    if (Test-Path -LiteralPath $proofRoot) {
        $resolvedProofRoot = [System.IO.Path]::GetFullPath($proofRoot)
        if (-not $resolvedProofRoot.StartsWith(
            $buildRoot + [System.IO.Path]::DirectorySeparatorChar
        )) {
            throw "Refusing to remove proof directory outside build: $resolvedProofRoot"
        }
        Remove-Item -LiteralPath $resolvedProofRoot -Recurse -Force
    }
}
