$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Set-StrictMode -Version 2.0

function LogMessage ([string] $Message) {
    Write-Output $Message | Out-File $env:HOME/log.txt -Append
}

function InvokeTool([string]$ToolCommand) {
    LogMessage "Invoke: $ToolCommand"
    
    # Reset $LASTEXITCODE in case it was tripped somewhere
    # See https://github.com/pester/Pester/issues/1616
    $Global:LASTEXITCODE = 0

    $result = Invoke-Expression $ToolCommand
    $exitCode = $LASTEXITCODE
    LogMessage "Result: $result"
    if ($exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: $ToolCommand"
    }

    return $result
}
