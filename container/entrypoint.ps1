[cmdletbinding()]
param(
    [Parameter(Mandatory = $True)]
    [string]$TargetImage,

    [string]$BaseImage,

    [string]$DockerfilePath,

    [string]$BaseStageName,

    [Parameter(Mandatory = $True)]
    [string]$Architecture
)

if (-not $baseImage) {
    $baseImage = $(& $PSScriptRoot/get-base-image.ps1 -DockerfilePath $DockerfilePath -BaseStageName $BaseStageName)
}

$triggerWorkflow = $(& $PSScriptRoot/check-image.ps1 -TargetImage $targetImage -BaseImage $baseImage -Architecture $Architecture)
return $triggerWorkflow
