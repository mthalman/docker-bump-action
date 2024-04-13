[cmdletbinding()]
param(
    [Parameter(Mandatory = $True)]
    [string]$TargetImage,

    [Parameter(Mandatory = $True)]
    [string]$BaseImage,

    [Parameter(Mandatory = $True)]
    [string]$Architecture
)

$result = dredge image compare layers --output json $BaseImage $TargetImage --os linux --arch $Architecture | ConvertFrom-Json
$value = "$($result.Summary.TargetIncludesAllBaseLayers)".ToLower()
return $value
