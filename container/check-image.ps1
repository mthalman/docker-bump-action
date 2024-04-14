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

$result = Invoke-Expression "dredge image compare layers --output json $BaseImage $TargetImage --os linux --arch $Architecture" | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    throw "dredge image compare failed"
}

$imageUpToDate = [bool]$($result.Summary.TargetIncludesAllBaseLayers)
$triggerWorkflow = ([string](-not $imageUpToDate)).ToLower()

return $triggerWorkflow
