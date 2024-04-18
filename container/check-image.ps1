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

function LogMessage ($Message) {
    Write-Output $Message | Out-File $env:HOME/log.txt -Append
}

$expr = "dredge image compare layers --output json $BaseImage $TargetImage --os linux --arch $Architecture"
LogMessage "Invoke: $expr"
$result = Invoke-Expression $expr
$dredgeExitCode = $LASTEXITCODE
LogMessage "Result: $result"
if ($dredgeExitCode -ne 0) {
    throw "dredge image compare failed"
}

$result = $result | ConvertFrom-Json

$imageUpToDate = [bool]$($result.summary.targetIncludesAllBaseLayers)
$sendDispatch = ([string](-not $imageUpToDate)).ToLower()

LogMessage "Send dispatch: $sendDispatch"

return $sendDispatch
