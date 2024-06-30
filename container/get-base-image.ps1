[cmdletbinding()]
param(
    [string]$DockerfilePath,
    [string]$BaseStageName,
    [string]$TargetImage,
    [string]$Architecture
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version 2.0

Import-Module $PSScriptRoot/common.psm1

function GetBaseImageFromDockerfile() {
    $dfspyArgs = @(
        'query',
        'from',
        '-f',
        $DockerfilePath
    )

    # If a stage name is provided we can directly filter the list-based output of the "query from" command.
    # Otherwise, we need to derive the base image by finding the last stage of the Dockerfile and walking
    # its parent chain. To do that, we need the graph layout.

    if (-not $BaseStageName) {
        LogMessage 'Stage name not provided. Will derive base image by walking parent chain.'
        $dfspyArgs += '--layout'
        $dfspyArgs += 'graph'
    }

    $dfspyArgsString = $dfspyArgs -join ' '

    $cmd = "dfspy $dfspyArgsString"
    $fromOutput = $(InvokeTool $cmd)
    $fromOutput = $fromOutput | ConvertFrom-Json

    if ($BaseStageName) {
        $baseImage = $fromOutput | Where-Object { $_.PSObject.Properties.Name -contains "stageName" -and $_.stageName -eq $BaseStageName } | Select-Object -ExpandProperty imageName
        if (-not $baseImage) {
            throw "Could not find stage with name '$BaseStageName'."
        }
    } else {
        # Find the last stage of the Dockerfile and walk its parent chain to find the base image
        $currentNode = $fromOutput | Select-Object -Last 1

        LogMessage "Deriving base image by walking parent chain from '$($currentNode.fromInstruction.imageName)'."

        while ($currentNode.PSObject.Properties.Name -contains "parent") {
            $currentNode = $currentNode.parent
        }

        $baseImage = $currentNode.fromInstruction.imageName
    }

    return $baseImage
}

function GetBaseImageFromAnnotation() {
    $baseNameAnnotationKey = "org.opencontainers.image.base.name"
    # Check whether a LABEL exists for the OCI annotation key
    $inspectOutput = $(InvokeTool "dredge image inspect $TargetImage --os linux --arch $Architecture") | ConvertFrom-Json
    Set-StrictMode -Off
    if ($inspectOutput.config.Labels `
        -and $inspectOutput.config.Labels.$baseNameAnnotationKey) {
        $baseImage = $inspectOutput.config.Labels.$baseNameAnnotationKey
        LogMessage "Found base image annotation from LABEL: '$baseImage'."
        return $baseImage
    }
    Set-StrictMode -Version 2.0

    # Check whether the annotation exists in the manifest
    $manifest = $(InvokeTool "dredge manifest get $TargetImage") | ConvertFrom-Json

    # The manifest may be for an image index, check that first.
    Set-StrictMode -Off
    if ($manifest.mediaType -eq "application/vnd.oci.image.index.v1+json") {
        if ($manifest.annotations -and $manifest.annotations.$baseNameAnnotationKey) {
            $baseImage = $manifest.Annotations.$baseNameAnnotationKey
            LogMessage "Found base image annotation from manifest: '$baseImage'."
            return $baseImage
        }
    }
    Set-StrictMode -Version 2.0

    $resolvedDigest = $(InvokeTool "dredge manifest resolve $TargetImage --os linux --arch $Architecture")
    $manifest = $(InvokeTool "dredge manifest get $resolvedDigest") | ConvertFrom-Json
    Set-StrictMode -Off
    if ($manifest.annotations -and $manifest.annotations.$baseNameAnnotationKey) {
        $baseImage = $manifest.Annotations.$baseNameAnnotationKey
        LogMessage "Found base image annotation from manifest: '$baseImage'."
        return $baseImage
    }
    Set-StrictMode -Version 2.0

    LogMessage "Could not find base image annotation '$baseNameAnnotationKey'."

    return $null
}

if ($DockerfilePath) {
    if (-not (Test-Path $DockerfilePath)) {
        throw "Dockerfile path '$DockerfilePath' does not exist."
    }
    $baseImage = GetBaseImageFromDockerfile
}
else {
    # If a Dockerfile path is not provided, we need to rely on the base image annotation being set on
    # the target image.
    $baseImage = GetBaseImageFromAnnotation
}

if (-not $baseImage) {
    throw "Could not derive base image name."
}

LogMessage "Using base image name '$baseImage'."

return $baseImage
