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

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version 2.0

if (-not $BaseImage) {
    $BaseImage = $(& $PSScriptRoot/get-base-image.ps1 -DockerfilePath $DockerfilePath -BaseStageName $BaseStageName -TargetImage $targetImage -Architecture $Architecture)
}

$result = $(& $PSScriptRoot/check-image.ps1 -TargetImage $targetImage -BaseImage $BaseImage -Architecture $Architecture -DockerfilePath $DockerfilePath)

return $result
