[cmdletbinding()]
param(
    [Parameter(Mandatory = $True)]
    [string]$TargetImage,

    [Parameter(Mandatory = $True)]
    [string]$BaseImage,

    [Parameter(Mandatory = $True)]
    [string]$Architecture
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version 2.0

Import-Module $PSScriptRoot/common.psm1

$cmd = "dredge image compare layers --output json $BaseImage $TargetImage --os linux --arch $Architecture"
$layerComparisonStr = $(InvokeTool $cmd "dredge image compare failed")

$layerComparison = $layerComparisonStr | ConvertFrom-Json

$imageUpToDate = [bool]$($layerComparison.summary.targetIncludesAllBaseLayers)
$sendDispatch = ([string](-not $imageUpToDate)).ToLower()

LogMessage "Send dispatch: $sendDispatch"

return $sendDispatch
