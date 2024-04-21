[cmdletbinding()]
param(
    [Parameter(Mandatory = $True)]
    [string]$DockerfilePath,
    [string]$BaseStageName
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version 2.0

function LogMessage ($Message) {
    Write-Output $Message | Out-File $env:HOME/log.txt -Append
}

if (-not (Test-Path $DockerfilePath)) {
    throw "Dockerfile path '$DockerfilePath' does not exist."
}

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

$expr = "dfspy $dfspyArgsString"
LogMessage "Invoke: $expr"
$fromOutput = Invoke-Expression $expr
$dfspyExitCode = $LASTEXITCODE
LogMessage "Result: $fromOutput"
if ($dfspyExitCode -ne 0) {
    throw "dfspy failed"
}
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

LogMessage "Using base image name '$baseImage'."

return $baseImage
