[cmdletbinding()]
param(
    [Parameter(Mandatory = $True)]
    [string]$TargetImage,

    [Parameter(Mandatory = $True)]
    [string]$BaseImage,

    [Parameter(Mandatory = $True)]
    [string]$Architecture,

    [string]$DockerfilePath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version 2.0

function GetDigest($imageName) {
    $digestCmd = "dredge manifest resolve $imageName --os linux --arch $Architecture"
    $digest = $(InvokeTool $digestCmd)
    return $digest
}

Import-Module $PSScriptRoot/common.psm1

$compareCmd = "dredge image compare layers --output json $BaseImage $TargetImage --os linux --arch $Architecture"
$layerComparisonStr = $(InvokeTool $compareCmd)
$layerComparison = $layerComparisonStr | ConvertFrom-Json

$imageUpToDate = [bool]$($layerComparison.summary.targetIncludesAllBaseLayers)
$sendDispatch = ([string](-not $imageUpToDate)).ToLower()

$targetDigest = $(GetDigest $TargetImage)
$baseDigest = $(GetDigest $BaseImage)

LogMessage "Send dispatch: $sendDispatch"

$updates = @()
if (-not $imageUpToDate) {
    $updates += @{
        targetImageName = $TargetImage
        targetImageDigest = $targetDigest
        dockerfile = $DockerfilePath
        baseImageName = $BaseImage
        baseImageDigest = $baseDigest
    }
}

$result = @{
    sendDispatch = $sendDispatch
    updates = $updates
} | ConvertTo-Json

return $result
